package client

type Dispatcher interface {
	Dispatch(opcode uint32, fd int, data []byte)
}

type Proxy interface {
	Context() *Context
	SetContext(ctx *Context)
	ID() uint32
	SetID(id uint32)
}

type BaseProxy struct {
	ctx *Context
	id  uint32
}

func (p *BaseProxy) ID() uint32 {
	return p.id
}

func (p *BaseProxy) SetID(id uint32) {
	p.id = id
}

func (p *BaseProxy) Context() *Context {
	return p.ctx
}

func (p *BaseProxy) SetContext(ctx *Context) {
	p.ctx = ctx
}
