package colorpicker

import (
	"fmt"

	"golang.org/x/sys/unix"
)

type ShmBuffer struct {
	fd     int
	data   []byte
	size   int
	Width  int
	Height int
	Stride int
}

func CreateShmBuffer(width, height, stride int) (*ShmBuffer, error) {
	size := stride * height

	fd, err := unix.MemfdCreate("dms-colorpicker", 0)
	if err != nil {
		return nil, fmt.Errorf("failed to create memfd: %w", err)
	}

	if err := unix.Ftruncate(fd, int64(size)); err != nil {
		unix.Close(fd)
		return nil, fmt.Errorf("ftruncate failed: %w", err)
	}

	data, err := unix.Mmap(fd, 0, size, unix.PROT_READ|unix.PROT_WRITE, unix.MAP_SHARED)
	if err != nil {
		unix.Close(fd)
		return nil, fmt.Errorf("mmap failed: %w", err)
	}

	return &ShmBuffer{
		fd:     fd,
		data:   data,
		size:   size,
		Width:  width,
		Height: height,
		Stride: stride,
	}, nil
}

func (s *ShmBuffer) Fd() int {
	return s.fd
}

func (s *ShmBuffer) Size() int {
	return s.size
}

func (s *ShmBuffer) Data() []byte {
	return s.data
}

func (s *ShmBuffer) GetPixel(x, y int) Color {
	if x < 0 || x >= s.Width || y < 0 || y >= s.Height {
		return Color{}
	}

	offset := y*s.Stride + x*4

	if offset+3 >= len(s.data) {
		return Color{}
	}

	return Color{
		B: s.data[offset],
		G: s.data[offset+1],
		R: s.data[offset+2],
		A: s.data[offset+3],
	}
}

func (s *ShmBuffer) Close() error {
	var firstErr error
	if s.data != nil {
		if err := unix.Munmap(s.data); err != nil && firstErr == nil {
			firstErr = fmt.Errorf("munmap failed: %w", err)
		}
		s.data = nil
	}
	if s.fd >= 0 {
		if err := unix.Close(s.fd); err != nil && firstErr == nil {
			firstErr = fmt.Errorf("close fd failed: %w", err)
		}
		s.fd = -1
	}
	return firstErr
}
