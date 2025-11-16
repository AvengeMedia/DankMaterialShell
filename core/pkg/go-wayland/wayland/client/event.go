package client

import (
	"bytes"
	"fmt"
	"unsafe"

	"golang.org/x/sys/unix"

	_ "unsafe"
)

var oobSpace = unix.CmsgSpace(4)

func (ctx *Context) ReadMsg() (senderID uint32, opcode uint32, fd int, msg []byte, err error) {
	fd = -1

	oob := make([]byte, oobSpace)
	header := make([]byte, 8)

	n, oobn, _, _, err := ctx.conn.ReadMsgUnix(header, oob)
	if err != nil {
		return senderID, opcode, fd, msg, err
	}
	if n != 8 {
		return senderID, opcode, fd, msg, fmt.Errorf("ctx.ReadMsg: incorrect number of bytes read for header (n=%d)", n)
	}

	if oobn > 0 {
		fds, err := getFdsFromOob(oob, oobn, "header")
		if err != nil {
			return senderID, opcode, fd, msg, fmt.Errorf("ctx.ReadMsg: %w", err)
		}

		if len(fds) > 0 {
			fd = fds[0]
		}
	}

	senderID = Uint32(header[:4])
	opcodeAndSize := Uint32(header[4:8])
	opcode = opcodeAndSize & 0xffff
	size := opcodeAndSize >> 16

	msgSize := int(size) - 8
	if msgSize == 0 {
		return senderID, opcode, fd, nil, nil
	}

	msg = make([]byte, msgSize)

	if fd == -1 {
		// if something was read before, then zero it out
		if oobn > 0 {
			oob = make([]byte, oobSpace)
		}

		n, oobn, _, _, err = ctx.conn.ReadMsgUnix(msg, oob)
	} else {
		n, err = ctx.conn.Read(msg)
	}
	if err != nil {
		return senderID, opcode, fd, msg, fmt.Errorf("ctx.ReadMsg: %w", err)
	}
	if n != msgSize {
		return senderID, opcode, fd, msg, fmt.Errorf("ctx.ReadMsg: incorrect number of bytes read for msg (n=%d, msgSize=%d)", n, msgSize)
	}

	if fd == -1 && oobn > 0 {
		fds, err := getFdsFromOob(oob, oobn, "msg")
		if err != nil {
			return senderID, opcode, fd, msg, fmt.Errorf("ctx.ReadMsg: %w", err)
		}

		if len(fds) > 0 {
			fd = fds[0]
		}
	}

	return senderID, opcode, fd, msg, nil
}

func getFdsFromOob(oob []byte, oobn int, source string) ([]int, error) {
	if oobn > len(oob) {
		return nil, fmt.Errorf("getFdsFromOob: incorrect number of bytes read from %s for oob (oobn=%d)", source, oobn)
	}
	scms, err := unix.ParseSocketControlMessage(oob)
	if err != nil {
		return nil, fmt.Errorf("getFdsFromOob: unable to parse control message from %s: %w", source, err)
	}

	var fdsRet []int
	for _, scm := range scms {
		fds, err := unix.ParseUnixRights(&scm)
		if err != nil {
			return nil, fmt.Errorf("getFdsFromOob: unable to parse unix rights from %s: %w", source, err)
		}

		fdsRet = append(fdsRet, fds...)
	}

	return fdsRet, nil
}

func Uint32(src []byte) uint32 {
	_ = src[3]
	return *(*uint32)(unsafe.Pointer(&src[0]))
}

func String(src []byte) string {
	idx := bytes.IndexByte(src, 0)
	src = src[:idx:idx]
	return *(*string)(unsafe.Pointer(&src))
}

func Fixed(src []byte) float64 {
	_ = src[3]
	fx := *(*int32)(unsafe.Pointer(&src[0]))
	return fixedToFloat64(fx)
}
