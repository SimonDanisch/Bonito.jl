import test from "node:test";
import assert from "node:assert/strict";
import { MessageWindow, MessageWindows } from "../js_dependencies/MessageWindow.js";

function fixture(capacity = 2, limit = 8) {
    const sent = [];
    const window = new MessageWindow({ capacity, limit,
        encode: (value, sequence) => ({ value, sequence }),
        send: packet => { sent.push(packet); return true; },
    });
    return { window, sent };
}

test("a bounded window holds events in FIFO order", () => {
    const { window, sent } = fixture();
    for (let i=1; i<=6; i++) window.enqueue(i);
    assert.equal(sent.length, 0);
    window.resume(0, 0);
    assert.deepEqual(sent.map(p => p.value), [1,2]);
    window.ack(2, 1);
    assert.deepEqual(sent.map(p => p.value), [1,2,3]);
    window.ack(3, 3);
    assert.deepEqual(sent.map(p => p.value), [1,2,3,4,5]);
    window.ack(5, 5);
    assert.deepEqual(sent.map(p => p.value), [1,2,3,4,5,6]);
    window.ack(6,6);
    assert.equal(window.backlog, 0);
});

test("duplicate and delayed credit cannot over-grant", () => {
    const { window, sent } = fixture();
    window.resume(0,0);
    for (let i=1; i<=6; i++) window.enqueue(i);
    window.ack(2,1);
    window.ack(2,1);
    window.ack(1,0);
    assert.equal(sent.length, 3);
    window.ack(3,2);
    assert.equal(sent.length, 4);
});

test("reconnect replays only unacknowledged events with their original identity", () => {
    const { window, sent } = fixture();
    window.resume(0,0);
    window.enqueue("first"); window.enqueue("second"); window.enqueue("third");
    window.ack(1,0);
    window.disconnect();
    window.resume(1,1);
    assert.deepEqual(sent.map(p => [p.sequence,p.value]), [[1,"first"],[2,"second"],[2,"second"],[3,"third"]]);
});

test("an acknowledgement lost on disconnect does not repeat an accepted event", () => {
    const { window, sent } = fixture();
    window.resume(0,0);
    window.enqueue("one"); window.enqueue("two"); window.enqueue("three");
    window.disconnect();
    window.resume(2,1);
    assert.deepEqual(sent.map(p => p.value), ["one","two","three"]);
});

test("overflow is explicit and does not consume an event identity", () => {
    const { window, sent } = fixture(1,2);
    window.enqueue(1); window.enqueue(2);
    assert.throws(() => window.enqueue(3), /backlog/i);
    window.resume(0,0);
    window.ack(1,1); window.ack(2,2);
    window.enqueue(4);
    assert.deepEqual(sent.map(p => p.sequence), [1,2,3]);
    assert.deepEqual(sent.map(p => p.value), [1,2,4]);
});

test("invalid credits and lost receiver state fail explicitly", () => {
    const { window } = fixture();
    window.resume(0,0); window.enqueue(1);
    assert.throws(() => window.ack(2,2), /credit/i);
    window.ack(1,1); window.disconnect();
    assert.throws(() => window.resume(0,0), /state/i);
});

test("a long burst remains bounded and preserves exact ordering", () => {
    const { window, sent } = fixture(4,1200);
    window.resume(0,0);
    for (let i=1;i<=1100;i++) window.enqueue(i);
    assert.equal(sent.length,4);
    for (let released=1;released<=1100;released++) {
        window.ack(Math.min(sent.length,1100),released);
        assert.ok(sent.length-released<=4);
    }
    assert.deepEqual(sent.map(p=>p.value),Array.from({length:1100},(_,i)=>i+1));
    assert.equal(window.backlog,0);
});

test("embedded aliases share their owner's window", () => {
    const sent=[], queries=[];
    const windows=new MessageWindows({encode:x=>x,send:x=>{sent.push(x);return true;},query:x=>queries.push(x)});
    windows.open();
    const page={owner:"page/flow/1",alias:"page",default:true,capacity:1,received:0,released:0};
    windows.configure({...page,resume:false});
    assert.deepEqual(queries,[page.owner]);
    windows.configure({...page,resume:true});
    windows.configure({...page,alias:"worker",default:false,resume:false});
    windows.enqueue({id:"worker/observable",payload:1});
    windows.enqueue({id:"ordinary-observable",payload:2});
    assert.equal(sent.length,1);
    assert.equal(sent[0].flow_owner,page.owner);
    windows.credit({owner:page.owner,received:1,released:1});
    assert.equal(sent.length,2);
    assert.deepEqual(sent.map(x=>x.event_sequence),[1,2]);
    assert.equal(windows.windows.size,1);
});

test("remote owners have independent admission and reconnect status", () => {
    const sent=[], queries=[];
    const windows=new MessageWindows({encode:x=>x,send:x=>{sent.push(x);return true;},query:x=>queries.push(x)});
    windows.open();
    const page={owner:"page/flow/1",alias:"page",default:true,capacity:1,received:0,released:0,resume:true};
    const remote={...page,owner:"remote/flow/1",alias:"remote",default:false};
    windows.configure(page); windows.configure(remote);
    windows.enqueue({id:"remote/one"}); windows.enqueue({id:"remote/two"});
    windows.enqueue({id:"local"});
    assert.deepEqual(sent.map(x=>x.id),["remote/one","local"]);
    windows.disconnect(); windows.open();
    assert.ok(queries.includes(remote.owner));
    windows.configure({...remote,received:1,released:1});
    assert.deepEqual(sent.map(x=>x.id),["remote/one","local","remote/two"]);
    windows.forget(remote.owner);
    assert.equal(windows.windows.size,1);
    assert.equal(windows.aliases.has(remote.alias),false);
});

test("a transport exception preserves replay identity and pauses sending", () => {
    let fail=true; const sent=[];
    const window=new MessageWindow({capacity:1,limit:4,encode:(value,sequence)=>({value,sequence}),
        send:packet=>{if(fail)throw new Error("transport failed");sent.push(packet);return true;}});
    window.resume(0,0);
    assert.throws(()=>window.enqueue("one"),/transport failed/);
    assert.equal(window.connected,false);
    fail=false; window.resume(0,0);
    assert.deepEqual(sent,[{value:"one",sequence:1}]);
});

test("events during initialization retain their original value", () => {
    const sent = [];
    const windows = new MessageWindows({encode: value => value, send: packet => {sent.push(packet);return true;},query:()=>{}});
    const payload = {value:1};
    windows.enqueue({id:"observable",payload});
    payload.value=2;
    windows.configure({owner:"host",alias:"host",capacity:2,received:0,released:0,resume:false,default:true});
    windows.open();
    windows.configure({owner:"host",alias:"host",capacity:2,received:0,released:0,resume:true,default:true});
    assert.equal(sent.length,1);
    assert.equal(sent[0].payload.value,1);
});

test("an uninitialized remote alias never spends the host's credits", () => {
    const sent=[];
    const windows = new MessageWindows({encode:value=>value,send:packet=>{sent.push(packet);return true;},query:()=>{}});
    windows.open();
    windows.configure({owner:"host",alias:"host",capacity:2,received:0,released:0,resume:true,default:true});
    windows.enqueue({id:"remote/observable",payload:7});
    assert.equal(sent.length,0);
    windows.configure({owner:"worker",alias:"remote",capacity:2,received:0,released:0,resume:true,default:false});
    assert.equal(sent.length,1);
    assert.equal(sent[0].flow_owner,"worker");
});
