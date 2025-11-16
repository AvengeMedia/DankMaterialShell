package client

import (
	"fmt"
	"unsafe"
)

func (ctx *Context) WriteMsg(b []byte, oob []byte) error {
	n, oobn, err := ctx.conn.WriteMsgUnix(b, oob, nil)
	if err != nil {
		return err
	}
	if n != len(b) || oobn != len(oob) {
		return fmt.Errorf("ctx.WriteMsg: incorrect number of bytes written (n=%d oobn=%d)", n, oobn)
	}

	return nil
}

func PutUint32(dst []byte, v uint32) {
	_ = dst[3]
	*(*uint32)(unsafe.Pointer(&dst[0])) = v
}

func PutFixed(dst []byte, f float64) {
	fx := fixedFromfloat64(f)
	_ = dst[3]
	*(*int32)(unsafe.Pointer(&dst[0])) = fx
}

// PutString places a string in Wayland's wire format on the destination buffer.
// It first places the length of the string (plus one for the null terminator) and then the string
// followed by a null byte.
// The length of dst must be equal to, or greater than, len(v) + 5.
func PutString(dst []byte, v string) {
	PutUint32(dst[:4], uint32(len(v)+1))
	copy(dst[4:], v)
	dst[4+len(v)] = '\x00' // To cause panic if dst is not large enough
}

func PutArray(dst []byte, a []byte) {
	PutUint32(dst[:4], uint32(len(a)))
	copy(dst[4:], a)
}
