package wp_cursor_shape

import "github.com/AvengeMedia/dankgo/wayland/client"

const WpCursorShapeManagerV1InterfaceName = "wp_cursor_shape_manager_v1"

const (
	ShapeCrosshair uint32 = 8
	ShapeGrab      uint32 = 16
	ShapeGrabbing  uint32 = 17
)

type WpCursorShapeManagerV1 struct{ client.BaseProxy }

func NewWpCursorShapeManagerV1(ctx *client.Context) *WpCursorShapeManagerV1 {
	mgr := &WpCursorShapeManagerV1{}
	ctx.Register(mgr)
	return mgr
}

func (i *WpCursorShapeManagerV1) GetPointer(pointer *client.Pointer) (*WpCursorShapeDeviceV1, error) {
	device := NewWpCursorShapeDeviceV1(i.Context())
	const requestLen = 16
	var request [requestLen]byte
	client.PutUint32(request[0:4], i.ID())
	client.PutUint32(request[4:8], uint32(requestLen<<16|1))
	client.PutUint32(request[8:12], device.ID())
	client.PutUint32(request[12:16], pointer.ID())
	return device, i.Context().WriteMsg(request[:], nil)
}

func (i *WpCursorShapeManagerV1) Destroy() error {
	defer i.MarkZombie()
	var request [8]byte
	client.PutUint32(request[0:4], i.ID())
	client.PutUint32(request[4:8], 8<<16)
	return i.Context().WriteMsg(request[:], nil)
}

type WpCursorShapeDeviceV1 struct{ client.BaseProxy }

func NewWpCursorShapeDeviceV1(ctx *client.Context) *WpCursorShapeDeviceV1 {
	device := &WpCursorShapeDeviceV1{}
	ctx.Register(device)
	return device
}

func (i *WpCursorShapeDeviceV1) SetShape(serial, shape uint32) error {
	const requestLen = 16
	var request [requestLen]byte
	client.PutUint32(request[0:4], i.ID())
	client.PutUint32(request[4:8], uint32(requestLen<<16|1))
	client.PutUint32(request[8:12], serial)
	client.PutUint32(request[12:16], shape)
	return i.Context().WriteMsg(request[:], nil)
}

func (i *WpCursorShapeDeviceV1) Destroy() error {
	defer i.MarkZombie()
	var request [8]byte
	client.PutUint32(request[0:4], i.ID())
	client.PutUint32(request[4:8], 8<<16)
	return i.Context().WriteMsg(request[:], nil)
}
