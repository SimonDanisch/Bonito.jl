// deno-fmt-ignore-file
// deno-lint-ignore-file
// This code was bundled using `deno bundle` and it's not recommended to edit it manually

var ar = Object.create;
var qe = Object.defineProperty;
var sr = Object.getOwnPropertyDescriptor;
var nr = Object.getOwnPropertyNames;
var or = Object.getPrototypeOf, lr = Object.prototype.hasOwnProperty;
var fr = (p, A)=>()=>(A || p((A = {
            exports: {}
        }).exports, A), A.exports);
var ur = (p, A, j, X)=>{
    if (A && typeof A == "object" || typeof A == "function") for (let R of nr(A))!lr.call(p, R) && R !== j && qe(p, R, {
        get: ()=>A[R],
        enumerable: !(X = sr(A, R)) || X.enumerable
    });
    return p;
};
var cr = (p, A, j)=>(j = p != null ? ar(or(p)) : {}, ur(A || !p || !p.__esModule ? qe(j, "default", {
        value: p,
        enumerable: !0
    }) : j, p));
var Xe = fr((re, Ie)=>{
    (function(p, A) {
        typeof re == "object" && typeof Ie < "u" ? A(re) : typeof define == "function" && define.amd ? define([
            "exports"
        ], A) : (p = typeof globalThis < "u" ? globalThis : p || self, A(p.noUiSlider = {}));
    })(re, function(p) {
        "use strict";
        p.PipsMode = void 0, function(t) {
            t.Range = "range", t.Steps = "steps", t.Positions = "positions", t.Count = "count", t.Values = "values";
        }(p.PipsMode || (p.PipsMode = {})), p.PipsType = void 0, function(t) {
            t[t.None = -1] = "None", t[t.NoValue = 0] = "NoValue", t[t.LargeValue = 1] = "LargeValue", t[t.SmallValue = 2] = "SmallValue";
        }(p.PipsType || (p.PipsType = {}));
        function A(t) {
            return j(t) && typeof t.from == "function";
        }
        function j(t) {
            return typeof t == "object" && typeof t.to == "function";
        }
        function X(t) {
            t.parentElement.removeChild(t);
        }
        function R(t) {
            return t != null;
        }
        function be(t) {
            t.preventDefault();
        }
        function Ge(t) {
            return t.filter(function(e) {
                return this[e] ? !1 : this[e] = !0;
            }, {});
        }
        function Je(t, e) {
            return Math.round(t / e) * e;
        }
        function Ze(t, e) {
            var n = t.getBoundingClientRect(), f = t.ownerDocument, u = f.documentElement, m = Ce(f);
            return /webkit.*Chrome.*Mobile/i.test(navigator.userAgent) && (m.x = 0), e ? n.top + m.y - u.clientTop : n.left + m.x - u.clientLeft;
        }
        function H(t) {
            return typeof t == "number" && !isNaN(t) && isFinite(t);
        }
        function xe(t, e, n) {
            n > 0 && (_(t, e), setTimeout(function() {
                J(t, e);
            }, n));
        }
        function Ee(t) {
            return Math.max(Math.min(t, 100), 0);
        }
        function G(t) {
            return Array.isArray(t) ? t : [
                t
            ];
        }
        function $e(t) {
            t = String(t);
            var e = t.split(".");
            return e.length > 1 ? e[1].length : 0;
        }
        function _(t, e) {
            t.classList && !/\s/.test(e) ? t.classList.add(e) : t.className += " " + e;
        }
        function J(t, e) {
            t.classList && !/\s/.test(e) ? t.classList.remove(e) : t.className = t.className.replace(new RegExp("(^|\\b)" + e.split(" ").join("|") + "(\\b|$)", "gi"), " ");
        }
        function Qe(t, e) {
            return t.classList ? t.classList.contains(e) : new RegExp("\\b" + e + "\\b").test(t.className);
        }
        function Ce(t) {
            var e = window.pageXOffset !== void 0, n = (t.compatMode || "") === "CSS1Compat", f = e ? window.pageXOffset : n ? t.documentElement.scrollLeft : t.body.scrollLeft, u = e ? window.pageYOffset : n ? t.documentElement.scrollTop : t.body.scrollTop;
            return {
                x: f,
                y: u
            };
        }
        function et() {
            return window.navigator.pointerEnabled ? {
                start: "pointerdown",
                move: "pointermove",
                end: "pointerup"
            } : window.navigator.msPointerEnabled ? {
                start: "MSPointerDown",
                move: "MSPointerMove",
                end: "MSPointerUp"
            } : {
                start: "mousedown touchstart",
                move: "mousemove touchmove",
                end: "mouseup touchend"
            };
        }
        function tt() {
            var t = !1;
            try {
                var e = Object.defineProperty({}, "passive", {
                    get: function() {
                        t = !0;
                    }
                });
                window.addEventListener("test", null, e);
            } catch  {}
            return t;
        }
        function rt() {
            return window.CSS && CSS.supports && CSS.supports("touch-action", "none");
        }
        function ie(t, e) {
            return 100 / (e - t);
        }
        function ae(t, e, n) {
            return e * 100 / (t[n + 1] - t[n]);
        }
        function it(t, e) {
            return ae(t, t[0] < 0 ? e + Math.abs(t[0]) : e - t[0], 0);
        }
        function at(t, e) {
            return e * (t[1] - t[0]) / 100 + t[0];
        }
        function Y(t, e) {
            for(var n = 1; t >= e[n];)n += 1;
            return n;
        }
        function st(t, e, n) {
            if (n >= t.slice(-1)[0]) return 100;
            var f = Y(n, t), u = t[f - 1], m = t[f], d = e[f - 1], x = e[f];
            return d + it([
                u,
                m
            ], n) / ie(d, x);
        }
        function nt(t, e, n) {
            if (n >= 100) return t.slice(-1)[0];
            var f = Y(n, e), u = t[f - 1], m = t[f], d = e[f - 1], x = e[f];
            return at([
                u,
                m
            ], (n - d) * ie(d, x));
        }
        function ot(t, e, n, f) {
            if (f === 100) return f;
            var u = Y(f, t), m = t[u - 1], d = t[u];
            return n ? f - m > (d - m) / 2 ? d : m : e[u - 1] ? t[u - 1] + Je(f - t[u - 1], e[u - 1]) : f;
        }
        var Pe = function() {
            function t(e, n, f) {
                this.xPct = [], this.xVal = [], this.xSteps = [], this.xNumSteps = [], this.xHighestCompleteStep = [], this.xSteps = [
                    f || !1
                ], this.xNumSteps = [
                    !1
                ], this.snap = n;
                var u, m = [];
                for(Object.keys(e).forEach(function(d) {
                    m.push([
                        G(e[d]),
                        d
                    ]);
                }), m.sort(function(d, x) {
                    return d[0][0] - x[0][0];
                }), u = 0; u < m.length; u++)this.handleEntryPoint(m[u][1], m[u][0]);
                for(this.xNumSteps = this.xSteps.slice(0), u = 0; u < this.xNumSteps.length; u++)this.handleStepPoint(u, this.xNumSteps[u]);
            }
            return t.prototype.getDistance = function(e) {
                for(var n = [], f = 0; f < this.xNumSteps.length - 1; f++)n[f] = ae(this.xVal, e, f);
                return n;
            }, t.prototype.getAbsoluteDistance = function(e, n, f) {
                var u = 0;
                if (e < this.xPct[this.xPct.length - 1]) for(; e > this.xPct[u + 1];)u++;
                else e === this.xPct[this.xPct.length - 1] && (u = this.xPct.length - 2);
                !f && e === this.xPct[u + 1] && u++, n === null && (n = []);
                var m, d = 1, x = n[u], v = 0, L = 0, z = 0, D = 0;
                for(f ? m = (e - this.xPct[u]) / (this.xPct[u + 1] - this.xPct[u]) : m = (this.xPct[u + 1] - e) / (this.xPct[u + 1] - this.xPct[u]); x > 0;)v = this.xPct[u + 1 + D] - this.xPct[u + D], n[u + D] * d + 100 - m * 100 > 100 ? (L = v * m, d = (x - 100 * m) / n[u + D], m = 1) : (L = n[u + D] * v / 100 * d, d = 0), f ? (z = z - L, this.xPct.length + D >= 1 && D--) : (z = z + L, this.xPct.length - D >= 1 && D++), x = n[u + D] * d;
                return e + z;
            }, t.prototype.toStepping = function(e) {
                return e = st(this.xVal, this.xPct, e), e;
            }, t.prototype.fromStepping = function(e) {
                return nt(this.xVal, this.xPct, e);
            }, t.prototype.getStep = function(e) {
                return e = ot(this.xPct, this.xSteps, this.snap, e), e;
            }, t.prototype.getDefaultStep = function(e, n, f) {
                var u = Y(e, this.xPct);
                return (e === 100 || n && e === this.xPct[u - 1]) && (u = Math.max(u - 1, 1)), (this.xVal[u] - this.xVal[u - 1]) / f;
            }, t.prototype.getNearbySteps = function(e) {
                var n = Y(e, this.xPct);
                return {
                    stepBefore: {
                        startValue: this.xVal[n - 2],
                        step: this.xNumSteps[n - 2],
                        highestStep: this.xHighestCompleteStep[n - 2]
                    },
                    thisStep: {
                        startValue: this.xVal[n - 1],
                        step: this.xNumSteps[n - 1],
                        highestStep: this.xHighestCompleteStep[n - 1]
                    },
                    stepAfter: {
                        startValue: this.xVal[n],
                        step: this.xNumSteps[n],
                        highestStep: this.xHighestCompleteStep[n]
                    }
                };
            }, t.prototype.countStepDecimals = function() {
                var e = this.xNumSteps.map($e);
                return Math.max.apply(null, e);
            }, t.prototype.hasNoSize = function() {
                return this.xVal[0] === this.xVal[this.xVal.length - 1];
            }, t.prototype.convert = function(e) {
                return this.getStep(this.toStepping(e));
            }, t.prototype.handleEntryPoint = function(e, n) {
                var f;
                if (e === "min" ? f = 0 : e === "max" ? f = 100 : f = parseFloat(e), !H(f) || !H(n[0])) throw new Error("noUiSlider: 'range' value isn't numeric.");
                this.xPct.push(f), this.xVal.push(n[0]);
                var u = Number(n[1]);
                f ? this.xSteps.push(isNaN(u) ? !1 : u) : isNaN(u) || (this.xSteps[0] = u), this.xHighestCompleteStep.push(0);
            }, t.prototype.handleStepPoint = function(e, n) {
                if (!!n) {
                    if (this.xVal[e] === this.xVal[e + 1]) {
                        this.xSteps[e] = this.xHighestCompleteStep[e] = this.xVal[e];
                        return;
                    }
                    this.xSteps[e] = ae([
                        this.xVal[e],
                        this.xVal[e + 1]
                    ], n, 0) / ie(this.xPct[e], this.xPct[e + 1]);
                    var f = (this.xVal[e + 1] - this.xVal[e]) / this.xNumSteps[e], u = Math.ceil(Number(f.toFixed(3)) - 1), m = this.xVal[e] + this.xNumSteps[e] * u;
                    this.xHighestCompleteStep[e] = m;
                }
            }, t;
        }(), ye = {
            to: function(t) {
                return t === void 0 ? "" : t.toFixed(2);
            },
            from: Number
        }, se = {
            target: "target",
            base: "base",
            origin: "origin",
            handle: "handle",
            handleLower: "handle-lower",
            handleUpper: "handle-upper",
            touchArea: "touch-area",
            horizontal: "horizontal",
            vertical: "vertical",
            background: "background",
            connect: "connect",
            connects: "connects",
            ltr: "ltr",
            rtl: "rtl",
            textDirectionLtr: "txt-dir-ltr",
            textDirectionRtl: "txt-dir-rtl",
            draggable: "draggable",
            drag: "state-drag",
            tap: "state-tap",
            active: "active",
            tooltip: "tooltip",
            pips: "pips",
            pipsHorizontal: "pips-horizontal",
            pipsVertical: "pips-vertical",
            marker: "marker",
            markerHorizontal: "marker-horizontal",
            markerVertical: "marker-vertical",
            markerNormal: "marker-normal",
            markerLarge: "marker-large",
            markerSub: "marker-sub",
            value: "value",
            valueHorizontal: "value-horizontal",
            valueVertical: "value-vertical",
            valueNormal: "value-normal",
            valueLarge: "value-large",
            valueSub: "value-sub"
        }, B = {
            tooltips: ".__tooltips",
            aria: ".__aria"
        };
        function lt(t, e) {
            if (!H(e)) throw new Error("noUiSlider: 'step' is not numeric.");
            t.singleStep = e;
        }
        function ft(t, e) {
            if (!H(e)) throw new Error("noUiSlider: 'keyboardPageMultiplier' is not numeric.");
            t.keyboardPageMultiplier = e;
        }
        function ut(t, e) {
            if (!H(e)) throw new Error("noUiSlider: 'keyboardMultiplier' is not numeric.");
            t.keyboardMultiplier = e;
        }
        function ct(t, e) {
            if (!H(e)) throw new Error("noUiSlider: 'keyboardDefaultStep' is not numeric.");
            t.keyboardDefaultStep = e;
        }
        function ht(t, e) {
            if (typeof e != "object" || Array.isArray(e)) throw new Error("noUiSlider: 'range' is not an object.");
            if (e.min === void 0 || e.max === void 0) throw new Error("noUiSlider: Missing 'min' or 'max' in 'range'.");
            t.spectrum = new Pe(e, t.snap || !1, t.singleStep);
        }
        function pt(t, e) {
            if (e = G(e), !Array.isArray(e) || !e.length) throw new Error("noUiSlider: 'start' option is incorrect.");
            t.handles = e.length, t.start = e;
        }
        function dt(t, e) {
            if (typeof e != "boolean") throw new Error("noUiSlider: 'snap' option must be a boolean.");
            t.snap = e;
        }
        function vt(t, e) {
            if (typeof e != "boolean") throw new Error("noUiSlider: 'animate' option must be a boolean.");
            t.animate = e;
        }
        function mt(t, e) {
            if (typeof e != "number") throw new Error("noUiSlider: 'animationDuration' option must be a number.");
            t.animationDuration = e;
        }
        function gt(t, e) {
            var n = [
                !1
            ], f;
            if (e === "lower" ? e = [
                !0,
                !1
            ] : e === "upper" && (e = [
                !1,
                !0
            ]), e === !0 || e === !1) {
                for(f = 1; f < t.handles; f++)n.push(e);
                n.push(!1);
            } else {
                if (!Array.isArray(e) || !e.length || e.length !== t.handles + 1) throw new Error("noUiSlider: 'connect' option doesn't match handle count.");
                n = e;
            }
            t.connect = n;
        }
        function St(t, e) {
            switch(e){
                case "horizontal":
                    t.ort = 0;
                    break;
                case "vertical":
                    t.ort = 1;
                    break;
                default:
                    throw new Error("noUiSlider: 'orientation' option is invalid.");
            }
        }
        function Ve(t, e) {
            if (!H(e)) throw new Error("noUiSlider: 'margin' option must be numeric.");
            e !== 0 && (t.margin = t.spectrum.getDistance(e));
        }
        function wt(t, e) {
            if (!H(e)) throw new Error("noUiSlider: 'limit' option must be numeric.");
            if (t.limit = t.spectrum.getDistance(e), !t.limit || t.handles < 2) throw new Error("noUiSlider: 'limit' option is only supported on linear sliders with 2 or more handles.");
        }
        function bt(t, e) {
            var n;
            if (!H(e) && !Array.isArray(e)) throw new Error("noUiSlider: 'padding' option must be numeric or array of exactly 2 numbers.");
            if (Array.isArray(e) && !(e.length === 2 || H(e[0]) || H(e[1]))) throw new Error("noUiSlider: 'padding' option must be numeric or array of exactly 2 numbers.");
            if (e !== 0) {
                for(Array.isArray(e) || (e = [
                    e,
                    e
                ]), t.padding = [
                    t.spectrum.getDistance(e[0]),
                    t.spectrum.getDistance(e[1])
                ], n = 0; n < t.spectrum.xNumSteps.length - 1; n++)if (t.padding[0][n] < 0 || t.padding[1][n] < 0) throw new Error("noUiSlider: 'padding' option must be a positive number(s).");
                var f = e[0] + e[1], u = t.spectrum.xVal[0], m = t.spectrum.xVal[t.spectrum.xVal.length - 1];
                if (f / (m - u) > 1) throw new Error("noUiSlider: 'padding' option must not exceed 100% of the range.");
            }
        }
        function xt(t, e) {
            switch(e){
                case "ltr":
                    t.dir = 0;
                    break;
                case "rtl":
                    t.dir = 1;
                    break;
                default:
                    throw new Error("noUiSlider: 'direction' option was not recognized.");
            }
        }
        function Et(t, e) {
            if (typeof e != "string") throw new Error("noUiSlider: 'behaviour' must be a string containing options.");
            var n = e.indexOf("tap") >= 0, f = e.indexOf("drag") >= 0, u = e.indexOf("fixed") >= 0, m = e.indexOf("snap") >= 0, d = e.indexOf("hover") >= 0, x = e.indexOf("unconstrained") >= 0, v = e.indexOf("drag-all") >= 0, L = e.indexOf("smooth-steps") >= 0;
            if (u) {
                if (t.handles !== 2) throw new Error("noUiSlider: 'fixed' behaviour must be used with 2 handles");
                Ve(t, t.start[1] - t.start[0]);
            }
            if (x && (t.margin || t.limit)) throw new Error("noUiSlider: 'unconstrained' behaviour cannot be used with margin or limit");
            t.events = {
                tap: n || m,
                drag: f,
                dragAll: v,
                smoothSteps: L,
                fixed: u,
                snap: m,
                hover: d,
                unconstrained: x
            };
        }
        function Ct(t, e) {
            if (e !== !1) if (e === !0 || j(e)) {
                t.tooltips = [];
                for(var n = 0; n < t.handles; n++)t.tooltips.push(e);
            } else {
                if (e = G(e), e.length !== t.handles) throw new Error("noUiSlider: must pass a formatter for all handles.");
                e.forEach(function(f) {
                    if (typeof f != "boolean" && !j(f)) throw new Error("noUiSlider: 'tooltips' must be passed a formatter or 'false'.");
                }), t.tooltips = e;
            }
        }
        function Pt(t, e) {
            if (e.length !== t.handles) throw new Error("noUiSlider: must pass a attributes for all handles.");
            t.handleAttributes = e;
        }
        function yt(t, e) {
            if (!j(e)) throw new Error("noUiSlider: 'ariaFormat' requires 'to' method.");
            t.ariaFormat = e;
        }
        function Vt(t, e) {
            if (!A(e)) throw new Error("noUiSlider: 'format' requires 'to' and 'from' methods.");
            t.format = e;
        }
        function At(t, e) {
            if (typeof e != "boolean") throw new Error("noUiSlider: 'keyboardSupport' option must be a boolean.");
            t.keyboardSupport = e;
        }
        function Dt(t, e) {
            t.documentElement = e;
        }
        function kt(t, e) {
            if (typeof e != "string" && e !== !1) throw new Error("noUiSlider: 'cssPrefix' must be a string or `false`.");
            t.cssPrefix = e;
        }
        function Mt(t, e) {
            if (typeof e != "object") throw new Error("noUiSlider: 'cssClasses' must be an object.");
            typeof t.cssPrefix == "string" ? (t.cssClasses = {}, Object.keys(e).forEach(function(n) {
                t.cssClasses[n] = t.cssPrefix + e[n];
            })) : t.cssClasses = e;
        }
        function Ae(t) {
            var e = {
                margin: null,
                limit: null,
                padding: null,
                animate: !0,
                animationDuration: 300,
                ariaFormat: ye,
                format: ye
            }, n = {
                step: {
                    r: !1,
                    t: lt
                },
                keyboardPageMultiplier: {
                    r: !1,
                    t: ft
                },
                keyboardMultiplier: {
                    r: !1,
                    t: ut
                },
                keyboardDefaultStep: {
                    r: !1,
                    t: ct
                },
                start: {
                    r: !0,
                    t: pt
                },
                connect: {
                    r: !0,
                    t: gt
                },
                direction: {
                    r: !0,
                    t: xt
                },
                snap: {
                    r: !1,
                    t: dt
                },
                animate: {
                    r: !1,
                    t: vt
                },
                animationDuration: {
                    r: !1,
                    t: mt
                },
                range: {
                    r: !0,
                    t: ht
                },
                orientation: {
                    r: !1,
                    t: St
                },
                margin: {
                    r: !1,
                    t: Ve
                },
                limit: {
                    r: !1,
                    t: wt
                },
                padding: {
                    r: !1,
                    t: bt
                },
                behaviour: {
                    r: !0,
                    t: Et
                },
                ariaFormat: {
                    r: !1,
                    t: yt
                },
                format: {
                    r: !1,
                    t: Vt
                },
                tooltips: {
                    r: !1,
                    t: Ct
                },
                keyboardSupport: {
                    r: !0,
                    t: At
                },
                documentElement: {
                    r: !1,
                    t: Dt
                },
                cssPrefix: {
                    r: !0,
                    t: kt
                },
                cssClasses: {
                    r: !0,
                    t: Mt
                },
                handleAttributes: {
                    r: !1,
                    t: Pt
                }
            }, f = {
                connect: !1,
                direction: "ltr",
                behaviour: "tap",
                orientation: "horizontal",
                keyboardSupport: !0,
                cssPrefix: "noUi-",
                cssClasses: se,
                keyboardPageMultiplier: 5,
                keyboardMultiplier: 1,
                keyboardDefaultStep: 10
            };
            t.format && !t.ariaFormat && (t.ariaFormat = t.format), Object.keys(n).forEach(function(v) {
                if (!R(t[v]) && f[v] === void 0) {
                    if (n[v].r) throw new Error("noUiSlider: '" + v + "' is required.");
                    return;
                }
                n[v].t(e, R(t[v]) ? t[v] : f[v]);
            }), e.pips = t.pips;
            var u = document.createElement("div"), m = u.style.msTransform !== void 0, d = u.style.transform !== void 0;
            e.transformRule = d ? "transform" : m ? "msTransform" : "webkitTransform";
            var x = [
                [
                    "left",
                    "top"
                ],
                [
                    "right",
                    "bottom"
                ]
            ];
            return e.style = x[e.dir][e.ort], e;
        }
        function _t(t, e, n) {
            var f = et(), u = rt(), m = u && tt(), d = t, x, v, L, z, D, g = e.spectrum, F = [], P = [], O = [], ne = 0, T = {}, I = t.ownerDocument, Z = e.documentElement || I.documentElement, $ = I.body, Lt = I.dir === "rtl" || e.ort === 1 ? 0 : 100;
            function N(r, i) {
                var a = I.createElement("div");
                return i && _(a, i), r.appendChild(a), a;
            }
            function Ot(r, i) {
                var a = N(r, e.cssClasses.origin), s = N(a, e.cssClasses.handle);
                if (N(s, e.cssClasses.touchArea), s.setAttribute("data-handle", String(i)), e.keyboardSupport && (s.setAttribute("tabindex", "0"), s.addEventListener("keydown", function(o) {
                    return Wt(o, i);
                })), e.handleAttributes !== void 0) {
                    var l = e.handleAttributes[i];
                    Object.keys(l).forEach(function(o) {
                        s.setAttribute(o, l[o]);
                    });
                }
                return s.setAttribute("role", "slider"), s.setAttribute("aria-orientation", e.ort ? "vertical" : "horizontal"), i === 0 ? _(s, e.cssClasses.handleLower) : i === e.handles - 1 && _(s, e.cssClasses.handleUpper), a;
            }
            function ke(r, i) {
                return i ? N(r, e.cssClasses.connect) : !1;
            }
            function Ht(r, i) {
                var a = N(i, e.cssClasses.connects);
                v = [], L = [], L.push(ke(a, r[0]));
                for(var s = 0; s < e.handles; s++)v.push(Ot(i, s)), O[s] = s, L.push(ke(a, r[s + 1]));
            }
            function zt(r) {
                _(r, e.cssClasses.target), e.dir === 0 ? _(r, e.cssClasses.ltr) : _(r, e.cssClasses.rtl), e.ort === 0 ? _(r, e.cssClasses.horizontal) : _(r, e.cssClasses.vertical);
                var i = getComputedStyle(r).direction;
                return i === "rtl" ? _(r, e.cssClasses.textDirectionRtl) : _(r, e.cssClasses.textDirectionLtr), N(r, e.cssClasses.base);
            }
            function jt(r, i) {
                return !e.tooltips || !e.tooltips[i] ? !1 : N(r.firstChild, e.cssClasses.tooltip);
            }
            function Me() {
                return d.hasAttribute("disabled");
            }
            function oe(r) {
                var i = v[r];
                return i.hasAttribute("disabled");
            }
            function le() {
                D && (W("update" + B.tooltips), D.forEach(function(r) {
                    r && X(r);
                }), D = null);
            }
            function _e() {
                le(), D = v.map(jt), pe("update" + B.tooltips, function(r, i, a) {
                    if (!(!D || !e.tooltips) && D[i] !== !1) {
                        var s = r[i];
                        e.tooltips[i] !== !0 && (s = e.tooltips[i].to(a[i])), D[i].innerHTML = s;
                    }
                });
            }
            function Rt() {
                W("update" + B.aria), pe("update" + B.aria, function(r, i, a, s, l) {
                    O.forEach(function(o) {
                        var h = v[o], c = Q(P, o, 0, !0, !0, !0), b = Q(P, o, 100, !0, !0, !0), w = l[o], E = String(e.ariaFormat.to(a[o]));
                        c = g.fromStepping(c).toFixed(1), b = g.fromStepping(b).toFixed(1), w = g.fromStepping(w).toFixed(1), h.children[0].setAttribute("aria-valuemin", c), h.children[0].setAttribute("aria-valuemax", b), h.children[0].setAttribute("aria-valuenow", w), h.children[0].setAttribute("aria-valuetext", E);
                    });
                });
            }
            function Ft(r) {
                if (r.mode === p.PipsMode.Range || r.mode === p.PipsMode.Steps) return g.xVal;
                if (r.mode === p.PipsMode.Count) {
                    if (r.values < 2) throw new Error("noUiSlider: 'values' (>= 2) required for mode 'count'.");
                    for(var i = r.values - 1, a = 100 / i, s = []; i--;)s[i] = i * a;
                    return s.push(100), Ue(s, r.stepped);
                }
                return r.mode === p.PipsMode.Positions ? Ue(r.values, r.stepped) : r.mode === p.PipsMode.Values ? r.stepped ? r.values.map(function(l) {
                    return g.fromStepping(g.getStep(g.toStepping(l)));
                }) : r.values : [];
            }
            function Ue(r, i) {
                return r.map(function(a) {
                    return g.fromStepping(i ? g.getStep(a) : a);
                });
            }
            function Tt(r) {
                function i(w, E) {
                    return Number((w + E).toFixed(7));
                }
                var a = Ft(r), s = {}, l = g.xVal[0], o = g.xVal[g.xVal.length - 1], h = !1, c = !1, b = 0;
                return a = Ge(a.slice().sort(function(w, E) {
                    return w - E;
                })), a[0] !== l && (a.unshift(l), h = !0), a[a.length - 1] !== o && (a.push(o), c = !0), a.forEach(function(w, E) {
                    var C, S, V, U = w, k = a[E + 1], M, me, ge, Se, Ne, we, Be, Ke = r.mode === p.PipsMode.Steps;
                    for(Ke && (C = g.xNumSteps[E]), C || (C = k - U), k === void 0 && (k = U), C = Math.max(C, 1e-7), S = U; S <= k; S = i(S, C)){
                        for(M = g.toStepping(S), me = M - b, Ne = me / (r.density || 1), we = Math.round(Ne), Be = me / we, V = 1; V <= we; V += 1)ge = b + V * Be, s[ge.toFixed(5)] = [
                            g.fromStepping(ge),
                            0
                        ];
                        Se = a.indexOf(S) > -1 ? p.PipsType.LargeValue : Ke ? p.PipsType.SmallValue : p.PipsType.NoValue, !E && h && S !== k && (Se = 0), S === k && c || (s[M.toFixed(5)] = [
                            S,
                            Se
                        ]), b = M;
                    }
                }), s;
            }
            function Nt(r, i, a) {
                var s, l, o = I.createElement("div"), h = (s = {}, s[p.PipsType.None] = "", s[p.PipsType.NoValue] = e.cssClasses.valueNormal, s[p.PipsType.LargeValue] = e.cssClasses.valueLarge, s[p.PipsType.SmallValue] = e.cssClasses.valueSub, s), c = (l = {}, l[p.PipsType.None] = "", l[p.PipsType.NoValue] = e.cssClasses.markerNormal, l[p.PipsType.LargeValue] = e.cssClasses.markerLarge, l[p.PipsType.SmallValue] = e.cssClasses.markerSub, l), b = [
                    e.cssClasses.valueHorizontal,
                    e.cssClasses.valueVertical
                ], w = [
                    e.cssClasses.markerHorizontal,
                    e.cssClasses.markerVertical
                ];
                _(o, e.cssClasses.pips), _(o, e.ort === 0 ? e.cssClasses.pipsHorizontal : e.cssClasses.pipsVertical);
                function E(S, V) {
                    var U = V === e.cssClasses.value, k = U ? b : w, M = U ? h : c;
                    return V + " " + k[e.ort] + " " + M[S];
                }
                function C(S, V, U) {
                    if (U = i ? i(V, U) : U, U !== p.PipsType.None) {
                        var k = N(o, !1);
                        k.className = E(U, e.cssClasses.marker), k.style[e.style] = S + "%", U > p.PipsType.NoValue && (k = N(o, !1), k.className = E(U, e.cssClasses.value), k.setAttribute("data-value", String(V)), k.style[e.style] = S + "%", k.innerHTML = String(a.to(V)));
                    }
                }
                return Object.keys(r).forEach(function(S) {
                    C(S, r[S][0], r[S][1]);
                }), o;
            }
            function fe() {
                z && (X(z), z = null);
            }
            function ue(r) {
                fe();
                var i = Tt(r), a = r.filter, s = r.format || {
                    to: function(l) {
                        return String(Math.round(l));
                    }
                };
                return z = d.appendChild(Nt(i, a, s)), z;
            }
            function Le() {
                var r = x.getBoundingClientRect(), i = "offset" + [
                    "Width",
                    "Height"
                ][e.ort];
                return e.ort === 0 ? r.width || x[i] : r.height || x[i];
            }
            function K(r, i, a, s) {
                var l = function(h) {
                    var c = Bt(h, s.pageOffset, s.target || i);
                    if (!c || Me() && !s.doNotReject || Qe(d, e.cssClasses.tap) && !s.doNotReject || r === f.start && c.buttons !== void 0 && c.buttons > 1 || s.hover && c.buttons) return !1;
                    m || c.preventDefault(), c.calcPoint = c.points[e.ort], a(c, s);
                }, o = [];
                return r.split(" ").forEach(function(h) {
                    i.addEventListener(h, l, m ? {
                        passive: !0
                    } : !1), o.push([
                        h,
                        l
                    ]);
                }), o;
            }
            function Bt(r, i, a) {
                var s = r.type.indexOf("touch") === 0, l = r.type.indexOf("mouse") === 0, o = r.type.indexOf("pointer") === 0, h = 0, c = 0;
                if (r.type.indexOf("MSPointer") === 0 && (o = !0), r.type === "mousedown" && !r.buttons && !r.touches) return !1;
                if (s) {
                    var b = function(C) {
                        var S = C.target;
                        return S === a || a.contains(S) || r.composed && r.composedPath().shift() === a;
                    };
                    if (r.type === "touchstart") {
                        var w = Array.prototype.filter.call(r.touches, b);
                        if (w.length > 1) return !1;
                        h = w[0].pageX, c = w[0].pageY;
                    } else {
                        var E = Array.prototype.find.call(r.changedTouches, b);
                        if (!E) return !1;
                        h = E.pageX, c = E.pageY;
                    }
                }
                return i = i || Ce(I), (l || o) && (h = r.clientX + i.x, c = r.clientY + i.y), r.pageOffset = i, r.points = [
                    h,
                    c
                ], r.cursor = l || o, r;
            }
            function Oe(r) {
                var i = r - Ze(x, e.ort), a = i * 100 / Le();
                return a = Ee(a), e.dir ? 100 - a : a;
            }
            function Kt(r) {
                var i = 100, a = !1;
                return v.forEach(function(s, l) {
                    if (!oe(l)) {
                        var o = P[l], h = Math.abs(o - r), c = h === 100 && i === 100, b = h < i, w = h <= i && r > o;
                        (b || w || c) && (a = l, i = h);
                    }
                }), a;
            }
            function qt(r, i) {
                r.type === "mouseout" && r.target.nodeName === "HTML" && r.relatedTarget === null && ce(r, i);
            }
            function It(r, i) {
                if (navigator.appVersion.indexOf("MSIE 9") === -1 && r.buttons === 0 && i.buttonsProperty !== 0) return ce(r, i);
                var a = (e.dir ? -1 : 1) * (r.calcPoint - i.startCalcPoint), s = a * 100 / i.baseSize;
                He(a > 0, s, i.locations, i.handleNumbers, i.connect);
            }
            function ce(r, i) {
                i.handle && (J(i.handle, e.cssClasses.active), ne -= 1), i.listeners.forEach(function(a) {
                    Z.removeEventListener(a[0], a[1]);
                }), ne === 0 && (J(d, e.cssClasses.drag), ve(), r.cursor && ($.style.cursor = "", $.removeEventListener("selectstart", be))), e.events.smoothSteps && (i.handleNumbers.forEach(function(a) {
                    q(a, P[a], !0, !0, !1, !1);
                }), i.handleNumbers.forEach(function(a) {
                    y("update", a);
                })), i.handleNumbers.forEach(function(a) {
                    y("change", a), y("set", a), y("end", a);
                });
            }
            function he(r, i) {
                if (!i.handleNumbers.some(oe)) {
                    var a;
                    if (i.handleNumbers.length === 1) {
                        var s = v[i.handleNumbers[0]];
                        a = s.children[0], ne += 1, _(a, e.cssClasses.active);
                    }
                    r.stopPropagation();
                    var l = [], o = K(f.move, Z, It, {
                        target: r.target,
                        handle: a,
                        connect: i.connect,
                        listeners: l,
                        startCalcPoint: r.calcPoint,
                        baseSize: Le(),
                        pageOffset: r.pageOffset,
                        handleNumbers: i.handleNumbers,
                        buttonsProperty: r.buttons,
                        locations: P.slice()
                    }), h = K(f.end, Z, ce, {
                        target: r.target,
                        handle: a,
                        listeners: l,
                        doNotReject: !0,
                        handleNumbers: i.handleNumbers
                    }), c = K("mouseout", Z, qt, {
                        target: r.target,
                        handle: a,
                        listeners: l,
                        doNotReject: !0,
                        handleNumbers: i.handleNumbers
                    });
                    l.push.apply(l, o.concat(h, c)), r.cursor && ($.style.cursor = getComputedStyle(r.target).cursor, v.length > 1 && _(d, e.cssClasses.drag), $.addEventListener("selectstart", be, !1)), i.handleNumbers.forEach(function(b) {
                        y("start", b);
                    });
                }
            }
            function Xt(r) {
                r.stopPropagation();
                var i = Oe(r.calcPoint), a = Kt(i);
                a !== !1 && (e.events.snap || xe(d, e.cssClasses.tap, e.animationDuration), q(a, i, !0, !0), ve(), y("slide", a, !0), y("update", a, !0), e.events.snap ? he(r, {
                    handleNumbers: [
                        a
                    ]
                }) : (y("change", a, !0), y("set", a, !0)));
            }
            function Yt(r) {
                var i = Oe(r.calcPoint), a = g.getStep(i), s = g.fromStepping(a);
                Object.keys(T).forEach(function(l) {
                    l.split(".")[0] === "hover" && T[l].forEach(function(o) {
                        o.call(te, s);
                    });
                });
            }
            function Wt(r, i) {
                if (Me() || oe(i)) return !1;
                var a = [
                    "Left",
                    "Right"
                ], s = [
                    "Down",
                    "Up"
                ], l = [
                    "PageDown",
                    "PageUp"
                ], o = [
                    "Home",
                    "End"
                ];
                e.dir && !e.ort ? a.reverse() : e.ort && !e.dir && (s.reverse(), l.reverse());
                var h = r.key.replace("Arrow", ""), c = h === l[0], b = h === l[1], w = h === s[0] || h === a[0] || c, E = h === s[1] || h === a[1] || b, C = h === o[0], S = h === o[1];
                if (!w && !E && !C && !S) return !0;
                r.preventDefault();
                var V;
                if (E || w) {
                    var U = w ? 0 : 1, k = Te(i), M = k[U];
                    if (M === null) return !1;
                    M === !1 && (M = g.getDefaultStep(P[i], w, e.keyboardDefaultStep)), b || c ? M *= e.keyboardPageMultiplier : M *= e.keyboardMultiplier, M = Math.max(M, 1e-7), M = (w ? -1 : 1) * M, V = F[i] + M;
                } else S ? V = e.spectrum.xVal[e.spectrum.xVal.length - 1] : V = e.spectrum.xVal[0];
                return q(i, g.toStepping(V), !0, !0), y("slide", i), y("update", i), y("change", i), y("set", i), !1;
            }
            function Gt(r) {
                r.fixed || v.forEach(function(i, a) {
                    K(f.start, i.children[0], he, {
                        handleNumbers: [
                            a
                        ]
                    });
                }), r.tap && K(f.start, x, Xt, {}), r.hover && K(f.move, x, Yt, {
                    hover: !0
                }), r.drag && L.forEach(function(i, a) {
                    if (!(i === !1 || a === 0 || a === L.length - 1)) {
                        var s = v[a - 1], l = v[a], o = [
                            i
                        ], h = [
                            s,
                            l
                        ], c = [
                            a - 1,
                            a
                        ];
                        _(i, e.cssClasses.draggable), r.fixed && (o.push(s.children[0]), o.push(l.children[0])), r.dragAll && (h = v, c = O), o.forEach(function(b) {
                            K(f.start, b, he, {
                                handles: h,
                                handleNumbers: c,
                                connect: i
                            });
                        });
                    }
                });
            }
            function pe(r, i) {
                T[r] = T[r] || [], T[r].push(i), r.split(".")[0] === "update" && v.forEach(function(a, s) {
                    y("update", s);
                });
            }
            function Jt(r) {
                return r === B.aria || r === B.tooltips;
            }
            function W(r) {
                var i = r && r.split(".")[0], a = i ? r.substring(i.length) : r;
                Object.keys(T).forEach(function(s) {
                    var l = s.split(".")[0], o = s.substring(l.length);
                    (!i || i === l) && (!a || a === o) && (!Jt(o) || a === o) && delete T[s];
                });
            }
            function y(r, i, a) {
                Object.keys(T).forEach(function(s) {
                    var l = s.split(".")[0];
                    r === l && T[s].forEach(function(o) {
                        o.call(te, F.map(e.format.to), i, F.slice(), a || !1, P.slice(), te);
                    });
                });
            }
            function Q(r, i, a, s, l, o, h) {
                var c;
                return v.length > 1 && !e.events.unconstrained && (s && i > 0 && (c = g.getAbsoluteDistance(r[i - 1], e.margin, !1), a = Math.max(a, c)), l && i < v.length - 1 && (c = g.getAbsoluteDistance(r[i + 1], e.margin, !0), a = Math.min(a, c))), v.length > 1 && e.limit && (s && i > 0 && (c = g.getAbsoluteDistance(r[i - 1], e.limit, !1), a = Math.min(a, c)), l && i < v.length - 1 && (c = g.getAbsoluteDistance(r[i + 1], e.limit, !0), a = Math.max(a, c))), e.padding && (i === 0 && (c = g.getAbsoluteDistance(0, e.padding[0], !1), a = Math.max(a, c)), i === v.length - 1 && (c = g.getAbsoluteDistance(100, e.padding[1], !0), a = Math.min(a, c))), h || (a = g.getStep(a)), a = Ee(a), a === r[i] && !o ? !1 : a;
            }
            function de(r, i) {
                var a = e.ort;
                return (a ? i : r) + ", " + (a ? r : i);
            }
            function He(r, i, a, s, l) {
                var o = a.slice(), h = s[0], c = e.events.smoothSteps, b = [
                    !r,
                    r
                ], w = [
                    r,
                    !r
                ];
                s = s.slice(), r && s.reverse(), s.length > 1 ? s.forEach(function(C, S) {
                    var V = Q(o, C, o[C] + i, b[S], w[S], !1, c);
                    V === !1 ? i = 0 : (i = V - o[C], o[C] = V);
                }) : b = w = [
                    !0
                ];
                var E = !1;
                s.forEach(function(C, S) {
                    E = q(C, a[C] + i, b[S], w[S], !1, c) || E;
                }), E && (s.forEach(function(C) {
                    y("update", C), y("slide", C);
                }), l != null && y("drag", h));
            }
            function ze(r, i) {
                return e.dir ? 100 - r - i : r;
            }
            function Zt(r, i) {
                P[r] = i, F[r] = g.fromStepping(i);
                var a = ze(i, 0) - Lt, s = "translate(" + de(a + "%", "0") + ")";
                v[r].style[e.transformRule] = s, je(r), je(r + 1);
            }
            function ve() {
                O.forEach(function(r) {
                    var i = P[r] > 50 ? -1 : 1, a = 3 + (v.length + i * r);
                    v[r].style.zIndex = String(a);
                });
            }
            function q(r, i, a, s, l, o) {
                return l || (i = Q(P, r, i, a, s, !1, o)), i === !1 ? !1 : (Zt(r, i), !0);
            }
            function je(r) {
                if (!!L[r]) {
                    var i = 0, a = 100;
                    r !== 0 && (i = P[r - 1]), r !== L.length - 1 && (a = P[r]);
                    var s = a - i, l = "translate(" + de(ze(i, s) + "%", "0") + ")", o = "scale(" + de(s / 100, "1") + ")";
                    L[r].style[e.transformRule] = l + " " + o;
                }
            }
            function Re(r, i) {
                return r === null || r === !1 || r === void 0 || (typeof r == "number" && (r = String(r)), r = e.format.from(r), r !== !1 && (r = g.toStepping(r)), r === !1 || isNaN(r)) ? P[i] : r;
            }
            function ee(r, i, a) {
                var s = G(r), l = P[0] === void 0;
                i = i === void 0 ? !0 : i, e.animate && !l && xe(d, e.cssClasses.tap, e.animationDuration), O.forEach(function(c) {
                    q(c, Re(s[c], c), !0, !1, a);
                });
                var o = O.length === 1 ? 0 : 1;
                if (l && g.hasNoSize() && (a = !0, P[0] = 0, O.length > 1)) {
                    var h = 100 / (O.length - 1);
                    O.forEach(function(c) {
                        P[c] = c * h;
                    });
                }
                for(; o < O.length; ++o)O.forEach(function(c) {
                    q(c, P[c], !0, !0, a);
                });
                ve(), O.forEach(function(c) {
                    y("update", c), s[c] !== null && i && y("set", c);
                });
            }
            function $t(r) {
                ee(e.start, r);
            }
            function Qt(r, i, a, s) {
                if (r = Number(r), !(r >= 0 && r < O.length)) throw new Error("noUiSlider: invalid handle number, got: " + r);
                q(r, Re(i, r), !0, !0, s), y("update", r), a && y("set", r);
            }
            function Fe(r) {
                if (r === void 0 && (r = !1), r) return F.length === 1 ? F[0] : F.slice(0);
                var i = F.map(e.format.to);
                return i.length === 1 ? i[0] : i;
            }
            function er() {
                for(W(B.aria), W(B.tooltips), Object.keys(e.cssClasses).forEach(function(r) {
                    J(d, e.cssClasses[r]);
                }); d.firstChild;)d.removeChild(d.firstChild);
                delete d.noUiSlider;
            }
            function Te(r) {
                var i = P[r], a = g.getNearbySteps(i), s = F[r], l = a.thisStep.step, o = null;
                if (e.snap) return [
                    s - a.stepBefore.startValue || null,
                    a.stepAfter.startValue - s || null
                ];
                l !== !1 && s + l > a.stepAfter.startValue && (l = a.stepAfter.startValue - s), s > a.thisStep.startValue ? o = a.thisStep.step : a.stepBefore.step === !1 ? o = !1 : o = s - a.stepBefore.highestStep, i === 100 ? l = null : i === 0 && (o = null);
                var h = g.countStepDecimals();
                return l !== null && l !== !1 && (l = Number(l.toFixed(h))), o !== null && o !== !1 && (o = Number(o.toFixed(h))), [
                    o,
                    l
                ];
            }
            function tr() {
                return O.map(Te);
            }
            function rr(r, i) {
                var a = Fe(), s = [
                    "margin",
                    "limit",
                    "padding",
                    "range",
                    "animate",
                    "snap",
                    "step",
                    "format",
                    "pips",
                    "tooltips"
                ];
                s.forEach(function(o) {
                    r[o] !== void 0 && (n[o] = r[o]);
                });
                var l = Ae(n);
                s.forEach(function(o) {
                    r[o] !== void 0 && (e[o] = l[o]);
                }), g = l.spectrum, e.margin = l.margin, e.limit = l.limit, e.padding = l.padding, e.pips ? ue(e.pips) : fe(), e.tooltips ? _e() : le(), P = [], ee(R(r.start) ? r.start : a, i);
            }
            function ir() {
                x = zt(d), Ht(e.connect, x), Gt(e.events), ee(e.start), e.pips && ue(e.pips), e.tooltips && _e(), Rt();
            }
            ir();
            var te = {
                destroy: er,
                steps: tr,
                on: pe,
                off: W,
                get: Fe,
                set: ee,
                setHandle: Qt,
                reset: $t,
                __moveHandles: function(r, i, a) {
                    He(r, i, P, a);
                },
                options: n,
                updateOptions: rr,
                target: d,
                removePips: fe,
                removeTooltips: le,
                getPositions: function() {
                    return P.slice();
                },
                getTooltips: function() {
                    return D;
                },
                getOrigins: function() {
                    return v;
                },
                pips: ue
            };
            return te;
        }
        function De(t, e) {
            if (!t || !t.nodeName) throw new Error("noUiSlider: create requires a single element, got: " + t);
            if (t.noUiSlider) throw new Error("noUiSlider: Slider was already initialized.");
            var n = Ae(e), f = _t(t, n, e);
            return t.noUiSlider = f, f;
        }
        var Ut = {
            __spectrum: Pe,
            cssClasses: se,
            create: De
        };
        p.create = De, p.cssClasses = se, p.default = Ut, Object.defineProperty(p, "__esModule", {
            value: !0
        });
    });
});
var We = cr(Xe()), dr = !0, { PipsMode: vr , PipsType: mr , create: gr , cssClasses: Sr  } = We, { default: Ye , ...hr } = We, wr = Ye !== void 0 ? Ye : hr;
export { vr as PipsMode, mr as PipsType, dr as __esModule, gr as create, Sr as cssClasses, wr as default };

