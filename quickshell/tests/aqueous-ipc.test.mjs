import assert from "node:assert/strict";
import {readFileSync} from "node:fs";
import vm from "node:vm";

const Ipc = vm.createContext({});
vm.runInContext(readFileSync(new URL("../Common/AqueousIpc.js", import.meta.url), "utf8"), Ipc);
assert(Ipc.socketPath("/private/runtime/aqueous/instance/ipc.sock", "/private/runtime"));
for (const path of ["", "relative", "/other/aqueous/instance/ipc.sock", "/private/runtime/aqueous/../ipc.sock", "/private/runtime/aqueous/one/two/ipc.sock", "/private/runtime/aqueous//ipc.sock"])
    assert.equal(Ipc.socketPath(path, "/private/runtime"), false, path);
assert.equal(Ipc.socketPath("/private/runtime/aqueous/instance/ipc.sock", ""), false);
const hello = JSON.parse(readFileSync(new URL("fixtures/aqueous/hello.json", import.meta.url))).result;
assert.equal(Ipc.hello(hello).session, hello.session);
for (const changed of [{schema: 2}, {session: "bad"}, {max_frame_bytes: 4259841}, {max_request_bytes: 65537}, {max_pending_requests: 2}, {capabilities: {}}, {capabilities: {...hello.capabilities, state: false}}])
    assert.throws(() => Ipc.hello({...hello, ...changed}), /unsupported/);
assert.equal(Ipc.nextId("9007199254740999"), "9007199254741000");
assert.equal(Ipc.nextId("9999999999999999999"), "10000000000000000000");
assert.throws(() => Ipc.nextId("99999999999999999999"), /exhausted/);
assert.equal(Ipc.envelope('{"ipc":1,"name":"🫧"}', 24).name, "🫧");
for (const text of ['{"ipc":2}', "[]", "null", '{"ipc":1,"a":' + "[".repeat(33) + "0" + "]".repeat(33) + "}"])
    assert.throws(() => Ipc.envelope(text, 1024));
assert.throws(() => Ipc.envelope('{"ipc":1,"name":"🫧"}', 20), /size bound/);
for (const value of [{ipc:1,id:"2",ok:true,result:{}}, {ipc:1,id:"1",ok:true,result:[]}, {ipc:1,id:"1",ok:false,error:{code:"locked"}}, {ipc:1,id:"1",ok:false,error:{code:7,message:"bad"}}, {ipc:1,id:"1",ok:true,result:{},event:"state"}])
    assert.throws(() => Ipc.response(value, "1"));
assert.equal(Ipc.response({id:"1",ok:false,error:{code:"busy",message:"queue full"}}, "1"), "busy: queue full");

function connection(events) {
    const sent = [], errors = [], installed = [], replies = [];
    const timer = () => ({running:false, restart(){this.running=true;},stop(){this.running=false;}});
    const ctx = vm.createContext({Ipc, events, connected:true, resetting:false, handshake:null,pending:null,lastId:"0",lastDelivery:"",subscribed:false,installed:false,
        frameParser:null, deadline:timer(), initialDeadline:timer(),
        socket:{linkUp:true,send(text){sent.push(JSON.parse(text));}},
        helloReceived(){},batchReceived(batch){installed.push(batch);},reply(result,error){replies.push({result,error});},failed(error){errors.push(error);}});
    ctx.root=ctx;
    Object.defineProperty(ctx,"ready",{get:()=>ctx.socket.linkUp && ctx.handshake!==null});
    const source=readFileSync(new URL("../Common/AqueousConnection.qml",import.meta.url),"utf8");
    for(const name of ["clear","fail","request","receive","subscribe"]){
        const start=source.indexOf("    function "+name+"(");
        vm.runInContext(source.slice(start,source.indexOf("\n    }",start)+6),ctx);
    }
    return {ctx,sent,errors,installed,replies};
}
const event={ipc:1,event:"state",delivery:"1",batch:{session:hello.session,type:"snapshot"}};
const respond=(c,result)=>c.ctx.receive(JSON.stringify({ipc:1,id:c.sent.at(-1).id,ok:true,result}));
const handshake=c=>{c.ctx.request("hello",{});respond(c,hello);};
const c=connection(true);
assert.throws(()=>c.ctx.request("subscribe",{}),/unavailable/);
handshake(c);
c.ctx.subscribe();
assert.equal(c.sent[1].session,hello.session);
respond(c,{subscribed:true});
c.ctx.receive(JSON.stringify(event));
assert.equal(c.installed.length,1);
assert.equal(c.sent.at(-1).op,"ack");
assert.equal(c.sent.at(-1).params.delivery,"1");
assert.equal(c.ctx.initialDeadline.running,false);
respond(c,{acked:"1"});
assert.equal(c.ctx.deadline.running,false);
c.ctx.receive(JSON.stringify({...event,delivery:"2",batch:{...event.batch,type:"delta"}}));
respond(c,{acked:"wrong"});
assert.match(c.errors.at(-1),/ack/);
for(const scenario of ["before subscribe reply","before ack reply","duplicate delivery","wrong session","delta first","unsolicited reply"]){
    const c=connection(true);handshake(c);c.ctx.subscribe();
    if(scenario!=="before subscribe reply") respond(c,{subscribed:true});
    if(scenario==="before ack reply" || scenario==="duplicate delivery"){
        c.ctx.receive(JSON.stringify(event));
        if(scenario==="duplicate delivery")respond(c,{acked:"1"});
    }
    let value=event;
    if(scenario==="wrong session")value={...event,batch:{...event.batch,session:"f".repeat(32)}};
    if(scenario==="delta first")value={...event,batch:{...event.batch,type:"delta"}};
    if(scenario==="unsolicited reply")value={ipc:1,id:"10",ok:true,result:{}};
    c.ctx.receive(JSON.stringify(value));
    assert.equal(c.errors.length,1,scenario);
}
const command=connection(false);handshake(command);
command.ctx.request("command",{action:"session.exit",fields:{}});
assert.throws(()=>command.ctx.request("command",{}),/unavailable/);
respond(command,{status:"accepted"});
assert.equal(command.replies[0].result.status,"accepted");
assert.equal(command.ctx.pending,null);
command.ctx.receive(JSON.stringify(event));
assert.match(command.errors.at(-1),/unexpected/);
command.ctx.clear();
assert.equal(command.ctx.handshake,null);
assert.equal(command.ctx.lastId,"0");
console.log("PASS: IPC envelopes, exact IDs, handshake, correlation, subscription/ack order and accepted results");
