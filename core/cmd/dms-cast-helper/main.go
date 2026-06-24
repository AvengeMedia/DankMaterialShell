//go:build casthelper

// Command dms-cast-helper captures the screen with GStreamer (the go-gst
// library — no gst-launch CLI) and either writes an HLS stream (for Chromecast)
// or an H.264 byte-stream to stdout (for AirPlay/doubletake).
//
// The screen source is the xdg-desktop-portal PipeWire remote: the parent
// negotiates the portal and passes the remote fd as fd 3 plus the node id via
// -node. With -test the source is a synthetic pattern (no portal needed), which
// makes the pipeline verifiable offline.
//
// Built only with CGO (it links GStreamer); the package has a no-cgo stub so
// `CGO_ENABLED=0 go build ./...` over the core stays green.
package main

import (
	"flag"
	"fmt"
	"os"
	"time"

	"github.com/go-gst/go-gst/gst"
	"github.com/go-gst/go-gst/gst/app"
)

const portalFD = 3 // the PipeWire remote fd the parent passes via ExtraFiles

func main() {
	mode := flag.String("mode", "h264", "output mode: h264 (stdout) | hls")
	out := flag.String("out", "", "HLS output directory (mode=hls)")
	node := flag.Int("node", 0, "PipeWire node id from the portal")
	fps := flag.Int("fps", 30, "framerate")
	bitrate := flag.Int("bitrate", 4147, "x264 bitrate kbps")
	width := flag.Int("width", 1920, "scaled width")
	height := flag.Int("height", 1080, "scaled height")
	test := flag.Bool("test", false, "use a synthetic source instead of the portal (debug)")
	flag.Parse()

	gst.Init(nil)

	desc, err := buildPipeline(*mode, *out, *node, *fps, *bitrate, *width, *height, *test)
	if err != nil {
		fmt.Fprintln(os.Stderr, "dms-cast-helper:", err)
		os.Exit(2)
	}

	pipeline, err := gst.NewPipelineFromString(desc)
	if err != nil {
		fmt.Fprintln(os.Stderr, "pipeline:", err)
		os.Exit(1)
	}

	// Rewrite PTS to a monotonic timeline on the encoder input: the portal
	// delivers pts=0 on every buffer, which breaks HLS segmentation (hlssink
	// cuts segments by timestamp) and gives the encoder no temporal reference.
	if err := restampEncoderInput(pipeline, *fps); err != nil {
		fmt.Fprintln(os.Stderr, "restamp:", err)
		os.Exit(1)
	}

	if *mode == "h264" {
		if err := wireH264Stdout(pipeline); err != nil {
			fmt.Fprintln(os.Stderr, "appsink:", err)
			os.Exit(1)
		}
	}

	if err := pipeline.SetState(gst.StatePlaying); err != nil {
		fmt.Fprintln(os.Stderr, "set playing:", err)
		os.Exit(1)
	}
	runUntilDone(pipeline)
}

// buildPipeline assembles the GStreamer pipeline description.
func buildPipeline(mode, out string, node, fps, bitrate, width, height int, test bool) (string, error) {
	var src string
	if test {
		// Synthetic source — already system-memory, no DMA-BUF import needed.
		src = fmt.Sprintf("videotestsrc is-live=true pattern=18 ! video/x-raw,width=%d,height=%d,framerate=%d/1,format=I420 ! videoconvert", width, height, fps)
	} else {
		// Portal PipeWire source: VA-import the DMA-BUF, scale, and force 4:2:0
		// (I420). RGB screens would otherwise yield High 4:4:4 Predictive, which
		// consumer TV/Cast decoders can't decode -> black.
		src = fmt.Sprintf("pipewiresrc fd=%d path=%d do-timestamp=true ! vapostproc ! video/x-raw,width=%d,height=%d,format=I420 ! videoconvert", portalFD, node, width, height)
	}

	enc := fmt.Sprintf("x264enc name=enc tune=zerolatency speed-preset=superfast bitrate=%d key-int-max=%d byte-stream=true ! h264parse config-interval=-1", bitrate, fps)

	switch mode {
	case "h264":
		return src + " ! " + enc + " ! video/x-h264,stream-format=byte-stream,alignment=au ! appsink name=sink sync=false max-buffers=8 drop=false", nil
	case "hls":
		if out == "" {
			return "", fmt.Errorf("mode=hls requires -out <dir>")
		}
		hls := fmt.Sprintf("mpegtsmux ! hlssink location=%s/segment%%05d.ts playlist-location=%s/stream.m3u8 target-duration=1 max-files=10 playlist-length=5", out, out)
		return src + " ! " + enc + " ! " + hls, nil
	default:
		return "", fmt.Errorf("unknown -mode %q (want h264|hls)", mode)
	}
}

// restampEncoderInput adds a pad probe on the encoder's sink that rewrites each
// buffer's PTS/duration to a monotonic fps timeline.
func restampEncoderInput(pipeline *gst.Pipeline, fps int) error {
	enc, err := pipeline.GetElementByName("enc")
	if err != nil {
		return err
	}
	sinkPad := enc.GetStaticPad("sink")
	frameDur := uint64(time.Second) / uint64(fps)
	var frame uint64
	sinkPad.AddProbe(gst.PadProbeTypeBuffer, func(self *gst.Pad, info *gst.PadProbeInfo) gst.PadProbeReturn {
		buf := info.GetBuffer()
		if buf == nil {
			return gst.PadProbeOK
		}
		buf.SetPresentationTimestamp(gst.ClockTime(frame * frameDur))
		buf.SetDuration(gst.ClockTime(frameDur))
		frame++
		return gst.PadProbeOK
	})
	return nil
}

// wireH264Stdout streams appsink buffers (raw H.264 byte-stream) to stdout.
func wireH264Stdout(pipeline *gst.Pipeline) error {
	elem, err := pipeline.GetElementByName("sink")
	if err != nil {
		return err
	}
	sink := app.SinkFromElement(elem)
	sink.SetCallbacks(&app.SinkCallbacks{
		NewSampleFunc: func(s *app.Sink) gst.FlowReturn {
			sample := s.PullSample()
			if sample == nil {
				return gst.FlowEOS
			}
			if _, err := os.Stdout.Write(sample.GetBuffer().Bytes()); err != nil {
				return gst.FlowError
			}
			return gst.FlowOK
		},
	})
	return nil
}

// runUntilDone blocks on the bus until EOS or error.
func runUntilDone(pipeline *gst.Pipeline) {
	bus := pipeline.GetBus()
	for {
		msg := bus.TimedPop(gst.ClockTime(uint64(gst.ClockTimeNone)))
		if msg == nil {
			continue
		}
		switch msg.Type() {
		case gst.MessageEOS:
			pipeline.SetState(gst.StateNull)
			return
		case gst.MessageError:
			fmt.Fprintln(os.Stderr, "gst error:", msg.ParseError().Error())
			pipeline.SetState(gst.StateNull)
			os.Exit(1)
		}
	}
}
