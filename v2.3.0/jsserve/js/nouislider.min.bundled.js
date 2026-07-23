// deno-fmt-ignore-file
// deno-lint-ignore-file
// This code was bundled using `deno bundle` and it's not recommended to edit it manually

var N;
(function(r) {
    r.Range = "range", r.Steps = "steps", r.Positions = "positions", r.Count = "count", r.Values = "values";
})(N || (N = {}));
var L;
(function(r) {
    r[r.None = -1] = "None", r[r.NoValue = 0] = "NoValue", r[r.LargeValue = 1] = "LargeValue", r[r.SmallValue = 2] = "SmallValue";
})(L || (L = {}));
function pe(r) {
    return $(r) && typeof r.from == "function";
}
function $(r) {
    return typeof r == "object" && typeof r.to == "function";
}
function Lt(r) {
    r.parentElement.removeChild(r);
}
function dt(r) {
    return r != null;
}
function _t(r) {
    r.preventDefault();
}
function me(r) {
    return r.filter(function(t) {
        return this[t] ? !1 : this[t] = !0;
    }, {});
}
function ge(r, t) {
    return Math.round(r / t) * t;
}
function Se(r, t) {
    var n = r.getBoundingClientRect(), f = r.ownerDocument, u = f.documentElement, p = Rt(f);
    return /webkit.*Chrome.*Mobile/i.test(navigator.userAgent) && (p.x = 0), t ? n.top + p.y - u.clientTop : n.left + p.x - u.clientLeft;
}
function H(r) {
    return typeof r == "number" && !isNaN(r) && isFinite(r);
}
function Ot(r, t, n) {
    n > 0 && (M(r, t), setTimeout(function() {
        Z(r, t);
    }, n));
}
function Ht(r) {
    return Math.max(Math.min(r, 100), 0);
}
function Q(r) {
    return Array.isArray(r) ? r : [
        r
    ];
}
function xe(r) {
    r = String(r);
    var t = r.split(".");
    return t.length > 1 ? t[1].length : 0;
}
function M(r, t) {
    r.classList && !/\s/.test(t) ? r.classList.add(t) : r.className += " " + t;
}
function Z(r, t) {
    r.classList && !/\s/.test(t) ? r.classList.remove(t) : r.className = r.className.replace(new RegExp("(^|\\b)" + t.split(" ").join("|") + "(\\b|$)", "gi"), " ");
}
function be(r, t) {
    return r.classList ? r.classList.contains(t) : new RegExp("\\b" + t + "\\b").test(r.className);
}
function Rt(r) {
    var t = window.pageXOffset !== void 0, n = (r.compatMode || "") === "CSS1Compat", f = t ? window.pageXOffset : n ? r.documentElement.scrollLeft : r.body.scrollLeft, u = t ? window.pageYOffset : n ? r.documentElement.scrollTop : r.body.scrollTop;
    return {
        x: f,
        y: u
    };
}
function we() {
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
function Ee() {
    var r = !1;
    try {
        var t = Object.defineProperty({}, "passive", {
            get: function() {
                r = !0;
            }
        });
        window.addEventListener("test", null, t);
    } catch  {}
    return r;
}
function Ce() {
    return window.CSS && CSS.supports && CSS.supports("touch-action", "none");
}
function mt(r, t) {
    return 100 / (t - r);
}
function pt(r, t, n) {
    return t * 100 / (r[n + 1] - r[n]);
}
function Pe(r, t) {
    return pt(r, r[0] < 0 ? t + Math.abs(r[0]) : t - r[0], 0);
}
function Ae(r, t) {
    return t * (r[1] - r[0]) / 100 + r[0];
}
function T(r, t) {
    for(var n = 1; r >= t[n];)n += 1;
    return n;
}
function Ve(r, t, n) {
    if (n >= r.slice(-1)[0]) return 100;
    var f = T(n, r), u = r[f - 1], p = r[f], d = t[f - 1], b = t[f];
    return d + Pe([
        u,
        p
    ], n) / mt(d, b);
}
function De(r, t, n) {
    if (n >= 100) return r.slice(-1)[0];
    var f = T(n, t), u = r[f - 1], p = r[f], d = t[f - 1], b = t[f];
    return Ae([
        u,
        p
    ], (n - d) * mt(d, b));
}
function ke(r, t, n, f) {
    if (f === 100) return f;
    var u = T(f, r), p = r[u - 1], d = r[u];
    return n ? f - p > (d - p) / 2 ? d : p : t[u - 1] ? r[u - 1] + ge(f - r[u - 1], t[u - 1]) : f;
}
var jt = function() {
    function r(t, n, f) {
        this.xPct = [], this.xVal = [], this.xSteps = [], this.xNumSteps = [], this.xHighestCompleteStep = [], this.xSteps = [
            f || !1
        ], this.xNumSteps = [
            !1
        ], this.snap = n;
        var u, p = [];
        for(Object.keys(t).forEach(function(d) {
            p.push([
                Q(t[d]),
                d
            ]);
        }), p.sort(function(d, b) {
            return d[0][0] - b[0][0];
        }), u = 0; u < p.length; u++)this.handleEntryPoint(p[u][1], p[u][0]);
        for(this.xNumSteps = this.xSteps.slice(0), u = 0; u < this.xNumSteps.length; u++)this.handleStepPoint(u, this.xNumSteps[u]);
    }
    return r.prototype.getDistance = function(t) {
        for(var n = [], f = 0; f < this.xNumSteps.length - 1; f++)n[f] = pt(this.xVal, t, f);
        return n;
    }, r.prototype.getAbsoluteDistance = function(t, n, f) {
        var u = 0;
        if (t < this.xPct[this.xPct.length - 1]) for(; t > this.xPct[u + 1];)u++;
        else t === this.xPct[this.xPct.length - 1] && (u = this.xPct.length - 2);
        !f && t === this.xPct[u + 1] && u++, n === null && (n = []);
        var p, d = 1, b = n[u], v = 0, U = 0, O = 0, V = 0;
        for(f ? p = (t - this.xPct[u]) / (this.xPct[u + 1] - this.xPct[u]) : p = (this.xPct[u + 1] - t) / (this.xPct[u + 1] - this.xPct[u]); b > 0;)v = this.xPct[u + 1 + V] - this.xPct[u + V], n[u + V] * d + 100 - p * 100 > 100 ? (U = v * p, d = (b - 100 * p) / n[u + V], p = 1) : (U = n[u + V] * v / 100 * d, d = 0), f ? (O = O - U, this.xPct.length + V >= 1 && V--) : (O = O + U, this.xPct.length - V >= 1 && V++), b = n[u + V] * d;
        return t + O;
    }, r.prototype.toStepping = function(t) {
        return t = Ve(this.xVal, this.xPct, t), t;
    }, r.prototype.fromStepping = function(t) {
        return De(this.xVal, this.xPct, t);
    }, r.prototype.getStep = function(t) {
        return t = ke(this.xPct, this.xSteps, this.snap, t), t;
    }, r.prototype.getDefaultStep = function(t, n, f) {
        var u = T(t, this.xPct);
        return (t === 100 || n && t === this.xPct[u - 1]) && (u = Math.max(u - 1, 1)), (this.xVal[u] - this.xVal[u - 1]) / f;
    }, r.prototype.getNearbySteps = function(t) {
        var n = T(t, this.xPct);
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
    }, r.prototype.countStepDecimals = function() {
        var t = this.xNumSteps.map(xe);
        return Math.max.apply(null, t);
    }, r.prototype.hasNoSize = function() {
        return this.xVal[0] === this.xVal[this.xVal.length - 1];
    }, r.prototype.convert = function(t) {
        return this.getStep(this.toStepping(t));
    }, r.prototype.handleEntryPoint = function(t, n) {
        var f;
        if (t === "min" ? f = 0 : t === "max" ? f = 100 : f = parseFloat(t), !H(f) || !H(n[0])) throw new Error("noUiSlider: 'range' value isn't numeric.");
        this.xPct.push(f), this.xVal.push(n[0]);
        var u = Number(n[1]);
        f ? this.xSteps.push(isNaN(u) ? !1 : u) : isNaN(u) || (this.xSteps[0] = u), this.xHighestCompleteStep.push(0);
    }, r.prototype.handleStepPoint = function(t, n) {
        if (n) {
            if (this.xVal[t] === this.xVal[t + 1]) {
                this.xSteps[t] = this.xHighestCompleteStep[t] = this.xVal[t];
                return;
            }
            this.xSteps[t] = pt([
                this.xVal[t],
                this.xVal[t + 1]
            ], n, 0) / mt(this.xPct[t], this.xPct[t + 1]);
            var f = (this.xVal[t + 1] - this.xVal[t]) / this.xNumSteps[t], u = Math.ceil(Number(f.toFixed(3)) - 1), p = this.xVal[t] + this.xNumSteps[t] * u;
            this.xHighestCompleteStep[t] = p;
        }
    }, r;
}(), zt = {
    to: function(r) {
        return r === void 0 ? "" : r.toFixed(2);
    },
    from: Number
}, Ft = {
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
}, F = {
    tooltips: ".__tooltips",
    aria: ".__aria"
};
function ye(r, t) {
    if (!H(t)) throw new Error("noUiSlider: 'step' is not numeric.");
    r.singleStep = t;
}
function Me(r, t) {
    if (!H(t)) throw new Error("noUiSlider: 'keyboardPageMultiplier' is not numeric.");
    r.keyboardPageMultiplier = t;
}
function Ue(r, t) {
    if (!H(t)) throw new Error("noUiSlider: 'keyboardMultiplier' is not numeric.");
    r.keyboardMultiplier = t;
}
function Le(r, t) {
    if (!H(t)) throw new Error("noUiSlider: 'keyboardDefaultStep' is not numeric.");
    r.keyboardDefaultStep = t;
}
function _e(r, t) {
    if (typeof t != "object" || Array.isArray(t)) throw new Error("noUiSlider: 'range' is not an object.");
    if (t.min === void 0 || t.max === void 0) throw new Error("noUiSlider: Missing 'min' or 'max' in 'range'.");
    r.spectrum = new jt(t, r.snap || !1, r.singleStep);
}
function Oe(r, t) {
    if (t = Q(t), !Array.isArray(t) || !t.length) throw new Error("noUiSlider: 'start' option is incorrect.");
    r.handles = t.length, r.start = t;
}
function He(r, t) {
    if (typeof t != "boolean") throw new Error("noUiSlider: 'snap' option must be a boolean.");
    r.snap = t;
}
function ze(r, t) {
    if (typeof t != "boolean") throw new Error("noUiSlider: 'animate' option must be a boolean.");
    r.animate = t;
}
function Re(r, t) {
    if (typeof t != "number") throw new Error("noUiSlider: 'animationDuration' option must be a number.");
    r.animationDuration = t;
}
function je(r, t) {
    var n = [
        !1
    ], f;
    if (t === "lower" ? t = [
        !0,
        !1
    ] : t === "upper" && (t = [
        !1,
        !0
    ]), t === !0 || t === !1) {
        for(f = 1; f < r.handles; f++)n.push(t);
        n.push(!1);
    } else {
        if (!Array.isArray(t) || !t.length || t.length !== r.handles + 1) throw new Error("noUiSlider: 'connect' option doesn't match handle count.");
        n = t;
    }
    r.connect = n;
}
function Fe(r, t) {
    switch(t){
        case "horizontal":
            r.ort = 0;
            break;
        case "vertical":
            r.ort = 1;
            break;
        default:
            throw new Error("noUiSlider: 'orientation' option is invalid.");
    }
}
function Nt(r, t) {
    if (!H(t)) throw new Error("noUiSlider: 'margin' option must be numeric.");
    t !== 0 && (r.margin = r.spectrum.getDistance(t));
}
function Ne(r, t) {
    if (!H(t)) throw new Error("noUiSlider: 'limit' option must be numeric.");
    if (r.limit = r.spectrum.getDistance(t), !r.limit || r.handles < 2) throw new Error("noUiSlider: 'limit' option is only supported on linear sliders with 2 or more handles.");
}
function Be(r, t) {
    var n;
    if (!H(t) && !Array.isArray(t)) throw new Error("noUiSlider: 'padding' option must be numeric or array of exactly 2 numbers.");
    if (Array.isArray(t) && !(t.length === 2 || H(t[0]) || H(t[1]))) throw new Error("noUiSlider: 'padding' option must be numeric or array of exactly 2 numbers.");
    if (t !== 0) {
        for(Array.isArray(t) || (t = [
            t,
            t
        ]), r.padding = [
            r.spectrum.getDistance(t[0]),
            r.spectrum.getDistance(t[1])
        ], n = 0; n < r.spectrum.xNumSteps.length - 1; n++)if (r.padding[0][n] < 0 || r.padding[1][n] < 0) throw new Error("noUiSlider: 'padding' option must be a positive number(s).");
        var f = t[0] + t[1], u = r.spectrum.xVal[0], p = r.spectrum.xVal[r.spectrum.xVal.length - 1];
        if (f / (p - u) > 1) throw new Error("noUiSlider: 'padding' option must not exceed 100% of the range.");
    }
}
function Ke(r, t) {
    switch(t){
        case "ltr":
            r.dir = 0;
            break;
        case "rtl":
            r.dir = 1;
            break;
        default:
            throw new Error("noUiSlider: 'direction' option was not recognized.");
    }
}
function qe(r, t) {
    if (typeof t != "string") throw new Error("noUiSlider: 'behaviour' must be a string containing options.");
    var n = t.indexOf("tap") >= 0, f = t.indexOf("drag") >= 0, u = t.indexOf("fixed") >= 0, p = t.indexOf("snap") >= 0, d = t.indexOf("hover") >= 0, b = t.indexOf("unconstrained") >= 0, v = t.indexOf("drag-all") >= 0, U = t.indexOf("smooth-steps") >= 0;
    if (u) {
        if (r.handles !== 2) throw new Error("noUiSlider: 'fixed' behaviour must be used with 2 handles");
        Nt(r, r.start[1] - r.start[0]);
    }
    if (b && (r.margin || r.limit)) throw new Error("noUiSlider: 'unconstrained' behaviour cannot be used with margin or limit");
    r.events = {
        tap: n || p,
        drag: f,
        dragAll: v,
        smoothSteps: U,
        fixed: u,
        snap: p,
        hover: d,
        unconstrained: b
    };
}
function Ie(r, t) {
    if (t !== !1) if (t === !0 || $(t)) {
        r.tooltips = [];
        for(var n = 0; n < r.handles; n++)r.tooltips.push(t);
    } else {
        if (t = Q(t), t.length !== r.handles) throw new Error("noUiSlider: must pass a formatter for all handles.");
        t.forEach(function(f) {
            if (typeof f != "boolean" && !$(f)) throw new Error("noUiSlider: 'tooltips' must be passed a formatter or 'false'.");
        }), r.tooltips = t;
    }
}
function Te(r, t) {
    if (t.length !== r.handles) throw new Error("noUiSlider: must pass a attributes for all handles.");
    r.handleAttributes = t;
}
function Xe(r, t) {
    if (!$(t)) throw new Error("noUiSlider: 'ariaFormat' requires 'to' method.");
    r.ariaFormat = t;
}
function Ye(r, t) {
    if (!pe(t)) throw new Error("noUiSlider: 'format' requires 'to' and 'from' methods.");
    r.format = t;
}
function We(r, t) {
    if (typeof t != "boolean") throw new Error("noUiSlider: 'keyboardSupport' option must be a boolean.");
    r.keyboardSupport = t;
}
function Ge(r, t) {
    r.documentElement = t;
}
function Je(r, t) {
    if (typeof t != "string" && t !== !1) throw new Error("noUiSlider: 'cssPrefix' must be a string or `false`.");
    r.cssPrefix = t;
}
function Ze(r, t) {
    if (typeof t != "object") throw new Error("noUiSlider: 'cssClasses' must be an object.");
    typeof r.cssPrefix == "string" ? (r.cssClasses = {}, Object.keys(t).forEach(function(n) {
        r.cssClasses[n] = r.cssPrefix + t[n];
    })) : r.cssClasses = t;
}
function Bt(r) {
    var t = {
        margin: null,
        limit: null,
        padding: null,
        animate: !0,
        animationDuration: 300,
        ariaFormat: zt,
        format: zt
    }, n = {
        step: {
            r: !1,
            t: ye
        },
        keyboardPageMultiplier: {
            r: !1,
            t: Me
        },
        keyboardMultiplier: {
            r: !1,
            t: Ue
        },
        keyboardDefaultStep: {
            r: !1,
            t: Le
        },
        start: {
            r: !0,
            t: Oe
        },
        connect: {
            r: !0,
            t: je
        },
        direction: {
            r: !0,
            t: Ke
        },
        snap: {
            r: !1,
            t: He
        },
        animate: {
            r: !1,
            t: ze
        },
        animationDuration: {
            r: !1,
            t: Re
        },
        range: {
            r: !0,
            t: _e
        },
        orientation: {
            r: !1,
            t: Fe
        },
        margin: {
            r: !1,
            t: Nt
        },
        limit: {
            r: !1,
            t: Ne
        },
        padding: {
            r: !1,
            t: Be
        },
        behaviour: {
            r: !0,
            t: qe
        },
        ariaFormat: {
            r: !1,
            t: Xe
        },
        format: {
            r: !1,
            t: Ye
        },
        tooltips: {
            r: !1,
            t: Ie
        },
        keyboardSupport: {
            r: !0,
            t: We
        },
        documentElement: {
            r: !1,
            t: Ge
        },
        cssPrefix: {
            r: !0,
            t: Je
        },
        cssClasses: {
            r: !0,
            t: Ze
        },
        handleAttributes: {
            r: !1,
            t: Te
        }
    }, f = {
        connect: !1,
        direction: "ltr",
        behaviour: "tap",
        orientation: "horizontal",
        keyboardSupport: !0,
        cssPrefix: "noUi-",
        cssClasses: Ft,
        keyboardPageMultiplier: 5,
        keyboardMultiplier: 1,
        keyboardDefaultStep: 10
    };
    r.format && !r.ariaFormat && (r.ariaFormat = r.format), Object.keys(n).forEach(function(v) {
        if (!dt(r[v]) && f[v] === void 0) {
            if (n[v].r) throw new Error("noUiSlider: '" + v + "' is required.");
            return;
        }
        n[v].t(t, dt(r[v]) ? r[v] : f[v]);
    }), t.pips = r.pips;
    var u = document.createElement("div"), p = u.style.msTransform !== void 0, d = u.style.transform !== void 0;
    t.transformRule = d ? "transform" : p ? "msTransform" : "webkitTransform";
    var b = [
        [
            "left",
            "top"
        ],
        [
            "right",
            "bottom"
        ]
    ];
    return t.style = b[t.dir][t.ort], t;
}
function $e(r, t, n) {
    var f = we(), u = Ce(), p = u && Ee(), d = r, b, v, U, O, V, m = t.spectrum, z = [], C = [], _ = [], tt = 0, R = {}, q = r.ownerDocument, X = t.documentElement || q.documentElement, Y = q.body, Kt = q.dir === "rtl" || t.ort === 1 ? 0 : 100;
    function j(e, i) {
        var a = q.createElement("div");
        return i && M(a, i), e.appendChild(a), a;
    }
    function qt(e, i) {
        var a = j(e, t.cssClasses.origin), s = j(a, t.cssClasses.handle);
        if (j(s, t.cssClasses.touchArea), s.setAttribute("data-handle", String(i)), t.keyboardSupport && (s.setAttribute("tabindex", "0"), s.addEventListener("keydown", function(o) {
            return se(o, i);
        })), t.handleAttributes !== void 0) {
            var l = t.handleAttributes[i];
            Object.keys(l).forEach(function(o) {
                s.setAttribute(o, l[o]);
            });
        }
        return s.setAttribute("role", "slider"), s.setAttribute("aria-orientation", t.ort ? "vertical" : "horizontal"), i === 0 ? M(s, t.cssClasses.handleLower) : i === t.handles - 1 && M(s, t.cssClasses.handleUpper), a.handle = s, a;
    }
    function gt(e, i) {
        return i ? j(e, t.cssClasses.connect) : !1;
    }
    function It(e, i) {
        var a = j(i, t.cssClasses.connects);
        v = [], U = [], U.push(gt(a, e[0]));
        for(var s = 0; s < t.handles; s++)v.push(qt(i, s)), _[s] = s, U.push(gt(a, e[s + 1]));
    }
    function Tt(e) {
        M(e, t.cssClasses.target), t.dir === 0 ? M(e, t.cssClasses.ltr) : M(e, t.cssClasses.rtl), t.ort === 0 ? M(e, t.cssClasses.horizontal) : M(e, t.cssClasses.vertical);
        var i = getComputedStyle(e).direction;
        return i === "rtl" ? M(e, t.cssClasses.textDirectionRtl) : M(e, t.cssClasses.textDirectionLtr), j(e, t.cssClasses.base);
    }
    function Xt(e, i) {
        return !t.tooltips || !t.tooltips[i] ? !1 : j(e.firstChild, t.cssClasses.tooltip);
    }
    function St() {
        return d.hasAttribute("disabled");
    }
    function et(e) {
        var i = v[e];
        return i.hasAttribute("disabled");
    }
    function Yt(e) {
        e != null ? (v[e].setAttribute("disabled", ""), v[e].handle.removeAttribute("tabindex")) : (d.setAttribute("disabled", ""), v.forEach(function(i) {
            i.handle.removeAttribute("tabindex");
        }));
    }
    function Wt(e) {
        e != null ? (v[e].removeAttribute("disabled"), v[e].handle.setAttribute("tabindex", "0")) : (d.removeAttribute("disabled"), v.forEach(function(i) {
            i.removeAttribute("disabled"), i.handle.setAttribute("tabindex", "0");
        }));
    }
    function rt() {
        V && (I("update" + F.tooltips), V.forEach(function(e) {
            e && Lt(e);
        }), V = null);
    }
    function xt() {
        rt(), V = v.map(Xt), ot("update" + F.tooltips, function(e, i, a) {
            if (!(!V || !t.tooltips) && V[i] !== !1) {
                var s = e[i];
                t.tooltips[i] !== !0 && (s = t.tooltips[i].to(a[i])), V[i].innerHTML = s;
            }
        });
    }
    function Gt() {
        I("update" + F.aria), ot("update" + F.aria, function(e, i, a, s, l) {
            _.forEach(function(o) {
                var h = v[o], c = W(C, o, 0, !0, !0, !0), x = W(C, o, 100, !0, !0, !0), S = l[o], w = String(t.ariaFormat.to(a[o]));
                c = m.fromStepping(c).toFixed(1), x = m.fromStepping(x).toFixed(1), S = m.fromStepping(S).toFixed(1), h.children[0].setAttribute("aria-valuemin", c), h.children[0].setAttribute("aria-valuemax", x), h.children[0].setAttribute("aria-valuenow", S), h.children[0].setAttribute("aria-valuetext", w);
            });
        });
    }
    function Jt(e) {
        if (e.mode === N.Range || e.mode === N.Steps) return m.xVal;
        if (e.mode === N.Count) {
            if (e.values < 2) throw new Error("noUiSlider: 'values' (>= 2) required for mode 'count'.");
            for(var i = e.values - 1, a = 100 / i, s = []; i--;)s[i] = i * a;
            return s.push(100), bt(s, e.stepped);
        }
        return e.mode === N.Positions ? bt(e.values, e.stepped) : e.mode === N.Values ? e.stepped ? e.values.map(function(l) {
            return m.fromStepping(m.getStep(m.toStepping(l)));
        }) : e.values : [];
    }
    function bt(e, i) {
        return e.map(function(a) {
            return m.fromStepping(i ? m.getStep(a) : a);
        });
    }
    function Zt(e) {
        function i(S, w) {
            return Number((S + w).toFixed(7));
        }
        var a = Jt(e), s = {}, l = m.xVal[0], o = m.xVal[m.xVal.length - 1], h = !1, c = !1, x = 0;
        return a = me(a.slice().sort(function(S, w) {
            return S - w;
        })), a[0] !== l && (a.unshift(l), h = !0), a[a.length - 1] !== o && (a.push(o), c = !0), a.forEach(function(S, w) {
            var E, g, A, y = S, D = a[w + 1], k, ut, ct, ht, yt, vt, Mt, Ut = e.mode === N.Steps;
            for(Ut && (E = m.xNumSteps[w]), E || (E = D - y), D === void 0 && (D = y), E = Math.max(E, 1e-7), g = y; g <= D; g = i(g, E)){
                for(k = m.toStepping(g), ut = k - x, yt = ut / (e.density || 1), vt = Math.round(yt), Mt = ut / vt, A = 1; A <= vt; A += 1)ct = x + A * Mt, s[ct.toFixed(5)] = [
                    m.fromStepping(ct),
                    0
                ];
                ht = a.indexOf(g) > -1 ? L.LargeValue : Ut ? L.SmallValue : L.NoValue, !w && h && g !== D && (ht = 0), g === D && c || (s[k.toFixed(5)] = [
                    g,
                    ht
                ]), x = k;
            }
        }), s;
    }
    function $t(e, i, a) {
        var s, l, o = q.createElement("div"), h = (s = {}, s[L.None] = "", s[L.NoValue] = t.cssClasses.valueNormal, s[L.LargeValue] = t.cssClasses.valueLarge, s[L.SmallValue] = t.cssClasses.valueSub, s), c = (l = {}, l[L.None] = "", l[L.NoValue] = t.cssClasses.markerNormal, l[L.LargeValue] = t.cssClasses.markerLarge, l[L.SmallValue] = t.cssClasses.markerSub, l), x = [
            t.cssClasses.valueHorizontal,
            t.cssClasses.valueVertical
        ], S = [
            t.cssClasses.markerHorizontal,
            t.cssClasses.markerVertical
        ];
        M(o, t.cssClasses.pips), M(o, t.ort === 0 ? t.cssClasses.pipsHorizontal : t.cssClasses.pipsVertical);
        function w(g, A) {
            var y = A === t.cssClasses.value, D = y ? x : S, k = y ? h : c;
            return A + " " + D[t.ort] + " " + k[g];
        }
        function E(g, A, y) {
            if (y = i ? i(A, y) : y, y !== L.None) {
                var D = j(o, !1);
                D.className = w(y, t.cssClasses.marker), D.style[t.style] = g + "%", y > L.NoValue && (D = j(o, !1), D.className = w(y, t.cssClasses.value), D.setAttribute("data-value", String(A)), D.style[t.style] = g + "%", D.innerHTML = String(a.to(A)));
            }
        }
        return Object.keys(e).forEach(function(g) {
            E(g, e[g][0], e[g][1]);
        }), o;
    }
    function it() {
        O && (Lt(O), O = null);
    }
    function at(e) {
        it();
        var i = Zt(e), a = e.filter, s = e.format || {
            to: function(l) {
                return String(Math.round(l));
            }
        };
        return O = d.appendChild($t(i, a, s)), O;
    }
    function wt() {
        var e = b.getBoundingClientRect(), i = "offset" + [
            "Width",
            "Height"
        ][t.ort];
        return t.ort === 0 ? e.width || b[i] : e.height || b[i];
    }
    function B(e, i, a, s) {
        var l = function(h) {
            var c = Qt(h, s.pageOffset, s.target || i);
            if (!c || St() && !s.doNotReject || be(d, t.cssClasses.tap) && !s.doNotReject || e === f.start && c.buttons !== void 0 && c.buttons > 1 || s.hover && c.buttons) return !1;
            p || c.preventDefault(), c.calcPoint = c.points[t.ort], a(c, s);
        }, o = [];
        return e.split(" ").forEach(function(h) {
            i.addEventListener(h, l, p ? {
                passive: !0
            } : !1), o.push([
                h,
                l
            ]);
        }), o;
    }
    function Qt(e, i, a) {
        var s = e.type.indexOf("touch") === 0, l = e.type.indexOf("mouse") === 0, o = e.type.indexOf("pointer") === 0, h = 0, c = 0;
        if (e.type.indexOf("MSPointer") === 0 && (o = !0), e.type === "mousedown" && !e.buttons && !e.touches) return !1;
        if (s) {
            var x = function(E) {
                var g = E.target;
                return g === a || a.contains(g) || e.composed && e.composedPath().shift() === a;
            };
            if (e.type === "touchstart") {
                var S = Array.prototype.filter.call(e.touches, x);
                if (S.length > 1) return !1;
                h = S[0].pageX, c = S[0].pageY;
            } else {
                var w = Array.prototype.find.call(e.changedTouches, x);
                if (!w) return !1;
                h = w.pageX, c = w.pageY;
            }
        }
        return i = i || Rt(q), (l || o) && (h = e.clientX + i.x, c = e.clientY + i.y), e.pageOffset = i, e.points = [
            h,
            c
        ], e.cursor = l || o, e;
    }
    function Et(e) {
        var i = e - Se(b, t.ort), a = i * 100 / wt();
        return a = Ht(a), t.dir ? 100 - a : a;
    }
    function te(e) {
        var i = 100, a = !1;
        return v.forEach(function(s, l) {
            if (!et(l)) {
                var o = C[l], h = Math.abs(o - e), c = h === 100 && i === 100, x = h < i, S = h <= i && e > o;
                (x || S || c) && (a = l, i = h);
            }
        }), a;
    }
    function ee(e, i) {
        e.type === "mouseout" && e.target.nodeName === "HTML" && e.relatedTarget === null && st(e, i);
    }
    function re(e, i) {
        if (navigator.appVersion.indexOf("MSIE 9") === -1 && e.buttons === 0 && i.buttonsProperty !== 0) return st(e, i);
        var a = (t.dir ? -1 : 1) * (e.calcPoint - i.startCalcPoint), s = a * 100 / i.baseSize;
        Ct(a > 0, s, i.locations, i.handleNumbers, i.connect);
    }
    function st(e, i) {
        i.handle && (Z(i.handle, t.cssClasses.active), tt -= 1), i.listeners.forEach(function(a) {
            X.removeEventListener(a[0], a[1]);
        }), tt === 0 && (Z(d, t.cssClasses.drag), ft(), e.cursor && (Y.style.cursor = "", Y.removeEventListener("selectstart", _t))), t.events.smoothSteps && (i.handleNumbers.forEach(function(a) {
            K(a, C[a], !0, !0, !1, !1);
        }), i.handleNumbers.forEach(function(a) {
            P("update", a);
        })), i.handleNumbers.forEach(function(a) {
            P("change", a), P("set", a), P("end", a);
        });
    }
    function nt(e, i) {
        if (!i.handleNumbers.some(et)) {
            var a;
            if (i.handleNumbers.length === 1) {
                var s = v[i.handleNumbers[0]];
                a = s.children[0], tt += 1, M(a, t.cssClasses.active);
            }
            e.stopPropagation();
            var l = [], o = B(f.move, X, re, {
                target: e.target,
                handle: a,
                connect: i.connect,
                listeners: l,
                startCalcPoint: e.calcPoint,
                baseSize: wt(),
                pageOffset: e.pageOffset,
                handleNumbers: i.handleNumbers,
                buttonsProperty: e.buttons,
                locations: C.slice()
            }), h = B(f.end, X, st, {
                target: e.target,
                handle: a,
                listeners: l,
                doNotReject: !0,
                handleNumbers: i.handleNumbers
            }), c = B("mouseout", X, ee, {
                target: e.target,
                handle: a,
                listeners: l,
                doNotReject: !0,
                handleNumbers: i.handleNumbers
            });
            l.push.apply(l, o.concat(h, c)), e.cursor && (Y.style.cursor = getComputedStyle(e.target).cursor, v.length > 1 && M(d, t.cssClasses.drag), Y.addEventListener("selectstart", _t, !1)), i.handleNumbers.forEach(function(x) {
                P("start", x);
            });
        }
    }
    function ie(e) {
        e.stopPropagation();
        var i = Et(e.calcPoint), a = te(i);
        a !== !1 && (t.events.snap || Ot(d, t.cssClasses.tap, t.animationDuration), K(a, i, !0, !0), ft(), P("slide", a, !0), P("update", a, !0), t.events.snap ? nt(e, {
            handleNumbers: [
                a
            ]
        }) : (P("change", a, !0), P("set", a, !0)));
    }
    function ae(e) {
        var i = Et(e.calcPoint), a = m.getStep(i), s = m.fromStepping(a);
        Object.keys(R).forEach(function(l) {
            l.split(".")[0] === "hover" && R[l].forEach(function(o) {
                o.call(J, s);
            });
        });
    }
    function se(e, i) {
        if (St() || et(i)) return !1;
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
        t.dir && !t.ort ? a.reverse() : t.ort && !t.dir && (s.reverse(), l.reverse());
        var h = e.key.replace("Arrow", ""), c = h === l[0], x = h === l[1], S = h === s[0] || h === a[0] || c, w = h === s[1] || h === a[1] || x, E = h === o[0], g = h === o[1];
        if (!S && !w && !E && !g) return !0;
        e.preventDefault();
        var A;
        if (w || S) {
            var y = S ? 0 : 1, D = kt(i), k = D[y];
            if (k === null) return !1;
            k === !1 && (k = m.getDefaultStep(C[i], S, t.keyboardDefaultStep)), x || c ? k *= t.keyboardPageMultiplier : k *= t.keyboardMultiplier, k = Math.max(k, 1e-7), k = (S ? -1 : 1) * k, A = z[i] + k;
        } else g ? A = t.spectrum.xVal[t.spectrum.xVal.length - 1] : A = t.spectrum.xVal[0];
        return K(i, m.toStepping(A), !0, !0), P("slide", i), P("update", i), P("change", i), P("set", i), !1;
    }
    function ne(e) {
        e.fixed || v.forEach(function(i, a) {
            B(f.start, i.children[0], nt, {
                handleNumbers: [
                    a
                ]
            });
        }), e.tap && B(f.start, b, ie, {}), e.hover && B(f.move, b, ae, {
            hover: !0
        }), e.drag && U.forEach(function(i, a) {
            if (!(i === !1 || a === 0 || a === U.length - 1)) {
                var s = v[a - 1], l = v[a], o = [
                    i
                ], h = [
                    s,
                    l
                ], c = [
                    a - 1,
                    a
                ];
                M(i, t.cssClasses.draggable), e.fixed && (o.push(s.children[0]), o.push(l.children[0])), e.dragAll && (h = v, c = _), o.forEach(function(x) {
                    B(f.start, x, nt, {
                        handles: h,
                        handleNumbers: c,
                        connect: i
                    });
                });
            }
        });
    }
    function ot(e, i) {
        R[e] = R[e] || [], R[e].push(i), e.split(".")[0] === "update" && v.forEach(function(a, s) {
            P("update", s);
        });
    }
    function oe(e) {
        return e === F.aria || e === F.tooltips;
    }
    function I(e) {
        var i = e && e.split(".")[0], a = i ? e.substring(i.length) : e;
        Object.keys(R).forEach(function(s) {
            var l = s.split(".")[0], o = s.substring(l.length);
            (!i || i === l) && (!a || a === o) && (!oe(o) || a === o) && delete R[s];
        });
    }
    function P(e, i, a) {
        Object.keys(R).forEach(function(s) {
            var l = s.split(".")[0];
            e === l && R[s].forEach(function(o) {
                o.call(J, z.map(t.format.to), i, z.slice(), a || !1, C.slice(), J);
            });
        });
    }
    function W(e, i, a, s, l, o, h) {
        var c;
        return v.length > 1 && !t.events.unconstrained && (s && i > 0 && (c = m.getAbsoluteDistance(e[i - 1], t.margin, !1), a = Math.max(a, c)), l && i < v.length - 1 && (c = m.getAbsoluteDistance(e[i + 1], t.margin, !0), a = Math.min(a, c))), v.length > 1 && t.limit && (s && i > 0 && (c = m.getAbsoluteDistance(e[i - 1], t.limit, !1), a = Math.min(a, c)), l && i < v.length - 1 && (c = m.getAbsoluteDistance(e[i + 1], t.limit, !0), a = Math.max(a, c))), t.padding && (i === 0 && (c = m.getAbsoluteDistance(0, t.padding[0], !1), a = Math.max(a, c)), i === v.length - 1 && (c = m.getAbsoluteDistance(100, t.padding[1], !0), a = Math.min(a, c))), h || (a = m.getStep(a)), a = Ht(a), a === e[i] && !o ? !1 : a;
    }
    function lt(e, i) {
        var a = t.ort;
        return (a ? i : e) + ", " + (a ? e : i);
    }
    function Ct(e, i, a, s, l) {
        var o = a.slice(), h = s[0], c = t.events.smoothSteps, x = [
            !e,
            e
        ], S = [
            e,
            !e
        ];
        s = s.slice(), e && s.reverse(), s.length > 1 ? s.forEach(function(E, g) {
            var A = W(o, E, o[E] + i, x[g], S[g], !1, c);
            A === !1 ? i = 0 : (i = A - o[E], o[E] = A);
        }) : x = S = [
            !0
        ];
        var w = !1;
        s.forEach(function(E, g) {
            w = K(E, a[E] + i, x[g], S[g], !1, c) || w;
        }), w && (s.forEach(function(E) {
            P("update", E), P("slide", E);
        }), l != null && P("drag", h));
    }
    function Pt(e, i) {
        return t.dir ? 100 - e - i : e;
    }
    function le(e, i) {
        C[e] = i, z[e] = m.fromStepping(i);
        var a = Pt(i, 0) - Kt, s = "translate(" + lt(a + "%", "0") + ")";
        v[e].style[t.transformRule] = s, At(e), At(e + 1);
    }
    function ft() {
        _.forEach(function(e) {
            var i = C[e] > 50 ? -1 : 1, a = 3 + (v.length + i * e);
            v[e].style.zIndex = String(a);
        });
    }
    function K(e, i, a, s, l, o) {
        return l || (i = W(C, e, i, a, s, !1, o)), i === !1 ? !1 : (le(e, i), !0);
    }
    function At(e) {
        if (U[e]) {
            var i = 0, a = 100;
            e !== 0 && (i = C[e - 1]), e !== U.length - 1 && (a = C[e]);
            var s = a - i, l = "translate(" + lt(Pt(i, s) + "%", "0") + ")", o = "scale(" + lt(s / 100, "1") + ")";
            U[e].style[t.transformRule] = l + " " + o;
        }
    }
    function Vt(e, i) {
        return e === null || e === !1 || e === void 0 || (typeof e == "number" && (e = String(e)), e = t.format.from(e), e !== !1 && (e = m.toStepping(e)), e === !1 || isNaN(e)) ? C[i] : e;
    }
    function G(e, i, a) {
        var s = Q(e), l = C[0] === void 0;
        i = i === void 0 ? !0 : i, t.animate && !l && Ot(d, t.cssClasses.tap, t.animationDuration), _.forEach(function(c) {
            K(c, Vt(s[c], c), !0, !1, a);
        });
        var o = _.length === 1 ? 0 : 1;
        if (l && m.hasNoSize() && (a = !0, C[0] = 0, _.length > 1)) {
            var h = 100 / (_.length - 1);
            _.forEach(function(c) {
                C[c] = c * h;
            });
        }
        for(; o < _.length; ++o)_.forEach(function(c) {
            K(c, C[c], !0, !0, a);
        });
        ft(), _.forEach(function(c) {
            P("update", c), s[c] !== null && i && P("set", c);
        });
    }
    function fe(e) {
        G(t.start, e);
    }
    function ue(e, i, a, s) {
        if (e = Number(e), !(e >= 0 && e < _.length)) throw new Error("noUiSlider: invalid handle number, got: " + e);
        K(e, Vt(i, e), !0, !0, s), P("update", e), a && P("set", e);
    }
    function Dt(e) {
        if (e === void 0 && (e = !1), e) return z.length === 1 ? z[0] : z.slice(0);
        var i = z.map(t.format.to);
        return i.length === 1 ? i[0] : i;
    }
    function ce() {
        for(I(F.aria), I(F.tooltips), Object.keys(t.cssClasses).forEach(function(e) {
            Z(d, t.cssClasses[e]);
        }); d.firstChild;)d.removeChild(d.firstChild);
        delete d.noUiSlider;
    }
    function kt(e) {
        var i = C[e], a = m.getNearbySteps(i), s = z[e], l = a.thisStep.step, o = null;
        if (t.snap) return [
            s - a.stepBefore.startValue || null,
            a.stepAfter.startValue - s || null
        ];
        l !== !1 && s + l > a.stepAfter.startValue && (l = a.stepAfter.startValue - s), s > a.thisStep.startValue ? o = a.thisStep.step : a.stepBefore.step === !1 ? o = !1 : o = s - a.stepBefore.highestStep, i === 100 ? l = null : i === 0 && (o = null);
        var h = m.countStepDecimals();
        return l !== null && l !== !1 && (l = Number(l.toFixed(h))), o !== null && o !== !1 && (o = Number(o.toFixed(h))), [
            o,
            l
        ];
    }
    function he() {
        return _.map(kt);
    }
    function ve(e, i) {
        var a = Dt(), s = [
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
            e[o] !== void 0 && (n[o] = e[o]);
        });
        var l = Bt(n);
        s.forEach(function(o) {
            e[o] !== void 0 && (t[o] = l[o]);
        }), m = l.spectrum, t.margin = l.margin, t.limit = l.limit, t.padding = l.padding, t.pips ? at(t.pips) : it(), t.tooltips ? xt() : rt(), C = [], G(dt(e.start) ? e.start : a, i);
    }
    function de() {
        b = Tt(d), It(t.connect, b), ne(t.events), G(t.start), t.pips && at(t.pips), t.tooltips && xt(), Gt();
    }
    de();
    var J = {
        destroy: ce,
        steps: he,
        on: ot,
        off: I,
        get: Dt,
        set: G,
        setHandle: ue,
        reset: fe,
        disable: Yt,
        enable: Wt,
        __moveHandles: function(e, i, a) {
            Ct(e, i, C, a);
        },
        options: n,
        updateOptions: ve,
        target: d,
        removePips: it,
        removeTooltips: rt,
        getPositions: function() {
            return C.slice();
        },
        getTooltips: function() {
            return V;
        },
        getOrigins: function() {
            return v;
        },
        pips: at
    };
    return J;
}
function Qe(r, t) {
    if (!r || !r.nodeName) throw new Error("noUiSlider: create requires a single element, got: " + r);
    if (r.noUiSlider) throw new Error("noUiSlider: Slider was already initialized.");
    var n = Bt(t), f = $e(r, n, t);
    return r.noUiSlider = f, f;
}
var tr = {
    __spectrum: jt,
    cssClasses: Ft,
    create: Qe
};
export { N as PipsMode, L as PipsType, Qe as create, Ft as cssClasses, tr as default };

