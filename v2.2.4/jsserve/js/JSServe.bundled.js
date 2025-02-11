// deno-fmt-ignore-file
// deno-lint-ignore-file
// This code was bundled using `deno bundle` and it's not recommended to edit it manually

var P = Object.create;
var d = Object.defineProperty;
var T = Object.getOwnPropertyDescriptor;
var F = Object.getOwnPropertyNames;
var I = Object.getPrototypeOf, K = Object.prototype.hasOwnProperty;
var o = (t, e)=>d(t, "name", {
        value: e,
        configurable: !0
    });
var W = (t, e)=>()=>(e || t((e = {
            exports: {}
        }).exports, e), e.exports);
var $ = (t, e, n, r)=>{
    if (e && typeof e == "object" || typeof e == "function") for (let i of F(e))!K.call(t, i) && i !== n && d(t, i, {
        get: ()=>e[i],
        enumerable: !(r = T(e, i)) || r.enumerable
    });
    return t;
};
var y = (t, e, n)=>(n = t != null ? P(I(t)) : {}, $(e || !t || !t.__esModule ? d(n, "default", {
        value: t,
        enumerable: !0
    }) : n, t));
var m = W((J, h)=>{
    "use strict";
    var c = typeof Reflect == "object" ? Reflect : null, g = c && typeof c.apply == "function" ? c.apply : o(function(e, n, r) {
        return Function.prototype.apply.call(e, n, r);
    }, "ReflectApply"), v;
    c && typeof c.ownKeys == "function" ? v = c.ownKeys : Object.getOwnPropertySymbols ? v = o(function(e) {
        return Object.getOwnPropertyNames(e).concat(Object.getOwnPropertySymbols(e));
    }, "ReflectOwnKeys") : v = o(function(e) {
        return Object.getOwnPropertyNames(e);
    }, "ReflectOwnKeys");
    function S(t) {
        console && console.warn && console.warn(t);
    }
    o(S, "ProcessEmitWarning");
    var w = Number.isNaN || o(function(e) {
        return e !== e;
    }, "NumberIsNaN");
    function f() {
        f.init.call(this);
    }
    o(f, "EventEmitter");
    h.exports = f;
    h.exports.once = q;
    f.EventEmitter = f;
    f.prototype._events = void 0;
    f.prototype._eventsCount = 0;
    f.prototype._maxListeners = void 0;
    var _ = 10;
    function p(t) {
        if (typeof t != "function") throw new TypeError('The "listener" argument must be of type Function. Received type ' + typeof t);
    }
    o(p, "checkListener");
    Object.defineProperty(f, "defaultMaxListeners", {
        enumerable: !0,
        get: function() {
            return _;
        },
        set: function(t) {
            if (typeof t != "number" || t < 0 || w(t)) throw new RangeError('The value of "defaultMaxListeners" is out of range. It must be a non-negative number. Received ' + t + ".");
            _ = t;
        }
    });
    f.init = function() {
        (this._events === void 0 || this._events === Object.getPrototypeOf(this)._events) && (this._events = Object.create(null), this._eventsCount = 0), this._maxListeners = this._maxListeners || void 0;
    };
    f.prototype.setMaxListeners = o(function(e) {
        if (typeof e != "number" || e < 0 || w(e)) throw new RangeError('The value of "n" is out of range. It must be a non-negative number. Received ' + e + ".");
        return this._maxListeners = e, this;
    }, "setMaxListeners");
    function b(t) {
        return t._maxListeners === void 0 ? f.defaultMaxListeners : t._maxListeners;
    }
    o(b, "_getMaxListeners");
    f.prototype.getMaxListeners = o(function() {
        return b(this);
    }, "getMaxListeners");
    f.prototype.emit = o(function(e) {
        for(var n = [], r = 1; r < arguments.length; r++)n.push(arguments[r]);
        var i = e === "error", u = this._events;
        if (u !== void 0) i = i && u.error === void 0;
        else if (!i) return !1;
        if (i) {
            var s;
            if (n.length > 0 && (s = n[0]), s instanceof Error) throw s;
            var a = new Error("Unhandled error." + (s ? " (" + s.message + ")" : ""));
            throw a.context = s, a;
        }
        var l = u[e];
        if (l === void 0) return !1;
        if (typeof l == "function") g(l, this, n);
        else for(var L = l.length, A = j(l, L), r = 0; r < L; ++r)g(A[r], this, n);
        return !0;
    }, "emit");
    function E(t, e, n, r) {
        var i, u, s;
        if (p(n), u = t._events, u === void 0 ? (u = t._events = Object.create(null), t._eventsCount = 0) : (u.newListener !== void 0 && (t.emit("newListener", e, n.listener ? n.listener : n), u = t._events), s = u[e]), s === void 0) s = u[e] = n, ++t._eventsCount;
        else if (typeof s == "function" ? s = u[e] = r ? [
            n,
            s
        ] : [
            s,
            n
        ] : r ? s.unshift(n) : s.push(n), i = b(t), i > 0 && s.length > i && !s.warned) {
            s.warned = !0;
            var a = new Error("Possible EventEmitter memory leak detected. " + s.length + " " + String(e) + " listeners added. Use emitter.setMaxListeners() to increase limit");
            a.name = "MaxListenersExceededWarning", a.emitter = t, a.type = e, a.count = s.length, S(a);
        }
        return t;
    }
    o(E, "_addListener");
    f.prototype.addListener = o(function(e, n) {
        return E(this, e, n, !1);
    }, "addListener");
    f.prototype.on = f.prototype.addListener;
    f.prototype.prependListener = o(function(e, n) {
        return E(this, e, n, !0);
    }, "prependListener");
    function U() {
        if (!this.fired) return this.target.removeListener(this.type, this.wrapFn), this.fired = !0, arguments.length === 0 ? this.listener.call(this.target) : this.listener.apply(this.target, arguments);
    }
    o(U, "onceWrapper");
    function O(t, e, n) {
        var r = {
            fired: !1,
            wrapFn: void 0,
            target: t,
            type: e,
            listener: n
        }, i = U.bind(r);
        return i.listener = n, r.wrapFn = i, i;
    }
    o(O, "_onceWrap");
    f.prototype.once = o(function(e, n) {
        return p(n), this.on(e, O(this, e, n)), this;
    }, "once");
    f.prototype.prependOnceListener = o(function(e, n) {
        return p(n), this.prependListener(e, O(this, e, n)), this;
    }, "prependOnceListener");
    f.prototype.removeListener = o(function(e, n) {
        var r, i, u, s, a;
        if (p(n), i = this._events, i === void 0) return this;
        if (r = i[e], r === void 0) return this;
        if (r === n || r.listener === n) --this._eventsCount === 0 ? this._events = Object.create(null) : (delete i[e], i.removeListener && this.emit("removeListener", e, r.listener || n));
        else if (typeof r != "function") {
            for(u = -1, s = r.length - 1; s >= 0; s--)if (r[s] === n || r[s].listener === n) {
                a = r[s].listener, u = s;
                break;
            }
            if (u < 0) return this;
            u === 0 ? r.shift() : k(r, u), r.length === 1 && (i[e] = r[0]), i.removeListener !== void 0 && this.emit("removeListener", e, a || n);
        }
        return this;
    }, "removeListener");
    f.prototype.off = f.prototype.removeListener;
    f.prototype.removeAllListeners = o(function(e) {
        var n, r, i;
        if (r = this._events, r === void 0) return this;
        if (r.removeListener === void 0) return arguments.length === 0 ? (this._events = Object.create(null), this._eventsCount = 0) : r[e] !== void 0 && (--this._eventsCount === 0 ? this._events = Object.create(null) : delete r[e]), this;
        if (arguments.length === 0) {
            var u = Object.keys(r), s;
            for(i = 0; i < u.length; ++i)s = u[i], s !== "removeListener" && this.removeAllListeners(s);
            return this.removeAllListeners("removeListener"), this._events = Object.create(null), this._eventsCount = 0, this;
        }
        if (n = r[e], typeof n == "function") this.removeListener(e, n);
        else if (n !== void 0) for(i = n.length - 1; i >= 0; i--)this.removeListener(e, n[i]);
        return this;
    }, "removeAllListeners");
    function x(t, e, n) {
        var r = t._events;
        if (r === void 0) return [];
        var i = r[e];
        return i === void 0 ? [] : typeof i == "function" ? n ? [
            i.listener || i
        ] : [
            i
        ] : n ? H(i) : j(i, i.length);
    }
    o(x, "_listeners");
    f.prototype.listeners = o(function(e) {
        return x(this, e, !0);
    }, "listeners");
    f.prototype.rawListeners = o(function(e) {
        return x(this, e, !1);
    }, "rawListeners");
    f.listenerCount = function(t, e) {
        return typeof t.listenerCount == "function" ? t.listenerCount(e) : C.call(t, e);
    };
    f.prototype.listenerCount = C;
    function C(t) {
        var e = this._events;
        if (e !== void 0) {
            var n = e[t];
            if (typeof n == "function") return 1;
            if (n !== void 0) return n.length;
        }
        return 0;
    }
    o(C, "listenerCount");
    f.prototype.eventNames = o(function() {
        return this._eventsCount > 0 ? v(this._events) : [];
    }, "eventNames");
    function j(t, e) {
        for(var n = new Array(e), r = 0; r < e; ++r)n[r] = t[r];
        return n;
    }
    o(j, "arrayClone");
    function k(t, e) {
        for(; e + 1 < t.length; e++)t[e] = t[e + 1];
        t.pop();
    }
    o(k, "spliceOne");
    function H(t) {
        for(var e = new Array(t.length), n = 0; n < e.length; ++n)e[n] = t[n].listener || t[n];
        return e;
    }
    o(H, "unwrapListeners");
    function q(t, e) {
        return new Promise(function(n, r) {
            function i(s) {
                t.removeListener(e, u), r(s);
            }
            o(i, "errorListener");
            function u() {
                typeof t.removeListener == "function" && t.removeListener("error", i), n([].slice.call(arguments));
            }
            o(u, "resolver"), R(t, e, u, {
                once: !0
            }), e !== "error" && z(t, i, {
                once: !0
            });
        });
    }
    o(q, "once");
    function z(t, e, n) {
        typeof t.on == "function" && R(t, "error", e, n);
    }
    o(z, "addErrorHandlerIfEventEmitter");
    function R(t, e, n, r) {
        if (typeof t.on == "function") r.once ? t.once(e, n) : t.on(e, n);
        else if (typeof t.addEventListener == "function") t.addEventListener(e, o(function i(u) {
            r.once && t.removeEventListener(e, i), n(u);
        }, "wrapListener"));
        else throw new TypeError('The "emitter" argument must be of type EventEmitter. Received type ' + typeof t);
    }
    o(R, "eventTargetAgnosticAddListener");
});
var N = y(m()), M = y(m()), { EventEmitter: Q , init: V , listenerCount: X , once: Y  } = M, { default: B , ...D } = M, Z = N.default ?? B ?? D;
const events = new Q();
events.setMaxListeners(1 << 10);
const deno = typeof Deno !== "undefined";
const __default = {
    title: deno ? "deno" : "browser",
    browser: true,
    env: deno ? new Proxy({}, {
        get (_target, prop) {
            return Deno.env.get(String(prop));
        },
        ownKeys: ()=>Reflect.ownKeys(Deno.env.toObject()),
        getOwnPropertyDescriptor: (_target, name)=>{
            const e = Deno.env.toObject();
            if (name in Deno.env.toObject()) {
                const o = {
                    enumerable: true,
                    configurable: true
                };
                if (typeof name === "string") {
                    o.value = e[name];
                }
                return o;
            }
        },
        set (_target, prop, value) {
            Deno.env.set(String(prop), String(value));
            return value;
        }
    }) : {},
    argv: deno ? Deno.args ?? [] : [],
    pid: deno ? Deno.pid ?? 0 : 0,
    version: "v16.18.0",
    versions: {
        node: '16.18.0',
        v8: '9.4.146.26-node.22',
        uv: '1.43.0',
        zlib: '1.2.11',
        brotli: '1.0.9',
        ares: '1.18.1',
        modules: '93',
        nghttp2: '1.47.0',
        napi: '8',
        llhttp: '6.0.10',
        openssl: '1.1.1q+quic',
        cldr: '41.0',
        icu: '71.1',
        tz: '2022b',
        unicode: '14.0',
        ngtcp2: '0.8.1',
        nghttp3: '0.7.0',
        ...deno ? Deno.version ?? {} : {}
    },
    on: (...args)=>events.on(...args),
    addListener: (...args)=>events.addListener(...args),
    once: (...args)=>events.once(...args),
    off: (...args)=>events.off(...args),
    removeListener: (...args)=>events.removeListener(...args),
    removeAllListeners: (...args)=>events.removeAllListeners(...args),
    emit: (...args)=>events.emit(...args),
    prependListener: (...args)=>events.prependListener(...args),
    prependOnceListener: (...args)=>events.prependOnceListener(...args),
    listeners: ()=>[],
    emitWarning: ()=>{
        throw new Error("process.emitWarning is not supported");
    },
    binding: ()=>{
        throw new Error("process.binding is not supported");
    },
    cwd: ()=>deno ? Deno.cwd?.() ?? "/" : "/",
    chdir: (path)=>{
        if (deno) {
            Deno.chdir(path);
        } else {
            throw new Error("process.chdir is not supported");
        }
    },
    umask: ()=>deno ? Deno.umask ?? 0 : 0,
    nextTick: (func, ...args)=>queueMicrotask(()=>func(...args))
};
var v = 4294967295;
function H(i, e, t) {
    var r = t / 4294967296, s = t;
    i.setUint32(e, r), i.setUint32(e + 4, s);
}
function A(i, e, t) {
    var r = Math.floor(t / 4294967296), s = t;
    i.setUint32(e, r), i.setUint32(e + 4, s);
}
function D1(i, e) {
    var t = i.getInt32(e), r = i.getUint32(e + 4);
    return t * 4294967296 + r;
}
function b(i, e) {
    var t = i.getUint32(e), r = i.getUint32(e + 4);
    return t * 4294967296 + r;
}
var k, O, R, M1 = (typeof __default > "u" || ((k = __default?.env) === null || k === void 0 ? void 0 : k.TEXT_ENCODING) !== "never") && typeof TextEncoder < "u" && typeof TextDecoder < "u";
function F1(i) {
    for(var e = i.length, t = 0, r = 0; r < e;){
        var s = i.charCodeAt(r++);
        if ((s & 4294967168) === 0) {
            t++;
            continue;
        } else if ((s & 4294965248) === 0) t += 2;
        else {
            if (s >= 55296 && s <= 56319 && r < e) {
                var n = i.charCodeAt(r);
                (n & 64512) === 56320 && (++r, s = ((s & 1023) << 10) + (n & 1023) + 65536);
            }
            (s & 4294901760) === 0 ? t += 3 : t += 4;
        }
    }
    return t;
}
function X1(i, e, t) {
    for(var r = i.length, s = t, n = 0; n < r;){
        var o = i.charCodeAt(n++);
        if ((o & 4294967168) === 0) {
            e[s++] = o;
            continue;
        } else if ((o & 4294965248) === 0) e[s++] = o >> 6 & 31 | 192;
        else {
            if (o >= 55296 && o <= 56319 && n < r) {
                var f = i.charCodeAt(n);
                (f & 64512) === 56320 && (++n, o = ((o & 1023) << 10) + (f & 1023) + 65536);
            }
            (o & 4294901760) === 0 ? (e[s++] = o >> 12 & 15 | 224, e[s++] = o >> 6 & 63 | 128) : (e[s++] = o >> 18 & 7 | 240, e[s++] = o >> 12 & 63 | 128, e[s++] = o >> 6 & 63 | 128);
        }
        e[s++] = o & 63 | 128;
    }
}
var T1 = M1 ? new TextEncoder : void 0, W1 = M1 ? typeof __default < "u" && ((O = __default?.env) === null || O === void 0 ? void 0 : O.TEXT_ENCODING) !== "force" ? 200 : 0 : v;
function oe(i, e, t) {
    e.set(T1.encode(i), t);
}
function ae(i, e, t) {
    T1.encodeInto(i, e.subarray(t));
}
var G = T1?.encodeInto ? ae : oe, fe = 4096;
function C(i, e, t) {
    for(var r = e, s = r + t, n = [], o = ""; r < s;){
        var f = i[r++];
        if ((f & 128) === 0) n.push(f);
        else if ((f & 224) === 192) {
            var c = i[r++] & 63;
            n.push((f & 31) << 6 | c);
        } else if ((f & 240) === 224) {
            var c = i[r++] & 63, a = i[r++] & 63;
            n.push((f & 31) << 12 | c << 6 | a);
        } else if ((f & 248) === 240) {
            var c = i[r++] & 63, a = i[r++] & 63, h = i[r++] & 63, d = (f & 7) << 18 | c << 12 | a << 6 | h;
            d > 65535 && (d -= 65536, n.push(d >>> 10 & 1023 | 55296), d = 56320 | d & 1023), n.push(d);
        } else n.push(f);
        n.length >= fe && (o += String.fromCharCode.apply(String, n), n.length = 0);
    }
    return n.length > 0 && (o += String.fromCharCode.apply(String, n)), o;
}
var ce = M1 ? new TextDecoder : null, K1 = M1 ? typeof __default < "u" && ((R = __default?.env) === null || R === void 0 ? void 0 : R.TEXT_DECODER) !== "force" ? 200 : 0 : v;
function Y1(i, e, t) {
    var r = i.subarray(e, e + t);
    return ce.decode(r);
}
var g = function() {
    function i(e, t) {
        this.type = e, this.data = t;
    }
    return i;
}();
var he = function() {
    var i = function(e, t) {
        return i = Object.setPrototypeOf || ({
            __proto__: []
        }) instanceof Array && function(r, s) {
            r.__proto__ = s;
        } || function(r, s) {
            for(var n in s)Object.prototype.hasOwnProperty.call(s, n) && (r[n] = s[n]);
        }, i(e, t);
    };
    return function(e, t) {
        if (typeof t != "function" && t !== null) throw new TypeError("Class extends value " + String(t) + " is not a constructor or null");
        i(e, t);
        function r() {
            this.constructor = e;
        }
        e.prototype = t === null ? Object.create(t) : (r.prototype = t.prototype, new r);
    };
}(), x = function(i) {
    he(e, i);
    function e(t) {
        var r = i.call(this, t) || this, s = Object.create(e.prototype);
        return Object.setPrototypeOf(r, s), Object.defineProperty(r, "name", {
            configurable: !0,
            enumerable: !1,
            value: e.name
        }), r;
    }
    return e;
}(Error);
var J = -1, ue = 4294967296 - 1, le = 17179869184 - 1;
function q(i) {
    var e = i.sec, t = i.nsec;
    if (e >= 0 && t >= 0 && e <= le) if (t === 0 && e <= ue) {
        var r = new Uint8Array(4), s = new DataView(r.buffer);
        return s.setUint32(0, e), r;
    } else {
        var n = e / 4294967296, o = e & 4294967295, r = new Uint8Array(8), s = new DataView(r.buffer);
        return s.setUint32(0, t << 2 | n & 3), s.setUint32(4, o), r;
    }
    else {
        var r = new Uint8Array(12), s = new DataView(r.buffer);
        return s.setUint32(0, t), A(s, 4, e), r;
    }
}
function Z1(i) {
    var e = i.getTime(), t = Math.floor(e / 1e3), r = (e - t * 1e3) * 1e6, s = Math.floor(r / 1e9);
    return {
        sec: t + s,
        nsec: r - s * 1e9
    };
}
function Q1(i) {
    if (i instanceof Date) {
        var e = Z1(i);
        return q(e);
    } else return null;
}
function $1(i) {
    var e = new DataView(i.buffer, i.byteOffset, i.byteLength);
    switch(i.byteLength){
        case 4:
            {
                var t = e.getUint32(0), r = 0;
                return {
                    sec: t,
                    nsec: r
                };
            }
        case 8:
            {
                var s = e.getUint32(0), n = e.getUint32(4), t = (s & 3) * 4294967296 + n, r = s >>> 2;
                return {
                    sec: t,
                    nsec: r
                };
            }
        case 12:
            {
                var t = D1(e, 4), r = e.getUint32(0);
                return {
                    sec: t,
                    nsec: r
                };
            }
        default:
            throw new x("Unrecognized data size for timestamp (expected 4, 8, or 12): ".concat(i.length));
    }
}
function j(i) {
    var e = $1(i);
    return new Date(e.sec * 1e3 + e.nsec / 1e6);
}
var ee = {
    type: J,
    encode: Q1,
    decode: j
};
var I1 = function() {
    function i() {
        this.builtInEncoders = [], this.builtInDecoders = [], this.encoders = [], this.decoders = [], this.register(ee);
    }
    return i.prototype.register = function(e) {
        var t = e.type, r = e.encode, s = e.decode;
        if (t >= 0) this.encoders[t] = r, this.decoders[t] = s;
        else {
            var n = 1 + t;
            this.builtInEncoders[n] = r, this.builtInDecoders[n] = s;
        }
    }, i.prototype.tryToEncode = function(e, t) {
        for(var r = 0; r < this.builtInEncoders.length; r++){
            var s = this.builtInEncoders[r];
            if (s != null) {
                var n = s(e, t);
                if (n != null) {
                    var o = -1 - r;
                    return new g(o, n);
                }
            }
        }
        for(var r = 0; r < this.encoders.length; r++){
            var s = this.encoders[r];
            if (s != null) {
                var n = s(e, t);
                if (n != null) {
                    var o = r;
                    return new g(o, n);
                }
            }
        }
        return e instanceof g ? e : null;
    }, i.prototype.decode = function(e, t, r) {
        var s = t < 0 ? this.builtInDecoders[-1 - t] : this.decoders[t];
        return s ? s(e, t, r) : new g(t, e);
    }, i.defaultCodec = new i, i;
}();
function E(i) {
    return i instanceof Uint8Array ? i : ArrayBuffer.isView(i) ? new Uint8Array(i.buffer, i.byteOffset, i.byteLength) : i instanceof ArrayBuffer ? new Uint8Array(i) : Uint8Array.from(i);
}
function te(i) {
    if (i instanceof ArrayBuffer) return new DataView(i);
    var e = E(i);
    return new DataView(e.buffer, e.byteOffset, e.byteLength);
}
var de = 100, pe = 2048, P1 = function() {
    function i(e, t, r, s, n, o, f, c) {
        e === void 0 && (e = I1.defaultCodec), t === void 0 && (t = void 0), r === void 0 && (r = de), s === void 0 && (s = pe), n === void 0 && (n = !1), o === void 0 && (o = !1), f === void 0 && (f = !1), c === void 0 && (c = !1), this.extensionCodec = e, this.context = t, this.maxDepth = r, this.initialBufferSize = s, this.sortKeys = n, this.forceFloat32 = o, this.ignoreUndefined = f, this.forceIntegerToFloat = c, this.pos = 0, this.view = new DataView(new ArrayBuffer(this.initialBufferSize)), this.bytes = new Uint8Array(this.view.buffer);
    }
    return i.prototype.reinitializeState = function() {
        this.pos = 0;
    }, i.prototype.encodeSharedRef = function(e) {
        return this.reinitializeState(), this.doEncode(e, 1), this.bytes.subarray(0, this.pos);
    }, i.prototype.encode = function(e) {
        return this.reinitializeState(), this.doEncode(e, 1), this.bytes.slice(0, this.pos);
    }, i.prototype.doEncode = function(e, t) {
        if (t > this.maxDepth) throw new Error("Too deep objects in depth ".concat(t));
        e == null ? this.encodeNil() : typeof e == "boolean" ? this.encodeBoolean(e) : typeof e == "number" ? this.encodeNumber(e) : typeof e == "string" ? this.encodeString(e) : this.encodeObject(e, t);
    }, i.prototype.ensureBufferSizeToWrite = function(e) {
        var t = this.pos + e;
        this.view.byteLength < t && this.resizeBuffer(t * 2);
    }, i.prototype.resizeBuffer = function(e) {
        var t = new ArrayBuffer(e), r = new Uint8Array(t), s = new DataView(t);
        r.set(this.bytes), this.view = s, this.bytes = r;
    }, i.prototype.encodeNil = function() {
        this.writeU8(192);
    }, i.prototype.encodeBoolean = function(e) {
        e === !1 ? this.writeU8(194) : this.writeU8(195);
    }, i.prototype.encodeNumber = function(e) {
        Number.isSafeInteger(e) && !this.forceIntegerToFloat ? e >= 0 ? e < 128 ? this.writeU8(e) : e < 256 ? (this.writeU8(204), this.writeU8(e)) : e < 65536 ? (this.writeU8(205), this.writeU16(e)) : e < 4294967296 ? (this.writeU8(206), this.writeU32(e)) : (this.writeU8(207), this.writeU64(e)) : e >= -32 ? this.writeU8(224 | e + 32) : e >= -128 ? (this.writeU8(208), this.writeI8(e)) : e >= -32768 ? (this.writeU8(209), this.writeI16(e)) : e >= -2147483648 ? (this.writeU8(210), this.writeI32(e)) : (this.writeU8(211), this.writeI64(e)) : this.forceFloat32 ? (this.writeU8(202), this.writeF32(e)) : (this.writeU8(203), this.writeF64(e));
    }, i.prototype.writeStringHeader = function(e) {
        if (e < 32) this.writeU8(160 + e);
        else if (e < 256) this.writeU8(217), this.writeU8(e);
        else if (e < 65536) this.writeU8(218), this.writeU16(e);
        else if (e < 4294967296) this.writeU8(219), this.writeU32(e);
        else throw new Error("Too long string: ".concat(e, " bytes in UTF-8"));
    }, i.prototype.encodeString = function(e) {
        var t = 5, r = e.length;
        if (r > W1) {
            var s = F1(e);
            this.ensureBufferSizeToWrite(t + s), this.writeStringHeader(s), G(e, this.bytes, this.pos), this.pos += s;
        } else {
            var s = F1(e);
            this.ensureBufferSizeToWrite(t + s), this.writeStringHeader(s), X1(e, this.bytes, this.pos), this.pos += s;
        }
    }, i.prototype.encodeObject = function(e, t) {
        var r = this.extensionCodec.tryToEncode(e, this.context);
        if (r != null) this.encodeExtension(r);
        else if (Array.isArray(e)) this.encodeArray(e, t);
        else if (ArrayBuffer.isView(e)) this.encodeBinary(e);
        else if (typeof e == "object") this.encodeMap(e, t);
        else throw new Error("Unrecognized object: ".concat(Object.prototype.toString.apply(e)));
    }, i.prototype.encodeBinary = function(e) {
        var t = e.byteLength;
        if (t < 256) this.writeU8(196), this.writeU8(t);
        else if (t < 65536) this.writeU8(197), this.writeU16(t);
        else if (t < 4294967296) this.writeU8(198), this.writeU32(t);
        else throw new Error("Too large binary: ".concat(t));
        var r = E(e);
        this.writeU8a(r);
    }, i.prototype.encodeArray = function(e, t) {
        var r = e.length;
        if (r < 16) this.writeU8(144 + r);
        else if (r < 65536) this.writeU8(220), this.writeU16(r);
        else if (r < 4294967296) this.writeU8(221), this.writeU32(r);
        else throw new Error("Too large array: ".concat(r));
        for(var s = 0, n = e; s < n.length; s++){
            var o = n[s];
            this.doEncode(o, t + 1);
        }
    }, i.prototype.countWithoutUndefined = function(e, t) {
        for(var r = 0, s = 0, n = t; s < n.length; s++){
            var o = n[s];
            e[o] !== void 0 && r++;
        }
        return r;
    }, i.prototype.encodeMap = function(e, t) {
        var r = Object.keys(e);
        this.sortKeys && r.sort();
        var s = this.ignoreUndefined ? this.countWithoutUndefined(e, r) : r.length;
        if (s < 16) this.writeU8(128 + s);
        else if (s < 65536) this.writeU8(222), this.writeU16(s);
        else if (s < 4294967296) this.writeU8(223), this.writeU32(s);
        else throw new Error("Too large map object: ".concat(s));
        for(var n = 0, o = r; n < o.length; n++){
            var f = o[n], c = e[f];
            this.ignoreUndefined && c === void 0 || (this.encodeString(f), this.doEncode(c, t + 1));
        }
    }, i.prototype.encodeExtension = function(e) {
        var t = e.data.length;
        if (t === 1) this.writeU8(212);
        else if (t === 2) this.writeU8(213);
        else if (t === 4) this.writeU8(214);
        else if (t === 8) this.writeU8(215);
        else if (t === 16) this.writeU8(216);
        else if (t < 256) this.writeU8(199), this.writeU8(t);
        else if (t < 65536) this.writeU8(200), this.writeU16(t);
        else if (t < 4294967296) this.writeU8(201), this.writeU32(t);
        else throw new Error("Too large extension object: ".concat(t));
        this.writeI8(e.type), this.writeU8a(e.data);
    }, i.prototype.writeU8 = function(e) {
        this.ensureBufferSizeToWrite(1), this.view.setUint8(this.pos, e), this.pos++;
    }, i.prototype.writeU8a = function(e) {
        var t = e.length;
        this.ensureBufferSizeToWrite(t), this.bytes.set(e, this.pos), this.pos += t;
    }, i.prototype.writeI8 = function(e) {
        this.ensureBufferSizeToWrite(1), this.view.setInt8(this.pos, e), this.pos++;
    }, i.prototype.writeU16 = function(e) {
        this.ensureBufferSizeToWrite(2), this.view.setUint16(this.pos, e), this.pos += 2;
    }, i.prototype.writeI16 = function(e) {
        this.ensureBufferSizeToWrite(2), this.view.setInt16(this.pos, e), this.pos += 2;
    }, i.prototype.writeU32 = function(e) {
        this.ensureBufferSizeToWrite(4), this.view.setUint32(this.pos, e), this.pos += 4;
    }, i.prototype.writeI32 = function(e) {
        this.ensureBufferSizeToWrite(4), this.view.setInt32(this.pos, e), this.pos += 4;
    }, i.prototype.writeF32 = function(e) {
        this.ensureBufferSizeToWrite(4), this.view.setFloat32(this.pos, e), this.pos += 4;
    }, i.prototype.writeF64 = function(e) {
        this.ensureBufferSizeToWrite(8), this.view.setFloat64(this.pos, e), this.pos += 8;
    }, i.prototype.writeU64 = function(e) {
        this.ensureBufferSizeToWrite(8), H(this.view, this.pos, e), this.pos += 8;
    }, i.prototype.writeI64 = function(e) {
        this.ensureBufferSizeToWrite(8), A(this.view, this.pos, e), this.pos += 8;
    }, i;
}();
var xe = {};
function ve(i, e) {
    e === void 0 && (e = xe);
    var t = new P1(e.extensionCodec, e.context, e.maxDepth, e.initialBufferSize, e.sortKeys, e.forceFloat32, e.ignoreUndefined, e.forceIntegerToFloat);
    return t.encodeSharedRef(i);
}
function z(i) {
    return "".concat(i < 0 ? "-" : "", "0x").concat(Math.abs(i).toString(16).padStart(2, "0"));
}
var we = 16, ye = 16, re = function() {
    function i(e, t) {
        e === void 0 && (e = we), t === void 0 && (t = ye), this.maxKeyLength = e, this.maxLengthPerKey = t, this.hit = 0, this.miss = 0, this.caches = [];
        for(var r = 0; r < this.maxKeyLength; r++)this.caches.push([]);
    }
    return i.prototype.canBeCached = function(e) {
        return e > 0 && e <= this.maxKeyLength;
    }, i.prototype.find = function(e, t, r) {
        var s = this.caches[r - 1];
        e: for(var n = 0, o = s; n < o.length; n++){
            for(var f = o[n], c = f.bytes, a = 0; a < r; a++)if (c[a] !== e[t + a]) continue e;
            return f.str;
        }
        return null;
    }, i.prototype.store = function(e, t) {
        var r = this.caches[e.length - 1], s = {
            bytes: e,
            str: t
        };
        r.length >= this.maxLengthPerKey ? r[Math.random() * r.length | 0] = s : r.push(s);
    }, i.prototype.decode = function(e, t, r) {
        var s = this.find(e, t, r);
        if (s != null) return this.hit++, s;
        this.miss++;
        var n = C(e, t, r), o = Uint8Array.prototype.slice.call(e, t, t + r);
        return this.store(o, n), n;
    }, i;
}();
var me = function(i, e, t, r) {
    function s(n) {
        return n instanceof t ? n : new t(function(o) {
            o(n);
        });
    }
    return new (t || (t = Promise))(function(n, o) {
        function f(h) {
            try {
                a(r.next(h));
            } catch (d) {
                o(d);
            }
        }
        function c(h) {
            try {
                a(r.throw(h));
            } catch (d) {
                o(d);
            }
        }
        function a(h) {
            h.done ? n(h.value) : s(h.value).then(f, c);
        }
        a((r = r.apply(i, e || [])).next());
    });
}, V1 = function(i, e) {
    var t = {
        label: 0,
        sent: function() {
            if (n[0] & 1) throw n[1];
            return n[1];
        },
        trys: [],
        ops: []
    }, r, s, n, o;
    return o = {
        next: f(0),
        throw: f(1),
        return: f(2)
    }, typeof Symbol == "function" && (o[Symbol.iterator] = function() {
        return this;
    }), o;
    function f(a) {
        return function(h) {
            return c([
                a,
                h
            ]);
        };
    }
    function c(a) {
        if (r) throw new TypeError("Generator is already executing.");
        for(; t;)try {
            if (r = 1, s && (n = a[0] & 2 ? s.return : a[0] ? s.throw || ((n = s.return) && n.call(s), 0) : s.next) && !(n = n.call(s, a[1])).done) return n;
            switch(s = 0, n && (a = [
                a[0] & 2,
                n.value
            ]), a[0]){
                case 0:
                case 1:
                    n = a;
                    break;
                case 4:
                    return t.label++, {
                        value: a[1],
                        done: !1
                    };
                case 5:
                    t.label++, s = a[1], a = [
                        0
                    ];
                    continue;
                case 7:
                    a = t.ops.pop(), t.trys.pop();
                    continue;
                default:
                    if (n = t.trys, !(n = n.length > 0 && n[n.length - 1]) && (a[0] === 6 || a[0] === 2)) {
                        t = 0;
                        continue;
                    }
                    if (a[0] === 3 && (!n || a[1] > n[0] && a[1] < n[3])) {
                        t.label = a[1];
                        break;
                    }
                    if (a[0] === 6 && t.label < n[1]) {
                        t.label = n[1], n = a;
                        break;
                    }
                    if (n && t.label < n[2]) {
                        t.label = n[2], t.ops.push(a);
                        break;
                    }
                    n[2] && t.ops.pop(), t.trys.pop();
                    continue;
            }
            a = e.call(i, t);
        } catch (h) {
            a = [
                6,
                h
            ], s = 0;
        } finally{
            r = n = 0;
        }
        if (a[0] & 5) throw a[1];
        return {
            value: a[0] ? a[1] : void 0,
            done: !0
        };
    }
}, ie = function(i) {
    if (!Symbol.asyncIterator) throw new TypeError("Symbol.asyncIterator is not defined.");
    var e = i[Symbol.asyncIterator], t;
    return e ? e.call(i) : (i = typeof __values == "function" ? __values(i) : i[Symbol.iterator](), t = {}, r("next"), r("throw"), r("return"), t[Symbol.asyncIterator] = function() {
        return this;
    }, t);
    function r(n) {
        t[n] = i[n] && function(o) {
            return new Promise(function(f, c) {
                o = i[n](o), s(f, c, o.done, o.value);
            });
        };
    }
    function s(n, o, f, c) {
        Promise.resolve(c).then(function(a) {
            n({
                value: a,
                done: f
            });
        }, o);
    }
}, U = function(i) {
    return this instanceof U ? (this.v = i, this) : new U(i);
}, ge = function(i, e, t) {
    if (!Symbol.asyncIterator) throw new TypeError("Symbol.asyncIterator is not defined.");
    var r = t.apply(i, e || []), s, n = [];
    return s = {}, o("next"), o("throw"), o("return"), s[Symbol.asyncIterator] = function() {
        return this;
    }, s;
    function o(u) {
        r[u] && (s[u] = function(l) {
            return new Promise(function(p, m) {
                n.push([
                    u,
                    l,
                    p,
                    m
                ]) > 1 || f(u, l);
            });
        });
    }
    function f(u, l) {
        try {
            c(r[u](l));
        } catch (p) {
            d(n[0][3], p);
        }
    }
    function c(u) {
        u.value instanceof U ? Promise.resolve(u.value.v).then(a, h) : d(n[0][2], u);
    }
    function a(u) {
        f("next", u);
    }
    function h(u) {
        f("throw", u);
    }
    function d(u, l) {
        u(l), n.shift(), n.length && f(n[0][0], n[0][1]);
    }
}, Ee = function(i) {
    var e = typeof i;
    return e === "string" || e === "number";
}, _ = -1, N1 = new DataView(new ArrayBuffer(0)), Ue = new Uint8Array(N1.buffer), L = function() {
    try {
        N1.getInt8(0);
    } catch (i) {
        return i.constructor;
    }
    throw new Error("never reached");
}(), ne = new L("Insufficient data"), Se = new re, w = function() {
    function i(e, t, r, s, n, o, f, c) {
        e === void 0 && (e = I1.defaultCodec), t === void 0 && (t = void 0), r === void 0 && (r = v), s === void 0 && (s = v), n === void 0 && (n = v), o === void 0 && (o = v), f === void 0 && (f = v), c === void 0 && (c = Se), this.extensionCodec = e, this.context = t, this.maxStrLength = r, this.maxBinLength = s, this.maxArrayLength = n, this.maxMapLength = o, this.maxExtLength = f, this.keyDecoder = c, this.totalPos = 0, this.pos = 0, this.view = N1, this.bytes = Ue, this.headByte = _, this.stack = [];
    }
    return i.prototype.reinitializeState = function() {
        this.totalPos = 0, this.headByte = _, this.stack.length = 0;
    }, i.prototype.setBuffer = function(e) {
        this.bytes = E(e), this.view = te(this.bytes), this.pos = 0;
    }, i.prototype.appendBuffer = function(e) {
        if (this.headByte === _ && !this.hasRemaining(1)) this.setBuffer(e);
        else {
            var t = this.bytes.subarray(this.pos), r = E(e), s = new Uint8Array(t.length + r.length);
            s.set(t), s.set(r, t.length), this.setBuffer(s);
        }
    }, i.prototype.hasRemaining = function(e) {
        return this.view.byteLength - this.pos >= e;
    }, i.prototype.createExtraByteError = function(e) {
        var t = this, r = t.view, s = t.pos;
        return new RangeError("Extra ".concat(r.byteLength - s, " of ").concat(r.byteLength, " byte(s) found at buffer[").concat(e, "]"));
    }, i.prototype.decode = function(e) {
        this.reinitializeState(), this.setBuffer(e);
        var t = this.doDecodeSync();
        if (this.hasRemaining(1)) throw this.createExtraByteError(this.pos);
        return t;
    }, i.prototype.decodeMulti = function(e) {
        return V1(this, function(t) {
            switch(t.label){
                case 0:
                    this.reinitializeState(), this.setBuffer(e), t.label = 1;
                case 1:
                    return this.hasRemaining(1) ? [
                        4,
                        this.doDecodeSync()
                    ] : [
                        3,
                        3
                    ];
                case 2:
                    return t.sent(), [
                        3,
                        1
                    ];
                case 3:
                    return [
                        2
                    ];
            }
        });
    }, i.prototype.decodeAsync = function(e) {
        var t, r, s, n;
        return me(this, void 0, void 0, function() {
            var o, f, c, a, h, d, u, l;
            return V1(this, function(p) {
                switch(p.label){
                    case 0:
                        o = !1, p.label = 1;
                    case 1:
                        p.trys.push([
                            1,
                            6,
                            7,
                            12
                        ]), t = ie(e), p.label = 2;
                    case 2:
                        return [
                            4,
                            t.next()
                        ];
                    case 3:
                        if (r = p.sent(), !!r.done) return [
                            3,
                            5
                        ];
                        if (c = r.value, o) throw this.createExtraByteError(this.totalPos);
                        this.appendBuffer(c);
                        try {
                            f = this.doDecodeSync(), o = !0;
                        } catch (m) {
                            if (!(m instanceof L)) throw m;
                        }
                        this.totalPos += this.pos, p.label = 4;
                    case 4:
                        return [
                            3,
                            2
                        ];
                    case 5:
                        return [
                            3,
                            12
                        ];
                    case 6:
                        return a = p.sent(), s = {
                            error: a
                        }, [
                            3,
                            12
                        ];
                    case 7:
                        return p.trys.push([
                            7,
                            ,
                            10,
                            11
                        ]), r && !r.done && (n = t.return) ? [
                            4,
                            n.call(t)
                        ] : [
                            3,
                            9
                        ];
                    case 8:
                        p.sent(), p.label = 9;
                    case 9:
                        return [
                            3,
                            11
                        ];
                    case 10:
                        if (s) throw s.error;
                        return [
                            7
                        ];
                    case 11:
                        return [
                            7
                        ];
                    case 12:
                        if (o) {
                            if (this.hasRemaining(1)) throw this.createExtraByteError(this.totalPos);
                            return [
                                2,
                                f
                            ];
                        }
                        throw h = this, d = h.headByte, u = h.pos, l = h.totalPos, new RangeError("Insufficient data in parsing ".concat(z(d), " at ").concat(l, " (").concat(u, " in the current buffer)"));
                }
            });
        });
    }, i.prototype.decodeArrayStream = function(e) {
        return this.decodeMultiAsync(e, !0);
    }, i.prototype.decodeStream = function(e) {
        return this.decodeMultiAsync(e, !1);
    }, i.prototype.decodeMultiAsync = function(e, t) {
        return ge(this, arguments, function() {
            var s, n, o, f, c, a, h, d, u;
            return V1(this, function(l) {
                switch(l.label){
                    case 0:
                        s = t, n = -1, l.label = 1;
                    case 1:
                        l.trys.push([
                            1,
                            13,
                            14,
                            19
                        ]), o = ie(e), l.label = 2;
                    case 2:
                        return [
                            4,
                            U(o.next())
                        ];
                    case 3:
                        if (f = l.sent(), !!f.done) return [
                            3,
                            12
                        ];
                        if (c = f.value, t && n === 0) throw this.createExtraByteError(this.totalPos);
                        this.appendBuffer(c), s && (n = this.readArraySize(), s = !1, this.complete()), l.label = 4;
                    case 4:
                        l.trys.push([
                            4,
                            9,
                            ,
                            10
                        ]), l.label = 5;
                    case 5:
                        return [
                            4,
                            U(this.doDecodeSync())
                        ];
                    case 6:
                        return [
                            4,
                            l.sent()
                        ];
                    case 7:
                        return l.sent(), --n === 0 ? [
                            3,
                            8
                        ] : [
                            3,
                            5
                        ];
                    case 8:
                        return [
                            3,
                            10
                        ];
                    case 9:
                        if (a = l.sent(), !(a instanceof L)) throw a;
                        return [
                            3,
                            10
                        ];
                    case 10:
                        this.totalPos += this.pos, l.label = 11;
                    case 11:
                        return [
                            3,
                            2
                        ];
                    case 12:
                        return [
                            3,
                            19
                        ];
                    case 13:
                        return h = l.sent(), d = {
                            error: h
                        }, [
                            3,
                            19
                        ];
                    case 14:
                        return l.trys.push([
                            14,
                            ,
                            17,
                            18
                        ]), f && !f.done && (u = o.return) ? [
                            4,
                            U(u.call(o))
                        ] : [
                            3,
                            16
                        ];
                    case 15:
                        l.sent(), l.label = 16;
                    case 16:
                        return [
                            3,
                            18
                        ];
                    case 17:
                        if (d) throw d.error;
                        return [
                            7
                        ];
                    case 18:
                        return [
                            7
                        ];
                    case 19:
                        return [
                            2
                        ];
                }
            });
        });
    }, i.prototype.doDecodeSync = function() {
        e: for(;;){
            var e = this.readHeadByte(), t = void 0;
            if (e >= 224) t = e - 256;
            else if (e < 192) if (e < 128) t = e;
            else if (e < 144) {
                var r = e - 128;
                if (r !== 0) {
                    this.pushMapState(r), this.complete();
                    continue e;
                } else t = {};
            } else if (e < 160) {
                var r = e - 144;
                if (r !== 0) {
                    this.pushArrayState(r), this.complete();
                    continue e;
                } else t = [];
            } else {
                var s = e - 160;
                t = this.decodeUtf8String(s, 0);
            }
            else if (e === 192) t = null;
            else if (e === 194) t = !1;
            else if (e === 195) t = !0;
            else if (e === 202) t = this.readF32();
            else if (e === 203) t = this.readF64();
            else if (e === 204) t = this.readU8();
            else if (e === 205) t = this.readU16();
            else if (e === 206) t = this.readU32();
            else if (e === 207) t = this.readU64();
            else if (e === 208) t = this.readI8();
            else if (e === 209) t = this.readI16();
            else if (e === 210) t = this.readI32();
            else if (e === 211) t = this.readI64();
            else if (e === 217) {
                var s = this.lookU8();
                t = this.decodeUtf8String(s, 1);
            } else if (e === 218) {
                var s = this.lookU16();
                t = this.decodeUtf8String(s, 2);
            } else if (e === 219) {
                var s = this.lookU32();
                t = this.decodeUtf8String(s, 4);
            } else if (e === 220) {
                var r = this.readU16();
                if (r !== 0) {
                    this.pushArrayState(r), this.complete();
                    continue e;
                } else t = [];
            } else if (e === 221) {
                var r = this.readU32();
                if (r !== 0) {
                    this.pushArrayState(r), this.complete();
                    continue e;
                } else t = [];
            } else if (e === 222) {
                var r = this.readU16();
                if (r !== 0) {
                    this.pushMapState(r), this.complete();
                    continue e;
                } else t = {};
            } else if (e === 223) {
                var r = this.readU32();
                if (r !== 0) {
                    this.pushMapState(r), this.complete();
                    continue e;
                } else t = {};
            } else if (e === 196) {
                var r = this.lookU8();
                t = this.decodeBinary(r, 1);
            } else if (e === 197) {
                var r = this.lookU16();
                t = this.decodeBinary(r, 2);
            } else if (e === 198) {
                var r = this.lookU32();
                t = this.decodeBinary(r, 4);
            } else if (e === 212) t = this.decodeExtension(1, 0);
            else if (e === 213) t = this.decodeExtension(2, 0);
            else if (e === 214) t = this.decodeExtension(4, 0);
            else if (e === 215) t = this.decodeExtension(8, 0);
            else if (e === 216) t = this.decodeExtension(16, 0);
            else if (e === 199) {
                var r = this.lookU8();
                t = this.decodeExtension(r, 1);
            } else if (e === 200) {
                var r = this.lookU16();
                t = this.decodeExtension(r, 2);
            } else if (e === 201) {
                var r = this.lookU32();
                t = this.decodeExtension(r, 4);
            } else throw new x("Unrecognized type byte: ".concat(z(e)));
            this.complete();
            for(var n = this.stack; n.length > 0;){
                var o = n[n.length - 1];
                if (o.type === 0) if (o.array[o.position] = t, o.position++, o.position === o.size) n.pop(), t = o.array;
                else continue e;
                else if (o.type === 1) {
                    if (!Ee(t)) throw new x("The type of key must be string or number but " + typeof t);
                    if (t === "__proto__") throw new x("The key __proto__ is not allowed");
                    o.key = t, o.type = 2;
                    continue e;
                } else if (o.map[o.key] = t, o.readCount++, o.readCount === o.size) n.pop(), t = o.map;
                else {
                    o.key = null, o.type = 1;
                    continue e;
                }
            }
            return t;
        }
    }, i.prototype.readHeadByte = function() {
        return this.headByte === _ && (this.headByte = this.readU8()), this.headByte;
    }, i.prototype.complete = function() {
        this.headByte = _;
    }, i.prototype.readArraySize = function() {
        var e = this.readHeadByte();
        switch(e){
            case 220:
                return this.readU16();
            case 221:
                return this.readU32();
            default:
                {
                    if (e < 160) return e - 144;
                    throw new x("Unrecognized array type byte: ".concat(z(e)));
                }
        }
    }, i.prototype.pushMapState = function(e) {
        if (e > this.maxMapLength) throw new x("Max length exceeded: map length (".concat(e, ") > maxMapLengthLength (").concat(this.maxMapLength, ")"));
        this.stack.push({
            type: 1,
            size: e,
            key: null,
            readCount: 0,
            map: {}
        });
    }, i.prototype.pushArrayState = function(e) {
        if (e > this.maxArrayLength) throw new x("Max length exceeded: array length (".concat(e, ") > maxArrayLength (").concat(this.maxArrayLength, ")"));
        this.stack.push({
            type: 0,
            size: e,
            array: new Array(e),
            position: 0
        });
    }, i.prototype.decodeUtf8String = function(e, t) {
        var r;
        if (e > this.maxStrLength) throw new x("Max length exceeded: UTF-8 byte length (".concat(e, ") > maxStrLength (").concat(this.maxStrLength, ")"));
        if (this.bytes.byteLength < this.pos + t + e) throw ne;
        var s = this.pos + t, n;
        return this.stateIsMapKey() && ((r = this.keyDecoder) === null || r === void 0 ? void 0 : r.canBeCached(e)) ? n = this.keyDecoder.decode(this.bytes, s, e) : e > K1 ? n = Y1(this.bytes, s, e) : n = C(this.bytes, s, e), this.pos += t + e, n;
    }, i.prototype.stateIsMapKey = function() {
        if (this.stack.length > 0) {
            var e = this.stack[this.stack.length - 1];
            return e.type === 1;
        }
        return !1;
    }, i.prototype.decodeBinary = function(e, t) {
        if (e > this.maxBinLength) throw new x("Max length exceeded: bin length (".concat(e, ") > maxBinLength (").concat(this.maxBinLength, ")"));
        if (!this.hasRemaining(e + t)) throw ne;
        var r = this.pos + t, s = this.bytes.subarray(r, r + e);
        return this.pos += t + e, s;
    }, i.prototype.decodeExtension = function(e, t) {
        if (e > this.maxExtLength) throw new x("Max length exceeded: ext length (".concat(e, ") > maxExtLength (").concat(this.maxExtLength, ")"));
        var r = this.view.getInt8(this.pos + t), s = this.decodeBinary(e, t + 1);
        return this.extensionCodec.decode(s, r, this.context);
    }, i.prototype.lookU8 = function() {
        return this.view.getUint8(this.pos);
    }, i.prototype.lookU16 = function() {
        return this.view.getUint16(this.pos);
    }, i.prototype.lookU32 = function() {
        return this.view.getUint32(this.pos);
    }, i.prototype.readU8 = function() {
        var e = this.view.getUint8(this.pos);
        return this.pos++, e;
    }, i.prototype.readI8 = function() {
        var e = this.view.getInt8(this.pos);
        return this.pos++, e;
    }, i.prototype.readU16 = function() {
        var e = this.view.getUint16(this.pos);
        return this.pos += 2, e;
    }, i.prototype.readI16 = function() {
        var e = this.view.getInt16(this.pos);
        return this.pos += 2, e;
    }, i.prototype.readU32 = function() {
        var e = this.view.getUint32(this.pos);
        return this.pos += 4, e;
    }, i.prototype.readI32 = function() {
        var e = this.view.getInt32(this.pos);
        return this.pos += 4, e;
    }, i.prototype.readU64 = function() {
        var e = b(this.view, this.pos);
        return this.pos += 8, e;
    }, i.prototype.readI64 = function() {
        var e = D1(this.view, this.pos);
        return this.pos += 8, e;
    }, i.prototype.readF32 = function() {
        var e = this.view.getFloat32(this.pos);
        return this.pos += 4, e;
    }, i.prototype.readF64 = function() {
        var e = this.view.getFloat64(this.pos);
        return this.pos += 8, e;
    }, i;
}();
var y1 = {};
function Te(i, e) {
    e === void 0 && (e = y1);
    var t = new w(e.extensionCodec, e.context, e.maxStrLength, e.maxBinLength, e.maxArrayLength, e.maxMapLength, e.maxExtLength);
    return t.decode(i);
}
var S = function(i) {
    return this instanceof S ? (this.v = i, this) : new S(i);
};
var Mi = 4, xt = 0, kt = 1, Fi = 2;
function _e(e) {
    let i = e.length;
    for(; --i >= 0;)e[i] = 0;
}
var Hi = 0, li = 1, Bi = 2, Ki = 3, Pi = 258, dt = 29, Ae = 256, ge1 = Ae + 1 + dt, oe1 = 30, st = 19, ri = 2 * ge1 + 1, Q2 = 15, Ge = 16, Xi = 7, ct = 256, fi = 16, oi = 17, _i = 18, ft = new Uint8Array([
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    1,
    1,
    1,
    1,
    2,
    2,
    2,
    2,
    3,
    3,
    3,
    3,
    4,
    4,
    4,
    4,
    5,
    5,
    5,
    5,
    0
]), Ce = new Uint8Array([
    0,
    0,
    0,
    0,
    1,
    1,
    2,
    2,
    3,
    3,
    4,
    4,
    5,
    5,
    6,
    6,
    7,
    7,
    8,
    8,
    9,
    9,
    10,
    10,
    11,
    11,
    12,
    12,
    13,
    13
]), Yi = new Uint8Array([
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    2,
    3,
    7
]), hi = new Uint8Array([
    16,
    17,
    18,
    0,
    8,
    7,
    9,
    6,
    10,
    5,
    11,
    4,
    12,
    3,
    13,
    2,
    14,
    1,
    15
]), Gi = 512, B1 = new Array((ge1 + 2) * 2);
_e(B1);
var ue1 = new Array(oe1 * 2);
_e(ue1);
var pe1 = new Array(Gi);
_e(pe1);
var xe1 = new Array(Pi - Ki + 1);
_e(xe1);
var ut = new Array(dt);
_e(ut);
var He = new Array(oe1);
_e(He);
function je(e, i, t, n, a) {
    this.static_tree = e, this.extra_bits = i, this.extra_base = t, this.elems = n, this.max_length = a, this.has_stree = e && e.length;
}
var di, si, ci;
function We(e, i) {
    this.dyn_tree = e, this.max_code = 0, this.stat_desc = i;
}
var ui = (e)=>e < 256 ? pe1[e] : pe1[256 + (e >>> 7)], ke = (e, i)=>{
    e.pending_buf[e.pending++] = i & 255, e.pending_buf[e.pending++] = i >>> 8 & 255;
}, N2 = (e, i, t)=>{
    e.bi_valid > Ge - t ? (e.bi_buf |= i << e.bi_valid & 65535, ke(e, e.bi_buf), e.bi_buf = i >> Ge - e.bi_valid, e.bi_valid += t - Ge) : (e.bi_buf |= i << e.bi_valid & 65535, e.bi_valid += t);
}, M2 = (e, i, t)=>{
    N2(e, t[i * 2], t[i * 2 + 1]);
}, bi = (e, i)=>{
    let t = 0;
    do t |= e & 1, e >>>= 1, t <<= 1;
    while (--i > 0)
    return t >>> 1;
}, ji = (e)=>{
    e.bi_valid === 16 ? (ke(e, e.bi_buf), e.bi_buf = 0, e.bi_valid = 0) : e.bi_valid >= 8 && (e.pending_buf[e.pending++] = e.bi_buf & 255, e.bi_buf >>= 8, e.bi_valid -= 8);
}, Wi = (e, i)=>{
    let t = i.dyn_tree, n = i.max_code, a = i.stat_desc.static_tree, l = i.stat_desc.has_stree, o = i.stat_desc.extra_bits, f = i.stat_desc.extra_base, c = i.stat_desc.max_length, r, _, E, s, h, u, m = 0;
    for(s = 0; s <= Q2; s++)e.bl_count[s] = 0;
    for(t[e.heap[e.heap_max] * 2 + 1] = 0, r = e.heap_max + 1; r < ri; r++)_ = e.heap[r], s = t[t[_ * 2 + 1] * 2 + 1] + 1, s > c && (s = c, m++), t[_ * 2 + 1] = s, !(_ > n) && (e.bl_count[s]++, h = 0, _ >= f && (h = o[_ - f]), u = t[_ * 2], e.opt_len += u * (s + h), l && (e.static_len += u * (a[_ * 2 + 1] + h)));
    if (m !== 0) {
        do {
            for(s = c - 1; e.bl_count[s] === 0;)s--;
            e.bl_count[s]--, e.bl_count[s + 1] += 2, e.bl_count[c]--, m -= 2;
        }while (m > 0)
        for(s = c; s !== 0; s--)for(_ = e.bl_count[s]; _ !== 0;)E = e.heap[--r], !(E > n) && (t[E * 2 + 1] !== s && (e.opt_len += (s - t[E * 2 + 1]) * t[E * 2], t[E * 2 + 1] = s), _--);
    }
}, wi = (e, i, t)=>{
    let n = new Array(Q2 + 1), a = 0, l, o;
    for(l = 1; l <= Q2; l++)n[l] = a = a + t[l - 1] << 1;
    for(o = 0; o <= i; o++){
        let f = e[o * 2 + 1];
        f !== 0 && (e[o * 2] = bi(n[f]++, f));
    }
}, Vi = ()=>{
    let e, i, t, n, a, l = new Array(Q2 + 1);
    for(t = 0, n = 0; n < dt - 1; n++)for(ut[n] = t, e = 0; e < 1 << ft[n]; e++)xe1[t++] = n;
    for(xe1[t - 1] = n, a = 0, n = 0; n < 16; n++)for(He[n] = a, e = 0; e < 1 << Ce[n]; e++)pe1[a++] = n;
    for(a >>= 7; n < oe1; n++)for(He[n] = a << 7, e = 0; e < 1 << Ce[n] - 7; e++)pe1[256 + a++] = n;
    for(i = 0; i <= Q2; i++)l[i] = 0;
    for(e = 0; e <= 143;)B1[e * 2 + 1] = 8, e++, l[8]++;
    for(; e <= 255;)B1[e * 2 + 1] = 9, e++, l[9]++;
    for(; e <= 279;)B1[e * 2 + 1] = 7, e++, l[7]++;
    for(; e <= 287;)B1[e * 2 + 1] = 8, e++, l[8]++;
    for(wi(B1, ge1 + 1, l), e = 0; e < oe1; e++)ue1[e * 2 + 1] = 5, ue1[e * 2] = bi(e, 5);
    di = new je(B1, ft, Ae + 1, ge1, Q2), si = new je(ue1, Ce, 0, oe1, Q2), ci = new je(new Array(0), Yi, 0, st, Xi);
}, gi = (e)=>{
    let i;
    for(i = 0; i < ge1; i++)e.dyn_ltree[i * 2] = 0;
    for(i = 0; i < oe1; i++)e.dyn_dtree[i * 2] = 0;
    for(i = 0; i < st; i++)e.bl_tree[i * 2] = 0;
    e.dyn_ltree[ct * 2] = 1, e.opt_len = e.static_len = 0, e.last_lit = e.matches = 0;
}, pi = (e)=>{
    e.bi_valid > 8 ? ke(e, e.bi_buf) : e.bi_valid > 0 && (e.pending_buf[e.pending++] = e.bi_buf), e.bi_buf = 0, e.bi_valid = 0;
}, Ji = (e, i, t, n)=>{
    pi(e), n && (ke(e, t), ke(e, ~t)), e.pending_buf.set(e.window.subarray(i, i + t), e.pending), e.pending += t;
}, vt = (e, i, t, n)=>{
    let a = i * 2, l = t * 2;
    return e[a] < e[l] || e[a] === e[l] && n[i] <= n[t];
}, Ve = (e, i, t)=>{
    let n = e.heap[t], a = t << 1;
    for(; a <= e.heap_len && (a < e.heap_len && vt(i, e.heap[a + 1], e.heap[a], e.depth) && a++, !vt(i, n, e.heap[a], e.depth));)e.heap[t] = e.heap[a], t = a, a <<= 1;
    e.heap[t] = n;
}, Et = (e, i, t)=>{
    let n, a, l = 0, o, f;
    if (e.last_lit !== 0) do n = e.pending_buf[e.d_buf + l * 2] << 8 | e.pending_buf[e.d_buf + l * 2 + 1], a = e.pending_buf[e.l_buf + l], l++, n === 0 ? M2(e, a, i) : (o = xe1[a], M2(e, o + Ae + 1, i), f = ft[o], f !== 0 && (a -= ut[o], N2(e, a, f)), n--, o = ui(n), M2(e, o, t), f = Ce[o], f !== 0 && (n -= He[o], N2(e, n, f)));
    while (l < e.last_lit)
    M2(e, ct, i);
}, ot = (e, i)=>{
    let t = i.dyn_tree, n = i.stat_desc.static_tree, a = i.stat_desc.has_stree, l = i.stat_desc.elems, o, f, c = -1, r;
    for(e.heap_len = 0, e.heap_max = ri, o = 0; o < l; o++)t[o * 2] !== 0 ? (e.heap[++e.heap_len] = c = o, e.depth[o] = 0) : t[o * 2 + 1] = 0;
    for(; e.heap_len < 2;)r = e.heap[++e.heap_len] = c < 2 ? ++c : 0, t[r * 2] = 1, e.depth[r] = 0, e.opt_len--, a && (e.static_len -= n[r * 2 + 1]);
    for(i.max_code = c, o = e.heap_len >> 1; o >= 1; o--)Ve(e, t, o);
    r = l;
    do o = e.heap[1], e.heap[1] = e.heap[e.heap_len--], Ve(e, t, 1), f = e.heap[1], e.heap[--e.heap_max] = o, e.heap[--e.heap_max] = f, t[r * 2] = t[o * 2] + t[f * 2], e.depth[r] = (e.depth[o] >= e.depth[f] ? e.depth[o] : e.depth[f]) + 1, t[o * 2 + 1] = t[f * 2 + 1] = r, e.heap[1] = r++, Ve(e, t, 1);
    while (e.heap_len >= 2)
    e.heap[--e.heap_max] = e.heap[1], Wi(e, i), wi(t, c, e.bl_count);
}, yt = (e, i, t)=>{
    let n, a = -1, l, o = i[0 * 2 + 1], f = 0, c = 7, r = 4;
    for(o === 0 && (c = 138, r = 3), i[(t + 1) * 2 + 1] = 65535, n = 0; n <= t; n++)l = o, o = i[(n + 1) * 2 + 1], !(++f < c && l === o) && (f < r ? e.bl_tree[l * 2] += f : l !== 0 ? (l !== a && e.bl_tree[l * 2]++, e.bl_tree[fi * 2]++) : f <= 10 ? e.bl_tree[oi * 2]++ : e.bl_tree[_i * 2]++, f = 0, a = l, o === 0 ? (c = 138, r = 3) : l === o ? (c = 6, r = 3) : (c = 7, r = 4));
}, St = (e, i, t)=>{
    let n, a = -1, l, o = i[0 * 2 + 1], f = 0, c = 7, r = 4;
    for(o === 0 && (c = 138, r = 3), n = 0; n <= t; n++)if (l = o, o = i[(n + 1) * 2 + 1], !(++f < c && l === o)) {
        if (f < r) do M2(e, l, e.bl_tree);
        while (--f !== 0)
        else l !== 0 ? (l !== a && (M2(e, l, e.bl_tree), f--), M2(e, fi, e.bl_tree), N2(e, f - 3, 2)) : f <= 10 ? (M2(e, oi, e.bl_tree), N2(e, f - 3, 3)) : (M2(e, _i, e.bl_tree), N2(e, f - 11, 7));
        f = 0, a = l, o === 0 ? (c = 138, r = 3) : l === o ? (c = 6, r = 3) : (c = 7, r = 4);
    }
}, Qi = (e)=>{
    let i;
    for(yt(e, e.dyn_ltree, e.l_desc.max_code), yt(e, e.dyn_dtree, e.d_desc.max_code), ot(e, e.bl_desc), i = st - 1; i >= 3 && e.bl_tree[hi[i] * 2 + 1] === 0; i--);
    return e.opt_len += 3 * (i + 1) + 5 + 5 + 4, i;
}, qi = (e, i, t, n)=>{
    let a;
    for(N2(e, i - 257, 5), N2(e, t - 1, 5), N2(e, n - 4, 4), a = 0; a < n; a++)N2(e, e.bl_tree[hi[a] * 2 + 1], 3);
    St(e, e.dyn_ltree, i - 1), St(e, e.dyn_dtree, t - 1);
}, ea = (e)=>{
    let i = 4093624447, t;
    for(t = 0; t <= 31; t++, i >>>= 1)if (i & 1 && e.dyn_ltree[t * 2] !== 0) return xt;
    if (e.dyn_ltree[9 * 2] !== 0 || e.dyn_ltree[10 * 2] !== 0 || e.dyn_ltree[13 * 2] !== 0) return kt;
    for(t = 32; t < Ae; t++)if (e.dyn_ltree[t * 2] !== 0) return kt;
    return xt;
}, At = !1, ta = (e)=>{
    At || (Vi(), At = !0), e.l_desc = new We(e.dyn_ltree, di), e.d_desc = new We(e.dyn_dtree, si), e.bl_desc = new We(e.bl_tree, ci), e.bi_buf = 0, e.bi_valid = 0, gi(e);
}, xi = (e, i, t, n)=>{
    N2(e, (Hi << 1) + (n ? 1 : 0), 3), Ji(e, i, t, !0);
}, ia = (e)=>{
    N2(e, li << 1, 3), M2(e, ct, B1), ji(e);
}, aa = (e, i, t, n)=>{
    let a, l, o = 0;
    e.level > 0 ? (e.strm.data_type === Fi && (e.strm.data_type = ea(e)), ot(e, e.l_desc), ot(e, e.d_desc), o = Qi(e), a = e.opt_len + 3 + 7 >>> 3, l = e.static_len + 3 + 7 >>> 3, l <= a && (a = l)) : a = l = t + 5, t + 4 <= a && i !== -1 ? xi(e, i, t, n) : e.strategy === Mi || l === a ? (N2(e, (li << 1) + (n ? 1 : 0), 3), Et(e, B1, ue1)) : (N2(e, (Bi << 1) + (n ? 1 : 0), 3), qi(e, e.l_desc.max_code + 1, e.d_desc.max_code + 1, o + 1), Et(e, e.dyn_ltree, e.dyn_dtree)), gi(e), n && pi(e);
}, na = (e, i, t)=>(e.pending_buf[e.d_buf + e.last_lit * 2] = i >>> 8 & 255, e.pending_buf[e.d_buf + e.last_lit * 2 + 1] = i & 255, e.pending_buf[e.l_buf + e.last_lit] = t & 255, e.last_lit++, i === 0 ? e.dyn_ltree[t * 2]++ : (e.matches++, i--, e.dyn_ltree[(xe1[t] + Ae + 1) * 2]++, e.dyn_dtree[ui(i) * 2]++), e.last_lit === e.lit_bufsize - 1), la = ta, ra = xi, fa = aa, oa = na, _a = ia, ha = {
    _tr_init: la,
    _tr_stored_block: ra,
    _tr_flush_block: fa,
    _tr_tally: oa,
    _tr_align: _a
}, da = (e, i, t, n)=>{
    let a = e & 65535 | 0, l = e >>> 16 & 65535 | 0, o = 0;
    for(; t !== 0;){
        o = t > 2e3 ? 2e3 : t, t -= o;
        do a = a + i[n++] | 0, l = l + a | 0;
        while (--o)
        a %= 65521, l %= 65521;
    }
    return a | l << 16 | 0;
}, ve1 = da, sa = ()=>{
    let e, i = [];
    for(var t = 0; t < 256; t++){
        e = t;
        for(var n = 0; n < 8; n++)e = e & 1 ? 3988292384 ^ e >>> 1 : e >>> 1;
        i[t] = e;
    }
    return i;
}, ca = new Uint32Array(sa()), ua = (e, i, t, n)=>{
    let a = ca, l = n + t;
    e ^= -1;
    for(let o = n; o < l; o++)e = e >>> 8 ^ a[(e ^ i[o]) & 255];
    return e ^ -1;
}, I2 = ua, ee1 = {
    2: "need dictionary",
    1: "stream end",
    0: "",
    "-1": "file error",
    "-2": "stream error",
    "-3": "data error",
    "-4": "insufficient memory",
    "-5": "buffer error",
    "-6": "incompatible version"
}, ne1 = {
    Z_NO_FLUSH: 0,
    Z_PARTIAL_FLUSH: 1,
    Z_SYNC_FLUSH: 2,
    Z_FULL_FLUSH: 3,
    Z_FINISH: 4,
    Z_BLOCK: 5,
    Z_TREES: 6,
    Z_OK: 0,
    Z_STREAM_END: 1,
    Z_NEED_DICT: 2,
    Z_ERRNO: -1,
    Z_STREAM_ERROR: -2,
    Z_DATA_ERROR: -3,
    Z_MEM_ERROR: -4,
    Z_BUF_ERROR: -5,
    Z_NO_COMPRESSION: 0,
    Z_BEST_SPEED: 1,
    Z_BEST_COMPRESSION: 9,
    Z_DEFAULT_COMPRESSION: -1,
    Z_FILTERED: 1,
    Z_HUFFMAN_ONLY: 2,
    Z_RLE: 3,
    Z_FIXED: 4,
    Z_DEFAULT_STRATEGY: 0,
    Z_BINARY: 0,
    Z_TEXT: 1,
    Z_UNKNOWN: 2,
    Z_DEFLATED: 8
}, { _tr_init: ba , _tr_stored_block: wa , _tr_flush_block: ga , _tr_tally: j1 , _tr_align: pa  } = ha, { Z_NO_FLUSH: le1 , Z_PARTIAL_FLUSH: xa , Z_FULL_FLUSH: ka , Z_FINISH: W2 , Z_BLOCK: Rt , Z_OK: F2 , Z_STREAM_END: zt , Z_STREAM_ERROR: L1 , Z_DATA_ERROR: va , Z_BUF_ERROR: Je , Z_DEFAULT_COMPRESSION: Ea , Z_FILTERED: ya , Z_HUFFMAN_ONLY: Ie , Z_RLE: Sa , Z_FIXED: Aa , Z_DEFAULT_STRATEGY: Ra , Z_UNKNOWN: za , Z_DEFLATED: Pe  } = ne1, Ta = 9, ma = 15, Da = 8, Za = 29, Ia = 256, _t = Ia + 1 + Za, Oa = 30, Na = 19, La = 2 * _t + 1, Ua = 15, k1 = 3, Y2 = 258, C1 = Y2 + k1 + 1, Ca = 32, Xe = 42, ht = 69, $e = 73, Me = 91, Fe = 103, q1 = 113, se = 666, D2 = 1, Re = 2, te1 = 3, he1 = 4, $a = 3, G1 = (e, i)=>(e.msg = ee1[i], i), Tt = (e)=>(e << 1) - (e > 4 ? 9 : 0), X2 = (e)=>{
    let i = e.length;
    for(; --i >= 0;)e[i] = 0;
}, Ma = (e, i, t)=>(i << e.hash_shift ^ t) & e.hash_mask, V2 = Ma, P2 = (e)=>{
    let i = e.state, t = i.pending;
    t > e.avail_out && (t = e.avail_out), t !== 0 && (e.output.set(i.pending_buf.subarray(i.pending_out, i.pending_out + t), e.next_out), e.next_out += t, i.pending_out += t, e.total_out += t, e.avail_out -= t, i.pending -= t, i.pending === 0 && (i.pending_out = 0));
}, O1 = (e, i)=>{
    ga(e, e.block_start >= 0 ? e.block_start : -1, e.strstart - e.block_start, i), e.block_start = e.strstart, P2(e.strm);
}, y2 = (e, i)=>{
    e.pending_buf[e.pending++] = i;
}, de1 = (e, i)=>{
    e.pending_buf[e.pending++] = i >>> 8 & 255, e.pending_buf[e.pending++] = i & 255;
}, Fa = (e, i, t, n)=>{
    let a = e.avail_in;
    return a > n && (a = n), a === 0 ? 0 : (e.avail_in -= a, i.set(e.input.subarray(e.next_in, e.next_in + a), t), e.state.wrap === 1 ? e.adler = ve1(e.adler, i, a, t) : e.state.wrap === 2 && (e.adler = I2(e.adler, i, a, t)), e.next_in += a, e.total_in += a, a);
}, ki = (e, i)=>{
    let t = e.max_chain_length, n = e.strstart, a, l, o = e.prev_length, f = e.nice_match, c = e.strstart > e.w_size - C1 ? e.strstart - (e.w_size - C1) : 0, r = e.window, _ = e.w_mask, E = e.prev, s = e.strstart + Y2, h = r[n + o - 1], u = r[n + o];
    e.prev_length >= e.good_match && (t >>= 2), f > e.lookahead && (f = e.lookahead);
    do if (a = i, !(r[a + o] !== u || r[a + o - 1] !== h || r[a] !== r[n] || r[++a] !== r[n + 1])) {
        n += 2, a++;
        do ;
        while (r[++n] === r[++a] && r[++n] === r[++a] && r[++n] === r[++a] && r[++n] === r[++a] && r[++n] === r[++a] && r[++n] === r[++a] && r[++n] === r[++a] && r[++n] === r[++a] && n < s)
        if (l = Y2 - (s - n), n = s - Y2, l > o) {
            if (e.match_start = i, o = l, l >= f) break;
            h = r[n + o - 1], u = r[n + o];
        }
    }
    while ((i = E[i & _]) > c && --t !== 0)
    return o <= e.lookahead ? o : e.lookahead;
}, ie1 = (e)=>{
    let i = e.w_size, t, n, a, l, o;
    do {
        if (l = e.window_size - e.lookahead - e.strstart, e.strstart >= i + (i - C1)) {
            e.window.set(e.window.subarray(i, i + i), 0), e.match_start -= i, e.strstart -= i, e.block_start -= i, n = e.hash_size, t = n;
            do a = e.head[--t], e.head[t] = a >= i ? a - i : 0;
            while (--n)
            n = i, t = n;
            do a = e.prev[--t], e.prev[t] = a >= i ? a - i : 0;
            while (--n)
            l += i;
        }
        if (e.strm.avail_in === 0) break;
        if (n = Fa(e.strm, e.window, e.strstart + e.lookahead, l), e.lookahead += n, e.lookahead + e.insert >= k1) for(o = e.strstart - e.insert, e.ins_h = e.window[o], e.ins_h = V2(e, e.ins_h, e.window[o + 1]); e.insert && (e.ins_h = V2(e, e.ins_h, e.window[o + k1 - 1]), e.prev[o & e.w_mask] = e.head[e.ins_h], e.head[e.ins_h] = o, o++, e.insert--, !(e.lookahead + e.insert < k1)););
    }while (e.lookahead < C1 && e.strm.avail_in !== 0)
}, Ha = (e, i)=>{
    let t = 65535;
    for(t > e.pending_buf_size - 5 && (t = e.pending_buf_size - 5);;){
        if (e.lookahead <= 1) {
            if (ie1(e), e.lookahead === 0 && i === le1) return D2;
            if (e.lookahead === 0) break;
        }
        e.strstart += e.lookahead, e.lookahead = 0;
        let n = e.block_start + t;
        if ((e.strstart === 0 || e.strstart >= n) && (e.lookahead = e.strstart - n, e.strstart = n, O1(e, !1), e.strm.avail_out === 0) || e.strstart - e.block_start >= e.w_size - C1 && (O1(e, !1), e.strm.avail_out === 0)) return D2;
    }
    return e.insert = 0, i === W2 ? (O1(e, !0), e.strm.avail_out === 0 ? te1 : he1) : (e.strstart > e.block_start && (O1(e, !1), e.strm.avail_out === 0), D2);
}, Qe = (e, i)=>{
    let t, n;
    for(;;){
        if (e.lookahead < C1) {
            if (ie1(e), e.lookahead < C1 && i === le1) return D2;
            if (e.lookahead === 0) break;
        }
        if (t = 0, e.lookahead >= k1 && (e.ins_h = V2(e, e.ins_h, e.window[e.strstart + k1 - 1]), t = e.prev[e.strstart & e.w_mask] = e.head[e.ins_h], e.head[e.ins_h] = e.strstart), t !== 0 && e.strstart - t <= e.w_size - C1 && (e.match_length = ki(e, t)), e.match_length >= k1) if (n = j1(e, e.strstart - e.match_start, e.match_length - k1), e.lookahead -= e.match_length, e.match_length <= e.max_lazy_match && e.lookahead >= k1) {
            e.match_length--;
            do e.strstart++, e.ins_h = V2(e, e.ins_h, e.window[e.strstart + k1 - 1]), t = e.prev[e.strstart & e.w_mask] = e.head[e.ins_h], e.head[e.ins_h] = e.strstart;
            while (--e.match_length !== 0)
            e.strstart++;
        } else e.strstart += e.match_length, e.match_length = 0, e.ins_h = e.window[e.strstart], e.ins_h = V2(e, e.ins_h, e.window[e.strstart + 1]);
        else n = j1(e, 0, e.window[e.strstart]), e.lookahead--, e.strstart++;
        if (n && (O1(e, !1), e.strm.avail_out === 0)) return D2;
    }
    return e.insert = e.strstart < k1 - 1 ? e.strstart : k1 - 1, i === W2 ? (O1(e, !0), e.strm.avail_out === 0 ? te1 : he1) : e.last_lit && (O1(e, !1), e.strm.avail_out === 0) ? D2 : Re;
}, re1 = (e, i)=>{
    let t, n, a;
    for(;;){
        if (e.lookahead < C1) {
            if (ie1(e), e.lookahead < C1 && i === le1) return D2;
            if (e.lookahead === 0) break;
        }
        if (t = 0, e.lookahead >= k1 && (e.ins_h = V2(e, e.ins_h, e.window[e.strstart + k1 - 1]), t = e.prev[e.strstart & e.w_mask] = e.head[e.ins_h], e.head[e.ins_h] = e.strstart), e.prev_length = e.match_length, e.prev_match = e.match_start, e.match_length = k1 - 1, t !== 0 && e.prev_length < e.max_lazy_match && e.strstart - t <= e.w_size - C1 && (e.match_length = ki(e, t), e.match_length <= 5 && (e.strategy === ya || e.match_length === k1 && e.strstart - e.match_start > 4096) && (e.match_length = k1 - 1)), e.prev_length >= k1 && e.match_length <= e.prev_length) {
            a = e.strstart + e.lookahead - k1, n = j1(e, e.strstart - 1 - e.prev_match, e.prev_length - k1), e.lookahead -= e.prev_length - 1, e.prev_length -= 2;
            do ++e.strstart <= a && (e.ins_h = V2(e, e.ins_h, e.window[e.strstart + k1 - 1]), t = e.prev[e.strstart & e.w_mask] = e.head[e.ins_h], e.head[e.ins_h] = e.strstart);
            while (--e.prev_length !== 0)
            if (e.match_available = 0, e.match_length = k1 - 1, e.strstart++, n && (O1(e, !1), e.strm.avail_out === 0)) return D2;
        } else if (e.match_available) {
            if (n = j1(e, 0, e.window[e.strstart - 1]), n && O1(e, !1), e.strstart++, e.lookahead--, e.strm.avail_out === 0) return D2;
        } else e.match_available = 1, e.strstart++, e.lookahead--;
    }
    return e.match_available && (n = j1(e, 0, e.window[e.strstart - 1]), e.match_available = 0), e.insert = e.strstart < k1 - 1 ? e.strstart : k1 - 1, i === W2 ? (O1(e, !0), e.strm.avail_out === 0 ? te1 : he1) : e.last_lit && (O1(e, !1), e.strm.avail_out === 0) ? D2 : Re;
}, Ba = (e, i)=>{
    let t, n, a, l, o = e.window;
    for(;;){
        if (e.lookahead <= Y2) {
            if (ie1(e), e.lookahead <= Y2 && i === le1) return D2;
            if (e.lookahead === 0) break;
        }
        if (e.match_length = 0, e.lookahead >= k1 && e.strstart > 0 && (a = e.strstart - 1, n = o[a], n === o[++a] && n === o[++a] && n === o[++a])) {
            l = e.strstart + Y2;
            do ;
            while (n === o[++a] && n === o[++a] && n === o[++a] && n === o[++a] && n === o[++a] && n === o[++a] && n === o[++a] && n === o[++a] && a < l)
            e.match_length = Y2 - (l - a), e.match_length > e.lookahead && (e.match_length = e.lookahead);
        }
        if (e.match_length >= k1 ? (t = j1(e, 1, e.match_length - k1), e.lookahead -= e.match_length, e.strstart += e.match_length, e.match_length = 0) : (t = j1(e, 0, e.window[e.strstart]), e.lookahead--, e.strstart++), t && (O1(e, !1), e.strm.avail_out === 0)) return D2;
    }
    return e.insert = 0, i === W2 ? (O1(e, !0), e.strm.avail_out === 0 ? te1 : he1) : e.last_lit && (O1(e, !1), e.strm.avail_out === 0) ? D2 : Re;
}, Ka = (e, i)=>{
    let t;
    for(;;){
        if (e.lookahead === 0 && (ie1(e), e.lookahead === 0)) {
            if (i === le1) return D2;
            break;
        }
        if (e.match_length = 0, t = j1(e, 0, e.window[e.strstart]), e.lookahead--, e.strstart++, t && (O1(e, !1), e.strm.avail_out === 0)) return D2;
    }
    return e.insert = 0, i === W2 ? (O1(e, !0), e.strm.avail_out === 0 ? te1 : he1) : e.last_lit && (O1(e, !1), e.strm.avail_out === 0) ? D2 : Re;
};
function $2(e, i, t, n, a) {
    this.good_length = e, this.max_lazy = i, this.nice_length = t, this.max_chain = n, this.func = a;
}
var ce1 = [
    new $2(0, 0, 0, 0, Ha),
    new $2(4, 4, 8, 4, Qe),
    new $2(4, 5, 16, 8, Qe),
    new $2(4, 6, 32, 32, Qe),
    new $2(4, 4, 16, 16, re1),
    new $2(8, 16, 32, 32, re1),
    new $2(8, 16, 128, 128, re1),
    new $2(8, 32, 128, 256, re1),
    new $2(32, 128, 258, 1024, re1),
    new $2(32, 258, 258, 4096, re1)
], Pa = (e)=>{
    e.window_size = 2 * e.w_size, X2(e.head), e.max_lazy_match = ce1[e.level].max_lazy, e.good_match = ce1[e.level].good_length, e.nice_match = ce1[e.level].nice_length, e.max_chain_length = ce1[e.level].max_chain, e.strstart = 0, e.block_start = 0, e.lookahead = 0, e.insert = 0, e.match_length = e.prev_length = k1 - 1, e.match_available = 0, e.ins_h = 0;
};
function Xa() {
    this.strm = null, this.status = 0, this.pending_buf = null, this.pending_buf_size = 0, this.pending_out = 0, this.pending = 0, this.wrap = 0, this.gzhead = null, this.gzindex = 0, this.method = Pe, this.last_flush = -1, this.w_size = 0, this.w_bits = 0, this.w_mask = 0, this.window = null, this.window_size = 0, this.prev = null, this.head = null, this.ins_h = 0, this.hash_size = 0, this.hash_bits = 0, this.hash_mask = 0, this.hash_shift = 0, this.block_start = 0, this.match_length = 0, this.prev_match = 0, this.match_available = 0, this.strstart = 0, this.match_start = 0, this.lookahead = 0, this.prev_length = 0, this.max_chain_length = 0, this.max_lazy_match = 0, this.level = 0, this.strategy = 0, this.good_match = 0, this.nice_match = 0, this.dyn_ltree = new Uint16Array(La * 2), this.dyn_dtree = new Uint16Array((2 * Oa + 1) * 2), this.bl_tree = new Uint16Array((2 * Na + 1) * 2), X2(this.dyn_ltree), X2(this.dyn_dtree), X2(this.bl_tree), this.l_desc = null, this.d_desc = null, this.bl_desc = null, this.bl_count = new Uint16Array(Ua + 1), this.heap = new Uint16Array(2 * _t + 1), X2(this.heap), this.heap_len = 0, this.heap_max = 0, this.depth = new Uint16Array(2 * _t + 1), X2(this.depth), this.l_buf = 0, this.lit_bufsize = 0, this.last_lit = 0, this.d_buf = 0, this.opt_len = 0, this.static_len = 0, this.matches = 0, this.insert = 0, this.bi_buf = 0, this.bi_valid = 0;
}
var vi = (e)=>{
    if (!e || !e.state) return G1(e, L1);
    e.total_in = e.total_out = 0, e.data_type = za;
    let i = e.state;
    return i.pending = 0, i.pending_out = 0, i.wrap < 0 && (i.wrap = -i.wrap), i.status = i.wrap ? Xe : q1, e.adler = i.wrap === 2 ? 0 : 1, i.last_flush = le1, ba(i), F2;
}, Ei = (e)=>{
    let i = vi(e);
    return i === F2 && Pa(e.state), i;
}, Ya = (e, i)=>!e || !e.state || e.state.wrap !== 2 ? L1 : (e.state.gzhead = i, F2), yi = (e, i, t, n, a, l)=>{
    if (!e) return L1;
    let o = 1;
    if (i === Ea && (i = 6), n < 0 ? (o = 0, n = -n) : n > 15 && (o = 2, n -= 16), a < 1 || a > Ta || t !== Pe || n < 8 || n > 15 || i < 0 || i > 9 || l < 0 || l > Aa) return G1(e, L1);
    n === 8 && (n = 9);
    let f = new Xa;
    return e.state = f, f.strm = e, f.wrap = o, f.gzhead = null, f.w_bits = n, f.w_size = 1 << f.w_bits, f.w_mask = f.w_size - 1, f.hash_bits = a + 7, f.hash_size = 1 << f.hash_bits, f.hash_mask = f.hash_size - 1, f.hash_shift = ~~((f.hash_bits + k1 - 1) / k1), f.window = new Uint8Array(f.w_size * 2), f.head = new Uint16Array(f.hash_size), f.prev = new Uint16Array(f.w_size), f.lit_bufsize = 1 << a + 6, f.pending_buf_size = f.lit_bufsize * 4, f.pending_buf = new Uint8Array(f.pending_buf_size), f.d_buf = 1 * f.lit_bufsize, f.l_buf = (1 + 2) * f.lit_bufsize, f.level = i, f.strategy = l, f.method = t, Ei(e);
}, Ga = (e, i)=>yi(e, i, Pe, ma, Da, Ra), ja = (e, i)=>{
    let t, n;
    if (!e || !e.state || i > Rt || i < 0) return e ? G1(e, L1) : L1;
    let a = e.state;
    if (!e.output || !e.input && e.avail_in !== 0 || a.status === se && i !== W2) return G1(e, e.avail_out === 0 ? Je : L1);
    a.strm = e;
    let l = a.last_flush;
    if (a.last_flush = i, a.status === Xe) if (a.wrap === 2) e.adler = 0, y2(a, 31), y2(a, 139), y2(a, 8), a.gzhead ? (y2(a, (a.gzhead.text ? 1 : 0) + (a.gzhead.hcrc ? 2 : 0) + (a.gzhead.extra ? 4 : 0) + (a.gzhead.name ? 8 : 0) + (a.gzhead.comment ? 16 : 0)), y2(a, a.gzhead.time & 255), y2(a, a.gzhead.time >> 8 & 255), y2(a, a.gzhead.time >> 16 & 255), y2(a, a.gzhead.time >> 24 & 255), y2(a, a.level === 9 ? 2 : a.strategy >= Ie || a.level < 2 ? 4 : 0), y2(a, a.gzhead.os & 255), a.gzhead.extra && a.gzhead.extra.length && (y2(a, a.gzhead.extra.length & 255), y2(a, a.gzhead.extra.length >> 8 & 255)), a.gzhead.hcrc && (e.adler = I2(e.adler, a.pending_buf, a.pending, 0)), a.gzindex = 0, a.status = ht) : (y2(a, 0), y2(a, 0), y2(a, 0), y2(a, 0), y2(a, 0), y2(a, a.level === 9 ? 2 : a.strategy >= Ie || a.level < 2 ? 4 : 0), y2(a, $a), a.status = q1);
    else {
        let o = Pe + (a.w_bits - 8 << 4) << 8, f = -1;
        a.strategy >= Ie || a.level < 2 ? f = 0 : a.level < 6 ? f = 1 : a.level === 6 ? f = 2 : f = 3, o |= f << 6, a.strstart !== 0 && (o |= Ca), o += 31 - o % 31, a.status = q1, de1(a, o), a.strstart !== 0 && (de1(a, e.adler >>> 16), de1(a, e.adler & 65535)), e.adler = 1;
    }
    if (a.status === ht) if (a.gzhead.extra) {
        for(t = a.pending; a.gzindex < (a.gzhead.extra.length & 65535) && !(a.pending === a.pending_buf_size && (a.gzhead.hcrc && a.pending > t && (e.adler = I2(e.adler, a.pending_buf, a.pending - t, t)), P2(e), t = a.pending, a.pending === a.pending_buf_size));)y2(a, a.gzhead.extra[a.gzindex] & 255), a.gzindex++;
        a.gzhead.hcrc && a.pending > t && (e.adler = I2(e.adler, a.pending_buf, a.pending - t, t)), a.gzindex === a.gzhead.extra.length && (a.gzindex = 0, a.status = $e);
    } else a.status = $e;
    if (a.status === $e) if (a.gzhead.name) {
        t = a.pending;
        do {
            if (a.pending === a.pending_buf_size && (a.gzhead.hcrc && a.pending > t && (e.adler = I2(e.adler, a.pending_buf, a.pending - t, t)), P2(e), t = a.pending, a.pending === a.pending_buf_size)) {
                n = 1;
                break;
            }
            a.gzindex < a.gzhead.name.length ? n = a.gzhead.name.charCodeAt(a.gzindex++) & 255 : n = 0, y2(a, n);
        }while (n !== 0)
        a.gzhead.hcrc && a.pending > t && (e.adler = I2(e.adler, a.pending_buf, a.pending - t, t)), n === 0 && (a.gzindex = 0, a.status = Me);
    } else a.status = Me;
    if (a.status === Me) if (a.gzhead.comment) {
        t = a.pending;
        do {
            if (a.pending === a.pending_buf_size && (a.gzhead.hcrc && a.pending > t && (e.adler = I2(e.adler, a.pending_buf, a.pending - t, t)), P2(e), t = a.pending, a.pending === a.pending_buf_size)) {
                n = 1;
                break;
            }
            a.gzindex < a.gzhead.comment.length ? n = a.gzhead.comment.charCodeAt(a.gzindex++) & 255 : n = 0, y2(a, n);
        }while (n !== 0)
        a.gzhead.hcrc && a.pending > t && (e.adler = I2(e.adler, a.pending_buf, a.pending - t, t)), n === 0 && (a.status = Fe);
    } else a.status = Fe;
    if (a.status === Fe && (a.gzhead.hcrc ? (a.pending + 2 > a.pending_buf_size && P2(e), a.pending + 2 <= a.pending_buf_size && (y2(a, e.adler & 255), y2(a, e.adler >> 8 & 255), e.adler = 0, a.status = q1)) : a.status = q1), a.pending !== 0) {
        if (P2(e), e.avail_out === 0) return a.last_flush = -1, F2;
    } else if (e.avail_in === 0 && Tt(i) <= Tt(l) && i !== W2) return G1(e, Je);
    if (a.status === se && e.avail_in !== 0) return G1(e, Je);
    if (e.avail_in !== 0 || a.lookahead !== 0 || i !== le1 && a.status !== se) {
        let o1 = a.strategy === Ie ? Ka(a, i) : a.strategy === Sa ? Ba(a, i) : ce1[a.level].func(a, i);
        if ((o1 === te1 || o1 === he1) && (a.status = se), o1 === D2 || o1 === te1) return e.avail_out === 0 && (a.last_flush = -1), F2;
        if (o1 === Re && (i === xa ? pa(a) : i !== Rt && (wa(a, 0, 0, !1), i === ka && (X2(a.head), a.lookahead === 0 && (a.strstart = 0, a.block_start = 0, a.insert = 0))), P2(e), e.avail_out === 0)) return a.last_flush = -1, F2;
    }
    return i !== W2 ? F2 : a.wrap <= 0 ? zt : (a.wrap === 2 ? (y2(a, e.adler & 255), y2(a, e.adler >> 8 & 255), y2(a, e.adler >> 16 & 255), y2(a, e.adler >> 24 & 255), y2(a, e.total_in & 255), y2(a, e.total_in >> 8 & 255), y2(a, e.total_in >> 16 & 255), y2(a, e.total_in >> 24 & 255)) : (de1(a, e.adler >>> 16), de1(a, e.adler & 65535)), P2(e), a.wrap > 0 && (a.wrap = -a.wrap), a.pending !== 0 ? F2 : zt);
}, Wa = (e)=>{
    if (!e || !e.state) return L1;
    let i = e.state.status;
    return i !== Xe && i !== ht && i !== $e && i !== Me && i !== Fe && i !== q1 && i !== se ? G1(e, L1) : (e.state = null, i === q1 ? G1(e, va) : F2);
}, Va = (e, i)=>{
    let t = i.length;
    if (!e || !e.state) return L1;
    let n = e.state, a = n.wrap;
    if (a === 2 || a === 1 && n.status !== Xe || n.lookahead) return L1;
    if (a === 1 && (e.adler = ve1(e.adler, i, t, 0)), n.wrap = 0, t >= n.w_size) {
        a === 0 && (X2(n.head), n.strstart = 0, n.block_start = 0, n.insert = 0);
        let c = new Uint8Array(n.w_size);
        c.set(i.subarray(t - n.w_size, t), 0), i = c, t = n.w_size;
    }
    let l = e.avail_in, o = e.next_in, f = e.input;
    for(e.avail_in = t, e.next_in = 0, e.input = i, ie1(n); n.lookahead >= k1;){
        let c1 = n.strstart, r = n.lookahead - (k1 - 1);
        do n.ins_h = V2(n, n.ins_h, n.window[c1 + k1 - 1]), n.prev[c1 & n.w_mask] = n.head[n.ins_h], n.head[n.ins_h] = c1, c1++;
        while (--r)
        n.strstart = c1, n.lookahead = k1 - 1, ie1(n);
    }
    return n.strstart += n.lookahead, n.block_start = n.strstart, n.insert = n.lookahead, n.lookahead = 0, n.match_length = n.prev_length = k1 - 1, n.match_available = 0, e.next_in = o, e.input = f, e.avail_in = l, n.wrap = a, F2;
}, Ja = Ga, Qa = yi, qa = Ei, en = vi, tn = Ya, an = ja, nn = Wa, ln = Va, rn = "pako deflate (from Nodeca project)", be = {
    deflateInit: Ja,
    deflateInit2: Qa,
    deflateReset: qa,
    deflateResetKeep: en,
    deflateSetHeader: tn,
    deflate: an,
    deflateEnd: nn,
    deflateSetDictionary: ln,
    deflateInfo: rn
}, fn = (e, i)=>Object.prototype.hasOwnProperty.call(e, i), on = function(e) {
    let i = Array.prototype.slice.call(arguments, 1);
    for(; i.length;){
        let t = i.shift();
        if (!!t) {
            if (typeof t != "object") throw new TypeError(t + "must be non-object");
            for(let n in t)fn(t, n) && (e[n] = t[n]);
        }
    }
    return e;
}, _n = (e)=>{
    let i = 0;
    for(let n = 0, a = e.length; n < a; n++)i += e[n].length;
    let t = new Uint8Array(i);
    for(let n1 = 0, a1 = 0, l = e.length; n1 < l; n1++){
        let o = e[n1];
        t.set(o, a1), a1 += o.length;
    }
    return t;
}, Ye = {
    assign: on,
    flattenChunks: _n
}, Si = !0;
try {
    String.fromCharCode.apply(null, new Uint8Array(1));
} catch  {
    Si = !1;
}
var Ee1 = new Uint8Array(256);
for(let e = 0; e < 256; e++)Ee1[e] = e >= 252 ? 6 : e >= 248 ? 5 : e >= 240 ? 4 : e >= 224 ? 3 : e >= 192 ? 2 : 1;
Ee1[254] = Ee1[254] = 1;
var hn = (e)=>{
    if (typeof TextEncoder == "function" && TextEncoder.prototype.encode) return new TextEncoder().encode(e);
    let i, t, n, a, l, o = e.length, f = 0;
    for(a = 0; a < o; a++)t = e.charCodeAt(a), (t & 64512) === 55296 && a + 1 < o && (n = e.charCodeAt(a + 1), (n & 64512) === 56320 && (t = 65536 + (t - 55296 << 10) + (n - 56320), a++)), f += t < 128 ? 1 : t < 2048 ? 2 : t < 65536 ? 3 : 4;
    for(i = new Uint8Array(f), l = 0, a = 0; l < f; a++)t = e.charCodeAt(a), (t & 64512) === 55296 && a + 1 < o && (n = e.charCodeAt(a + 1), (n & 64512) === 56320 && (t = 65536 + (t - 55296 << 10) + (n - 56320), a++)), t < 128 ? i[l++] = t : t < 2048 ? (i[l++] = 192 | t >>> 6, i[l++] = 128 | t & 63) : t < 65536 ? (i[l++] = 224 | t >>> 12, i[l++] = 128 | t >>> 6 & 63, i[l++] = 128 | t & 63) : (i[l++] = 240 | t >>> 18, i[l++] = 128 | t >>> 12 & 63, i[l++] = 128 | t >>> 6 & 63, i[l++] = 128 | t & 63);
    return i;
}, dn = (e, i)=>{
    if (i < 65534 && e.subarray && Si) return String.fromCharCode.apply(null, e.length === i ? e : e.subarray(0, i));
    let t = "";
    for(let n = 0; n < i; n++)t += String.fromCharCode(e[n]);
    return t;
}, sn = (e, i)=>{
    let t = i || e.length;
    if (typeof TextDecoder == "function" && TextDecoder.prototype.decode) return new TextDecoder().decode(e.subarray(0, i));
    let n, a, l = new Array(t * 2);
    for(a = 0, n = 0; n < t;){
        let o = e[n++];
        if (o < 128) {
            l[a++] = o;
            continue;
        }
        let f = Ee1[o];
        if (f > 4) {
            l[a++] = 65533, n += f - 1;
            continue;
        }
        for(o &= f === 2 ? 31 : f === 3 ? 15 : 7; f > 1 && n < t;)o = o << 6 | e[n++] & 63, f--;
        if (f > 1) {
            l[a++] = 65533;
            continue;
        }
        o < 65536 ? l[a++] = o : (o -= 65536, l[a++] = 55296 | o >> 10 & 1023, l[a++] = 56320 | o & 1023);
    }
    return dn(l, a);
}, cn = (e, i)=>{
    i = i || e.length, i > e.length && (i = e.length);
    let t = i - 1;
    for(; t >= 0 && (e[t] & 192) === 128;)t--;
    return t < 0 || t === 0 ? i : t + Ee1[e[t]] > i ? t : i;
}, ye1 = {
    string2buf: hn,
    buf2string: sn,
    utf8border: cn
};
function un() {
    this.input = null, this.next_in = 0, this.avail_in = 0, this.total_in = 0, this.output = null, this.next_out = 0, this.avail_out = 0, this.total_out = 0, this.msg = "", this.state = null, this.data_type = 2, this.adler = 0;
}
var Ai = un, Ri = Object.prototype.toString, { Z_NO_FLUSH: bn , Z_SYNC_FLUSH: wn , Z_FULL_FLUSH: gn , Z_FINISH: pn , Z_OK: Be , Z_STREAM_END: xn , Z_DEFAULT_COMPRESSION: kn , Z_DEFAULT_STRATEGY: vn , Z_DEFLATED: En  } = ne1;
function ze(e) {
    this.options = Ye.assign({
        level: kn,
        method: En,
        chunkSize: 16384,
        windowBits: 15,
        memLevel: 8,
        strategy: vn
    }, e || {});
    let i = this.options;
    i.raw && i.windowBits > 0 ? i.windowBits = -i.windowBits : i.gzip && i.windowBits > 0 && i.windowBits < 16 && (i.windowBits += 16), this.err = 0, this.msg = "", this.ended = !1, this.chunks = [], this.strm = new Ai, this.strm.avail_out = 0;
    let t = be.deflateInit2(this.strm, i.level, i.method, i.windowBits, i.memLevel, i.strategy);
    if (t !== Be) throw new Error(ee1[t]);
    if (i.header && be.deflateSetHeader(this.strm, i.header), i.dictionary) {
        let n;
        if (typeof i.dictionary == "string" ? n = ye1.string2buf(i.dictionary) : Ri.call(i.dictionary) === "[object ArrayBuffer]" ? n = new Uint8Array(i.dictionary) : n = i.dictionary, t = be.deflateSetDictionary(this.strm, n), t !== Be) throw new Error(ee1[t]);
        this._dict_set = !0;
    }
}
ze.prototype.push = function(e, i) {
    let t = this.strm, n = this.options.chunkSize, a, l;
    if (this.ended) return !1;
    for(i === ~~i ? l = i : l = i === !0 ? pn : bn, typeof e == "string" ? t.input = ye1.string2buf(e) : Ri.call(e) === "[object ArrayBuffer]" ? t.input = new Uint8Array(e) : t.input = e, t.next_in = 0, t.avail_in = t.input.length;;){
        if (t.avail_out === 0 && (t.output = new Uint8Array(n), t.next_out = 0, t.avail_out = n), (l === wn || l === gn) && t.avail_out <= 6) {
            this.onData(t.output.subarray(0, t.next_out)), t.avail_out = 0;
            continue;
        }
        if (a = be.deflate(t, l), a === xn) return t.next_out > 0 && this.onData(t.output.subarray(0, t.next_out)), a = be.deflateEnd(this.strm), this.onEnd(a), this.ended = !0, a === Be;
        if (t.avail_out === 0) {
            this.onData(t.output);
            continue;
        }
        if (l > 0 && t.next_out > 0) {
            this.onData(t.output.subarray(0, t.next_out)), t.avail_out = 0;
            continue;
        }
        if (t.avail_in === 0) break;
    }
    return !0;
};
ze.prototype.onData = function(e) {
    this.chunks.push(e);
};
ze.prototype.onEnd = function(e) {
    e === Be && (this.result = Ye.flattenChunks(this.chunks)), this.chunks = [], this.err = e, this.msg = this.strm.msg;
};
function bt(e, i) {
    let t = new ze(i);
    if (t.push(e, !0), t.err) throw t.msg || ee1[t.err];
    return t.result;
}
function yn(e, i) {
    return i = i || {}, i.raw = !0, bt(e, i);
}
function Sn(e, i) {
    return i = i || {}, i.gzip = !0, bt(e, i);
}
var An = ze, Rn = bt, zn = yn, Tn = Sn, mn = ne1, Dn = {
    Deflate: An,
    deflate: Rn,
    deflateRaw: zn,
    gzip: Tn,
    constants: mn
}, Oe = 30, Zn = 12, In = function(i, t) {
    let n, a, l, o, f, c, r, _, E, s, h, u, m, v, w, A, x, d, S, Z, b, z, R, g, p = i.state;
    n = i.next_in, R = i.input, a = n + (i.avail_in - 5), l = i.next_out, g = i.output, o = l - (t - i.avail_out), f = l + (i.avail_out - 257), c = p.dmax, r = p.wsize, _ = p.whave, E = p.wnext, s = p.window, h = p.hold, u = p.bits, m = p.lencode, v = p.distcode, w = (1 << p.lenbits) - 1, A = (1 << p.distbits) - 1;
    e: do {
        u < 15 && (h += R[n++] << u, u += 8, h += R[n++] << u, u += 8), x = m[h & w];
        t: for(;;){
            if (d = x >>> 24, h >>>= d, u -= d, d = x >>> 16 & 255, d === 0) g[l++] = x & 65535;
            else if (d & 16) {
                S = x & 65535, d &= 15, d && (u < d && (h += R[n++] << u, u += 8), S += h & (1 << d) - 1, h >>>= d, u -= d), u < 15 && (h += R[n++] << u, u += 8, h += R[n++] << u, u += 8), x = v[h & A];
                i: for(;;){
                    if (d = x >>> 24, h >>>= d, u -= d, d = x >>> 16 & 255, d & 16) {
                        if (Z = x & 65535, d &= 15, u < d && (h += R[n++] << u, u += 8, u < d && (h += R[n++] << u, u += 8)), Z += h & (1 << d) - 1, Z > c) {
                            i.msg = "invalid distance too far back", p.mode = Oe;
                            break e;
                        }
                        if (h >>>= d, u -= d, d = l - o, Z > d) {
                            if (d = Z - d, d > _ && p.sane) {
                                i.msg = "invalid distance too far back", p.mode = Oe;
                                break e;
                            }
                            if (b = 0, z = s, E === 0) {
                                if (b += r - d, d < S) {
                                    S -= d;
                                    do g[l++] = s[b++];
                                    while (--d)
                                    b = l - Z, z = g;
                                }
                            } else if (E < d) {
                                if (b += r + E - d, d -= E, d < S) {
                                    S -= d;
                                    do g[l++] = s[b++];
                                    while (--d)
                                    if (b = 0, E < S) {
                                        d = E, S -= d;
                                        do g[l++] = s[b++];
                                        while (--d)
                                        b = l - Z, z = g;
                                    }
                                }
                            } else if (b += E - d, d < S) {
                                S -= d;
                                do g[l++] = s[b++];
                                while (--d)
                                b = l - Z, z = g;
                            }
                            for(; S > 2;)g[l++] = z[b++], g[l++] = z[b++], g[l++] = z[b++], S -= 3;
                            S && (g[l++] = z[b++], S > 1 && (g[l++] = z[b++]));
                        } else {
                            b = l - Z;
                            do g[l++] = g[b++], g[l++] = g[b++], g[l++] = g[b++], S -= 3;
                            while (S > 2)
                            S && (g[l++] = g[b++], S > 1 && (g[l++] = g[b++]));
                        }
                    } else if ((d & 64) === 0) {
                        x = v[(x & 65535) + (h & (1 << d) - 1)];
                        continue i;
                    } else {
                        i.msg = "invalid distance code", p.mode = Oe;
                        break e;
                    }
                    break;
                }
            } else if ((d & 64) === 0) {
                x = m[(x & 65535) + (h & (1 << d) - 1)];
                continue t;
            } else if (d & 32) {
                p.mode = Zn;
                break e;
            } else {
                i.msg = "invalid literal/length code", p.mode = Oe;
                break e;
            }
            break;
        }
    }while (n < a && l < f)
    S = u >> 3, n -= S, u -= S << 3, h &= (1 << u) - 1, i.next_in = n, i.next_out = l, i.avail_in = n < a ? 5 + (a - n) : 5 - (n - a), i.avail_out = l < f ? 257 + (f - l) : 257 - (l - f), p.hold = h, p.bits = u;
}, fe1 = 15, mt = 852, Dt = 592, Zt = 0, qe = 1, It = 2, On = new Uint16Array([
    3,
    4,
    5,
    6,
    7,
    8,
    9,
    10,
    11,
    13,
    15,
    17,
    19,
    23,
    27,
    31,
    35,
    43,
    51,
    59,
    67,
    83,
    99,
    115,
    131,
    163,
    195,
    227,
    258,
    0,
    0
]), Nn = new Uint8Array([
    16,
    16,
    16,
    16,
    16,
    16,
    16,
    16,
    17,
    17,
    17,
    17,
    18,
    18,
    18,
    18,
    19,
    19,
    19,
    19,
    20,
    20,
    20,
    20,
    21,
    21,
    21,
    21,
    16,
    72,
    78
]), Ln = new Uint16Array([
    1,
    2,
    3,
    4,
    5,
    7,
    9,
    13,
    17,
    25,
    33,
    49,
    65,
    97,
    129,
    193,
    257,
    385,
    513,
    769,
    1025,
    1537,
    2049,
    3073,
    4097,
    6145,
    8193,
    12289,
    16385,
    24577,
    0,
    0
]), Un = new Uint8Array([
    16,
    16,
    16,
    16,
    17,
    17,
    18,
    18,
    19,
    19,
    20,
    20,
    21,
    21,
    22,
    22,
    23,
    23,
    24,
    24,
    25,
    25,
    26,
    26,
    27,
    27,
    28,
    28,
    29,
    29,
    64,
    64
]), Cn = (e, i, t, n, a, l, o, f)=>{
    let c = f.bits, r = 0, _ = 0, E = 0, s = 0, h = 0, u = 0, m = 0, v = 0, w = 0, A = 0, x, d, S, Z, b, z = null, R = 0, g, p = new Uint16Array(fe1 + 1), J = new Uint16Array(fe1 + 1), me = null, gt = 0, pt, De, Ze;
    for(r = 0; r <= fe1; r++)p[r] = 0;
    for(_ = 0; _ < n; _++)p[i[t + _]]++;
    for(h = c, s = fe1; s >= 1 && p[s] === 0; s--);
    if (h > s && (h = s), s === 0) return a[l++] = 1 << 24 | 64 << 16 | 0, a[l++] = 1 << 24 | 64 << 16 | 0, f.bits = 1, 0;
    for(E = 1; E < s && p[E] === 0; E++);
    for(h < E && (h = E), v = 1, r = 1; r <= fe1; r++)if (v <<= 1, v -= p[r], v < 0) return -1;
    if (v > 0 && (e === Zt || s !== 1)) return -1;
    for(J[1] = 0, r = 1; r < fe1; r++)J[r + 1] = J[r] + p[r];
    for(_ = 0; _ < n; _++)i[t + _] !== 0 && (o[J[i[t + _]]++] = _);
    if (e === Zt ? (z = me = o, g = 19) : e === qe ? (z = On, R -= 257, me = Nn, gt -= 257, g = 256) : (z = Ln, me = Un, g = -1), A = 0, _ = 0, r = E, b = l, u = h, m = 0, S = -1, w = 1 << h, Z = w - 1, e === qe && w > mt || e === It && w > Dt) return 1;
    for(;;){
        pt = r - m, o[_] < g ? (De = 0, Ze = o[_]) : o[_] > g ? (De = me[gt + o[_]], Ze = z[R + o[_]]) : (De = 32 + 64, Ze = 0), x = 1 << r - m, d = 1 << u, E = d;
        do d -= x, a[b + (A >> m) + d] = pt << 24 | De << 16 | Ze | 0;
        while (d !== 0)
        for(x = 1 << r - 1; A & x;)x >>= 1;
        if (x !== 0 ? (A &= x - 1, A += x) : A = 0, _++, --p[r] === 0) {
            if (r === s) break;
            r = i[t + o[_]];
        }
        if (r > h && (A & Z) !== S) {
            for(m === 0 && (m = h), b += E, u = r - m, v = 1 << u; u + m < s && (v -= p[u + m], !(v <= 0));)u++, v <<= 1;
            if (w += 1 << u, e === qe && w > mt || e === It && w > Dt) return 1;
            S = A & Z, a[S] = h << 24 | u << 16 | b - l | 0;
        }
    }
    return A !== 0 && (a[b + A] = r - m << 24 | 64 << 16 | 0), f.bits = h, 0;
}, we1 = Cn, $n = 0, zi = 1, Ti = 2, { Z_FINISH: Ot , Z_BLOCK: Mn , Z_TREES: Ne , Z_OK: ae1 , Z_STREAM_END: Fn , Z_NEED_DICT: Hn , Z_STREAM_ERROR: U1 , Z_DATA_ERROR: mi , Z_MEM_ERROR: Di , Z_BUF_ERROR: Bn , Z_DEFLATED: Nt  } = ne1, Zi = 1, Lt = 2, Ut = 3, Ct = 4, $t = 5, Mt = 6, Ft = 7, Ht = 8, Bt = 9, Kt = 10, Ke = 11, H1 = 12, et = 13, Pt = 14, tt = 15, Xt = 16, Yt = 17, Gt = 18, jt = 19, Le = 20, Ue1 = 21, Wt = 22, Vt = 23, Jt = 24, Qt = 25, qt = 26, it = 27, ei = 28, ti = 29, T2 = 30, Ii = 31, Kn = 32, Pn = 852, Xn = 592, Yn = 15, Gn = Yn, ii = (e)=>(e >>> 24 & 255) + (e >>> 8 & 65280) + ((e & 65280) << 8) + ((e & 255) << 24);
function jn() {
    this.mode = 0, this.last = !1, this.wrap = 0, this.havedict = !1, this.flags = 0, this.dmax = 0, this.check = 0, this.total = 0, this.head = null, this.wbits = 0, this.wsize = 0, this.whave = 0, this.wnext = 0, this.window = null, this.hold = 0, this.bits = 0, this.length = 0, this.offset = 0, this.extra = 0, this.lencode = null, this.distcode = null, this.lenbits = 0, this.distbits = 0, this.ncode = 0, this.nlen = 0, this.ndist = 0, this.have = 0, this.next = null, this.lens = new Uint16Array(320), this.work = new Uint16Array(288), this.lendyn = null, this.distdyn = null, this.sane = 0, this.back = 0, this.was = 0;
}
var Oi = (e)=>{
    if (!e || !e.state) return U1;
    let i = e.state;
    return e.total_in = e.total_out = i.total = 0, e.msg = "", i.wrap && (e.adler = i.wrap & 1), i.mode = Zi, i.last = 0, i.havedict = 0, i.dmax = 32768, i.head = null, i.hold = 0, i.bits = 0, i.lencode = i.lendyn = new Int32Array(Pn), i.distcode = i.distdyn = new Int32Array(Xn), i.sane = 1, i.back = -1, ae1;
}, Ni = (e)=>{
    if (!e || !e.state) return U1;
    let i = e.state;
    return i.wsize = 0, i.whave = 0, i.wnext = 0, Oi(e);
}, Li = (e, i)=>{
    let t;
    if (!e || !e.state) return U1;
    let n = e.state;
    return i < 0 ? (t = 0, i = -i) : (t = (i >> 4) + 1, i < 48 && (i &= 15)), i && (i < 8 || i > 15) ? U1 : (n.window !== null && n.wbits !== i && (n.window = null), n.wrap = t, n.wbits = i, Ni(e));
}, Ui = (e, i)=>{
    if (!e) return U1;
    let t = new jn;
    e.state = t, t.window = null;
    let n = Li(e, i);
    return n !== ae1 && (e.state = null), n;
}, Wn = (e)=>Ui(e, Gn), ai = !0, at, nt, Vn = (e)=>{
    if (ai) {
        at = new Int32Array(512), nt = new Int32Array(32);
        let i = 0;
        for(; i < 144;)e.lens[i++] = 8;
        for(; i < 256;)e.lens[i++] = 9;
        for(; i < 280;)e.lens[i++] = 7;
        for(; i < 288;)e.lens[i++] = 8;
        for(we1(zi, e.lens, 0, 288, at, 0, e.work, {
            bits: 9
        }), i = 0; i < 32;)e.lens[i++] = 5;
        we1(Ti, e.lens, 0, 32, nt, 0, e.work, {
            bits: 5
        }), ai = !1;
    }
    e.lencode = at, e.lenbits = 9, e.distcode = nt, e.distbits = 5;
}, Ci = (e, i, t, n)=>{
    let a, l = e.state;
    return l.window === null && (l.wsize = 1 << l.wbits, l.wnext = 0, l.whave = 0, l.window = new Uint8Array(l.wsize)), n >= l.wsize ? (l.window.set(i.subarray(t - l.wsize, t), 0), l.wnext = 0, l.whave = l.wsize) : (a = l.wsize - l.wnext, a > n && (a = n), l.window.set(i.subarray(t - n, t - n + a), l.wnext), n -= a, n ? (l.window.set(i.subarray(t - n, t), 0), l.wnext = n, l.whave = l.wsize) : (l.wnext += a, l.wnext === l.wsize && (l.wnext = 0), l.whave < l.wsize && (l.whave += a))), 0;
}, Jn = (e, i)=>{
    let t, n, a, l, o, f, c, r, _, E, s, h, u, m, v = 0, w, A, x, d, S, Z, b, z, R = new Uint8Array(4), g, p, J = new Uint8Array([
        16,
        17,
        18,
        0,
        8,
        7,
        9,
        6,
        10,
        5,
        11,
        4,
        12,
        3,
        13,
        2,
        14,
        1,
        15
    ]);
    if (!e || !e.state || !e.output || !e.input && e.avail_in !== 0) return U1;
    t = e.state, t.mode === H1 && (t.mode = et), o = e.next_out, a = e.output, c = e.avail_out, l = e.next_in, n = e.input, f = e.avail_in, r = t.hold, _ = t.bits, E = f, s = c, z = ae1;
    e: for(;;)switch(t.mode){
        case Zi:
            if (t.wrap === 0) {
                t.mode = et;
                break;
            }
            for(; _ < 16;){
                if (f === 0) break e;
                f--, r += n[l++] << _, _ += 8;
            }
            if (t.wrap & 2 && r === 35615) {
                t.check = 0, R[0] = r & 255, R[1] = r >>> 8 & 255, t.check = I2(t.check, R, 2, 0), r = 0, _ = 0, t.mode = Lt;
                break;
            }
            if (t.flags = 0, t.head && (t.head.done = !1), !(t.wrap & 1) || (((r & 255) << 8) + (r >> 8)) % 31) {
                e.msg = "incorrect header check", t.mode = T2;
                break;
            }
            if ((r & 15) !== Nt) {
                e.msg = "unknown compression method", t.mode = T2;
                break;
            }
            if (r >>>= 4, _ -= 4, b = (r & 15) + 8, t.wbits === 0) t.wbits = b;
            else if (b > t.wbits) {
                e.msg = "invalid window size", t.mode = T2;
                break;
            }
            t.dmax = 1 << t.wbits, e.adler = t.check = 1, t.mode = r & 512 ? Kt : H1, r = 0, _ = 0;
            break;
        case Lt:
            for(; _ < 16;){
                if (f === 0) break e;
                f--, r += n[l++] << _, _ += 8;
            }
            if (t.flags = r, (t.flags & 255) !== Nt) {
                e.msg = "unknown compression method", t.mode = T2;
                break;
            }
            if (t.flags & 57344) {
                e.msg = "unknown header flags set", t.mode = T2;
                break;
            }
            t.head && (t.head.text = r >> 8 & 1), t.flags & 512 && (R[0] = r & 255, R[1] = r >>> 8 & 255, t.check = I2(t.check, R, 2, 0)), r = 0, _ = 0, t.mode = Ut;
        case Ut:
            for(; _ < 32;){
                if (f === 0) break e;
                f--, r += n[l++] << _, _ += 8;
            }
            t.head && (t.head.time = r), t.flags & 512 && (R[0] = r & 255, R[1] = r >>> 8 & 255, R[2] = r >>> 16 & 255, R[3] = r >>> 24 & 255, t.check = I2(t.check, R, 4, 0)), r = 0, _ = 0, t.mode = Ct;
        case Ct:
            for(; _ < 16;){
                if (f === 0) break e;
                f--, r += n[l++] << _, _ += 8;
            }
            t.head && (t.head.xflags = r & 255, t.head.os = r >> 8), t.flags & 512 && (R[0] = r & 255, R[1] = r >>> 8 & 255, t.check = I2(t.check, R, 2, 0)), r = 0, _ = 0, t.mode = $t;
        case $t:
            if (t.flags & 1024) {
                for(; _ < 16;){
                    if (f === 0) break e;
                    f--, r += n[l++] << _, _ += 8;
                }
                t.length = r, t.head && (t.head.extra_len = r), t.flags & 512 && (R[0] = r & 255, R[1] = r >>> 8 & 255, t.check = I2(t.check, R, 2, 0)), r = 0, _ = 0;
            } else t.head && (t.head.extra = null);
            t.mode = Mt;
        case Mt:
            if (t.flags & 1024 && (h = t.length, h > f && (h = f), h && (t.head && (b = t.head.extra_len - t.length, t.head.extra || (t.head.extra = new Uint8Array(t.head.extra_len)), t.head.extra.set(n.subarray(l, l + h), b)), t.flags & 512 && (t.check = I2(t.check, n, h, l)), f -= h, l += h, t.length -= h), t.length)) break e;
            t.length = 0, t.mode = Ft;
        case Ft:
            if (t.flags & 2048) {
                if (f === 0) break e;
                h = 0;
                do b = n[l + h++], t.head && b && t.length < 65536 && (t.head.name += String.fromCharCode(b));
                while (b && h < f)
                if (t.flags & 512 && (t.check = I2(t.check, n, h, l)), f -= h, l += h, b) break e;
            } else t.head && (t.head.name = null);
            t.length = 0, t.mode = Ht;
        case Ht:
            if (t.flags & 4096) {
                if (f === 0) break e;
                h = 0;
                do b = n[l + h++], t.head && b && t.length < 65536 && (t.head.comment += String.fromCharCode(b));
                while (b && h < f)
                if (t.flags & 512 && (t.check = I2(t.check, n, h, l)), f -= h, l += h, b) break e;
            } else t.head && (t.head.comment = null);
            t.mode = Bt;
        case Bt:
            if (t.flags & 512) {
                for(; _ < 16;){
                    if (f === 0) break e;
                    f--, r += n[l++] << _, _ += 8;
                }
                if (r !== (t.check & 65535)) {
                    e.msg = "header crc mismatch", t.mode = T2;
                    break;
                }
                r = 0, _ = 0;
            }
            t.head && (t.head.hcrc = t.flags >> 9 & 1, t.head.done = !0), e.adler = t.check = 0, t.mode = H1;
            break;
        case Kt:
            for(; _ < 32;){
                if (f === 0) break e;
                f--, r += n[l++] << _, _ += 8;
            }
            e.adler = t.check = ii(r), r = 0, _ = 0, t.mode = Ke;
        case Ke:
            if (t.havedict === 0) return e.next_out = o, e.avail_out = c, e.next_in = l, e.avail_in = f, t.hold = r, t.bits = _, Hn;
            e.adler = t.check = 1, t.mode = H1;
        case H1:
            if (i === Mn || i === Ne) break e;
        case et:
            if (t.last) {
                r >>>= _ & 7, _ -= _ & 7, t.mode = it;
                break;
            }
            for(; _ < 3;){
                if (f === 0) break e;
                f--, r += n[l++] << _, _ += 8;
            }
            switch(t.last = r & 1, r >>>= 1, _ -= 1, r & 3){
                case 0:
                    t.mode = Pt;
                    break;
                case 1:
                    if (Vn(t), t.mode = Le, i === Ne) {
                        r >>>= 2, _ -= 2;
                        break e;
                    }
                    break;
                case 2:
                    t.mode = Yt;
                    break;
                case 3:
                    e.msg = "invalid block type", t.mode = T2;
            }
            r >>>= 2, _ -= 2;
            break;
        case Pt:
            for(r >>>= _ & 7, _ -= _ & 7; _ < 32;){
                if (f === 0) break e;
                f--, r += n[l++] << _, _ += 8;
            }
            if ((r & 65535) !== (r >>> 16 ^ 65535)) {
                e.msg = "invalid stored block lengths", t.mode = T2;
                break;
            }
            if (t.length = r & 65535, r = 0, _ = 0, t.mode = tt, i === Ne) break e;
        case tt:
            t.mode = Xt;
        case Xt:
            if (h = t.length, h) {
                if (h > f && (h = f), h > c && (h = c), h === 0) break e;
                a.set(n.subarray(l, l + h), o), f -= h, l += h, c -= h, o += h, t.length -= h;
                break;
            }
            t.mode = H1;
            break;
        case Yt:
            for(; _ < 14;){
                if (f === 0) break e;
                f--, r += n[l++] << _, _ += 8;
            }
            if (t.nlen = (r & 31) + 257, r >>>= 5, _ -= 5, t.ndist = (r & 31) + 1, r >>>= 5, _ -= 5, t.ncode = (r & 15) + 4, r >>>= 4, _ -= 4, t.nlen > 286 || t.ndist > 30) {
                e.msg = "too many length or distance symbols", t.mode = T2;
                break;
            }
            t.have = 0, t.mode = Gt;
        case Gt:
            for(; t.have < t.ncode;){
                for(; _ < 3;){
                    if (f === 0) break e;
                    f--, r += n[l++] << _, _ += 8;
                }
                t.lens[J[t.have++]] = r & 7, r >>>= 3, _ -= 3;
            }
            for(; t.have < 19;)t.lens[J[t.have++]] = 0;
            if (t.lencode = t.lendyn, t.lenbits = 7, g = {
                bits: t.lenbits
            }, z = we1($n, t.lens, 0, 19, t.lencode, 0, t.work, g), t.lenbits = g.bits, z) {
                e.msg = "invalid code lengths set", t.mode = T2;
                break;
            }
            t.have = 0, t.mode = jt;
        case jt:
            for(; t.have < t.nlen + t.ndist;){
                for(; v = t.lencode[r & (1 << t.lenbits) - 1], w = v >>> 24, A = v >>> 16 & 255, x = v & 65535, !(w <= _);){
                    if (f === 0) break e;
                    f--, r += n[l++] << _, _ += 8;
                }
                if (x < 16) r >>>= w, _ -= w, t.lens[t.have++] = x;
                else {
                    if (x === 16) {
                        for(p = w + 2; _ < p;){
                            if (f === 0) break e;
                            f--, r += n[l++] << _, _ += 8;
                        }
                        if (r >>>= w, _ -= w, t.have === 0) {
                            e.msg = "invalid bit length repeat", t.mode = T2;
                            break;
                        }
                        b = t.lens[t.have - 1], h = 3 + (r & 3), r >>>= 2, _ -= 2;
                    } else if (x === 17) {
                        for(p = w + 3; _ < p;){
                            if (f === 0) break e;
                            f--, r += n[l++] << _, _ += 8;
                        }
                        r >>>= w, _ -= w, b = 0, h = 3 + (r & 7), r >>>= 3, _ -= 3;
                    } else {
                        for(p = w + 7; _ < p;){
                            if (f === 0) break e;
                            f--, r += n[l++] << _, _ += 8;
                        }
                        r >>>= w, _ -= w, b = 0, h = 11 + (r & 127), r >>>= 7, _ -= 7;
                    }
                    if (t.have + h > t.nlen + t.ndist) {
                        e.msg = "invalid bit length repeat", t.mode = T2;
                        break;
                    }
                    for(; h--;)t.lens[t.have++] = b;
                }
            }
            if (t.mode === T2) break;
            if (t.lens[256] === 0) {
                e.msg = "invalid code -- missing end-of-block", t.mode = T2;
                break;
            }
            if (t.lenbits = 9, g = {
                bits: t.lenbits
            }, z = we1(zi, t.lens, 0, t.nlen, t.lencode, 0, t.work, g), t.lenbits = g.bits, z) {
                e.msg = "invalid literal/lengths set", t.mode = T2;
                break;
            }
            if (t.distbits = 6, t.distcode = t.distdyn, g = {
                bits: t.distbits
            }, z = we1(Ti, t.lens, t.nlen, t.ndist, t.distcode, 0, t.work, g), t.distbits = g.bits, z) {
                e.msg = "invalid distances set", t.mode = T2;
                break;
            }
            if (t.mode = Le, i === Ne) break e;
        case Le:
            t.mode = Ue1;
        case Ue1:
            if (f >= 6 && c >= 258) {
                e.next_out = o, e.avail_out = c, e.next_in = l, e.avail_in = f, t.hold = r, t.bits = _, In(e, s), o = e.next_out, a = e.output, c = e.avail_out, l = e.next_in, n = e.input, f = e.avail_in, r = t.hold, _ = t.bits, t.mode === H1 && (t.back = -1);
                break;
            }
            for(t.back = 0; v = t.lencode[r & (1 << t.lenbits) - 1], w = v >>> 24, A = v >>> 16 & 255, x = v & 65535, !(w <= _);){
                if (f === 0) break e;
                f--, r += n[l++] << _, _ += 8;
            }
            if (A && (A & 240) === 0) {
                for(d = w, S = A, Z = x; v = t.lencode[Z + ((r & (1 << d + S) - 1) >> d)], w = v >>> 24, A = v >>> 16 & 255, x = v & 65535, !(d + w <= _);){
                    if (f === 0) break e;
                    f--, r += n[l++] << _, _ += 8;
                }
                r >>>= d, _ -= d, t.back += d;
            }
            if (r >>>= w, _ -= w, t.back += w, t.length = x, A === 0) {
                t.mode = qt;
                break;
            }
            if (A & 32) {
                t.back = -1, t.mode = H1;
                break;
            }
            if (A & 64) {
                e.msg = "invalid literal/length code", t.mode = T2;
                break;
            }
            t.extra = A & 15, t.mode = Wt;
        case Wt:
            if (t.extra) {
                for(p = t.extra; _ < p;){
                    if (f === 0) break e;
                    f--, r += n[l++] << _, _ += 8;
                }
                t.length += r & (1 << t.extra) - 1, r >>>= t.extra, _ -= t.extra, t.back += t.extra;
            }
            t.was = t.length, t.mode = Vt;
        case Vt:
            for(; v = t.distcode[r & (1 << t.distbits) - 1], w = v >>> 24, A = v >>> 16 & 255, x = v & 65535, !(w <= _);){
                if (f === 0) break e;
                f--, r += n[l++] << _, _ += 8;
            }
            if ((A & 240) === 0) {
                for(d = w, S = A, Z = x; v = t.distcode[Z + ((r & (1 << d + S) - 1) >> d)], w = v >>> 24, A = v >>> 16 & 255, x = v & 65535, !(d + w <= _);){
                    if (f === 0) break e;
                    f--, r += n[l++] << _, _ += 8;
                }
                r >>>= d, _ -= d, t.back += d;
            }
            if (r >>>= w, _ -= w, t.back += w, A & 64) {
                e.msg = "invalid distance code", t.mode = T2;
                break;
            }
            t.offset = x, t.extra = A & 15, t.mode = Jt;
        case Jt:
            if (t.extra) {
                for(p = t.extra; _ < p;){
                    if (f === 0) break e;
                    f--, r += n[l++] << _, _ += 8;
                }
                t.offset += r & (1 << t.extra) - 1, r >>>= t.extra, _ -= t.extra, t.back += t.extra;
            }
            if (t.offset > t.dmax) {
                e.msg = "invalid distance too far back", t.mode = T2;
                break;
            }
            t.mode = Qt;
        case Qt:
            if (c === 0) break e;
            if (h = s - c, t.offset > h) {
                if (h = t.offset - h, h > t.whave && t.sane) {
                    e.msg = "invalid distance too far back", t.mode = T2;
                    break;
                }
                h > t.wnext ? (h -= t.wnext, u = t.wsize - h) : u = t.wnext - h, h > t.length && (h = t.length), m = t.window;
            } else m = a, u = o - t.offset, h = t.length;
            h > c && (h = c), c -= h, t.length -= h;
            do a[o++] = m[u++];
            while (--h)
            t.length === 0 && (t.mode = Ue1);
            break;
        case qt:
            if (c === 0) break e;
            a[o++] = t.length, c--, t.mode = Ue1;
            break;
        case it:
            if (t.wrap) {
                for(; _ < 32;){
                    if (f === 0) break e;
                    f--, r |= n[l++] << _, _ += 8;
                }
                if (s -= c, e.total_out += s, t.total += s, s && (e.adler = t.check = t.flags ? I2(t.check, a, s, o - s) : ve1(t.check, a, s, o - s)), s = c, (t.flags ? r : ii(r)) !== t.check) {
                    e.msg = "incorrect data check", t.mode = T2;
                    break;
                }
                r = 0, _ = 0;
            }
            t.mode = ei;
        case ei:
            if (t.wrap && t.flags) {
                for(; _ < 32;){
                    if (f === 0) break e;
                    f--, r += n[l++] << _, _ += 8;
                }
                if (r !== (t.total & 4294967295)) {
                    e.msg = "incorrect length check", t.mode = T2;
                    break;
                }
                r = 0, _ = 0;
            }
            t.mode = ti;
        case ti:
            z = Fn;
            break e;
        case T2:
            z = mi;
            break e;
        case Ii:
            return Di;
        case Kn:
        default:
            return U1;
    }
    return e.next_out = o, e.avail_out = c, e.next_in = l, e.avail_in = f, t.hold = r, t.bits = _, (t.wsize || s !== e.avail_out && t.mode < T2 && (t.mode < it || i !== Ot)) && Ci(e, e.output, e.next_out, s - e.avail_out), E -= e.avail_in, s -= e.avail_out, e.total_in += E, e.total_out += s, t.total += s, t.wrap && s && (e.adler = t.check = t.flags ? I2(t.check, a, s, e.next_out - s) : ve1(t.check, a, s, e.next_out - s)), e.data_type = t.bits + (t.last ? 64 : 0) + (t.mode === H1 ? 128 : 0) + (t.mode === Le || t.mode === tt ? 256 : 0), (E === 0 && s === 0 || i === Ot) && z === ae1 && (z = Bn), z;
}, Qn = (e)=>{
    if (!e || !e.state) return U1;
    let i = e.state;
    return i.window && (i.window = null), e.state = null, ae1;
}, qn = (e, i)=>{
    if (!e || !e.state) return U1;
    let t = e.state;
    return (t.wrap & 2) === 0 ? U1 : (t.head = i, i.done = !1, ae1);
}, el = (e, i)=>{
    let t = i.length, n, a, l;
    return !e || !e.state || (n = e.state, n.wrap !== 0 && n.mode !== Ke) ? U1 : n.mode === Ke && (a = 1, a = ve1(a, i, t, 0), a !== n.check) ? mi : (l = Ci(e, i, t, t), l ? (n.mode = Ii, Di) : (n.havedict = 1, ae1));
}, tl = Ni, il = Li, al = Oi, nl = Wn, ll = Ui, rl = Jn, fl = Qn, ol = qn, _l = el, hl = "pako inflate (from Nodeca project)", K2 = {
    inflateReset: tl,
    inflateReset2: il,
    inflateResetKeep: al,
    inflateInit: nl,
    inflateInit2: ll,
    inflate: rl,
    inflateEnd: fl,
    inflateGetHeader: ol,
    inflateSetDictionary: _l,
    inflateInfo: hl
};
function dl() {
    this.text = 0, this.time = 0, this.xflags = 0, this.os = 0, this.extra = null, this.extra_len = 0, this.name = "", this.comment = "", this.hcrc = 0, this.done = !1;
}
var sl = dl, $i = Object.prototype.toString, { Z_NO_FLUSH: cl , Z_FINISH: ul , Z_OK: Se1 , Z_STREAM_END: lt , Z_NEED_DICT: rt , Z_STREAM_ERROR: bl , Z_DATA_ERROR: ni , Z_MEM_ERROR: wl  } = ne1;
function Te1(e) {
    this.options = Ye.assign({
        chunkSize: 1024 * 64,
        windowBits: 15,
        to: ""
    }, e || {});
    let i = this.options;
    i.raw && i.windowBits >= 0 && i.windowBits < 16 && (i.windowBits = -i.windowBits, i.windowBits === 0 && (i.windowBits = -15)), i.windowBits >= 0 && i.windowBits < 16 && !(e && e.windowBits) && (i.windowBits += 32), i.windowBits > 15 && i.windowBits < 48 && (i.windowBits & 15) === 0 && (i.windowBits |= 15), this.err = 0, this.msg = "", this.ended = !1, this.chunks = [], this.strm = new Ai, this.strm.avail_out = 0;
    let t = K2.inflateInit2(this.strm, i.windowBits);
    if (t !== Se1) throw new Error(ee1[t]);
    if (this.header = new sl, K2.inflateGetHeader(this.strm, this.header), i.dictionary && (typeof i.dictionary == "string" ? i.dictionary = ye1.string2buf(i.dictionary) : $i.call(i.dictionary) === "[object ArrayBuffer]" && (i.dictionary = new Uint8Array(i.dictionary)), i.raw && (t = K2.inflateSetDictionary(this.strm, i.dictionary), t !== Se1))) throw new Error(ee1[t]);
}
Te1.prototype.push = function(e, i) {
    let t = this.strm, n = this.options.chunkSize, a = this.options.dictionary, l, o, f;
    if (this.ended) return !1;
    for(i === ~~i ? o = i : o = i === !0 ? ul : cl, $i.call(e) === "[object ArrayBuffer]" ? t.input = new Uint8Array(e) : t.input = e, t.next_in = 0, t.avail_in = t.input.length;;){
        for(t.avail_out === 0 && (t.output = new Uint8Array(n), t.next_out = 0, t.avail_out = n), l = K2.inflate(t, o), l === rt && a && (l = K2.inflateSetDictionary(t, a), l === Se1 ? l = K2.inflate(t, o) : l === ni && (l = rt)); t.avail_in > 0 && l === lt && t.state.wrap > 0 && e[t.next_in] !== 0;)K2.inflateReset(t), l = K2.inflate(t, o);
        switch(l){
            case bl:
            case ni:
            case rt:
            case wl:
                return this.onEnd(l), this.ended = !0, !1;
        }
        if (f = t.avail_out, t.next_out && (t.avail_out === 0 || l === lt)) if (this.options.to === "string") {
            let c = ye1.utf8border(t.output, t.next_out), r = t.next_out - c, _ = ye1.buf2string(t.output, c);
            t.next_out = r, t.avail_out = n - r, r && t.output.set(t.output.subarray(c, c + r), 0), this.onData(_);
        } else this.onData(t.output.length === t.next_out ? t.output : t.output.subarray(0, t.next_out));
        if (!(l === Se1 && f === 0)) {
            if (l === lt) return l = K2.inflateEnd(this.strm), this.onEnd(l), this.ended = !0, !0;
            if (t.avail_in === 0) break;
        }
    }
    return !0;
};
Te1.prototype.onData = function(e) {
    this.chunks.push(e);
};
Te1.prototype.onEnd = function(e) {
    e === Se1 && (this.options.to === "string" ? this.result = this.chunks.join("") : this.result = Ye.flattenChunks(this.chunks)), this.chunks = [], this.err = e, this.msg = this.strm.msg;
};
function wt(e, i) {
    let t = new Te1(i);
    if (t.push(e), t.err) throw t.msg || ee1[t.err];
    return t.result;
}
function gl(e, i) {
    return i = i || {}, i.raw = !0, wt(e, i);
}
var pl = Te1, xl = wt, kl = gl, vl = wt, El = ne1, yl = {
    Inflate: pl,
    inflate: xl,
    inflateRaw: kl,
    ungzip: vl,
    constants: El
}, { Deflate: Sl , deflate: Al , deflateRaw: Rl , gzip: zl  } = Dn, { Inflate: Tl , inflate: ml , inflateRaw: Dl , ungzip: Zl  } = yl, Ol = Al, Cl = ml;
const UpdateObservable = "0";
class Retain {
    constructor(value){
        this.value = value;
    }
}
const OnjsCallback = "1";
const EvalJavascript = "2";
const JavascriptError = "3";
const JavascriptWarning = "4";
const RegisterObservable = "5";
const JSDoneLoading = "8";
const FusedMessage = "9";
const CloseSession = "10";
const PingPong = "11";
const UpdateSession = "12";
const CONNECTION = {
    send_message: undefined,
    queue: [],
    status: "closed"
};
function on_connection_open(send_message_callback, compression_enabled) {
    CONNECTION.send_message = send_message_callback;
    CONNECTION.status = "open";
    CONNECTION.compression_enabled = compression_enabled;
    CONNECTION.queue.forEach((message)=>send_to_julia(message));
}
function on_connection_close() {
    CONNECTION.status = "closed";
}
const EXTENSION_CODEC = new I1();
window.EXTENSION_CODEC = EXTENSION_CODEC;
function unpack(uint8array) {
    return Te(uint8array, {
        extensionCodec: EXTENSION_CODEC
    });
}
function pack(object) {
    return ve(object, {
        extensionCodec: EXTENSION_CODEC
    });
}
function reinterpret_array(ArrayType, uint8array) {
    if (ArrayType === Uint8Array) {
        return uint8array;
    } else {
        const bo = uint8array.byteOffset;
        const bpe = ArrayType.BYTES_PER_ELEMENT;
        const new_array_length = uint8array.byteLength / bpe;
        const buffer = uint8array.buffer.slice(bo, bo + uint8array.byteLength);
        return new ArrayType(buffer, 0, new_array_length);
    }
}
function register_ext_array(type_tag, array_type) {
    EXTENSION_CODEC.register({
        type: type_tag,
        decode: (uint8array)=>reinterpret_array(array_type, uint8array),
        encode: (object)=>{
            if (object instanceof array_type) {
                return new Uint8Array(object.buffer, object.byteOffset, object.byteLength);
            } else {
                return null;
            }
        }
    });
}
register_ext_array(0x11, Int8Array);
register_ext_array(0x12, Uint8Array);
register_ext_array(0x13, Int16Array);
register_ext_array(0x14, Uint16Array);
register_ext_array(0x15, Int32Array);
register_ext_array(0x16, Uint32Array);
register_ext_array(0x17, Float32Array);
register_ext_array(0x18, Float64Array);
function register_ext(type_tag, decode, encode) {
    EXTENSION_CODEC.register({
        type: type_tag,
        decode,
        encode
    });
}
class JLArray {
    constructor(size, array){
        this.size = size;
        this.array = array;
    }
}
register_ext(99, (uint_8_array)=>{
    const [size, array] = unpack(uint_8_array);
    return new JLArray(size, array);
}, (object)=>{
    if (object instanceof JLArray) {
        return pack([
            object.size,
            object.array
        ]);
    } else {
        return null;
    }
});
function send_error(message, exception) {
    console.error(message);
    console.error(exception);
    send_to_julia({
        msg_type: JavascriptError,
        message: message,
        exception: String(exception),
        stacktrace: exception === null ? "" : exception.stack
    });
}
const SESSIONS = {};
const GLOBAL_OBJECT_CACHE = {};
function send_pingpong() {
    send_to_julia({
        msg_type: PingPong
    });
}
function encode_binary(data, compression_enabled) {
    if (compression_enabled) {
        return pack(Ol(pack(data)));
    } else {
        return pack(data);
    }
}
function send_to_julia(message) {
    const { send_message , status , compression_enabled  } = CONNECTION;
    if (send_message && status === "open") {
        send_message(encode_binary(message, compression_enabled));
    } else if (status === "closed") {
        CONNECTION.queue.push(message);
    } else {
        console.log("Trying to send messages while connection is offline");
    }
}
class Observable {
    #callbacks = [];
    constructor(id, value){
        this.id = id;
        this.value = value;
    }
    notify(value, dont_notify_julia) {
        if (value) {
            this.value = value;
        }
        this.#callbacks.forEach((callback)=>{
            try {
                const deregister = callback(value);
                if (deregister == false) {
                    this.#callbacks.splice(this.#callbacks.indexOf(callback), 1);
                }
            } catch (exception) {
                send_error("Error during running onjs callback\n" + "Callback:\n" + callback.toString(), exception);
            }
        });
        if (!dont_notify_julia) {
            send_to_julia({
                msg_type: UpdateObservable,
                id: this.id,
                payload: value
            });
        }
    }
    on(callback) {
        this.#callbacks.push(callback);
    }
}
register_ext(101, (uint_8_array)=>{
    const [id, value] = unpack(uint_8_array);
    return new Observable(id, value);
});
register_ext(102, (uint_8_array)=>{
    const [interpolated_objects, source, julia_file] = unpack(uint_8_array);
    const lookup_interpolated = (id)=>interpolated_objects[id];
    try {
        const eval_func = new Function("__lookup_interpolated", "JSServe", source);
        return ()=>{
            try {
                return eval_func(lookup_interpolated, window.JSServe);
            } catch (err) {
                console.log(`error in closure from: ${julia_file}`);
                console.log(`Source:`);
                console.log(source);
                throw err;
            }
        };
    } catch (err) {
        console.log(`error in closure from: ${julia_file}`);
        console.log(`Source:`);
        console.log(source);
        throw err;
    }
});
register_ext(103, (uint_8_array)=>{
    const real_value = unpack(uint_8_array);
    return new Retain(real_value);
});
function send_warning(message) {
    console.warn(message);
    send_to_julia({
        msg_type: JavascriptWarning,
        message: message
    });
}
function send_done_loading(session, exception) {
    send_to_julia({
        msg_type: JSDoneLoading,
        session,
        message: "",
        exception: exception === null ? "nothing" : String(exception),
        stacktrace: exception === null ? "" : exception.stack
    });
}
function send_close_session(session, subsession) {
    send_to_julia({
        msg_type: CloseSession,
        session,
        subsession
    });
}
class Lock {
    constructor(){
        this.locked = false;
        this.queue = [];
        this.locking_tasks = new Set();
    }
    unlock() {
        this.locked = false;
        if (this.queue.length > 0) {
            const job = this.queue.pop();
            this.lock(job);
        }
    }
    task_lock(task_id) {
        this.locking_tasks.add(task_id);
        this.locked = true;
    }
    task_unlock(task_id) {
        this.locking_tasks.delete(task_id);
        if (this.locking_tasks.size == 0) {
            this.unlock();
        }
    }
    lock(func) {
        return new Promise((resolve)=>{
            if (this.locked) {
                const func_res = ()=>Promise.resolve(func()).then(resolve);
                this.queue.push(func_res);
            } else {
                this.locked = true;
                Promise.resolve(func()).then((x)=>{
                    this.unlock();
                    resolve(x);
                });
            }
        });
    }
}
const MESSAGE_PROCESS_LOCK = new Lock();
function with_message_lock(func) {
    return MESSAGE_PROCESS_LOCK.lock(func);
}
function process_message(data) {
    try {
        switch(data.msg_type){
            case UpdateObservable:
                lookup_global_object(data.id).notify(data.payload, true);
                break;
            case OnjsCallback:
                data.obs.on(data.payload());
                break;
            case EvalJavascript:
                data.payload();
                break;
            case FusedMessage:
                data.payload.forEach(process_message);
                break;
            case PingPong:
                console.debug("ping");
                break;
            case UpdateSession:
                update_session_dom(data);
                break;
            default:
                throw new Error("Unrecognized message type: " + data.msg_type + ".");
        }
    } catch (e) {
        send_error(`Error while processing message ${JSON.stringify(data)}`, e);
    }
}
const mod = {
    UpdateObservable: UpdateObservable,
    OnjsCallback: OnjsCallback,
    EvalJavascript: EvalJavascript,
    JavascriptError: JavascriptError,
    JavascriptWarning: JavascriptWarning,
    RegisterObservable: RegisterObservable,
    JSDoneLoading: JSDoneLoading,
    FusedMessage: FusedMessage,
    on_connection_open: on_connection_open,
    on_connection_close: on_connection_close,
    send_to_julia: send_to_julia,
    send_pingpong: send_pingpong,
    send_error: send_error,
    send_warning: send_warning,
    send_done_loading: send_done_loading,
    send_close_session: send_close_session,
    Lock: Lock,
    with_message_lock: with_message_lock,
    process_message: process_message
};
const OBJECT_FREEING_LOCK = new Lock();
const SESSION_LOAD_LOCK = new Lock();
function lock_loading(f) {
    SESSION_LOAD_LOCK.lock(f);
}
function lookup_global_object(key) {
    const object = GLOBAL_OBJECT_CACHE[key];
    if (object) {
        if (object instanceof Retain) {
            return object.value;
        } else {
            return object;
        }
    }
    throw new Error(`Key ${key} not found! ${object}`);
}
function is_still_referenced(id) {
    for(const session_id in SESSIONS){
        const [tracked_objects, allow_delete] = SESSIONS[session_id];
        if (allow_delete && tracked_objects.has(id)) {
            return true;
        }
    }
    return false;
}
function free_object(id) {
    const data = GLOBAL_OBJECT_CACHE[id];
    if (data) {
        if (data instanceof Promise) {
            return;
        }
        if (data instanceof Retain) {
            return;
        }
        if (!is_still_referenced(id)) {
            delete GLOBAL_OBJECT_CACHE[id];
        }
        return;
    } else {
        send_warning(`Trying to delete object ${id}, which is not in global session cache.`);
    }
    return;
}
let DELETE_OBSERVER = undefined;
function track_deleted_sessions() {
    if (!DELETE_OBSERVER) {
        const observer = new MutationObserver(function(mutations) {
            let removal_occured = false;
            const to_delete = new Set();
            mutations.forEach((mutation)=>{
                mutation.removedNodes.forEach((x)=>{
                    if (x.id in SESSIONS) {
                        const status = SESSIONS[x.id][1];
                        if (status === "delete") {
                            to_delete.add(x.id);
                        }
                    } else {
                        removal_occured = true;
                    }
                });
            });
            if (removal_occured) {
                Object.keys(SESSIONS).forEach((id)=>{
                    const status = SESSIONS[id][1];
                    if (status === "delete") {
                        if (!document.getElementById(id)) {
                            console.debug(`adding session to delete candidates: ${id}`);
                            to_delete.add(id);
                        }
                    }
                });
            }
            to_delete.forEach((id)=>{
                close_session(id);
            });
        });
        observer.observe(document, {
            attributes: false,
            childList: true,
            characterData: false,
            subtree: true
        });
        DELETE_OBSERVER = observer;
    }
}
function done_initializing_session(session_id) {
    if (!(session_id in SESSIONS)) {
        throw new Error("Session ");
    }
    send_done_loading(session_id, null);
    if (SESSIONS[session_id][1] != "root") {
        SESSIONS[session_id][1] = "delete";
    }
    console.log(`session ${session_id} fully initialized`);
}
register_ext(104, (uint_8_array)=>{
    const key = unpack(uint_8_array);
    return lookup_global_object(key);
});
function create_tag(tag, attributes) {
    if (attributes.juliasvgnode) {
        return document.createElementNS("http://www.w3.org/2000/svg", tag);
    } else {
        return document.createElement(tag);
    }
}
register_ext(105, (uint_8_array)=>{
    const [tag, children, attributes] = unpack(uint_8_array);
    const node = create_tag(tag, attributes);
    Object.keys(attributes).forEach((key)=>{
        if (key == "juliasvgnode") {
            return;
        }
        if (key == "class") {
            node.className = attributes[key];
        } else {
            node.setAttribute(key, attributes[key]);
        }
    });
    children.forEach((child)=>node.append(child));
    return node;
});
function decode_binary(binary, compression_enabled) {
    const serialized_message = unpack_binary(binary, compression_enabled);
    const [session_id, message_data] = serialized_message;
    return message_data;
}
function init_session(session_id, binary_messages, session_status) {
    track_deleted_sessions();
    OBJECT_FREEING_LOCK.task_lock(session_id);
    try {
        SESSIONS[session_id] = [
            new Set(),
            session_status
        ];
        console.log(`init session: ${session_id}, ${session_status}`);
        if (binary_messages) {
            process_message(decode_binary(binary_messages));
        }
        done_initializing_session(session_id);
    } catch (error) {
        send_done_loading(session_id, error);
        console.error(error.stack);
        throw error;
    } finally{
        OBJECT_FREEING_LOCK.task_unlock(session_id);
    }
}
function close_session(session_id) {
    const session = SESSIONS[session_id];
    if (!session) {
        console.error("double freeing session!");
        return;
    }
    const [session_objects, status] = session;
    const root_node = document.getElementById(session_id);
    if (root_node) {
        root_node.style.display = "none";
        root_node.parentNode.removeChild(root_node);
    }
    if (status === "delete") {
        send_close_session(session_id, status);
        SESSIONS[session_id] = [
            session_objects,
            false
        ];
    }
    return;
}
function free_session(session_id) {
    OBJECT_FREEING_LOCK.lock(()=>{
        console.log(`actually freeing session ${session_id}`);
        const session = SESSIONS[session_id];
        if (!session) {
            console.error("double freeing session!");
            return;
        }
        const [tracked_objects, status] = session;
        tracked_objects.forEach(free_object);
        tracked_objects.clear();
        delete SESSIONS[session_id];
    });
}
function on_node_available(node_id, timeout) {
    return new Promise((resolve)=>{
        function test_node(timeout) {
            const node = document.querySelector(`[data-jscall-id='${node_id}']`);
            if (node) {
                resolve(node);
            } else {
                const new_timeout = 2 * timeout;
                console.log(new_timeout);
                setTimeout(test_node, new_timeout, new_timeout);
            }
        }
        test_node(timeout);
    });
}
function update_or_replace(node, new_html, replace) {
    if (replace) {
        node.parentNode.replaceChild(new_html, node);
    } else {
        while(node.childElementCount > 0){
            node.removeChild(node.firstChild);
        }
        node.append(new_html);
    }
}
function update_session_dom(message) {
    const { session_id , messages , html , dom_node_selector , replace  } = message;
    on_node_available(dom_node_selector, 1).then((dom)=>{
        try {
            update_or_replace(dom, html, replace);
            process_message(messages);
            done_initializing_session(session_id);
        } catch (error) {
            send_done_loading(session_id, error);
            console.error(error.stack);
            throw error;
        } finally{
            OBJECT_FREEING_LOCK.task_unlock(session_id);
        }
    });
    return;
}
function update_session_cache(session_id, new_jl_objects, session_status) {
    function update_cache(tracked_objects) {
        for(const key in new_jl_objects){
            tracked_objects.add(key);
            const new_object = new_jl_objects[key];
            if (new_object == "tracking-only") {
                if (!(key in GLOBAL_OBJECT_CACHE)) {
                    throw new Error(`Key ${key} only send for tracking, but not already tracked!!!`);
                }
            } else {
                if (!(key in GLOBAL_OBJECT_CACHE)) {
                    GLOBAL_OBJECT_CACHE[key] = new_object;
                } else {
                    console.warn(`${key} in session cache and send again!!`);
                }
            }
        }
    }
    const session = SESSIONS[session_id];
    if (session) {
        update_cache(session[0]);
    } else {
        OBJECT_FREEING_LOCK.task_lock(session_id);
        const tracked_items = new Set();
        SESSIONS[session_id] = [
            tracked_items,
            session_status
        ];
        update_cache(tracked_items);
    }
}
const mod1 = {
    SESSIONS: SESSIONS,
    GLOBAL_OBJECT_CACHE: GLOBAL_OBJECT_CACHE,
    lock_loading: lock_loading,
    lookup_global_object: lookup_global_object,
    track_deleted_sessions: track_deleted_sessions,
    done_initializing_session: done_initializing_session,
    init_session: init_session,
    close_session: close_session,
    free_session: free_session,
    on_node_available: on_node_available,
    update_or_replace: update_or_replace,
    update_session_dom: update_session_dom,
    update_session_cache: update_session_cache
};
register_ext(106, (uint_8_array)=>{
    const [session_id, objects, session_status] = unpack(uint_8_array);
    update_session_cache(session_id, objects, session_status);
    return session_id;
});
register_ext(107, (uint_8_array)=>{
    const [session_id, message] = unpack(uint_8_array);
    return message;
});
function base64encode(data_as_uint8array) {
    const base64_promise = new Promise((resolve)=>{
        const reader = new FileReader();
        reader.onload = ()=>{
            const len = 37;
            const base64url = reader.result;
            resolve(base64url.slice(len, base64url.length));
        };
        reader.readAsDataURL(new Blob([
            data_as_uint8array
        ]));
    });
    return base64_promise;
}
function base64decode(base64_str) {
    return new Promise((resolve)=>{
        fetch("data:application/octet-stream;base64," + base64_str).then((response)=>{
            response.arrayBuffer().then((array)=>{
                resolve(new Uint8Array(array));
            });
        });
    });
}
function decode_base64_message(base64_string, compression_enabled) {
    return base64decode(base64_string).then((x)=>decode_binary(x, compression_enabled));
}
function unpack_binary(binary, compression_enabled) {
    if (compression_enabled) {
        return unpack(Cl(binary));
    } else {
        return unpack(binary);
    }
}
const mod2 = {
    Retain: Retain,
    base64encode: base64encode,
    base64decode: base64decode,
    decode_base64_message: decode_base64_message,
    decode_binary: decode_binary,
    unpack_binary: unpack_binary,
    encode_binary: encode_binary
};
function onany(observables, f) {
    const callback = (x)=>f(observables.map((x)=>x.value));
    observables.forEach((obs)=>{
        obs.on(callback);
    });
}
const { send_error: send_error1 , send_warning: send_warning1 , process_message: process_message1 , on_connection_open: on_connection_open1 , on_connection_close: on_connection_close1 , send_close_session: send_close_session1 , send_pingpong: send_pingpong1 , with_message_lock: with_message_lock1  } = mod;
const { base64decode: base64decode1 , base64encode: base64encode1 , decode_binary: decode_binary1 , encode_binary: encode_binary1 , decode_base64_message: decode_base64_message1  } = mod2;
const { init_session: init_session1 , free_session: free_session1 , lookup_global_object: lookup_global_object1 , update_or_replace: update_or_replace1 , lock_loading: lock_loading1  } = mod1;
function update_node_attribute(node, attribute, value) {
    if (node) {
        if (node[attribute] != value) {
            node[attribute] = value;
        }
        return true;
    } else {
        return false;
    }
}
function update_dom_node(dom, html) {
    if (dom) {
        dom.innerHTML = html;
        return true;
    } else {
        return false;
    }
}
function fetch_binary(url) {
    return fetch(url).then((response)=>{
        if (!response.ok) {
            throw new Error("HTTP error, status = " + response.status);
        }
        return response.arrayBuffer();
    });
}
const JSServe = {
    Protocol: mod2,
    base64decode: base64decode1,
    base64encode: base64encode1,
    decode_binary: decode_binary1,
    encode_binary: encode_binary1,
    decode_base64_message: decode_base64_message1,
    fetch_binary,
    Connection: mod,
    send_error: send_error1,
    send_warning: send_warning1,
    process_message: process_message1,
    on_connection_open: on_connection_open1,
    on_connection_close: on_connection_close1,
    send_close_session: send_close_session1,
    send_pingpong: send_pingpong1,
    with_message_lock: with_message_lock1,
    Sessions: mod1,
    init_session: init_session1,
    free_session: free_session1,
    lock_loading: lock_loading1,
    update_node_attribute,
    update_dom_node,
    lookup_global_object: lookup_global_object1,
    update_or_replace: update_or_replace1,
    onany
};
window.JSServe = JSServe;
export { mod2 as Protocol, base64decode1 as base64decode, base64encode1 as base64encode, decode_binary1 as decode_binary, encode_binary1 as encode_binary, decode_base64_message1 as decode_base64_message, mod as Connection, send_error1 as send_error, send_warning1 as send_warning, process_message1 as process_message, on_connection_open1 as on_connection_open, on_connection_close1 as on_connection_close, send_close_session1 as send_close_session, send_pingpong1 as send_pingpong, with_message_lock1 as with_message_lock, mod1 as Sessions, init_session1 as init_session, free_session1 as free_session, lock_loading1 as lock_loading, update_node_attribute as update_node_attribute, update_dom_node as update_dom_node, lookup_global_object1 as lookup_global_object, update_or_replace1 as update_or_replace, onany as onany };

