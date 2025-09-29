// deno-fmt-ignore-file
// deno-lint-ignore-file
// This code was bundled using `deno bundle` and it's not recommended to edit it manually

class SourceLocation {
    constructor(lexer, start, end){
        this.lexer = void 0;
        this.start = void 0;
        this.end = void 0;
        this.lexer = lexer;
        this.start = start;
        this.end = end;
    }
    static range(first, second) {
        if (!second) {
            return first && first.loc;
        } else if (!first || !first.loc || !second.loc || first.loc.lexer !== second.loc.lexer) {
            return null;
        } else {
            return new SourceLocation(first.loc.lexer, first.loc.start, second.loc.end);
        }
    }
}
class Token {
    constructor(text, loc){
        this.text = void 0;
        this.loc = void 0;
        this.noexpand = void 0;
        this.treatAsRelax = void 0;
        this.text = text;
        this.loc = loc;
    }
    range(endToken, text) {
        return new Token(text, SourceLocation.range(this, endToken));
    }
}
class ParseError {
    constructor(message, token){
        this.name = void 0;
        this.position = void 0;
        this.length = void 0;
        this.rawMessage = void 0;
        var error = "KaTeX parse error: " + message;
        var start;
        var end;
        var loc = token && token.loc;
        if (loc && loc.start <= loc.end) {
            var input = loc.lexer.input;
            start = loc.start;
            end = loc.end;
            if (start === input.length) {
                error += " at end of input: ";
            } else {
                error += " at position " + (start + 1) + ": ";
            }
            var underlined = input.slice(start, end).replace(/[^]/g, "$&\u0332");
            var left;
            if (start > 15) {
                left = "…" + input.slice(start - 15, start);
            } else {
                left = input.slice(0, start);
            }
            var right;
            if (end + 15 < input.length) {
                right = input.slice(end, end + 15) + "…";
            } else {
                right = input.slice(end);
            }
            error += left + underlined + right;
        }
        var self = new Error(error);
        self.name = "ParseError";
        self.__proto__ = ParseError.prototype;
        self.position = start;
        if (start != null && end != null) {
            self.length = end - start;
        }
        self.rawMessage = message;
        return self;
    }
}
ParseError.prototype.__proto__ = Error.prototype;
var contains = function contains(list, elem) {
    return list.indexOf(elem) !== -1;
};
var deflt = function deflt(setting, defaultIfUndefined) {
    return setting === undefined ? defaultIfUndefined : setting;
};
var uppercase = /([A-Z])/g;
var hyphenate = function hyphenate(str) {
    return str.replace(uppercase, "-$1").toLowerCase();
};
var ESCAPE_LOOKUP = {
    "&": "&amp;",
    ">": "&gt;",
    "<": "&lt;",
    "\"": "&quot;",
    "'": "&#x27;"
};
var ESCAPE_REGEX = /[&><"']/g;
function escape(text) {
    return String(text).replace(ESCAPE_REGEX, (match)=>ESCAPE_LOOKUP[match]);
}
var getBaseElem = function getBaseElem(group) {
    if (group.type === "ordgroup") {
        if (group.body.length === 1) {
            return getBaseElem(group.body[0]);
        } else {
            return group;
        }
    } else if (group.type === "color") {
        if (group.body.length === 1) {
            return getBaseElem(group.body[0]);
        } else {
            return group;
        }
    } else if (group.type === "font") {
        return getBaseElem(group.body);
    } else {
        return group;
    }
};
var isCharacterBox = function isCharacterBox(group) {
    var baseElem = getBaseElem(group);
    return baseElem.type === "mathord" || baseElem.type === "textord" || baseElem.type === "atom";
};
var assert = function assert(value) {
    if (!value) {
        throw new Error('Expected non-null, but got ' + String(value));
    }
    return value;
};
var protocolFromUrl = function protocolFromUrl(url) {
    var protocol = /^\s*([^\\/#]*?)(?::|&#0*58|&#x0*3a)/i.exec(url);
    return protocol != null ? protocol[1] : "_relative";
};
var utils = {
    contains,
    deflt,
    escape,
    hyphenate,
    getBaseElem,
    isCharacterBox,
    protocolFromUrl
};
var SETTINGS_SCHEMA = {
    displayMode: {
        type: "boolean",
        description: "Render math in display mode, which puts the math in " + "display style (so \\int and \\sum are large, for example), and " + "centers the math on the page on its own line.",
        cli: "-d, --display-mode"
    },
    output: {
        type: {
            enum: [
                "htmlAndMathml",
                "html",
                "mathml"
            ]
        },
        description: "Determines the markup language of the output.",
        cli: "-F, --format <type>"
    },
    leqno: {
        type: "boolean",
        description: "Render display math in leqno style (left-justified tags)."
    },
    fleqn: {
        type: "boolean",
        description: "Render display math flush left."
    },
    throwOnError: {
        type: "boolean",
        default: true,
        cli: "-t, --no-throw-on-error",
        cliDescription: "Render errors (in the color given by --error-color) ins" + "tead of throwing a ParseError exception when encountering an error."
    },
    errorColor: {
        type: "string",
        default: "#cc0000",
        cli: "-c, --error-color <color>",
        cliDescription: "A color string given in the format 'rgb' or 'rrggbb' " + "(no #). This option determines the color of errors rendered by the " + "-t option.",
        cliProcessor: (color)=>"#" + color
    },
    macros: {
        type: "object",
        cli: "-m, --macro <def>",
        cliDescription: "Define custom macro of the form '\\foo:expansion' (use " + "multiple -m arguments for multiple macros).",
        cliDefault: [],
        cliProcessor: (def, defs)=>{
            defs.push(def);
            return defs;
        }
    },
    minRuleThickness: {
        type: "number",
        description: "Specifies a minimum thickness, in ems, for fraction lines," + " `\\sqrt` top lines, `{array}` vertical lines, `\\hline`, " + "`\\hdashline`, `\\underline`, `\\overline`, and the borders of " + "`\\fbox`, `\\boxed`, and `\\fcolorbox`.",
        processor: (t)=>Math.max(0, t),
        cli: "--min-rule-thickness <size>",
        cliProcessor: parseFloat
    },
    colorIsTextColor: {
        type: "boolean",
        description: "Makes \\color behave like LaTeX's 2-argument \\textcolor, " + "instead of LaTeX's one-argument \\color mode change.",
        cli: "-b, --color-is-text-color"
    },
    strict: {
        type: [
            {
                enum: [
                    "warn",
                    "ignore",
                    "error"
                ]
            },
            "boolean",
            "function"
        ],
        description: "Turn on strict / LaTeX faithfulness mode, which throws an " + "error if the input uses features that are not supported by LaTeX.",
        cli: "-S, --strict",
        cliDefault: false
    },
    trust: {
        type: [
            "boolean",
            "function"
        ],
        description: "Trust the input, enabling all HTML features such as \\url.",
        cli: "-T, --trust"
    },
    maxSize: {
        type: "number",
        default: Infinity,
        description: "If non-zero, all user-specified sizes, e.g. in " + "\\rule{500em}{500em}, will be capped to maxSize ems. Otherwise, " + "elements and spaces can be arbitrarily large",
        processor: (s)=>Math.max(0, s),
        cli: "-s, --max-size <n>",
        cliProcessor: parseInt
    },
    maxExpand: {
        type: "number",
        default: 1000,
        description: "Limit the number of macro expansions to the specified " + "number, to prevent e.g. infinite macro loops. If set to Infinity, " + "the macro expander will try to fully expand as in LaTeX.",
        processor: (n)=>Math.max(0, n),
        cli: "-e, --max-expand <n>",
        cliProcessor: (n)=>n === "Infinity" ? Infinity : parseInt(n)
    },
    globalGroup: {
        type: "boolean",
        cli: false
    }
};
function getDefaultValue(schema) {
    if (schema.default) {
        return schema.default;
    }
    var type = schema.type;
    var defaultType = Array.isArray(type) ? type[0] : type;
    if (typeof defaultType !== 'string') {
        return defaultType.enum[0];
    }
    switch(defaultType){
        case 'boolean':
            return false;
        case 'string':
            return '';
        case 'number':
            return 0;
        case 'object':
            return {};
    }
}
class Settings {
    constructor(options){
        this.displayMode = void 0;
        this.output = void 0;
        this.leqno = void 0;
        this.fleqn = void 0;
        this.throwOnError = void 0;
        this.errorColor = void 0;
        this.macros = void 0;
        this.minRuleThickness = void 0;
        this.colorIsTextColor = void 0;
        this.strict = void 0;
        this.trust = void 0;
        this.maxSize = void 0;
        this.maxExpand = void 0;
        this.globalGroup = void 0;
        options = options || {};
        for(var prop in SETTINGS_SCHEMA){
            if (SETTINGS_SCHEMA.hasOwnProperty(prop)) {
                var schema = SETTINGS_SCHEMA[prop];
                this[prop] = options[prop] !== undefined ? schema.processor ? schema.processor(options[prop]) : options[prop] : getDefaultValue(schema);
            }
        }
    }
    reportNonstrict(errorCode, errorMsg, token) {
        var strict = this.strict;
        if (typeof strict === "function") {
            strict = strict(errorCode, errorMsg, token);
        }
        if (!strict || strict === "ignore") {
            return;
        } else if (strict === true || strict === "error") {
            throw new ParseError("LaTeX-incompatible input and strict mode is set to 'error': " + (errorMsg + " [" + errorCode + "]"), token);
        } else if (strict === "warn") {
            typeof console !== "undefined" && console.warn("LaTeX-incompatible input and strict mode is set to 'warn': " + (errorMsg + " [" + errorCode + "]"));
        } else {
            typeof console !== "undefined" && console.warn("LaTeX-incompatible input and strict mode is set to " + ("unrecognized '" + strict + "': " + errorMsg + " [" + errorCode + "]"));
        }
    }
    useStrictBehavior(errorCode, errorMsg, token) {
        var strict = this.strict;
        if (typeof strict === "function") {
            try {
                strict = strict(errorCode, errorMsg, token);
            } catch (error) {
                strict = "error";
            }
        }
        if (!strict || strict === "ignore") {
            return false;
        } else if (strict === true || strict === "error") {
            return true;
        } else if (strict === "warn") {
            typeof console !== "undefined" && console.warn("LaTeX-incompatible input and strict mode is set to 'warn': " + (errorMsg + " [" + errorCode + "]"));
            return false;
        } else {
            typeof console !== "undefined" && console.warn("LaTeX-incompatible input and strict mode is set to " + ("unrecognized '" + strict + "': " + errorMsg + " [" + errorCode + "]"));
            return false;
        }
    }
    isTrusted(context) {
        if (context.url && !context.protocol) {
            context.protocol = utils.protocolFromUrl(context.url);
        }
        var trust = typeof this.trust === "function" ? this.trust(context) : this.trust;
        return Boolean(trust);
    }
}
class Style {
    constructor(id, size, cramped){
        this.id = void 0;
        this.size = void 0;
        this.cramped = void 0;
        this.id = id;
        this.size = size;
        this.cramped = cramped;
    }
    sup() {
        return styles[sup[this.id]];
    }
    sub() {
        return styles[sub[this.id]];
    }
    fracNum() {
        return styles[fracNum[this.id]];
    }
    fracDen() {
        return styles[fracDen[this.id]];
    }
    cramp() {
        return styles[cramp[this.id]];
    }
    text() {
        return styles[text$1[this.id]];
    }
    isTight() {
        return this.size >= 2;
    }
}
var D = 0;
var Dc = 1;
var T = 2;
var Tc = 3;
var S = 4;
var Sc = 5;
var SS = 6;
var SSc = 7;
var styles = [
    new Style(D, 0, false),
    new Style(Dc, 0, true),
    new Style(T, 1, false),
    new Style(Tc, 1, true),
    new Style(S, 2, false),
    new Style(Sc, 2, true),
    new Style(SS, 3, false),
    new Style(SSc, 3, true)
];
var sup = [
    S,
    Sc,
    S,
    Sc,
    SS,
    SSc,
    SS,
    SSc
];
var sub = [
    Sc,
    Sc,
    Sc,
    Sc,
    SSc,
    SSc,
    SSc,
    SSc
];
var fracNum = [
    T,
    Tc,
    S,
    Sc,
    SS,
    SSc,
    SS,
    SSc
];
var fracDen = [
    Tc,
    Tc,
    Sc,
    Sc,
    SSc,
    SSc,
    SSc,
    SSc
];
var cramp = [
    Dc,
    Dc,
    Tc,
    Tc,
    Sc,
    Sc,
    SSc,
    SSc
];
var text$1 = [
    D,
    Dc,
    T,
    Tc,
    T,
    Tc,
    T,
    Tc
];
var Style$1 = {
    DISPLAY: styles[D],
    TEXT: styles[T],
    SCRIPT: styles[S],
    SCRIPTSCRIPT: styles[SS]
};
var scriptData = [
    {
        name: 'latin',
        blocks: [
            [
                0x0100,
                0x024f
            ],
            [
                0x0300,
                0x036f
            ]
        ]
    },
    {
        name: 'cyrillic',
        blocks: [
            [
                0x0400,
                0x04ff
            ]
        ]
    },
    {
        name: 'armenian',
        blocks: [
            [
                0x0530,
                0x058F
            ]
        ]
    },
    {
        name: 'brahmic',
        blocks: [
            [
                0x0900,
                0x109F
            ]
        ]
    },
    {
        name: 'georgian',
        blocks: [
            [
                0x10A0,
                0x10ff
            ]
        ]
    },
    {
        name: "cjk",
        blocks: [
            [
                0x3000,
                0x30FF
            ],
            [
                0x4E00,
                0x9FAF
            ],
            [
                0xFF00,
                0xFF60
            ]
        ]
    },
    {
        name: 'hangul',
        blocks: [
            [
                0xAC00,
                0xD7AF
            ]
        ]
    }
];
function scriptFromCodepoint(codepoint) {
    for(var i = 0; i < scriptData.length; i++){
        var script = scriptData[i];
        for(var _i = 0; _i < script.blocks.length; _i++){
            var block = script.blocks[_i];
            if (codepoint >= block[0] && codepoint <= block[1]) {
                return script.name;
            }
        }
    }
    return null;
}
var allBlocks = [];
scriptData.forEach((s)=>s.blocks.forEach((b)=>allBlocks.push(...b)));
function supportedCodepoint(codepoint) {
    for(var i = 0; i < allBlocks.length; i += 2){
        if (codepoint >= allBlocks[i] && codepoint <= allBlocks[i + 1]) {
            return true;
        }
    }
    return false;
}
var hLinePad = 80;
var sqrtMain = function sqrtMain(extraVinculum, hLinePad) {
    return "M95," + (622 + extraVinculum + hLinePad) + "\nc-2.7,0,-7.17,-2.7,-13.5,-8c-5.8,-5.3,-9.5,-10,-9.5,-14\nc0,-2,0.3,-3.3,1,-4c1.3,-2.7,23.83,-20.7,67.5,-54\nc44.2,-33.3,65.8,-50.3,66.5,-51c1.3,-1.3,3,-2,5,-2c4.7,0,8.7,3.3,12,10\ns173,378,173,378c0.7,0,35.3,-71,104,-213c68.7,-142,137.5,-285,206.5,-429\nc69,-144,104.5,-217.7,106.5,-221\nl" + extraVinculum / 2.075 + " -" + extraVinculum + "\nc5.3,-9.3,12,-14,20,-14\nH400000v" + (40 + extraVinculum) + "H845.2724\ns-225.272,467,-225.272,467s-235,486,-235,486c-2.7,4.7,-9,7,-19,7\nc-6,0,-10,-1,-12,-3s-194,-422,-194,-422s-65,47,-65,47z\nM" + (834 + extraVinculum) + " " + hLinePad + "h400000v" + (40 + extraVinculum) + "h-400000z";
};
var sqrtSize1 = function sqrtSize1(extraVinculum, hLinePad) {
    return "M263," + (601 + extraVinculum + hLinePad) + "c0.7,0,18,39.7,52,119\nc34,79.3,68.167,158.7,102.5,238c34.3,79.3,51.8,119.3,52.5,120\nc340,-704.7,510.7,-1060.3,512,-1067\nl" + extraVinculum / 2.084 + " -" + extraVinculum + "\nc4.7,-7.3,11,-11,19,-11\nH40000v" + (40 + extraVinculum) + "H1012.3\ns-271.3,567,-271.3,567c-38.7,80.7,-84,175,-136,283c-52,108,-89.167,185.3,-111.5,232\nc-22.3,46.7,-33.8,70.3,-34.5,71c-4.7,4.7,-12.3,7,-23,7s-12,-1,-12,-1\ns-109,-253,-109,-253c-72.7,-168,-109.3,-252,-110,-252c-10.7,8,-22,16.7,-34,26\nc-22,17.3,-33.3,26,-34,26s-26,-26,-26,-26s76,-59,76,-59s76,-60,76,-60z\nM" + (1001 + extraVinculum) + " " + hLinePad + "h400000v" + (40 + extraVinculum) + "h-400000z";
};
var sqrtSize2 = function sqrtSize2(extraVinculum, hLinePad) {
    return "M983 " + (10 + extraVinculum + hLinePad) + "\nl" + extraVinculum / 3.13 + " -" + extraVinculum + "\nc4,-6.7,10,-10,18,-10 H400000v" + (40 + extraVinculum) + "\nH1013.1s-83.4,268,-264.1,840c-180.7,572,-277,876.3,-289,913c-4.7,4.7,-12.7,7,-24,7\ns-12,0,-12,0c-1.3,-3.3,-3.7,-11.7,-7,-25c-35.3,-125.3,-106.7,-373.3,-214,-744\nc-10,12,-21,25,-33,39s-32,39,-32,39c-6,-5.3,-15,-14,-27,-26s25,-30,25,-30\nc26.7,-32.7,52,-63,76,-91s52,-60,52,-60s208,722,208,722\nc56,-175.3,126.3,-397.3,211,-666c84.7,-268.7,153.8,-488.2,207.5,-658.5\nc53.7,-170.3,84.5,-266.8,92.5,-289.5z\nM" + (1001 + extraVinculum) + " " + hLinePad + "h400000v" + (40 + extraVinculum) + "h-400000z";
};
var sqrtSize3 = function sqrtSize3(extraVinculum, hLinePad) {
    return "M424," + (2398 + extraVinculum + hLinePad) + "\nc-1.3,-0.7,-38.5,-172,-111.5,-514c-73,-342,-109.8,-513.3,-110.5,-514\nc0,-2,-10.7,14.3,-32,49c-4.7,7.3,-9.8,15.7,-15.5,25c-5.7,9.3,-9.8,16,-12.5,20\ns-5,7,-5,7c-4,-3.3,-8.3,-7.7,-13,-13s-13,-13,-13,-13s76,-122,76,-122s77,-121,77,-121\ns209,968,209,968c0,-2,84.7,-361.7,254,-1079c169.3,-717.3,254.7,-1077.7,256,-1081\nl" + extraVinculum / 4.223 + " -" + extraVinculum + "c4,-6.7,10,-10,18,-10 H400000\nv" + (40 + extraVinculum) + "H1014.6\ns-87.3,378.7,-272.6,1166c-185.3,787.3,-279.3,1182.3,-282,1185\nc-2,6,-10,9,-24,9\nc-8,0,-12,-0.7,-12,-2z M" + (1001 + extraVinculum) + " " + hLinePad + "\nh400000v" + (40 + extraVinculum) + "h-400000z";
};
var sqrtSize4 = function sqrtSize4(extraVinculum, hLinePad) {
    return "M473," + (2713 + extraVinculum + hLinePad) + "\nc339.3,-1799.3,509.3,-2700,510,-2702 l" + extraVinculum / 5.298 + " -" + extraVinculum + "\nc3.3,-7.3,9.3,-11,18,-11 H400000v" + (40 + extraVinculum) + "H1017.7\ns-90.5,478,-276.2,1466c-185.7,988,-279.5,1483,-281.5,1485c-2,6,-10,9,-24,9\nc-8,0,-12,-0.7,-12,-2c0,-1.3,-5.3,-32,-16,-92c-50.7,-293.3,-119.7,-693.3,-207,-1200\nc0,-1.3,-5.3,8.7,-16,30c-10.7,21.3,-21.3,42.7,-32,64s-16,33,-16,33s-26,-26,-26,-26\ns76,-153,76,-153s77,-151,77,-151c0.7,0.7,35.7,202,105,604c67.3,400.7,102,602.7,104,\n606zM" + (1001 + extraVinculum) + " " + hLinePad + "h400000v" + (40 + extraVinculum) + "H1017.7z";
};
var phasePath = function phasePath(y) {
    var x = y / 2;
    return "M400000 " + y + " H0 L" + x + " 0 l65 45 L145 " + (y - 80) + " H400000z";
};
var sqrtTall = function sqrtTall(extraVinculum, hLinePad, viewBoxHeight) {
    var vertSegment = viewBoxHeight - 54 - hLinePad - extraVinculum;
    return "M702 " + (extraVinculum + hLinePad) + "H400000" + (40 + extraVinculum) + "\nH742v" + vertSegment + "l-4 4-4 4c-.667.7 -2 1.5-4 2.5s-4.167 1.833-6.5 2.5-5.5 1-9.5 1\nh-12l-28-84c-16.667-52-96.667 -294.333-240-727l-212 -643 -85 170\nc-4-3.333-8.333-7.667-13 -13l-13-13l77-155 77-156c66 199.333 139 419.667\n219 661 l218 661zM702 " + hLinePad + "H400000v" + (40 + extraVinculum) + "H742z";
};
var sqrtPath = function sqrtPath(size, extraVinculum, viewBoxHeight) {
    extraVinculum = 1000 * extraVinculum;
    var path = "";
    switch(size){
        case "sqrtMain":
            path = sqrtMain(extraVinculum, hLinePad);
            break;
        case "sqrtSize1":
            path = sqrtSize1(extraVinculum, hLinePad);
            break;
        case "sqrtSize2":
            path = sqrtSize2(extraVinculum, hLinePad);
            break;
        case "sqrtSize3":
            path = sqrtSize3(extraVinculum, hLinePad);
            break;
        case "sqrtSize4":
            path = sqrtSize4(extraVinculum, hLinePad);
            break;
        case "sqrtTall":
            path = sqrtTall(extraVinculum, hLinePad, viewBoxHeight);
    }
    return path;
};
var innerPath = function innerPath(name, height) {
    switch(name){
        case "\u239c":
            return "M291 0 H417 V" + height + " H291z M291 0 H417 V" + height + " H291z";
        case "\u2223":
            return "M145 0 H188 V" + height + " H145z M145 0 H188 V" + height + " H145z";
        case "\u2225":
            return "M145 0 H188 V" + height + " H145z M145 0 H188 V" + height + " H145z" + ("M367 0 H410 V" + height + " H367z M367 0 H410 V" + height + " H367z");
        case "\u239f":
            return "M457 0 H583 V" + height + " H457z M457 0 H583 V" + height + " H457z";
        case "\u23a2":
            return "M319 0 H403 V" + height + " H319z M319 0 H403 V" + height + " H319z";
        case "\u23a5":
            return "M263 0 H347 V" + height + " H263z M263 0 H347 V" + height + " H263z";
        case "\u23aa":
            return "M384 0 H504 V" + height + " H384z M384 0 H504 V" + height + " H384z";
        case "\u23d0":
            return "M312 0 H355 V" + height + " H312z M312 0 H355 V" + height + " H312z";
        case "\u2016":
            return "M257 0 H300 V" + height + " H257z M257 0 H300 V" + height + " H257z" + ("M478 0 H521 V" + height + " H478z M478 0 H521 V" + height + " H478z");
        default:
            return "";
    }
};
var path = {
    doubleleftarrow: "M262 157\nl10-10c34-36 62.7-77 86-123 3.3-8 5-13.3 5-16 0-5.3-6.7-8-20-8-7.3\n 0-12.2.5-14.5 1.5-2.3 1-4.8 4.5-7.5 10.5-49.3 97.3-121.7 169.3-217 216-28\n 14-57.3 25-88 33-6.7 2-11 3.8-13 5.5-2 1.7-3 4.2-3 7.5s1 5.8 3 7.5\nc2 1.7 6.3 3.5 13 5.5 68 17.3 128.2 47.8 180.5 91.5 52.3 43.7 93.8 96.2 124.5\n 157.5 9.3 8 15.3 12.3 18 13h6c12-.7 18-4 18-10 0-2-1.7-7-5-15-23.3-46-52-87\n-86-123l-10-10h399738v-40H218c328 0 0 0 0 0l-10-8c-26.7-20-65.7-43-117-69 2.7\n-2 6-3.7 10-5 36.7-16 72.3-37.3 107-64l10-8h399782v-40z\nm8 0v40h399730v-40zm0 194v40h399730v-40z",
    doublerightarrow: "M399738 392l\n-10 10c-34 36-62.7 77-86 123-3.3 8-5 13.3-5 16 0 5.3 6.7 8 20 8 7.3 0 12.2-.5\n 14.5-1.5 2.3-1 4.8-4.5 7.5-10.5 49.3-97.3 121.7-169.3 217-216 28-14 57.3-25 88\n-33 6.7-2 11-3.8 13-5.5 2-1.7 3-4.2 3-7.5s-1-5.8-3-7.5c-2-1.7-6.3-3.5-13-5.5-68\n-17.3-128.2-47.8-180.5-91.5-52.3-43.7-93.8-96.2-124.5-157.5-9.3-8-15.3-12.3-18\n-13h-6c-12 .7-18 4-18 10 0 2 1.7 7 5 15 23.3 46 52 87 86 123l10 10H0v40h399782\nc-328 0 0 0 0 0l10 8c26.7 20 65.7 43 117 69-2.7 2-6 3.7-10 5-36.7 16-72.3 37.3\n-107 64l-10 8H0v40zM0 157v40h399730v-40zm0 194v40h399730v-40z",
    leftarrow: "M400000 241H110l3-3c68.7-52.7 113.7-120\n 135-202 4-14.7 6-23 6-25 0-7.3-7-11-21-11-8 0-13.2.8-15.5 2.5-2.3 1.7-4.2 5.8\n-5.5 12.5-1.3 4.7-2.7 10.3-4 17-12 48.7-34.8 92-68.5 130S65.3 228.3 18 247\nc-10 4-16 7.7-18 11 0 8.7 6 14.3 18 17 47.3 18.7 87.8 47 121.5 85S196 441.3 208\n 490c.7 2 1.3 5 2 9s1.2 6.7 1.5 8c.3 1.3 1 3.3 2 6s2.2 4.5 3.5 5.5c1.3 1 3.3\n 1.8 6 2.5s6 1 10 1c14 0 21-3.7 21-11 0-2-2-10.3-6-25-20-79.3-65-146.7-135-202\n l-3-3h399890zM100 241v40h399900v-40z",
    leftbrace: "M6 548l-6-6v-35l6-11c56-104 135.3-181.3 238-232 57.3-28.7 117\n-45 179-50h399577v120H403c-43.3 7-81 15-113 26-100.7 33-179.7 91-237 174-2.7\n 5-6 9-10 13-.7 1-7.3 1-20 1H6z",
    leftbraceunder: "M0 6l6-6h17c12.688 0 19.313.3 20 1 4 4 7.313 8.3 10 13\n 35.313 51.3 80.813 93.8 136.5 127.5 55.688 33.7 117.188 55.8 184.5 66.5.688\n 0 2 .3 4 1 18.688 2.7 76 4.3 172 5h399450v120H429l-6-1c-124.688-8-235-61.7\n-331-161C60.687 138.7 32.312 99.3 7 54L0 41V6z",
    leftgroup: "M400000 80\nH435C64 80 168.3 229.4 21 260c-5.9 1.2-18 0-18 0-2 0-3-1-3-3v-38C76 61 257 0\n 435 0h399565z",
    leftgroupunder: "M400000 262\nH435C64 262 168.3 112.6 21 82c-5.9-1.2-18 0-18 0-2 0-3 1-3 3v38c76 158 257 219\n 435 219h399565z",
    leftharpoon: "M0 267c.7 5.3 3 10 7 14h399993v-40H93c3.3\n-3.3 10.2-9.5 20.5-18.5s17.8-15.8 22.5-20.5c50.7-52 88-110.3 112-175 4-11.3 5\n-18.3 3-21-1.3-4-7.3-6-18-6-8 0-13 .7-15 2s-4.7 6.7-8 16c-42 98.7-107.3 174.7\n-196 228-6.7 4.7-10.7 8-12 10-1.3 2-2 5.7-2 11zm100-26v40h399900v-40z",
    leftharpoonplus: "M0 267c.7 5.3 3 10 7 14h399993v-40H93c3.3-3.3 10.2-9.5\n 20.5-18.5s17.8-15.8 22.5-20.5c50.7-52 88-110.3 112-175 4-11.3 5-18.3 3-21-1.3\n-4-7.3-6-18-6-8 0-13 .7-15 2s-4.7 6.7-8 16c-42 98.7-107.3 174.7-196 228-6.7 4.7\n-10.7 8-12 10-1.3 2-2 5.7-2 11zm100-26v40h399900v-40zM0 435v40h400000v-40z\nm0 0v40h400000v-40z",
    leftharpoondown: "M7 241c-4 4-6.333 8.667-7 14 0 5.333.667 9 2 11s5.333\n 5.333 12 10c90.667 54 156 130 196 228 3.333 10.667 6.333 16.333 9 17 2 .667 5\n 1 9 1h5c10.667 0 16.667-2 18-6 2-2.667 1-9.667-3-21-32-87.333-82.667-157.667\n-152-211l-3-3h399907v-40zM93 281 H400000 v-40L7 241z",
    leftharpoondownplus: "M7 435c-4 4-6.3 8.7-7 14 0 5.3.7 9 2 11s5.3 5.3 12\n 10c90.7 54 156 130 196 228 3.3 10.7 6.3 16.3 9 17 2 .7 5 1 9 1h5c10.7 0 16.7\n-2 18-6 2-2.7 1-9.7-3-21-32-87.3-82.7-157.7-152-211l-3-3h399907v-40H7zm93 0\nv40h399900v-40zM0 241v40h399900v-40zm0 0v40h399900v-40z",
    lefthook: "M400000 281 H103s-33-11.2-61-33.5S0 197.3 0 164s14.2-61.2 42.5\n-83.5C70.8 58.2 104 47 142 47 c16.7 0 25 6.7 25 20 0 12-8.7 18.7-26 20-40 3.3\n-68.7 15.7-86 37-10 12-15 25.3-15 40 0 22.7 9.8 40.7 29.5 54 19.7 13.3 43.5 21\n 71.5 23h399859zM103 281v-40h399897v40z",
    leftlinesegment: "M40 281 V428 H0 V94 H40 V241 H400000 v40z\nM40 281 V428 H0 V94 H40 V241 H400000 v40z",
    leftmapsto: "M40 281 V448H0V74H40V241H400000v40z\nM40 281 V448H0V74H40V241H400000v40z",
    leftToFrom: "M0 147h400000v40H0zm0 214c68 40 115.7 95.7 143 167h22c15.3 0 23\n-.3 23-1 0-1.3-5.3-13.7-16-37-18-35.3-41.3-69-70-101l-7-8h399905v-40H95l7-8\nc28.7-32 52-65.7 70-101 10.7-23.3 16-35.7 16-37 0-.7-7.7-1-23-1h-22C115.7 265.3\n 68 321 0 361zm0-174v-40h399900v40zm100 154v40h399900v-40z",
    longequal: "M0 50 h400000 v40H0z m0 194h40000v40H0z\nM0 50 h400000 v40H0z m0 194h40000v40H0z",
    midbrace: "M200428 334\nc-100.7-8.3-195.3-44-280-108-55.3-42-101.7-93-139-153l-9-14c-2.7 4-5.7 8.7-9 14\n-53.3 86.7-123.7 153-211 199-66.7 36-137.3 56.3-212 62H0V214h199568c178.3-11.7\n 311.7-78.3 403-201 6-8 9.7-12 11-12 .7-.7 6.7-1 18-1s17.3.3 18 1c1.3 0 5 4 11\n 12 44.7 59.3 101.3 106.3 170 141s145.3 54.3 229 60h199572v120z",
    midbraceunder: "M199572 214\nc100.7 8.3 195.3 44 280 108 55.3 42 101.7 93 139 153l9 14c2.7-4 5.7-8.7 9-14\n 53.3-86.7 123.7-153 211-199 66.7-36 137.3-56.3 212-62h199568v120H200432c-178.3\n 11.7-311.7 78.3-403 201-6 8-9.7 12-11 12-.7.7-6.7 1-18 1s-17.3-.3-18-1c-1.3 0\n-5-4-11-12-44.7-59.3-101.3-106.3-170-141s-145.3-54.3-229-60H0V214z",
    oiintSize1: "M512.6 71.6c272.6 0 320.3 106.8 320.3 178.2 0 70.8-47.7 177.6\n-320.3 177.6S193.1 320.6 193.1 249.8c0-71.4 46.9-178.2 319.5-178.2z\nm368.1 178.2c0-86.4-60.9-215.4-368.1-215.4-306.4 0-367.3 129-367.3 215.4 0 85.8\n60.9 214.8 367.3 214.8 307.2 0 368.1-129 368.1-214.8z",
    oiintSize2: "M757.8 100.1c384.7 0 451.1 137.6 451.1 230 0 91.3-66.4 228.8\n-451.1 228.8-386.3 0-452.7-137.5-452.7-228.8 0-92.4 66.4-230 452.7-230z\nm502.4 230c0-111.2-82.4-277.2-502.4-277.2s-504 166-504 277.2\nc0 110 84 276 504 276s502.4-166 502.4-276z",
    oiiintSize1: "M681.4 71.6c408.9 0 480.5 106.8 480.5 178.2 0 70.8-71.6 177.6\n-480.5 177.6S202.1 320.6 202.1 249.8c0-71.4 70.5-178.2 479.3-178.2z\nm525.8 178.2c0-86.4-86.8-215.4-525.7-215.4-437.9 0-524.7 129-524.7 215.4 0\n85.8 86.8 214.8 524.7 214.8 438.9 0 525.7-129 525.7-214.8z",
    oiiintSize2: "M1021.2 53c603.6 0 707.8 165.8 707.8 277.2 0 110-104.2 275.8\n-707.8 275.8-606 0-710.2-165.8-710.2-275.8C311 218.8 415.2 53 1021.2 53z\nm770.4 277.1c0-131.2-126.4-327.6-770.5-327.6S248.4 198.9 248.4 330.1\nc0 130 128.8 326.4 772.7 326.4s770.5-196.4 770.5-326.4z",
    rightarrow: "M0 241v40h399891c-47.3 35.3-84 78-110 128\n-16.7 32-27.7 63.7-33 95 0 1.3-.2 2.7-.5 4-.3 1.3-.5 2.3-.5 3 0 7.3 6.7 11 20\n 11 8 0 13.2-.8 15.5-2.5 2.3-1.7 4.2-5.5 5.5-11.5 2-13.3 5.7-27 11-41 14.7-44.7\n 39-84.5 73-119.5s73.7-60.2 119-75.5c6-2 9-5.7 9-11s-3-9-9-11c-45.3-15.3-85\n-40.5-119-75.5s-58.3-74.8-73-119.5c-4.7-14-8.3-27.3-11-40-1.3-6.7-3.2-10.8-5.5\n-12.5-2.3-1.7-7.5-2.5-15.5-2.5-14 0-21 3.7-21 11 0 2 2 10.3 6 25 20.7 83.3 67\n 151.7 139 205zm0 0v40h399900v-40z",
    rightbrace: "M400000 542l\n-6 6h-17c-12.7 0-19.3-.3-20-1-4-4-7.3-8.3-10-13-35.3-51.3-80.8-93.8-136.5-127.5\ns-117.2-55.8-184.5-66.5c-.7 0-2-.3-4-1-18.7-2.7-76-4.3-172-5H0V214h399571l6 1\nc124.7 8 235 61.7 331 161 31.3 33.3 59.7 72.7 85 118l7 13v35z",
    rightbraceunder: "M399994 0l6 6v35l-6 11c-56 104-135.3 181.3-238 232-57.3\n 28.7-117 45-179 50H-300V214h399897c43.3-7 81-15 113-26 100.7-33 179.7-91 237\n-174 2.7-5 6-9 10-13 .7-1 7.3-1 20-1h17z",
    rightgroup: "M0 80h399565c371 0 266.7 149.4 414 180 5.9 1.2 18 0 18 0 2 0\n 3-1 3-3v-38c-76-158-257-219-435-219H0z",
    rightgroupunder: "M0 262h399565c371 0 266.7-149.4 414-180 5.9-1.2 18 0 18\n 0 2 0 3 1 3 3v38c-76 158-257 219-435 219H0z",
    rightharpoon: "M0 241v40h399993c4.7-4.7 7-9.3 7-14 0-9.3\n-3.7-15.3-11-18-92.7-56.7-159-133.7-199-231-3.3-9.3-6-14.7-8-16-2-1.3-7-2-15-2\n-10.7 0-16.7 2-18 6-2 2.7-1 9.7 3 21 15.3 42 36.7 81.8 64 119.5 27.3 37.7 58\n 69.2 92 94.5zm0 0v40h399900v-40z",
    rightharpoonplus: "M0 241v40h399993c4.7-4.7 7-9.3 7-14 0-9.3-3.7-15.3-11\n-18-92.7-56.7-159-133.7-199-231-3.3-9.3-6-14.7-8-16-2-1.3-7-2-15-2-10.7 0-16.7\n 2-18 6-2 2.7-1 9.7 3 21 15.3 42 36.7 81.8 64 119.5 27.3 37.7 58 69.2 92 94.5z\nm0 0v40h399900v-40z m100 194v40h399900v-40zm0 0v40h399900v-40z",
    rightharpoondown: "M399747 511c0 7.3 6.7 11 20 11 8 0 13-.8 15-2.5s4.7-6.8\n 8-15.5c40-94 99.3-166.3 178-217 13.3-8 20.3-12.3 21-13 5.3-3.3 8.5-5.8 9.5\n-7.5 1-1.7 1.5-5.2 1.5-10.5s-2.3-10.3-7-15H0v40h399908c-34 25.3-64.7 57-92 95\n-27.3 38-48.7 77.7-64 119-3.3 8.7-5 14-5 16zM0 241v40h399900v-40z",
    rightharpoondownplus: "M399747 705c0 7.3 6.7 11 20 11 8 0 13-.8\n 15-2.5s4.7-6.8 8-15.5c40-94 99.3-166.3 178-217 13.3-8 20.3-12.3 21-13 5.3-3.3\n 8.5-5.8 9.5-7.5 1-1.7 1.5-5.2 1.5-10.5s-2.3-10.3-7-15H0v40h399908c-34 25.3\n-64.7 57-92 95-27.3 38-48.7 77.7-64 119-3.3 8.7-5 14-5 16zM0 435v40h399900v-40z\nm0-194v40h400000v-40zm0 0v40h400000v-40z",
    righthook: "M399859 241c-764 0 0 0 0 0 40-3.3 68.7-15.7 86-37 10-12 15-25.3\n 15-40 0-22.7-9.8-40.7-29.5-54-19.7-13.3-43.5-21-71.5-23-17.3-1.3-26-8-26-20 0\n-13.3 8.7-20 26-20 38 0 71 11.2 99 33.5 0 0 7 5.6 21 16.7 14 11.2 21 33.5 21\n 66.8s-14 61.2-42 83.5c-28 22.3-61 33.5-99 33.5L0 241z M0 281v-40h399859v40z",
    rightlinesegment: "M399960 241 V94 h40 V428 h-40 V281 H0 v-40z\nM399960 241 V94 h40 V428 h-40 V281 H0 v-40z",
    rightToFrom: "M400000 167c-70.7-42-118-97.7-142-167h-23c-15.3 0-23 .3-23\n 1 0 1.3 5.3 13.7 16 37 18 35.3 41.3 69 70 101l7 8H0v40h399905l-7 8c-28.7 32\n-52 65.7-70 101-10.7 23.3-16 35.7-16 37 0 .7 7.7 1 23 1h23c24-69.3 71.3-125 142\n-167z M100 147v40h399900v-40zM0 341v40h399900v-40z",
    twoheadleftarrow: "M0 167c68 40\n 115.7 95.7 143 167h22c15.3 0 23-.3 23-1 0-1.3-5.3-13.7-16-37-18-35.3-41.3-69\n-70-101l-7-8h125l9 7c50.7 39.3 85 86 103 140h46c0-4.7-6.3-18.7-19-42-18-35.3\n-40-67.3-66-96l-9-9h399716v-40H284l9-9c26-28.7 48-60.7 66-96 12.7-23.333 19\n-37.333 19-42h-46c-18 54-52.3 100.7-103 140l-9 7H95l7-8c28.7-32 52-65.7 70-101\n 10.7-23.333 16-35.7 16-37 0-.7-7.7-1-23-1h-22C115.7 71.3 68 127 0 167z",
    twoheadrightarrow: "M400000 167\nc-68-40-115.7-95.7-143-167h-22c-15.3 0-23 .3-23 1 0 1.3 5.3 13.7 16 37 18 35.3\n 41.3 69 70 101l7 8h-125l-9-7c-50.7-39.3-85-86-103-140h-46c0 4.7 6.3 18.7 19 42\n 18 35.3 40 67.3 66 96l9 9H0v40h399716l-9 9c-26 28.7-48 60.7-66 96-12.7 23.333\n-19 37.333-19 42h46c18-54 52.3-100.7 103-140l9-7h125l-7 8c-28.7 32-52 65.7-70\n 101-10.7 23.333-16 35.7-16 37 0 .7 7.7 1 23 1h22c27.3-71.3 75-127 143-167z",
    tilde1: "M200 55.538c-77 0-168 73.953-177 73.953-3 0-7\n-2.175-9-5.437L2 97c-1-2-2-4-2-6 0-4 2-7 5-9l20-12C116 12 171 0 207 0c86 0\n 114 68 191 68 78 0 168-68 177-68 4 0 7 2 9 5l12 19c1 2.175 2 4.35 2 6.525 0\n 4.35-2 7.613-5 9.788l-19 13.05c-92 63.077-116.937 75.308-183 76.128\n-68.267.847-113-73.952-191-73.952z",
    tilde2: "M344 55.266c-142 0-300.638 81.316-311.5 86.418\n-8.01 3.762-22.5 10.91-23.5 5.562L1 120c-1-2-1-3-1-4 0-5 3-9 8-10l18.4-9C160.9\n 31.9 283 0 358 0c148 0 188 122 331 122s314-97 326-97c4 0 8 2 10 7l7 21.114\nc1 2.14 1 3.21 1 4.28 0 5.347-3 9.626-7 10.696l-22.3 12.622C852.6 158.372 751\n 181.476 676 181.476c-149 0-189-126.21-332-126.21z",
    tilde3: "M786 59C457 59 32 175.242 13 175.242c-6 0-10-3.457\n-11-10.37L.15 138c-1-7 3-12 10-13l19.2-6.4C378.4 40.7 634.3 0 804.3 0c337 0\n 411.8 157 746.8 157 328 0 754-112 773-112 5 0 10 3 11 9l1 14.075c1 8.066-.697\n 16.595-6.697 17.492l-21.052 7.31c-367.9 98.146-609.15 122.696-778.15 122.696\n -338 0-409-156.573-744-156.573z",
    tilde4: "M786 58C457 58 32 177.487 13 177.487c-6 0-10-3.345\n-11-10.035L.15 143c-1-7 3-12 10-13l22-6.7C381.2 35 637.15 0 807.15 0c337 0 409\n 177 744 177 328 0 754-127 773-127 5 0 10 3 11 9l1 14.794c1 7.805-3 13.38-9\n 14.495l-20.7 5.574c-366.85 99.79-607.3 139.372-776.3 139.372-338 0-409\n -175.236-744-175.236z",
    vec: "M377 20c0-5.333 1.833-10 5.5-14S391 0 397 0c4.667 0 8.667 1.667 12 5\n3.333 2.667 6.667 9 10 19 6.667 24.667 20.333 43.667 41 57 7.333 4.667 11\n10.667 11 18 0 6-1 10-3 12s-6.667 5-14 9c-28.667 14.667-53.667 35.667-75 63\n-1.333 1.333-3.167 3.5-5.5 6.5s-4 4.833-5 5.5c-1 .667-2.5 1.333-4.5 2s-4.333 1\n-7 1c-4.667 0-9.167-1.833-13.5-5.5S337 184 337 178c0-12.667 15.667-32.333 47-59\nH213l-171-1c-8.667-6-13-12.333-13-19 0-4.667 4.333-11.333 13-20h359\nc-16-25.333-24-45-24-59z",
    widehat1: "M529 0h5l519 115c5 1 9 5 9 10 0 1-1 2-1 3l-4 22\nc-1 5-5 9-11 9h-2L532 67 19 159h-2c-5 0-9-4-11-9l-5-22c-1-6 2-12 8-13z",
    widehat2: "M1181 0h2l1171 176c6 0 10 5 10 11l-2 23c-1 6-5 10\n-11 10h-1L1182 67 15 220h-1c-6 0-10-4-11-10l-2-23c-1-6 4-11 10-11z",
    widehat3: "M1181 0h2l1171 236c6 0 10 5 10 11l-2 23c-1 6-5 10\n-11 10h-1L1182 67 15 280h-1c-6 0-10-4-11-10l-2-23c-1-6 4-11 10-11z",
    widehat4: "M1181 0h2l1171 296c6 0 10 5 10 11l-2 23c-1 6-5 10\n-11 10h-1L1182 67 15 340h-1c-6 0-10-4-11-10l-2-23c-1-6 4-11 10-11z",
    widecheck1: "M529,159h5l519,-115c5,-1,9,-5,9,-10c0,-1,-1,-2,-1,-3l-4,-22c-1,\n-5,-5,-9,-11,-9h-2l-512,92l-513,-92h-2c-5,0,-9,4,-11,9l-5,22c-1,6,2,12,8,13z",
    widecheck2: "M1181,220h2l1171,-176c6,0,10,-5,10,-11l-2,-23c-1,-6,-5,-10,\n-11,-10h-1l-1168,153l-1167,-153h-1c-6,0,-10,4,-11,10l-2,23c-1,6,4,11,10,11z",
    widecheck3: "M1181,280h2l1171,-236c6,0,10,-5,10,-11l-2,-23c-1,-6,-5,-10,\n-11,-10h-1l-1168,213l-1167,-213h-1c-6,0,-10,4,-11,10l-2,23c-1,6,4,11,10,11z",
    widecheck4: "M1181,340h2l1171,-296c6,0,10,-5,10,-11l-2,-23c-1,-6,-5,-10,\n-11,-10h-1l-1168,273l-1167,-273h-1c-6,0,-10,4,-11,10l-2,23c-1,6,4,11,10,11z",
    baraboveleftarrow: "M400000 620h-399890l3 -3c68.7 -52.7 113.7 -120 135 -202\nc4 -14.7 6 -23 6 -25c0 -7.3 -7 -11 -21 -11c-8 0 -13.2 0.8 -15.5 2.5\nc-2.3 1.7 -4.2 5.8 -5.5 12.5c-1.3 4.7 -2.7 10.3 -4 17c-12 48.7 -34.8 92 -68.5 130\ns-74.2 66.3 -121.5 85c-10 4 -16 7.7 -18 11c0 8.7 6 14.3 18 17c47.3 18.7 87.8 47\n121.5 85s56.5 81.3 68.5 130c0.7 2 1.3 5 2 9s1.2 6.7 1.5 8c0.3 1.3 1 3.3 2 6\ns2.2 4.5 3.5 5.5c1.3 1 3.3 1.8 6 2.5s6 1 10 1c14 0 21 -3.7 21 -11\nc0 -2 -2 -10.3 -6 -25c-20 -79.3 -65 -146.7 -135 -202l-3 -3h399890z\nM100 620v40h399900v-40z M0 241v40h399900v-40zM0 241v40h399900v-40z",
    rightarrowabovebar: "M0 241v40h399891c-47.3 35.3-84 78-110 128-16.7 32\n-27.7 63.7-33 95 0 1.3-.2 2.7-.5 4-.3 1.3-.5 2.3-.5 3 0 7.3 6.7 11 20 11 8 0\n13.2-.8 15.5-2.5 2.3-1.7 4.2-5.5 5.5-11.5 2-13.3 5.7-27 11-41 14.7-44.7 39\n-84.5 73-119.5s73.7-60.2 119-75.5c6-2 9-5.7 9-11s-3-9-9-11c-45.3-15.3-85-40.5\n-119-75.5s-58.3-74.8-73-119.5c-4.7-14-8.3-27.3-11-40-1.3-6.7-3.2-10.8-5.5\n-12.5-2.3-1.7-7.5-2.5-15.5-2.5-14 0-21 3.7-21 11 0 2 2 10.3 6 25 20.7 83.3 67\n151.7 139 205zm96 379h399894v40H0zm0 0h399904v40H0z",
    baraboveshortleftharpoon: "M507,435c-4,4,-6.3,8.7,-7,14c0,5.3,0.7,9,2,11\nc1.3,2,5.3,5.3,12,10c90.7,54,156,130,196,228c3.3,10.7,6.3,16.3,9,17\nc2,0.7,5,1,9,1c0,0,5,0,5,0c10.7,0,16.7,-2,18,-6c2,-2.7,1,-9.7,-3,-21\nc-32,-87.3,-82.7,-157.7,-152,-211c0,0,-3,-3,-3,-3l399351,0l0,-40\nc-398570,0,-399437,0,-399437,0z M593 435 v40 H399500 v-40z\nM0 281 v-40 H399908 v40z M0 281 v-40 H399908 v40z",
    rightharpoonaboveshortbar: "M0,241 l0,40c399126,0,399993,0,399993,0\nc4.7,-4.7,7,-9.3,7,-14c0,-9.3,-3.7,-15.3,-11,-18c-92.7,-56.7,-159,-133.7,-199,\n-231c-3.3,-9.3,-6,-14.7,-8,-16c-2,-1.3,-7,-2,-15,-2c-10.7,0,-16.7,2,-18,6\nc-2,2.7,-1,9.7,3,21c15.3,42,36.7,81.8,64,119.5c27.3,37.7,58,69.2,92,94.5z\nM0 241 v40 H399908 v-40z M0 475 v-40 H399500 v40z M0 475 v-40 H399500 v40z",
    shortbaraboveleftharpoon: "M7,435c-4,4,-6.3,8.7,-7,14c0,5.3,0.7,9,2,11\nc1.3,2,5.3,5.3,12,10c90.7,54,156,130,196,228c3.3,10.7,6.3,16.3,9,17c2,0.7,5,1,9,\n1c0,0,5,0,5,0c10.7,0,16.7,-2,18,-6c2,-2.7,1,-9.7,-3,-21c-32,-87.3,-82.7,-157.7,\n-152,-211c0,0,-3,-3,-3,-3l399907,0l0,-40c-399126,0,-399993,0,-399993,0z\nM93 435 v40 H400000 v-40z M500 241 v40 H400000 v-40z M500 241 v40 H400000 v-40z",
    shortrightharpoonabovebar: "M53,241l0,40c398570,0,399437,0,399437,0\nc4.7,-4.7,7,-9.3,7,-14c0,-9.3,-3.7,-15.3,-11,-18c-92.7,-56.7,-159,-133.7,-199,\n-231c-3.3,-9.3,-6,-14.7,-8,-16c-2,-1.3,-7,-2,-15,-2c-10.7,0,-16.7,2,-18,6\nc-2,2.7,-1,9.7,3,21c15.3,42,36.7,81.8,64,119.5c27.3,37.7,58,69.2,92,94.5z\nM500 241 v40 H399408 v-40z M500 435 v40 H400000 v-40z"
};
var tallDelim = function tallDelim(label, midHeight) {
    switch(label){
        case "lbrack":
            return "M403 1759 V84 H666 V0 H319 V1759 v" + midHeight + " v1759 h347 v-84\nH403z M403 1759 V0 H319 V1759 v" + midHeight + " v1759 h84z";
        case "rbrack":
            return "M347 1759 V0 H0 V84 H263 V1759 v" + midHeight + " v1759 H0 v84 H347z\nM347 1759 V0 H263 V1759 v" + midHeight + " v1759 h84z";
        case "vert":
            return "M145 15 v585 v" + midHeight + " v585 c2.667,10,9.667,15,21,15\nc10,0,16.667,-5,20,-15 v-585 v" + -midHeight + " v-585 c-2.667,-10,-9.667,-15,-21,-15\nc-10,0,-16.667,5,-20,15z M188 15 H145 v585 v" + midHeight + " v585 h43z";
        case "doublevert":
            return "M145 15 v585 v" + midHeight + " v585 c2.667,10,9.667,15,21,15\nc10,0,16.667,-5,20,-15 v-585 v" + -midHeight + " v-585 c-2.667,-10,-9.667,-15,-21,-15\nc-10,0,-16.667,5,-20,15z M188 15 H145 v585 v" + midHeight + " v585 h43z\nM367 15 v585 v" + midHeight + " v585 c2.667,10,9.667,15,21,15\nc10,0,16.667,-5,20,-15 v-585 v" + -midHeight + " v-585 c-2.667,-10,-9.667,-15,-21,-15\nc-10,0,-16.667,5,-20,15z M410 15 H367 v585 v" + midHeight + " v585 h43z";
        case "lfloor":
            return "M319 602 V0 H403 V602 v" + midHeight + " v1715 h263 v84 H319z\nMM319 602 V0 H403 V602 v" + midHeight + " v1715 H319z";
        case "rfloor":
            return "M319 602 V0 H403 V602 v" + midHeight + " v1799 H0 v-84 H319z\nMM319 602 V0 H403 V602 v" + midHeight + " v1715 H319z";
        case "lceil":
            return "M403 1759 V84 H666 V0 H319 V1759 v" + midHeight + " v602 h84z\nM403 1759 V0 H319 V1759 v" + midHeight + " v602 h84z";
        case "rceil":
            return "M347 1759 V0 H0 V84 H263 V1759 v" + midHeight + " v602 h84z\nM347 1759 V0 h-84 V1759 v" + midHeight + " v602 h84z";
        case "lparen":
            return "M863,9c0,-2,-2,-5,-6,-9c0,0,-17,0,-17,0c-12.7,0,-19.3,0.3,-20,1\nc-5.3,5.3,-10.3,11,-15,17c-242.7,294.7,-395.3,682,-458,1162c-21.3,163.3,-33.3,349,\n-36,557 l0," + (midHeight + 84) + "c0.2,6,0,26,0,60c2,159.3,10,310.7,24,454c53.3,528,210,\n949.7,470,1265c4.7,6,9.7,11.7,15,17c0.7,0.7,7,1,19,1c0,0,18,0,18,0c4,-4,6,-7,6,-9\nc0,-2.7,-3.3,-8.7,-10,-18c-135.3,-192.7,-235.5,-414.3,-300.5,-665c-65,-250.7,-102.5,\n-544.7,-112.5,-882c-2,-104,-3,-167,-3,-189\nl0,-" + (midHeight + 92) + "c0,-162.7,5.7,-314,17,-454c20.7,-272,63.7,-513,129,-723c65.3,\n-210,155.3,-396.3,270,-559c6.7,-9.3,10,-15.3,10,-18z";
        case "rparen":
            return "M76,0c-16.7,0,-25,3,-25,9c0,2,2,6.3,6,13c21.3,28.7,42.3,60.3,\n63,95c96.7,156.7,172.8,332.5,228.5,527.5c55.7,195,92.8,416.5,111.5,664.5\nc11.3,139.3,17,290.7,17,454c0,28,1.7,43,3.3,45l0," + (midHeight + 9) + "\nc-3,4,-3.3,16.7,-3.3,38c0,162,-5.7,313.7,-17,455c-18.7,248,-55.8,469.3,-111.5,664\nc-55.7,194.7,-131.8,370.3,-228.5,527c-20.7,34.7,-41.7,66.3,-63,95c-2,3.3,-4,7,-6,11\nc0,7.3,5.7,11,17,11c0,0,11,0,11,0c9.3,0,14.3,-0.3,15,-1c5.3,-5.3,10.3,-11,15,-17\nc242.7,-294.7,395.3,-681.7,458,-1161c21.3,-164.7,33.3,-350.7,36,-558\nl0,-" + (midHeight + 144) + "c-2,-159.3,-10,-310.7,-24,-454c-53.3,-528,-210,-949.7,\n-470,-1265c-4.7,-6,-9.7,-11.7,-15,-17c-0.7,-0.7,-6.7,-1,-18,-1z";
        default:
            throw new Error("Unknown stretchy delimiter.");
    }
};
class DocumentFragment {
    constructor(children){
        this.children = void 0;
        this.classes = void 0;
        this.height = void 0;
        this.depth = void 0;
        this.maxFontSize = void 0;
        this.style = void 0;
        this.children = children;
        this.classes = [];
        this.height = 0;
        this.depth = 0;
        this.maxFontSize = 0;
        this.style = {};
    }
    hasClass(className) {
        return utils.contains(this.classes, className);
    }
    toNode() {
        var frag = document.createDocumentFragment();
        for(var i = 0; i < this.children.length; i++){
            frag.appendChild(this.children[i].toNode());
        }
        return frag;
    }
    toMarkup() {
        var markup = "";
        for(var i = 0; i < this.children.length; i++){
            markup += this.children[i].toMarkup();
        }
        return markup;
    }
    toText() {
        var toText = (child)=>child.toText();
        return this.children.map(toText).join("");
    }
}
var fontMetricsData = {
    "AMS-Regular": {
        "32": [
            0,
            0,
            0,
            0,
            0.25
        ],
        "65": [
            0,
            0.68889,
            0,
            0,
            0.72222
        ],
        "66": [
            0,
            0.68889,
            0,
            0,
            0.66667
        ],
        "67": [
            0,
            0.68889,
            0,
            0,
            0.72222
        ],
        "68": [
            0,
            0.68889,
            0,
            0,
            0.72222
        ],
        "69": [
            0,
            0.68889,
            0,
            0,
            0.66667
        ],
        "70": [
            0,
            0.68889,
            0,
            0,
            0.61111
        ],
        "71": [
            0,
            0.68889,
            0,
            0,
            0.77778
        ],
        "72": [
            0,
            0.68889,
            0,
            0,
            0.77778
        ],
        "73": [
            0,
            0.68889,
            0,
            0,
            0.38889
        ],
        "74": [
            0.16667,
            0.68889,
            0,
            0,
            0.5
        ],
        "75": [
            0,
            0.68889,
            0,
            0,
            0.77778
        ],
        "76": [
            0,
            0.68889,
            0,
            0,
            0.66667
        ],
        "77": [
            0,
            0.68889,
            0,
            0,
            0.94445
        ],
        "78": [
            0,
            0.68889,
            0,
            0,
            0.72222
        ],
        "79": [
            0.16667,
            0.68889,
            0,
            0,
            0.77778
        ],
        "80": [
            0,
            0.68889,
            0,
            0,
            0.61111
        ],
        "81": [
            0.16667,
            0.68889,
            0,
            0,
            0.77778
        ],
        "82": [
            0,
            0.68889,
            0,
            0,
            0.72222
        ],
        "83": [
            0,
            0.68889,
            0,
            0,
            0.55556
        ],
        "84": [
            0,
            0.68889,
            0,
            0,
            0.66667
        ],
        "85": [
            0,
            0.68889,
            0,
            0,
            0.72222
        ],
        "86": [
            0,
            0.68889,
            0,
            0,
            0.72222
        ],
        "87": [
            0,
            0.68889,
            0,
            0,
            1.0
        ],
        "88": [
            0,
            0.68889,
            0,
            0,
            0.72222
        ],
        "89": [
            0,
            0.68889,
            0,
            0,
            0.72222
        ],
        "90": [
            0,
            0.68889,
            0,
            0,
            0.66667
        ],
        "107": [
            0,
            0.68889,
            0,
            0,
            0.55556
        ],
        "160": [
            0,
            0,
            0,
            0,
            0.25
        ],
        "165": [
            0,
            0.675,
            0.025,
            0,
            0.75
        ],
        "174": [
            0.15559,
            0.69224,
            0,
            0,
            0.94666
        ],
        "240": [
            0,
            0.68889,
            0,
            0,
            0.55556
        ],
        "295": [
            0,
            0.68889,
            0,
            0,
            0.54028
        ],
        "710": [
            0,
            0.825,
            0,
            0,
            2.33334
        ],
        "732": [
            0,
            0.9,
            0,
            0,
            2.33334
        ],
        "770": [
            0,
            0.825,
            0,
            0,
            2.33334
        ],
        "771": [
            0,
            0.9,
            0,
            0,
            2.33334
        ],
        "989": [
            0.08167,
            0.58167,
            0,
            0,
            0.77778
        ],
        "1008": [
            0,
            0.43056,
            0.04028,
            0,
            0.66667
        ],
        "8245": [
            0,
            0.54986,
            0,
            0,
            0.275
        ],
        "8463": [
            0,
            0.68889,
            0,
            0,
            0.54028
        ],
        "8487": [
            0,
            0.68889,
            0,
            0,
            0.72222
        ],
        "8498": [
            0,
            0.68889,
            0,
            0,
            0.55556
        ],
        "8502": [
            0,
            0.68889,
            0,
            0,
            0.66667
        ],
        "8503": [
            0,
            0.68889,
            0,
            0,
            0.44445
        ],
        "8504": [
            0,
            0.68889,
            0,
            0,
            0.66667
        ],
        "8513": [
            0,
            0.68889,
            0,
            0,
            0.63889
        ],
        "8592": [
            -0.03598,
            0.46402,
            0,
            0,
            0.5
        ],
        "8594": [
            -0.03598,
            0.46402,
            0,
            0,
            0.5
        ],
        "8602": [
            -0.13313,
            0.36687,
            0,
            0,
            1.0
        ],
        "8603": [
            -0.13313,
            0.36687,
            0,
            0,
            1.0
        ],
        "8606": [
            0.01354,
            0.52239,
            0,
            0,
            1.0
        ],
        "8608": [
            0.01354,
            0.52239,
            0,
            0,
            1.0
        ],
        "8610": [
            0.01354,
            0.52239,
            0,
            0,
            1.11111
        ],
        "8611": [
            0.01354,
            0.52239,
            0,
            0,
            1.11111
        ],
        "8619": [
            0,
            0.54986,
            0,
            0,
            1.0
        ],
        "8620": [
            0,
            0.54986,
            0,
            0,
            1.0
        ],
        "8621": [
            -0.13313,
            0.37788,
            0,
            0,
            1.38889
        ],
        "8622": [
            -0.13313,
            0.36687,
            0,
            0,
            1.0
        ],
        "8624": [
            0,
            0.69224,
            0,
            0,
            0.5
        ],
        "8625": [
            0,
            0.69224,
            0,
            0,
            0.5
        ],
        "8630": [
            0,
            0.43056,
            0,
            0,
            1.0
        ],
        "8631": [
            0,
            0.43056,
            0,
            0,
            1.0
        ],
        "8634": [
            0.08198,
            0.58198,
            0,
            0,
            0.77778
        ],
        "8635": [
            0.08198,
            0.58198,
            0,
            0,
            0.77778
        ],
        "8638": [
            0.19444,
            0.69224,
            0,
            0,
            0.41667
        ],
        "8639": [
            0.19444,
            0.69224,
            0,
            0,
            0.41667
        ],
        "8642": [
            0.19444,
            0.69224,
            0,
            0,
            0.41667
        ],
        "8643": [
            0.19444,
            0.69224,
            0,
            0,
            0.41667
        ],
        "8644": [
            0.1808,
            0.675,
            0,
            0,
            1.0
        ],
        "8646": [
            0.1808,
            0.675,
            0,
            0,
            1.0
        ],
        "8647": [
            0.1808,
            0.675,
            0,
            0,
            1.0
        ],
        "8648": [
            0.19444,
            0.69224,
            0,
            0,
            0.83334
        ],
        "8649": [
            0.1808,
            0.675,
            0,
            0,
            1.0
        ],
        "8650": [
            0.19444,
            0.69224,
            0,
            0,
            0.83334
        ],
        "8651": [
            0.01354,
            0.52239,
            0,
            0,
            1.0
        ],
        "8652": [
            0.01354,
            0.52239,
            0,
            0,
            1.0
        ],
        "8653": [
            -0.13313,
            0.36687,
            0,
            0,
            1.0
        ],
        "8654": [
            -0.13313,
            0.36687,
            0,
            0,
            1.0
        ],
        "8655": [
            -0.13313,
            0.36687,
            0,
            0,
            1.0
        ],
        "8666": [
            0.13667,
            0.63667,
            0,
            0,
            1.0
        ],
        "8667": [
            0.13667,
            0.63667,
            0,
            0,
            1.0
        ],
        "8669": [
            -0.13313,
            0.37788,
            0,
            0,
            1.0
        ],
        "8672": [
            -0.064,
            0.437,
            0,
            0,
            1.334
        ],
        "8674": [
            -0.064,
            0.437,
            0,
            0,
            1.334
        ],
        "8705": [
            0,
            0.825,
            0,
            0,
            0.5
        ],
        "8708": [
            0,
            0.68889,
            0,
            0,
            0.55556
        ],
        "8709": [
            0.08167,
            0.58167,
            0,
            0,
            0.77778
        ],
        "8717": [
            0,
            0.43056,
            0,
            0,
            0.42917
        ],
        "8722": [
            -0.03598,
            0.46402,
            0,
            0,
            0.5
        ],
        "8724": [
            0.08198,
            0.69224,
            0,
            0,
            0.77778
        ],
        "8726": [
            0.08167,
            0.58167,
            0,
            0,
            0.77778
        ],
        "8733": [
            0,
            0.69224,
            0,
            0,
            0.77778
        ],
        "8736": [
            0,
            0.69224,
            0,
            0,
            0.72222
        ],
        "8737": [
            0,
            0.69224,
            0,
            0,
            0.72222
        ],
        "8738": [
            0.03517,
            0.52239,
            0,
            0,
            0.72222
        ],
        "8739": [
            0.08167,
            0.58167,
            0,
            0,
            0.22222
        ],
        "8740": [
            0.25142,
            0.74111,
            0,
            0,
            0.27778
        ],
        "8741": [
            0.08167,
            0.58167,
            0,
            0,
            0.38889
        ],
        "8742": [
            0.25142,
            0.74111,
            0,
            0,
            0.5
        ],
        "8756": [
            0,
            0.69224,
            0,
            0,
            0.66667
        ],
        "8757": [
            0,
            0.69224,
            0,
            0,
            0.66667
        ],
        "8764": [
            -0.13313,
            0.36687,
            0,
            0,
            0.77778
        ],
        "8765": [
            -0.13313,
            0.37788,
            0,
            0,
            0.77778
        ],
        "8769": [
            -0.13313,
            0.36687,
            0,
            0,
            0.77778
        ],
        "8770": [
            -0.03625,
            0.46375,
            0,
            0,
            0.77778
        ],
        "8774": [
            0.30274,
            0.79383,
            0,
            0,
            0.77778
        ],
        "8776": [
            -0.01688,
            0.48312,
            0,
            0,
            0.77778
        ],
        "8778": [
            0.08167,
            0.58167,
            0,
            0,
            0.77778
        ],
        "8782": [
            0.06062,
            0.54986,
            0,
            0,
            0.77778
        ],
        "8783": [
            0.06062,
            0.54986,
            0,
            0,
            0.77778
        ],
        "8785": [
            0.08198,
            0.58198,
            0,
            0,
            0.77778
        ],
        "8786": [
            0.08198,
            0.58198,
            0,
            0,
            0.77778
        ],
        "8787": [
            0.08198,
            0.58198,
            0,
            0,
            0.77778
        ],
        "8790": [
            0,
            0.69224,
            0,
            0,
            0.77778
        ],
        "8791": [
            0.22958,
            0.72958,
            0,
            0,
            0.77778
        ],
        "8796": [
            0.08198,
            0.91667,
            0,
            0,
            0.77778
        ],
        "8806": [
            0.25583,
            0.75583,
            0,
            0,
            0.77778
        ],
        "8807": [
            0.25583,
            0.75583,
            0,
            0,
            0.77778
        ],
        "8808": [
            0.25142,
            0.75726,
            0,
            0,
            0.77778
        ],
        "8809": [
            0.25142,
            0.75726,
            0,
            0,
            0.77778
        ],
        "8812": [
            0.25583,
            0.75583,
            0,
            0,
            0.5
        ],
        "8814": [
            0.20576,
            0.70576,
            0,
            0,
            0.77778
        ],
        "8815": [
            0.20576,
            0.70576,
            0,
            0,
            0.77778
        ],
        "8816": [
            0.30274,
            0.79383,
            0,
            0,
            0.77778
        ],
        "8817": [
            0.30274,
            0.79383,
            0,
            0,
            0.77778
        ],
        "8818": [
            0.22958,
            0.72958,
            0,
            0,
            0.77778
        ],
        "8819": [
            0.22958,
            0.72958,
            0,
            0,
            0.77778
        ],
        "8822": [
            0.1808,
            0.675,
            0,
            0,
            0.77778
        ],
        "8823": [
            0.1808,
            0.675,
            0,
            0,
            0.77778
        ],
        "8828": [
            0.13667,
            0.63667,
            0,
            0,
            0.77778
        ],
        "8829": [
            0.13667,
            0.63667,
            0,
            0,
            0.77778
        ],
        "8830": [
            0.22958,
            0.72958,
            0,
            0,
            0.77778
        ],
        "8831": [
            0.22958,
            0.72958,
            0,
            0,
            0.77778
        ],
        "8832": [
            0.20576,
            0.70576,
            0,
            0,
            0.77778
        ],
        "8833": [
            0.20576,
            0.70576,
            0,
            0,
            0.77778
        ],
        "8840": [
            0.30274,
            0.79383,
            0,
            0,
            0.77778
        ],
        "8841": [
            0.30274,
            0.79383,
            0,
            0,
            0.77778
        ],
        "8842": [
            0.13597,
            0.63597,
            0,
            0,
            0.77778
        ],
        "8843": [
            0.13597,
            0.63597,
            0,
            0,
            0.77778
        ],
        "8847": [
            0.03517,
            0.54986,
            0,
            0,
            0.77778
        ],
        "8848": [
            0.03517,
            0.54986,
            0,
            0,
            0.77778
        ],
        "8858": [
            0.08198,
            0.58198,
            0,
            0,
            0.77778
        ],
        "8859": [
            0.08198,
            0.58198,
            0,
            0,
            0.77778
        ],
        "8861": [
            0.08198,
            0.58198,
            0,
            0,
            0.77778
        ],
        "8862": [
            0,
            0.675,
            0,
            0,
            0.77778
        ],
        "8863": [
            0,
            0.675,
            0,
            0,
            0.77778
        ],
        "8864": [
            0,
            0.675,
            0,
            0,
            0.77778
        ],
        "8865": [
            0,
            0.675,
            0,
            0,
            0.77778
        ],
        "8872": [
            0,
            0.69224,
            0,
            0,
            0.61111
        ],
        "8873": [
            0,
            0.69224,
            0,
            0,
            0.72222
        ],
        "8874": [
            0,
            0.69224,
            0,
            0,
            0.88889
        ],
        "8876": [
            0,
            0.68889,
            0,
            0,
            0.61111
        ],
        "8877": [
            0,
            0.68889,
            0,
            0,
            0.61111
        ],
        "8878": [
            0,
            0.68889,
            0,
            0,
            0.72222
        ],
        "8879": [
            0,
            0.68889,
            0,
            0,
            0.72222
        ],
        "8882": [
            0.03517,
            0.54986,
            0,
            0,
            0.77778
        ],
        "8883": [
            0.03517,
            0.54986,
            0,
            0,
            0.77778
        ],
        "8884": [
            0.13667,
            0.63667,
            0,
            0,
            0.77778
        ],
        "8885": [
            0.13667,
            0.63667,
            0,
            0,
            0.77778
        ],
        "8888": [
            0,
            0.54986,
            0,
            0,
            1.11111
        ],
        "8890": [
            0.19444,
            0.43056,
            0,
            0,
            0.55556
        ],
        "8891": [
            0.19444,
            0.69224,
            0,
            0,
            0.61111
        ],
        "8892": [
            0.19444,
            0.69224,
            0,
            0,
            0.61111
        ],
        "8901": [
            0,
            0.54986,
            0,
            0,
            0.27778
        ],
        "8903": [
            0.08167,
            0.58167,
            0,
            0,
            0.77778
        ],
        "8905": [
            0.08167,
            0.58167,
            0,
            0,
            0.77778
        ],
        "8906": [
            0.08167,
            0.58167,
            0,
            0,
            0.77778
        ],
        "8907": [
            0,
            0.69224,
            0,
            0,
            0.77778
        ],
        "8908": [
            0,
            0.69224,
            0,
            0,
            0.77778
        ],
        "8909": [
            -0.03598,
            0.46402,
            0,
            0,
            0.77778
        ],
        "8910": [
            0,
            0.54986,
            0,
            0,
            0.76042
        ],
        "8911": [
            0,
            0.54986,
            0,
            0,
            0.76042
        ],
        "8912": [
            0.03517,
            0.54986,
            0,
            0,
            0.77778
        ],
        "8913": [
            0.03517,
            0.54986,
            0,
            0,
            0.77778
        ],
        "8914": [
            0,
            0.54986,
            0,
            0,
            0.66667
        ],
        "8915": [
            0,
            0.54986,
            0,
            0,
            0.66667
        ],
        "8916": [
            0,
            0.69224,
            0,
            0,
            0.66667
        ],
        "8918": [
            0.0391,
            0.5391,
            0,
            0,
            0.77778
        ],
        "8919": [
            0.0391,
            0.5391,
            0,
            0,
            0.77778
        ],
        "8920": [
            0.03517,
            0.54986,
            0,
            0,
            1.33334
        ],
        "8921": [
            0.03517,
            0.54986,
            0,
            0,
            1.33334
        ],
        "8922": [
            0.38569,
            0.88569,
            0,
            0,
            0.77778
        ],
        "8923": [
            0.38569,
            0.88569,
            0,
            0,
            0.77778
        ],
        "8926": [
            0.13667,
            0.63667,
            0,
            0,
            0.77778
        ],
        "8927": [
            0.13667,
            0.63667,
            0,
            0,
            0.77778
        ],
        "8928": [
            0.30274,
            0.79383,
            0,
            0,
            0.77778
        ],
        "8929": [
            0.30274,
            0.79383,
            0,
            0,
            0.77778
        ],
        "8934": [
            0.23222,
            0.74111,
            0,
            0,
            0.77778
        ],
        "8935": [
            0.23222,
            0.74111,
            0,
            0,
            0.77778
        ],
        "8936": [
            0.23222,
            0.74111,
            0,
            0,
            0.77778
        ],
        "8937": [
            0.23222,
            0.74111,
            0,
            0,
            0.77778
        ],
        "8938": [
            0.20576,
            0.70576,
            0,
            0,
            0.77778
        ],
        "8939": [
            0.20576,
            0.70576,
            0,
            0,
            0.77778
        ],
        "8940": [
            0.30274,
            0.79383,
            0,
            0,
            0.77778
        ],
        "8941": [
            0.30274,
            0.79383,
            0,
            0,
            0.77778
        ],
        "8994": [
            0.19444,
            0.69224,
            0,
            0,
            0.77778
        ],
        "8995": [
            0.19444,
            0.69224,
            0,
            0,
            0.77778
        ],
        "9416": [
            0.15559,
            0.69224,
            0,
            0,
            0.90222
        ],
        "9484": [
            0,
            0.69224,
            0,
            0,
            0.5
        ],
        "9488": [
            0,
            0.69224,
            0,
            0,
            0.5
        ],
        "9492": [
            0,
            0.37788,
            0,
            0,
            0.5
        ],
        "9496": [
            0,
            0.37788,
            0,
            0,
            0.5
        ],
        "9585": [
            0.19444,
            0.68889,
            0,
            0,
            0.88889
        ],
        "9586": [
            0.19444,
            0.74111,
            0,
            0,
            0.88889
        ],
        "9632": [
            0,
            0.675,
            0,
            0,
            0.77778
        ],
        "9633": [
            0,
            0.675,
            0,
            0,
            0.77778
        ],
        "9650": [
            0,
            0.54986,
            0,
            0,
            0.72222
        ],
        "9651": [
            0,
            0.54986,
            0,
            0,
            0.72222
        ],
        "9654": [
            0.03517,
            0.54986,
            0,
            0,
            0.77778
        ],
        "9660": [
            0,
            0.54986,
            0,
            0,
            0.72222
        ],
        "9661": [
            0,
            0.54986,
            0,
            0,
            0.72222
        ],
        "9664": [
            0.03517,
            0.54986,
            0,
            0,
            0.77778
        ],
        "9674": [
            0.11111,
            0.69224,
            0,
            0,
            0.66667
        ],
        "9733": [
            0.19444,
            0.69224,
            0,
            0,
            0.94445
        ],
        "10003": [
            0,
            0.69224,
            0,
            0,
            0.83334
        ],
        "10016": [
            0,
            0.69224,
            0,
            0,
            0.83334
        ],
        "10731": [
            0.11111,
            0.69224,
            0,
            0,
            0.66667
        ],
        "10846": [
            0.19444,
            0.75583,
            0,
            0,
            0.61111
        ],
        "10877": [
            0.13667,
            0.63667,
            0,
            0,
            0.77778
        ],
        "10878": [
            0.13667,
            0.63667,
            0,
            0,
            0.77778
        ],
        "10885": [
            0.25583,
            0.75583,
            0,
            0,
            0.77778
        ],
        "10886": [
            0.25583,
            0.75583,
            0,
            0,
            0.77778
        ],
        "10887": [
            0.13597,
            0.63597,
            0,
            0,
            0.77778
        ],
        "10888": [
            0.13597,
            0.63597,
            0,
            0,
            0.77778
        ],
        "10889": [
            0.26167,
            0.75726,
            0,
            0,
            0.77778
        ],
        "10890": [
            0.26167,
            0.75726,
            0,
            0,
            0.77778
        ],
        "10891": [
            0.48256,
            0.98256,
            0,
            0,
            0.77778
        ],
        "10892": [
            0.48256,
            0.98256,
            0,
            0,
            0.77778
        ],
        "10901": [
            0.13667,
            0.63667,
            0,
            0,
            0.77778
        ],
        "10902": [
            0.13667,
            0.63667,
            0,
            0,
            0.77778
        ],
        "10933": [
            0.25142,
            0.75726,
            0,
            0,
            0.77778
        ],
        "10934": [
            0.25142,
            0.75726,
            0,
            0,
            0.77778
        ],
        "10935": [
            0.26167,
            0.75726,
            0,
            0,
            0.77778
        ],
        "10936": [
            0.26167,
            0.75726,
            0,
            0,
            0.77778
        ],
        "10937": [
            0.26167,
            0.75726,
            0,
            0,
            0.77778
        ],
        "10938": [
            0.26167,
            0.75726,
            0,
            0,
            0.77778
        ],
        "10949": [
            0.25583,
            0.75583,
            0,
            0,
            0.77778
        ],
        "10950": [
            0.25583,
            0.75583,
            0,
            0,
            0.77778
        ],
        "10955": [
            0.28481,
            0.79383,
            0,
            0,
            0.77778
        ],
        "10956": [
            0.28481,
            0.79383,
            0,
            0,
            0.77778
        ],
        "57350": [
            0.08167,
            0.58167,
            0,
            0,
            0.22222
        ],
        "57351": [
            0.08167,
            0.58167,
            0,
            0,
            0.38889
        ],
        "57352": [
            0.08167,
            0.58167,
            0,
            0,
            0.77778
        ],
        "57353": [
            0,
            0.43056,
            0.04028,
            0,
            0.66667
        ],
        "57356": [
            0.25142,
            0.75726,
            0,
            0,
            0.77778
        ],
        "57357": [
            0.25142,
            0.75726,
            0,
            0,
            0.77778
        ],
        "57358": [
            0.41951,
            0.91951,
            0,
            0,
            0.77778
        ],
        "57359": [
            0.30274,
            0.79383,
            0,
            0,
            0.77778
        ],
        "57360": [
            0.30274,
            0.79383,
            0,
            0,
            0.77778
        ],
        "57361": [
            0.41951,
            0.91951,
            0,
            0,
            0.77778
        ],
        "57366": [
            0.25142,
            0.75726,
            0,
            0,
            0.77778
        ],
        "57367": [
            0.25142,
            0.75726,
            0,
            0,
            0.77778
        ],
        "57368": [
            0.25142,
            0.75726,
            0,
            0,
            0.77778
        ],
        "57369": [
            0.25142,
            0.75726,
            0,
            0,
            0.77778
        ],
        "57370": [
            0.13597,
            0.63597,
            0,
            0,
            0.77778
        ],
        "57371": [
            0.13597,
            0.63597,
            0,
            0,
            0.77778
        ]
    },
    "Caligraphic-Regular": {
        "32": [
            0,
            0,
            0,
            0,
            0.25
        ],
        "65": [
            0,
            0.68333,
            0,
            0.19445,
            0.79847
        ],
        "66": [
            0,
            0.68333,
            0.03041,
            0.13889,
            0.65681
        ],
        "67": [
            0,
            0.68333,
            0.05834,
            0.13889,
            0.52653
        ],
        "68": [
            0,
            0.68333,
            0.02778,
            0.08334,
            0.77139
        ],
        "69": [
            0,
            0.68333,
            0.08944,
            0.11111,
            0.52778
        ],
        "70": [
            0,
            0.68333,
            0.09931,
            0.11111,
            0.71875
        ],
        "71": [
            0.09722,
            0.68333,
            0.0593,
            0.11111,
            0.59487
        ],
        "72": [
            0,
            0.68333,
            0.00965,
            0.11111,
            0.84452
        ],
        "73": [
            0,
            0.68333,
            0.07382,
            0,
            0.54452
        ],
        "74": [
            0.09722,
            0.68333,
            0.18472,
            0.16667,
            0.67778
        ],
        "75": [
            0,
            0.68333,
            0.01445,
            0.05556,
            0.76195
        ],
        "76": [
            0,
            0.68333,
            0,
            0.13889,
            0.68972
        ],
        "77": [
            0,
            0.68333,
            0,
            0.13889,
            1.2009
        ],
        "78": [
            0,
            0.68333,
            0.14736,
            0.08334,
            0.82049
        ],
        "79": [
            0,
            0.68333,
            0.02778,
            0.11111,
            0.79611
        ],
        "80": [
            0,
            0.68333,
            0.08222,
            0.08334,
            0.69556
        ],
        "81": [
            0.09722,
            0.68333,
            0,
            0.11111,
            0.81667
        ],
        "82": [
            0,
            0.68333,
            0,
            0.08334,
            0.8475
        ],
        "83": [
            0,
            0.68333,
            0.075,
            0.13889,
            0.60556
        ],
        "84": [
            0,
            0.68333,
            0.25417,
            0,
            0.54464
        ],
        "85": [
            0,
            0.68333,
            0.09931,
            0.08334,
            0.62583
        ],
        "86": [
            0,
            0.68333,
            0.08222,
            0,
            0.61278
        ],
        "87": [
            0,
            0.68333,
            0.08222,
            0.08334,
            0.98778
        ],
        "88": [
            0,
            0.68333,
            0.14643,
            0.13889,
            0.7133
        ],
        "89": [
            0.09722,
            0.68333,
            0.08222,
            0.08334,
            0.66834
        ],
        "90": [
            0,
            0.68333,
            0.07944,
            0.13889,
            0.72473
        ],
        "160": [
            0,
            0,
            0,
            0,
            0.25
        ]
    },
    "Fraktur-Regular": {
        "32": [
            0,
            0,
            0,
            0,
            0.25
        ],
        "33": [
            0,
            0.69141,
            0,
            0,
            0.29574
        ],
        "34": [
            0,
            0.69141,
            0,
            0,
            0.21471
        ],
        "38": [
            0,
            0.69141,
            0,
            0,
            0.73786
        ],
        "39": [
            0,
            0.69141,
            0,
            0,
            0.21201
        ],
        "40": [
            0.24982,
            0.74947,
            0,
            0,
            0.38865
        ],
        "41": [
            0.24982,
            0.74947,
            0,
            0,
            0.38865
        ],
        "42": [
            0,
            0.62119,
            0,
            0,
            0.27764
        ],
        "43": [
            0.08319,
            0.58283,
            0,
            0,
            0.75623
        ],
        "44": [
            0,
            0.10803,
            0,
            0,
            0.27764
        ],
        "45": [
            0.08319,
            0.58283,
            0,
            0,
            0.75623
        ],
        "46": [
            0,
            0.10803,
            0,
            0,
            0.27764
        ],
        "47": [
            0.24982,
            0.74947,
            0,
            0,
            0.50181
        ],
        "48": [
            0,
            0.47534,
            0,
            0,
            0.50181
        ],
        "49": [
            0,
            0.47534,
            0,
            0,
            0.50181
        ],
        "50": [
            0,
            0.47534,
            0,
            0,
            0.50181
        ],
        "51": [
            0.18906,
            0.47534,
            0,
            0,
            0.50181
        ],
        "52": [
            0.18906,
            0.47534,
            0,
            0,
            0.50181
        ],
        "53": [
            0.18906,
            0.47534,
            0,
            0,
            0.50181
        ],
        "54": [
            0,
            0.69141,
            0,
            0,
            0.50181
        ],
        "55": [
            0.18906,
            0.47534,
            0,
            0,
            0.50181
        ],
        "56": [
            0,
            0.69141,
            0,
            0,
            0.50181
        ],
        "57": [
            0.18906,
            0.47534,
            0,
            0,
            0.50181
        ],
        "58": [
            0,
            0.47534,
            0,
            0,
            0.21606
        ],
        "59": [
            0.12604,
            0.47534,
            0,
            0,
            0.21606
        ],
        "61": [
            -0.13099,
            0.36866,
            0,
            0,
            0.75623
        ],
        "63": [
            0,
            0.69141,
            0,
            0,
            0.36245
        ],
        "65": [
            0,
            0.69141,
            0,
            0,
            0.7176
        ],
        "66": [
            0,
            0.69141,
            0,
            0,
            0.88397
        ],
        "67": [
            0,
            0.69141,
            0,
            0,
            0.61254
        ],
        "68": [
            0,
            0.69141,
            0,
            0,
            0.83158
        ],
        "69": [
            0,
            0.69141,
            0,
            0,
            0.66278
        ],
        "70": [
            0.12604,
            0.69141,
            0,
            0,
            0.61119
        ],
        "71": [
            0,
            0.69141,
            0,
            0,
            0.78539
        ],
        "72": [
            0.06302,
            0.69141,
            0,
            0,
            0.7203
        ],
        "73": [
            0,
            0.69141,
            0,
            0,
            0.55448
        ],
        "74": [
            0.12604,
            0.69141,
            0,
            0,
            0.55231
        ],
        "75": [
            0,
            0.69141,
            0,
            0,
            0.66845
        ],
        "76": [
            0,
            0.69141,
            0,
            0,
            0.66602
        ],
        "77": [
            0,
            0.69141,
            0,
            0,
            1.04953
        ],
        "78": [
            0,
            0.69141,
            0,
            0,
            0.83212
        ],
        "79": [
            0,
            0.69141,
            0,
            0,
            0.82699
        ],
        "80": [
            0.18906,
            0.69141,
            0,
            0,
            0.82753
        ],
        "81": [
            0.03781,
            0.69141,
            0,
            0,
            0.82699
        ],
        "82": [
            0,
            0.69141,
            0,
            0,
            0.82807
        ],
        "83": [
            0,
            0.69141,
            0,
            0,
            0.82861
        ],
        "84": [
            0,
            0.69141,
            0,
            0,
            0.66899
        ],
        "85": [
            0,
            0.69141,
            0,
            0,
            0.64576
        ],
        "86": [
            0,
            0.69141,
            0,
            0,
            0.83131
        ],
        "87": [
            0,
            0.69141,
            0,
            0,
            1.04602
        ],
        "88": [
            0,
            0.69141,
            0,
            0,
            0.71922
        ],
        "89": [
            0.18906,
            0.69141,
            0,
            0,
            0.83293
        ],
        "90": [
            0.12604,
            0.69141,
            0,
            0,
            0.60201
        ],
        "91": [
            0.24982,
            0.74947,
            0,
            0,
            0.27764
        ],
        "93": [
            0.24982,
            0.74947,
            0,
            0,
            0.27764
        ],
        "94": [
            0,
            0.69141,
            0,
            0,
            0.49965
        ],
        "97": [
            0,
            0.47534,
            0,
            0,
            0.50046
        ],
        "98": [
            0,
            0.69141,
            0,
            0,
            0.51315
        ],
        "99": [
            0,
            0.47534,
            0,
            0,
            0.38946
        ],
        "100": [
            0,
            0.62119,
            0,
            0,
            0.49857
        ],
        "101": [
            0,
            0.47534,
            0,
            0,
            0.40053
        ],
        "102": [
            0.18906,
            0.69141,
            0,
            0,
            0.32626
        ],
        "103": [
            0.18906,
            0.47534,
            0,
            0,
            0.5037
        ],
        "104": [
            0.18906,
            0.69141,
            0,
            0,
            0.52126
        ],
        "105": [
            0,
            0.69141,
            0,
            0,
            0.27899
        ],
        "106": [
            0,
            0.69141,
            0,
            0,
            0.28088
        ],
        "107": [
            0,
            0.69141,
            0,
            0,
            0.38946
        ],
        "108": [
            0,
            0.69141,
            0,
            0,
            0.27953
        ],
        "109": [
            0,
            0.47534,
            0,
            0,
            0.76676
        ],
        "110": [
            0,
            0.47534,
            0,
            0,
            0.52666
        ],
        "111": [
            0,
            0.47534,
            0,
            0,
            0.48885
        ],
        "112": [
            0.18906,
            0.52396,
            0,
            0,
            0.50046
        ],
        "113": [
            0.18906,
            0.47534,
            0,
            0,
            0.48912
        ],
        "114": [
            0,
            0.47534,
            0,
            0,
            0.38919
        ],
        "115": [
            0,
            0.47534,
            0,
            0,
            0.44266
        ],
        "116": [
            0,
            0.62119,
            0,
            0,
            0.33301
        ],
        "117": [
            0,
            0.47534,
            0,
            0,
            0.5172
        ],
        "118": [
            0,
            0.52396,
            0,
            0,
            0.5118
        ],
        "119": [
            0,
            0.52396,
            0,
            0,
            0.77351
        ],
        "120": [
            0.18906,
            0.47534,
            0,
            0,
            0.38865
        ],
        "121": [
            0.18906,
            0.47534,
            0,
            0,
            0.49884
        ],
        "122": [
            0.18906,
            0.47534,
            0,
            0,
            0.39054
        ],
        "160": [
            0,
            0,
            0,
            0,
            0.25
        ],
        "8216": [
            0,
            0.69141,
            0,
            0,
            0.21471
        ],
        "8217": [
            0,
            0.69141,
            0,
            0,
            0.21471
        ],
        "58112": [
            0,
            0.62119,
            0,
            0,
            0.49749
        ],
        "58113": [
            0,
            0.62119,
            0,
            0,
            0.4983
        ],
        "58114": [
            0.18906,
            0.69141,
            0,
            0,
            0.33328
        ],
        "58115": [
            0.18906,
            0.69141,
            0,
            0,
            0.32923
        ],
        "58116": [
            0.18906,
            0.47534,
            0,
            0,
            0.50343
        ],
        "58117": [
            0,
            0.69141,
            0,
            0,
            0.33301
        ],
        "58118": [
            0,
            0.62119,
            0,
            0,
            0.33409
        ],
        "58119": [
            0,
            0.47534,
            0,
            0,
            0.50073
        ]
    },
    "Main-Bold": {
        "32": [
            0,
            0,
            0,
            0,
            0.25
        ],
        "33": [
            0,
            0.69444,
            0,
            0,
            0.35
        ],
        "34": [
            0,
            0.69444,
            0,
            0,
            0.60278
        ],
        "35": [
            0.19444,
            0.69444,
            0,
            0,
            0.95833
        ],
        "36": [
            0.05556,
            0.75,
            0,
            0,
            0.575
        ],
        "37": [
            0.05556,
            0.75,
            0,
            0,
            0.95833
        ],
        "38": [
            0,
            0.69444,
            0,
            0,
            0.89444
        ],
        "39": [
            0,
            0.69444,
            0,
            0,
            0.31944
        ],
        "40": [
            0.25,
            0.75,
            0,
            0,
            0.44722
        ],
        "41": [
            0.25,
            0.75,
            0,
            0,
            0.44722
        ],
        "42": [
            0,
            0.75,
            0,
            0,
            0.575
        ],
        "43": [
            0.13333,
            0.63333,
            0,
            0,
            0.89444
        ],
        "44": [
            0.19444,
            0.15556,
            0,
            0,
            0.31944
        ],
        "45": [
            0,
            0.44444,
            0,
            0,
            0.38333
        ],
        "46": [
            0,
            0.15556,
            0,
            0,
            0.31944
        ],
        "47": [
            0.25,
            0.75,
            0,
            0,
            0.575
        ],
        "48": [
            0,
            0.64444,
            0,
            0,
            0.575
        ],
        "49": [
            0,
            0.64444,
            0,
            0,
            0.575
        ],
        "50": [
            0,
            0.64444,
            0,
            0,
            0.575
        ],
        "51": [
            0,
            0.64444,
            0,
            0,
            0.575
        ],
        "52": [
            0,
            0.64444,
            0,
            0,
            0.575
        ],
        "53": [
            0,
            0.64444,
            0,
            0,
            0.575
        ],
        "54": [
            0,
            0.64444,
            0,
            0,
            0.575
        ],
        "55": [
            0,
            0.64444,
            0,
            0,
            0.575
        ],
        "56": [
            0,
            0.64444,
            0,
            0,
            0.575
        ],
        "57": [
            0,
            0.64444,
            0,
            0,
            0.575
        ],
        "58": [
            0,
            0.44444,
            0,
            0,
            0.31944
        ],
        "59": [
            0.19444,
            0.44444,
            0,
            0,
            0.31944
        ],
        "60": [
            0.08556,
            0.58556,
            0,
            0,
            0.89444
        ],
        "61": [
            -0.10889,
            0.39111,
            0,
            0,
            0.89444
        ],
        "62": [
            0.08556,
            0.58556,
            0,
            0,
            0.89444
        ],
        "63": [
            0,
            0.69444,
            0,
            0,
            0.54305
        ],
        "64": [
            0,
            0.69444,
            0,
            0,
            0.89444
        ],
        "65": [
            0,
            0.68611,
            0,
            0,
            0.86944
        ],
        "66": [
            0,
            0.68611,
            0,
            0,
            0.81805
        ],
        "67": [
            0,
            0.68611,
            0,
            0,
            0.83055
        ],
        "68": [
            0,
            0.68611,
            0,
            0,
            0.88194
        ],
        "69": [
            0,
            0.68611,
            0,
            0,
            0.75555
        ],
        "70": [
            0,
            0.68611,
            0,
            0,
            0.72361
        ],
        "71": [
            0,
            0.68611,
            0,
            0,
            0.90416
        ],
        "72": [
            0,
            0.68611,
            0,
            0,
            0.9
        ],
        "73": [
            0,
            0.68611,
            0,
            0,
            0.43611
        ],
        "74": [
            0,
            0.68611,
            0,
            0,
            0.59444
        ],
        "75": [
            0,
            0.68611,
            0,
            0,
            0.90138
        ],
        "76": [
            0,
            0.68611,
            0,
            0,
            0.69166
        ],
        "77": [
            0,
            0.68611,
            0,
            0,
            1.09166
        ],
        "78": [
            0,
            0.68611,
            0,
            0,
            0.9
        ],
        "79": [
            0,
            0.68611,
            0,
            0,
            0.86388
        ],
        "80": [
            0,
            0.68611,
            0,
            0,
            0.78611
        ],
        "81": [
            0.19444,
            0.68611,
            0,
            0,
            0.86388
        ],
        "82": [
            0,
            0.68611,
            0,
            0,
            0.8625
        ],
        "83": [
            0,
            0.68611,
            0,
            0,
            0.63889
        ],
        "84": [
            0,
            0.68611,
            0,
            0,
            0.8
        ],
        "85": [
            0,
            0.68611,
            0,
            0,
            0.88472
        ],
        "86": [
            0,
            0.68611,
            0.01597,
            0,
            0.86944
        ],
        "87": [
            0,
            0.68611,
            0.01597,
            0,
            1.18888
        ],
        "88": [
            0,
            0.68611,
            0,
            0,
            0.86944
        ],
        "89": [
            0,
            0.68611,
            0.02875,
            0,
            0.86944
        ],
        "90": [
            0,
            0.68611,
            0,
            0,
            0.70277
        ],
        "91": [
            0.25,
            0.75,
            0,
            0,
            0.31944
        ],
        "92": [
            0.25,
            0.75,
            0,
            0,
            0.575
        ],
        "93": [
            0.25,
            0.75,
            0,
            0,
            0.31944
        ],
        "94": [
            0,
            0.69444,
            0,
            0,
            0.575
        ],
        "95": [
            0.31,
            0.13444,
            0.03194,
            0,
            0.575
        ],
        "97": [
            0,
            0.44444,
            0,
            0,
            0.55902
        ],
        "98": [
            0,
            0.69444,
            0,
            0,
            0.63889
        ],
        "99": [
            0,
            0.44444,
            0,
            0,
            0.51111
        ],
        "100": [
            0,
            0.69444,
            0,
            0,
            0.63889
        ],
        "101": [
            0,
            0.44444,
            0,
            0,
            0.52708
        ],
        "102": [
            0,
            0.69444,
            0.10903,
            0,
            0.35139
        ],
        "103": [
            0.19444,
            0.44444,
            0.01597,
            0,
            0.575
        ],
        "104": [
            0,
            0.69444,
            0,
            0,
            0.63889
        ],
        "105": [
            0,
            0.69444,
            0,
            0,
            0.31944
        ],
        "106": [
            0.19444,
            0.69444,
            0,
            0,
            0.35139
        ],
        "107": [
            0,
            0.69444,
            0,
            0,
            0.60694
        ],
        "108": [
            0,
            0.69444,
            0,
            0,
            0.31944
        ],
        "109": [
            0,
            0.44444,
            0,
            0,
            0.95833
        ],
        "110": [
            0,
            0.44444,
            0,
            0,
            0.63889
        ],
        "111": [
            0,
            0.44444,
            0,
            0,
            0.575
        ],
        "112": [
            0.19444,
            0.44444,
            0,
            0,
            0.63889
        ],
        "113": [
            0.19444,
            0.44444,
            0,
            0,
            0.60694
        ],
        "114": [
            0,
            0.44444,
            0,
            0,
            0.47361
        ],
        "115": [
            0,
            0.44444,
            0,
            0,
            0.45361
        ],
        "116": [
            0,
            0.63492,
            0,
            0,
            0.44722
        ],
        "117": [
            0,
            0.44444,
            0,
            0,
            0.63889
        ],
        "118": [
            0,
            0.44444,
            0.01597,
            0,
            0.60694
        ],
        "119": [
            0,
            0.44444,
            0.01597,
            0,
            0.83055
        ],
        "120": [
            0,
            0.44444,
            0,
            0,
            0.60694
        ],
        "121": [
            0.19444,
            0.44444,
            0.01597,
            0,
            0.60694
        ],
        "122": [
            0,
            0.44444,
            0,
            0,
            0.51111
        ],
        "123": [
            0.25,
            0.75,
            0,
            0,
            0.575
        ],
        "124": [
            0.25,
            0.75,
            0,
            0,
            0.31944
        ],
        "125": [
            0.25,
            0.75,
            0,
            0,
            0.575
        ],
        "126": [
            0.35,
            0.34444,
            0,
            0,
            0.575
        ],
        "160": [
            0,
            0,
            0,
            0,
            0.25
        ],
        "163": [
            0,
            0.69444,
            0,
            0,
            0.86853
        ],
        "168": [
            0,
            0.69444,
            0,
            0,
            0.575
        ],
        "172": [
            0,
            0.44444,
            0,
            0,
            0.76666
        ],
        "176": [
            0,
            0.69444,
            0,
            0,
            0.86944
        ],
        "177": [
            0.13333,
            0.63333,
            0,
            0,
            0.89444
        ],
        "184": [
            0.17014,
            0,
            0,
            0,
            0.51111
        ],
        "198": [
            0,
            0.68611,
            0,
            0,
            1.04166
        ],
        "215": [
            0.13333,
            0.63333,
            0,
            0,
            0.89444
        ],
        "216": [
            0.04861,
            0.73472,
            0,
            0,
            0.89444
        ],
        "223": [
            0,
            0.69444,
            0,
            0,
            0.59722
        ],
        "230": [
            0,
            0.44444,
            0,
            0,
            0.83055
        ],
        "247": [
            0.13333,
            0.63333,
            0,
            0,
            0.89444
        ],
        "248": [
            0.09722,
            0.54167,
            0,
            0,
            0.575
        ],
        "305": [
            0,
            0.44444,
            0,
            0,
            0.31944
        ],
        "338": [
            0,
            0.68611,
            0,
            0,
            1.16944
        ],
        "339": [
            0,
            0.44444,
            0,
            0,
            0.89444
        ],
        "567": [
            0.19444,
            0.44444,
            0,
            0,
            0.35139
        ],
        "710": [
            0,
            0.69444,
            0,
            0,
            0.575
        ],
        "711": [
            0,
            0.63194,
            0,
            0,
            0.575
        ],
        "713": [
            0,
            0.59611,
            0,
            0,
            0.575
        ],
        "714": [
            0,
            0.69444,
            0,
            0,
            0.575
        ],
        "715": [
            0,
            0.69444,
            0,
            0,
            0.575
        ],
        "728": [
            0,
            0.69444,
            0,
            0,
            0.575
        ],
        "729": [
            0,
            0.69444,
            0,
            0,
            0.31944
        ],
        "730": [
            0,
            0.69444,
            0,
            0,
            0.86944
        ],
        "732": [
            0,
            0.69444,
            0,
            0,
            0.575
        ],
        "733": [
            0,
            0.69444,
            0,
            0,
            0.575
        ],
        "915": [
            0,
            0.68611,
            0,
            0,
            0.69166
        ],
        "916": [
            0,
            0.68611,
            0,
            0,
            0.95833
        ],
        "920": [
            0,
            0.68611,
            0,
            0,
            0.89444
        ],
        "923": [
            0,
            0.68611,
            0,
            0,
            0.80555
        ],
        "926": [
            0,
            0.68611,
            0,
            0,
            0.76666
        ],
        "928": [
            0,
            0.68611,
            0,
            0,
            0.9
        ],
        "931": [
            0,
            0.68611,
            0,
            0,
            0.83055
        ],
        "933": [
            0,
            0.68611,
            0,
            0,
            0.89444
        ],
        "934": [
            0,
            0.68611,
            0,
            0,
            0.83055
        ],
        "936": [
            0,
            0.68611,
            0,
            0,
            0.89444
        ],
        "937": [
            0,
            0.68611,
            0,
            0,
            0.83055
        ],
        "8211": [
            0,
            0.44444,
            0.03194,
            0,
            0.575
        ],
        "8212": [
            0,
            0.44444,
            0.03194,
            0,
            1.14999
        ],
        "8216": [
            0,
            0.69444,
            0,
            0,
            0.31944
        ],
        "8217": [
            0,
            0.69444,
            0,
            0,
            0.31944
        ],
        "8220": [
            0,
            0.69444,
            0,
            0,
            0.60278
        ],
        "8221": [
            0,
            0.69444,
            0,
            0,
            0.60278
        ],
        "8224": [
            0.19444,
            0.69444,
            0,
            0,
            0.51111
        ],
        "8225": [
            0.19444,
            0.69444,
            0,
            0,
            0.51111
        ],
        "8242": [
            0,
            0.55556,
            0,
            0,
            0.34444
        ],
        "8407": [
            0,
            0.72444,
            0.15486,
            0,
            0.575
        ],
        "8463": [
            0,
            0.69444,
            0,
            0,
            0.66759
        ],
        "8465": [
            0,
            0.69444,
            0,
            0,
            0.83055
        ],
        "8467": [
            0,
            0.69444,
            0,
            0,
            0.47361
        ],
        "8472": [
            0.19444,
            0.44444,
            0,
            0,
            0.74027
        ],
        "8476": [
            0,
            0.69444,
            0,
            0,
            0.83055
        ],
        "8501": [
            0,
            0.69444,
            0,
            0,
            0.70277
        ],
        "8592": [
            -0.10889,
            0.39111,
            0,
            0,
            1.14999
        ],
        "8593": [
            0.19444,
            0.69444,
            0,
            0,
            0.575
        ],
        "8594": [
            -0.10889,
            0.39111,
            0,
            0,
            1.14999
        ],
        "8595": [
            0.19444,
            0.69444,
            0,
            0,
            0.575
        ],
        "8596": [
            -0.10889,
            0.39111,
            0,
            0,
            1.14999
        ],
        "8597": [
            0.25,
            0.75,
            0,
            0,
            0.575
        ],
        "8598": [
            0.19444,
            0.69444,
            0,
            0,
            1.14999
        ],
        "8599": [
            0.19444,
            0.69444,
            0,
            0,
            1.14999
        ],
        "8600": [
            0.19444,
            0.69444,
            0,
            0,
            1.14999
        ],
        "8601": [
            0.19444,
            0.69444,
            0,
            0,
            1.14999
        ],
        "8636": [
            -0.10889,
            0.39111,
            0,
            0,
            1.14999
        ],
        "8637": [
            -0.10889,
            0.39111,
            0,
            0,
            1.14999
        ],
        "8640": [
            -0.10889,
            0.39111,
            0,
            0,
            1.14999
        ],
        "8641": [
            -0.10889,
            0.39111,
            0,
            0,
            1.14999
        ],
        "8656": [
            -0.10889,
            0.39111,
            0,
            0,
            1.14999
        ],
        "8657": [
            0.19444,
            0.69444,
            0,
            0,
            0.70277
        ],
        "8658": [
            -0.10889,
            0.39111,
            0,
            0,
            1.14999
        ],
        "8659": [
            0.19444,
            0.69444,
            0,
            0,
            0.70277
        ],
        "8660": [
            -0.10889,
            0.39111,
            0,
            0,
            1.14999
        ],
        "8661": [
            0.25,
            0.75,
            0,
            0,
            0.70277
        ],
        "8704": [
            0,
            0.69444,
            0,
            0,
            0.63889
        ],
        "8706": [
            0,
            0.69444,
            0.06389,
            0,
            0.62847
        ],
        "8707": [
            0,
            0.69444,
            0,
            0,
            0.63889
        ],
        "8709": [
            0.05556,
            0.75,
            0,
            0,
            0.575
        ],
        "8711": [
            0,
            0.68611,
            0,
            0,
            0.95833
        ],
        "8712": [
            0.08556,
            0.58556,
            0,
            0,
            0.76666
        ],
        "8715": [
            0.08556,
            0.58556,
            0,
            0,
            0.76666
        ],
        "8722": [
            0.13333,
            0.63333,
            0,
            0,
            0.89444
        ],
        "8723": [
            0.13333,
            0.63333,
            0,
            0,
            0.89444
        ],
        "8725": [
            0.25,
            0.75,
            0,
            0,
            0.575
        ],
        "8726": [
            0.25,
            0.75,
            0,
            0,
            0.575
        ],
        "8727": [
            -0.02778,
            0.47222,
            0,
            0,
            0.575
        ],
        "8728": [
            -0.02639,
            0.47361,
            0,
            0,
            0.575
        ],
        "8729": [
            -0.02639,
            0.47361,
            0,
            0,
            0.575
        ],
        "8730": [
            0.18,
            0.82,
            0,
            0,
            0.95833
        ],
        "8733": [
            0,
            0.44444,
            0,
            0,
            0.89444
        ],
        "8734": [
            0,
            0.44444,
            0,
            0,
            1.14999
        ],
        "8736": [
            0,
            0.69224,
            0,
            0,
            0.72222
        ],
        "8739": [
            0.25,
            0.75,
            0,
            0,
            0.31944
        ],
        "8741": [
            0.25,
            0.75,
            0,
            0,
            0.575
        ],
        "8743": [
            0,
            0.55556,
            0,
            0,
            0.76666
        ],
        "8744": [
            0,
            0.55556,
            0,
            0,
            0.76666
        ],
        "8745": [
            0,
            0.55556,
            0,
            0,
            0.76666
        ],
        "8746": [
            0,
            0.55556,
            0,
            0,
            0.76666
        ],
        "8747": [
            0.19444,
            0.69444,
            0.12778,
            0,
            0.56875
        ],
        "8764": [
            -0.10889,
            0.39111,
            0,
            0,
            0.89444
        ],
        "8768": [
            0.19444,
            0.69444,
            0,
            0,
            0.31944
        ],
        "8771": [
            0.00222,
            0.50222,
            0,
            0,
            0.89444
        ],
        "8773": [
            0.027,
            0.638,
            0,
            0,
            0.894
        ],
        "8776": [
            0.02444,
            0.52444,
            0,
            0,
            0.89444
        ],
        "8781": [
            0.00222,
            0.50222,
            0,
            0,
            0.89444
        ],
        "8801": [
            0.00222,
            0.50222,
            0,
            0,
            0.89444
        ],
        "8804": [
            0.19667,
            0.69667,
            0,
            0,
            0.89444
        ],
        "8805": [
            0.19667,
            0.69667,
            0,
            0,
            0.89444
        ],
        "8810": [
            0.08556,
            0.58556,
            0,
            0,
            1.14999
        ],
        "8811": [
            0.08556,
            0.58556,
            0,
            0,
            1.14999
        ],
        "8826": [
            0.08556,
            0.58556,
            0,
            0,
            0.89444
        ],
        "8827": [
            0.08556,
            0.58556,
            0,
            0,
            0.89444
        ],
        "8834": [
            0.08556,
            0.58556,
            0,
            0,
            0.89444
        ],
        "8835": [
            0.08556,
            0.58556,
            0,
            0,
            0.89444
        ],
        "8838": [
            0.19667,
            0.69667,
            0,
            0,
            0.89444
        ],
        "8839": [
            0.19667,
            0.69667,
            0,
            0,
            0.89444
        ],
        "8846": [
            0,
            0.55556,
            0,
            0,
            0.76666
        ],
        "8849": [
            0.19667,
            0.69667,
            0,
            0,
            0.89444
        ],
        "8850": [
            0.19667,
            0.69667,
            0,
            0,
            0.89444
        ],
        "8851": [
            0,
            0.55556,
            0,
            0,
            0.76666
        ],
        "8852": [
            0,
            0.55556,
            0,
            0,
            0.76666
        ],
        "8853": [
            0.13333,
            0.63333,
            0,
            0,
            0.89444
        ],
        "8854": [
            0.13333,
            0.63333,
            0,
            0,
            0.89444
        ],
        "8855": [
            0.13333,
            0.63333,
            0,
            0,
            0.89444
        ],
        "8856": [
            0.13333,
            0.63333,
            0,
            0,
            0.89444
        ],
        "8857": [
            0.13333,
            0.63333,
            0,
            0,
            0.89444
        ],
        "8866": [
            0,
            0.69444,
            0,
            0,
            0.70277
        ],
        "8867": [
            0,
            0.69444,
            0,
            0,
            0.70277
        ],
        "8868": [
            0,
            0.69444,
            0,
            0,
            0.89444
        ],
        "8869": [
            0,
            0.69444,
            0,
            0,
            0.89444
        ],
        "8900": [
            -0.02639,
            0.47361,
            0,
            0,
            0.575
        ],
        "8901": [
            -0.02639,
            0.47361,
            0,
            0,
            0.31944
        ],
        "8902": [
            -0.02778,
            0.47222,
            0,
            0,
            0.575
        ],
        "8968": [
            0.25,
            0.75,
            0,
            0,
            0.51111
        ],
        "8969": [
            0.25,
            0.75,
            0,
            0,
            0.51111
        ],
        "8970": [
            0.25,
            0.75,
            0,
            0,
            0.51111
        ],
        "8971": [
            0.25,
            0.75,
            0,
            0,
            0.51111
        ],
        "8994": [
            -0.13889,
            0.36111,
            0,
            0,
            1.14999
        ],
        "8995": [
            -0.13889,
            0.36111,
            0,
            0,
            1.14999
        ],
        "9651": [
            0.19444,
            0.69444,
            0,
            0,
            1.02222
        ],
        "9657": [
            -0.02778,
            0.47222,
            0,
            0,
            0.575
        ],
        "9661": [
            0.19444,
            0.69444,
            0,
            0,
            1.02222
        ],
        "9667": [
            -0.02778,
            0.47222,
            0,
            0,
            0.575
        ],
        "9711": [
            0.19444,
            0.69444,
            0,
            0,
            1.14999
        ],
        "9824": [
            0.12963,
            0.69444,
            0,
            0,
            0.89444
        ],
        "9825": [
            0.12963,
            0.69444,
            0,
            0,
            0.89444
        ],
        "9826": [
            0.12963,
            0.69444,
            0,
            0,
            0.89444
        ],
        "9827": [
            0.12963,
            0.69444,
            0,
            0,
            0.89444
        ],
        "9837": [
            0,
            0.75,
            0,
            0,
            0.44722
        ],
        "9838": [
            0.19444,
            0.69444,
            0,
            0,
            0.44722
        ],
        "9839": [
            0.19444,
            0.69444,
            0,
            0,
            0.44722
        ],
        "10216": [
            0.25,
            0.75,
            0,
            0,
            0.44722
        ],
        "10217": [
            0.25,
            0.75,
            0,
            0,
            0.44722
        ],
        "10815": [
            0,
            0.68611,
            0,
            0,
            0.9
        ],
        "10927": [
            0.19667,
            0.69667,
            0,
            0,
            0.89444
        ],
        "10928": [
            0.19667,
            0.69667,
            0,
            0,
            0.89444
        ],
        "57376": [
            0.19444,
            0.69444,
            0,
            0,
            0
        ]
    },
    "Main-BoldItalic": {
        "32": [
            0,
            0,
            0,
            0,
            0.25
        ],
        "33": [
            0,
            0.69444,
            0.11417,
            0,
            0.38611
        ],
        "34": [
            0,
            0.69444,
            0.07939,
            0,
            0.62055
        ],
        "35": [
            0.19444,
            0.69444,
            0.06833,
            0,
            0.94444
        ],
        "37": [
            0.05556,
            0.75,
            0.12861,
            0,
            0.94444
        ],
        "38": [
            0,
            0.69444,
            0.08528,
            0,
            0.88555
        ],
        "39": [
            0,
            0.69444,
            0.12945,
            0,
            0.35555
        ],
        "40": [
            0.25,
            0.75,
            0.15806,
            0,
            0.47333
        ],
        "41": [
            0.25,
            0.75,
            0.03306,
            0,
            0.47333
        ],
        "42": [
            0,
            0.75,
            0.14333,
            0,
            0.59111
        ],
        "43": [
            0.10333,
            0.60333,
            0.03306,
            0,
            0.88555
        ],
        "44": [
            0.19444,
            0.14722,
            0,
            0,
            0.35555
        ],
        "45": [
            0,
            0.44444,
            0.02611,
            0,
            0.41444
        ],
        "46": [
            0,
            0.14722,
            0,
            0,
            0.35555
        ],
        "47": [
            0.25,
            0.75,
            0.15806,
            0,
            0.59111
        ],
        "48": [
            0,
            0.64444,
            0.13167,
            0,
            0.59111
        ],
        "49": [
            0,
            0.64444,
            0.13167,
            0,
            0.59111
        ],
        "50": [
            0,
            0.64444,
            0.13167,
            0,
            0.59111
        ],
        "51": [
            0,
            0.64444,
            0.13167,
            0,
            0.59111
        ],
        "52": [
            0.19444,
            0.64444,
            0.13167,
            0,
            0.59111
        ],
        "53": [
            0,
            0.64444,
            0.13167,
            0,
            0.59111
        ],
        "54": [
            0,
            0.64444,
            0.13167,
            0,
            0.59111
        ],
        "55": [
            0.19444,
            0.64444,
            0.13167,
            0,
            0.59111
        ],
        "56": [
            0,
            0.64444,
            0.13167,
            0,
            0.59111
        ],
        "57": [
            0,
            0.64444,
            0.13167,
            0,
            0.59111
        ],
        "58": [
            0,
            0.44444,
            0.06695,
            0,
            0.35555
        ],
        "59": [
            0.19444,
            0.44444,
            0.06695,
            0,
            0.35555
        ],
        "61": [
            -0.10889,
            0.39111,
            0.06833,
            0,
            0.88555
        ],
        "63": [
            0,
            0.69444,
            0.11472,
            0,
            0.59111
        ],
        "64": [
            0,
            0.69444,
            0.09208,
            0,
            0.88555
        ],
        "65": [
            0,
            0.68611,
            0,
            0,
            0.86555
        ],
        "66": [
            0,
            0.68611,
            0.0992,
            0,
            0.81666
        ],
        "67": [
            0,
            0.68611,
            0.14208,
            0,
            0.82666
        ],
        "68": [
            0,
            0.68611,
            0.09062,
            0,
            0.87555
        ],
        "69": [
            0,
            0.68611,
            0.11431,
            0,
            0.75666
        ],
        "70": [
            0,
            0.68611,
            0.12903,
            0,
            0.72722
        ],
        "71": [
            0,
            0.68611,
            0.07347,
            0,
            0.89527
        ],
        "72": [
            0,
            0.68611,
            0.17208,
            0,
            0.8961
        ],
        "73": [
            0,
            0.68611,
            0.15681,
            0,
            0.47166
        ],
        "74": [
            0,
            0.68611,
            0.145,
            0,
            0.61055
        ],
        "75": [
            0,
            0.68611,
            0.14208,
            0,
            0.89499
        ],
        "76": [
            0,
            0.68611,
            0,
            0,
            0.69777
        ],
        "77": [
            0,
            0.68611,
            0.17208,
            0,
            1.07277
        ],
        "78": [
            0,
            0.68611,
            0.17208,
            0,
            0.8961
        ],
        "79": [
            0,
            0.68611,
            0.09062,
            0,
            0.85499
        ],
        "80": [
            0,
            0.68611,
            0.0992,
            0,
            0.78721
        ],
        "81": [
            0.19444,
            0.68611,
            0.09062,
            0,
            0.85499
        ],
        "82": [
            0,
            0.68611,
            0.02559,
            0,
            0.85944
        ],
        "83": [
            0,
            0.68611,
            0.11264,
            0,
            0.64999
        ],
        "84": [
            0,
            0.68611,
            0.12903,
            0,
            0.7961
        ],
        "85": [
            0,
            0.68611,
            0.17208,
            0,
            0.88083
        ],
        "86": [
            0,
            0.68611,
            0.18625,
            0,
            0.86555
        ],
        "87": [
            0,
            0.68611,
            0.18625,
            0,
            1.15999
        ],
        "88": [
            0,
            0.68611,
            0.15681,
            0,
            0.86555
        ],
        "89": [
            0,
            0.68611,
            0.19803,
            0,
            0.86555
        ],
        "90": [
            0,
            0.68611,
            0.14208,
            0,
            0.70888
        ],
        "91": [
            0.25,
            0.75,
            0.1875,
            0,
            0.35611
        ],
        "93": [
            0.25,
            0.75,
            0.09972,
            0,
            0.35611
        ],
        "94": [
            0,
            0.69444,
            0.06709,
            0,
            0.59111
        ],
        "95": [
            0.31,
            0.13444,
            0.09811,
            0,
            0.59111
        ],
        "97": [
            0,
            0.44444,
            0.09426,
            0,
            0.59111
        ],
        "98": [
            0,
            0.69444,
            0.07861,
            0,
            0.53222
        ],
        "99": [
            0,
            0.44444,
            0.05222,
            0,
            0.53222
        ],
        "100": [
            0,
            0.69444,
            0.10861,
            0,
            0.59111
        ],
        "101": [
            0,
            0.44444,
            0.085,
            0,
            0.53222
        ],
        "102": [
            0.19444,
            0.69444,
            0.21778,
            0,
            0.4
        ],
        "103": [
            0.19444,
            0.44444,
            0.105,
            0,
            0.53222
        ],
        "104": [
            0,
            0.69444,
            0.09426,
            0,
            0.59111
        ],
        "105": [
            0,
            0.69326,
            0.11387,
            0,
            0.35555
        ],
        "106": [
            0.19444,
            0.69326,
            0.1672,
            0,
            0.35555
        ],
        "107": [
            0,
            0.69444,
            0.11111,
            0,
            0.53222
        ],
        "108": [
            0,
            0.69444,
            0.10861,
            0,
            0.29666
        ],
        "109": [
            0,
            0.44444,
            0.09426,
            0,
            0.94444
        ],
        "110": [
            0,
            0.44444,
            0.09426,
            0,
            0.64999
        ],
        "111": [
            0,
            0.44444,
            0.07861,
            0,
            0.59111
        ],
        "112": [
            0.19444,
            0.44444,
            0.07861,
            0,
            0.59111
        ],
        "113": [
            0.19444,
            0.44444,
            0.105,
            0,
            0.53222
        ],
        "114": [
            0,
            0.44444,
            0.11111,
            0,
            0.50167
        ],
        "115": [
            0,
            0.44444,
            0.08167,
            0,
            0.48694
        ],
        "116": [
            0,
            0.63492,
            0.09639,
            0,
            0.385
        ],
        "117": [
            0,
            0.44444,
            0.09426,
            0,
            0.62055
        ],
        "118": [
            0,
            0.44444,
            0.11111,
            0,
            0.53222
        ],
        "119": [
            0,
            0.44444,
            0.11111,
            0,
            0.76777
        ],
        "120": [
            0,
            0.44444,
            0.12583,
            0,
            0.56055
        ],
        "121": [
            0.19444,
            0.44444,
            0.105,
            0,
            0.56166
        ],
        "122": [
            0,
            0.44444,
            0.13889,
            0,
            0.49055
        ],
        "126": [
            0.35,
            0.34444,
            0.11472,
            0,
            0.59111
        ],
        "160": [
            0,
            0,
            0,
            0,
            0.25
        ],
        "168": [
            0,
            0.69444,
            0.11473,
            0,
            0.59111
        ],
        "176": [
            0,
            0.69444,
            0,
            0,
            0.94888
        ],
        "184": [
            0.17014,
            0,
            0,
            0,
            0.53222
        ],
        "198": [
            0,
            0.68611,
            0.11431,
            0,
            1.02277
        ],
        "216": [
            0.04861,
            0.73472,
            0.09062,
            0,
            0.88555
        ],
        "223": [
            0.19444,
            0.69444,
            0.09736,
            0,
            0.665
        ],
        "230": [
            0,
            0.44444,
            0.085,
            0,
            0.82666
        ],
        "248": [
            0.09722,
            0.54167,
            0.09458,
            0,
            0.59111
        ],
        "305": [
            0,
            0.44444,
            0.09426,
            0,
            0.35555
        ],
        "338": [
            0,
            0.68611,
            0.11431,
            0,
            1.14054
        ],
        "339": [
            0,
            0.44444,
            0.085,
            0,
            0.82666
        ],
        "567": [
            0.19444,
            0.44444,
            0.04611,
            0,
            0.385
        ],
        "710": [
            0,
            0.69444,
            0.06709,
            0,
            0.59111
        ],
        "711": [
            0,
            0.63194,
            0.08271,
            0,
            0.59111
        ],
        "713": [
            0,
            0.59444,
            0.10444,
            0,
            0.59111
        ],
        "714": [
            0,
            0.69444,
            0.08528,
            0,
            0.59111
        ],
        "715": [
            0,
            0.69444,
            0,
            0,
            0.59111
        ],
        "728": [
            0,
            0.69444,
            0.10333,
            0,
            0.59111
        ],
        "729": [
            0,
            0.69444,
            0.12945,
            0,
            0.35555
        ],
        "730": [
            0,
            0.69444,
            0,
            0,
            0.94888
        ],
        "732": [
            0,
            0.69444,
            0.11472,
            0,
            0.59111
        ],
        "733": [
            0,
            0.69444,
            0.11472,
            0,
            0.59111
        ],
        "915": [
            0,
            0.68611,
            0.12903,
            0,
            0.69777
        ],
        "916": [
            0,
            0.68611,
            0,
            0,
            0.94444
        ],
        "920": [
            0,
            0.68611,
            0.09062,
            0,
            0.88555
        ],
        "923": [
            0,
            0.68611,
            0,
            0,
            0.80666
        ],
        "926": [
            0,
            0.68611,
            0.15092,
            0,
            0.76777
        ],
        "928": [
            0,
            0.68611,
            0.17208,
            0,
            0.8961
        ],
        "931": [
            0,
            0.68611,
            0.11431,
            0,
            0.82666
        ],
        "933": [
            0,
            0.68611,
            0.10778,
            0,
            0.88555
        ],
        "934": [
            0,
            0.68611,
            0.05632,
            0,
            0.82666
        ],
        "936": [
            0,
            0.68611,
            0.10778,
            0,
            0.88555
        ],
        "937": [
            0,
            0.68611,
            0.0992,
            0,
            0.82666
        ],
        "8211": [
            0,
            0.44444,
            0.09811,
            0,
            0.59111
        ],
        "8212": [
            0,
            0.44444,
            0.09811,
            0,
            1.18221
        ],
        "8216": [
            0,
            0.69444,
            0.12945,
            0,
            0.35555
        ],
        "8217": [
            0,
            0.69444,
            0.12945,
            0,
            0.35555
        ],
        "8220": [
            0,
            0.69444,
            0.16772,
            0,
            0.62055
        ],
        "8221": [
            0,
            0.69444,
            0.07939,
            0,
            0.62055
        ]
    },
    "Main-Italic": {
        "32": [
            0,
            0,
            0,
            0,
            0.25
        ],
        "33": [
            0,
            0.69444,
            0.12417,
            0,
            0.30667
        ],
        "34": [
            0,
            0.69444,
            0.06961,
            0,
            0.51444
        ],
        "35": [
            0.19444,
            0.69444,
            0.06616,
            0,
            0.81777
        ],
        "37": [
            0.05556,
            0.75,
            0.13639,
            0,
            0.81777
        ],
        "38": [
            0,
            0.69444,
            0.09694,
            0,
            0.76666
        ],
        "39": [
            0,
            0.69444,
            0.12417,
            0,
            0.30667
        ],
        "40": [
            0.25,
            0.75,
            0.16194,
            0,
            0.40889
        ],
        "41": [
            0.25,
            0.75,
            0.03694,
            0,
            0.40889
        ],
        "42": [
            0,
            0.75,
            0.14917,
            0,
            0.51111
        ],
        "43": [
            0.05667,
            0.56167,
            0.03694,
            0,
            0.76666
        ],
        "44": [
            0.19444,
            0.10556,
            0,
            0,
            0.30667
        ],
        "45": [
            0,
            0.43056,
            0.02826,
            0,
            0.35778
        ],
        "46": [
            0,
            0.10556,
            0,
            0,
            0.30667
        ],
        "47": [
            0.25,
            0.75,
            0.16194,
            0,
            0.51111
        ],
        "48": [
            0,
            0.64444,
            0.13556,
            0,
            0.51111
        ],
        "49": [
            0,
            0.64444,
            0.13556,
            0,
            0.51111
        ],
        "50": [
            0,
            0.64444,
            0.13556,
            0,
            0.51111
        ],
        "51": [
            0,
            0.64444,
            0.13556,
            0,
            0.51111
        ],
        "52": [
            0.19444,
            0.64444,
            0.13556,
            0,
            0.51111
        ],
        "53": [
            0,
            0.64444,
            0.13556,
            0,
            0.51111
        ],
        "54": [
            0,
            0.64444,
            0.13556,
            0,
            0.51111
        ],
        "55": [
            0.19444,
            0.64444,
            0.13556,
            0,
            0.51111
        ],
        "56": [
            0,
            0.64444,
            0.13556,
            0,
            0.51111
        ],
        "57": [
            0,
            0.64444,
            0.13556,
            0,
            0.51111
        ],
        "58": [
            0,
            0.43056,
            0.0582,
            0,
            0.30667
        ],
        "59": [
            0.19444,
            0.43056,
            0.0582,
            0,
            0.30667
        ],
        "61": [
            -0.13313,
            0.36687,
            0.06616,
            0,
            0.76666
        ],
        "63": [
            0,
            0.69444,
            0.1225,
            0,
            0.51111
        ],
        "64": [
            0,
            0.69444,
            0.09597,
            0,
            0.76666
        ],
        "65": [
            0,
            0.68333,
            0,
            0,
            0.74333
        ],
        "66": [
            0,
            0.68333,
            0.10257,
            0,
            0.70389
        ],
        "67": [
            0,
            0.68333,
            0.14528,
            0,
            0.71555
        ],
        "68": [
            0,
            0.68333,
            0.09403,
            0,
            0.755
        ],
        "69": [
            0,
            0.68333,
            0.12028,
            0,
            0.67833
        ],
        "70": [
            0,
            0.68333,
            0.13305,
            0,
            0.65277
        ],
        "71": [
            0,
            0.68333,
            0.08722,
            0,
            0.77361
        ],
        "72": [
            0,
            0.68333,
            0.16389,
            0,
            0.74333
        ],
        "73": [
            0,
            0.68333,
            0.15806,
            0,
            0.38555
        ],
        "74": [
            0,
            0.68333,
            0.14028,
            0,
            0.525
        ],
        "75": [
            0,
            0.68333,
            0.14528,
            0,
            0.76888
        ],
        "76": [
            0,
            0.68333,
            0,
            0,
            0.62722
        ],
        "77": [
            0,
            0.68333,
            0.16389,
            0,
            0.89666
        ],
        "78": [
            0,
            0.68333,
            0.16389,
            0,
            0.74333
        ],
        "79": [
            0,
            0.68333,
            0.09403,
            0,
            0.76666
        ],
        "80": [
            0,
            0.68333,
            0.10257,
            0,
            0.67833
        ],
        "81": [
            0.19444,
            0.68333,
            0.09403,
            0,
            0.76666
        ],
        "82": [
            0,
            0.68333,
            0.03868,
            0,
            0.72944
        ],
        "83": [
            0,
            0.68333,
            0.11972,
            0,
            0.56222
        ],
        "84": [
            0,
            0.68333,
            0.13305,
            0,
            0.71555
        ],
        "85": [
            0,
            0.68333,
            0.16389,
            0,
            0.74333
        ],
        "86": [
            0,
            0.68333,
            0.18361,
            0,
            0.74333
        ],
        "87": [
            0,
            0.68333,
            0.18361,
            0,
            0.99888
        ],
        "88": [
            0,
            0.68333,
            0.15806,
            0,
            0.74333
        ],
        "89": [
            0,
            0.68333,
            0.19383,
            0,
            0.74333
        ],
        "90": [
            0,
            0.68333,
            0.14528,
            0,
            0.61333
        ],
        "91": [
            0.25,
            0.75,
            0.1875,
            0,
            0.30667
        ],
        "93": [
            0.25,
            0.75,
            0.10528,
            0,
            0.30667
        ],
        "94": [
            0,
            0.69444,
            0.06646,
            0,
            0.51111
        ],
        "95": [
            0.31,
            0.12056,
            0.09208,
            0,
            0.51111
        ],
        "97": [
            0,
            0.43056,
            0.07671,
            0,
            0.51111
        ],
        "98": [
            0,
            0.69444,
            0.06312,
            0,
            0.46
        ],
        "99": [
            0,
            0.43056,
            0.05653,
            0,
            0.46
        ],
        "100": [
            0,
            0.69444,
            0.10333,
            0,
            0.51111
        ],
        "101": [
            0,
            0.43056,
            0.07514,
            0,
            0.46
        ],
        "102": [
            0.19444,
            0.69444,
            0.21194,
            0,
            0.30667
        ],
        "103": [
            0.19444,
            0.43056,
            0.08847,
            0,
            0.46
        ],
        "104": [
            0,
            0.69444,
            0.07671,
            0,
            0.51111
        ],
        "105": [
            0,
            0.65536,
            0.1019,
            0,
            0.30667
        ],
        "106": [
            0.19444,
            0.65536,
            0.14467,
            0,
            0.30667
        ],
        "107": [
            0,
            0.69444,
            0.10764,
            0,
            0.46
        ],
        "108": [
            0,
            0.69444,
            0.10333,
            0,
            0.25555
        ],
        "109": [
            0,
            0.43056,
            0.07671,
            0,
            0.81777
        ],
        "110": [
            0,
            0.43056,
            0.07671,
            0,
            0.56222
        ],
        "111": [
            0,
            0.43056,
            0.06312,
            0,
            0.51111
        ],
        "112": [
            0.19444,
            0.43056,
            0.06312,
            0,
            0.51111
        ],
        "113": [
            0.19444,
            0.43056,
            0.08847,
            0,
            0.46
        ],
        "114": [
            0,
            0.43056,
            0.10764,
            0,
            0.42166
        ],
        "115": [
            0,
            0.43056,
            0.08208,
            0,
            0.40889
        ],
        "116": [
            0,
            0.61508,
            0.09486,
            0,
            0.33222
        ],
        "117": [
            0,
            0.43056,
            0.07671,
            0,
            0.53666
        ],
        "118": [
            0,
            0.43056,
            0.10764,
            0,
            0.46
        ],
        "119": [
            0,
            0.43056,
            0.10764,
            0,
            0.66444
        ],
        "120": [
            0,
            0.43056,
            0.12042,
            0,
            0.46389
        ],
        "121": [
            0.19444,
            0.43056,
            0.08847,
            0,
            0.48555
        ],
        "122": [
            0,
            0.43056,
            0.12292,
            0,
            0.40889
        ],
        "126": [
            0.35,
            0.31786,
            0.11585,
            0,
            0.51111
        ],
        "160": [
            0,
            0,
            0,
            0,
            0.25
        ],
        "168": [
            0,
            0.66786,
            0.10474,
            0,
            0.51111
        ],
        "176": [
            0,
            0.69444,
            0,
            0,
            0.83129
        ],
        "184": [
            0.17014,
            0,
            0,
            0,
            0.46
        ],
        "198": [
            0,
            0.68333,
            0.12028,
            0,
            0.88277
        ],
        "216": [
            0.04861,
            0.73194,
            0.09403,
            0,
            0.76666
        ],
        "223": [
            0.19444,
            0.69444,
            0.10514,
            0,
            0.53666
        ],
        "230": [
            0,
            0.43056,
            0.07514,
            0,
            0.71555
        ],
        "248": [
            0.09722,
            0.52778,
            0.09194,
            0,
            0.51111
        ],
        "338": [
            0,
            0.68333,
            0.12028,
            0,
            0.98499
        ],
        "339": [
            0,
            0.43056,
            0.07514,
            0,
            0.71555
        ],
        "710": [
            0,
            0.69444,
            0.06646,
            0,
            0.51111
        ],
        "711": [
            0,
            0.62847,
            0.08295,
            0,
            0.51111
        ],
        "713": [
            0,
            0.56167,
            0.10333,
            0,
            0.51111
        ],
        "714": [
            0,
            0.69444,
            0.09694,
            0,
            0.51111
        ],
        "715": [
            0,
            0.69444,
            0,
            0,
            0.51111
        ],
        "728": [
            0,
            0.69444,
            0.10806,
            0,
            0.51111
        ],
        "729": [
            0,
            0.66786,
            0.11752,
            0,
            0.30667
        ],
        "730": [
            0,
            0.69444,
            0,
            0,
            0.83129
        ],
        "732": [
            0,
            0.66786,
            0.11585,
            0,
            0.51111
        ],
        "733": [
            0,
            0.69444,
            0.1225,
            0,
            0.51111
        ],
        "915": [
            0,
            0.68333,
            0.13305,
            0,
            0.62722
        ],
        "916": [
            0,
            0.68333,
            0,
            0,
            0.81777
        ],
        "920": [
            0,
            0.68333,
            0.09403,
            0,
            0.76666
        ],
        "923": [
            0,
            0.68333,
            0,
            0,
            0.69222
        ],
        "926": [
            0,
            0.68333,
            0.15294,
            0,
            0.66444
        ],
        "928": [
            0,
            0.68333,
            0.16389,
            0,
            0.74333
        ],
        "931": [
            0,
            0.68333,
            0.12028,
            0,
            0.71555
        ],
        "933": [
            0,
            0.68333,
            0.11111,
            0,
            0.76666
        ],
        "934": [
            0,
            0.68333,
            0.05986,
            0,
            0.71555
        ],
        "936": [
            0,
            0.68333,
            0.11111,
            0,
            0.76666
        ],
        "937": [
            0,
            0.68333,
            0.10257,
            0,
            0.71555
        ],
        "8211": [
            0,
            0.43056,
            0.09208,
            0,
            0.51111
        ],
        "8212": [
            0,
            0.43056,
            0.09208,
            0,
            1.02222
        ],
        "8216": [
            0,
            0.69444,
            0.12417,
            0,
            0.30667
        ],
        "8217": [
            0,
            0.69444,
            0.12417,
            0,
            0.30667
        ],
        "8220": [
            0,
            0.69444,
            0.1685,
            0,
            0.51444
        ],
        "8221": [
            0,
            0.69444,
            0.06961,
            0,
            0.51444
        ],
        "8463": [
            0,
            0.68889,
            0,
            0,
            0.54028
        ]
    },
    "Main-Regular": {
        "32": [
            0,
            0,
            0,
            0,
            0.25
        ],
        "33": [
            0,
            0.69444,
            0,
            0,
            0.27778
        ],
        "34": [
            0,
            0.69444,
            0,
            0,
            0.5
        ],
        "35": [
            0.19444,
            0.69444,
            0,
            0,
            0.83334
        ],
        "36": [
            0.05556,
            0.75,
            0,
            0,
            0.5
        ],
        "37": [
            0.05556,
            0.75,
            0,
            0,
            0.83334
        ],
        "38": [
            0,
            0.69444,
            0,
            0,
            0.77778
        ],
        "39": [
            0,
            0.69444,
            0,
            0,
            0.27778
        ],
        "40": [
            0.25,
            0.75,
            0,
            0,
            0.38889
        ],
        "41": [
            0.25,
            0.75,
            0,
            0,
            0.38889
        ],
        "42": [
            0,
            0.75,
            0,
            0,
            0.5
        ],
        "43": [
            0.08333,
            0.58333,
            0,
            0,
            0.77778
        ],
        "44": [
            0.19444,
            0.10556,
            0,
            0,
            0.27778
        ],
        "45": [
            0,
            0.43056,
            0,
            0,
            0.33333
        ],
        "46": [
            0,
            0.10556,
            0,
            0,
            0.27778
        ],
        "47": [
            0.25,
            0.75,
            0,
            0,
            0.5
        ],
        "48": [
            0,
            0.64444,
            0,
            0,
            0.5
        ],
        "49": [
            0,
            0.64444,
            0,
            0,
            0.5
        ],
        "50": [
            0,
            0.64444,
            0,
            0,
            0.5
        ],
        "51": [
            0,
            0.64444,
            0,
            0,
            0.5
        ],
        "52": [
            0,
            0.64444,
            0,
            0,
            0.5
        ],
        "53": [
            0,
            0.64444,
            0,
            0,
            0.5
        ],
        "54": [
            0,
            0.64444,
            0,
            0,
            0.5
        ],
        "55": [
            0,
            0.64444,
            0,
            0,
            0.5
        ],
        "56": [
            0,
            0.64444,
            0,
            0,
            0.5
        ],
        "57": [
            0,
            0.64444,
            0,
            0,
            0.5
        ],
        "58": [
            0,
            0.43056,
            0,
            0,
            0.27778
        ],
        "59": [
            0.19444,
            0.43056,
            0,
            0,
            0.27778
        ],
        "60": [
            0.0391,
            0.5391,
            0,
            0,
            0.77778
        ],
        "61": [
            -0.13313,
            0.36687,
            0,
            0,
            0.77778
        ],
        "62": [
            0.0391,
            0.5391,
            0,
            0,
            0.77778
        ],
        "63": [
            0,
            0.69444,
            0,
            0,
            0.47222
        ],
        "64": [
            0,
            0.69444,
            0,
            0,
            0.77778
        ],
        "65": [
            0,
            0.68333,
            0,
            0,
            0.75
        ],
        "66": [
            0,
            0.68333,
            0,
            0,
            0.70834
        ],
        "67": [
            0,
            0.68333,
            0,
            0,
            0.72222
        ],
        "68": [
            0,
            0.68333,
            0,
            0,
            0.76389
        ],
        "69": [
            0,
            0.68333,
            0,
            0,
            0.68056
        ],
        "70": [
            0,
            0.68333,
            0,
            0,
            0.65278
        ],
        "71": [
            0,
            0.68333,
            0,
            0,
            0.78472
        ],
        "72": [
            0,
            0.68333,
            0,
            0,
            0.75
        ],
        "73": [
            0,
            0.68333,
            0,
            0,
            0.36111
        ],
        "74": [
            0,
            0.68333,
            0,
            0,
            0.51389
        ],
        "75": [
            0,
            0.68333,
            0,
            0,
            0.77778
        ],
        "76": [
            0,
            0.68333,
            0,
            0,
            0.625
        ],
        "77": [
            0,
            0.68333,
            0,
            0,
            0.91667
        ],
        "78": [
            0,
            0.68333,
            0,
            0,
            0.75
        ],
        "79": [
            0,
            0.68333,
            0,
            0,
            0.77778
        ],
        "80": [
            0,
            0.68333,
            0,
            0,
            0.68056
        ],
        "81": [
            0.19444,
            0.68333,
            0,
            0,
            0.77778
        ],
        "82": [
            0,
            0.68333,
            0,
            0,
            0.73611
        ],
        "83": [
            0,
            0.68333,
            0,
            0,
            0.55556
        ],
        "84": [
            0,
            0.68333,
            0,
            0,
            0.72222
        ],
        "85": [
            0,
            0.68333,
            0,
            0,
            0.75
        ],
        "86": [
            0,
            0.68333,
            0.01389,
            0,
            0.75
        ],
        "87": [
            0,
            0.68333,
            0.01389,
            0,
            1.02778
        ],
        "88": [
            0,
            0.68333,
            0,
            0,
            0.75
        ],
        "89": [
            0,
            0.68333,
            0.025,
            0,
            0.75
        ],
        "90": [
            0,
            0.68333,
            0,
            0,
            0.61111
        ],
        "91": [
            0.25,
            0.75,
            0,
            0,
            0.27778
        ],
        "92": [
            0.25,
            0.75,
            0,
            0,
            0.5
        ],
        "93": [
            0.25,
            0.75,
            0,
            0,
            0.27778
        ],
        "94": [
            0,
            0.69444,
            0,
            0,
            0.5
        ],
        "95": [
            0.31,
            0.12056,
            0.02778,
            0,
            0.5
        ],
        "97": [
            0,
            0.43056,
            0,
            0,
            0.5
        ],
        "98": [
            0,
            0.69444,
            0,
            0,
            0.55556
        ],
        "99": [
            0,
            0.43056,
            0,
            0,
            0.44445
        ],
        "100": [
            0,
            0.69444,
            0,
            0,
            0.55556
        ],
        "101": [
            0,
            0.43056,
            0,
            0,
            0.44445
        ],
        "102": [
            0,
            0.69444,
            0.07778,
            0,
            0.30556
        ],
        "103": [
            0.19444,
            0.43056,
            0.01389,
            0,
            0.5
        ],
        "104": [
            0,
            0.69444,
            0,
            0,
            0.55556
        ],
        "105": [
            0,
            0.66786,
            0,
            0,
            0.27778
        ],
        "106": [
            0.19444,
            0.66786,
            0,
            0,
            0.30556
        ],
        "107": [
            0,
            0.69444,
            0,
            0,
            0.52778
        ],
        "108": [
            0,
            0.69444,
            0,
            0,
            0.27778
        ],
        "109": [
            0,
            0.43056,
            0,
            0,
            0.83334
        ],
        "110": [
            0,
            0.43056,
            0,
            0,
            0.55556
        ],
        "111": [
            0,
            0.43056,
            0,
            0,
            0.5
        ],
        "112": [
            0.19444,
            0.43056,
            0,
            0,
            0.55556
        ],
        "113": [
            0.19444,
            0.43056,
            0,
            0,
            0.52778
        ],
        "114": [
            0,
            0.43056,
            0,
            0,
            0.39167
        ],
        "115": [
            0,
            0.43056,
            0,
            0,
            0.39445
        ],
        "116": [
            0,
            0.61508,
            0,
            0,
            0.38889
        ],
        "117": [
            0,
            0.43056,
            0,
            0,
            0.55556
        ],
        "118": [
            0,
            0.43056,
            0.01389,
            0,
            0.52778
        ],
        "119": [
            0,
            0.43056,
            0.01389,
            0,
            0.72222
        ],
        "120": [
            0,
            0.43056,
            0,
            0,
            0.52778
        ],
        "121": [
            0.19444,
            0.43056,
            0.01389,
            0,
            0.52778
        ],
        "122": [
            0,
            0.43056,
            0,
            0,
            0.44445
        ],
        "123": [
            0.25,
            0.75,
            0,
            0,
            0.5
        ],
        "124": [
            0.25,
            0.75,
            0,
            0,
            0.27778
        ],
        "125": [
            0.25,
            0.75,
            0,
            0,
            0.5
        ],
        "126": [
            0.35,
            0.31786,
            0,
            0,
            0.5
        ],
        "160": [
            0,
            0,
            0,
            0,
            0.25
        ],
        "163": [
            0,
            0.69444,
            0,
            0,
            0.76909
        ],
        "167": [
            0.19444,
            0.69444,
            0,
            0,
            0.44445
        ],
        "168": [
            0,
            0.66786,
            0,
            0,
            0.5
        ],
        "172": [
            0,
            0.43056,
            0,
            0,
            0.66667
        ],
        "176": [
            0,
            0.69444,
            0,
            0,
            0.75
        ],
        "177": [
            0.08333,
            0.58333,
            0,
            0,
            0.77778
        ],
        "182": [
            0.19444,
            0.69444,
            0,
            0,
            0.61111
        ],
        "184": [
            0.17014,
            0,
            0,
            0,
            0.44445
        ],
        "198": [
            0,
            0.68333,
            0,
            0,
            0.90278
        ],
        "215": [
            0.08333,
            0.58333,
            0,
            0,
            0.77778
        ],
        "216": [
            0.04861,
            0.73194,
            0,
            0,
            0.77778
        ],
        "223": [
            0,
            0.69444,
            0,
            0,
            0.5
        ],
        "230": [
            0,
            0.43056,
            0,
            0,
            0.72222
        ],
        "247": [
            0.08333,
            0.58333,
            0,
            0,
            0.77778
        ],
        "248": [
            0.09722,
            0.52778,
            0,
            0,
            0.5
        ],
        "305": [
            0,
            0.43056,
            0,
            0,
            0.27778
        ],
        "338": [
            0,
            0.68333,
            0,
            0,
            1.01389
        ],
        "339": [
            0,
            0.43056,
            0,
            0,
            0.77778
        ],
        "567": [
            0.19444,
            0.43056,
            0,
            0,
            0.30556
        ],
        "710": [
            0,
            0.69444,
            0,
            0,
            0.5
        ],
        "711": [
            0,
            0.62847,
            0,
            0,
            0.5
        ],
        "713": [
            0,
            0.56778,
            0,
            0,
            0.5
        ],
        "714": [
            0,
            0.69444,
            0,
            0,
            0.5
        ],
        "715": [
            0,
            0.69444,
            0,
            0,
            0.5
        ],
        "728": [
            0,
            0.69444,
            0,
            0,
            0.5
        ],
        "729": [
            0,
            0.66786,
            0,
            0,
            0.27778
        ],
        "730": [
            0,
            0.69444,
            0,
            0,
            0.75
        ],
        "732": [
            0,
            0.66786,
            0,
            0,
            0.5
        ],
        "733": [
            0,
            0.69444,
            0,
            0,
            0.5
        ],
        "915": [
            0,
            0.68333,
            0,
            0,
            0.625
        ],
        "916": [
            0,
            0.68333,
            0,
            0,
            0.83334
        ],
        "920": [
            0,
            0.68333,
            0,
            0,
            0.77778
        ],
        "923": [
            0,
            0.68333,
            0,
            0,
            0.69445
        ],
        "926": [
            0,
            0.68333,
            0,
            0,
            0.66667
        ],
        "928": [
            0,
            0.68333,
            0,
            0,
            0.75
        ],
        "931": [
            0,
            0.68333,
            0,
            0,
            0.72222
        ],
        "933": [
            0,
            0.68333,
            0,
            0,
            0.77778
        ],
        "934": [
            0,
            0.68333,
            0,
            0,
            0.72222
        ],
        "936": [
            0,
            0.68333,
            0,
            0,
            0.77778
        ],
        "937": [
            0,
            0.68333,
            0,
            0,
            0.72222
        ],
        "8211": [
            0,
            0.43056,
            0.02778,
            0,
            0.5
        ],
        "8212": [
            0,
            0.43056,
            0.02778,
            0,
            1.0
        ],
        "8216": [
            0,
            0.69444,
            0,
            0,
            0.27778
        ],
        "8217": [
            0,
            0.69444,
            0,
            0,
            0.27778
        ],
        "8220": [
            0,
            0.69444,
            0,
            0,
            0.5
        ],
        "8221": [
            0,
            0.69444,
            0,
            0,
            0.5
        ],
        "8224": [
            0.19444,
            0.69444,
            0,
            0,
            0.44445
        ],
        "8225": [
            0.19444,
            0.69444,
            0,
            0,
            0.44445
        ],
        "8230": [
            0,
            0.123,
            0,
            0,
            1.172
        ],
        "8242": [
            0,
            0.55556,
            0,
            0,
            0.275
        ],
        "8407": [
            0,
            0.71444,
            0.15382,
            0,
            0.5
        ],
        "8463": [
            0,
            0.68889,
            0,
            0,
            0.54028
        ],
        "8465": [
            0,
            0.69444,
            0,
            0,
            0.72222
        ],
        "8467": [
            0,
            0.69444,
            0,
            0.11111,
            0.41667
        ],
        "8472": [
            0.19444,
            0.43056,
            0,
            0.11111,
            0.63646
        ],
        "8476": [
            0,
            0.69444,
            0,
            0,
            0.72222
        ],
        "8501": [
            0,
            0.69444,
            0,
            0,
            0.61111
        ],
        "8592": [
            -0.13313,
            0.36687,
            0,
            0,
            1.0
        ],
        "8593": [
            0.19444,
            0.69444,
            0,
            0,
            0.5
        ],
        "8594": [
            -0.13313,
            0.36687,
            0,
            0,
            1.0
        ],
        "8595": [
            0.19444,
            0.69444,
            0,
            0,
            0.5
        ],
        "8596": [
            -0.13313,
            0.36687,
            0,
            0,
            1.0
        ],
        "8597": [
            0.25,
            0.75,
            0,
            0,
            0.5
        ],
        "8598": [
            0.19444,
            0.69444,
            0,
            0,
            1.0
        ],
        "8599": [
            0.19444,
            0.69444,
            0,
            0,
            1.0
        ],
        "8600": [
            0.19444,
            0.69444,
            0,
            0,
            1.0
        ],
        "8601": [
            0.19444,
            0.69444,
            0,
            0,
            1.0
        ],
        "8614": [
            0.011,
            0.511,
            0,
            0,
            1.0
        ],
        "8617": [
            0.011,
            0.511,
            0,
            0,
            1.126
        ],
        "8618": [
            0.011,
            0.511,
            0,
            0,
            1.126
        ],
        "8636": [
            -0.13313,
            0.36687,
            0,
            0,
            1.0
        ],
        "8637": [
            -0.13313,
            0.36687,
            0,
            0,
            1.0
        ],
        "8640": [
            -0.13313,
            0.36687,
            0,
            0,
            1.0
        ],
        "8641": [
            -0.13313,
            0.36687,
            0,
            0,
            1.0
        ],
        "8652": [
            0.011,
            0.671,
            0,
            0,
            1.0
        ],
        "8656": [
            -0.13313,
            0.36687,
            0,
            0,
            1.0
        ],
        "8657": [
            0.19444,
            0.69444,
            0,
            0,
            0.61111
        ],
        "8658": [
            -0.13313,
            0.36687,
            0,
            0,
            1.0
        ],
        "8659": [
            0.19444,
            0.69444,
            0,
            0,
            0.61111
        ],
        "8660": [
            -0.13313,
            0.36687,
            0,
            0,
            1.0
        ],
        "8661": [
            0.25,
            0.75,
            0,
            0,
            0.61111
        ],
        "8704": [
            0,
            0.69444,
            0,
            0,
            0.55556
        ],
        "8706": [
            0,
            0.69444,
            0.05556,
            0.08334,
            0.5309
        ],
        "8707": [
            0,
            0.69444,
            0,
            0,
            0.55556
        ],
        "8709": [
            0.05556,
            0.75,
            0,
            0,
            0.5
        ],
        "8711": [
            0,
            0.68333,
            0,
            0,
            0.83334
        ],
        "8712": [
            0.0391,
            0.5391,
            0,
            0,
            0.66667
        ],
        "8715": [
            0.0391,
            0.5391,
            0,
            0,
            0.66667
        ],
        "8722": [
            0.08333,
            0.58333,
            0,
            0,
            0.77778
        ],
        "8723": [
            0.08333,
            0.58333,
            0,
            0,
            0.77778
        ],
        "8725": [
            0.25,
            0.75,
            0,
            0,
            0.5
        ],
        "8726": [
            0.25,
            0.75,
            0,
            0,
            0.5
        ],
        "8727": [
            -0.03472,
            0.46528,
            0,
            0,
            0.5
        ],
        "8728": [
            -0.05555,
            0.44445,
            0,
            0,
            0.5
        ],
        "8729": [
            -0.05555,
            0.44445,
            0,
            0,
            0.5
        ],
        "8730": [
            0.2,
            0.8,
            0,
            0,
            0.83334
        ],
        "8733": [
            0,
            0.43056,
            0,
            0,
            0.77778
        ],
        "8734": [
            0,
            0.43056,
            0,
            0,
            1.0
        ],
        "8736": [
            0,
            0.69224,
            0,
            0,
            0.72222
        ],
        "8739": [
            0.25,
            0.75,
            0,
            0,
            0.27778
        ],
        "8741": [
            0.25,
            0.75,
            0,
            0,
            0.5
        ],
        "8743": [
            0,
            0.55556,
            0,
            0,
            0.66667
        ],
        "8744": [
            0,
            0.55556,
            0,
            0,
            0.66667
        ],
        "8745": [
            0,
            0.55556,
            0,
            0,
            0.66667
        ],
        "8746": [
            0,
            0.55556,
            0,
            0,
            0.66667
        ],
        "8747": [
            0.19444,
            0.69444,
            0.11111,
            0,
            0.41667
        ],
        "8764": [
            -0.13313,
            0.36687,
            0,
            0,
            0.77778
        ],
        "8768": [
            0.19444,
            0.69444,
            0,
            0,
            0.27778
        ],
        "8771": [
            -0.03625,
            0.46375,
            0,
            0,
            0.77778
        ],
        "8773": [
            -0.022,
            0.589,
            0,
            0,
            0.778
        ],
        "8776": [
            -0.01688,
            0.48312,
            0,
            0,
            0.77778
        ],
        "8781": [
            -0.03625,
            0.46375,
            0,
            0,
            0.77778
        ],
        "8784": [
            -0.133,
            0.673,
            0,
            0,
            0.778
        ],
        "8801": [
            -0.03625,
            0.46375,
            0,
            0,
            0.77778
        ],
        "8804": [
            0.13597,
            0.63597,
            0,
            0,
            0.77778
        ],
        "8805": [
            0.13597,
            0.63597,
            0,
            0,
            0.77778
        ],
        "8810": [
            0.0391,
            0.5391,
            0,
            0,
            1.0
        ],
        "8811": [
            0.0391,
            0.5391,
            0,
            0,
            1.0
        ],
        "8826": [
            0.0391,
            0.5391,
            0,
            0,
            0.77778
        ],
        "8827": [
            0.0391,
            0.5391,
            0,
            0,
            0.77778
        ],
        "8834": [
            0.0391,
            0.5391,
            0,
            0,
            0.77778
        ],
        "8835": [
            0.0391,
            0.5391,
            0,
            0,
            0.77778
        ],
        "8838": [
            0.13597,
            0.63597,
            0,
            0,
            0.77778
        ],
        "8839": [
            0.13597,
            0.63597,
            0,
            0,
            0.77778
        ],
        "8846": [
            0,
            0.55556,
            0,
            0,
            0.66667
        ],
        "8849": [
            0.13597,
            0.63597,
            0,
            0,
            0.77778
        ],
        "8850": [
            0.13597,
            0.63597,
            0,
            0,
            0.77778
        ],
        "8851": [
            0,
            0.55556,
            0,
            0,
            0.66667
        ],
        "8852": [
            0,
            0.55556,
            0,
            0,
            0.66667
        ],
        "8853": [
            0.08333,
            0.58333,
            0,
            0,
            0.77778
        ],
        "8854": [
            0.08333,
            0.58333,
            0,
            0,
            0.77778
        ],
        "8855": [
            0.08333,
            0.58333,
            0,
            0,
            0.77778
        ],
        "8856": [
            0.08333,
            0.58333,
            0,
            0,
            0.77778
        ],
        "8857": [
            0.08333,
            0.58333,
            0,
            0,
            0.77778
        ],
        "8866": [
            0,
            0.69444,
            0,
            0,
            0.61111
        ],
        "8867": [
            0,
            0.69444,
            0,
            0,
            0.61111
        ],
        "8868": [
            0,
            0.69444,
            0,
            0,
            0.77778
        ],
        "8869": [
            0,
            0.69444,
            0,
            0,
            0.77778
        ],
        "8872": [
            0.249,
            0.75,
            0,
            0,
            0.867
        ],
        "8900": [
            -0.05555,
            0.44445,
            0,
            0,
            0.5
        ],
        "8901": [
            -0.05555,
            0.44445,
            0,
            0,
            0.27778
        ],
        "8902": [
            -0.03472,
            0.46528,
            0,
            0,
            0.5
        ],
        "8904": [
            0.005,
            0.505,
            0,
            0,
            0.9
        ],
        "8942": [
            0.03,
            0.903,
            0,
            0,
            0.278
        ],
        "8943": [
            -0.19,
            0.313,
            0,
            0,
            1.172
        ],
        "8945": [
            -0.1,
            0.823,
            0,
            0,
            1.282
        ],
        "8968": [
            0.25,
            0.75,
            0,
            0,
            0.44445
        ],
        "8969": [
            0.25,
            0.75,
            0,
            0,
            0.44445
        ],
        "8970": [
            0.25,
            0.75,
            0,
            0,
            0.44445
        ],
        "8971": [
            0.25,
            0.75,
            0,
            0,
            0.44445
        ],
        "8994": [
            -0.14236,
            0.35764,
            0,
            0,
            1.0
        ],
        "8995": [
            -0.14236,
            0.35764,
            0,
            0,
            1.0
        ],
        "9136": [
            0.244,
            0.744,
            0,
            0,
            0.412
        ],
        "9137": [
            0.244,
            0.745,
            0,
            0,
            0.412
        ],
        "9651": [
            0.19444,
            0.69444,
            0,
            0,
            0.88889
        ],
        "9657": [
            -0.03472,
            0.46528,
            0,
            0,
            0.5
        ],
        "9661": [
            0.19444,
            0.69444,
            0,
            0,
            0.88889
        ],
        "9667": [
            -0.03472,
            0.46528,
            0,
            0,
            0.5
        ],
        "9711": [
            0.19444,
            0.69444,
            0,
            0,
            1.0
        ],
        "9824": [
            0.12963,
            0.69444,
            0,
            0,
            0.77778
        ],
        "9825": [
            0.12963,
            0.69444,
            0,
            0,
            0.77778
        ],
        "9826": [
            0.12963,
            0.69444,
            0,
            0,
            0.77778
        ],
        "9827": [
            0.12963,
            0.69444,
            0,
            0,
            0.77778
        ],
        "9837": [
            0,
            0.75,
            0,
            0,
            0.38889
        ],
        "9838": [
            0.19444,
            0.69444,
            0,
            0,
            0.38889
        ],
        "9839": [
            0.19444,
            0.69444,
            0,
            0,
            0.38889
        ],
        "10216": [
            0.25,
            0.75,
            0,
            0,
            0.38889
        ],
        "10217": [
            0.25,
            0.75,
            0,
            0,
            0.38889
        ],
        "10222": [
            0.244,
            0.744,
            0,
            0,
            0.412
        ],
        "10223": [
            0.244,
            0.745,
            0,
            0,
            0.412
        ],
        "10229": [
            0.011,
            0.511,
            0,
            0,
            1.609
        ],
        "10230": [
            0.011,
            0.511,
            0,
            0,
            1.638
        ],
        "10231": [
            0.011,
            0.511,
            0,
            0,
            1.859
        ],
        "10232": [
            0.024,
            0.525,
            0,
            0,
            1.609
        ],
        "10233": [
            0.024,
            0.525,
            0,
            0,
            1.638
        ],
        "10234": [
            0.024,
            0.525,
            0,
            0,
            1.858
        ],
        "10236": [
            0.011,
            0.511,
            0,
            0,
            1.638
        ],
        "10815": [
            0,
            0.68333,
            0,
            0,
            0.75
        ],
        "10927": [
            0.13597,
            0.63597,
            0,
            0,
            0.77778
        ],
        "10928": [
            0.13597,
            0.63597,
            0,
            0,
            0.77778
        ],
        "57376": [
            0.19444,
            0.69444,
            0,
            0,
            0
        ]
    },
    "Math-BoldItalic": {
        "32": [
            0,
            0,
            0,
            0,
            0.25
        ],
        "48": [
            0,
            0.44444,
            0,
            0,
            0.575
        ],
        "49": [
            0,
            0.44444,
            0,
            0,
            0.575
        ],
        "50": [
            0,
            0.44444,
            0,
            0,
            0.575
        ],
        "51": [
            0.19444,
            0.44444,
            0,
            0,
            0.575
        ],
        "52": [
            0.19444,
            0.44444,
            0,
            0,
            0.575
        ],
        "53": [
            0.19444,
            0.44444,
            0,
            0,
            0.575
        ],
        "54": [
            0,
            0.64444,
            0,
            0,
            0.575
        ],
        "55": [
            0.19444,
            0.44444,
            0,
            0,
            0.575
        ],
        "56": [
            0,
            0.64444,
            0,
            0,
            0.575
        ],
        "57": [
            0.19444,
            0.44444,
            0,
            0,
            0.575
        ],
        "65": [
            0,
            0.68611,
            0,
            0,
            0.86944
        ],
        "66": [
            0,
            0.68611,
            0.04835,
            0,
            0.8664
        ],
        "67": [
            0,
            0.68611,
            0.06979,
            0,
            0.81694
        ],
        "68": [
            0,
            0.68611,
            0.03194,
            0,
            0.93812
        ],
        "69": [
            0,
            0.68611,
            0.05451,
            0,
            0.81007
        ],
        "70": [
            0,
            0.68611,
            0.15972,
            0,
            0.68889
        ],
        "71": [
            0,
            0.68611,
            0,
            0,
            0.88673
        ],
        "72": [
            0,
            0.68611,
            0.08229,
            0,
            0.98229
        ],
        "73": [
            0,
            0.68611,
            0.07778,
            0,
            0.51111
        ],
        "74": [
            0,
            0.68611,
            0.10069,
            0,
            0.63125
        ],
        "75": [
            0,
            0.68611,
            0.06979,
            0,
            0.97118
        ],
        "76": [
            0,
            0.68611,
            0,
            0,
            0.75555
        ],
        "77": [
            0,
            0.68611,
            0.11424,
            0,
            1.14201
        ],
        "78": [
            0,
            0.68611,
            0.11424,
            0,
            0.95034
        ],
        "79": [
            0,
            0.68611,
            0.03194,
            0,
            0.83666
        ],
        "80": [
            0,
            0.68611,
            0.15972,
            0,
            0.72309
        ],
        "81": [
            0.19444,
            0.68611,
            0,
            0,
            0.86861
        ],
        "82": [
            0,
            0.68611,
            0.00421,
            0,
            0.87235
        ],
        "83": [
            0,
            0.68611,
            0.05382,
            0,
            0.69271
        ],
        "84": [
            0,
            0.68611,
            0.15972,
            0,
            0.63663
        ],
        "85": [
            0,
            0.68611,
            0.11424,
            0,
            0.80027
        ],
        "86": [
            0,
            0.68611,
            0.25555,
            0,
            0.67778
        ],
        "87": [
            0,
            0.68611,
            0.15972,
            0,
            1.09305
        ],
        "88": [
            0,
            0.68611,
            0.07778,
            0,
            0.94722
        ],
        "89": [
            0,
            0.68611,
            0.25555,
            0,
            0.67458
        ],
        "90": [
            0,
            0.68611,
            0.06979,
            0,
            0.77257
        ],
        "97": [
            0,
            0.44444,
            0,
            0,
            0.63287
        ],
        "98": [
            0,
            0.69444,
            0,
            0,
            0.52083
        ],
        "99": [
            0,
            0.44444,
            0,
            0,
            0.51342
        ],
        "100": [
            0,
            0.69444,
            0,
            0,
            0.60972
        ],
        "101": [
            0,
            0.44444,
            0,
            0,
            0.55361
        ],
        "102": [
            0.19444,
            0.69444,
            0.11042,
            0,
            0.56806
        ],
        "103": [
            0.19444,
            0.44444,
            0.03704,
            0,
            0.5449
        ],
        "104": [
            0,
            0.69444,
            0,
            0,
            0.66759
        ],
        "105": [
            0,
            0.69326,
            0,
            0,
            0.4048
        ],
        "106": [
            0.19444,
            0.69326,
            0.0622,
            0,
            0.47083
        ],
        "107": [
            0,
            0.69444,
            0.01852,
            0,
            0.6037
        ],
        "108": [
            0,
            0.69444,
            0.0088,
            0,
            0.34815
        ],
        "109": [
            0,
            0.44444,
            0,
            0,
            1.0324
        ],
        "110": [
            0,
            0.44444,
            0,
            0,
            0.71296
        ],
        "111": [
            0,
            0.44444,
            0,
            0,
            0.58472
        ],
        "112": [
            0.19444,
            0.44444,
            0,
            0,
            0.60092
        ],
        "113": [
            0.19444,
            0.44444,
            0.03704,
            0,
            0.54213
        ],
        "114": [
            0,
            0.44444,
            0.03194,
            0,
            0.5287
        ],
        "115": [
            0,
            0.44444,
            0,
            0,
            0.53125
        ],
        "116": [
            0,
            0.63492,
            0,
            0,
            0.41528
        ],
        "117": [
            0,
            0.44444,
            0,
            0,
            0.68102
        ],
        "118": [
            0,
            0.44444,
            0.03704,
            0,
            0.56666
        ],
        "119": [
            0,
            0.44444,
            0.02778,
            0,
            0.83148
        ],
        "120": [
            0,
            0.44444,
            0,
            0,
            0.65903
        ],
        "121": [
            0.19444,
            0.44444,
            0.03704,
            0,
            0.59028
        ],
        "122": [
            0,
            0.44444,
            0.04213,
            0,
            0.55509
        ],
        "160": [
            0,
            0,
            0,
            0,
            0.25
        ],
        "915": [
            0,
            0.68611,
            0.15972,
            0,
            0.65694
        ],
        "916": [
            0,
            0.68611,
            0,
            0,
            0.95833
        ],
        "920": [
            0,
            0.68611,
            0.03194,
            0,
            0.86722
        ],
        "923": [
            0,
            0.68611,
            0,
            0,
            0.80555
        ],
        "926": [
            0,
            0.68611,
            0.07458,
            0,
            0.84125
        ],
        "928": [
            0,
            0.68611,
            0.08229,
            0,
            0.98229
        ],
        "931": [
            0,
            0.68611,
            0.05451,
            0,
            0.88507
        ],
        "933": [
            0,
            0.68611,
            0.15972,
            0,
            0.67083
        ],
        "934": [
            0,
            0.68611,
            0,
            0,
            0.76666
        ],
        "936": [
            0,
            0.68611,
            0.11653,
            0,
            0.71402
        ],
        "937": [
            0,
            0.68611,
            0.04835,
            0,
            0.8789
        ],
        "945": [
            0,
            0.44444,
            0,
            0,
            0.76064
        ],
        "946": [
            0.19444,
            0.69444,
            0.03403,
            0,
            0.65972
        ],
        "947": [
            0.19444,
            0.44444,
            0.06389,
            0,
            0.59003
        ],
        "948": [
            0,
            0.69444,
            0.03819,
            0,
            0.52222
        ],
        "949": [
            0,
            0.44444,
            0,
            0,
            0.52882
        ],
        "950": [
            0.19444,
            0.69444,
            0.06215,
            0,
            0.50833
        ],
        "951": [
            0.19444,
            0.44444,
            0.03704,
            0,
            0.6
        ],
        "952": [
            0,
            0.69444,
            0.03194,
            0,
            0.5618
        ],
        "953": [
            0,
            0.44444,
            0,
            0,
            0.41204
        ],
        "954": [
            0,
            0.44444,
            0,
            0,
            0.66759
        ],
        "955": [
            0,
            0.69444,
            0,
            0,
            0.67083
        ],
        "956": [
            0.19444,
            0.44444,
            0,
            0,
            0.70787
        ],
        "957": [
            0,
            0.44444,
            0.06898,
            0,
            0.57685
        ],
        "958": [
            0.19444,
            0.69444,
            0.03021,
            0,
            0.50833
        ],
        "959": [
            0,
            0.44444,
            0,
            0,
            0.58472
        ],
        "960": [
            0,
            0.44444,
            0.03704,
            0,
            0.68241
        ],
        "961": [
            0.19444,
            0.44444,
            0,
            0,
            0.6118
        ],
        "962": [
            0.09722,
            0.44444,
            0.07917,
            0,
            0.42361
        ],
        "963": [
            0,
            0.44444,
            0.03704,
            0,
            0.68588
        ],
        "964": [
            0,
            0.44444,
            0.13472,
            0,
            0.52083
        ],
        "965": [
            0,
            0.44444,
            0.03704,
            0,
            0.63055
        ],
        "966": [
            0.19444,
            0.44444,
            0,
            0,
            0.74722
        ],
        "967": [
            0.19444,
            0.44444,
            0,
            0,
            0.71805
        ],
        "968": [
            0.19444,
            0.69444,
            0.03704,
            0,
            0.75833
        ],
        "969": [
            0,
            0.44444,
            0.03704,
            0,
            0.71782
        ],
        "977": [
            0,
            0.69444,
            0,
            0,
            0.69155
        ],
        "981": [
            0.19444,
            0.69444,
            0,
            0,
            0.7125
        ],
        "982": [
            0,
            0.44444,
            0.03194,
            0,
            0.975
        ],
        "1009": [
            0.19444,
            0.44444,
            0,
            0,
            0.6118
        ],
        "1013": [
            0,
            0.44444,
            0,
            0,
            0.48333
        ],
        "57649": [
            0,
            0.44444,
            0,
            0,
            0.39352
        ],
        "57911": [
            0.19444,
            0.44444,
            0,
            0,
            0.43889
        ]
    },
    "Math-Italic": {
        "32": [
            0,
            0,
            0,
            0,
            0.25
        ],
        "48": [
            0,
            0.43056,
            0,
            0,
            0.5
        ],
        "49": [
            0,
            0.43056,
            0,
            0,
            0.5
        ],
        "50": [
            0,
            0.43056,
            0,
            0,
            0.5
        ],
        "51": [
            0.19444,
            0.43056,
            0,
            0,
            0.5
        ],
        "52": [
            0.19444,
            0.43056,
            0,
            0,
            0.5
        ],
        "53": [
            0.19444,
            0.43056,
            0,
            0,
            0.5
        ],
        "54": [
            0,
            0.64444,
            0,
            0,
            0.5
        ],
        "55": [
            0.19444,
            0.43056,
            0,
            0,
            0.5
        ],
        "56": [
            0,
            0.64444,
            0,
            0,
            0.5
        ],
        "57": [
            0.19444,
            0.43056,
            0,
            0,
            0.5
        ],
        "65": [
            0,
            0.68333,
            0,
            0.13889,
            0.75
        ],
        "66": [
            0,
            0.68333,
            0.05017,
            0.08334,
            0.75851
        ],
        "67": [
            0,
            0.68333,
            0.07153,
            0.08334,
            0.71472
        ],
        "68": [
            0,
            0.68333,
            0.02778,
            0.05556,
            0.82792
        ],
        "69": [
            0,
            0.68333,
            0.05764,
            0.08334,
            0.7382
        ],
        "70": [
            0,
            0.68333,
            0.13889,
            0.08334,
            0.64306
        ],
        "71": [
            0,
            0.68333,
            0,
            0.08334,
            0.78625
        ],
        "72": [
            0,
            0.68333,
            0.08125,
            0.05556,
            0.83125
        ],
        "73": [
            0,
            0.68333,
            0.07847,
            0.11111,
            0.43958
        ],
        "74": [
            0,
            0.68333,
            0.09618,
            0.16667,
            0.55451
        ],
        "75": [
            0,
            0.68333,
            0.07153,
            0.05556,
            0.84931
        ],
        "76": [
            0,
            0.68333,
            0,
            0.02778,
            0.68056
        ],
        "77": [
            0,
            0.68333,
            0.10903,
            0.08334,
            0.97014
        ],
        "78": [
            0,
            0.68333,
            0.10903,
            0.08334,
            0.80347
        ],
        "79": [
            0,
            0.68333,
            0.02778,
            0.08334,
            0.76278
        ],
        "80": [
            0,
            0.68333,
            0.13889,
            0.08334,
            0.64201
        ],
        "81": [
            0.19444,
            0.68333,
            0,
            0.08334,
            0.79056
        ],
        "82": [
            0,
            0.68333,
            0.00773,
            0.08334,
            0.75929
        ],
        "83": [
            0,
            0.68333,
            0.05764,
            0.08334,
            0.6132
        ],
        "84": [
            0,
            0.68333,
            0.13889,
            0.08334,
            0.58438
        ],
        "85": [
            0,
            0.68333,
            0.10903,
            0.02778,
            0.68278
        ],
        "86": [
            0,
            0.68333,
            0.22222,
            0,
            0.58333
        ],
        "87": [
            0,
            0.68333,
            0.13889,
            0,
            0.94445
        ],
        "88": [
            0,
            0.68333,
            0.07847,
            0.08334,
            0.82847
        ],
        "89": [
            0,
            0.68333,
            0.22222,
            0,
            0.58056
        ],
        "90": [
            0,
            0.68333,
            0.07153,
            0.08334,
            0.68264
        ],
        "97": [
            0,
            0.43056,
            0,
            0,
            0.52859
        ],
        "98": [
            0,
            0.69444,
            0,
            0,
            0.42917
        ],
        "99": [
            0,
            0.43056,
            0,
            0.05556,
            0.43276
        ],
        "100": [
            0,
            0.69444,
            0,
            0.16667,
            0.52049
        ],
        "101": [
            0,
            0.43056,
            0,
            0.05556,
            0.46563
        ],
        "102": [
            0.19444,
            0.69444,
            0.10764,
            0.16667,
            0.48959
        ],
        "103": [
            0.19444,
            0.43056,
            0.03588,
            0.02778,
            0.47697
        ],
        "104": [
            0,
            0.69444,
            0,
            0,
            0.57616
        ],
        "105": [
            0,
            0.65952,
            0,
            0,
            0.34451
        ],
        "106": [
            0.19444,
            0.65952,
            0.05724,
            0,
            0.41181
        ],
        "107": [
            0,
            0.69444,
            0.03148,
            0,
            0.5206
        ],
        "108": [
            0,
            0.69444,
            0.01968,
            0.08334,
            0.29838
        ],
        "109": [
            0,
            0.43056,
            0,
            0,
            0.87801
        ],
        "110": [
            0,
            0.43056,
            0,
            0,
            0.60023
        ],
        "111": [
            0,
            0.43056,
            0,
            0.05556,
            0.48472
        ],
        "112": [
            0.19444,
            0.43056,
            0,
            0.08334,
            0.50313
        ],
        "113": [
            0.19444,
            0.43056,
            0.03588,
            0.08334,
            0.44641
        ],
        "114": [
            0,
            0.43056,
            0.02778,
            0.05556,
            0.45116
        ],
        "115": [
            0,
            0.43056,
            0,
            0.05556,
            0.46875
        ],
        "116": [
            0,
            0.61508,
            0,
            0.08334,
            0.36111
        ],
        "117": [
            0,
            0.43056,
            0,
            0.02778,
            0.57246
        ],
        "118": [
            0,
            0.43056,
            0.03588,
            0.02778,
            0.48472
        ],
        "119": [
            0,
            0.43056,
            0.02691,
            0.08334,
            0.71592
        ],
        "120": [
            0,
            0.43056,
            0,
            0.02778,
            0.57153
        ],
        "121": [
            0.19444,
            0.43056,
            0.03588,
            0.05556,
            0.49028
        ],
        "122": [
            0,
            0.43056,
            0.04398,
            0.05556,
            0.46505
        ],
        "160": [
            0,
            0,
            0,
            0,
            0.25
        ],
        "915": [
            0,
            0.68333,
            0.13889,
            0.08334,
            0.61528
        ],
        "916": [
            0,
            0.68333,
            0,
            0.16667,
            0.83334
        ],
        "920": [
            0,
            0.68333,
            0.02778,
            0.08334,
            0.76278
        ],
        "923": [
            0,
            0.68333,
            0,
            0.16667,
            0.69445
        ],
        "926": [
            0,
            0.68333,
            0.07569,
            0.08334,
            0.74236
        ],
        "928": [
            0,
            0.68333,
            0.08125,
            0.05556,
            0.83125
        ],
        "931": [
            0,
            0.68333,
            0.05764,
            0.08334,
            0.77986
        ],
        "933": [
            0,
            0.68333,
            0.13889,
            0.05556,
            0.58333
        ],
        "934": [
            0,
            0.68333,
            0,
            0.08334,
            0.66667
        ],
        "936": [
            0,
            0.68333,
            0.11,
            0.05556,
            0.61222
        ],
        "937": [
            0,
            0.68333,
            0.05017,
            0.08334,
            0.7724
        ],
        "945": [
            0,
            0.43056,
            0.0037,
            0.02778,
            0.6397
        ],
        "946": [
            0.19444,
            0.69444,
            0.05278,
            0.08334,
            0.56563
        ],
        "947": [
            0.19444,
            0.43056,
            0.05556,
            0,
            0.51773
        ],
        "948": [
            0,
            0.69444,
            0.03785,
            0.05556,
            0.44444
        ],
        "949": [
            0,
            0.43056,
            0,
            0.08334,
            0.46632
        ],
        "950": [
            0.19444,
            0.69444,
            0.07378,
            0.08334,
            0.4375
        ],
        "951": [
            0.19444,
            0.43056,
            0.03588,
            0.05556,
            0.49653
        ],
        "952": [
            0,
            0.69444,
            0.02778,
            0.08334,
            0.46944
        ],
        "953": [
            0,
            0.43056,
            0,
            0.05556,
            0.35394
        ],
        "954": [
            0,
            0.43056,
            0,
            0,
            0.57616
        ],
        "955": [
            0,
            0.69444,
            0,
            0,
            0.58334
        ],
        "956": [
            0.19444,
            0.43056,
            0,
            0.02778,
            0.60255
        ],
        "957": [
            0,
            0.43056,
            0.06366,
            0.02778,
            0.49398
        ],
        "958": [
            0.19444,
            0.69444,
            0.04601,
            0.11111,
            0.4375
        ],
        "959": [
            0,
            0.43056,
            0,
            0.05556,
            0.48472
        ],
        "960": [
            0,
            0.43056,
            0.03588,
            0,
            0.57003
        ],
        "961": [
            0.19444,
            0.43056,
            0,
            0.08334,
            0.51702
        ],
        "962": [
            0.09722,
            0.43056,
            0.07986,
            0.08334,
            0.36285
        ],
        "963": [
            0,
            0.43056,
            0.03588,
            0,
            0.57141
        ],
        "964": [
            0,
            0.43056,
            0.1132,
            0.02778,
            0.43715
        ],
        "965": [
            0,
            0.43056,
            0.03588,
            0.02778,
            0.54028
        ],
        "966": [
            0.19444,
            0.43056,
            0,
            0.08334,
            0.65417
        ],
        "967": [
            0.19444,
            0.43056,
            0,
            0.05556,
            0.62569
        ],
        "968": [
            0.19444,
            0.69444,
            0.03588,
            0.11111,
            0.65139
        ],
        "969": [
            0,
            0.43056,
            0.03588,
            0,
            0.62245
        ],
        "977": [
            0,
            0.69444,
            0,
            0.08334,
            0.59144
        ],
        "981": [
            0.19444,
            0.69444,
            0,
            0.08334,
            0.59583
        ],
        "982": [
            0,
            0.43056,
            0.02778,
            0,
            0.82813
        ],
        "1009": [
            0.19444,
            0.43056,
            0,
            0.08334,
            0.51702
        ],
        "1013": [
            0,
            0.43056,
            0,
            0.05556,
            0.4059
        ],
        "57649": [
            0,
            0.43056,
            0,
            0.02778,
            0.32246
        ],
        "57911": [
            0.19444,
            0.43056,
            0,
            0.08334,
            0.38403
        ]
    },
    "SansSerif-Bold": {
        "32": [
            0,
            0,
            0,
            0,
            0.25
        ],
        "33": [
            0,
            0.69444,
            0,
            0,
            0.36667
        ],
        "34": [
            0,
            0.69444,
            0,
            0,
            0.55834
        ],
        "35": [
            0.19444,
            0.69444,
            0,
            0,
            0.91667
        ],
        "36": [
            0.05556,
            0.75,
            0,
            0,
            0.55
        ],
        "37": [
            0.05556,
            0.75,
            0,
            0,
            1.02912
        ],
        "38": [
            0,
            0.69444,
            0,
            0,
            0.83056
        ],
        "39": [
            0,
            0.69444,
            0,
            0,
            0.30556
        ],
        "40": [
            0.25,
            0.75,
            0,
            0,
            0.42778
        ],
        "41": [
            0.25,
            0.75,
            0,
            0,
            0.42778
        ],
        "42": [
            0,
            0.75,
            0,
            0,
            0.55
        ],
        "43": [
            0.11667,
            0.61667,
            0,
            0,
            0.85556
        ],
        "44": [
            0.10556,
            0.13056,
            0,
            0,
            0.30556
        ],
        "45": [
            0,
            0.45833,
            0,
            0,
            0.36667
        ],
        "46": [
            0,
            0.13056,
            0,
            0,
            0.30556
        ],
        "47": [
            0.25,
            0.75,
            0,
            0,
            0.55
        ],
        "48": [
            0,
            0.69444,
            0,
            0,
            0.55
        ],
        "49": [
            0,
            0.69444,
            0,
            0,
            0.55
        ],
        "50": [
            0,
            0.69444,
            0,
            0,
            0.55
        ],
        "51": [
            0,
            0.69444,
            0,
            0,
            0.55
        ],
        "52": [
            0,
            0.69444,
            0,
            0,
            0.55
        ],
        "53": [
            0,
            0.69444,
            0,
            0,
            0.55
        ],
        "54": [
            0,
            0.69444,
            0,
            0,
            0.55
        ],
        "55": [
            0,
            0.69444,
            0,
            0,
            0.55
        ],
        "56": [
            0,
            0.69444,
            0,
            0,
            0.55
        ],
        "57": [
            0,
            0.69444,
            0,
            0,
            0.55
        ],
        "58": [
            0,
            0.45833,
            0,
            0,
            0.30556
        ],
        "59": [
            0.10556,
            0.45833,
            0,
            0,
            0.30556
        ],
        "61": [
            -0.09375,
            0.40625,
            0,
            0,
            0.85556
        ],
        "63": [
            0,
            0.69444,
            0,
            0,
            0.51945
        ],
        "64": [
            0,
            0.69444,
            0,
            0,
            0.73334
        ],
        "65": [
            0,
            0.69444,
            0,
            0,
            0.73334
        ],
        "66": [
            0,
            0.69444,
            0,
            0,
            0.73334
        ],
        "67": [
            0,
            0.69444,
            0,
            0,
            0.70278
        ],
        "68": [
            0,
            0.69444,
            0,
            0,
            0.79445
        ],
        "69": [
            0,
            0.69444,
            0,
            0,
            0.64167
        ],
        "70": [
            0,
            0.69444,
            0,
            0,
            0.61111
        ],
        "71": [
            0,
            0.69444,
            0,
            0,
            0.73334
        ],
        "72": [
            0,
            0.69444,
            0,
            0,
            0.79445
        ],
        "73": [
            0,
            0.69444,
            0,
            0,
            0.33056
        ],
        "74": [
            0,
            0.69444,
            0,
            0,
            0.51945
        ],
        "75": [
            0,
            0.69444,
            0,
            0,
            0.76389
        ],
        "76": [
            0,
            0.69444,
            0,
            0,
            0.58056
        ],
        "77": [
            0,
            0.69444,
            0,
            0,
            0.97778
        ],
        "78": [
            0,
            0.69444,
            0,
            0,
            0.79445
        ],
        "79": [
            0,
            0.69444,
            0,
            0,
            0.79445
        ],
        "80": [
            0,
            0.69444,
            0,
            0,
            0.70278
        ],
        "81": [
            0.10556,
            0.69444,
            0,
            0,
            0.79445
        ],
        "82": [
            0,
            0.69444,
            0,
            0,
            0.70278
        ],
        "83": [
            0,
            0.69444,
            0,
            0,
            0.61111
        ],
        "84": [
            0,
            0.69444,
            0,
            0,
            0.73334
        ],
        "85": [
            0,
            0.69444,
            0,
            0,
            0.76389
        ],
        "86": [
            0,
            0.69444,
            0.01528,
            0,
            0.73334
        ],
        "87": [
            0,
            0.69444,
            0.01528,
            0,
            1.03889
        ],
        "88": [
            0,
            0.69444,
            0,
            0,
            0.73334
        ],
        "89": [
            0,
            0.69444,
            0.0275,
            0,
            0.73334
        ],
        "90": [
            0,
            0.69444,
            0,
            0,
            0.67223
        ],
        "91": [
            0.25,
            0.75,
            0,
            0,
            0.34306
        ],
        "93": [
            0.25,
            0.75,
            0,
            0,
            0.34306
        ],
        "94": [
            0,
            0.69444,
            0,
            0,
            0.55
        ],
        "95": [
            0.35,
            0.10833,
            0.03056,
            0,
            0.55
        ],
        "97": [
            0,
            0.45833,
            0,
            0,
            0.525
        ],
        "98": [
            0,
            0.69444,
            0,
            0,
            0.56111
        ],
        "99": [
            0,
            0.45833,
            0,
            0,
            0.48889
        ],
        "100": [
            0,
            0.69444,
            0,
            0,
            0.56111
        ],
        "101": [
            0,
            0.45833,
            0,
            0,
            0.51111
        ],
        "102": [
            0,
            0.69444,
            0.07639,
            0,
            0.33611
        ],
        "103": [
            0.19444,
            0.45833,
            0.01528,
            0,
            0.55
        ],
        "104": [
            0,
            0.69444,
            0,
            0,
            0.56111
        ],
        "105": [
            0,
            0.69444,
            0,
            0,
            0.25556
        ],
        "106": [
            0.19444,
            0.69444,
            0,
            0,
            0.28611
        ],
        "107": [
            0,
            0.69444,
            0,
            0,
            0.53056
        ],
        "108": [
            0,
            0.69444,
            0,
            0,
            0.25556
        ],
        "109": [
            0,
            0.45833,
            0,
            0,
            0.86667
        ],
        "110": [
            0,
            0.45833,
            0,
            0,
            0.56111
        ],
        "111": [
            0,
            0.45833,
            0,
            0,
            0.55
        ],
        "112": [
            0.19444,
            0.45833,
            0,
            0,
            0.56111
        ],
        "113": [
            0.19444,
            0.45833,
            0,
            0,
            0.56111
        ],
        "114": [
            0,
            0.45833,
            0.01528,
            0,
            0.37222
        ],
        "115": [
            0,
            0.45833,
            0,
            0,
            0.42167
        ],
        "116": [
            0,
            0.58929,
            0,
            0,
            0.40417
        ],
        "117": [
            0,
            0.45833,
            0,
            0,
            0.56111
        ],
        "118": [
            0,
            0.45833,
            0.01528,
            0,
            0.5
        ],
        "119": [
            0,
            0.45833,
            0.01528,
            0,
            0.74445
        ],
        "120": [
            0,
            0.45833,
            0,
            0,
            0.5
        ],
        "121": [
            0.19444,
            0.45833,
            0.01528,
            0,
            0.5
        ],
        "122": [
            0,
            0.45833,
            0,
            0,
            0.47639
        ],
        "126": [
            0.35,
            0.34444,
            0,
            0,
            0.55
        ],
        "160": [
            0,
            0,
            0,
            0,
            0.25
        ],
        "168": [
            0,
            0.69444,
            0,
            0,
            0.55
        ],
        "176": [
            0,
            0.69444,
            0,
            0,
            0.73334
        ],
        "180": [
            0,
            0.69444,
            0,
            0,
            0.55
        ],
        "184": [
            0.17014,
            0,
            0,
            0,
            0.48889
        ],
        "305": [
            0,
            0.45833,
            0,
            0,
            0.25556
        ],
        "567": [
            0.19444,
            0.45833,
            0,
            0,
            0.28611
        ],
        "710": [
            0,
            0.69444,
            0,
            0,
            0.55
        ],
        "711": [
            0,
            0.63542,
            0,
            0,
            0.55
        ],
        "713": [
            0,
            0.63778,
            0,
            0,
            0.55
        ],
        "728": [
            0,
            0.69444,
            0,
            0,
            0.55
        ],
        "729": [
            0,
            0.69444,
            0,
            0,
            0.30556
        ],
        "730": [
            0,
            0.69444,
            0,
            0,
            0.73334
        ],
        "732": [
            0,
            0.69444,
            0,
            0,
            0.55
        ],
        "733": [
            0,
            0.69444,
            0,
            0,
            0.55
        ],
        "915": [
            0,
            0.69444,
            0,
            0,
            0.58056
        ],
        "916": [
            0,
            0.69444,
            0,
            0,
            0.91667
        ],
        "920": [
            0,
            0.69444,
            0,
            0,
            0.85556
        ],
        "923": [
            0,
            0.69444,
            0,
            0,
            0.67223
        ],
        "926": [
            0,
            0.69444,
            0,
            0,
            0.73334
        ],
        "928": [
            0,
            0.69444,
            0,
            0,
            0.79445
        ],
        "931": [
            0,
            0.69444,
            0,
            0,
            0.79445
        ],
        "933": [
            0,
            0.69444,
            0,
            0,
            0.85556
        ],
        "934": [
            0,
            0.69444,
            0,
            0,
            0.79445
        ],
        "936": [
            0,
            0.69444,
            0,
            0,
            0.85556
        ],
        "937": [
            0,
            0.69444,
            0,
            0,
            0.79445
        ],
        "8211": [
            0,
            0.45833,
            0.03056,
            0,
            0.55
        ],
        "8212": [
            0,
            0.45833,
            0.03056,
            0,
            1.10001
        ],
        "8216": [
            0,
            0.69444,
            0,
            0,
            0.30556
        ],
        "8217": [
            0,
            0.69444,
            0,
            0,
            0.30556
        ],
        "8220": [
            0,
            0.69444,
            0,
            0,
            0.55834
        ],
        "8221": [
            0,
            0.69444,
            0,
            0,
            0.55834
        ]
    },
    "SansSerif-Italic": {
        "32": [
            0,
            0,
            0,
            0,
            0.25
        ],
        "33": [
            0,
            0.69444,
            0.05733,
            0,
            0.31945
        ],
        "34": [
            0,
            0.69444,
            0.00316,
            0,
            0.5
        ],
        "35": [
            0.19444,
            0.69444,
            0.05087,
            0,
            0.83334
        ],
        "36": [
            0.05556,
            0.75,
            0.11156,
            0,
            0.5
        ],
        "37": [
            0.05556,
            0.75,
            0.03126,
            0,
            0.83334
        ],
        "38": [
            0,
            0.69444,
            0.03058,
            0,
            0.75834
        ],
        "39": [
            0,
            0.69444,
            0.07816,
            0,
            0.27778
        ],
        "40": [
            0.25,
            0.75,
            0.13164,
            0,
            0.38889
        ],
        "41": [
            0.25,
            0.75,
            0.02536,
            0,
            0.38889
        ],
        "42": [
            0,
            0.75,
            0.11775,
            0,
            0.5
        ],
        "43": [
            0.08333,
            0.58333,
            0.02536,
            0,
            0.77778
        ],
        "44": [
            0.125,
            0.08333,
            0,
            0,
            0.27778
        ],
        "45": [
            0,
            0.44444,
            0.01946,
            0,
            0.33333
        ],
        "46": [
            0,
            0.08333,
            0,
            0,
            0.27778
        ],
        "47": [
            0.25,
            0.75,
            0.13164,
            0,
            0.5
        ],
        "48": [
            0,
            0.65556,
            0.11156,
            0,
            0.5
        ],
        "49": [
            0,
            0.65556,
            0.11156,
            0,
            0.5
        ],
        "50": [
            0,
            0.65556,
            0.11156,
            0,
            0.5
        ],
        "51": [
            0,
            0.65556,
            0.11156,
            0,
            0.5
        ],
        "52": [
            0,
            0.65556,
            0.11156,
            0,
            0.5
        ],
        "53": [
            0,
            0.65556,
            0.11156,
            0,
            0.5
        ],
        "54": [
            0,
            0.65556,
            0.11156,
            0,
            0.5
        ],
        "55": [
            0,
            0.65556,
            0.11156,
            0,
            0.5
        ],
        "56": [
            0,
            0.65556,
            0.11156,
            0,
            0.5
        ],
        "57": [
            0,
            0.65556,
            0.11156,
            0,
            0.5
        ],
        "58": [
            0,
            0.44444,
            0.02502,
            0,
            0.27778
        ],
        "59": [
            0.125,
            0.44444,
            0.02502,
            0,
            0.27778
        ],
        "61": [
            -0.13,
            0.37,
            0.05087,
            0,
            0.77778
        ],
        "63": [
            0,
            0.69444,
            0.11809,
            0,
            0.47222
        ],
        "64": [
            0,
            0.69444,
            0.07555,
            0,
            0.66667
        ],
        "65": [
            0,
            0.69444,
            0,
            0,
            0.66667
        ],
        "66": [
            0,
            0.69444,
            0.08293,
            0,
            0.66667
        ],
        "67": [
            0,
            0.69444,
            0.11983,
            0,
            0.63889
        ],
        "68": [
            0,
            0.69444,
            0.07555,
            0,
            0.72223
        ],
        "69": [
            0,
            0.69444,
            0.11983,
            0,
            0.59722
        ],
        "70": [
            0,
            0.69444,
            0.13372,
            0,
            0.56945
        ],
        "71": [
            0,
            0.69444,
            0.11983,
            0,
            0.66667
        ],
        "72": [
            0,
            0.69444,
            0.08094,
            0,
            0.70834
        ],
        "73": [
            0,
            0.69444,
            0.13372,
            0,
            0.27778
        ],
        "74": [
            0,
            0.69444,
            0.08094,
            0,
            0.47222
        ],
        "75": [
            0,
            0.69444,
            0.11983,
            0,
            0.69445
        ],
        "76": [
            0,
            0.69444,
            0,
            0,
            0.54167
        ],
        "77": [
            0,
            0.69444,
            0.08094,
            0,
            0.875
        ],
        "78": [
            0,
            0.69444,
            0.08094,
            0,
            0.70834
        ],
        "79": [
            0,
            0.69444,
            0.07555,
            0,
            0.73611
        ],
        "80": [
            0,
            0.69444,
            0.08293,
            0,
            0.63889
        ],
        "81": [
            0.125,
            0.69444,
            0.07555,
            0,
            0.73611
        ],
        "82": [
            0,
            0.69444,
            0.08293,
            0,
            0.64584
        ],
        "83": [
            0,
            0.69444,
            0.09205,
            0,
            0.55556
        ],
        "84": [
            0,
            0.69444,
            0.13372,
            0,
            0.68056
        ],
        "85": [
            0,
            0.69444,
            0.08094,
            0,
            0.6875
        ],
        "86": [
            0,
            0.69444,
            0.1615,
            0,
            0.66667
        ],
        "87": [
            0,
            0.69444,
            0.1615,
            0,
            0.94445
        ],
        "88": [
            0,
            0.69444,
            0.13372,
            0,
            0.66667
        ],
        "89": [
            0,
            0.69444,
            0.17261,
            0,
            0.66667
        ],
        "90": [
            0,
            0.69444,
            0.11983,
            0,
            0.61111
        ],
        "91": [
            0.25,
            0.75,
            0.15942,
            0,
            0.28889
        ],
        "93": [
            0.25,
            0.75,
            0.08719,
            0,
            0.28889
        ],
        "94": [
            0,
            0.69444,
            0.0799,
            0,
            0.5
        ],
        "95": [
            0.35,
            0.09444,
            0.08616,
            0,
            0.5
        ],
        "97": [
            0,
            0.44444,
            0.00981,
            0,
            0.48056
        ],
        "98": [
            0,
            0.69444,
            0.03057,
            0,
            0.51667
        ],
        "99": [
            0,
            0.44444,
            0.08336,
            0,
            0.44445
        ],
        "100": [
            0,
            0.69444,
            0.09483,
            0,
            0.51667
        ],
        "101": [
            0,
            0.44444,
            0.06778,
            0,
            0.44445
        ],
        "102": [
            0,
            0.69444,
            0.21705,
            0,
            0.30556
        ],
        "103": [
            0.19444,
            0.44444,
            0.10836,
            0,
            0.5
        ],
        "104": [
            0,
            0.69444,
            0.01778,
            0,
            0.51667
        ],
        "105": [
            0,
            0.67937,
            0.09718,
            0,
            0.23889
        ],
        "106": [
            0.19444,
            0.67937,
            0.09162,
            0,
            0.26667
        ],
        "107": [
            0,
            0.69444,
            0.08336,
            0,
            0.48889
        ],
        "108": [
            0,
            0.69444,
            0.09483,
            0,
            0.23889
        ],
        "109": [
            0,
            0.44444,
            0.01778,
            0,
            0.79445
        ],
        "110": [
            0,
            0.44444,
            0.01778,
            0,
            0.51667
        ],
        "111": [
            0,
            0.44444,
            0.06613,
            0,
            0.5
        ],
        "112": [
            0.19444,
            0.44444,
            0.0389,
            0,
            0.51667
        ],
        "113": [
            0.19444,
            0.44444,
            0.04169,
            0,
            0.51667
        ],
        "114": [
            0,
            0.44444,
            0.10836,
            0,
            0.34167
        ],
        "115": [
            0,
            0.44444,
            0.0778,
            0,
            0.38333
        ],
        "116": [
            0,
            0.57143,
            0.07225,
            0,
            0.36111
        ],
        "117": [
            0,
            0.44444,
            0.04169,
            0,
            0.51667
        ],
        "118": [
            0,
            0.44444,
            0.10836,
            0,
            0.46111
        ],
        "119": [
            0,
            0.44444,
            0.10836,
            0,
            0.68334
        ],
        "120": [
            0,
            0.44444,
            0.09169,
            0,
            0.46111
        ],
        "121": [
            0.19444,
            0.44444,
            0.10836,
            0,
            0.46111
        ],
        "122": [
            0,
            0.44444,
            0.08752,
            0,
            0.43472
        ],
        "126": [
            0.35,
            0.32659,
            0.08826,
            0,
            0.5
        ],
        "160": [
            0,
            0,
            0,
            0,
            0.25
        ],
        "168": [
            0,
            0.67937,
            0.06385,
            0,
            0.5
        ],
        "176": [
            0,
            0.69444,
            0,
            0,
            0.73752
        ],
        "184": [
            0.17014,
            0,
            0,
            0,
            0.44445
        ],
        "305": [
            0,
            0.44444,
            0.04169,
            0,
            0.23889
        ],
        "567": [
            0.19444,
            0.44444,
            0.04169,
            0,
            0.26667
        ],
        "710": [
            0,
            0.69444,
            0.0799,
            0,
            0.5
        ],
        "711": [
            0,
            0.63194,
            0.08432,
            0,
            0.5
        ],
        "713": [
            0,
            0.60889,
            0.08776,
            0,
            0.5
        ],
        "714": [
            0,
            0.69444,
            0.09205,
            0,
            0.5
        ],
        "715": [
            0,
            0.69444,
            0,
            0,
            0.5
        ],
        "728": [
            0,
            0.69444,
            0.09483,
            0,
            0.5
        ],
        "729": [
            0,
            0.67937,
            0.07774,
            0,
            0.27778
        ],
        "730": [
            0,
            0.69444,
            0,
            0,
            0.73752
        ],
        "732": [
            0,
            0.67659,
            0.08826,
            0,
            0.5
        ],
        "733": [
            0,
            0.69444,
            0.09205,
            0,
            0.5
        ],
        "915": [
            0,
            0.69444,
            0.13372,
            0,
            0.54167
        ],
        "916": [
            0,
            0.69444,
            0,
            0,
            0.83334
        ],
        "920": [
            0,
            0.69444,
            0.07555,
            0,
            0.77778
        ],
        "923": [
            0,
            0.69444,
            0,
            0,
            0.61111
        ],
        "926": [
            0,
            0.69444,
            0.12816,
            0,
            0.66667
        ],
        "928": [
            0,
            0.69444,
            0.08094,
            0,
            0.70834
        ],
        "931": [
            0,
            0.69444,
            0.11983,
            0,
            0.72222
        ],
        "933": [
            0,
            0.69444,
            0.09031,
            0,
            0.77778
        ],
        "934": [
            0,
            0.69444,
            0.04603,
            0,
            0.72222
        ],
        "936": [
            0,
            0.69444,
            0.09031,
            0,
            0.77778
        ],
        "937": [
            0,
            0.69444,
            0.08293,
            0,
            0.72222
        ],
        "8211": [
            0,
            0.44444,
            0.08616,
            0,
            0.5
        ],
        "8212": [
            0,
            0.44444,
            0.08616,
            0,
            1.0
        ],
        "8216": [
            0,
            0.69444,
            0.07816,
            0,
            0.27778
        ],
        "8217": [
            0,
            0.69444,
            0.07816,
            0,
            0.27778
        ],
        "8220": [
            0,
            0.69444,
            0.14205,
            0,
            0.5
        ],
        "8221": [
            0,
            0.69444,
            0.00316,
            0,
            0.5
        ]
    },
    "SansSerif-Regular": {
        "32": [
            0,
            0,
            0,
            0,
            0.25
        ],
        "33": [
            0,
            0.69444,
            0,
            0,
            0.31945
        ],
        "34": [
            0,
            0.69444,
            0,
            0,
            0.5
        ],
        "35": [
            0.19444,
            0.69444,
            0,
            0,
            0.83334
        ],
        "36": [
            0.05556,
            0.75,
            0,
            0,
            0.5
        ],
        "37": [
            0.05556,
            0.75,
            0,
            0,
            0.83334
        ],
        "38": [
            0,
            0.69444,
            0,
            0,
            0.75834
        ],
        "39": [
            0,
            0.69444,
            0,
            0,
            0.27778
        ],
        "40": [
            0.25,
            0.75,
            0,
            0,
            0.38889
        ],
        "41": [
            0.25,
            0.75,
            0,
            0,
            0.38889
        ],
        "42": [
            0,
            0.75,
            0,
            0,
            0.5
        ],
        "43": [
            0.08333,
            0.58333,
            0,
            0,
            0.77778
        ],
        "44": [
            0.125,
            0.08333,
            0,
            0,
            0.27778
        ],
        "45": [
            0,
            0.44444,
            0,
            0,
            0.33333
        ],
        "46": [
            0,
            0.08333,
            0,
            0,
            0.27778
        ],
        "47": [
            0.25,
            0.75,
            0,
            0,
            0.5
        ],
        "48": [
            0,
            0.65556,
            0,
            0,
            0.5
        ],
        "49": [
            0,
            0.65556,
            0,
            0,
            0.5
        ],
        "50": [
            0,
            0.65556,
            0,
            0,
            0.5
        ],
        "51": [
            0,
            0.65556,
            0,
            0,
            0.5
        ],
        "52": [
            0,
            0.65556,
            0,
            0,
            0.5
        ],
        "53": [
            0,
            0.65556,
            0,
            0,
            0.5
        ],
        "54": [
            0,
            0.65556,
            0,
            0,
            0.5
        ],
        "55": [
            0,
            0.65556,
            0,
            0,
            0.5
        ],
        "56": [
            0,
            0.65556,
            0,
            0,
            0.5
        ],
        "57": [
            0,
            0.65556,
            0,
            0,
            0.5
        ],
        "58": [
            0,
            0.44444,
            0,
            0,
            0.27778
        ],
        "59": [
            0.125,
            0.44444,
            0,
            0,
            0.27778
        ],
        "61": [
            -0.13,
            0.37,
            0,
            0,
            0.77778
        ],
        "63": [
            0,
            0.69444,
            0,
            0,
            0.47222
        ],
        "64": [
            0,
            0.69444,
            0,
            0,
            0.66667
        ],
        "65": [
            0,
            0.69444,
            0,
            0,
            0.66667
        ],
        "66": [
            0,
            0.69444,
            0,
            0,
            0.66667
        ],
        "67": [
            0,
            0.69444,
            0,
            0,
            0.63889
        ],
        "68": [
            0,
            0.69444,
            0,
            0,
            0.72223
        ],
        "69": [
            0,
            0.69444,
            0,
            0,
            0.59722
        ],
        "70": [
            0,
            0.69444,
            0,
            0,
            0.56945
        ],
        "71": [
            0,
            0.69444,
            0,
            0,
            0.66667
        ],
        "72": [
            0,
            0.69444,
            0,
            0,
            0.70834
        ],
        "73": [
            0,
            0.69444,
            0,
            0,
            0.27778
        ],
        "74": [
            0,
            0.69444,
            0,
            0,
            0.47222
        ],
        "75": [
            0,
            0.69444,
            0,
            0,
            0.69445
        ],
        "76": [
            0,
            0.69444,
            0,
            0,
            0.54167
        ],
        "77": [
            0,
            0.69444,
            0,
            0,
            0.875
        ],
        "78": [
            0,
            0.69444,
            0,
            0,
            0.70834
        ],
        "79": [
            0,
            0.69444,
            0,
            0,
            0.73611
        ],
        "80": [
            0,
            0.69444,
            0,
            0,
            0.63889
        ],
        "81": [
            0.125,
            0.69444,
            0,
            0,
            0.73611
        ],
        "82": [
            0,
            0.69444,
            0,
            0,
            0.64584
        ],
        "83": [
            0,
            0.69444,
            0,
            0,
            0.55556
        ],
        "84": [
            0,
            0.69444,
            0,
            0,
            0.68056
        ],
        "85": [
            0,
            0.69444,
            0,
            0,
            0.6875
        ],
        "86": [
            0,
            0.69444,
            0.01389,
            0,
            0.66667
        ],
        "87": [
            0,
            0.69444,
            0.01389,
            0,
            0.94445
        ],
        "88": [
            0,
            0.69444,
            0,
            0,
            0.66667
        ],
        "89": [
            0,
            0.69444,
            0.025,
            0,
            0.66667
        ],
        "90": [
            0,
            0.69444,
            0,
            0,
            0.61111
        ],
        "91": [
            0.25,
            0.75,
            0,
            0,
            0.28889
        ],
        "93": [
            0.25,
            0.75,
            0,
            0,
            0.28889
        ],
        "94": [
            0,
            0.69444,
            0,
            0,
            0.5
        ],
        "95": [
            0.35,
            0.09444,
            0.02778,
            0,
            0.5
        ],
        "97": [
            0,
            0.44444,
            0,
            0,
            0.48056
        ],
        "98": [
            0,
            0.69444,
            0,
            0,
            0.51667
        ],
        "99": [
            0,
            0.44444,
            0,
            0,
            0.44445
        ],
        "100": [
            0,
            0.69444,
            0,
            0,
            0.51667
        ],
        "101": [
            0,
            0.44444,
            0,
            0,
            0.44445
        ],
        "102": [
            0,
            0.69444,
            0.06944,
            0,
            0.30556
        ],
        "103": [
            0.19444,
            0.44444,
            0.01389,
            0,
            0.5
        ],
        "104": [
            0,
            0.69444,
            0,
            0,
            0.51667
        ],
        "105": [
            0,
            0.67937,
            0,
            0,
            0.23889
        ],
        "106": [
            0.19444,
            0.67937,
            0,
            0,
            0.26667
        ],
        "107": [
            0,
            0.69444,
            0,
            0,
            0.48889
        ],
        "108": [
            0,
            0.69444,
            0,
            0,
            0.23889
        ],
        "109": [
            0,
            0.44444,
            0,
            0,
            0.79445
        ],
        "110": [
            0,
            0.44444,
            0,
            0,
            0.51667
        ],
        "111": [
            0,
            0.44444,
            0,
            0,
            0.5
        ],
        "112": [
            0.19444,
            0.44444,
            0,
            0,
            0.51667
        ],
        "113": [
            0.19444,
            0.44444,
            0,
            0,
            0.51667
        ],
        "114": [
            0,
            0.44444,
            0.01389,
            0,
            0.34167
        ],
        "115": [
            0,
            0.44444,
            0,
            0,
            0.38333
        ],
        "116": [
            0,
            0.57143,
            0,
            0,
            0.36111
        ],
        "117": [
            0,
            0.44444,
            0,
            0,
            0.51667
        ],
        "118": [
            0,
            0.44444,
            0.01389,
            0,
            0.46111
        ],
        "119": [
            0,
            0.44444,
            0.01389,
            0,
            0.68334
        ],
        "120": [
            0,
            0.44444,
            0,
            0,
            0.46111
        ],
        "121": [
            0.19444,
            0.44444,
            0.01389,
            0,
            0.46111
        ],
        "122": [
            0,
            0.44444,
            0,
            0,
            0.43472
        ],
        "126": [
            0.35,
            0.32659,
            0,
            0,
            0.5
        ],
        "160": [
            0,
            0,
            0,
            0,
            0.25
        ],
        "168": [
            0,
            0.67937,
            0,
            0,
            0.5
        ],
        "176": [
            0,
            0.69444,
            0,
            0,
            0.66667
        ],
        "184": [
            0.17014,
            0,
            0,
            0,
            0.44445
        ],
        "305": [
            0,
            0.44444,
            0,
            0,
            0.23889
        ],
        "567": [
            0.19444,
            0.44444,
            0,
            0,
            0.26667
        ],
        "710": [
            0,
            0.69444,
            0,
            0,
            0.5
        ],
        "711": [
            0,
            0.63194,
            0,
            0,
            0.5
        ],
        "713": [
            0,
            0.60889,
            0,
            0,
            0.5
        ],
        "714": [
            0,
            0.69444,
            0,
            0,
            0.5
        ],
        "715": [
            0,
            0.69444,
            0,
            0,
            0.5
        ],
        "728": [
            0,
            0.69444,
            0,
            0,
            0.5
        ],
        "729": [
            0,
            0.67937,
            0,
            0,
            0.27778
        ],
        "730": [
            0,
            0.69444,
            0,
            0,
            0.66667
        ],
        "732": [
            0,
            0.67659,
            0,
            0,
            0.5
        ],
        "733": [
            0,
            0.69444,
            0,
            0,
            0.5
        ],
        "915": [
            0,
            0.69444,
            0,
            0,
            0.54167
        ],
        "916": [
            0,
            0.69444,
            0,
            0,
            0.83334
        ],
        "920": [
            0,
            0.69444,
            0,
            0,
            0.77778
        ],
        "923": [
            0,
            0.69444,
            0,
            0,
            0.61111
        ],
        "926": [
            0,
            0.69444,
            0,
            0,
            0.66667
        ],
        "928": [
            0,
            0.69444,
            0,
            0,
            0.70834
        ],
        "931": [
            0,
            0.69444,
            0,
            0,
            0.72222
        ],
        "933": [
            0,
            0.69444,
            0,
            0,
            0.77778
        ],
        "934": [
            0,
            0.69444,
            0,
            0,
            0.72222
        ],
        "936": [
            0,
            0.69444,
            0,
            0,
            0.77778
        ],
        "937": [
            0,
            0.69444,
            0,
            0,
            0.72222
        ],
        "8211": [
            0,
            0.44444,
            0.02778,
            0,
            0.5
        ],
        "8212": [
            0,
            0.44444,
            0.02778,
            0,
            1.0
        ],
        "8216": [
            0,
            0.69444,
            0,
            0,
            0.27778
        ],
        "8217": [
            0,
            0.69444,
            0,
            0,
            0.27778
        ],
        "8220": [
            0,
            0.69444,
            0,
            0,
            0.5
        ],
        "8221": [
            0,
            0.69444,
            0,
            0,
            0.5
        ]
    },
    "Script-Regular": {
        "32": [
            0,
            0,
            0,
            0,
            0.25
        ],
        "65": [
            0,
            0.7,
            0.22925,
            0,
            0.80253
        ],
        "66": [
            0,
            0.7,
            0.04087,
            0,
            0.90757
        ],
        "67": [
            0,
            0.7,
            0.1689,
            0,
            0.66619
        ],
        "68": [
            0,
            0.7,
            0.09371,
            0,
            0.77443
        ],
        "69": [
            0,
            0.7,
            0.18583,
            0,
            0.56162
        ],
        "70": [
            0,
            0.7,
            0.13634,
            0,
            0.89544
        ],
        "71": [
            0,
            0.7,
            0.17322,
            0,
            0.60961
        ],
        "72": [
            0,
            0.7,
            0.29694,
            0,
            0.96919
        ],
        "73": [
            0,
            0.7,
            0.19189,
            0,
            0.80907
        ],
        "74": [
            0.27778,
            0.7,
            0.19189,
            0,
            1.05159
        ],
        "75": [
            0,
            0.7,
            0.31259,
            0,
            0.91364
        ],
        "76": [
            0,
            0.7,
            0.19189,
            0,
            0.87373
        ],
        "77": [
            0,
            0.7,
            0.15981,
            0,
            1.08031
        ],
        "78": [
            0,
            0.7,
            0.3525,
            0,
            0.9015
        ],
        "79": [
            0,
            0.7,
            0.08078,
            0,
            0.73787
        ],
        "80": [
            0,
            0.7,
            0.08078,
            0,
            1.01262
        ],
        "81": [
            0,
            0.7,
            0.03305,
            0,
            0.88282
        ],
        "82": [
            0,
            0.7,
            0.06259,
            0,
            0.85
        ],
        "83": [
            0,
            0.7,
            0.19189,
            0,
            0.86767
        ],
        "84": [
            0,
            0.7,
            0.29087,
            0,
            0.74697
        ],
        "85": [
            0,
            0.7,
            0.25815,
            0,
            0.79996
        ],
        "86": [
            0,
            0.7,
            0.27523,
            0,
            0.62204
        ],
        "87": [
            0,
            0.7,
            0.27523,
            0,
            0.80532
        ],
        "88": [
            0,
            0.7,
            0.26006,
            0,
            0.94445
        ],
        "89": [
            0,
            0.7,
            0.2939,
            0,
            0.70961
        ],
        "90": [
            0,
            0.7,
            0.24037,
            0,
            0.8212
        ],
        "160": [
            0,
            0,
            0,
            0,
            0.25
        ]
    },
    "Size1-Regular": {
        "32": [
            0,
            0,
            0,
            0,
            0.25
        ],
        "40": [
            0.35001,
            0.85,
            0,
            0,
            0.45834
        ],
        "41": [
            0.35001,
            0.85,
            0,
            0,
            0.45834
        ],
        "47": [
            0.35001,
            0.85,
            0,
            0,
            0.57778
        ],
        "91": [
            0.35001,
            0.85,
            0,
            0,
            0.41667
        ],
        "92": [
            0.35001,
            0.85,
            0,
            0,
            0.57778
        ],
        "93": [
            0.35001,
            0.85,
            0,
            0,
            0.41667
        ],
        "123": [
            0.35001,
            0.85,
            0,
            0,
            0.58334
        ],
        "125": [
            0.35001,
            0.85,
            0,
            0,
            0.58334
        ],
        "160": [
            0,
            0,
            0,
            0,
            0.25
        ],
        "710": [
            0,
            0.72222,
            0,
            0,
            0.55556
        ],
        "732": [
            0,
            0.72222,
            0,
            0,
            0.55556
        ],
        "770": [
            0,
            0.72222,
            0,
            0,
            0.55556
        ],
        "771": [
            0,
            0.72222,
            0,
            0,
            0.55556
        ],
        "8214": [
            -0.00099,
            0.601,
            0,
            0,
            0.77778
        ],
        "8593": [
            1e-05,
            0.6,
            0,
            0,
            0.66667
        ],
        "8595": [
            1e-05,
            0.6,
            0,
            0,
            0.66667
        ],
        "8657": [
            1e-05,
            0.6,
            0,
            0,
            0.77778
        ],
        "8659": [
            1e-05,
            0.6,
            0,
            0,
            0.77778
        ],
        "8719": [
            0.25001,
            0.75,
            0,
            0,
            0.94445
        ],
        "8720": [
            0.25001,
            0.75,
            0,
            0,
            0.94445
        ],
        "8721": [
            0.25001,
            0.75,
            0,
            0,
            1.05556
        ],
        "8730": [
            0.35001,
            0.85,
            0,
            0,
            1.0
        ],
        "8739": [
            -0.00599,
            0.606,
            0,
            0,
            0.33333
        ],
        "8741": [
            -0.00599,
            0.606,
            0,
            0,
            0.55556
        ],
        "8747": [
            0.30612,
            0.805,
            0.19445,
            0,
            0.47222
        ],
        "8748": [
            0.306,
            0.805,
            0.19445,
            0,
            0.47222
        ],
        "8749": [
            0.306,
            0.805,
            0.19445,
            0,
            0.47222
        ],
        "8750": [
            0.30612,
            0.805,
            0.19445,
            0,
            0.47222
        ],
        "8896": [
            0.25001,
            0.75,
            0,
            0,
            0.83334
        ],
        "8897": [
            0.25001,
            0.75,
            0,
            0,
            0.83334
        ],
        "8898": [
            0.25001,
            0.75,
            0,
            0,
            0.83334
        ],
        "8899": [
            0.25001,
            0.75,
            0,
            0,
            0.83334
        ],
        "8968": [
            0.35001,
            0.85,
            0,
            0,
            0.47222
        ],
        "8969": [
            0.35001,
            0.85,
            0,
            0,
            0.47222
        ],
        "8970": [
            0.35001,
            0.85,
            0,
            0,
            0.47222
        ],
        "8971": [
            0.35001,
            0.85,
            0,
            0,
            0.47222
        ],
        "9168": [
            -0.00099,
            0.601,
            0,
            0,
            0.66667
        ],
        "10216": [
            0.35001,
            0.85,
            0,
            0,
            0.47222
        ],
        "10217": [
            0.35001,
            0.85,
            0,
            0,
            0.47222
        ],
        "10752": [
            0.25001,
            0.75,
            0,
            0,
            1.11111
        ],
        "10753": [
            0.25001,
            0.75,
            0,
            0,
            1.11111
        ],
        "10754": [
            0.25001,
            0.75,
            0,
            0,
            1.11111
        ],
        "10756": [
            0.25001,
            0.75,
            0,
            0,
            0.83334
        ],
        "10758": [
            0.25001,
            0.75,
            0,
            0,
            0.83334
        ]
    },
    "Size2-Regular": {
        "32": [
            0,
            0,
            0,
            0,
            0.25
        ],
        "40": [
            0.65002,
            1.15,
            0,
            0,
            0.59722
        ],
        "41": [
            0.65002,
            1.15,
            0,
            0,
            0.59722
        ],
        "47": [
            0.65002,
            1.15,
            0,
            0,
            0.81111
        ],
        "91": [
            0.65002,
            1.15,
            0,
            0,
            0.47222
        ],
        "92": [
            0.65002,
            1.15,
            0,
            0,
            0.81111
        ],
        "93": [
            0.65002,
            1.15,
            0,
            0,
            0.47222
        ],
        "123": [
            0.65002,
            1.15,
            0,
            0,
            0.66667
        ],
        "125": [
            0.65002,
            1.15,
            0,
            0,
            0.66667
        ],
        "160": [
            0,
            0,
            0,
            0,
            0.25
        ],
        "710": [
            0,
            0.75,
            0,
            0,
            1.0
        ],
        "732": [
            0,
            0.75,
            0,
            0,
            1.0
        ],
        "770": [
            0,
            0.75,
            0,
            0,
            1.0
        ],
        "771": [
            0,
            0.75,
            0,
            0,
            1.0
        ],
        "8719": [
            0.55001,
            1.05,
            0,
            0,
            1.27778
        ],
        "8720": [
            0.55001,
            1.05,
            0,
            0,
            1.27778
        ],
        "8721": [
            0.55001,
            1.05,
            0,
            0,
            1.44445
        ],
        "8730": [
            0.65002,
            1.15,
            0,
            0,
            1.0
        ],
        "8747": [
            0.86225,
            1.36,
            0.44445,
            0,
            0.55556
        ],
        "8748": [
            0.862,
            1.36,
            0.44445,
            0,
            0.55556
        ],
        "8749": [
            0.862,
            1.36,
            0.44445,
            0,
            0.55556
        ],
        "8750": [
            0.86225,
            1.36,
            0.44445,
            0,
            0.55556
        ],
        "8896": [
            0.55001,
            1.05,
            0,
            0,
            1.11111
        ],
        "8897": [
            0.55001,
            1.05,
            0,
            0,
            1.11111
        ],
        "8898": [
            0.55001,
            1.05,
            0,
            0,
            1.11111
        ],
        "8899": [
            0.55001,
            1.05,
            0,
            0,
            1.11111
        ],
        "8968": [
            0.65002,
            1.15,
            0,
            0,
            0.52778
        ],
        "8969": [
            0.65002,
            1.15,
            0,
            0,
            0.52778
        ],
        "8970": [
            0.65002,
            1.15,
            0,
            0,
            0.52778
        ],
        "8971": [
            0.65002,
            1.15,
            0,
            0,
            0.52778
        ],
        "10216": [
            0.65002,
            1.15,
            0,
            0,
            0.61111
        ],
        "10217": [
            0.65002,
            1.15,
            0,
            0,
            0.61111
        ],
        "10752": [
            0.55001,
            1.05,
            0,
            0,
            1.51112
        ],
        "10753": [
            0.55001,
            1.05,
            0,
            0,
            1.51112
        ],
        "10754": [
            0.55001,
            1.05,
            0,
            0,
            1.51112
        ],
        "10756": [
            0.55001,
            1.05,
            0,
            0,
            1.11111
        ],
        "10758": [
            0.55001,
            1.05,
            0,
            0,
            1.11111
        ]
    },
    "Size3-Regular": {
        "32": [
            0,
            0,
            0,
            0,
            0.25
        ],
        "40": [
            0.95003,
            1.45,
            0,
            0,
            0.73611
        ],
        "41": [
            0.95003,
            1.45,
            0,
            0,
            0.73611
        ],
        "47": [
            0.95003,
            1.45,
            0,
            0,
            1.04445
        ],
        "91": [
            0.95003,
            1.45,
            0,
            0,
            0.52778
        ],
        "92": [
            0.95003,
            1.45,
            0,
            0,
            1.04445
        ],
        "93": [
            0.95003,
            1.45,
            0,
            0,
            0.52778
        ],
        "123": [
            0.95003,
            1.45,
            0,
            0,
            0.75
        ],
        "125": [
            0.95003,
            1.45,
            0,
            0,
            0.75
        ],
        "160": [
            0,
            0,
            0,
            0,
            0.25
        ],
        "710": [
            0,
            0.75,
            0,
            0,
            1.44445
        ],
        "732": [
            0,
            0.75,
            0,
            0,
            1.44445
        ],
        "770": [
            0,
            0.75,
            0,
            0,
            1.44445
        ],
        "771": [
            0,
            0.75,
            0,
            0,
            1.44445
        ],
        "8730": [
            0.95003,
            1.45,
            0,
            0,
            1.0
        ],
        "8968": [
            0.95003,
            1.45,
            0,
            0,
            0.58334
        ],
        "8969": [
            0.95003,
            1.45,
            0,
            0,
            0.58334
        ],
        "8970": [
            0.95003,
            1.45,
            0,
            0,
            0.58334
        ],
        "8971": [
            0.95003,
            1.45,
            0,
            0,
            0.58334
        ],
        "10216": [
            0.95003,
            1.45,
            0,
            0,
            0.75
        ],
        "10217": [
            0.95003,
            1.45,
            0,
            0,
            0.75
        ]
    },
    "Size4-Regular": {
        "32": [
            0,
            0,
            0,
            0,
            0.25
        ],
        "40": [
            1.25003,
            1.75,
            0,
            0,
            0.79167
        ],
        "41": [
            1.25003,
            1.75,
            0,
            0,
            0.79167
        ],
        "47": [
            1.25003,
            1.75,
            0,
            0,
            1.27778
        ],
        "91": [
            1.25003,
            1.75,
            0,
            0,
            0.58334
        ],
        "92": [
            1.25003,
            1.75,
            0,
            0,
            1.27778
        ],
        "93": [
            1.25003,
            1.75,
            0,
            0,
            0.58334
        ],
        "123": [
            1.25003,
            1.75,
            0,
            0,
            0.80556
        ],
        "125": [
            1.25003,
            1.75,
            0,
            0,
            0.80556
        ],
        "160": [
            0,
            0,
            0,
            0,
            0.25
        ],
        "710": [
            0,
            0.825,
            0,
            0,
            1.8889
        ],
        "732": [
            0,
            0.825,
            0,
            0,
            1.8889
        ],
        "770": [
            0,
            0.825,
            0,
            0,
            1.8889
        ],
        "771": [
            0,
            0.825,
            0,
            0,
            1.8889
        ],
        "8730": [
            1.25003,
            1.75,
            0,
            0,
            1.0
        ],
        "8968": [
            1.25003,
            1.75,
            0,
            0,
            0.63889
        ],
        "8969": [
            1.25003,
            1.75,
            0,
            0,
            0.63889
        ],
        "8970": [
            1.25003,
            1.75,
            0,
            0,
            0.63889
        ],
        "8971": [
            1.25003,
            1.75,
            0,
            0,
            0.63889
        ],
        "9115": [
            0.64502,
            1.155,
            0,
            0,
            0.875
        ],
        "9116": [
            1e-05,
            0.6,
            0,
            0,
            0.875
        ],
        "9117": [
            0.64502,
            1.155,
            0,
            0,
            0.875
        ],
        "9118": [
            0.64502,
            1.155,
            0,
            0,
            0.875
        ],
        "9119": [
            1e-05,
            0.6,
            0,
            0,
            0.875
        ],
        "9120": [
            0.64502,
            1.155,
            0,
            0,
            0.875
        ],
        "9121": [
            0.64502,
            1.155,
            0,
            0,
            0.66667
        ],
        "9122": [
            -0.00099,
            0.601,
            0,
            0,
            0.66667
        ],
        "9123": [
            0.64502,
            1.155,
            0,
            0,
            0.66667
        ],
        "9124": [
            0.64502,
            1.155,
            0,
            0,
            0.66667
        ],
        "9125": [
            -0.00099,
            0.601,
            0,
            0,
            0.66667
        ],
        "9126": [
            0.64502,
            1.155,
            0,
            0,
            0.66667
        ],
        "9127": [
            1e-05,
            0.9,
            0,
            0,
            0.88889
        ],
        "9128": [
            0.65002,
            1.15,
            0,
            0,
            0.88889
        ],
        "9129": [
            0.90001,
            0,
            0,
            0,
            0.88889
        ],
        "9130": [
            0,
            0.3,
            0,
            0,
            0.88889
        ],
        "9131": [
            1e-05,
            0.9,
            0,
            0,
            0.88889
        ],
        "9132": [
            0.65002,
            1.15,
            0,
            0,
            0.88889
        ],
        "9133": [
            0.90001,
            0,
            0,
            0,
            0.88889
        ],
        "9143": [
            0.88502,
            0.915,
            0,
            0,
            1.05556
        ],
        "10216": [
            1.25003,
            1.75,
            0,
            0,
            0.80556
        ],
        "10217": [
            1.25003,
            1.75,
            0,
            0,
            0.80556
        ],
        "57344": [
            -0.00499,
            0.605,
            0,
            0,
            1.05556
        ],
        "57345": [
            -0.00499,
            0.605,
            0,
            0,
            1.05556
        ],
        "57680": [
            0,
            0.12,
            0,
            0,
            0.45
        ],
        "57681": [
            0,
            0.12,
            0,
            0,
            0.45
        ],
        "57682": [
            0,
            0.12,
            0,
            0,
            0.45
        ],
        "57683": [
            0,
            0.12,
            0,
            0,
            0.45
        ]
    },
    "Typewriter-Regular": {
        "32": [
            0,
            0,
            0,
            0,
            0.525
        ],
        "33": [
            0,
            0.61111,
            0,
            0,
            0.525
        ],
        "34": [
            0,
            0.61111,
            0,
            0,
            0.525
        ],
        "35": [
            0,
            0.61111,
            0,
            0,
            0.525
        ],
        "36": [
            0.08333,
            0.69444,
            0,
            0,
            0.525
        ],
        "37": [
            0.08333,
            0.69444,
            0,
            0,
            0.525
        ],
        "38": [
            0,
            0.61111,
            0,
            0,
            0.525
        ],
        "39": [
            0,
            0.61111,
            0,
            0,
            0.525
        ],
        "40": [
            0.08333,
            0.69444,
            0,
            0,
            0.525
        ],
        "41": [
            0.08333,
            0.69444,
            0,
            0,
            0.525
        ],
        "42": [
            0,
            0.52083,
            0,
            0,
            0.525
        ],
        "43": [
            -0.08056,
            0.53055,
            0,
            0,
            0.525
        ],
        "44": [
            0.13889,
            0.125,
            0,
            0,
            0.525
        ],
        "45": [
            -0.08056,
            0.53055,
            0,
            0,
            0.525
        ],
        "46": [
            0,
            0.125,
            0,
            0,
            0.525
        ],
        "47": [
            0.08333,
            0.69444,
            0,
            0,
            0.525
        ],
        "48": [
            0,
            0.61111,
            0,
            0,
            0.525
        ],
        "49": [
            0,
            0.61111,
            0,
            0,
            0.525
        ],
        "50": [
            0,
            0.61111,
            0,
            0,
            0.525
        ],
        "51": [
            0,
            0.61111,
            0,
            0,
            0.525
        ],
        "52": [
            0,
            0.61111,
            0,
            0,
            0.525
        ],
        "53": [
            0,
            0.61111,
            0,
            0,
            0.525
        ],
        "54": [
            0,
            0.61111,
            0,
            0,
            0.525
        ],
        "55": [
            0,
            0.61111,
            0,
            0,
            0.525
        ],
        "56": [
            0,
            0.61111,
            0,
            0,
            0.525
        ],
        "57": [
            0,
            0.61111,
            0,
            0,
            0.525
        ],
        "58": [
            0,
            0.43056,
            0,
            0,
            0.525
        ],
        "59": [
            0.13889,
            0.43056,
            0,
            0,
            0.525
        ],
        "60": [
            -0.05556,
            0.55556,
            0,
            0,
            0.525
        ],
        "61": [
            -0.19549,
            0.41562,
            0,
            0,
            0.525
        ],
        "62": [
            -0.05556,
            0.55556,
            0,
            0,
            0.525
        ],
        "63": [
            0,
            0.61111,
            0,
            0,
            0.525
        ],
        "64": [
            0,
            0.61111,
            0,
            0,
            0.525
        ],
        "65": [
            0,
            0.61111,
            0,
            0,
            0.525
        ],
        "66": [
            0,
            0.61111,
            0,
            0,
            0.525
        ],
        "67": [
            0,
            0.61111,
            0,
            0,
            0.525
        ],
        "68": [
            0,
            0.61111,
            0,
            0,
            0.525
        ],
        "69": [
            0,
            0.61111,
            0,
            0,
            0.525
        ],
        "70": [
            0,
            0.61111,
            0,
            0,
            0.525
        ],
        "71": [
            0,
            0.61111,
            0,
            0,
            0.525
        ],
        "72": [
            0,
            0.61111,
            0,
            0,
            0.525
        ],
        "73": [
            0,
            0.61111,
            0,
            0,
            0.525
        ],
        "74": [
            0,
            0.61111,
            0,
            0,
            0.525
        ],
        "75": [
            0,
            0.61111,
            0,
            0,
            0.525
        ],
        "76": [
            0,
            0.61111,
            0,
            0,
            0.525
        ],
        "77": [
            0,
            0.61111,
            0,
            0,
            0.525
        ],
        "78": [
            0,
            0.61111,
            0,
            0,
            0.525
        ],
        "79": [
            0,
            0.61111,
            0,
            0,
            0.525
        ],
        "80": [
            0,
            0.61111,
            0,
            0,
            0.525
        ],
        "81": [
            0.13889,
            0.61111,
            0,
            0,
            0.525
        ],
        "82": [
            0,
            0.61111,
            0,
            0,
            0.525
        ],
        "83": [
            0,
            0.61111,
            0,
            0,
            0.525
        ],
        "84": [
            0,
            0.61111,
            0,
            0,
            0.525
        ],
        "85": [
            0,
            0.61111,
            0,
            0,
            0.525
        ],
        "86": [
            0,
            0.61111,
            0,
            0,
            0.525
        ],
        "87": [
            0,
            0.61111,
            0,
            0,
            0.525
        ],
        "88": [
            0,
            0.61111,
            0,
            0,
            0.525
        ],
        "89": [
            0,
            0.61111,
            0,
            0,
            0.525
        ],
        "90": [
            0,
            0.61111,
            0,
            0,
            0.525
        ],
        "91": [
            0.08333,
            0.69444,
            0,
            0,
            0.525
        ],
        "92": [
            0.08333,
            0.69444,
            0,
            0,
            0.525
        ],
        "93": [
            0.08333,
            0.69444,
            0,
            0,
            0.525
        ],
        "94": [
            0,
            0.61111,
            0,
            0,
            0.525
        ],
        "95": [
            0.09514,
            0,
            0,
            0,
            0.525
        ],
        "96": [
            0,
            0.61111,
            0,
            0,
            0.525
        ],
        "97": [
            0,
            0.43056,
            0,
            0,
            0.525
        ],
        "98": [
            0,
            0.61111,
            0,
            0,
            0.525
        ],
        "99": [
            0,
            0.43056,
            0,
            0,
            0.525
        ],
        "100": [
            0,
            0.61111,
            0,
            0,
            0.525
        ],
        "101": [
            0,
            0.43056,
            0,
            0,
            0.525
        ],
        "102": [
            0,
            0.61111,
            0,
            0,
            0.525
        ],
        "103": [
            0.22222,
            0.43056,
            0,
            0,
            0.525
        ],
        "104": [
            0,
            0.61111,
            0,
            0,
            0.525
        ],
        "105": [
            0,
            0.61111,
            0,
            0,
            0.525
        ],
        "106": [
            0.22222,
            0.61111,
            0,
            0,
            0.525
        ],
        "107": [
            0,
            0.61111,
            0,
            0,
            0.525
        ],
        "108": [
            0,
            0.61111,
            0,
            0,
            0.525
        ],
        "109": [
            0,
            0.43056,
            0,
            0,
            0.525
        ],
        "110": [
            0,
            0.43056,
            0,
            0,
            0.525
        ],
        "111": [
            0,
            0.43056,
            0,
            0,
            0.525
        ],
        "112": [
            0.22222,
            0.43056,
            0,
            0,
            0.525
        ],
        "113": [
            0.22222,
            0.43056,
            0,
            0,
            0.525
        ],
        "114": [
            0,
            0.43056,
            0,
            0,
            0.525
        ],
        "115": [
            0,
            0.43056,
            0,
            0,
            0.525
        ],
        "116": [
            0,
            0.55358,
            0,
            0,
            0.525
        ],
        "117": [
            0,
            0.43056,
            0,
            0,
            0.525
        ],
        "118": [
            0,
            0.43056,
            0,
            0,
            0.525
        ],
        "119": [
            0,
            0.43056,
            0,
            0,
            0.525
        ],
        "120": [
            0,
            0.43056,
            0,
            0,
            0.525
        ],
        "121": [
            0.22222,
            0.43056,
            0,
            0,
            0.525
        ],
        "122": [
            0,
            0.43056,
            0,
            0,
            0.525
        ],
        "123": [
            0.08333,
            0.69444,
            0,
            0,
            0.525
        ],
        "124": [
            0.08333,
            0.69444,
            0,
            0,
            0.525
        ],
        "125": [
            0.08333,
            0.69444,
            0,
            0,
            0.525
        ],
        "126": [
            0,
            0.61111,
            0,
            0,
            0.525
        ],
        "127": [
            0,
            0.61111,
            0,
            0,
            0.525
        ],
        "160": [
            0,
            0,
            0,
            0,
            0.525
        ],
        "176": [
            0,
            0.61111,
            0,
            0,
            0.525
        ],
        "184": [
            0.19445,
            0,
            0,
            0,
            0.525
        ],
        "305": [
            0,
            0.43056,
            0,
            0,
            0.525
        ],
        "567": [
            0.22222,
            0.43056,
            0,
            0,
            0.525
        ],
        "711": [
            0,
            0.56597,
            0,
            0,
            0.525
        ],
        "713": [
            0,
            0.56555,
            0,
            0,
            0.525
        ],
        "714": [
            0,
            0.61111,
            0,
            0,
            0.525
        ],
        "715": [
            0,
            0.61111,
            0,
            0,
            0.525
        ],
        "728": [
            0,
            0.61111,
            0,
            0,
            0.525
        ],
        "730": [
            0,
            0.61111,
            0,
            0,
            0.525
        ],
        "770": [
            0,
            0.61111,
            0,
            0,
            0.525
        ],
        "771": [
            0,
            0.61111,
            0,
            0,
            0.525
        ],
        "776": [
            0,
            0.61111,
            0,
            0,
            0.525
        ],
        "915": [
            0,
            0.61111,
            0,
            0,
            0.525
        ],
        "916": [
            0,
            0.61111,
            0,
            0,
            0.525
        ],
        "920": [
            0,
            0.61111,
            0,
            0,
            0.525
        ],
        "923": [
            0,
            0.61111,
            0,
            0,
            0.525
        ],
        "926": [
            0,
            0.61111,
            0,
            0,
            0.525
        ],
        "928": [
            0,
            0.61111,
            0,
            0,
            0.525
        ],
        "931": [
            0,
            0.61111,
            0,
            0,
            0.525
        ],
        "933": [
            0,
            0.61111,
            0,
            0,
            0.525
        ],
        "934": [
            0,
            0.61111,
            0,
            0,
            0.525
        ],
        "936": [
            0,
            0.61111,
            0,
            0,
            0.525
        ],
        "937": [
            0,
            0.61111,
            0,
            0,
            0.525
        ],
        "8216": [
            0,
            0.61111,
            0,
            0,
            0.525
        ],
        "8217": [
            0,
            0.61111,
            0,
            0,
            0.525
        ],
        "8242": [
            0,
            0.61111,
            0,
            0,
            0.525
        ],
        "9251": [
            0.11111,
            0.21944,
            0,
            0,
            0.525
        ]
    }
};
var sigmasAndXis = {
    slant: [
        0.250,
        0.250,
        0.250
    ],
    space: [
        0.000,
        0.000,
        0.000
    ],
    stretch: [
        0.000,
        0.000,
        0.000
    ],
    shrink: [
        0.000,
        0.000,
        0.000
    ],
    xHeight: [
        0.431,
        0.431,
        0.431
    ],
    quad: [
        1.000,
        1.171,
        1.472
    ],
    extraSpace: [
        0.000,
        0.000,
        0.000
    ],
    num1: [
        0.677,
        0.732,
        0.925
    ],
    num2: [
        0.394,
        0.384,
        0.387
    ],
    num3: [
        0.444,
        0.471,
        0.504
    ],
    denom1: [
        0.686,
        0.752,
        1.025
    ],
    denom2: [
        0.345,
        0.344,
        0.532
    ],
    sup1: [
        0.413,
        0.503,
        0.504
    ],
    sup2: [
        0.363,
        0.431,
        0.404
    ],
    sup3: [
        0.289,
        0.286,
        0.294
    ],
    sub1: [
        0.150,
        0.143,
        0.200
    ],
    sub2: [
        0.247,
        0.286,
        0.400
    ],
    supDrop: [
        0.386,
        0.353,
        0.494
    ],
    subDrop: [
        0.050,
        0.071,
        0.100
    ],
    delim1: [
        2.390,
        1.700,
        1.980
    ],
    delim2: [
        1.010,
        1.157,
        1.420
    ],
    axisHeight: [
        0.250,
        0.250,
        0.250
    ],
    defaultRuleThickness: [
        0.04,
        0.049,
        0.049
    ],
    bigOpSpacing1: [
        0.111,
        0.111,
        0.111
    ],
    bigOpSpacing2: [
        0.166,
        0.166,
        0.166
    ],
    bigOpSpacing3: [
        0.2,
        0.2,
        0.2
    ],
    bigOpSpacing4: [
        0.6,
        0.611,
        0.611
    ],
    bigOpSpacing5: [
        0.1,
        0.143,
        0.143
    ],
    sqrtRuleThickness: [
        0.04,
        0.04,
        0.04
    ],
    ptPerEm: [
        10.0,
        10.0,
        10.0
    ],
    doubleRuleSep: [
        0.2,
        0.2,
        0.2
    ],
    arrayRuleWidth: [
        0.04,
        0.04,
        0.04
    ],
    fboxsep: [
        0.3,
        0.3,
        0.3
    ],
    fboxrule: [
        0.04,
        0.04,
        0.04
    ]
};
var extraCharacterMap = {
    'Å': 'A',
    'Ð': 'D',
    'Þ': 'o',
    'å': 'a',
    'ð': 'd',
    'þ': 'o',
    'А': 'A',
    'Б': 'B',
    'В': 'B',
    'Г': 'F',
    'Д': 'A',
    'Е': 'E',
    'Ж': 'K',
    'З': '3',
    'И': 'N',
    'Й': 'N',
    'К': 'K',
    'Л': 'N',
    'М': 'M',
    'Н': 'H',
    'О': 'O',
    'П': 'N',
    'Р': 'P',
    'С': 'C',
    'Т': 'T',
    'У': 'y',
    'Ф': 'O',
    'Х': 'X',
    'Ц': 'U',
    'Ч': 'h',
    'Ш': 'W',
    'Щ': 'W',
    'Ъ': 'B',
    'Ы': 'X',
    'Ь': 'B',
    'Э': '3',
    'Ю': 'X',
    'Я': 'R',
    'а': 'a',
    'б': 'b',
    'в': 'a',
    'г': 'r',
    'д': 'y',
    'е': 'e',
    'ж': 'm',
    'з': 'e',
    'и': 'n',
    'й': 'n',
    'к': 'n',
    'л': 'n',
    'м': 'm',
    'н': 'n',
    'о': 'o',
    'п': 'n',
    'р': 'p',
    'с': 'c',
    'т': 'o',
    'у': 'y',
    'ф': 'b',
    'х': 'x',
    'ц': 'n',
    'ч': 'n',
    'ш': 'w',
    'щ': 'w',
    'ъ': 'a',
    'ы': 'm',
    'ь': 'a',
    'э': 'e',
    'ю': 'm',
    'я': 'r'
};
function setFontMetrics(fontName, metrics) {
    fontMetricsData[fontName] = metrics;
}
function getCharacterMetrics(character, font, mode) {
    if (!fontMetricsData[font]) {
        throw new Error("Font metrics not found for font: " + font + ".");
    }
    var ch = character.charCodeAt(0);
    var metrics = fontMetricsData[font][ch];
    if (!metrics && character[0] in extraCharacterMap) {
        ch = extraCharacterMap[character[0]].charCodeAt(0);
        metrics = fontMetricsData[font][ch];
    }
    if (!metrics && mode === 'text') {
        if (supportedCodepoint(ch)) {
            metrics = fontMetricsData[font][77];
        }
    }
    if (metrics) {
        return {
            depth: metrics[0],
            height: metrics[1],
            italic: metrics[2],
            skew: metrics[3],
            width: metrics[4]
        };
    }
}
var fontMetricsBySizeIndex = {};
function getGlobalMetrics(size) {
    var sizeIndex;
    if (size >= 5) {
        sizeIndex = 0;
    } else if (size >= 3) {
        sizeIndex = 1;
    } else {
        sizeIndex = 2;
    }
    if (!fontMetricsBySizeIndex[sizeIndex]) {
        var metrics = fontMetricsBySizeIndex[sizeIndex] = {
            cssEmPerMu: sigmasAndXis.quad[sizeIndex] / 18
        };
        for(var key in sigmasAndXis){
            if (sigmasAndXis.hasOwnProperty(key)) {
                metrics[key] = sigmasAndXis[key][sizeIndex];
            }
        }
    }
    return fontMetricsBySizeIndex[sizeIndex];
}
var sizeStyleMap = [
    [
        1,
        1,
        1
    ],
    [
        2,
        1,
        1
    ],
    [
        3,
        1,
        1
    ],
    [
        4,
        2,
        1
    ],
    [
        5,
        2,
        1
    ],
    [
        6,
        3,
        1
    ],
    [
        7,
        4,
        2
    ],
    [
        8,
        6,
        3
    ],
    [
        9,
        7,
        6
    ],
    [
        10,
        8,
        7
    ],
    [
        11,
        10,
        9
    ]
];
var sizeMultipliers = [
    0.5,
    0.6,
    0.7,
    0.8,
    0.9,
    1.0,
    1.2,
    1.44,
    1.728,
    2.074,
    2.488
];
var sizeAtStyle = function sizeAtStyle(size, style) {
    return style.size < 2 ? size : sizeStyleMap[size - 1][style.size - 1];
};
class Options {
    constructor(data){
        this.style = void 0;
        this.color = void 0;
        this.size = void 0;
        this.textSize = void 0;
        this.phantom = void 0;
        this.font = void 0;
        this.fontFamily = void 0;
        this.fontWeight = void 0;
        this.fontShape = void 0;
        this.sizeMultiplier = void 0;
        this.maxSize = void 0;
        this.minRuleThickness = void 0;
        this._fontMetrics = void 0;
        this.style = data.style;
        this.color = data.color;
        this.size = data.size || Options.BASESIZE;
        this.textSize = data.textSize || this.size;
        this.phantom = !!data.phantom;
        this.font = data.font || "";
        this.fontFamily = data.fontFamily || "";
        this.fontWeight = data.fontWeight || '';
        this.fontShape = data.fontShape || '';
        this.sizeMultiplier = sizeMultipliers[this.size - 1];
        this.maxSize = data.maxSize;
        this.minRuleThickness = data.minRuleThickness;
        this._fontMetrics = undefined;
    }
    extend(extension) {
        var data = {
            style: this.style,
            size: this.size,
            textSize: this.textSize,
            color: this.color,
            phantom: this.phantom,
            font: this.font,
            fontFamily: this.fontFamily,
            fontWeight: this.fontWeight,
            fontShape: this.fontShape,
            maxSize: this.maxSize,
            minRuleThickness: this.minRuleThickness
        };
        for(var key in extension){
            if (extension.hasOwnProperty(key)) {
                data[key] = extension[key];
            }
        }
        return new Options(data);
    }
    havingStyle(style) {
        if (this.style === style) {
            return this;
        } else {
            return this.extend({
                style: style,
                size: sizeAtStyle(this.textSize, style)
            });
        }
    }
    havingCrampedStyle() {
        return this.havingStyle(this.style.cramp());
    }
    havingSize(size) {
        if (this.size === size && this.textSize === size) {
            return this;
        } else {
            return this.extend({
                style: this.style.text(),
                size: size,
                textSize: size,
                sizeMultiplier: sizeMultipliers[size - 1]
            });
        }
    }
    havingBaseStyle(style) {
        style = style || this.style.text();
        var wantSize = sizeAtStyle(Options.BASESIZE, style);
        if (this.size === wantSize && this.textSize === Options.BASESIZE && this.style === style) {
            return this;
        } else {
            return this.extend({
                style: style,
                size: wantSize
            });
        }
    }
    havingBaseSizing() {
        var size;
        switch(this.style.id){
            case 4:
            case 5:
                size = 3;
                break;
            case 6:
            case 7:
                size = 1;
                break;
            default:
                size = 6;
        }
        return this.extend({
            style: this.style.text(),
            size: size
        });
    }
    withColor(color) {
        return this.extend({
            color: color
        });
    }
    withPhantom() {
        return this.extend({
            phantom: true
        });
    }
    withFont(font) {
        return this.extend({
            font
        });
    }
    withTextFontFamily(fontFamily) {
        return this.extend({
            fontFamily,
            font: ""
        });
    }
    withTextFontWeight(fontWeight) {
        return this.extend({
            fontWeight,
            font: ""
        });
    }
    withTextFontShape(fontShape) {
        return this.extend({
            fontShape,
            font: ""
        });
    }
    sizingClasses(oldOptions) {
        if (oldOptions.size !== this.size) {
            return [
                "sizing",
                "reset-size" + oldOptions.size,
                "size" + this.size
            ];
        } else {
            return [];
        }
    }
    baseSizingClasses() {
        if (this.size !== Options.BASESIZE) {
            return [
                "sizing",
                "reset-size" + this.size,
                "size" + Options.BASESIZE
            ];
        } else {
            return [];
        }
    }
    fontMetrics() {
        if (!this._fontMetrics) {
            this._fontMetrics = getGlobalMetrics(this.size);
        }
        return this._fontMetrics;
    }
    getColor() {
        if (this.phantom) {
            return "transparent";
        } else {
            return this.color;
        }
    }
}
Options.BASESIZE = 6;
var ptPerUnit = {
    "pt": 1,
    "mm": 7227 / 2540,
    "cm": 7227 / 254,
    "in": 72.27,
    "bp": 803 / 800,
    "pc": 12,
    "dd": 1238 / 1157,
    "cc": 14856 / 1157,
    "nd": 685 / 642,
    "nc": 1370 / 107,
    "sp": 1 / 65536,
    "px": 803 / 800
};
var relativeUnit = {
    "ex": true,
    "em": true,
    "mu": true
};
var validUnit = function validUnit(unit) {
    if (typeof unit !== "string") {
        unit = unit.unit;
    }
    return unit in ptPerUnit || unit in relativeUnit || unit === "ex";
};
var calculateSize = function calculateSize(sizeValue, options) {
    var scale;
    if (sizeValue.unit in ptPerUnit) {
        scale = ptPerUnit[sizeValue.unit] / options.fontMetrics().ptPerEm / options.sizeMultiplier;
    } else if (sizeValue.unit === "mu") {
        scale = options.fontMetrics().cssEmPerMu;
    } else {
        var unitOptions;
        if (options.style.isTight()) {
            unitOptions = options.havingStyle(options.style.text());
        } else {
            unitOptions = options;
        }
        if (sizeValue.unit === "ex") {
            scale = unitOptions.fontMetrics().xHeight;
        } else if (sizeValue.unit === "em") {
            scale = unitOptions.fontMetrics().quad;
        } else {
            throw new ParseError("Invalid unit: '" + sizeValue.unit + "'");
        }
        if (unitOptions !== options) {
            scale *= unitOptions.sizeMultiplier / options.sizeMultiplier;
        }
    }
    return Math.min(sizeValue.number * scale, options.maxSize);
};
var makeEm = function makeEm(n) {
    return +n.toFixed(4) + "em";
};
var createClass = function createClass(classes) {
    return classes.filter((cls)=>cls).join(" ");
};
var initNode = function initNode(classes, options, style) {
    this.classes = classes || [];
    this.attributes = {};
    this.height = 0;
    this.depth = 0;
    this.maxFontSize = 0;
    this.style = style || {};
    if (options) {
        if (options.style.isTight()) {
            this.classes.push("mtight");
        }
        var color = options.getColor();
        if (color) {
            this.style.color = color;
        }
    }
};
var toNode = function toNode(tagName) {
    var node = document.createElement(tagName);
    node.className = createClass(this.classes);
    for(var style in this.style){
        if (this.style.hasOwnProperty(style)) {
            node.style[style] = this.style[style];
        }
    }
    for(var attr in this.attributes){
        if (this.attributes.hasOwnProperty(attr)) {
            node.setAttribute(attr, this.attributes[attr]);
        }
    }
    for(var i = 0; i < this.children.length; i++){
        node.appendChild(this.children[i].toNode());
    }
    return node;
};
var toMarkup = function toMarkup(tagName) {
    var markup = "<" + tagName;
    if (this.classes.length) {
        markup += " class=\"" + utils.escape(createClass(this.classes)) + "\"";
    }
    var styles = "";
    for(var style in this.style){
        if (this.style.hasOwnProperty(style)) {
            styles += utils.hyphenate(style) + ":" + this.style[style] + ";";
        }
    }
    if (styles) {
        markup += " style=\"" + utils.escape(styles) + "\"";
    }
    for(var attr in this.attributes){
        if (this.attributes.hasOwnProperty(attr)) {
            markup += " " + attr + "=\"" + utils.escape(this.attributes[attr]) + "\"";
        }
    }
    markup += ">";
    for(var i = 0; i < this.children.length; i++){
        markup += this.children[i].toMarkup();
    }
    markup += "</" + tagName + ">";
    return markup;
};
class Span {
    constructor(classes, children, options, style){
        this.children = void 0;
        this.attributes = void 0;
        this.classes = void 0;
        this.height = void 0;
        this.depth = void 0;
        this.width = void 0;
        this.maxFontSize = void 0;
        this.style = void 0;
        initNode.call(this, classes, options, style);
        this.children = children || [];
    }
    setAttribute(attribute, value) {
        this.attributes[attribute] = value;
    }
    hasClass(className) {
        return utils.contains(this.classes, className);
    }
    toNode() {
        return toNode.call(this, "span");
    }
    toMarkup() {
        return toMarkup.call(this, "span");
    }
}
class Anchor {
    constructor(href, classes, children, options){
        this.children = void 0;
        this.attributes = void 0;
        this.classes = void 0;
        this.height = void 0;
        this.depth = void 0;
        this.maxFontSize = void 0;
        this.style = void 0;
        initNode.call(this, classes, options);
        this.children = children || [];
        this.setAttribute('href', href);
    }
    setAttribute(attribute, value) {
        this.attributes[attribute] = value;
    }
    hasClass(className) {
        return utils.contains(this.classes, className);
    }
    toNode() {
        return toNode.call(this, "a");
    }
    toMarkup() {
        return toMarkup.call(this, "a");
    }
}
class Img {
    constructor(src, alt, style){
        this.src = void 0;
        this.alt = void 0;
        this.classes = void 0;
        this.height = void 0;
        this.depth = void 0;
        this.maxFontSize = void 0;
        this.style = void 0;
        this.alt = alt;
        this.src = src;
        this.classes = [
            "mord"
        ];
        this.style = style;
    }
    hasClass(className) {
        return utils.contains(this.classes, className);
    }
    toNode() {
        var node = document.createElement("img");
        node.src = this.src;
        node.alt = this.alt;
        node.className = "mord";
        for(var style in this.style){
            if (this.style.hasOwnProperty(style)) {
                node.style[style] = this.style[style];
            }
        }
        return node;
    }
    toMarkup() {
        var markup = "<img  src='" + this.src + " 'alt='" + this.alt + "' ";
        var styles = "";
        for(var style in this.style){
            if (this.style.hasOwnProperty(style)) {
                styles += utils.hyphenate(style) + ":" + this.style[style] + ";";
            }
        }
        if (styles) {
            markup += " style=\"" + utils.escape(styles) + "\"";
        }
        markup += "'/>";
        return markup;
    }
}
var iCombinations = {
    'î': '\u0131\u0302',
    'ï': '\u0131\u0308',
    'í': '\u0131\u0301',
    'ì': '\u0131\u0300'
};
class SymbolNode {
    constructor(text, height, depth, italic, skew, width, classes, style){
        this.text = void 0;
        this.height = void 0;
        this.depth = void 0;
        this.italic = void 0;
        this.skew = void 0;
        this.width = void 0;
        this.maxFontSize = void 0;
        this.classes = void 0;
        this.style = void 0;
        this.text = text;
        this.height = height || 0;
        this.depth = depth || 0;
        this.italic = italic || 0;
        this.skew = skew || 0;
        this.width = width || 0;
        this.classes = classes || [];
        this.style = style || {};
        this.maxFontSize = 0;
        var script = scriptFromCodepoint(this.text.charCodeAt(0));
        if (script) {
            this.classes.push(script + "_fallback");
        }
        if (/[îïíì]/.test(this.text)) {
            this.text = iCombinations[this.text];
        }
    }
    hasClass(className) {
        return utils.contains(this.classes, className);
    }
    toNode() {
        var node = document.createTextNode(this.text);
        var span = null;
        if (this.italic > 0) {
            span = document.createElement("span");
            span.style.marginRight = makeEm(this.italic);
        }
        if (this.classes.length > 0) {
            span = span || document.createElement("span");
            span.className = createClass(this.classes);
        }
        for(var style in this.style){
            if (this.style.hasOwnProperty(style)) {
                span = span || document.createElement("span");
                span.style[style] = this.style[style];
            }
        }
        if (span) {
            span.appendChild(node);
            return span;
        } else {
            return node;
        }
    }
    toMarkup() {
        var needsSpan = false;
        var markup = "<span";
        if (this.classes.length) {
            needsSpan = true;
            markup += " class=\"";
            markup += utils.escape(createClass(this.classes));
            markup += "\"";
        }
        var styles = "";
        if (this.italic > 0) {
            styles += "margin-right:" + this.italic + "em;";
        }
        for(var style in this.style){
            if (this.style.hasOwnProperty(style)) {
                styles += utils.hyphenate(style) + ":" + this.style[style] + ";";
            }
        }
        if (styles) {
            needsSpan = true;
            markup += " style=\"" + utils.escape(styles) + "\"";
        }
        var escaped = utils.escape(this.text);
        if (needsSpan) {
            markup += ">";
            markup += escaped;
            markup += "</span>";
            return markup;
        } else {
            return escaped;
        }
    }
}
class SvgNode {
    constructor(children, attributes){
        this.children = void 0;
        this.attributes = void 0;
        this.children = children || [];
        this.attributes = attributes || {};
    }
    toNode() {
        var svgNS = "http://www.w3.org/2000/svg";
        var node = document.createElementNS(svgNS, "svg");
        for(var attr in this.attributes){
            if (Object.prototype.hasOwnProperty.call(this.attributes, attr)) {
                node.setAttribute(attr, this.attributes[attr]);
            }
        }
        for(var i = 0; i < this.children.length; i++){
            node.appendChild(this.children[i].toNode());
        }
        return node;
    }
    toMarkup() {
        var markup = "<svg xmlns=\"http://www.w3.org/2000/svg\"";
        for(var attr in this.attributes){
            if (Object.prototype.hasOwnProperty.call(this.attributes, attr)) {
                markup += " " + attr + "='" + this.attributes[attr] + "'";
            }
        }
        markup += ">";
        for(var i = 0; i < this.children.length; i++){
            markup += this.children[i].toMarkup();
        }
        markup += "</svg>";
        return markup;
    }
}
class PathNode {
    constructor(pathName, alternate){
        this.pathName = void 0;
        this.alternate = void 0;
        this.pathName = pathName;
        this.alternate = alternate;
    }
    toNode() {
        var svgNS = "http://www.w3.org/2000/svg";
        var node = document.createElementNS(svgNS, "path");
        if (this.alternate) {
            node.setAttribute("d", this.alternate);
        } else {
            node.setAttribute("d", path[this.pathName]);
        }
        return node;
    }
    toMarkup() {
        if (this.alternate) {
            return "<path d='" + this.alternate + "'/>";
        } else {
            return "<path d='" + path[this.pathName] + "'/>";
        }
    }
}
class LineNode {
    constructor(attributes){
        this.attributes = void 0;
        this.attributes = attributes || {};
    }
    toNode() {
        var svgNS = "http://www.w3.org/2000/svg";
        var node = document.createElementNS(svgNS, "line");
        for(var attr in this.attributes){
            if (Object.prototype.hasOwnProperty.call(this.attributes, attr)) {
                node.setAttribute(attr, this.attributes[attr]);
            }
        }
        return node;
    }
    toMarkup() {
        var markup = "<line";
        for(var attr in this.attributes){
            if (Object.prototype.hasOwnProperty.call(this.attributes, attr)) {
                markup += " " + attr + "='" + this.attributes[attr] + "'";
            }
        }
        markup += "/>";
        return markup;
    }
}
function assertSymbolDomNode(group) {
    if (group instanceof SymbolNode) {
        return group;
    } else {
        throw new Error("Expected symbolNode but got " + String(group) + ".");
    }
}
function assertSpan(group) {
    if (group instanceof Span) {
        return group;
    } else {
        throw new Error("Expected span<HtmlDomNode> but got " + String(group) + ".");
    }
}
var ATOMS = {
    "bin": 1,
    "close": 1,
    "inner": 1,
    "open": 1,
    "punct": 1,
    "rel": 1
};
var NON_ATOMS = {
    "accent-token": 1,
    "mathord": 1,
    "op-token": 1,
    "spacing": 1,
    "textord": 1
};
var symbols = {
    "math": {},
    "text": {}
};
function defineSymbol(mode, font, group, replace, name, acceptUnicodeChar) {
    symbols[mode][name] = {
        font,
        group,
        replace
    };
    if (acceptUnicodeChar && replace) {
        symbols[mode][replace] = symbols[mode][name];
    }
}
var math = "math";
var text = "text";
var main = "main";
var ams = "ams";
var accent = "accent-token";
var bin = "bin";
var close = "close";
var inner = "inner";
var mathord = "mathord";
var op = "op-token";
var open = "open";
var punct = "punct";
var rel = "rel";
var spacing = "spacing";
var textord = "textord";
defineSymbol(math, main, rel, "\u2261", "\\equiv", true);
defineSymbol(math, main, rel, "\u227a", "\\prec", true);
defineSymbol(math, main, rel, "\u227b", "\\succ", true);
defineSymbol(math, main, rel, "\u223c", "\\sim", true);
defineSymbol(math, main, rel, "\u22a5", "\\perp");
defineSymbol(math, main, rel, "\u2aaf", "\\preceq", true);
defineSymbol(math, main, rel, "\u2ab0", "\\succeq", true);
defineSymbol(math, main, rel, "\u2243", "\\simeq", true);
defineSymbol(math, main, rel, "\u2223", "\\mid", true);
defineSymbol(math, main, rel, "\u226a", "\\ll", true);
defineSymbol(math, main, rel, "\u226b", "\\gg", true);
defineSymbol(math, main, rel, "\u224d", "\\asymp", true);
defineSymbol(math, main, rel, "\u2225", "\\parallel");
defineSymbol(math, main, rel, "\u22c8", "\\bowtie", true);
defineSymbol(math, main, rel, "\u2323", "\\smile", true);
defineSymbol(math, main, rel, "\u2291", "\\sqsubseteq", true);
defineSymbol(math, main, rel, "\u2292", "\\sqsupseteq", true);
defineSymbol(math, main, rel, "\u2250", "\\doteq", true);
defineSymbol(math, main, rel, "\u2322", "\\frown", true);
defineSymbol(math, main, rel, "\u220b", "\\ni", true);
defineSymbol(math, main, rel, "\u221d", "\\propto", true);
defineSymbol(math, main, rel, "\u22a2", "\\vdash", true);
defineSymbol(math, main, rel, "\u22a3", "\\dashv", true);
defineSymbol(math, main, rel, "\u220b", "\\owns");
defineSymbol(math, main, punct, "\u002e", "\\ldotp");
defineSymbol(math, main, punct, "\u22c5", "\\cdotp");
defineSymbol(math, main, textord, "\u0023", "\\#");
defineSymbol(text, main, textord, "\u0023", "\\#");
defineSymbol(math, main, textord, "\u0026", "\\&");
defineSymbol(text, main, textord, "\u0026", "\\&");
defineSymbol(math, main, textord, "\u2135", "\\aleph", true);
defineSymbol(math, main, textord, "\u2200", "\\forall", true);
defineSymbol(math, main, textord, "\u210f", "\\hbar", true);
defineSymbol(math, main, textord, "\u2203", "\\exists", true);
defineSymbol(math, main, textord, "\u2207", "\\nabla", true);
defineSymbol(math, main, textord, "\u266d", "\\flat", true);
defineSymbol(math, main, textord, "\u2113", "\\ell", true);
defineSymbol(math, main, textord, "\u266e", "\\natural", true);
defineSymbol(math, main, textord, "\u2663", "\\clubsuit", true);
defineSymbol(math, main, textord, "\u2118", "\\wp", true);
defineSymbol(math, main, textord, "\u266f", "\\sharp", true);
defineSymbol(math, main, textord, "\u2662", "\\diamondsuit", true);
defineSymbol(math, main, textord, "\u211c", "\\Re", true);
defineSymbol(math, main, textord, "\u2661", "\\heartsuit", true);
defineSymbol(math, main, textord, "\u2111", "\\Im", true);
defineSymbol(math, main, textord, "\u2660", "\\spadesuit", true);
defineSymbol(math, main, textord, "\u00a7", "\\S", true);
defineSymbol(text, main, textord, "\u00a7", "\\S");
defineSymbol(math, main, textord, "\u00b6", "\\P", true);
defineSymbol(text, main, textord, "\u00b6", "\\P");
defineSymbol(math, main, textord, "\u2020", "\\dag");
defineSymbol(text, main, textord, "\u2020", "\\dag");
defineSymbol(text, main, textord, "\u2020", "\\textdagger");
defineSymbol(math, main, textord, "\u2021", "\\ddag");
defineSymbol(text, main, textord, "\u2021", "\\ddag");
defineSymbol(text, main, textord, "\u2021", "\\textdaggerdbl");
defineSymbol(math, main, close, "\u23b1", "\\rmoustache", true);
defineSymbol(math, main, open, "\u23b0", "\\lmoustache", true);
defineSymbol(math, main, close, "\u27ef", "\\rgroup", true);
defineSymbol(math, main, open, "\u27ee", "\\lgroup", true);
defineSymbol(math, main, bin, "\u2213", "\\mp", true);
defineSymbol(math, main, bin, "\u2296", "\\ominus", true);
defineSymbol(math, main, bin, "\u228e", "\\uplus", true);
defineSymbol(math, main, bin, "\u2293", "\\sqcap", true);
defineSymbol(math, main, bin, "\u2217", "\\ast");
defineSymbol(math, main, bin, "\u2294", "\\sqcup", true);
defineSymbol(math, main, bin, "\u25ef", "\\bigcirc", true);
defineSymbol(math, main, bin, "\u2219", "\\bullet", true);
defineSymbol(math, main, bin, "\u2021", "\\ddagger");
defineSymbol(math, main, bin, "\u2240", "\\wr", true);
defineSymbol(math, main, bin, "\u2a3f", "\\amalg");
defineSymbol(math, main, bin, "\u0026", "\\And");
defineSymbol(math, main, rel, "\u27f5", "\\longleftarrow", true);
defineSymbol(math, main, rel, "\u21d0", "\\Leftarrow", true);
defineSymbol(math, main, rel, "\u27f8", "\\Longleftarrow", true);
defineSymbol(math, main, rel, "\u27f6", "\\longrightarrow", true);
defineSymbol(math, main, rel, "\u21d2", "\\Rightarrow", true);
defineSymbol(math, main, rel, "\u27f9", "\\Longrightarrow", true);
defineSymbol(math, main, rel, "\u2194", "\\leftrightarrow", true);
defineSymbol(math, main, rel, "\u27f7", "\\longleftrightarrow", true);
defineSymbol(math, main, rel, "\u21d4", "\\Leftrightarrow", true);
defineSymbol(math, main, rel, "\u27fa", "\\Longleftrightarrow", true);
defineSymbol(math, main, rel, "\u21a6", "\\mapsto", true);
defineSymbol(math, main, rel, "\u27fc", "\\longmapsto", true);
defineSymbol(math, main, rel, "\u2197", "\\nearrow", true);
defineSymbol(math, main, rel, "\u21a9", "\\hookleftarrow", true);
defineSymbol(math, main, rel, "\u21aa", "\\hookrightarrow", true);
defineSymbol(math, main, rel, "\u2198", "\\searrow", true);
defineSymbol(math, main, rel, "\u21bc", "\\leftharpoonup", true);
defineSymbol(math, main, rel, "\u21c0", "\\rightharpoonup", true);
defineSymbol(math, main, rel, "\u2199", "\\swarrow", true);
defineSymbol(math, main, rel, "\u21bd", "\\leftharpoondown", true);
defineSymbol(math, main, rel, "\u21c1", "\\rightharpoondown", true);
defineSymbol(math, main, rel, "\u2196", "\\nwarrow", true);
defineSymbol(math, main, rel, "\u21cc", "\\rightleftharpoons", true);
defineSymbol(math, ams, rel, "\u226e", "\\nless", true);
defineSymbol(math, ams, rel, "\ue010", "\\@nleqslant");
defineSymbol(math, ams, rel, "\ue011", "\\@nleqq");
defineSymbol(math, ams, rel, "\u2a87", "\\lneq", true);
defineSymbol(math, ams, rel, "\u2268", "\\lneqq", true);
defineSymbol(math, ams, rel, "\ue00c", "\\@lvertneqq");
defineSymbol(math, ams, rel, "\u22e6", "\\lnsim", true);
defineSymbol(math, ams, rel, "\u2a89", "\\lnapprox", true);
defineSymbol(math, ams, rel, "\u2280", "\\nprec", true);
defineSymbol(math, ams, rel, "\u22e0", "\\npreceq", true);
defineSymbol(math, ams, rel, "\u22e8", "\\precnsim", true);
defineSymbol(math, ams, rel, "\u2ab9", "\\precnapprox", true);
defineSymbol(math, ams, rel, "\u2241", "\\nsim", true);
defineSymbol(math, ams, rel, "\ue006", "\\@nshortmid");
defineSymbol(math, ams, rel, "\u2224", "\\nmid", true);
defineSymbol(math, ams, rel, "\u22ac", "\\nvdash", true);
defineSymbol(math, ams, rel, "\u22ad", "\\nvDash", true);
defineSymbol(math, ams, rel, "\u22ea", "\\ntriangleleft");
defineSymbol(math, ams, rel, "\u22ec", "\\ntrianglelefteq", true);
defineSymbol(math, ams, rel, "\u228a", "\\subsetneq", true);
defineSymbol(math, ams, rel, "\ue01a", "\\@varsubsetneq");
defineSymbol(math, ams, rel, "\u2acb", "\\subsetneqq", true);
defineSymbol(math, ams, rel, "\ue017", "\\@varsubsetneqq");
defineSymbol(math, ams, rel, "\u226f", "\\ngtr", true);
defineSymbol(math, ams, rel, "\ue00f", "\\@ngeqslant");
defineSymbol(math, ams, rel, "\ue00e", "\\@ngeqq");
defineSymbol(math, ams, rel, "\u2a88", "\\gneq", true);
defineSymbol(math, ams, rel, "\u2269", "\\gneqq", true);
defineSymbol(math, ams, rel, "\ue00d", "\\@gvertneqq");
defineSymbol(math, ams, rel, "\u22e7", "\\gnsim", true);
defineSymbol(math, ams, rel, "\u2a8a", "\\gnapprox", true);
defineSymbol(math, ams, rel, "\u2281", "\\nsucc", true);
defineSymbol(math, ams, rel, "\u22e1", "\\nsucceq", true);
defineSymbol(math, ams, rel, "\u22e9", "\\succnsim", true);
defineSymbol(math, ams, rel, "\u2aba", "\\succnapprox", true);
defineSymbol(math, ams, rel, "\u2246", "\\ncong", true);
defineSymbol(math, ams, rel, "\ue007", "\\@nshortparallel");
defineSymbol(math, ams, rel, "\u2226", "\\nparallel", true);
defineSymbol(math, ams, rel, "\u22af", "\\nVDash", true);
defineSymbol(math, ams, rel, "\u22eb", "\\ntriangleright");
defineSymbol(math, ams, rel, "\u22ed", "\\ntrianglerighteq", true);
defineSymbol(math, ams, rel, "\ue018", "\\@nsupseteqq");
defineSymbol(math, ams, rel, "\u228b", "\\supsetneq", true);
defineSymbol(math, ams, rel, "\ue01b", "\\@varsupsetneq");
defineSymbol(math, ams, rel, "\u2acc", "\\supsetneqq", true);
defineSymbol(math, ams, rel, "\ue019", "\\@varsupsetneqq");
defineSymbol(math, ams, rel, "\u22ae", "\\nVdash", true);
defineSymbol(math, ams, rel, "\u2ab5", "\\precneqq", true);
defineSymbol(math, ams, rel, "\u2ab6", "\\succneqq", true);
defineSymbol(math, ams, rel, "\ue016", "\\@nsubseteqq");
defineSymbol(math, ams, bin, "\u22b4", "\\unlhd");
defineSymbol(math, ams, bin, "\u22b5", "\\unrhd");
defineSymbol(math, ams, rel, "\u219a", "\\nleftarrow", true);
defineSymbol(math, ams, rel, "\u219b", "\\nrightarrow", true);
defineSymbol(math, ams, rel, "\u21cd", "\\nLeftarrow", true);
defineSymbol(math, ams, rel, "\u21cf", "\\nRightarrow", true);
defineSymbol(math, ams, rel, "\u21ae", "\\nleftrightarrow", true);
defineSymbol(math, ams, rel, "\u21ce", "\\nLeftrightarrow", true);
defineSymbol(math, ams, rel, "\u25b3", "\\vartriangle");
defineSymbol(math, ams, textord, "\u210f", "\\hslash");
defineSymbol(math, ams, textord, "\u25bd", "\\triangledown");
defineSymbol(math, ams, textord, "\u25ca", "\\lozenge");
defineSymbol(math, ams, textord, "\u24c8", "\\circledS");
defineSymbol(math, ams, textord, "\u00ae", "\\circledR");
defineSymbol(text, ams, textord, "\u00ae", "\\circledR");
defineSymbol(math, ams, textord, "\u2221", "\\measuredangle", true);
defineSymbol(math, ams, textord, "\u2204", "\\nexists");
defineSymbol(math, ams, textord, "\u2127", "\\mho");
defineSymbol(math, ams, textord, "\u2132", "\\Finv", true);
defineSymbol(math, ams, textord, "\u2141", "\\Game", true);
defineSymbol(math, ams, textord, "\u2035", "\\backprime");
defineSymbol(math, ams, textord, "\u25b2", "\\blacktriangle");
defineSymbol(math, ams, textord, "\u25bc", "\\blacktriangledown");
defineSymbol(math, ams, textord, "\u25a0", "\\blacksquare");
defineSymbol(math, ams, textord, "\u29eb", "\\blacklozenge");
defineSymbol(math, ams, textord, "\u2605", "\\bigstar");
defineSymbol(math, ams, textord, "\u2222", "\\sphericalangle", true);
defineSymbol(math, ams, textord, "\u2201", "\\complement", true);
defineSymbol(math, ams, textord, "\u00f0", "\\eth", true);
defineSymbol(text, main, textord, "\u00f0", "\u00f0");
defineSymbol(math, ams, textord, "\u2571", "\\diagup");
defineSymbol(math, ams, textord, "\u2572", "\\diagdown");
defineSymbol(math, ams, textord, "\u25a1", "\\square");
defineSymbol(math, ams, textord, "\u25a1", "\\Box");
defineSymbol(math, ams, textord, "\u25ca", "\\Diamond");
defineSymbol(math, ams, textord, "\u00a5", "\\yen", true);
defineSymbol(text, ams, textord, "\u00a5", "\\yen", true);
defineSymbol(math, ams, textord, "\u2713", "\\checkmark", true);
defineSymbol(text, ams, textord, "\u2713", "\\checkmark");
defineSymbol(math, ams, textord, "\u2136", "\\beth", true);
defineSymbol(math, ams, textord, "\u2138", "\\daleth", true);
defineSymbol(math, ams, textord, "\u2137", "\\gimel", true);
defineSymbol(math, ams, textord, "\u03dd", "\\digamma", true);
defineSymbol(math, ams, textord, "\u03f0", "\\varkappa");
defineSymbol(math, ams, open, "\u250c", "\\@ulcorner", true);
defineSymbol(math, ams, close, "\u2510", "\\@urcorner", true);
defineSymbol(math, ams, open, "\u2514", "\\@llcorner", true);
defineSymbol(math, ams, close, "\u2518", "\\@lrcorner", true);
defineSymbol(math, ams, rel, "\u2266", "\\leqq", true);
defineSymbol(math, ams, rel, "\u2a7d", "\\leqslant", true);
defineSymbol(math, ams, rel, "\u2a95", "\\eqslantless", true);
defineSymbol(math, ams, rel, "\u2272", "\\lesssim", true);
defineSymbol(math, ams, rel, "\u2a85", "\\lessapprox", true);
defineSymbol(math, ams, rel, "\u224a", "\\approxeq", true);
defineSymbol(math, ams, bin, "\u22d6", "\\lessdot");
defineSymbol(math, ams, rel, "\u22d8", "\\lll", true);
defineSymbol(math, ams, rel, "\u2276", "\\lessgtr", true);
defineSymbol(math, ams, rel, "\u22da", "\\lesseqgtr", true);
defineSymbol(math, ams, rel, "\u2a8b", "\\lesseqqgtr", true);
defineSymbol(math, ams, rel, "\u2251", "\\doteqdot");
defineSymbol(math, ams, rel, "\u2253", "\\risingdotseq", true);
defineSymbol(math, ams, rel, "\u2252", "\\fallingdotseq", true);
defineSymbol(math, ams, rel, "\u223d", "\\backsim", true);
defineSymbol(math, ams, rel, "\u22cd", "\\backsimeq", true);
defineSymbol(math, ams, rel, "\u2ac5", "\\subseteqq", true);
defineSymbol(math, ams, rel, "\u22d0", "\\Subset", true);
defineSymbol(math, ams, rel, "\u228f", "\\sqsubset", true);
defineSymbol(math, ams, rel, "\u227c", "\\preccurlyeq", true);
defineSymbol(math, ams, rel, "\u22de", "\\curlyeqprec", true);
defineSymbol(math, ams, rel, "\u227e", "\\precsim", true);
defineSymbol(math, ams, rel, "\u2ab7", "\\precapprox", true);
defineSymbol(math, ams, rel, "\u22b2", "\\vartriangleleft");
defineSymbol(math, ams, rel, "\u22b4", "\\trianglelefteq");
defineSymbol(math, ams, rel, "\u22a8", "\\vDash", true);
defineSymbol(math, ams, rel, "\u22aa", "\\Vvdash", true);
defineSymbol(math, ams, rel, "\u2323", "\\smallsmile");
defineSymbol(math, ams, rel, "\u2322", "\\smallfrown");
defineSymbol(math, ams, rel, "\u224f", "\\bumpeq", true);
defineSymbol(math, ams, rel, "\u224e", "\\Bumpeq", true);
defineSymbol(math, ams, rel, "\u2267", "\\geqq", true);
defineSymbol(math, ams, rel, "\u2a7e", "\\geqslant", true);
defineSymbol(math, ams, rel, "\u2a96", "\\eqslantgtr", true);
defineSymbol(math, ams, rel, "\u2273", "\\gtrsim", true);
defineSymbol(math, ams, rel, "\u2a86", "\\gtrapprox", true);
defineSymbol(math, ams, bin, "\u22d7", "\\gtrdot");
defineSymbol(math, ams, rel, "\u22d9", "\\ggg", true);
defineSymbol(math, ams, rel, "\u2277", "\\gtrless", true);
defineSymbol(math, ams, rel, "\u22db", "\\gtreqless", true);
defineSymbol(math, ams, rel, "\u2a8c", "\\gtreqqless", true);
defineSymbol(math, ams, rel, "\u2256", "\\eqcirc", true);
defineSymbol(math, ams, rel, "\u2257", "\\circeq", true);
defineSymbol(math, ams, rel, "\u225c", "\\triangleq", true);
defineSymbol(math, ams, rel, "\u223c", "\\thicksim");
defineSymbol(math, ams, rel, "\u2248", "\\thickapprox");
defineSymbol(math, ams, rel, "\u2ac6", "\\supseteqq", true);
defineSymbol(math, ams, rel, "\u22d1", "\\Supset", true);
defineSymbol(math, ams, rel, "\u2290", "\\sqsupset", true);
defineSymbol(math, ams, rel, "\u227d", "\\succcurlyeq", true);
defineSymbol(math, ams, rel, "\u22df", "\\curlyeqsucc", true);
defineSymbol(math, ams, rel, "\u227f", "\\succsim", true);
defineSymbol(math, ams, rel, "\u2ab8", "\\succapprox", true);
defineSymbol(math, ams, rel, "\u22b3", "\\vartriangleright");
defineSymbol(math, ams, rel, "\u22b5", "\\trianglerighteq");
defineSymbol(math, ams, rel, "\u22a9", "\\Vdash", true);
defineSymbol(math, ams, rel, "\u2223", "\\shortmid");
defineSymbol(math, ams, rel, "\u2225", "\\shortparallel");
defineSymbol(math, ams, rel, "\u226c", "\\between", true);
defineSymbol(math, ams, rel, "\u22d4", "\\pitchfork", true);
defineSymbol(math, ams, rel, "\u221d", "\\varpropto");
defineSymbol(math, ams, rel, "\u25c0", "\\blacktriangleleft");
defineSymbol(math, ams, rel, "\u2234", "\\therefore", true);
defineSymbol(math, ams, rel, "\u220d", "\\backepsilon");
defineSymbol(math, ams, rel, "\u25b6", "\\blacktriangleright");
defineSymbol(math, ams, rel, "\u2235", "\\because", true);
defineSymbol(math, ams, rel, "\u22d8", "\\llless");
defineSymbol(math, ams, rel, "\u22d9", "\\gggtr");
defineSymbol(math, ams, bin, "\u22b2", "\\lhd");
defineSymbol(math, ams, bin, "\u22b3", "\\rhd");
defineSymbol(math, ams, rel, "\u2242", "\\eqsim", true);
defineSymbol(math, main, rel, "\u22c8", "\\Join");
defineSymbol(math, ams, rel, "\u2251", "\\Doteq", true);
defineSymbol(math, ams, bin, "\u2214", "\\dotplus", true);
defineSymbol(math, ams, bin, "\u2216", "\\smallsetminus");
defineSymbol(math, ams, bin, "\u22d2", "\\Cap", true);
defineSymbol(math, ams, bin, "\u22d3", "\\Cup", true);
defineSymbol(math, ams, bin, "\u2a5e", "\\doublebarwedge", true);
defineSymbol(math, ams, bin, "\u229f", "\\boxminus", true);
defineSymbol(math, ams, bin, "\u229e", "\\boxplus", true);
defineSymbol(math, ams, bin, "\u22c7", "\\divideontimes", true);
defineSymbol(math, ams, bin, "\u22c9", "\\ltimes", true);
defineSymbol(math, ams, bin, "\u22ca", "\\rtimes", true);
defineSymbol(math, ams, bin, "\u22cb", "\\leftthreetimes", true);
defineSymbol(math, ams, bin, "\u22cc", "\\rightthreetimes", true);
defineSymbol(math, ams, bin, "\u22cf", "\\curlywedge", true);
defineSymbol(math, ams, bin, "\u22ce", "\\curlyvee", true);
defineSymbol(math, ams, bin, "\u229d", "\\circleddash", true);
defineSymbol(math, ams, bin, "\u229b", "\\circledast", true);
defineSymbol(math, ams, bin, "\u22c5", "\\centerdot");
defineSymbol(math, ams, bin, "\u22ba", "\\intercal", true);
defineSymbol(math, ams, bin, "\u22d2", "\\doublecap");
defineSymbol(math, ams, bin, "\u22d3", "\\doublecup");
defineSymbol(math, ams, bin, "\u22a0", "\\boxtimes", true);
defineSymbol(math, ams, rel, "\u21e2", "\\dashrightarrow", true);
defineSymbol(math, ams, rel, "\u21e0", "\\dashleftarrow", true);
defineSymbol(math, ams, rel, "\u21c7", "\\leftleftarrows", true);
defineSymbol(math, ams, rel, "\u21c6", "\\leftrightarrows", true);
defineSymbol(math, ams, rel, "\u21da", "\\Lleftarrow", true);
defineSymbol(math, ams, rel, "\u219e", "\\twoheadleftarrow", true);
defineSymbol(math, ams, rel, "\u21a2", "\\leftarrowtail", true);
defineSymbol(math, ams, rel, "\u21ab", "\\looparrowleft", true);
defineSymbol(math, ams, rel, "\u21cb", "\\leftrightharpoons", true);
defineSymbol(math, ams, rel, "\u21b6", "\\curvearrowleft", true);
defineSymbol(math, ams, rel, "\u21ba", "\\circlearrowleft", true);
defineSymbol(math, ams, rel, "\u21b0", "\\Lsh", true);
defineSymbol(math, ams, rel, "\u21c8", "\\upuparrows", true);
defineSymbol(math, ams, rel, "\u21bf", "\\upharpoonleft", true);
defineSymbol(math, ams, rel, "\u21c3", "\\downharpoonleft", true);
defineSymbol(math, main, rel, "\u22b6", "\\origof", true);
defineSymbol(math, main, rel, "\u22b7", "\\imageof", true);
defineSymbol(math, ams, rel, "\u22b8", "\\multimap", true);
defineSymbol(math, ams, rel, "\u21ad", "\\leftrightsquigarrow", true);
defineSymbol(math, ams, rel, "\u21c9", "\\rightrightarrows", true);
defineSymbol(math, ams, rel, "\u21c4", "\\rightleftarrows", true);
defineSymbol(math, ams, rel, "\u21a0", "\\twoheadrightarrow", true);
defineSymbol(math, ams, rel, "\u21a3", "\\rightarrowtail", true);
defineSymbol(math, ams, rel, "\u21ac", "\\looparrowright", true);
defineSymbol(math, ams, rel, "\u21b7", "\\curvearrowright", true);
defineSymbol(math, ams, rel, "\u21bb", "\\circlearrowright", true);
defineSymbol(math, ams, rel, "\u21b1", "\\Rsh", true);
defineSymbol(math, ams, rel, "\u21ca", "\\downdownarrows", true);
defineSymbol(math, ams, rel, "\u21be", "\\upharpoonright", true);
defineSymbol(math, ams, rel, "\u21c2", "\\downharpoonright", true);
defineSymbol(math, ams, rel, "\u21dd", "\\rightsquigarrow", true);
defineSymbol(math, ams, rel, "\u21dd", "\\leadsto");
defineSymbol(math, ams, rel, "\u21db", "\\Rrightarrow", true);
defineSymbol(math, ams, rel, "\u21be", "\\restriction");
defineSymbol(math, main, textord, "\u2018", "`");
defineSymbol(math, main, textord, "$", "\\$");
defineSymbol(text, main, textord, "$", "\\$");
defineSymbol(text, main, textord, "$", "\\textdollar");
defineSymbol(math, main, textord, "%", "\\%");
defineSymbol(text, main, textord, "%", "\\%");
defineSymbol(math, main, textord, "_", "\\_");
defineSymbol(text, main, textord, "_", "\\_");
defineSymbol(text, main, textord, "_", "\\textunderscore");
defineSymbol(math, main, textord, "\u2220", "\\angle", true);
defineSymbol(math, main, textord, "\u221e", "\\infty", true);
defineSymbol(math, main, textord, "\u2032", "\\prime");
defineSymbol(math, main, textord, "\u25b3", "\\triangle");
defineSymbol(math, main, textord, "\u0393", "\\Gamma", true);
defineSymbol(math, main, textord, "\u0394", "\\Delta", true);
defineSymbol(math, main, textord, "\u0398", "\\Theta", true);
defineSymbol(math, main, textord, "\u039b", "\\Lambda", true);
defineSymbol(math, main, textord, "\u039e", "\\Xi", true);
defineSymbol(math, main, textord, "\u03a0", "\\Pi", true);
defineSymbol(math, main, textord, "\u03a3", "\\Sigma", true);
defineSymbol(math, main, textord, "\u03a5", "\\Upsilon", true);
defineSymbol(math, main, textord, "\u03a6", "\\Phi", true);
defineSymbol(math, main, textord, "\u03a8", "\\Psi", true);
defineSymbol(math, main, textord, "\u03a9", "\\Omega", true);
defineSymbol(math, main, textord, "A", "\u0391");
defineSymbol(math, main, textord, "B", "\u0392");
defineSymbol(math, main, textord, "E", "\u0395");
defineSymbol(math, main, textord, "Z", "\u0396");
defineSymbol(math, main, textord, "H", "\u0397");
defineSymbol(math, main, textord, "I", "\u0399");
defineSymbol(math, main, textord, "K", "\u039A");
defineSymbol(math, main, textord, "M", "\u039C");
defineSymbol(math, main, textord, "N", "\u039D");
defineSymbol(math, main, textord, "O", "\u039F");
defineSymbol(math, main, textord, "P", "\u03A1");
defineSymbol(math, main, textord, "T", "\u03A4");
defineSymbol(math, main, textord, "X", "\u03A7");
defineSymbol(math, main, textord, "\u00ac", "\\neg", true);
defineSymbol(math, main, textord, "\u00ac", "\\lnot");
defineSymbol(math, main, textord, "\u22a4", "\\top");
defineSymbol(math, main, textord, "\u22a5", "\\bot");
defineSymbol(math, main, textord, "\u2205", "\\emptyset");
defineSymbol(math, ams, textord, "\u2205", "\\varnothing");
defineSymbol(math, main, mathord, "\u03b1", "\\alpha", true);
defineSymbol(math, main, mathord, "\u03b2", "\\beta", true);
defineSymbol(math, main, mathord, "\u03b3", "\\gamma", true);
defineSymbol(math, main, mathord, "\u03b4", "\\delta", true);
defineSymbol(math, main, mathord, "\u03f5", "\\epsilon", true);
defineSymbol(math, main, mathord, "\u03b6", "\\zeta", true);
defineSymbol(math, main, mathord, "\u03b7", "\\eta", true);
defineSymbol(math, main, mathord, "\u03b8", "\\theta", true);
defineSymbol(math, main, mathord, "\u03b9", "\\iota", true);
defineSymbol(math, main, mathord, "\u03ba", "\\kappa", true);
defineSymbol(math, main, mathord, "\u03bb", "\\lambda", true);
defineSymbol(math, main, mathord, "\u03bc", "\\mu", true);
defineSymbol(math, main, mathord, "\u03bd", "\\nu", true);
defineSymbol(math, main, mathord, "\u03be", "\\xi", true);
defineSymbol(math, main, mathord, "\u03bf", "\\omicron", true);
defineSymbol(math, main, mathord, "\u03c0", "\\pi", true);
defineSymbol(math, main, mathord, "\u03c1", "\\rho", true);
defineSymbol(math, main, mathord, "\u03c3", "\\sigma", true);
defineSymbol(math, main, mathord, "\u03c4", "\\tau", true);
defineSymbol(math, main, mathord, "\u03c5", "\\upsilon", true);
defineSymbol(math, main, mathord, "\u03d5", "\\phi", true);
defineSymbol(math, main, mathord, "\u03c7", "\\chi", true);
defineSymbol(math, main, mathord, "\u03c8", "\\psi", true);
defineSymbol(math, main, mathord, "\u03c9", "\\omega", true);
defineSymbol(math, main, mathord, "\u03b5", "\\varepsilon", true);
defineSymbol(math, main, mathord, "\u03d1", "\\vartheta", true);
defineSymbol(math, main, mathord, "\u03d6", "\\varpi", true);
defineSymbol(math, main, mathord, "\u03f1", "\\varrho", true);
defineSymbol(math, main, mathord, "\u03c2", "\\varsigma", true);
defineSymbol(math, main, mathord, "\u03c6", "\\varphi", true);
defineSymbol(math, main, bin, "\u2217", "*", true);
defineSymbol(math, main, bin, "+", "+");
defineSymbol(math, main, bin, "\u2212", "-", true);
defineSymbol(math, main, bin, "\u22c5", "\\cdot", true);
defineSymbol(math, main, bin, "\u2218", "\\circ", true);
defineSymbol(math, main, bin, "\u00f7", "\\div", true);
defineSymbol(math, main, bin, "\u00b1", "\\pm", true);
defineSymbol(math, main, bin, "\u00d7", "\\times", true);
defineSymbol(math, main, bin, "\u2229", "\\cap", true);
defineSymbol(math, main, bin, "\u222a", "\\cup", true);
defineSymbol(math, main, bin, "\u2216", "\\setminus", true);
defineSymbol(math, main, bin, "\u2227", "\\land");
defineSymbol(math, main, bin, "\u2228", "\\lor");
defineSymbol(math, main, bin, "\u2227", "\\wedge", true);
defineSymbol(math, main, bin, "\u2228", "\\vee", true);
defineSymbol(math, main, textord, "\u221a", "\\surd");
defineSymbol(math, main, open, "\u27e8", "\\langle", true);
defineSymbol(math, main, open, "\u2223", "\\lvert");
defineSymbol(math, main, open, "\u2225", "\\lVert");
defineSymbol(math, main, close, "?", "?");
defineSymbol(math, main, close, "!", "!");
defineSymbol(math, main, close, "\u27e9", "\\rangle", true);
defineSymbol(math, main, close, "\u2223", "\\rvert");
defineSymbol(math, main, close, "\u2225", "\\rVert");
defineSymbol(math, main, rel, "=", "=");
defineSymbol(math, main, rel, ":", ":");
defineSymbol(math, main, rel, "\u2248", "\\approx", true);
defineSymbol(math, main, rel, "\u2245", "\\cong", true);
defineSymbol(math, main, rel, "\u2265", "\\ge");
defineSymbol(math, main, rel, "\u2265", "\\geq", true);
defineSymbol(math, main, rel, "\u2190", "\\gets");
defineSymbol(math, main, rel, ">", "\\gt", true);
defineSymbol(math, main, rel, "\u2208", "\\in", true);
defineSymbol(math, main, rel, "\ue020", "\\@not");
defineSymbol(math, main, rel, "\u2282", "\\subset", true);
defineSymbol(math, main, rel, "\u2283", "\\supset", true);
defineSymbol(math, main, rel, "\u2286", "\\subseteq", true);
defineSymbol(math, main, rel, "\u2287", "\\supseteq", true);
defineSymbol(math, ams, rel, "\u2288", "\\nsubseteq", true);
defineSymbol(math, ams, rel, "\u2289", "\\nsupseteq", true);
defineSymbol(math, main, rel, "\u22a8", "\\models");
defineSymbol(math, main, rel, "\u2190", "\\leftarrow", true);
defineSymbol(math, main, rel, "\u2264", "\\le");
defineSymbol(math, main, rel, "\u2264", "\\leq", true);
defineSymbol(math, main, rel, "<", "\\lt", true);
defineSymbol(math, main, rel, "\u2192", "\\rightarrow", true);
defineSymbol(math, main, rel, "\u2192", "\\to");
defineSymbol(math, ams, rel, "\u2271", "\\ngeq", true);
defineSymbol(math, ams, rel, "\u2270", "\\nleq", true);
defineSymbol(math, main, spacing, "\u00a0", "\\ ");
defineSymbol(math, main, spacing, "\u00a0", "\\space");
defineSymbol(math, main, spacing, "\u00a0", "\\nobreakspace");
defineSymbol(text, main, spacing, "\u00a0", "\\ ");
defineSymbol(text, main, spacing, "\u00a0", " ");
defineSymbol(text, main, spacing, "\u00a0", "\\space");
defineSymbol(text, main, spacing, "\u00a0", "\\nobreakspace");
defineSymbol(math, main, spacing, null, "\\nobreak");
defineSymbol(math, main, spacing, null, "\\allowbreak");
defineSymbol(math, main, punct, ",", ",");
defineSymbol(math, main, punct, ";", ";");
defineSymbol(math, ams, bin, "\u22bc", "\\barwedge", true);
defineSymbol(math, ams, bin, "\u22bb", "\\veebar", true);
defineSymbol(math, main, bin, "\u2299", "\\odot", true);
defineSymbol(math, main, bin, "\u2295", "\\oplus", true);
defineSymbol(math, main, bin, "\u2297", "\\otimes", true);
defineSymbol(math, main, textord, "\u2202", "\\partial", true);
defineSymbol(math, main, bin, "\u2298", "\\oslash", true);
defineSymbol(math, ams, bin, "\u229a", "\\circledcirc", true);
defineSymbol(math, ams, bin, "\u22a1", "\\boxdot", true);
defineSymbol(math, main, bin, "\u25b3", "\\bigtriangleup");
defineSymbol(math, main, bin, "\u25bd", "\\bigtriangledown");
defineSymbol(math, main, bin, "\u2020", "\\dagger");
defineSymbol(math, main, bin, "\u22c4", "\\diamond");
defineSymbol(math, main, bin, "\u22c6", "\\star");
defineSymbol(math, main, bin, "\u25c3", "\\triangleleft");
defineSymbol(math, main, bin, "\u25b9", "\\triangleright");
defineSymbol(math, main, open, "{", "\\{");
defineSymbol(text, main, textord, "{", "\\{");
defineSymbol(text, main, textord, "{", "\\textbraceleft");
defineSymbol(math, main, close, "}", "\\}");
defineSymbol(text, main, textord, "}", "\\}");
defineSymbol(text, main, textord, "}", "\\textbraceright");
defineSymbol(math, main, open, "{", "\\lbrace");
defineSymbol(math, main, close, "}", "\\rbrace");
defineSymbol(math, main, open, "[", "\\lbrack", true);
defineSymbol(text, main, textord, "[", "\\lbrack", true);
defineSymbol(math, main, close, "]", "\\rbrack", true);
defineSymbol(text, main, textord, "]", "\\rbrack", true);
defineSymbol(math, main, open, "(", "\\lparen", true);
defineSymbol(math, main, close, ")", "\\rparen", true);
defineSymbol(text, main, textord, "<", "\\textless", true);
defineSymbol(text, main, textord, ">", "\\textgreater", true);
defineSymbol(math, main, open, "\u230a", "\\lfloor", true);
defineSymbol(math, main, close, "\u230b", "\\rfloor", true);
defineSymbol(math, main, open, "\u2308", "\\lceil", true);
defineSymbol(math, main, close, "\u2309", "\\rceil", true);
defineSymbol(math, main, textord, "\\", "\\backslash");
defineSymbol(math, main, textord, "\u2223", "|");
defineSymbol(math, main, textord, "\u2223", "\\vert");
defineSymbol(text, main, textord, "|", "\\textbar", true);
defineSymbol(math, main, textord, "\u2225", "\\|");
defineSymbol(math, main, textord, "\u2225", "\\Vert");
defineSymbol(text, main, textord, "\u2225", "\\textbardbl");
defineSymbol(text, main, textord, "~", "\\textasciitilde");
defineSymbol(text, main, textord, "\\", "\\textbackslash");
defineSymbol(text, main, textord, "^", "\\textasciicircum");
defineSymbol(math, main, rel, "\u2191", "\\uparrow", true);
defineSymbol(math, main, rel, "\u21d1", "\\Uparrow", true);
defineSymbol(math, main, rel, "\u2193", "\\downarrow", true);
defineSymbol(math, main, rel, "\u21d3", "\\Downarrow", true);
defineSymbol(math, main, rel, "\u2195", "\\updownarrow", true);
defineSymbol(math, main, rel, "\u21d5", "\\Updownarrow", true);
defineSymbol(math, main, op, "\u2210", "\\coprod");
defineSymbol(math, main, op, "\u22c1", "\\bigvee");
defineSymbol(math, main, op, "\u22c0", "\\bigwedge");
defineSymbol(math, main, op, "\u2a04", "\\biguplus");
defineSymbol(math, main, op, "\u22c2", "\\bigcap");
defineSymbol(math, main, op, "\u22c3", "\\bigcup");
defineSymbol(math, main, op, "\u222b", "\\int");
defineSymbol(math, main, op, "\u222b", "\\intop");
defineSymbol(math, main, op, "\u222c", "\\iint");
defineSymbol(math, main, op, "\u222d", "\\iiint");
defineSymbol(math, main, op, "\u220f", "\\prod");
defineSymbol(math, main, op, "\u2211", "\\sum");
defineSymbol(math, main, op, "\u2a02", "\\bigotimes");
defineSymbol(math, main, op, "\u2a01", "\\bigoplus");
defineSymbol(math, main, op, "\u2a00", "\\bigodot");
defineSymbol(math, main, op, "\u222e", "\\oint");
defineSymbol(math, main, op, "\u222f", "\\oiint");
defineSymbol(math, main, op, "\u2230", "\\oiiint");
defineSymbol(math, main, op, "\u2a06", "\\bigsqcup");
defineSymbol(math, main, op, "\u222b", "\\smallint");
defineSymbol(text, main, inner, "\u2026", "\\textellipsis");
defineSymbol(math, main, inner, "\u2026", "\\mathellipsis");
defineSymbol(text, main, inner, "\u2026", "\\ldots", true);
defineSymbol(math, main, inner, "\u2026", "\\ldots", true);
defineSymbol(math, main, inner, "\u22ef", "\\@cdots", true);
defineSymbol(math, main, inner, "\u22f1", "\\ddots", true);
defineSymbol(math, main, textord, "\u22ee", "\\varvdots");
defineSymbol(math, main, accent, "\u02ca", "\\acute");
defineSymbol(math, main, accent, "\u02cb", "\\grave");
defineSymbol(math, main, accent, "\u00a8", "\\ddot");
defineSymbol(math, main, accent, "\u007e", "\\tilde");
defineSymbol(math, main, accent, "\u02c9", "\\bar");
defineSymbol(math, main, accent, "\u02d8", "\\breve");
defineSymbol(math, main, accent, "\u02c7", "\\check");
defineSymbol(math, main, accent, "\u005e", "\\hat");
defineSymbol(math, main, accent, "\u20d7", "\\vec");
defineSymbol(math, main, accent, "\u02d9", "\\dot");
defineSymbol(math, main, accent, "\u02da", "\\mathring");
defineSymbol(math, main, mathord, "\ue131", "\\@imath");
defineSymbol(math, main, mathord, "\ue237", "\\@jmath");
defineSymbol(math, main, textord, "\u0131", "\u0131");
defineSymbol(math, main, textord, "\u0237", "\u0237");
defineSymbol(text, main, textord, "\u0131", "\\i", true);
defineSymbol(text, main, textord, "\u0237", "\\j", true);
defineSymbol(text, main, textord, "\u00df", "\\ss", true);
defineSymbol(text, main, textord, "\u00e6", "\\ae", true);
defineSymbol(text, main, textord, "\u0153", "\\oe", true);
defineSymbol(text, main, textord, "\u00f8", "\\o", true);
defineSymbol(text, main, textord, "\u00c6", "\\AE", true);
defineSymbol(text, main, textord, "\u0152", "\\OE", true);
defineSymbol(text, main, textord, "\u00d8", "\\O", true);
defineSymbol(text, main, accent, "\u02ca", "\\'");
defineSymbol(text, main, accent, "\u02cb", "\\`");
defineSymbol(text, main, accent, "\u02c6", "\\^");
defineSymbol(text, main, accent, "\u02dc", "\\~");
defineSymbol(text, main, accent, "\u02c9", "\\=");
defineSymbol(text, main, accent, "\u02d8", "\\u");
defineSymbol(text, main, accent, "\u02d9", "\\.");
defineSymbol(text, main, accent, "\u00b8", "\\c");
defineSymbol(text, main, accent, "\u02da", "\\r");
defineSymbol(text, main, accent, "\u02c7", "\\v");
defineSymbol(text, main, accent, "\u00a8", '\\"');
defineSymbol(text, main, accent, "\u02dd", "\\H");
defineSymbol(text, main, accent, "\u25ef", "\\textcircled");
var ligatures = {
    "--": true,
    "---": true,
    "``": true,
    "''": true
};
defineSymbol(text, main, textord, "\u2013", "--", true);
defineSymbol(text, main, textord, "\u2013", "\\textendash");
defineSymbol(text, main, textord, "\u2014", "---", true);
defineSymbol(text, main, textord, "\u2014", "\\textemdash");
defineSymbol(text, main, textord, "\u2018", "`", true);
defineSymbol(text, main, textord, "\u2018", "\\textquoteleft");
defineSymbol(text, main, textord, "\u2019", "'", true);
defineSymbol(text, main, textord, "\u2019", "\\textquoteright");
defineSymbol(text, main, textord, "\u201c", "``", true);
defineSymbol(text, main, textord, "\u201c", "\\textquotedblleft");
defineSymbol(text, main, textord, "\u201d", "''", true);
defineSymbol(text, main, textord, "\u201d", "\\textquotedblright");
defineSymbol(math, main, textord, "\u00b0", "\\degree", true);
defineSymbol(text, main, textord, "\u00b0", "\\degree");
defineSymbol(text, main, textord, "\u00b0", "\\textdegree", true);
defineSymbol(math, main, textord, "\u00a3", "\\pounds");
defineSymbol(math, main, textord, "\u00a3", "\\mathsterling", true);
defineSymbol(text, main, textord, "\u00a3", "\\pounds");
defineSymbol(text, main, textord, "\u00a3", "\\textsterling", true);
defineSymbol(math, ams, textord, "\u2720", "\\maltese");
defineSymbol(text, ams, textord, "\u2720", "\\maltese");
var mathTextSymbols = "0123456789/@.\"";
for(var i = 0; i < mathTextSymbols.length; i++){
    var ch = mathTextSymbols.charAt(i);
    defineSymbol(math, main, textord, ch, ch);
}
var textSymbols = "0123456789!@*()-=+\";:?/.,";
for(var _i = 0; _i < textSymbols.length; _i++){
    var _ch = textSymbols.charAt(_i);
    defineSymbol(text, main, textord, _ch, _ch);
}
var letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";
for(var _i2 = 0; _i2 < letters.length; _i2++){
    var _ch2 = letters.charAt(_i2);
    defineSymbol(math, main, mathord, _ch2, _ch2);
    defineSymbol(text, main, textord, _ch2, _ch2);
}
defineSymbol(math, ams, textord, "C", "\u2102");
defineSymbol(text, ams, textord, "C", "\u2102");
defineSymbol(math, ams, textord, "H", "\u210D");
defineSymbol(text, ams, textord, "H", "\u210D");
defineSymbol(math, ams, textord, "N", "\u2115");
defineSymbol(text, ams, textord, "N", "\u2115");
defineSymbol(math, ams, textord, "P", "\u2119");
defineSymbol(text, ams, textord, "P", "\u2119");
defineSymbol(math, ams, textord, "Q", "\u211A");
defineSymbol(text, ams, textord, "Q", "\u211A");
defineSymbol(math, ams, textord, "R", "\u211D");
defineSymbol(text, ams, textord, "R", "\u211D");
defineSymbol(math, ams, textord, "Z", "\u2124");
defineSymbol(text, ams, textord, "Z", "\u2124");
defineSymbol(math, main, mathord, "h", "\u210E");
defineSymbol(text, main, mathord, "h", "\u210E");
var wideChar = "";
for(var _i3 = 0; _i3 < letters.length; _i3++){
    var _ch3 = letters.charAt(_i3);
    wideChar = String.fromCharCode(0xD835, 0xDC00 + _i3);
    defineSymbol(math, main, mathord, _ch3, wideChar);
    defineSymbol(text, main, textord, _ch3, wideChar);
    wideChar = String.fromCharCode(0xD835, 0xDC34 + _i3);
    defineSymbol(math, main, mathord, _ch3, wideChar);
    defineSymbol(text, main, textord, _ch3, wideChar);
    wideChar = String.fromCharCode(0xD835, 0xDC68 + _i3);
    defineSymbol(math, main, mathord, _ch3, wideChar);
    defineSymbol(text, main, textord, _ch3, wideChar);
    wideChar = String.fromCharCode(0xD835, 0xDD04 + _i3);
    defineSymbol(math, main, mathord, _ch3, wideChar);
    defineSymbol(text, main, textord, _ch3, wideChar);
    wideChar = String.fromCharCode(0xD835, 0xDD6C + _i3);
    defineSymbol(math, main, mathord, _ch3, wideChar);
    defineSymbol(text, main, textord, _ch3, wideChar);
    wideChar = String.fromCharCode(0xD835, 0xDDA0 + _i3);
    defineSymbol(math, main, mathord, _ch3, wideChar);
    defineSymbol(text, main, textord, _ch3, wideChar);
    wideChar = String.fromCharCode(0xD835, 0xDDD4 + _i3);
    defineSymbol(math, main, mathord, _ch3, wideChar);
    defineSymbol(text, main, textord, _ch3, wideChar);
    wideChar = String.fromCharCode(0xD835, 0xDE08 + _i3);
    defineSymbol(math, main, mathord, _ch3, wideChar);
    defineSymbol(text, main, textord, _ch3, wideChar);
    wideChar = String.fromCharCode(0xD835, 0xDE70 + _i3);
    defineSymbol(math, main, mathord, _ch3, wideChar);
    defineSymbol(text, main, textord, _ch3, wideChar);
    if (_i3 < 26) {
        wideChar = String.fromCharCode(0xD835, 0xDD38 + _i3);
        defineSymbol(math, main, mathord, _ch3, wideChar);
        defineSymbol(text, main, textord, _ch3, wideChar);
        wideChar = String.fromCharCode(0xD835, 0xDC9C + _i3);
        defineSymbol(math, main, mathord, _ch3, wideChar);
        defineSymbol(text, main, textord, _ch3, wideChar);
    }
}
wideChar = String.fromCharCode(0xD835, 0xDD5C);
defineSymbol(math, main, mathord, "k", wideChar);
defineSymbol(text, main, textord, "k", wideChar);
for(var _i4 = 0; _i4 < 10; _i4++){
    var _ch4 = _i4.toString();
    wideChar = String.fromCharCode(0xD835, 0xDFCE + _i4);
    defineSymbol(math, main, mathord, _ch4, wideChar);
    defineSymbol(text, main, textord, _ch4, wideChar);
    wideChar = String.fromCharCode(0xD835, 0xDFE2 + _i4);
    defineSymbol(math, main, mathord, _ch4, wideChar);
    defineSymbol(text, main, textord, _ch4, wideChar);
    wideChar = String.fromCharCode(0xD835, 0xDFEC + _i4);
    defineSymbol(math, main, mathord, _ch4, wideChar);
    defineSymbol(text, main, textord, _ch4, wideChar);
    wideChar = String.fromCharCode(0xD835, 0xDFF6 + _i4);
    defineSymbol(math, main, mathord, _ch4, wideChar);
    defineSymbol(text, main, textord, _ch4, wideChar);
}
var extraLatin = "\u00d0\u00de\u00fe";
for(var _i5 = 0; _i5 < extraLatin.length; _i5++){
    var _ch5 = extraLatin.charAt(_i5);
    defineSymbol(math, main, mathord, _ch5, _ch5);
    defineSymbol(text, main, textord, _ch5, _ch5);
}
var wideLatinLetterData = [
    [
        "mathbf",
        "textbf",
        "Main-Bold"
    ],
    [
        "mathbf",
        "textbf",
        "Main-Bold"
    ],
    [
        "mathnormal",
        "textit",
        "Math-Italic"
    ],
    [
        "mathnormal",
        "textit",
        "Math-Italic"
    ],
    [
        "boldsymbol",
        "boldsymbol",
        "Main-BoldItalic"
    ],
    [
        "boldsymbol",
        "boldsymbol",
        "Main-BoldItalic"
    ],
    [
        "mathscr",
        "textscr",
        "Script-Regular"
    ],
    [
        "",
        "",
        ""
    ],
    [
        "",
        "",
        ""
    ],
    [
        "",
        "",
        ""
    ],
    [
        "mathfrak",
        "textfrak",
        "Fraktur-Regular"
    ],
    [
        "mathfrak",
        "textfrak",
        "Fraktur-Regular"
    ],
    [
        "mathbb",
        "textbb",
        "AMS-Regular"
    ],
    [
        "mathbb",
        "textbb",
        "AMS-Regular"
    ],
    [
        "mathboldfrak",
        "textboldfrak",
        "Fraktur-Regular"
    ],
    [
        "mathboldfrak",
        "textboldfrak",
        "Fraktur-Regular"
    ],
    [
        "mathsf",
        "textsf",
        "SansSerif-Regular"
    ],
    [
        "mathsf",
        "textsf",
        "SansSerif-Regular"
    ],
    [
        "mathboldsf",
        "textboldsf",
        "SansSerif-Bold"
    ],
    [
        "mathboldsf",
        "textboldsf",
        "SansSerif-Bold"
    ],
    [
        "mathitsf",
        "textitsf",
        "SansSerif-Italic"
    ],
    [
        "mathitsf",
        "textitsf",
        "SansSerif-Italic"
    ],
    [
        "",
        "",
        ""
    ],
    [
        "",
        "",
        ""
    ],
    [
        "mathtt",
        "texttt",
        "Typewriter-Regular"
    ],
    [
        "mathtt",
        "texttt",
        "Typewriter-Regular"
    ]
];
var wideNumeralData = [
    [
        "mathbf",
        "textbf",
        "Main-Bold"
    ],
    [
        "",
        "",
        ""
    ],
    [
        "mathsf",
        "textsf",
        "SansSerif-Regular"
    ],
    [
        "mathboldsf",
        "textboldsf",
        "SansSerif-Bold"
    ],
    [
        "mathtt",
        "texttt",
        "Typewriter-Regular"
    ]
];
var wideCharacterFont = function wideCharacterFont(wideChar, mode) {
    var H = wideChar.charCodeAt(0);
    var L = wideChar.charCodeAt(1);
    var codePoint = (H - 0xD800) * 0x400 + (L - 0xDC00) + 0x10000;
    var j = mode === "math" ? 0 : 1;
    if (0x1D400 <= codePoint && codePoint < 0x1D6A4) {
        var i = Math.floor((codePoint - 0x1D400) / 26);
        return [
            wideLatinLetterData[i][2],
            wideLatinLetterData[i][j]
        ];
    } else if (0x1D7CE <= codePoint && codePoint <= 0x1D7FF) {
        var _i = Math.floor((codePoint - 0x1D7CE) / 10);
        return [
            wideNumeralData[_i][2],
            wideNumeralData[_i][j]
        ];
    } else if (codePoint === 0x1D6A5 || codePoint === 0x1D6A6) {
        return [
            wideLatinLetterData[0][2],
            wideLatinLetterData[0][j]
        ];
    } else if (0x1D6A6 < codePoint && codePoint < 0x1D7CE) {
        return [
            "",
            ""
        ];
    } else {
        throw new ParseError("Unsupported character: " + wideChar);
    }
};
var lookupSymbol = function lookupSymbol(value, fontName, mode) {
    if (symbols[mode][value] && symbols[mode][value].replace) {
        value = symbols[mode][value].replace;
    }
    return {
        value: value,
        metrics: getCharacterMetrics(value, fontName, mode)
    };
};
var makeSymbol = function makeSymbol(value, fontName, mode, options, classes) {
    var lookup = lookupSymbol(value, fontName, mode);
    var metrics = lookup.metrics;
    value = lookup.value;
    var symbolNode;
    if (metrics) {
        var italic = metrics.italic;
        if (mode === "text" || options && options.font === "mathit") {
            italic = 0;
        }
        symbolNode = new SymbolNode(value, metrics.height, metrics.depth, italic, metrics.skew, metrics.width, classes);
    } else {
        typeof console !== "undefined" && console.warn("No character metrics " + ("for '" + value + "' in style '" + fontName + "' and mode '" + mode + "'"));
        symbolNode = new SymbolNode(value, 0, 0, 0, 0, 0, classes);
    }
    if (options) {
        symbolNode.maxFontSize = options.sizeMultiplier;
        if (options.style.isTight()) {
            symbolNode.classes.push("mtight");
        }
        var color = options.getColor();
        if (color) {
            symbolNode.style.color = color;
        }
    }
    return symbolNode;
};
var mathsym = function mathsym(value, mode, options, classes) {
    if (classes === void 0) {
        classes = [];
    }
    if (options.font === "boldsymbol" && lookupSymbol(value, "Main-Bold", mode).metrics) {
        return makeSymbol(value, "Main-Bold", mode, options, classes.concat([
            "mathbf"
        ]));
    } else if (value === "\\" || symbols[mode][value].font === "main") {
        return makeSymbol(value, "Main-Regular", mode, options, classes);
    } else {
        return makeSymbol(value, "AMS-Regular", mode, options, classes.concat([
            "amsrm"
        ]));
    }
};
var boldsymbol = function boldsymbol(value, mode, options, classes, type) {
    if (type !== "textord" && lookupSymbol(value, "Math-BoldItalic", mode).metrics) {
        return {
            fontName: "Math-BoldItalic",
            fontClass: "boldsymbol"
        };
    } else {
        return {
            fontName: "Main-Bold",
            fontClass: "mathbf"
        };
    }
};
var makeOrd = function makeOrd(group, options, type) {
    var mode = group.mode;
    var text = group.text;
    var classes = [
        "mord"
    ];
    var isFont = mode === "math" || mode === "text" && options.font;
    var fontOrFamily = isFont ? options.font : options.fontFamily;
    var wideFontName = "";
    var wideFontClass = "";
    if (text.charCodeAt(0) === 0xD835) {
        [wideFontName, wideFontClass] = wideCharacterFont(text, mode);
    }
    if (wideFontName.length > 0) {
        return makeSymbol(text, wideFontName, mode, options, classes.concat(wideFontClass));
    } else if (fontOrFamily) {
        var fontName;
        var fontClasses;
        if (fontOrFamily === "boldsymbol") {
            var fontData = boldsymbol(text, mode, options, classes, type);
            fontName = fontData.fontName;
            fontClasses = [
                fontData.fontClass
            ];
        } else if (isFont) {
            fontName = fontMap[fontOrFamily].fontName;
            fontClasses = [
                fontOrFamily
            ];
        } else {
            fontName = retrieveTextFontName(fontOrFamily, options.fontWeight, options.fontShape);
            fontClasses = [
                fontOrFamily,
                options.fontWeight,
                options.fontShape
            ];
        }
        if (lookupSymbol(text, fontName, mode).metrics) {
            return makeSymbol(text, fontName, mode, options, classes.concat(fontClasses));
        } else if (ligatures.hasOwnProperty(text) && fontName.slice(0, 10) === "Typewriter") {
            var parts = [];
            for(var i = 0; i < text.length; i++){
                parts.push(makeSymbol(text[i], fontName, mode, options, classes.concat(fontClasses)));
            }
            return makeFragment(parts);
        }
    }
    if (type === "mathord") {
        return makeSymbol(text, "Math-Italic", mode, options, classes.concat([
            "mathnormal"
        ]));
    } else if (type === "textord") {
        var font = symbols[mode][text] && symbols[mode][text].font;
        if (font === "ams") {
            var _fontName = retrieveTextFontName("amsrm", options.fontWeight, options.fontShape);
            return makeSymbol(text, _fontName, mode, options, classes.concat("amsrm", options.fontWeight, options.fontShape));
        } else if (font === "main" || !font) {
            var _fontName2 = retrieveTextFontName("textrm", options.fontWeight, options.fontShape);
            return makeSymbol(text, _fontName2, mode, options, classes.concat(options.fontWeight, options.fontShape));
        } else {
            var _fontName3 = retrieveTextFontName(font, options.fontWeight, options.fontShape);
            return makeSymbol(text, _fontName3, mode, options, classes.concat(_fontName3, options.fontWeight, options.fontShape));
        }
    } else {
        throw new Error("unexpected type: " + type + " in makeOrd");
    }
};
var canCombine = (prev, next)=>{
    if (createClass(prev.classes) !== createClass(next.classes) || prev.skew !== next.skew || prev.maxFontSize !== next.maxFontSize) {
        return false;
    }
    if (prev.classes.length === 1) {
        var cls = prev.classes[0];
        if (cls === "mbin" || cls === "mord") {
            return false;
        }
    }
    for(var style in prev.style){
        if (prev.style.hasOwnProperty(style) && prev.style[style] !== next.style[style]) {
            return false;
        }
    }
    for(var _style in next.style){
        if (next.style.hasOwnProperty(_style) && prev.style[_style] !== next.style[_style]) {
            return false;
        }
    }
    return true;
};
var tryCombineChars = (chars)=>{
    for(var i = 0; i < chars.length - 1; i++){
        var prev = chars[i];
        var next = chars[i + 1];
        if (prev instanceof SymbolNode && next instanceof SymbolNode && canCombine(prev, next)) {
            prev.text += next.text;
            prev.height = Math.max(prev.height, next.height);
            prev.depth = Math.max(prev.depth, next.depth);
            prev.italic = next.italic;
            chars.splice(i + 1, 1);
            i--;
        }
    }
    return chars;
};
var sizeElementFromChildren = function sizeElementFromChildren(elem) {
    var height = 0;
    var depth = 0;
    var maxFontSize = 0;
    for(var i = 0; i < elem.children.length; i++){
        var child = elem.children[i];
        if (child.height > height) {
            height = child.height;
        }
        if (child.depth > depth) {
            depth = child.depth;
        }
        if (child.maxFontSize > maxFontSize) {
            maxFontSize = child.maxFontSize;
        }
    }
    elem.height = height;
    elem.depth = depth;
    elem.maxFontSize = maxFontSize;
};
var makeSpan$2 = function makeSpan(classes, children, options, style) {
    var span = new Span(classes, children, options, style);
    sizeElementFromChildren(span);
    return span;
};
var makeSvgSpan = (classes, children, options, style)=>new Span(classes, children, options, style);
var makeLineSpan = function makeLineSpan(className, options, thickness) {
    var line = makeSpan$2([
        className
    ], [], options);
    line.height = Math.max(thickness || options.fontMetrics().defaultRuleThickness, options.minRuleThickness);
    line.style.borderBottomWidth = makeEm(line.height);
    line.maxFontSize = 1.0;
    return line;
};
var makeAnchor = function makeAnchor(href, classes, children, options) {
    var anchor = new Anchor(href, classes, children, options);
    sizeElementFromChildren(anchor);
    return anchor;
};
var makeFragment = function makeFragment(children) {
    var fragment = new DocumentFragment(children);
    sizeElementFromChildren(fragment);
    return fragment;
};
var wrapFragment = function wrapFragment(group, options) {
    if (group instanceof DocumentFragment) {
        return makeSpan$2([], [
            group
        ], options);
    }
    return group;
};
var getVListChildrenAndDepth = function getVListChildrenAndDepth(params) {
    if (params.positionType === "individualShift") {
        var oldChildren = params.children;
        var children = [
            oldChildren[0]
        ];
        var _depth = -oldChildren[0].shift - oldChildren[0].elem.depth;
        var currPos = _depth;
        for(var i = 1; i < oldChildren.length; i++){
            var diff = -oldChildren[i].shift - currPos - oldChildren[i].elem.depth;
            var size = diff - (oldChildren[i - 1].elem.height + oldChildren[i - 1].elem.depth);
            currPos = currPos + diff;
            children.push({
                type: "kern",
                size
            });
            children.push(oldChildren[i]);
        }
        return {
            children,
            depth: _depth
        };
    }
    var depth;
    if (params.positionType === "top") {
        var bottom = params.positionData;
        for(var _i = 0; _i < params.children.length; _i++){
            var child = params.children[_i];
            bottom -= child.type === "kern" ? child.size : child.elem.height + child.elem.depth;
        }
        depth = bottom;
    } else if (params.positionType === "bottom") {
        depth = -params.positionData;
    } else {
        var firstChild = params.children[0];
        if (firstChild.type !== "elem") {
            throw new Error('First child must have type "elem".');
        }
        if (params.positionType === "shift") {
            depth = -firstChild.elem.depth - params.positionData;
        } else if (params.positionType === "firstBaseline") {
            depth = -firstChild.elem.depth;
        } else {
            throw new Error("Invalid positionType " + params.positionType + ".");
        }
    }
    return {
        children: params.children,
        depth
    };
};
var makeVList = function makeVList(params, options) {
    var { children , depth  } = getVListChildrenAndDepth(params);
    var pstrutSize = 0;
    for(var i = 0; i < children.length; i++){
        var child = children[i];
        if (child.type === "elem") {
            var elem = child.elem;
            pstrutSize = Math.max(pstrutSize, elem.maxFontSize, elem.height);
        }
    }
    pstrutSize += 2;
    var pstrut = makeSpan$2([
        "pstrut"
    ], []);
    pstrut.style.height = makeEm(pstrutSize);
    var realChildren = [];
    var minPos = depth;
    var maxPos = depth;
    var currPos = depth;
    for(var _i2 = 0; _i2 < children.length; _i2++){
        var _child = children[_i2];
        if (_child.type === "kern") {
            currPos += _child.size;
        } else {
            var _elem = _child.elem;
            var classes = _child.wrapperClasses || [];
            var style = _child.wrapperStyle || {};
            var childWrap = makeSpan$2(classes, [
                pstrut,
                _elem
            ], undefined, style);
            childWrap.style.top = makeEm(-pstrutSize - currPos - _elem.depth);
            if (_child.marginLeft) {
                childWrap.style.marginLeft = _child.marginLeft;
            }
            if (_child.marginRight) {
                childWrap.style.marginRight = _child.marginRight;
            }
            realChildren.push(childWrap);
            currPos += _elem.height + _elem.depth;
        }
        minPos = Math.min(minPos, currPos);
        maxPos = Math.max(maxPos, currPos);
    }
    var vlist = makeSpan$2([
        "vlist"
    ], realChildren);
    vlist.style.height = makeEm(maxPos);
    var rows;
    if (minPos < 0) {
        var emptySpan = makeSpan$2([], []);
        var depthStrut = makeSpan$2([
            "vlist"
        ], [
            emptySpan
        ]);
        depthStrut.style.height = makeEm(-minPos);
        var topStrut = makeSpan$2([
            "vlist-s"
        ], [
            new SymbolNode("\u200b")
        ]);
        rows = [
            makeSpan$2([
                "vlist-r"
            ], [
                vlist,
                topStrut
            ]),
            makeSpan$2([
                "vlist-r"
            ], [
                depthStrut
            ])
        ];
    } else {
        rows = [
            makeSpan$2([
                "vlist-r"
            ], [
                vlist
            ])
        ];
    }
    var vtable = makeSpan$2([
        "vlist-t"
    ], rows);
    if (rows.length === 2) {
        vtable.classes.push("vlist-t2");
    }
    vtable.height = maxPos;
    vtable.depth = -minPos;
    return vtable;
};
var makeGlue = (measurement, options)=>{
    var rule = makeSpan$2([
        "mspace"
    ], [], options);
    var size = calculateSize(measurement, options);
    rule.style.marginRight = makeEm(size);
    return rule;
};
var retrieveTextFontName = function retrieveTextFontName(fontFamily, fontWeight, fontShape) {
    var baseFontName = "";
    switch(fontFamily){
        case "amsrm":
            baseFontName = "AMS";
            break;
        case "textrm":
            baseFontName = "Main";
            break;
        case "textsf":
            baseFontName = "SansSerif";
            break;
        case "texttt":
            baseFontName = "Typewriter";
            break;
        default:
            baseFontName = fontFamily;
    }
    var fontStylesName;
    if (fontWeight === "textbf" && fontShape === "textit") {
        fontStylesName = "BoldItalic";
    } else if (fontWeight === "textbf") {
        fontStylesName = "Bold";
    } else if (fontWeight === "textit") {
        fontStylesName = "Italic";
    } else {
        fontStylesName = "Regular";
    }
    return baseFontName + "-" + fontStylesName;
};
var fontMap = {
    "mathbf": {
        variant: "bold",
        fontName: "Main-Bold"
    },
    "mathrm": {
        variant: "normal",
        fontName: "Main-Regular"
    },
    "textit": {
        variant: "italic",
        fontName: "Main-Italic"
    },
    "mathit": {
        variant: "italic",
        fontName: "Main-Italic"
    },
    "mathnormal": {
        variant: "italic",
        fontName: "Math-Italic"
    },
    "mathbb": {
        variant: "double-struck",
        fontName: "AMS-Regular"
    },
    "mathcal": {
        variant: "script",
        fontName: "Caligraphic-Regular"
    },
    "mathfrak": {
        variant: "fraktur",
        fontName: "Fraktur-Regular"
    },
    "mathscr": {
        variant: "script",
        fontName: "Script-Regular"
    },
    "mathsf": {
        variant: "sans-serif",
        fontName: "SansSerif-Regular"
    },
    "mathtt": {
        variant: "monospace",
        fontName: "Typewriter-Regular"
    }
};
var svgData = {
    vec: [
        "vec",
        0.471,
        0.714
    ],
    oiintSize1: [
        "oiintSize1",
        0.957,
        0.499
    ],
    oiintSize2: [
        "oiintSize2",
        1.472,
        0.659
    ],
    oiiintSize1: [
        "oiiintSize1",
        1.304,
        0.499
    ],
    oiiintSize2: [
        "oiiintSize2",
        1.98,
        0.659
    ]
};
var staticSvg = function staticSvg(value, options) {
    var [pathName, width, height] = svgData[value];
    var path = new PathNode(pathName);
    var svgNode = new SvgNode([
        path
    ], {
        "width": makeEm(width),
        "height": makeEm(height),
        "style": "width:" + makeEm(width),
        "viewBox": "0 0 " + 1000 * width + " " + 1000 * height,
        "preserveAspectRatio": "xMinYMin"
    });
    var span = makeSvgSpan([
        "overlay"
    ], [
        svgNode
    ], options);
    span.height = height;
    span.style.height = makeEm(height);
    span.style.width = makeEm(width);
    return span;
};
var buildCommon = {
    fontMap,
    makeSymbol,
    mathsym,
    makeSpan: makeSpan$2,
    makeSvgSpan,
    makeLineSpan,
    makeAnchor,
    makeFragment,
    wrapFragment,
    makeVList,
    makeOrd,
    makeGlue,
    staticSvg,
    svgData,
    tryCombineChars
};
var thinspace = {
    number: 3,
    unit: "mu"
};
var mediumspace = {
    number: 4,
    unit: "mu"
};
var thickspace = {
    number: 5,
    unit: "mu"
};
var spacings = {
    mord: {
        mop: thinspace,
        mbin: mediumspace,
        mrel: thickspace,
        minner: thinspace
    },
    mop: {
        mord: thinspace,
        mop: thinspace,
        mrel: thickspace,
        minner: thinspace
    },
    mbin: {
        mord: mediumspace,
        mop: mediumspace,
        mopen: mediumspace,
        minner: mediumspace
    },
    mrel: {
        mord: thickspace,
        mop: thickspace,
        mopen: thickspace,
        minner: thickspace
    },
    mopen: {},
    mclose: {
        mop: thinspace,
        mbin: mediumspace,
        mrel: thickspace,
        minner: thinspace
    },
    mpunct: {
        mord: thinspace,
        mop: thinspace,
        mrel: thickspace,
        mopen: thinspace,
        mclose: thinspace,
        mpunct: thinspace,
        minner: thinspace
    },
    minner: {
        mord: thinspace,
        mop: thinspace,
        mbin: mediumspace,
        mrel: thickspace,
        mopen: thinspace,
        mpunct: thinspace,
        minner: thinspace
    }
};
var tightSpacings = {
    mord: {
        mop: thinspace
    },
    mop: {
        mord: thinspace,
        mop: thinspace
    },
    mbin: {},
    mrel: {},
    mopen: {},
    mclose: {
        mop: thinspace
    },
    mpunct: {},
    minner: {
        mop: thinspace
    }
};
var _functions = {};
var _htmlGroupBuilders = {};
var _mathmlGroupBuilders = {};
function defineFunction(_ref) {
    var { type , names , props , handler , htmlBuilder , mathmlBuilder  } = _ref;
    var data = {
        type,
        numArgs: props.numArgs,
        argTypes: props.argTypes,
        allowedInArgument: !!props.allowedInArgument,
        allowedInText: !!props.allowedInText,
        allowedInMath: props.allowedInMath === undefined ? true : props.allowedInMath,
        numOptionalArgs: props.numOptionalArgs || 0,
        infix: !!props.infix,
        primitive: !!props.primitive,
        handler: handler
    };
    for(var i = 0; i < names.length; ++i){
        _functions[names[i]] = data;
    }
    if (type) {
        if (htmlBuilder) {
            _htmlGroupBuilders[type] = htmlBuilder;
        }
        if (mathmlBuilder) {
            _mathmlGroupBuilders[type] = mathmlBuilder;
        }
    }
}
function defineFunctionBuilders(_ref2) {
    var { type , htmlBuilder , mathmlBuilder  } = _ref2;
    defineFunction({
        type,
        names: [],
        props: {
            numArgs: 0
        },
        handler () {
            throw new Error('Should never be called.');
        },
        htmlBuilder,
        mathmlBuilder
    });
}
var normalizeArgument = function normalizeArgument(arg) {
    return arg.type === "ordgroup" && arg.body.length === 1 ? arg.body[0] : arg;
};
var ordargument = function ordargument(arg) {
    return arg.type === "ordgroup" ? arg.body : [
        arg
    ];
};
var makeSpan$1 = buildCommon.makeSpan;
var binLeftCanceller = [
    "leftmost",
    "mbin",
    "mopen",
    "mrel",
    "mop",
    "mpunct"
];
var binRightCanceller = [
    "rightmost",
    "mrel",
    "mclose",
    "mpunct"
];
var styleMap$1 = {
    "display": Style$1.DISPLAY,
    "text": Style$1.TEXT,
    "script": Style$1.SCRIPT,
    "scriptscript": Style$1.SCRIPTSCRIPT
};
var DomEnum = {
    mord: "mord",
    mop: "mop",
    mbin: "mbin",
    mrel: "mrel",
    mopen: "mopen",
    mclose: "mclose",
    mpunct: "mpunct",
    minner: "minner"
};
var buildExpression$1 = function buildExpression(expression, options, isRealGroup, surrounding) {
    if (surrounding === void 0) {
        surrounding = [
            null,
            null
        ];
    }
    var groups = [];
    for(var i = 0; i < expression.length; i++){
        var output = buildGroup$1(expression[i], options);
        if (output instanceof DocumentFragment) {
            var children = output.children;
            groups.push(...children);
        } else {
            groups.push(output);
        }
    }
    buildCommon.tryCombineChars(groups);
    if (!isRealGroup) {
        return groups;
    }
    var glueOptions = options;
    if (expression.length === 1) {
        var node = expression[0];
        if (node.type === "sizing") {
            glueOptions = options.havingSize(node.size);
        } else if (node.type === "styling") {
            glueOptions = options.havingStyle(styleMap$1[node.style]);
        }
    }
    var dummyPrev = makeSpan$1([
        surrounding[0] || "leftmost"
    ], [], options);
    var dummyNext = makeSpan$1([
        surrounding[1] || "rightmost"
    ], [], options);
    var isRoot = isRealGroup === "root";
    traverseNonSpaceNodes(groups, (node, prev)=>{
        var prevType = prev.classes[0];
        var type = node.classes[0];
        if (prevType === "mbin" && utils.contains(binRightCanceller, type)) {
            prev.classes[0] = "mord";
        } else if (type === "mbin" && utils.contains(binLeftCanceller, prevType)) {
            node.classes[0] = "mord";
        }
    }, {
        node: dummyPrev
    }, dummyNext, isRoot);
    traverseNonSpaceNodes(groups, (node, prev)=>{
        var prevType = getTypeOfDomTree(prev);
        var type = getTypeOfDomTree(node);
        var space = prevType && type ? node.hasClass("mtight") ? tightSpacings[prevType][type] : spacings[prevType][type] : null;
        if (space) {
            return buildCommon.makeGlue(space, glueOptions);
        }
    }, {
        node: dummyPrev
    }, dummyNext, isRoot);
    return groups;
};
var traverseNonSpaceNodes = function traverseNonSpaceNodes(nodes, callback, prev, next, isRoot) {
    if (next) {
        nodes.push(next);
    }
    var i = 0;
    for(; i < nodes.length; i++){
        var node = nodes[i];
        var partialGroup = checkPartialGroup(node);
        if (partialGroup) {
            traverseNonSpaceNodes(partialGroup.children, callback, prev, null, isRoot);
            continue;
        }
        var nonspace = !node.hasClass("mspace");
        if (nonspace) {
            var result = callback(node, prev.node);
            if (result) {
                if (prev.insertAfter) {
                    prev.insertAfter(result);
                } else {
                    nodes.unshift(result);
                    i++;
                }
            }
        }
        if (nonspace) {
            prev.node = node;
        } else if (isRoot && node.hasClass("newline")) {
            prev.node = makeSpan$1([
                "leftmost"
            ]);
        }
        prev.insertAfter = ((index)=>(n)=>{
                nodes.splice(index + 1, 0, n);
                i++;
            })(i);
    }
    if (next) {
        nodes.pop();
    }
};
var checkPartialGroup = function checkPartialGroup(node) {
    if (node instanceof DocumentFragment || node instanceof Anchor || node instanceof Span && node.hasClass("enclosing")) {
        return node;
    }
    return null;
};
var getOutermostNode = function getOutermostNode(node, side) {
    var partialGroup = checkPartialGroup(node);
    if (partialGroup) {
        var children = partialGroup.children;
        if (children.length) {
            if (side === "right") {
                return getOutermostNode(children[children.length - 1], "right");
            } else if (side === "left") {
                return getOutermostNode(children[0], "left");
            }
        }
    }
    return node;
};
var getTypeOfDomTree = function getTypeOfDomTree(node, side) {
    if (!node) {
        return null;
    }
    if (side) {
        node = getOutermostNode(node, side);
    }
    return DomEnum[node.classes[0]] || null;
};
var makeNullDelimiter = function makeNullDelimiter(options, classes) {
    var moreClasses = [
        "nulldelimiter"
    ].concat(options.baseSizingClasses());
    return makeSpan$1(classes.concat(moreClasses));
};
var buildGroup$1 = function buildGroup(group, options, baseOptions) {
    if (!group) {
        return makeSpan$1();
    }
    if (_htmlGroupBuilders[group.type]) {
        var groupNode = _htmlGroupBuilders[group.type](group, options);
        if (baseOptions && options.size !== baseOptions.size) {
            groupNode = makeSpan$1(options.sizingClasses(baseOptions), [
                groupNode
            ], options);
            var multiplier = options.sizeMultiplier / baseOptions.sizeMultiplier;
            groupNode.height *= multiplier;
            groupNode.depth *= multiplier;
        }
        return groupNode;
    } else {
        throw new ParseError("Got group of unknown type: '" + group.type + "'");
    }
};
function buildHTMLUnbreakable(children, options) {
    var body = makeSpan$1([
        "base"
    ], children, options);
    var strut = makeSpan$1([
        "strut"
    ]);
    strut.style.height = makeEm(body.height + body.depth);
    if (body.depth) {
        strut.style.verticalAlign = makeEm(-body.depth);
    }
    body.children.unshift(strut);
    return body;
}
function buildHTML(tree, options) {
    var tag = null;
    if (tree.length === 1 && tree[0].type === "tag") {
        tag = tree[0].tag;
        tree = tree[0].body;
    }
    var expression = buildExpression$1(tree, options, "root");
    var eqnNum;
    if (expression.length === 2 && expression[1].hasClass("tag")) {
        eqnNum = expression.pop();
    }
    var children = [];
    var parts = [];
    for(var i = 0; i < expression.length; i++){
        parts.push(expression[i]);
        if (expression[i].hasClass("mbin") || expression[i].hasClass("mrel") || expression[i].hasClass("allowbreak")) {
            var nobreak = false;
            while(i < expression.length - 1 && expression[i + 1].hasClass("mspace") && !expression[i + 1].hasClass("newline")){
                i++;
                parts.push(expression[i]);
                if (expression[i].hasClass("nobreak")) {
                    nobreak = true;
                }
            }
            if (!nobreak) {
                children.push(buildHTMLUnbreakable(parts, options));
                parts = [];
            }
        } else if (expression[i].hasClass("newline")) {
            parts.pop();
            if (parts.length > 0) {
                children.push(buildHTMLUnbreakable(parts, options));
                parts = [];
            }
            children.push(expression[i]);
        }
    }
    if (parts.length > 0) {
        children.push(buildHTMLUnbreakable(parts, options));
    }
    var tagChild;
    if (tag) {
        tagChild = buildHTMLUnbreakable(buildExpression$1(tag, options, true));
        tagChild.classes = [
            "tag"
        ];
        children.push(tagChild);
    } else if (eqnNum) {
        children.push(eqnNum);
    }
    var htmlNode = makeSpan$1([
        "katex-html"
    ], children);
    htmlNode.setAttribute("aria-hidden", "true");
    if (tagChild) {
        var strut = tagChild.children[0];
        strut.style.height = makeEm(htmlNode.height + htmlNode.depth);
        if (htmlNode.depth) {
            strut.style.verticalAlign = makeEm(-htmlNode.depth);
        }
    }
    return htmlNode;
}
function newDocumentFragment(children) {
    return new DocumentFragment(children);
}
class MathNode {
    constructor(type, children, classes){
        this.type = void 0;
        this.attributes = void 0;
        this.children = void 0;
        this.classes = void 0;
        this.type = type;
        this.attributes = {};
        this.children = children || [];
        this.classes = classes || [];
    }
    setAttribute(name, value) {
        this.attributes[name] = value;
    }
    getAttribute(name) {
        return this.attributes[name];
    }
    toNode() {
        var node = document.createElementNS("http://www.w3.org/1998/Math/MathML", this.type);
        for(var attr in this.attributes){
            if (Object.prototype.hasOwnProperty.call(this.attributes, attr)) {
                node.setAttribute(attr, this.attributes[attr]);
            }
        }
        if (this.classes.length > 0) {
            node.className = createClass(this.classes);
        }
        for(var i = 0; i < this.children.length; i++){
            node.appendChild(this.children[i].toNode());
        }
        return node;
    }
    toMarkup() {
        var markup = "<" + this.type;
        for(var attr in this.attributes){
            if (Object.prototype.hasOwnProperty.call(this.attributes, attr)) {
                markup += " " + attr + "=\"";
                markup += utils.escape(this.attributes[attr]);
                markup += "\"";
            }
        }
        if (this.classes.length > 0) {
            markup += " class =\"" + utils.escape(createClass(this.classes)) + "\"";
        }
        markup += ">";
        for(var i = 0; i < this.children.length; i++){
            markup += this.children[i].toMarkup();
        }
        markup += "</" + this.type + ">";
        return markup;
    }
    toText() {
        return this.children.map((child)=>child.toText()).join("");
    }
}
class TextNode {
    constructor(text){
        this.text = void 0;
        this.text = text;
    }
    toNode() {
        return document.createTextNode(this.text);
    }
    toMarkup() {
        return utils.escape(this.toText());
    }
    toText() {
        return this.text;
    }
}
class SpaceNode {
    constructor(width){
        this.width = void 0;
        this.character = void 0;
        this.width = width;
        if (width >= 0.05555 && width <= 0.05556) {
            this.character = "\u200a";
        } else if (width >= 0.1666 && width <= 0.1667) {
            this.character = "\u2009";
        } else if (width >= 0.2222 && width <= 0.2223) {
            this.character = "\u2005";
        } else if (width >= 0.2777 && width <= 0.2778) {
            this.character = "\u2005\u200a";
        } else if (width >= -0.05556 && width <= -0.05555) {
            this.character = "\u200a\u2063";
        } else if (width >= -0.1667 && width <= -0.1666) {
            this.character = "\u2009\u2063";
        } else if (width >= -0.2223 && width <= -0.2222) {
            this.character = "\u205f\u2063";
        } else if (width >= -0.2778 && width <= -0.2777) {
            this.character = "\u2005\u2063";
        } else {
            this.character = null;
        }
    }
    toNode() {
        if (this.character) {
            return document.createTextNode(this.character);
        } else {
            var node = document.createElementNS("http://www.w3.org/1998/Math/MathML", "mspace");
            node.setAttribute("width", makeEm(this.width));
            return node;
        }
    }
    toMarkup() {
        if (this.character) {
            return "<mtext>" + this.character + "</mtext>";
        } else {
            return "<mspace width=\"" + makeEm(this.width) + "\"/>";
        }
    }
    toText() {
        if (this.character) {
            return this.character;
        } else {
            return " ";
        }
    }
}
var mathMLTree = {
    MathNode,
    TextNode,
    SpaceNode,
    newDocumentFragment
};
var makeText = function makeText(text, mode, options) {
    if (symbols[mode][text] && symbols[mode][text].replace && text.charCodeAt(0) !== 0xD835 && !(ligatures.hasOwnProperty(text) && options && (options.fontFamily && options.fontFamily.slice(4, 6) === "tt" || options.font && options.font.slice(4, 6) === "tt"))) {
        text = symbols[mode][text].replace;
    }
    return new mathMLTree.TextNode(text);
};
var makeRow = function makeRow(body) {
    if (body.length === 1) {
        return body[0];
    } else {
        return new mathMLTree.MathNode("mrow", body);
    }
};
var getVariant = function getVariant(group, options) {
    if (options.fontFamily === "texttt") {
        return "monospace";
    } else if (options.fontFamily === "textsf") {
        if (options.fontShape === "textit" && options.fontWeight === "textbf") {
            return "sans-serif-bold-italic";
        } else if (options.fontShape === "textit") {
            return "sans-serif-italic";
        } else if (options.fontWeight === "textbf") {
            return "bold-sans-serif";
        } else {
            return "sans-serif";
        }
    } else if (options.fontShape === "textit" && options.fontWeight === "textbf") {
        return "bold-italic";
    } else if (options.fontShape === "textit") {
        return "italic";
    } else if (options.fontWeight === "textbf") {
        return "bold";
    }
    var font = options.font;
    if (!font || font === "mathnormal") {
        return null;
    }
    var mode = group.mode;
    if (font === "mathit") {
        return "italic";
    } else if (font === "boldsymbol") {
        return group.type === "textord" ? "bold" : "bold-italic";
    } else if (font === "mathbf") {
        return "bold";
    } else if (font === "mathbb") {
        return "double-struck";
    } else if (font === "mathfrak") {
        return "fraktur";
    } else if (font === "mathscr" || font === "mathcal") {
        return "script";
    } else if (font === "mathsf") {
        return "sans-serif";
    } else if (font === "mathtt") {
        return "monospace";
    }
    var text = group.text;
    if (utils.contains([
        "\\imath",
        "\\jmath"
    ], text)) {
        return null;
    }
    if (symbols[mode][text] && symbols[mode][text].replace) {
        text = symbols[mode][text].replace;
    }
    var fontName = buildCommon.fontMap[font].fontName;
    if (getCharacterMetrics(text, fontName, mode)) {
        return buildCommon.fontMap[font].variant;
    }
    return null;
};
var buildExpression = function buildExpression(expression, options, isOrdgroup) {
    if (expression.length === 1) {
        var group = buildGroup(expression[0], options);
        if (isOrdgroup && group instanceof MathNode && group.type === "mo") {
            group.setAttribute("lspace", "0em");
            group.setAttribute("rspace", "0em");
        }
        return [
            group
        ];
    }
    var groups = [];
    var lastGroup;
    for(var i = 0; i < expression.length; i++){
        var _group = buildGroup(expression[i], options);
        if (_group instanceof MathNode && lastGroup instanceof MathNode) {
            if (_group.type === 'mtext' && lastGroup.type === 'mtext' && _group.getAttribute('mathvariant') === lastGroup.getAttribute('mathvariant')) {
                lastGroup.children.push(..._group.children);
                continue;
            } else if (_group.type === 'mn' && lastGroup.type === 'mn') {
                lastGroup.children.push(..._group.children);
                continue;
            } else if (_group.type === 'mi' && _group.children.length === 1 && lastGroup.type === 'mn') {
                var child = _group.children[0];
                if (child instanceof TextNode && child.text === '.') {
                    lastGroup.children.push(..._group.children);
                    continue;
                }
            } else if (lastGroup.type === 'mi' && lastGroup.children.length === 1) {
                var lastChild = lastGroup.children[0];
                if (lastChild instanceof TextNode && lastChild.text === '\u0338' && (_group.type === 'mo' || _group.type === 'mi' || _group.type === 'mn')) {
                    var _child = _group.children[0];
                    if (_child instanceof TextNode && _child.text.length > 0) {
                        _child.text = _child.text.slice(0, 1) + "\u0338" + _child.text.slice(1);
                        groups.pop();
                    }
                }
            }
        }
        groups.push(_group);
        lastGroup = _group;
    }
    return groups;
};
var buildExpressionRow = function buildExpressionRow(expression, options, isOrdgroup) {
    return makeRow(buildExpression(expression, options, isOrdgroup));
};
var buildGroup = function buildGroup(group, options) {
    if (!group) {
        return new mathMLTree.MathNode("mrow");
    }
    if (_mathmlGroupBuilders[group.type]) {
        var result = _mathmlGroupBuilders[group.type](group, options);
        return result;
    } else {
        throw new ParseError("Got group of unknown type: '" + group.type + "'");
    }
};
function buildMathML(tree, texExpression, options, isDisplayMode, forMathmlOnly) {
    var expression = buildExpression(tree, options);
    var wrapper;
    if (expression.length === 1 && expression[0] instanceof MathNode && utils.contains([
        "mrow",
        "mtable"
    ], expression[0].type)) {
        wrapper = expression[0];
    } else {
        wrapper = new mathMLTree.MathNode("mrow", expression);
    }
    var annotation = new mathMLTree.MathNode("annotation", [
        new mathMLTree.TextNode(texExpression)
    ]);
    annotation.setAttribute("encoding", "application/x-tex");
    var semantics = new mathMLTree.MathNode("semantics", [
        wrapper,
        annotation
    ]);
    var math = new mathMLTree.MathNode("math", [
        semantics
    ]);
    math.setAttribute("xmlns", "http://www.w3.org/1998/Math/MathML");
    if (isDisplayMode) {
        math.setAttribute("display", "block");
    }
    var wrapperClass = forMathmlOnly ? "katex" : "katex-mathml";
    return buildCommon.makeSpan([
        wrapperClass
    ], [
        math
    ]);
}
var optionsFromSettings = function optionsFromSettings(settings) {
    return new Options({
        style: settings.displayMode ? Style$1.DISPLAY : Style$1.TEXT,
        maxSize: settings.maxSize,
        minRuleThickness: settings.minRuleThickness
    });
};
var displayWrap = function displayWrap(node, settings) {
    if (settings.displayMode) {
        var classes = [
            "katex-display"
        ];
        if (settings.leqno) {
            classes.push("leqno");
        }
        if (settings.fleqn) {
            classes.push("fleqn");
        }
        node = buildCommon.makeSpan(classes, [
            node
        ]);
    }
    return node;
};
var buildTree = function buildTree(tree, expression, settings) {
    var options = optionsFromSettings(settings);
    var katexNode;
    if (settings.output === "mathml") {
        return buildMathML(tree, expression, options, settings.displayMode, true);
    } else if (settings.output === "html") {
        var htmlNode = buildHTML(tree, options);
        katexNode = buildCommon.makeSpan([
            "katex"
        ], [
            htmlNode
        ]);
    } else {
        var mathMLNode = buildMathML(tree, expression, options, settings.displayMode, false);
        var _htmlNode = buildHTML(tree, options);
        katexNode = buildCommon.makeSpan([
            "katex"
        ], [
            mathMLNode,
            _htmlNode
        ]);
    }
    return displayWrap(katexNode, settings);
};
var buildHTMLTree = function buildHTMLTree(tree, expression, settings) {
    var options = optionsFromSettings(settings);
    var htmlNode = buildHTML(tree, options);
    var katexNode = buildCommon.makeSpan([
        "katex"
    ], [
        htmlNode
    ]);
    return displayWrap(katexNode, settings);
};
var stretchyCodePoint = {
    widehat: "^",
    widecheck: "ˇ",
    widetilde: "~",
    utilde: "~",
    overleftarrow: "\u2190",
    underleftarrow: "\u2190",
    xleftarrow: "\u2190",
    overrightarrow: "\u2192",
    underrightarrow: "\u2192",
    xrightarrow: "\u2192",
    underbrace: "\u23df",
    overbrace: "\u23de",
    overgroup: "\u23e0",
    undergroup: "\u23e1",
    overleftrightarrow: "\u2194",
    underleftrightarrow: "\u2194",
    xleftrightarrow: "\u2194",
    Overrightarrow: "\u21d2",
    xRightarrow: "\u21d2",
    overleftharpoon: "\u21bc",
    xleftharpoonup: "\u21bc",
    overrightharpoon: "\u21c0",
    xrightharpoonup: "\u21c0",
    xLeftarrow: "\u21d0",
    xLeftrightarrow: "\u21d4",
    xhookleftarrow: "\u21a9",
    xhookrightarrow: "\u21aa",
    xmapsto: "\u21a6",
    xrightharpoondown: "\u21c1",
    xleftharpoondown: "\u21bd",
    xrightleftharpoons: "\u21cc",
    xleftrightharpoons: "\u21cb",
    xtwoheadleftarrow: "\u219e",
    xtwoheadrightarrow: "\u21a0",
    xlongequal: "=",
    xtofrom: "\u21c4",
    xrightleftarrows: "\u21c4",
    xrightequilibrium: "\u21cc",
    xleftequilibrium: "\u21cb",
    "\\cdrightarrow": "\u2192",
    "\\cdleftarrow": "\u2190",
    "\\cdlongequal": "="
};
var mathMLnode = function mathMLnode(label) {
    var node = new mathMLTree.MathNode("mo", [
        new mathMLTree.TextNode(stretchyCodePoint[label.replace(/^\\/, '')])
    ]);
    node.setAttribute("stretchy", "true");
    return node;
};
var katexImagesData = {
    overrightarrow: [
        [
            "rightarrow"
        ],
        0.888,
        522,
        "xMaxYMin"
    ],
    overleftarrow: [
        [
            "leftarrow"
        ],
        0.888,
        522,
        "xMinYMin"
    ],
    underrightarrow: [
        [
            "rightarrow"
        ],
        0.888,
        522,
        "xMaxYMin"
    ],
    underleftarrow: [
        [
            "leftarrow"
        ],
        0.888,
        522,
        "xMinYMin"
    ],
    xrightarrow: [
        [
            "rightarrow"
        ],
        1.469,
        522,
        "xMaxYMin"
    ],
    "\\cdrightarrow": [
        [
            "rightarrow"
        ],
        3.0,
        522,
        "xMaxYMin"
    ],
    xleftarrow: [
        [
            "leftarrow"
        ],
        1.469,
        522,
        "xMinYMin"
    ],
    "\\cdleftarrow": [
        [
            "leftarrow"
        ],
        3.0,
        522,
        "xMinYMin"
    ],
    Overrightarrow: [
        [
            "doublerightarrow"
        ],
        0.888,
        560,
        "xMaxYMin"
    ],
    xRightarrow: [
        [
            "doublerightarrow"
        ],
        1.526,
        560,
        "xMaxYMin"
    ],
    xLeftarrow: [
        [
            "doubleleftarrow"
        ],
        1.526,
        560,
        "xMinYMin"
    ],
    overleftharpoon: [
        [
            "leftharpoon"
        ],
        0.888,
        522,
        "xMinYMin"
    ],
    xleftharpoonup: [
        [
            "leftharpoon"
        ],
        0.888,
        522,
        "xMinYMin"
    ],
    xleftharpoondown: [
        [
            "leftharpoondown"
        ],
        0.888,
        522,
        "xMinYMin"
    ],
    overrightharpoon: [
        [
            "rightharpoon"
        ],
        0.888,
        522,
        "xMaxYMin"
    ],
    xrightharpoonup: [
        [
            "rightharpoon"
        ],
        0.888,
        522,
        "xMaxYMin"
    ],
    xrightharpoondown: [
        [
            "rightharpoondown"
        ],
        0.888,
        522,
        "xMaxYMin"
    ],
    xlongequal: [
        [
            "longequal"
        ],
        0.888,
        334,
        "xMinYMin"
    ],
    "\\cdlongequal": [
        [
            "longequal"
        ],
        3.0,
        334,
        "xMinYMin"
    ],
    xtwoheadleftarrow: [
        [
            "twoheadleftarrow"
        ],
        0.888,
        334,
        "xMinYMin"
    ],
    xtwoheadrightarrow: [
        [
            "twoheadrightarrow"
        ],
        0.888,
        334,
        "xMaxYMin"
    ],
    overleftrightarrow: [
        [
            "leftarrow",
            "rightarrow"
        ],
        0.888,
        522
    ],
    overbrace: [
        [
            "leftbrace",
            "midbrace",
            "rightbrace"
        ],
        1.6,
        548
    ],
    underbrace: [
        [
            "leftbraceunder",
            "midbraceunder",
            "rightbraceunder"
        ],
        1.6,
        548
    ],
    underleftrightarrow: [
        [
            "leftarrow",
            "rightarrow"
        ],
        0.888,
        522
    ],
    xleftrightarrow: [
        [
            "leftarrow",
            "rightarrow"
        ],
        1.75,
        522
    ],
    xLeftrightarrow: [
        [
            "doubleleftarrow",
            "doublerightarrow"
        ],
        1.75,
        560
    ],
    xrightleftharpoons: [
        [
            "leftharpoondownplus",
            "rightharpoonplus"
        ],
        1.75,
        716
    ],
    xleftrightharpoons: [
        [
            "leftharpoonplus",
            "rightharpoondownplus"
        ],
        1.75,
        716
    ],
    xhookleftarrow: [
        [
            "leftarrow",
            "righthook"
        ],
        1.08,
        522
    ],
    xhookrightarrow: [
        [
            "lefthook",
            "rightarrow"
        ],
        1.08,
        522
    ],
    overlinesegment: [
        [
            "leftlinesegment",
            "rightlinesegment"
        ],
        0.888,
        522
    ],
    underlinesegment: [
        [
            "leftlinesegment",
            "rightlinesegment"
        ],
        0.888,
        522
    ],
    overgroup: [
        [
            "leftgroup",
            "rightgroup"
        ],
        0.888,
        342
    ],
    undergroup: [
        [
            "leftgroupunder",
            "rightgroupunder"
        ],
        0.888,
        342
    ],
    xmapsto: [
        [
            "leftmapsto",
            "rightarrow"
        ],
        1.5,
        522
    ],
    xtofrom: [
        [
            "leftToFrom",
            "rightToFrom"
        ],
        1.75,
        528
    ],
    xrightleftarrows: [
        [
            "baraboveleftarrow",
            "rightarrowabovebar"
        ],
        1.75,
        901
    ],
    xrightequilibrium: [
        [
            "baraboveshortleftharpoon",
            "rightharpoonaboveshortbar"
        ],
        1.75,
        716
    ],
    xleftequilibrium: [
        [
            "shortbaraboveleftharpoon",
            "shortrightharpoonabovebar"
        ],
        1.75,
        716
    ]
};
var groupLength = function groupLength(arg) {
    if (arg.type === "ordgroup") {
        return arg.body.length;
    } else {
        return 1;
    }
};
var svgSpan = function svgSpan(group, options) {
    function buildSvgSpan_() {
        var viewBoxWidth = 400000;
        var label = group.label.slice(1);
        if (utils.contains([
            "widehat",
            "widecheck",
            "widetilde",
            "utilde"
        ], label)) {
            var grp = group;
            var numChars = groupLength(grp.base);
            var viewBoxHeight;
            var pathName;
            var _height;
            if (numChars > 5) {
                if (label === "widehat" || label === "widecheck") {
                    viewBoxHeight = 420;
                    viewBoxWidth = 2364;
                    _height = 0.42;
                    pathName = label + "4";
                } else {
                    viewBoxHeight = 312;
                    viewBoxWidth = 2340;
                    _height = 0.34;
                    pathName = "tilde4";
                }
            } else {
                var imgIndex = [
                    1,
                    1,
                    2,
                    2,
                    3,
                    3
                ][numChars];
                if (label === "widehat" || label === "widecheck") {
                    viewBoxWidth = [
                        0,
                        1062,
                        2364,
                        2364,
                        2364
                    ][imgIndex];
                    viewBoxHeight = [
                        0,
                        239,
                        300,
                        360,
                        420
                    ][imgIndex];
                    _height = [
                        0,
                        0.24,
                        0.3,
                        0.3,
                        0.36,
                        0.42
                    ][imgIndex];
                    pathName = label + imgIndex;
                } else {
                    viewBoxWidth = [
                        0,
                        600,
                        1033,
                        2339,
                        2340
                    ][imgIndex];
                    viewBoxHeight = [
                        0,
                        260,
                        286,
                        306,
                        312
                    ][imgIndex];
                    _height = [
                        0,
                        0.26,
                        0.286,
                        0.3,
                        0.306,
                        0.34
                    ][imgIndex];
                    pathName = "tilde" + imgIndex;
                }
            }
            var path = new PathNode(pathName);
            var svgNode = new SvgNode([
                path
            ], {
                "width": "100%",
                "height": makeEm(_height),
                "viewBox": "0 0 " + viewBoxWidth + " " + viewBoxHeight,
                "preserveAspectRatio": "none"
            });
            return {
                span: buildCommon.makeSvgSpan([], [
                    svgNode
                ], options),
                minWidth: 0,
                height: _height
            };
        } else {
            var spans = [];
            var data = katexImagesData[label];
            var [paths, _minWidth, _viewBoxHeight] = data;
            var _height2 = _viewBoxHeight / 1000;
            var numSvgChildren = paths.length;
            var widthClasses;
            var aligns;
            if (numSvgChildren === 1) {
                var align1 = data[3];
                widthClasses = [
                    "hide-tail"
                ];
                aligns = [
                    align1
                ];
            } else if (numSvgChildren === 2) {
                widthClasses = [
                    "halfarrow-left",
                    "halfarrow-right"
                ];
                aligns = [
                    "xMinYMin",
                    "xMaxYMin"
                ];
            } else if (numSvgChildren === 3) {
                widthClasses = [
                    "brace-left",
                    "brace-center",
                    "brace-right"
                ];
                aligns = [
                    "xMinYMin",
                    "xMidYMin",
                    "xMaxYMin"
                ];
            } else {
                throw new Error("Correct katexImagesData or update code here to support\n                    " + numSvgChildren + " children.");
            }
            for(var i = 0; i < numSvgChildren; i++){
                var _path = new PathNode(paths[i]);
                var _svgNode = new SvgNode([
                    _path
                ], {
                    "width": "400em",
                    "height": makeEm(_height2),
                    "viewBox": "0 0 " + viewBoxWidth + " " + _viewBoxHeight,
                    "preserveAspectRatio": aligns[i] + " slice"
                });
                var _span = buildCommon.makeSvgSpan([
                    widthClasses[i]
                ], [
                    _svgNode
                ], options);
                if (numSvgChildren === 1) {
                    return {
                        span: _span,
                        minWidth: _minWidth,
                        height: _height2
                    };
                } else {
                    _span.style.height = makeEm(_height2);
                    spans.push(_span);
                }
            }
            return {
                span: buildCommon.makeSpan([
                    "stretchy"
                ], spans, options),
                minWidth: _minWidth,
                height: _height2
            };
        }
    }
    var { span , minWidth , height  } = buildSvgSpan_();
    span.height = height;
    span.style.height = makeEm(height);
    if (minWidth > 0) {
        span.style.minWidth = makeEm(minWidth);
    }
    return span;
};
var encloseSpan = function encloseSpan(inner, label, topPad, bottomPad, options) {
    var img;
    var totalHeight = inner.height + inner.depth + topPad + bottomPad;
    if (/fbox|color|angl/.test(label)) {
        img = buildCommon.makeSpan([
            "stretchy",
            label
        ], [], options);
        if (label === "fbox") {
            var color = options.color && options.getColor();
            if (color) {
                img.style.borderColor = color;
            }
        }
    } else {
        var lines = [];
        if (/^[bx]cancel$/.test(label)) {
            lines.push(new LineNode({
                "x1": "0",
                "y1": "0",
                "x2": "100%",
                "y2": "100%",
                "stroke-width": "0.046em"
            }));
        }
        if (/^x?cancel$/.test(label)) {
            lines.push(new LineNode({
                "x1": "0",
                "y1": "100%",
                "x2": "100%",
                "y2": "0",
                "stroke-width": "0.046em"
            }));
        }
        var svgNode = new SvgNode(lines, {
            "width": "100%",
            "height": makeEm(totalHeight)
        });
        img = buildCommon.makeSvgSpan([], [
            svgNode
        ], options);
    }
    img.height = totalHeight;
    img.style.height = makeEm(totalHeight);
    return img;
};
var stretchy = {
    encloseSpan,
    mathMLnode,
    svgSpan
};
function assertNodeType(node, type) {
    if (!node || node.type !== type) {
        throw new Error("Expected node of type " + type + ", but got " + (node ? "node of type " + node.type : String(node)));
    }
    return node;
}
function assertSymbolNodeType(node) {
    var typedNode = checkSymbolNodeType(node);
    if (!typedNode) {
        throw new Error("Expected node of symbol group type, but got " + (node ? "node of type " + node.type : String(node)));
    }
    return typedNode;
}
function checkSymbolNodeType(node) {
    if (node && (node.type === "atom" || NON_ATOMS.hasOwnProperty(node.type))) {
        return node;
    }
    return null;
}
var htmlBuilder$a = (grp, options)=>{
    var base;
    var group;
    var supSubGroup;
    if (grp && grp.type === "supsub") {
        group = assertNodeType(grp.base, "accent");
        base = group.base;
        grp.base = base;
        supSubGroup = assertSpan(buildGroup$1(grp, options));
        grp.base = group;
    } else {
        group = assertNodeType(grp, "accent");
        base = group.base;
    }
    var body = buildGroup$1(base, options.havingCrampedStyle());
    var mustShift = group.isShifty && utils.isCharacterBox(base);
    var skew = 0;
    if (mustShift) {
        var baseChar = utils.getBaseElem(base);
        var baseGroup = buildGroup$1(baseChar, options.havingCrampedStyle());
        skew = assertSymbolDomNode(baseGroup).skew;
    }
    var accentBelow = group.label === "\\c";
    var clearance = accentBelow ? body.height + body.depth : Math.min(body.height, options.fontMetrics().xHeight);
    var accentBody;
    if (!group.isStretchy) {
        var accent;
        var width;
        if (group.label === "\\vec") {
            accent = buildCommon.staticSvg("vec", options);
            width = buildCommon.svgData.vec[1];
        } else {
            accent = buildCommon.makeOrd({
                mode: group.mode,
                text: group.label
            }, options, "textord");
            accent = assertSymbolDomNode(accent);
            accent.italic = 0;
            width = accent.width;
            if (accentBelow) {
                clearance += accent.depth;
            }
        }
        accentBody = buildCommon.makeSpan([
            "accent-body"
        ], [
            accent
        ]);
        var accentFull = group.label === "\\textcircled";
        if (accentFull) {
            accentBody.classes.push('accent-full');
            clearance = body.height;
        }
        var left = skew;
        if (!accentFull) {
            left -= width / 2;
        }
        accentBody.style.left = makeEm(left);
        if (group.label === "\\textcircled") {
            accentBody.style.top = ".2em";
        }
        accentBody = buildCommon.makeVList({
            positionType: "firstBaseline",
            children: [
                {
                    type: "elem",
                    elem: body
                },
                {
                    type: "kern",
                    size: -clearance
                },
                {
                    type: "elem",
                    elem: accentBody
                }
            ]
        }, options);
    } else {
        accentBody = stretchy.svgSpan(group, options);
        accentBody = buildCommon.makeVList({
            positionType: "firstBaseline",
            children: [
                {
                    type: "elem",
                    elem: body
                },
                {
                    type: "elem",
                    elem: accentBody,
                    wrapperClasses: [
                        "svg-align"
                    ],
                    wrapperStyle: skew > 0 ? {
                        width: "calc(100% - " + makeEm(2 * skew) + ")",
                        marginLeft: makeEm(2 * skew)
                    } : undefined
                }
            ]
        }, options);
    }
    var accentWrap = buildCommon.makeSpan([
        "mord",
        "accent"
    ], [
        accentBody
    ], options);
    if (supSubGroup) {
        supSubGroup.children[0] = accentWrap;
        supSubGroup.height = Math.max(accentWrap.height, supSubGroup.height);
        supSubGroup.classes[0] = "mord";
        return supSubGroup;
    } else {
        return accentWrap;
    }
};
var mathmlBuilder$9 = (group, options)=>{
    var accentNode = group.isStretchy ? stretchy.mathMLnode(group.label) : new mathMLTree.MathNode("mo", [
        makeText(group.label, group.mode)
    ]);
    var node = new mathMLTree.MathNode("mover", [
        buildGroup(group.base, options),
        accentNode
    ]);
    node.setAttribute("accent", "true");
    return node;
};
var NON_STRETCHY_ACCENT_REGEX = new RegExp([
    "\\acute",
    "\\grave",
    "\\ddot",
    "\\tilde",
    "\\bar",
    "\\breve",
    "\\check",
    "\\hat",
    "\\vec",
    "\\dot",
    "\\mathring"
].map((accent)=>"\\" + accent).join("|"));
defineFunction({
    type: "accent",
    names: [
        "\\acute",
        "\\grave",
        "\\ddot",
        "\\tilde",
        "\\bar",
        "\\breve",
        "\\check",
        "\\hat",
        "\\vec",
        "\\dot",
        "\\mathring",
        "\\widecheck",
        "\\widehat",
        "\\widetilde",
        "\\overrightarrow",
        "\\overleftarrow",
        "\\Overrightarrow",
        "\\overleftrightarrow",
        "\\overgroup",
        "\\overlinesegment",
        "\\overleftharpoon",
        "\\overrightharpoon"
    ],
    props: {
        numArgs: 1
    },
    handler: (context, args)=>{
        var base = normalizeArgument(args[0]);
        var isStretchy = !NON_STRETCHY_ACCENT_REGEX.test(context.funcName);
        var isShifty = !isStretchy || context.funcName === "\\widehat" || context.funcName === "\\widetilde" || context.funcName === "\\widecheck";
        return {
            type: "accent",
            mode: context.parser.mode,
            label: context.funcName,
            isStretchy: isStretchy,
            isShifty: isShifty,
            base: base
        };
    },
    htmlBuilder: htmlBuilder$a,
    mathmlBuilder: mathmlBuilder$9
});
defineFunction({
    type: "accent",
    names: [
        "\\'",
        "\\`",
        "\\^",
        "\\~",
        "\\=",
        "\\u",
        "\\.",
        '\\"',
        "\\c",
        "\\r",
        "\\H",
        "\\v",
        "\\textcircled"
    ],
    props: {
        numArgs: 1,
        allowedInText: true,
        allowedInMath: true,
        argTypes: [
            "primitive"
        ]
    },
    handler: (context, args)=>{
        var base = args[0];
        var mode = context.parser.mode;
        if (mode === "math") {
            context.parser.settings.reportNonstrict("mathVsTextAccents", "LaTeX's accent " + context.funcName + " works only in text mode");
            mode = "text";
        }
        return {
            type: "accent",
            mode: mode,
            label: context.funcName,
            isStretchy: false,
            isShifty: true,
            base: base
        };
    },
    htmlBuilder: htmlBuilder$a,
    mathmlBuilder: mathmlBuilder$9
});
defineFunction({
    type: "accentUnder",
    names: [
        "\\underleftarrow",
        "\\underrightarrow",
        "\\underleftrightarrow",
        "\\undergroup",
        "\\underlinesegment",
        "\\utilde"
    ],
    props: {
        numArgs: 1
    },
    handler: (_ref, args)=>{
        var { parser , funcName  } = _ref;
        var base = args[0];
        return {
            type: "accentUnder",
            mode: parser.mode,
            label: funcName,
            base: base
        };
    },
    htmlBuilder: (group, options)=>{
        var innerGroup = buildGroup$1(group.base, options);
        var accentBody = stretchy.svgSpan(group, options);
        var kern = group.label === "\\utilde" ? 0.12 : 0;
        var vlist = buildCommon.makeVList({
            positionType: "top",
            positionData: innerGroup.height,
            children: [
                {
                    type: "elem",
                    elem: accentBody,
                    wrapperClasses: [
                        "svg-align"
                    ]
                },
                {
                    type: "kern",
                    size: kern
                },
                {
                    type: "elem",
                    elem: innerGroup
                }
            ]
        }, options);
        return buildCommon.makeSpan([
            "mord",
            "accentunder"
        ], [
            vlist
        ], options);
    },
    mathmlBuilder: (group, options)=>{
        var accentNode = stretchy.mathMLnode(group.label);
        var node = new mathMLTree.MathNode("munder", [
            buildGroup(group.base, options),
            accentNode
        ]);
        node.setAttribute("accentunder", "true");
        return node;
    }
});
var paddedNode = (group)=>{
    var node = new mathMLTree.MathNode("mpadded", group ? [
        group
    ] : []);
    node.setAttribute("width", "+0.6em");
    node.setAttribute("lspace", "0.3em");
    return node;
};
defineFunction({
    type: "xArrow",
    names: [
        "\\xleftarrow",
        "\\xrightarrow",
        "\\xLeftarrow",
        "\\xRightarrow",
        "\\xleftrightarrow",
        "\\xLeftrightarrow",
        "\\xhookleftarrow",
        "\\xhookrightarrow",
        "\\xmapsto",
        "\\xrightharpoondown",
        "\\xrightharpoonup",
        "\\xleftharpoondown",
        "\\xleftharpoonup",
        "\\xrightleftharpoons",
        "\\xleftrightharpoons",
        "\\xlongequal",
        "\\xtwoheadrightarrow",
        "\\xtwoheadleftarrow",
        "\\xtofrom",
        "\\xrightleftarrows",
        "\\xrightequilibrium",
        "\\xleftequilibrium",
        "\\\\cdrightarrow",
        "\\\\cdleftarrow",
        "\\\\cdlongequal"
    ],
    props: {
        numArgs: 1,
        numOptionalArgs: 1
    },
    handler (_ref, args, optArgs) {
        var { parser , funcName  } = _ref;
        return {
            type: "xArrow",
            mode: parser.mode,
            label: funcName,
            body: args[0],
            below: optArgs[0]
        };
    },
    htmlBuilder (group, options) {
        var style = options.style;
        var newOptions = options.havingStyle(style.sup());
        var upperGroup = buildCommon.wrapFragment(buildGroup$1(group.body, newOptions, options), options);
        var arrowPrefix = group.label.slice(0, 2) === "\\x" ? "x" : "cd";
        upperGroup.classes.push(arrowPrefix + "-arrow-pad");
        var lowerGroup;
        if (group.below) {
            newOptions = options.havingStyle(style.sub());
            lowerGroup = buildCommon.wrapFragment(buildGroup$1(group.below, newOptions, options), options);
            lowerGroup.classes.push(arrowPrefix + "-arrow-pad");
        }
        var arrowBody = stretchy.svgSpan(group, options);
        var arrowShift = -options.fontMetrics().axisHeight + 0.5 * arrowBody.height;
        var upperShift = -options.fontMetrics().axisHeight - 0.5 * arrowBody.height - 0.111;
        if (upperGroup.depth > 0.25 || group.label === "\\xleftequilibrium") {
            upperShift -= upperGroup.depth;
        }
        var vlist;
        if (lowerGroup) {
            var lowerShift = -options.fontMetrics().axisHeight + lowerGroup.height + 0.5 * arrowBody.height + 0.111;
            vlist = buildCommon.makeVList({
                positionType: "individualShift",
                children: [
                    {
                        type: "elem",
                        elem: upperGroup,
                        shift: upperShift
                    },
                    {
                        type: "elem",
                        elem: arrowBody,
                        shift: arrowShift
                    },
                    {
                        type: "elem",
                        elem: lowerGroup,
                        shift: lowerShift
                    }
                ]
            }, options);
        } else {
            vlist = buildCommon.makeVList({
                positionType: "individualShift",
                children: [
                    {
                        type: "elem",
                        elem: upperGroup,
                        shift: upperShift
                    },
                    {
                        type: "elem",
                        elem: arrowBody,
                        shift: arrowShift
                    }
                ]
            }, options);
        }
        vlist.children[0].children[0].children[1].classes.push("svg-align");
        return buildCommon.makeSpan([
            "mrel",
            "x-arrow"
        ], [
            vlist
        ], options);
    },
    mathmlBuilder (group, options) {
        var arrowNode = stretchy.mathMLnode(group.label);
        arrowNode.setAttribute("minsize", group.label.charAt(0) === "x" ? "1.75em" : "3.0em");
        var node;
        if (group.body) {
            var upperNode = paddedNode(buildGroup(group.body, options));
            if (group.below) {
                var lowerNode = paddedNode(buildGroup(group.below, options));
                node = new mathMLTree.MathNode("munderover", [
                    arrowNode,
                    lowerNode,
                    upperNode
                ]);
            } else {
                node = new mathMLTree.MathNode("mover", [
                    arrowNode,
                    upperNode
                ]);
            }
        } else if (group.below) {
            var _lowerNode = paddedNode(buildGroup(group.below, options));
            node = new mathMLTree.MathNode("munder", [
                arrowNode,
                _lowerNode
            ]);
        } else {
            node = paddedNode();
            node = new mathMLTree.MathNode("mover", [
                arrowNode,
                node
            ]);
        }
        return node;
    }
});
var makeSpan = buildCommon.makeSpan;
function htmlBuilder$9(group, options) {
    var elements = buildExpression$1(group.body, options, true);
    return makeSpan([
        group.mclass
    ], elements, options);
}
function mathmlBuilder$8(group, options) {
    var node;
    var inner = buildExpression(group.body, options);
    if (group.mclass === "minner") {
        node = new mathMLTree.MathNode("mpadded", inner);
    } else if (group.mclass === "mord") {
        if (group.isCharacterBox) {
            node = inner[0];
            node.type = "mi";
        } else {
            node = new mathMLTree.MathNode("mi", inner);
        }
    } else {
        if (group.isCharacterBox) {
            node = inner[0];
            node.type = "mo";
        } else {
            node = new mathMLTree.MathNode("mo", inner);
        }
        if (group.mclass === "mbin") {
            node.attributes.lspace = "0.22em";
            node.attributes.rspace = "0.22em";
        } else if (group.mclass === "mpunct") {
            node.attributes.lspace = "0em";
            node.attributes.rspace = "0.17em";
        } else if (group.mclass === "mopen" || group.mclass === "mclose") {
            node.attributes.lspace = "0em";
            node.attributes.rspace = "0em";
        } else if (group.mclass === "minner") {
            node.attributes.lspace = "0.0556em";
            node.attributes.width = "+0.1111em";
        }
    }
    return node;
}
defineFunction({
    type: "mclass",
    names: [
        "\\mathord",
        "\\mathbin",
        "\\mathrel",
        "\\mathopen",
        "\\mathclose",
        "\\mathpunct",
        "\\mathinner"
    ],
    props: {
        numArgs: 1,
        primitive: true
    },
    handler (_ref, args) {
        var { parser , funcName  } = _ref;
        var body = args[0];
        return {
            type: "mclass",
            mode: parser.mode,
            mclass: "m" + funcName.slice(5),
            body: ordargument(body),
            isCharacterBox: utils.isCharacterBox(body)
        };
    },
    htmlBuilder: htmlBuilder$9,
    mathmlBuilder: mathmlBuilder$8
});
var binrelClass = (arg)=>{
    var atom = arg.type === "ordgroup" && arg.body.length ? arg.body[0] : arg;
    if (atom.type === "atom" && (atom.family === "bin" || atom.family === "rel")) {
        return "m" + atom.family;
    } else {
        return "mord";
    }
};
defineFunction({
    type: "mclass",
    names: [
        "\\@binrel"
    ],
    props: {
        numArgs: 2
    },
    handler (_ref2, args) {
        var { parser  } = _ref2;
        return {
            type: "mclass",
            mode: parser.mode,
            mclass: binrelClass(args[0]),
            body: ordargument(args[1]),
            isCharacterBox: utils.isCharacterBox(args[1])
        };
    }
});
defineFunction({
    type: "mclass",
    names: [
        "\\stackrel",
        "\\overset",
        "\\underset"
    ],
    props: {
        numArgs: 2
    },
    handler (_ref3, args) {
        var { parser , funcName  } = _ref3;
        var baseArg = args[1];
        var shiftedArg = args[0];
        var mclass;
        if (funcName !== "\\stackrel") {
            mclass = binrelClass(baseArg);
        } else {
            mclass = "mrel";
        }
        var baseOp = {
            type: "op",
            mode: baseArg.mode,
            limits: true,
            alwaysHandleSupSub: true,
            parentIsSupSub: false,
            symbol: false,
            suppressBaseShift: funcName !== "\\stackrel",
            body: ordargument(baseArg)
        };
        var supsub = {
            type: "supsub",
            mode: shiftedArg.mode,
            base: baseOp,
            sup: funcName === "\\underset" ? null : shiftedArg,
            sub: funcName === "\\underset" ? shiftedArg : null
        };
        return {
            type: "mclass",
            mode: parser.mode,
            mclass,
            body: [
                supsub
            ],
            isCharacterBox: utils.isCharacterBox(supsub)
        };
    },
    htmlBuilder: htmlBuilder$9,
    mathmlBuilder: mathmlBuilder$8
});
defineFunction({
    type: "pmb",
    names: [
        "\\pmb"
    ],
    props: {
        numArgs: 1,
        allowedInText: true
    },
    handler (_ref, args) {
        var { parser  } = _ref;
        return {
            type: "pmb",
            mode: parser.mode,
            mclass: binrelClass(args[0]),
            body: ordargument(args[0])
        };
    },
    htmlBuilder (group, options) {
        var elements = buildExpression$1(group.body, options, true);
        var node = buildCommon.makeSpan([
            group.mclass
        ], elements, options);
        node.style.textShadow = "0.02em 0.01em 0.04px";
        return node;
    },
    mathmlBuilder (group, style) {
        var inner = buildExpression(group.body, style);
        var node = new mathMLTree.MathNode("mstyle", inner);
        node.setAttribute("style", "text-shadow: 0.02em 0.01em 0.04px");
        return node;
    }
});
var cdArrowFunctionName = {
    ">": "\\\\cdrightarrow",
    "<": "\\\\cdleftarrow",
    "=": "\\\\cdlongequal",
    "A": "\\uparrow",
    "V": "\\downarrow",
    "|": "\\Vert",
    ".": "no arrow"
};
var newCell = ()=>{
    return {
        type: "styling",
        body: [],
        mode: "math",
        style: "display"
    };
};
var isStartOfArrow = (node)=>{
    return node.type === "textord" && node.text === "@";
};
var isLabelEnd = (node, endChar)=>{
    return (node.type === "mathord" || node.type === "atom") && node.text === endChar;
};
function cdArrow(arrowChar, labels, parser) {
    var funcName = cdArrowFunctionName[arrowChar];
    switch(funcName){
        case "\\\\cdrightarrow":
        case "\\\\cdleftarrow":
            return parser.callFunction(funcName, [
                labels[0]
            ], [
                labels[1]
            ]);
        case "\\uparrow":
        case "\\downarrow":
            {
                var leftLabel = parser.callFunction("\\\\cdleft", [
                    labels[0]
                ], []);
                var bareArrow = {
                    type: "atom",
                    text: funcName,
                    mode: "math",
                    family: "rel"
                };
                var sizedArrow = parser.callFunction("\\Big", [
                    bareArrow
                ], []);
                var rightLabel = parser.callFunction("\\\\cdright", [
                    labels[1]
                ], []);
                var arrowGroup = {
                    type: "ordgroup",
                    mode: "math",
                    body: [
                        leftLabel,
                        sizedArrow,
                        rightLabel
                    ]
                };
                return parser.callFunction("\\\\cdparent", [
                    arrowGroup
                ], []);
            }
        case "\\\\cdlongequal":
            return parser.callFunction("\\\\cdlongequal", [], []);
        case "\\Vert":
            {
                var arrow = {
                    type: "textord",
                    text: "\\Vert",
                    mode: "math"
                };
                return parser.callFunction("\\Big", [
                    arrow
                ], []);
            }
        default:
            return {
                type: "textord",
                text: " ",
                mode: "math"
            };
    }
}
function parseCD(parser) {
    var parsedRows = [];
    parser.gullet.beginGroup();
    parser.gullet.macros.set("\\cr", "\\\\\\relax");
    parser.gullet.beginGroup();
    while(true){
        parsedRows.push(parser.parseExpression(false, "\\\\"));
        parser.gullet.endGroup();
        parser.gullet.beginGroup();
        var next = parser.fetch().text;
        if (next === "&" || next === "\\\\") {
            parser.consume();
        } else if (next === "\\end") {
            if (parsedRows[parsedRows.length - 1].length === 0) {
                parsedRows.pop();
            }
            break;
        } else {
            throw new ParseError("Expected \\\\ or \\cr or \\end", parser.nextToken);
        }
    }
    var row = [];
    var body = [
        row
    ];
    for(var i = 0; i < parsedRows.length; i++){
        var rowNodes = parsedRows[i];
        var cell = newCell();
        for(var j = 0; j < rowNodes.length; j++){
            if (!isStartOfArrow(rowNodes[j])) {
                cell.body.push(rowNodes[j]);
            } else {
                row.push(cell);
                j += 1;
                var arrowChar = assertSymbolNodeType(rowNodes[j]).text;
                var labels = new Array(2);
                labels[0] = {
                    type: "ordgroup",
                    mode: "math",
                    body: []
                };
                labels[1] = {
                    type: "ordgroup",
                    mode: "math",
                    body: []
                };
                if ("=|.".indexOf(arrowChar) > -1) ;
                else if ("<>AV".indexOf(arrowChar) > -1) {
                    for(var labelNum = 0; labelNum < 2; labelNum++){
                        var inLabel = true;
                        for(var k = j + 1; k < rowNodes.length; k++){
                            if (isLabelEnd(rowNodes[k], arrowChar)) {
                                inLabel = false;
                                j = k;
                                break;
                            }
                            if (isStartOfArrow(rowNodes[k])) {
                                throw new ParseError("Missing a " + arrowChar + " character to complete a CD arrow.", rowNodes[k]);
                            }
                            labels[labelNum].body.push(rowNodes[k]);
                        }
                        if (inLabel) {
                            throw new ParseError("Missing a " + arrowChar + " character to complete a CD arrow.", rowNodes[j]);
                        }
                    }
                } else {
                    throw new ParseError("Expected one of \"<>AV=|.\" after @", rowNodes[j]);
                }
                var arrow = cdArrow(arrowChar, labels, parser);
                var wrappedArrow = {
                    type: "styling",
                    body: [
                        arrow
                    ],
                    mode: "math",
                    style: "display"
                };
                row.push(wrappedArrow);
                cell = newCell();
            }
        }
        if (i % 2 === 0) {
            row.push(cell);
        } else {
            row.shift();
        }
        row = [];
        body.push(row);
    }
    parser.gullet.endGroup();
    parser.gullet.endGroup();
    var cols = new Array(body[0].length).fill({
        type: "align",
        align: "c",
        pregap: 0.25,
        postgap: 0.25
    });
    return {
        type: "array",
        mode: "math",
        body,
        arraystretch: 1,
        addJot: true,
        rowGaps: [
            null
        ],
        cols,
        colSeparationType: "CD",
        hLinesBeforeRow: new Array(body.length + 1).fill([])
    };
}
defineFunction({
    type: "cdlabel",
    names: [
        "\\\\cdleft",
        "\\\\cdright"
    ],
    props: {
        numArgs: 1
    },
    handler (_ref, args) {
        var { parser , funcName  } = _ref;
        return {
            type: "cdlabel",
            mode: parser.mode,
            side: funcName.slice(4),
            label: args[0]
        };
    },
    htmlBuilder (group, options) {
        var newOptions = options.havingStyle(options.style.sup());
        var label = buildCommon.wrapFragment(buildGroup$1(group.label, newOptions, options), options);
        label.classes.push("cd-label-" + group.side);
        label.style.bottom = makeEm(0.8 - label.depth);
        label.height = 0;
        label.depth = 0;
        return label;
    },
    mathmlBuilder (group, options) {
        var label = new mathMLTree.MathNode("mrow", [
            buildGroup(group.label, options)
        ]);
        label = new mathMLTree.MathNode("mpadded", [
            label
        ]);
        label.setAttribute("width", "0");
        if (group.side === "left") {
            label.setAttribute("lspace", "-1width");
        }
        label.setAttribute("voffset", "0.7em");
        label = new mathMLTree.MathNode("mstyle", [
            label
        ]);
        label.setAttribute("displaystyle", "false");
        label.setAttribute("scriptlevel", "1");
        return label;
    }
});
defineFunction({
    type: "cdlabelparent",
    names: [
        "\\\\cdparent"
    ],
    props: {
        numArgs: 1
    },
    handler (_ref2, args) {
        var { parser  } = _ref2;
        return {
            type: "cdlabelparent",
            mode: parser.mode,
            fragment: args[0]
        };
    },
    htmlBuilder (group, options) {
        var parent = buildCommon.wrapFragment(buildGroup$1(group.fragment, options), options);
        parent.classes.push("cd-vert-arrow");
        return parent;
    },
    mathmlBuilder (group, options) {
        return new mathMLTree.MathNode("mrow", [
            buildGroup(group.fragment, options)
        ]);
    }
});
defineFunction({
    type: "textord",
    names: [
        "\\@char"
    ],
    props: {
        numArgs: 1,
        allowedInText: true
    },
    handler (_ref, args) {
        var { parser  } = _ref;
        var arg = assertNodeType(args[0], "ordgroup");
        var group = arg.body;
        var number = "";
        for(var i = 0; i < group.length; i++){
            var node = assertNodeType(group[i], "textord");
            number += node.text;
        }
        var code = parseInt(number);
        var text;
        if (isNaN(code)) {
            throw new ParseError("\\@char has non-numeric argument " + number);
        } else if (code < 0 || code >= 0x10ffff) {
            throw new ParseError("\\@char with invalid code point " + number);
        } else if (code <= 0xffff) {
            text = String.fromCharCode(code);
        } else {
            code -= 0x10000;
            text = String.fromCharCode((code >> 10) + 0xd800, (code & 0x3ff) + 0xdc00);
        }
        return {
            type: "textord",
            mode: parser.mode,
            text: text
        };
    }
});
var htmlBuilder$8 = (group, options)=>{
    var elements = buildExpression$1(group.body, options.withColor(group.color), false);
    return buildCommon.makeFragment(elements);
};
var mathmlBuilder$7 = (group, options)=>{
    var inner = buildExpression(group.body, options.withColor(group.color));
    var node = new mathMLTree.MathNode("mstyle", inner);
    node.setAttribute("mathcolor", group.color);
    return node;
};
defineFunction({
    type: "color",
    names: [
        "\\textcolor"
    ],
    props: {
        numArgs: 2,
        allowedInText: true,
        argTypes: [
            "color",
            "original"
        ]
    },
    handler (_ref, args) {
        var { parser  } = _ref;
        var color = assertNodeType(args[0], "color-token").color;
        var body = args[1];
        return {
            type: "color",
            mode: parser.mode,
            color,
            body: ordargument(body)
        };
    },
    htmlBuilder: htmlBuilder$8,
    mathmlBuilder: mathmlBuilder$7
});
defineFunction({
    type: "color",
    names: [
        "\\color"
    ],
    props: {
        numArgs: 1,
        allowedInText: true,
        argTypes: [
            "color"
        ]
    },
    handler (_ref2, args) {
        var { parser , breakOnTokenText  } = _ref2;
        var color = assertNodeType(args[0], "color-token").color;
        parser.gullet.macros.set("\\current@color", color);
        var body = parser.parseExpression(true, breakOnTokenText);
        return {
            type: "color",
            mode: parser.mode,
            color,
            body
        };
    },
    htmlBuilder: htmlBuilder$8,
    mathmlBuilder: mathmlBuilder$7
});
defineFunction({
    type: "cr",
    names: [
        "\\\\"
    ],
    props: {
        numArgs: 0,
        numOptionalArgs: 0,
        allowedInText: true
    },
    handler (_ref, args, optArgs) {
        var { parser  } = _ref;
        var size = parser.gullet.future().text === "[" ? parser.parseSizeGroup(true) : null;
        var newLine = !parser.settings.displayMode || !parser.settings.useStrictBehavior("newLineInDisplayMode", "In LaTeX, \\\\ or \\newline " + "does nothing in display mode");
        return {
            type: "cr",
            mode: parser.mode,
            newLine,
            size: size && assertNodeType(size, "size").value
        };
    },
    htmlBuilder (group, options) {
        var span = buildCommon.makeSpan([
            "mspace"
        ], [], options);
        if (group.newLine) {
            span.classes.push("newline");
            if (group.size) {
                span.style.marginTop = makeEm(calculateSize(group.size, options));
            }
        }
        return span;
    },
    mathmlBuilder (group, options) {
        var node = new mathMLTree.MathNode("mspace");
        if (group.newLine) {
            node.setAttribute("linebreak", "newline");
            if (group.size) {
                node.setAttribute("height", makeEm(calculateSize(group.size, options)));
            }
        }
        return node;
    }
});
var globalMap = {
    "\\global": "\\global",
    "\\long": "\\\\globallong",
    "\\\\globallong": "\\\\globallong",
    "\\def": "\\gdef",
    "\\gdef": "\\gdef",
    "\\edef": "\\xdef",
    "\\xdef": "\\xdef",
    "\\let": "\\\\globallet",
    "\\futurelet": "\\\\globalfuture"
};
var checkControlSequence = (tok)=>{
    var name = tok.text;
    if (/^(?:[\\{}$&#^_]|EOF)$/.test(name)) {
        throw new ParseError("Expected a control sequence", tok);
    }
    return name;
};
var getRHS = (parser)=>{
    var tok = parser.gullet.popToken();
    if (tok.text === "=") {
        tok = parser.gullet.popToken();
        if (tok.text === " ") {
            tok = parser.gullet.popToken();
        }
    }
    return tok;
};
var letCommand = (parser, name, tok, global)=>{
    var macro = parser.gullet.macros.get(tok.text);
    if (macro == null) {
        tok.noexpand = true;
        macro = {
            tokens: [
                tok
            ],
            numArgs: 0,
            unexpandable: !parser.gullet.isExpandable(tok.text)
        };
    }
    parser.gullet.macros.set(name, macro, global);
};
defineFunction({
    type: "internal",
    names: [
        "\\global",
        "\\long",
        "\\\\globallong"
    ],
    props: {
        numArgs: 0,
        allowedInText: true
    },
    handler (_ref) {
        var { parser , funcName  } = _ref;
        parser.consumeSpaces();
        var token = parser.fetch();
        if (globalMap[token.text]) {
            if (funcName === "\\global" || funcName === "\\\\globallong") {
                token.text = globalMap[token.text];
            }
            return assertNodeType(parser.parseFunction(), "internal");
        }
        throw new ParseError("Invalid token after macro prefix", token);
    }
});
defineFunction({
    type: "internal",
    names: [
        "\\def",
        "\\gdef",
        "\\edef",
        "\\xdef"
    ],
    props: {
        numArgs: 0,
        allowedInText: true,
        primitive: true
    },
    handler (_ref2) {
        var { parser , funcName  } = _ref2;
        var tok = parser.gullet.popToken();
        var name = tok.text;
        if (/^(?:[\\{}$&#^_]|EOF)$/.test(name)) {
            throw new ParseError("Expected a control sequence", tok);
        }
        var numArgs = 0;
        var insert;
        var delimiters = [
            []
        ];
        while(parser.gullet.future().text !== "{"){
            tok = parser.gullet.popToken();
            if (tok.text === "#") {
                if (parser.gullet.future().text === "{") {
                    insert = parser.gullet.future();
                    delimiters[numArgs].push("{");
                    break;
                }
                tok = parser.gullet.popToken();
                if (!/^[1-9]$/.test(tok.text)) {
                    throw new ParseError("Invalid argument number \"" + tok.text + "\"");
                }
                if (parseInt(tok.text) !== numArgs + 1) {
                    throw new ParseError("Argument number \"" + tok.text + "\" out of order");
                }
                numArgs++;
                delimiters.push([]);
            } else if (tok.text === "EOF") {
                throw new ParseError("Expected a macro definition");
            } else {
                delimiters[numArgs].push(tok.text);
            }
        }
        var { tokens  } = parser.gullet.consumeArg();
        if (insert) {
            tokens.unshift(insert);
        }
        if (funcName === "\\edef" || funcName === "\\xdef") {
            tokens = parser.gullet.expandTokens(tokens);
            tokens.reverse();
        }
        parser.gullet.macros.set(name, {
            tokens,
            numArgs,
            delimiters
        }, funcName === globalMap[funcName]);
        return {
            type: "internal",
            mode: parser.mode
        };
    }
});
defineFunction({
    type: "internal",
    names: [
        "\\let",
        "\\\\globallet"
    ],
    props: {
        numArgs: 0,
        allowedInText: true,
        primitive: true
    },
    handler (_ref3) {
        var { parser , funcName  } = _ref3;
        var name = checkControlSequence(parser.gullet.popToken());
        parser.gullet.consumeSpaces();
        var tok = getRHS(parser);
        letCommand(parser, name, tok, funcName === "\\\\globallet");
        return {
            type: "internal",
            mode: parser.mode
        };
    }
});
defineFunction({
    type: "internal",
    names: [
        "\\futurelet",
        "\\\\globalfuture"
    ],
    props: {
        numArgs: 0,
        allowedInText: true,
        primitive: true
    },
    handler (_ref4) {
        var { parser , funcName  } = _ref4;
        var name = checkControlSequence(parser.gullet.popToken());
        var middle = parser.gullet.popToken();
        var tok = parser.gullet.popToken();
        letCommand(parser, name, tok, funcName === "\\\\globalfuture");
        parser.gullet.pushToken(tok);
        parser.gullet.pushToken(middle);
        return {
            type: "internal",
            mode: parser.mode
        };
    }
});
var getMetrics = function getMetrics(symbol, font, mode) {
    var replace = symbols.math[symbol] && symbols.math[symbol].replace;
    var metrics = getCharacterMetrics(replace || symbol, font, mode);
    if (!metrics) {
        throw new Error("Unsupported symbol " + symbol + " and font size " + font + ".");
    }
    return metrics;
};
var styleWrap = function styleWrap(delim, toStyle, options, classes) {
    var newOptions = options.havingBaseStyle(toStyle);
    var span = buildCommon.makeSpan(classes.concat(newOptions.sizingClasses(options)), [
        delim
    ], options);
    var delimSizeMultiplier = newOptions.sizeMultiplier / options.sizeMultiplier;
    span.height *= delimSizeMultiplier;
    span.depth *= delimSizeMultiplier;
    span.maxFontSize = newOptions.sizeMultiplier;
    return span;
};
var centerSpan = function centerSpan(span, options, style) {
    var newOptions = options.havingBaseStyle(style);
    var shift = (1 - options.sizeMultiplier / newOptions.sizeMultiplier) * options.fontMetrics().axisHeight;
    span.classes.push("delimcenter");
    span.style.top = makeEm(shift);
    span.height -= shift;
    span.depth += shift;
};
var makeSmallDelim = function makeSmallDelim(delim, style, center, options, mode, classes) {
    var text = buildCommon.makeSymbol(delim, "Main-Regular", mode, options);
    var span = styleWrap(text, style, options, classes);
    if (center) {
        centerSpan(span, options, style);
    }
    return span;
};
var mathrmSize = function mathrmSize(value, size, mode, options) {
    return buildCommon.makeSymbol(value, "Size" + size + "-Regular", mode, options);
};
var makeLargeDelim = function makeLargeDelim(delim, size, center, options, mode, classes) {
    var inner = mathrmSize(delim, size, mode, options);
    var span = styleWrap(buildCommon.makeSpan([
        "delimsizing",
        "size" + size
    ], [
        inner
    ], options), Style$1.TEXT, options, classes);
    if (center) {
        centerSpan(span, options, Style$1.TEXT);
    }
    return span;
};
var makeGlyphSpan = function makeGlyphSpan(symbol, font, mode) {
    var sizeClass;
    if (font === "Size1-Regular") {
        sizeClass = "delim-size1";
    } else {
        sizeClass = "delim-size4";
    }
    var corner = buildCommon.makeSpan([
        "delimsizinginner",
        sizeClass
    ], [
        buildCommon.makeSpan([], [
            buildCommon.makeSymbol(symbol, font, mode)
        ])
    ]);
    return {
        type: "elem",
        elem: corner
    };
};
var makeInner = function makeInner(ch, height, options) {
    var width = fontMetricsData['Size4-Regular'][ch.charCodeAt(0)] ? fontMetricsData['Size4-Regular'][ch.charCodeAt(0)][4] : fontMetricsData['Size1-Regular'][ch.charCodeAt(0)][4];
    var path = new PathNode("inner", innerPath(ch, Math.round(1000 * height)));
    var svgNode = new SvgNode([
        path
    ], {
        "width": makeEm(width),
        "height": makeEm(height),
        "style": "width:" + makeEm(width),
        "viewBox": "0 0 " + 1000 * width + " " + Math.round(1000 * height),
        "preserveAspectRatio": "xMinYMin"
    });
    var span = buildCommon.makeSvgSpan([], [
        svgNode
    ], options);
    span.height = height;
    span.style.height = makeEm(height);
    span.style.width = makeEm(width);
    return {
        type: "elem",
        elem: span
    };
};
var lapInEms = 0.008;
var lap = {
    type: "kern",
    size: -1 * lapInEms
};
var verts = [
    "|",
    "\\lvert",
    "\\rvert",
    "\\vert"
];
var doubleVerts = [
    "\\|",
    "\\lVert",
    "\\rVert",
    "\\Vert"
];
var makeStackedDelim = function makeStackedDelim(delim, heightTotal, center, options, mode, classes) {
    var top;
    var middle;
    var repeat;
    var bottom;
    var svgLabel = "";
    var viewBoxWidth = 0;
    top = repeat = bottom = delim;
    middle = null;
    var font = "Size1-Regular";
    if (delim === "\\uparrow") {
        repeat = bottom = "\u23d0";
    } else if (delim === "\\Uparrow") {
        repeat = bottom = "\u2016";
    } else if (delim === "\\downarrow") {
        top = repeat = "\u23d0";
    } else if (delim === "\\Downarrow") {
        top = repeat = "\u2016";
    } else if (delim === "\\updownarrow") {
        top = "\\uparrow";
        repeat = "\u23d0";
        bottom = "\\downarrow";
    } else if (delim === "\\Updownarrow") {
        top = "\\Uparrow";
        repeat = "\u2016";
        bottom = "\\Downarrow";
    } else if (utils.contains(verts, delim)) {
        repeat = "\u2223";
        svgLabel = "vert";
        viewBoxWidth = 333;
    } else if (utils.contains(doubleVerts, delim)) {
        repeat = "\u2225";
        svgLabel = "doublevert";
        viewBoxWidth = 556;
    } else if (delim === "[" || delim === "\\lbrack") {
        top = "\u23a1";
        repeat = "\u23a2";
        bottom = "\u23a3";
        font = "Size4-Regular";
        svgLabel = "lbrack";
        viewBoxWidth = 667;
    } else if (delim === "]" || delim === "\\rbrack") {
        top = "\u23a4";
        repeat = "\u23a5";
        bottom = "\u23a6";
        font = "Size4-Regular";
        svgLabel = "rbrack";
        viewBoxWidth = 667;
    } else if (delim === "\\lfloor" || delim === "\u230a") {
        repeat = top = "\u23a2";
        bottom = "\u23a3";
        font = "Size4-Regular";
        svgLabel = "lfloor";
        viewBoxWidth = 667;
    } else if (delim === "\\lceil" || delim === "\u2308") {
        top = "\u23a1";
        repeat = bottom = "\u23a2";
        font = "Size4-Regular";
        svgLabel = "lceil";
        viewBoxWidth = 667;
    } else if (delim === "\\rfloor" || delim === "\u230b") {
        repeat = top = "\u23a5";
        bottom = "\u23a6";
        font = "Size4-Regular";
        svgLabel = "rfloor";
        viewBoxWidth = 667;
    } else if (delim === "\\rceil" || delim === "\u2309") {
        top = "\u23a4";
        repeat = bottom = "\u23a5";
        font = "Size4-Regular";
        svgLabel = "rceil";
        viewBoxWidth = 667;
    } else if (delim === "(" || delim === "\\lparen") {
        top = "\u239b";
        repeat = "\u239c";
        bottom = "\u239d";
        font = "Size4-Regular";
        svgLabel = "lparen";
        viewBoxWidth = 875;
    } else if (delim === ")" || delim === "\\rparen") {
        top = "\u239e";
        repeat = "\u239f";
        bottom = "\u23a0";
        font = "Size4-Regular";
        svgLabel = "rparen";
        viewBoxWidth = 875;
    } else if (delim === "\\{" || delim === "\\lbrace") {
        top = "\u23a7";
        middle = "\u23a8";
        bottom = "\u23a9";
        repeat = "\u23aa";
        font = "Size4-Regular";
    } else if (delim === "\\}" || delim === "\\rbrace") {
        top = "\u23ab";
        middle = "\u23ac";
        bottom = "\u23ad";
        repeat = "\u23aa";
        font = "Size4-Regular";
    } else if (delim === "\\lgroup" || delim === "\u27ee") {
        top = "\u23a7";
        bottom = "\u23a9";
        repeat = "\u23aa";
        font = "Size4-Regular";
    } else if (delim === "\\rgroup" || delim === "\u27ef") {
        top = "\u23ab";
        bottom = "\u23ad";
        repeat = "\u23aa";
        font = "Size4-Regular";
    } else if (delim === "\\lmoustache" || delim === "\u23b0") {
        top = "\u23a7";
        bottom = "\u23ad";
        repeat = "\u23aa";
        font = "Size4-Regular";
    } else if (delim === "\\rmoustache" || delim === "\u23b1") {
        top = "\u23ab";
        bottom = "\u23a9";
        repeat = "\u23aa";
        font = "Size4-Regular";
    }
    var topMetrics = getMetrics(top, font, mode);
    var topHeightTotal = topMetrics.height + topMetrics.depth;
    var repeatMetrics = getMetrics(repeat, font, mode);
    var repeatHeightTotal = repeatMetrics.height + repeatMetrics.depth;
    var bottomMetrics = getMetrics(bottom, font, mode);
    var bottomHeightTotal = bottomMetrics.height + bottomMetrics.depth;
    var middleHeightTotal = 0;
    var middleFactor = 1;
    if (middle !== null) {
        var middleMetrics = getMetrics(middle, font, mode);
        middleHeightTotal = middleMetrics.height + middleMetrics.depth;
        middleFactor = 2;
    }
    var minHeight = topHeightTotal + bottomHeightTotal + middleHeightTotal;
    var repeatCount = Math.max(0, Math.ceil((heightTotal - minHeight) / (middleFactor * repeatHeightTotal)));
    var realHeightTotal = minHeight + repeatCount * middleFactor * repeatHeightTotal;
    var axisHeight = options.fontMetrics().axisHeight;
    if (center) {
        axisHeight *= options.sizeMultiplier;
    }
    var depth = realHeightTotal / 2 - axisHeight;
    var stack = [];
    if (svgLabel.length > 0) {
        var midHeight = realHeightTotal - topHeightTotal - bottomHeightTotal;
        var viewBoxHeight = Math.round(realHeightTotal * 1000);
        var pathStr = tallDelim(svgLabel, Math.round(midHeight * 1000));
        var path = new PathNode(svgLabel, pathStr);
        var width = (viewBoxWidth / 1000).toFixed(3) + "em";
        var height = (viewBoxHeight / 1000).toFixed(3) + "em";
        var svg = new SvgNode([
            path
        ], {
            "width": width,
            "height": height,
            "viewBox": "0 0 " + viewBoxWidth + " " + viewBoxHeight
        });
        var wrapper = buildCommon.makeSvgSpan([], [
            svg
        ], options);
        wrapper.height = viewBoxHeight / 1000;
        wrapper.style.width = width;
        wrapper.style.height = height;
        stack.push({
            type: "elem",
            elem: wrapper
        });
    } else {
        stack.push(makeGlyphSpan(bottom, font, mode));
        stack.push(lap);
        if (middle === null) {
            var innerHeight = realHeightTotal - topHeightTotal - bottomHeightTotal + 2 * lapInEms;
            stack.push(makeInner(repeat, innerHeight, options));
        } else {
            var _innerHeight = (realHeightTotal - topHeightTotal - bottomHeightTotal - middleHeightTotal) / 2 + 2 * lapInEms;
            stack.push(makeInner(repeat, _innerHeight, options));
            stack.push(lap);
            stack.push(makeGlyphSpan(middle, font, mode));
            stack.push(lap);
            stack.push(makeInner(repeat, _innerHeight, options));
        }
        stack.push(lap);
        stack.push(makeGlyphSpan(top, font, mode));
    }
    var newOptions = options.havingBaseStyle(Style$1.TEXT);
    var inner = buildCommon.makeVList({
        positionType: "bottom",
        positionData: depth,
        children: stack
    }, newOptions);
    return styleWrap(buildCommon.makeSpan([
        "delimsizing",
        "mult"
    ], [
        inner
    ], newOptions), Style$1.TEXT, options, classes);
};
var vbPad = 80;
var emPad = 0.08;
var sqrtSvg = function sqrtSvg(sqrtName, height, viewBoxHeight, extraVinculum, options) {
    var path = sqrtPath(sqrtName, extraVinculum, viewBoxHeight);
    var pathNode = new PathNode(sqrtName, path);
    var svg = new SvgNode([
        pathNode
    ], {
        "width": "400em",
        "height": makeEm(height),
        "viewBox": "0 0 400000 " + viewBoxHeight,
        "preserveAspectRatio": "xMinYMin slice"
    });
    return buildCommon.makeSvgSpan([
        "hide-tail"
    ], [
        svg
    ], options);
};
var makeSqrtImage = function makeSqrtImage(height, options) {
    var newOptions = options.havingBaseSizing();
    var delim = traverseSequence("\\surd", height * newOptions.sizeMultiplier, stackLargeDelimiterSequence, newOptions);
    var sizeMultiplier = newOptions.sizeMultiplier;
    var extraVinculum = Math.max(0, options.minRuleThickness - options.fontMetrics().sqrtRuleThickness);
    var span;
    var spanHeight = 0;
    var texHeight = 0;
    var viewBoxHeight = 0;
    var advanceWidth;
    if (delim.type === "small") {
        viewBoxHeight = 1000 + 1000 * extraVinculum + vbPad;
        if (height < 1.0) {
            sizeMultiplier = 1.0;
        } else if (height < 1.4) {
            sizeMultiplier = 0.7;
        }
        spanHeight = (1.0 + extraVinculum + emPad) / sizeMultiplier;
        texHeight = (1.00 + extraVinculum) / sizeMultiplier;
        span = sqrtSvg("sqrtMain", spanHeight, viewBoxHeight, extraVinculum, options);
        span.style.minWidth = "0.853em";
        advanceWidth = 0.833 / sizeMultiplier;
    } else if (delim.type === "large") {
        viewBoxHeight = (1000 + vbPad) * sizeToMaxHeight[delim.size];
        texHeight = (sizeToMaxHeight[delim.size] + extraVinculum) / sizeMultiplier;
        spanHeight = (sizeToMaxHeight[delim.size] + extraVinculum + emPad) / sizeMultiplier;
        span = sqrtSvg("sqrtSize" + delim.size, spanHeight, viewBoxHeight, extraVinculum, options);
        span.style.minWidth = "1.02em";
        advanceWidth = 1.0 / sizeMultiplier;
    } else {
        spanHeight = height + extraVinculum + emPad;
        texHeight = height + extraVinculum;
        viewBoxHeight = Math.floor(1000 * height + extraVinculum) + vbPad;
        span = sqrtSvg("sqrtTall", spanHeight, viewBoxHeight, extraVinculum, options);
        span.style.minWidth = "0.742em";
        advanceWidth = 1.056;
    }
    span.height = texHeight;
    span.style.height = makeEm(spanHeight);
    return {
        span,
        advanceWidth,
        ruleWidth: (options.fontMetrics().sqrtRuleThickness + extraVinculum) * sizeMultiplier
    };
};
var stackLargeDelimiters = [
    "(",
    "\\lparen",
    ")",
    "\\rparen",
    "[",
    "\\lbrack",
    "]",
    "\\rbrack",
    "\\{",
    "\\lbrace",
    "\\}",
    "\\rbrace",
    "\\lfloor",
    "\\rfloor",
    "\u230a",
    "\u230b",
    "\\lceil",
    "\\rceil",
    "\u2308",
    "\u2309",
    "\\surd"
];
var stackAlwaysDelimiters = [
    "\\uparrow",
    "\\downarrow",
    "\\updownarrow",
    "\\Uparrow",
    "\\Downarrow",
    "\\Updownarrow",
    "|",
    "\\|",
    "\\vert",
    "\\Vert",
    "\\lvert",
    "\\rvert",
    "\\lVert",
    "\\rVert",
    "\\lgroup",
    "\\rgroup",
    "\u27ee",
    "\u27ef",
    "\\lmoustache",
    "\\rmoustache",
    "\u23b0",
    "\u23b1"
];
var stackNeverDelimiters = [
    "<",
    ">",
    "\\langle",
    "\\rangle",
    "/",
    "\\backslash",
    "\\lt",
    "\\gt"
];
var sizeToMaxHeight = [
    0,
    1.2,
    1.8,
    2.4,
    3.0
];
var makeSizedDelim = function makeSizedDelim(delim, size, options, mode, classes) {
    if (delim === "<" || delim === "\\lt" || delim === "\u27e8") {
        delim = "\\langle";
    } else if (delim === ">" || delim === "\\gt" || delim === "\u27e9") {
        delim = "\\rangle";
    }
    if (utils.contains(stackLargeDelimiters, delim) || utils.contains(stackNeverDelimiters, delim)) {
        return makeLargeDelim(delim, size, false, options, mode, classes);
    } else if (utils.contains(stackAlwaysDelimiters, delim)) {
        return makeStackedDelim(delim, sizeToMaxHeight[size], false, options, mode, classes);
    } else {
        throw new ParseError("Illegal delimiter: '" + delim + "'");
    }
};
var stackNeverDelimiterSequence = [
    {
        type: "small",
        style: Style$1.SCRIPTSCRIPT
    },
    {
        type: "small",
        style: Style$1.SCRIPT
    },
    {
        type: "small",
        style: Style$1.TEXT
    },
    {
        type: "large",
        size: 1
    },
    {
        type: "large",
        size: 2
    },
    {
        type: "large",
        size: 3
    },
    {
        type: "large",
        size: 4
    }
];
var stackAlwaysDelimiterSequence = [
    {
        type: "small",
        style: Style$1.SCRIPTSCRIPT
    },
    {
        type: "small",
        style: Style$1.SCRIPT
    },
    {
        type: "small",
        style: Style$1.TEXT
    },
    {
        type: "stack"
    }
];
var stackLargeDelimiterSequence = [
    {
        type: "small",
        style: Style$1.SCRIPTSCRIPT
    },
    {
        type: "small",
        style: Style$1.SCRIPT
    },
    {
        type: "small",
        style: Style$1.TEXT
    },
    {
        type: "large",
        size: 1
    },
    {
        type: "large",
        size: 2
    },
    {
        type: "large",
        size: 3
    },
    {
        type: "large",
        size: 4
    },
    {
        type: "stack"
    }
];
var delimTypeToFont = function delimTypeToFont(type) {
    if (type.type === "small") {
        return "Main-Regular";
    } else if (type.type === "large") {
        return "Size" + type.size + "-Regular";
    } else if (type.type === "stack") {
        return "Size4-Regular";
    } else {
        throw new Error("Add support for delim type '" + type.type + "' here.");
    }
};
var traverseSequence = function traverseSequence(delim, height, sequence, options) {
    var start = Math.min(2, 3 - options.style.size);
    for(var i = start; i < sequence.length; i++){
        if (sequence[i].type === "stack") {
            break;
        }
        var metrics = getMetrics(delim, delimTypeToFont(sequence[i]), "math");
        var heightDepth = metrics.height + metrics.depth;
        if (sequence[i].type === "small") {
            var newOptions = options.havingBaseStyle(sequence[i].style);
            heightDepth *= newOptions.sizeMultiplier;
        }
        if (heightDepth > height) {
            return sequence[i];
        }
    }
    return sequence[sequence.length - 1];
};
var makeCustomSizedDelim = function makeCustomSizedDelim(delim, height, center, options, mode, classes) {
    if (delim === "<" || delim === "\\lt" || delim === "\u27e8") {
        delim = "\\langle";
    } else if (delim === ">" || delim === "\\gt" || delim === "\u27e9") {
        delim = "\\rangle";
    }
    var sequence;
    if (utils.contains(stackNeverDelimiters, delim)) {
        sequence = stackNeverDelimiterSequence;
    } else if (utils.contains(stackLargeDelimiters, delim)) {
        sequence = stackLargeDelimiterSequence;
    } else {
        sequence = stackAlwaysDelimiterSequence;
    }
    var delimType = traverseSequence(delim, height, sequence, options);
    if (delimType.type === "small") {
        return makeSmallDelim(delim, delimType.style, center, options, mode, classes);
    } else if (delimType.type === "large") {
        return makeLargeDelim(delim, delimType.size, center, options, mode, classes);
    } else {
        return makeStackedDelim(delim, height, center, options, mode, classes);
    }
};
var makeLeftRightDelim = function makeLeftRightDelim(delim, height, depth, options, mode, classes) {
    var axisHeight = options.fontMetrics().axisHeight * options.sizeMultiplier;
    var delimiterFactor = 901;
    var delimiterExtend = 5.0 / options.fontMetrics().ptPerEm;
    var maxDistFromAxis = Math.max(height - axisHeight, depth + axisHeight);
    var totalHeight = Math.max(maxDistFromAxis / 500 * delimiterFactor, 2 * maxDistFromAxis - delimiterExtend);
    return makeCustomSizedDelim(delim, totalHeight, true, options, mode, classes);
};
var delimiter = {
    sqrtImage: makeSqrtImage,
    sizedDelim: makeSizedDelim,
    sizeToMaxHeight: sizeToMaxHeight,
    customSizedDelim: makeCustomSizedDelim,
    leftRightDelim: makeLeftRightDelim
};
var delimiterSizes = {
    "\\bigl": {
        mclass: "mopen",
        size: 1
    },
    "\\Bigl": {
        mclass: "mopen",
        size: 2
    },
    "\\biggl": {
        mclass: "mopen",
        size: 3
    },
    "\\Biggl": {
        mclass: "mopen",
        size: 4
    },
    "\\bigr": {
        mclass: "mclose",
        size: 1
    },
    "\\Bigr": {
        mclass: "mclose",
        size: 2
    },
    "\\biggr": {
        mclass: "mclose",
        size: 3
    },
    "\\Biggr": {
        mclass: "mclose",
        size: 4
    },
    "\\bigm": {
        mclass: "mrel",
        size: 1
    },
    "\\Bigm": {
        mclass: "mrel",
        size: 2
    },
    "\\biggm": {
        mclass: "mrel",
        size: 3
    },
    "\\Biggm": {
        mclass: "mrel",
        size: 4
    },
    "\\big": {
        mclass: "mord",
        size: 1
    },
    "\\Big": {
        mclass: "mord",
        size: 2
    },
    "\\bigg": {
        mclass: "mord",
        size: 3
    },
    "\\Bigg": {
        mclass: "mord",
        size: 4
    }
};
var delimiters = [
    "(",
    "\\lparen",
    ")",
    "\\rparen",
    "[",
    "\\lbrack",
    "]",
    "\\rbrack",
    "\\{",
    "\\lbrace",
    "\\}",
    "\\rbrace",
    "\\lfloor",
    "\\rfloor",
    "\u230a",
    "\u230b",
    "\\lceil",
    "\\rceil",
    "\u2308",
    "\u2309",
    "<",
    ">",
    "\\langle",
    "\u27e8",
    "\\rangle",
    "\u27e9",
    "\\lt",
    "\\gt",
    "\\lvert",
    "\\rvert",
    "\\lVert",
    "\\rVert",
    "\\lgroup",
    "\\rgroup",
    "\u27ee",
    "\u27ef",
    "\\lmoustache",
    "\\rmoustache",
    "\u23b0",
    "\u23b1",
    "/",
    "\\backslash",
    "|",
    "\\vert",
    "\\|",
    "\\Vert",
    "\\uparrow",
    "\\Uparrow",
    "\\downarrow",
    "\\Downarrow",
    "\\updownarrow",
    "\\Updownarrow",
    "."
];
function checkDelimiter(delim, context) {
    var symDelim = checkSymbolNodeType(delim);
    if (symDelim && utils.contains(delimiters, symDelim.text)) {
        return symDelim;
    } else if (symDelim) {
        throw new ParseError("Invalid delimiter '" + symDelim.text + "' after '" + context.funcName + "'", delim);
    } else {
        throw new ParseError("Invalid delimiter type '" + delim.type + "'", delim);
    }
}
defineFunction({
    type: "delimsizing",
    names: [
        "\\bigl",
        "\\Bigl",
        "\\biggl",
        "\\Biggl",
        "\\bigr",
        "\\Bigr",
        "\\biggr",
        "\\Biggr",
        "\\bigm",
        "\\Bigm",
        "\\biggm",
        "\\Biggm",
        "\\big",
        "\\Big",
        "\\bigg",
        "\\Bigg"
    ],
    props: {
        numArgs: 1,
        argTypes: [
            "primitive"
        ]
    },
    handler: (context, args)=>{
        var delim = checkDelimiter(args[0], context);
        return {
            type: "delimsizing",
            mode: context.parser.mode,
            size: delimiterSizes[context.funcName].size,
            mclass: delimiterSizes[context.funcName].mclass,
            delim: delim.text
        };
    },
    htmlBuilder: (group, options)=>{
        if (group.delim === ".") {
            return buildCommon.makeSpan([
                group.mclass
            ]);
        }
        return delimiter.sizedDelim(group.delim, group.size, options, group.mode, [
            group.mclass
        ]);
    },
    mathmlBuilder: (group)=>{
        var children = [];
        if (group.delim !== ".") {
            children.push(makeText(group.delim, group.mode));
        }
        var node = new mathMLTree.MathNode("mo", children);
        if (group.mclass === "mopen" || group.mclass === "mclose") {
            node.setAttribute("fence", "true");
        } else {
            node.setAttribute("fence", "false");
        }
        node.setAttribute("stretchy", "true");
        var size = makeEm(delimiter.sizeToMaxHeight[group.size]);
        node.setAttribute("minsize", size);
        node.setAttribute("maxsize", size);
        return node;
    }
});
function assertParsed(group) {
    if (!group.body) {
        throw new Error("Bug: The leftright ParseNode wasn't fully parsed.");
    }
}
defineFunction({
    type: "leftright-right",
    names: [
        "\\right"
    ],
    props: {
        numArgs: 1,
        primitive: true
    },
    handler: (context, args)=>{
        var color = context.parser.gullet.macros.get("\\current@color");
        if (color && typeof color !== "string") {
            throw new ParseError("\\current@color set to non-string in \\right");
        }
        return {
            type: "leftright-right",
            mode: context.parser.mode,
            delim: checkDelimiter(args[0], context).text,
            color
        };
    }
});
defineFunction({
    type: "leftright",
    names: [
        "\\left"
    ],
    props: {
        numArgs: 1,
        primitive: true
    },
    handler: (context, args)=>{
        var delim = checkDelimiter(args[0], context);
        var parser = context.parser;
        ++parser.leftrightDepth;
        var body = parser.parseExpression(false);
        --parser.leftrightDepth;
        parser.expect("\\right", false);
        var right = assertNodeType(parser.parseFunction(), "leftright-right");
        return {
            type: "leftright",
            mode: parser.mode,
            body,
            left: delim.text,
            right: right.delim,
            rightColor: right.color
        };
    },
    htmlBuilder: (group, options)=>{
        assertParsed(group);
        var inner = buildExpression$1(group.body, options, true, [
            "mopen",
            "mclose"
        ]);
        var innerHeight = 0;
        var innerDepth = 0;
        var hadMiddle = false;
        for(var i = 0; i < inner.length; i++){
            if (inner[i].isMiddle) {
                hadMiddle = true;
            } else {
                innerHeight = Math.max(inner[i].height, innerHeight);
                innerDepth = Math.max(inner[i].depth, innerDepth);
            }
        }
        innerHeight *= options.sizeMultiplier;
        innerDepth *= options.sizeMultiplier;
        var leftDelim;
        if (group.left === ".") {
            leftDelim = makeNullDelimiter(options, [
                "mopen"
            ]);
        } else {
            leftDelim = delimiter.leftRightDelim(group.left, innerHeight, innerDepth, options, group.mode, [
                "mopen"
            ]);
        }
        inner.unshift(leftDelim);
        if (hadMiddle) {
            for(var _i = 1; _i < inner.length; _i++){
                var middleDelim = inner[_i];
                var isMiddle = middleDelim.isMiddle;
                if (isMiddle) {
                    inner[_i] = delimiter.leftRightDelim(isMiddle.delim, innerHeight, innerDepth, isMiddle.options, group.mode, []);
                }
            }
        }
        var rightDelim;
        if (group.right === ".") {
            rightDelim = makeNullDelimiter(options, [
                "mclose"
            ]);
        } else {
            var colorOptions = group.rightColor ? options.withColor(group.rightColor) : options;
            rightDelim = delimiter.leftRightDelim(group.right, innerHeight, innerDepth, colorOptions, group.mode, [
                "mclose"
            ]);
        }
        inner.push(rightDelim);
        return buildCommon.makeSpan([
            "minner"
        ], inner, options);
    },
    mathmlBuilder: (group, options)=>{
        assertParsed(group);
        var inner = buildExpression(group.body, options);
        if (group.left !== ".") {
            var leftNode = new mathMLTree.MathNode("mo", [
                makeText(group.left, group.mode)
            ]);
            leftNode.setAttribute("fence", "true");
            inner.unshift(leftNode);
        }
        if (group.right !== ".") {
            var rightNode = new mathMLTree.MathNode("mo", [
                makeText(group.right, group.mode)
            ]);
            rightNode.setAttribute("fence", "true");
            if (group.rightColor) {
                rightNode.setAttribute("mathcolor", group.rightColor);
            }
            inner.push(rightNode);
        }
        return makeRow(inner);
    }
});
defineFunction({
    type: "middle",
    names: [
        "\\middle"
    ],
    props: {
        numArgs: 1,
        primitive: true
    },
    handler: (context, args)=>{
        var delim = checkDelimiter(args[0], context);
        if (!context.parser.leftrightDepth) {
            throw new ParseError("\\middle without preceding \\left", delim);
        }
        return {
            type: "middle",
            mode: context.parser.mode,
            delim: delim.text
        };
    },
    htmlBuilder: (group, options)=>{
        var middleDelim;
        if (group.delim === ".") {
            middleDelim = makeNullDelimiter(options, []);
        } else {
            middleDelim = delimiter.sizedDelim(group.delim, 1, options, group.mode, []);
            var isMiddle = {
                delim: group.delim,
                options
            };
            middleDelim.isMiddle = isMiddle;
        }
        return middleDelim;
    },
    mathmlBuilder: (group, options)=>{
        var textNode = group.delim === "\\vert" || group.delim === "|" ? makeText("|", "text") : makeText(group.delim, group.mode);
        var middleNode = new mathMLTree.MathNode("mo", [
            textNode
        ]);
        middleNode.setAttribute("fence", "true");
        middleNode.setAttribute("lspace", "0.05em");
        middleNode.setAttribute("rspace", "0.05em");
        return middleNode;
    }
});
var htmlBuilder$7 = (group, options)=>{
    var inner = buildCommon.wrapFragment(buildGroup$1(group.body, options), options);
    var label = group.label.slice(1);
    var scale = options.sizeMultiplier;
    var img;
    var imgShift = 0;
    var isSingleChar = utils.isCharacterBox(group.body);
    if (label === "sout") {
        img = buildCommon.makeSpan([
            "stretchy",
            "sout"
        ]);
        img.height = options.fontMetrics().defaultRuleThickness / scale;
        imgShift = -0.5 * options.fontMetrics().xHeight;
    } else if (label === "phase") {
        var lineWeight = calculateSize({
            number: 0.6,
            unit: "pt"
        }, options);
        var clearance = calculateSize({
            number: 0.35,
            unit: "ex"
        }, options);
        var newOptions = options.havingBaseSizing();
        scale = scale / newOptions.sizeMultiplier;
        var angleHeight = inner.height + inner.depth + lineWeight + clearance;
        inner.style.paddingLeft = makeEm(angleHeight / 2 + lineWeight);
        var viewBoxHeight = Math.floor(1000 * angleHeight * scale);
        var path = phasePath(viewBoxHeight);
        var svgNode = new SvgNode([
            new PathNode("phase", path)
        ], {
            "width": "400em",
            "height": makeEm(viewBoxHeight / 1000),
            "viewBox": "0 0 400000 " + viewBoxHeight,
            "preserveAspectRatio": "xMinYMin slice"
        });
        img = buildCommon.makeSvgSpan([
            "hide-tail"
        ], [
            svgNode
        ], options);
        img.style.height = makeEm(angleHeight);
        imgShift = inner.depth + lineWeight + clearance;
    } else {
        if (/cancel/.test(label)) {
            if (!isSingleChar) {
                inner.classes.push("cancel-pad");
            }
        } else if (label === "angl") {
            inner.classes.push("anglpad");
        } else {
            inner.classes.push("boxpad");
        }
        var topPad = 0;
        var bottomPad = 0;
        var ruleThickness = 0;
        if (/box/.test(label)) {
            ruleThickness = Math.max(options.fontMetrics().fboxrule, options.minRuleThickness);
            topPad = options.fontMetrics().fboxsep + (label === "colorbox" ? 0 : ruleThickness);
            bottomPad = topPad;
        } else if (label === "angl") {
            ruleThickness = Math.max(options.fontMetrics().defaultRuleThickness, options.minRuleThickness);
            topPad = 4 * ruleThickness;
            bottomPad = Math.max(0, 0.25 - inner.depth);
        } else {
            topPad = isSingleChar ? 0.2 : 0;
            bottomPad = topPad;
        }
        img = stretchy.encloseSpan(inner, label, topPad, bottomPad, options);
        if (/fbox|boxed|fcolorbox/.test(label)) {
            img.style.borderStyle = "solid";
            img.style.borderWidth = makeEm(ruleThickness);
        } else if (label === "angl" && ruleThickness !== 0.049) {
            img.style.borderTopWidth = makeEm(ruleThickness);
            img.style.borderRightWidth = makeEm(ruleThickness);
        }
        imgShift = inner.depth + bottomPad;
        if (group.backgroundColor) {
            img.style.backgroundColor = group.backgroundColor;
            if (group.borderColor) {
                img.style.borderColor = group.borderColor;
            }
        }
    }
    var vlist;
    if (group.backgroundColor) {
        vlist = buildCommon.makeVList({
            positionType: "individualShift",
            children: [
                {
                    type: "elem",
                    elem: img,
                    shift: imgShift
                },
                {
                    type: "elem",
                    elem: inner,
                    shift: 0
                }
            ]
        }, options);
    } else {
        var classes = /cancel|phase/.test(label) ? [
            "svg-align"
        ] : [];
        vlist = buildCommon.makeVList({
            positionType: "individualShift",
            children: [
                {
                    type: "elem",
                    elem: inner,
                    shift: 0
                },
                {
                    type: "elem",
                    elem: img,
                    shift: imgShift,
                    wrapperClasses: classes
                }
            ]
        }, options);
    }
    if (/cancel/.test(label)) {
        vlist.height = inner.height;
        vlist.depth = inner.depth;
    }
    if (/cancel/.test(label) && !isSingleChar) {
        return buildCommon.makeSpan([
            "mord",
            "cancel-lap"
        ], [
            vlist
        ], options);
    } else {
        return buildCommon.makeSpan([
            "mord"
        ], [
            vlist
        ], options);
    }
};
var mathmlBuilder$6 = (group, options)=>{
    var fboxsep = 0;
    var node = new mathMLTree.MathNode(group.label.indexOf("colorbox") > -1 ? "mpadded" : "menclose", [
        buildGroup(group.body, options)
    ]);
    switch(group.label){
        case "\\cancel":
            node.setAttribute("notation", "updiagonalstrike");
            break;
        case "\\bcancel":
            node.setAttribute("notation", "downdiagonalstrike");
            break;
        case "\\phase":
            node.setAttribute("notation", "phasorangle");
            break;
        case "\\sout":
            node.setAttribute("notation", "horizontalstrike");
            break;
        case "\\fbox":
            node.setAttribute("notation", "box");
            break;
        case "\\angl":
            node.setAttribute("notation", "actuarial");
            break;
        case "\\fcolorbox":
        case "\\colorbox":
            fboxsep = options.fontMetrics().fboxsep * options.fontMetrics().ptPerEm;
            node.setAttribute("width", "+" + 2 * fboxsep + "pt");
            node.setAttribute("height", "+" + 2 * fboxsep + "pt");
            node.setAttribute("lspace", fboxsep + "pt");
            node.setAttribute("voffset", fboxsep + "pt");
            if (group.label === "\\fcolorbox") {
                var thk = Math.max(options.fontMetrics().fboxrule, options.minRuleThickness);
                node.setAttribute("style", "border: " + thk + "em solid " + String(group.borderColor));
            }
            break;
        case "\\xcancel":
            node.setAttribute("notation", "updiagonalstrike downdiagonalstrike");
            break;
    }
    if (group.backgroundColor) {
        node.setAttribute("mathbackground", group.backgroundColor);
    }
    return node;
};
defineFunction({
    type: "enclose",
    names: [
        "\\colorbox"
    ],
    props: {
        numArgs: 2,
        allowedInText: true,
        argTypes: [
            "color",
            "text"
        ]
    },
    handler (_ref, args, optArgs) {
        var { parser , funcName  } = _ref;
        var color = assertNodeType(args[0], "color-token").color;
        var body = args[1];
        return {
            type: "enclose",
            mode: parser.mode,
            label: funcName,
            backgroundColor: color,
            body
        };
    },
    htmlBuilder: htmlBuilder$7,
    mathmlBuilder: mathmlBuilder$6
});
defineFunction({
    type: "enclose",
    names: [
        "\\fcolorbox"
    ],
    props: {
        numArgs: 3,
        allowedInText: true,
        argTypes: [
            "color",
            "color",
            "text"
        ]
    },
    handler (_ref2, args, optArgs) {
        var { parser , funcName  } = _ref2;
        var borderColor = assertNodeType(args[0], "color-token").color;
        var backgroundColor = assertNodeType(args[1], "color-token").color;
        var body = args[2];
        return {
            type: "enclose",
            mode: parser.mode,
            label: funcName,
            backgroundColor,
            borderColor,
            body
        };
    },
    htmlBuilder: htmlBuilder$7,
    mathmlBuilder: mathmlBuilder$6
});
defineFunction({
    type: "enclose",
    names: [
        "\\fbox"
    ],
    props: {
        numArgs: 1,
        argTypes: [
            "hbox"
        ],
        allowedInText: true
    },
    handler (_ref3, args) {
        var { parser  } = _ref3;
        return {
            type: "enclose",
            mode: parser.mode,
            label: "\\fbox",
            body: args[0]
        };
    }
});
defineFunction({
    type: "enclose",
    names: [
        "\\cancel",
        "\\bcancel",
        "\\xcancel",
        "\\sout",
        "\\phase"
    ],
    props: {
        numArgs: 1
    },
    handler (_ref4, args) {
        var { parser , funcName  } = _ref4;
        var body = args[0];
        return {
            type: "enclose",
            mode: parser.mode,
            label: funcName,
            body
        };
    },
    htmlBuilder: htmlBuilder$7,
    mathmlBuilder: mathmlBuilder$6
});
defineFunction({
    type: "enclose",
    names: [
        "\\angl"
    ],
    props: {
        numArgs: 1,
        argTypes: [
            "hbox"
        ],
        allowedInText: false
    },
    handler (_ref5, args) {
        var { parser  } = _ref5;
        return {
            type: "enclose",
            mode: parser.mode,
            label: "\\angl",
            body: args[0]
        };
    }
});
var _environments = {};
function defineEnvironment(_ref) {
    var { type , names , props , handler , htmlBuilder , mathmlBuilder  } = _ref;
    var data = {
        type,
        numArgs: props.numArgs || 0,
        allowedInText: false,
        numOptionalArgs: 0,
        handler
    };
    for(var i = 0; i < names.length; ++i){
        _environments[names[i]] = data;
    }
    if (htmlBuilder) {
        _htmlGroupBuilders[type] = htmlBuilder;
    }
    if (mathmlBuilder) {
        _mathmlGroupBuilders[type] = mathmlBuilder;
    }
}
var _macros = {};
function defineMacro(name, body) {
    _macros[name] = body;
}
function getHLines(parser) {
    var hlineInfo = [];
    parser.consumeSpaces();
    var nxt = parser.fetch().text;
    if (nxt === "\\relax") {
        parser.consume();
        parser.consumeSpaces();
        nxt = parser.fetch().text;
    }
    while(nxt === "\\hline" || nxt === "\\hdashline"){
        parser.consume();
        hlineInfo.push(nxt === "\\hdashline");
        parser.consumeSpaces();
        nxt = parser.fetch().text;
    }
    return hlineInfo;
}
var validateAmsEnvironmentContext = (context)=>{
    var settings = context.parser.settings;
    if (!settings.displayMode) {
        throw new ParseError("{" + context.envName + "} can be used only in" + " display mode.");
    }
};
function getAutoTag(name) {
    if (name.indexOf("ed") === -1) {
        return name.indexOf("*") === -1;
    }
}
function parseArray(parser, _ref, style) {
    var { hskipBeforeAndAfter , addJot , cols , arraystretch , colSeparationType , autoTag , singleRow , emptySingleRow , maxNumCols , leqno  } = _ref;
    parser.gullet.beginGroup();
    if (!singleRow) {
        parser.gullet.macros.set("\\cr", "\\\\\\relax");
    }
    if (!arraystretch) {
        var stretch = parser.gullet.expandMacroAsText("\\arraystretch");
        if (stretch == null) {
            arraystretch = 1;
        } else {
            arraystretch = parseFloat(stretch);
            if (!arraystretch || arraystretch < 0) {
                throw new ParseError("Invalid \\arraystretch: " + stretch);
            }
        }
    }
    parser.gullet.beginGroup();
    var row = [];
    var body = [
        row
    ];
    var rowGaps = [];
    var hLinesBeforeRow = [];
    var tags = autoTag != null ? [] : undefined;
    function beginRow() {
        if (autoTag) {
            parser.gullet.macros.set("\\@eqnsw", "1", true);
        }
    }
    function endRow() {
        if (tags) {
            if (parser.gullet.macros.get("\\df@tag")) {
                tags.push(parser.subparse([
                    new Token("\\df@tag")
                ]));
                parser.gullet.macros.set("\\df@tag", undefined, true);
            } else {
                tags.push(Boolean(autoTag) && parser.gullet.macros.get("\\@eqnsw") === "1");
            }
        }
    }
    beginRow();
    hLinesBeforeRow.push(getHLines(parser));
    while(true){
        var cell = parser.parseExpression(false, singleRow ? "\\end" : "\\\\");
        parser.gullet.endGroup();
        parser.gullet.beginGroup();
        cell = {
            type: "ordgroup",
            mode: parser.mode,
            body: cell
        };
        if (style) {
            cell = {
                type: "styling",
                mode: parser.mode,
                style,
                body: [
                    cell
                ]
            };
        }
        row.push(cell);
        var next = parser.fetch().text;
        if (next === "&") {
            if (maxNumCols && row.length === maxNumCols) {
                if (singleRow || colSeparationType) {
                    throw new ParseError("Too many tab characters: &", parser.nextToken);
                } else {
                    parser.settings.reportNonstrict("textEnv", "Too few columns " + "specified in the {array} column argument.");
                }
            }
            parser.consume();
        } else if (next === "\\end") {
            endRow();
            if (row.length === 1 && cell.type === "styling" && cell.body[0].body.length === 0 && (body.length > 1 || !emptySingleRow)) {
                body.pop();
            }
            if (hLinesBeforeRow.length < body.length + 1) {
                hLinesBeforeRow.push([]);
            }
            break;
        } else if (next === "\\\\") {
            parser.consume();
            var size = void 0;
            if (parser.gullet.future().text !== " ") {
                size = parser.parseSizeGroup(true);
            }
            rowGaps.push(size ? size.value : null);
            endRow();
            hLinesBeforeRow.push(getHLines(parser));
            row = [];
            body.push(row);
            beginRow();
        } else {
            throw new ParseError("Expected & or \\\\ or \\cr or \\end", parser.nextToken);
        }
    }
    parser.gullet.endGroup();
    parser.gullet.endGroup();
    return {
        type: "array",
        mode: parser.mode,
        addJot,
        arraystretch,
        body,
        cols,
        rowGaps,
        hskipBeforeAndAfter,
        hLinesBeforeRow,
        colSeparationType,
        tags,
        leqno
    };
}
function dCellStyle(envName) {
    if (envName.slice(0, 1) === "d") {
        return "display";
    } else {
        return "text";
    }
}
var htmlBuilder$6 = function htmlBuilder(group, options) {
    var r;
    var c;
    var nr = group.body.length;
    var hLinesBeforeRow = group.hLinesBeforeRow;
    var nc = 0;
    var body = new Array(nr);
    var hlines = [];
    var ruleThickness = Math.max(options.fontMetrics().arrayRuleWidth, options.minRuleThickness);
    var pt = 1 / options.fontMetrics().ptPerEm;
    var arraycolsep = 5 * pt;
    if (group.colSeparationType && group.colSeparationType === "small") {
        var localMultiplier = options.havingStyle(Style$1.SCRIPT).sizeMultiplier;
        arraycolsep = 0.2778 * (localMultiplier / options.sizeMultiplier);
    }
    var baselineskip = group.colSeparationType === "CD" ? calculateSize({
        number: 3,
        unit: "ex"
    }, options) : 12 * pt;
    var jot = 3 * pt;
    var arrayskip = group.arraystretch * baselineskip;
    var arstrutHeight = 0.7 * arrayskip;
    var arstrutDepth = 0.3 * arrayskip;
    var totalHeight = 0;
    function setHLinePos(hlinesInGap) {
        for(var i = 0; i < hlinesInGap.length; ++i){
            if (i > 0) {
                totalHeight += 0.25;
            }
            hlines.push({
                pos: totalHeight,
                isDashed: hlinesInGap[i]
            });
        }
    }
    setHLinePos(hLinesBeforeRow[0]);
    for(r = 0; r < group.body.length; ++r){
        var inrow = group.body[r];
        var height = arstrutHeight;
        var depth = arstrutDepth;
        if (nc < inrow.length) {
            nc = inrow.length;
        }
        var outrow = new Array(inrow.length);
        for(c = 0; c < inrow.length; ++c){
            var elt = buildGroup$1(inrow[c], options);
            if (depth < elt.depth) {
                depth = elt.depth;
            }
            if (height < elt.height) {
                height = elt.height;
            }
            outrow[c] = elt;
        }
        var rowGap = group.rowGaps[r];
        var gap = 0;
        if (rowGap) {
            gap = calculateSize(rowGap, options);
            if (gap > 0) {
                gap += arstrutDepth;
                if (depth < gap) {
                    depth = gap;
                }
                gap = 0;
            }
        }
        if (group.addJot) {
            depth += jot;
        }
        outrow.height = height;
        outrow.depth = depth;
        totalHeight += height;
        outrow.pos = totalHeight;
        totalHeight += depth + gap;
        body[r] = outrow;
        setHLinePos(hLinesBeforeRow[r + 1]);
    }
    var offset = totalHeight / 2 + options.fontMetrics().axisHeight;
    var colDescriptions = group.cols || [];
    var cols = [];
    var colSep;
    var colDescrNum;
    var tagSpans = [];
    if (group.tags && group.tags.some((tag)=>tag)) {
        for(r = 0; r < nr; ++r){
            var rw = body[r];
            var shift = rw.pos - offset;
            var tag = group.tags[r];
            var tagSpan = void 0;
            if (tag === true) {
                tagSpan = buildCommon.makeSpan([
                    "eqn-num"
                ], [], options);
            } else if (tag === false) {
                tagSpan = buildCommon.makeSpan([], [], options);
            } else {
                tagSpan = buildCommon.makeSpan([], buildExpression$1(tag, options, true), options);
            }
            tagSpan.depth = rw.depth;
            tagSpan.height = rw.height;
            tagSpans.push({
                type: "elem",
                elem: tagSpan,
                shift
            });
        }
    }
    for(c = 0, colDescrNum = 0; c < nc || colDescrNum < colDescriptions.length; ++c, ++colDescrNum){
        var colDescr = colDescriptions[colDescrNum] || {};
        var firstSeparator = true;
        while(colDescr.type === "separator"){
            if (!firstSeparator) {
                colSep = buildCommon.makeSpan([
                    "arraycolsep"
                ], []);
                colSep.style.width = makeEm(options.fontMetrics().doubleRuleSep);
                cols.push(colSep);
            }
            if (colDescr.separator === "|" || colDescr.separator === ":") {
                var lineType = colDescr.separator === "|" ? "solid" : "dashed";
                var separator = buildCommon.makeSpan([
                    "vertical-separator"
                ], [], options);
                separator.style.height = makeEm(totalHeight);
                separator.style.borderRightWidth = makeEm(ruleThickness);
                separator.style.borderRightStyle = lineType;
                separator.style.margin = "0 " + makeEm(-ruleThickness / 2);
                var _shift = totalHeight - offset;
                if (_shift) {
                    separator.style.verticalAlign = makeEm(-_shift);
                }
                cols.push(separator);
            } else {
                throw new ParseError("Invalid separator type: " + colDescr.separator);
            }
            colDescrNum++;
            colDescr = colDescriptions[colDescrNum] || {};
            firstSeparator = false;
        }
        if (c >= nc) {
            continue;
        }
        var sepwidth = void 0;
        if (c > 0 || group.hskipBeforeAndAfter) {
            sepwidth = utils.deflt(colDescr.pregap, arraycolsep);
            if (sepwidth !== 0) {
                colSep = buildCommon.makeSpan([
                    "arraycolsep"
                ], []);
                colSep.style.width = makeEm(sepwidth);
                cols.push(colSep);
            }
        }
        var col = [];
        for(r = 0; r < nr; ++r){
            var row = body[r];
            var elem = row[c];
            if (!elem) {
                continue;
            }
            var _shift2 = row.pos - offset;
            elem.depth = row.depth;
            elem.height = row.height;
            col.push({
                type: "elem",
                elem: elem,
                shift: _shift2
            });
        }
        col = buildCommon.makeVList({
            positionType: "individualShift",
            children: col
        }, options);
        col = buildCommon.makeSpan([
            "col-align-" + (colDescr.align || "c")
        ], [
            col
        ]);
        cols.push(col);
        if (c < nc - 1 || group.hskipBeforeAndAfter) {
            sepwidth = utils.deflt(colDescr.postgap, arraycolsep);
            if (sepwidth !== 0) {
                colSep = buildCommon.makeSpan([
                    "arraycolsep"
                ], []);
                colSep.style.width = makeEm(sepwidth);
                cols.push(colSep);
            }
        }
    }
    body = buildCommon.makeSpan([
        "mtable"
    ], cols);
    if (hlines.length > 0) {
        var line = buildCommon.makeLineSpan("hline", options, ruleThickness);
        var dashes = buildCommon.makeLineSpan("hdashline", options, ruleThickness);
        var vListElems = [
            {
                type: "elem",
                elem: body,
                shift: 0
            }
        ];
        while(hlines.length > 0){
            var hline = hlines.pop();
            var lineShift = hline.pos - offset;
            if (hline.isDashed) {
                vListElems.push({
                    type: "elem",
                    elem: dashes,
                    shift: lineShift
                });
            } else {
                vListElems.push({
                    type: "elem",
                    elem: line,
                    shift: lineShift
                });
            }
        }
        body = buildCommon.makeVList({
            positionType: "individualShift",
            children: vListElems
        }, options);
    }
    if (tagSpans.length === 0) {
        return buildCommon.makeSpan([
            "mord"
        ], [
            body
        ], options);
    } else {
        var eqnNumCol = buildCommon.makeVList({
            positionType: "individualShift",
            children: tagSpans
        }, options);
        eqnNumCol = buildCommon.makeSpan([
            "tag"
        ], [
            eqnNumCol
        ], options);
        return buildCommon.makeFragment([
            body,
            eqnNumCol
        ]);
    }
};
var alignMap = {
    c: "center ",
    l: "left ",
    r: "right "
};
var mathmlBuilder$5 = function mathmlBuilder(group, options) {
    var tbl = [];
    var glue = new mathMLTree.MathNode("mtd", [], [
        "mtr-glue"
    ]);
    var tag = new mathMLTree.MathNode("mtd", [], [
        "mml-eqn-num"
    ]);
    for(var i = 0; i < group.body.length; i++){
        var rw = group.body[i];
        var row = [];
        for(var j = 0; j < rw.length; j++){
            row.push(new mathMLTree.MathNode("mtd", [
                buildGroup(rw[j], options)
            ]));
        }
        if (group.tags && group.tags[i]) {
            row.unshift(glue);
            row.push(glue);
            if (group.leqno) {
                row.unshift(tag);
            } else {
                row.push(tag);
            }
        }
        tbl.push(new mathMLTree.MathNode("mtr", row));
    }
    var table = new mathMLTree.MathNode("mtable", tbl);
    var gap = group.arraystretch === 0.5 ? 0.1 : 0.16 + group.arraystretch - 1 + (group.addJot ? 0.09 : 0);
    table.setAttribute("rowspacing", makeEm(gap));
    var menclose = "";
    var align = "";
    if (group.cols && group.cols.length > 0) {
        var cols = group.cols;
        var columnLines = "";
        var prevTypeWasAlign = false;
        var iStart = 0;
        var iEnd = cols.length;
        if (cols[0].type === "separator") {
            menclose += "top ";
            iStart = 1;
        }
        if (cols[cols.length - 1].type === "separator") {
            menclose += "bottom ";
            iEnd -= 1;
        }
        for(var _i = iStart; _i < iEnd; _i++){
            if (cols[_i].type === "align") {
                align += alignMap[cols[_i].align];
                if (prevTypeWasAlign) {
                    columnLines += "none ";
                }
                prevTypeWasAlign = true;
            } else if (cols[_i].type === "separator") {
                if (prevTypeWasAlign) {
                    columnLines += cols[_i].separator === "|" ? "solid " : "dashed ";
                    prevTypeWasAlign = false;
                }
            }
        }
        table.setAttribute("columnalign", align.trim());
        if (/[sd]/.test(columnLines)) {
            table.setAttribute("columnlines", columnLines.trim());
        }
    }
    if (group.colSeparationType === "align") {
        var _cols = group.cols || [];
        var spacing = "";
        for(var _i2 = 1; _i2 < _cols.length; _i2++){
            spacing += _i2 % 2 ? "0em " : "1em ";
        }
        table.setAttribute("columnspacing", spacing.trim());
    } else if (group.colSeparationType === "alignat" || group.colSeparationType === "gather") {
        table.setAttribute("columnspacing", "0em");
    } else if (group.colSeparationType === "small") {
        table.setAttribute("columnspacing", "0.2778em");
    } else if (group.colSeparationType === "CD") {
        table.setAttribute("columnspacing", "0.5em");
    } else {
        table.setAttribute("columnspacing", "1em");
    }
    var rowLines = "";
    var hlines = group.hLinesBeforeRow;
    menclose += hlines[0].length > 0 ? "left " : "";
    menclose += hlines[hlines.length - 1].length > 0 ? "right " : "";
    for(var _i3 = 1; _i3 < hlines.length - 1; _i3++){
        rowLines += hlines[_i3].length === 0 ? "none " : hlines[_i3][0] ? "dashed " : "solid ";
    }
    if (/[sd]/.test(rowLines)) {
        table.setAttribute("rowlines", rowLines.trim());
    }
    if (menclose !== "") {
        table = new mathMLTree.MathNode("menclose", [
            table
        ]);
        table.setAttribute("notation", menclose.trim());
    }
    if (group.arraystretch && group.arraystretch < 1) {
        table = new mathMLTree.MathNode("mstyle", [
            table
        ]);
        table.setAttribute("scriptlevel", "1");
    }
    return table;
};
var alignedHandler = function alignedHandler(context, args) {
    if (context.envName.indexOf("ed") === -1) {
        validateAmsEnvironmentContext(context);
    }
    var cols = [];
    var separationType = context.envName.indexOf("at") > -1 ? "alignat" : "align";
    var isSplit = context.envName === "split";
    var res = parseArray(context.parser, {
        cols,
        addJot: true,
        autoTag: isSplit ? undefined : getAutoTag(context.envName),
        emptySingleRow: true,
        colSeparationType: separationType,
        maxNumCols: isSplit ? 2 : undefined,
        leqno: context.parser.settings.leqno
    }, "display");
    var numMaths;
    var numCols = 0;
    var emptyGroup = {
        type: "ordgroup",
        mode: context.mode,
        body: []
    };
    if (args[0] && args[0].type === "ordgroup") {
        var arg0 = "";
        for(var i = 0; i < args[0].body.length; i++){
            var textord = assertNodeType(args[0].body[i], "textord");
            arg0 += textord.text;
        }
        numMaths = Number(arg0);
        numCols = numMaths * 2;
    }
    var isAligned = !numCols;
    res.body.forEach(function(row) {
        for(var _i4 = 1; _i4 < row.length; _i4 += 2){
            var styling = assertNodeType(row[_i4], "styling");
            var ordgroup = assertNodeType(styling.body[0], "ordgroup");
            ordgroup.body.unshift(emptyGroup);
        }
        if (!isAligned) {
            var curMaths = row.length / 2;
            if (numMaths < curMaths) {
                throw new ParseError("Too many math in a row: " + ("expected " + numMaths + ", but got " + curMaths), row[0]);
            }
        } else if (numCols < row.length) {
            numCols = row.length;
        }
    });
    for(var _i5 = 0; _i5 < numCols; ++_i5){
        var align = "r";
        var pregap = 0;
        if (_i5 % 2 === 1) {
            align = "l";
        } else if (_i5 > 0 && isAligned) {
            pregap = 1;
        }
        cols[_i5] = {
            type: "align",
            align: align,
            pregap: pregap,
            postgap: 0
        };
    }
    res.colSeparationType = isAligned ? "align" : "alignat";
    return res;
};
defineEnvironment({
    type: "array",
    names: [
        "array",
        "darray"
    ],
    props: {
        numArgs: 1
    },
    handler (context, args) {
        var symNode = checkSymbolNodeType(args[0]);
        var colalign = symNode ? [
            args[0]
        ] : assertNodeType(args[0], "ordgroup").body;
        var cols = colalign.map(function(nde) {
            var node = assertSymbolNodeType(nde);
            var ca = node.text;
            if ("lcr".indexOf(ca) !== -1) {
                return {
                    type: "align",
                    align: ca
                };
            } else if (ca === "|") {
                return {
                    type: "separator",
                    separator: "|"
                };
            } else if (ca === ":") {
                return {
                    type: "separator",
                    separator: ":"
                };
            }
            throw new ParseError("Unknown column alignment: " + ca, nde);
        });
        var res = {
            cols,
            hskipBeforeAndAfter: true,
            maxNumCols: cols.length
        };
        return parseArray(context.parser, res, dCellStyle(context.envName));
    },
    htmlBuilder: htmlBuilder$6,
    mathmlBuilder: mathmlBuilder$5
});
defineEnvironment({
    type: "array",
    names: [
        "matrix",
        "pmatrix",
        "bmatrix",
        "Bmatrix",
        "vmatrix",
        "Vmatrix",
        "matrix*",
        "pmatrix*",
        "bmatrix*",
        "Bmatrix*",
        "vmatrix*",
        "Vmatrix*"
    ],
    props: {
        numArgs: 0
    },
    handler (context) {
        var delimiters = {
            "matrix": null,
            "pmatrix": [
                "(",
                ")"
            ],
            "bmatrix": [
                "[",
                "]"
            ],
            "Bmatrix": [
                "\\{",
                "\\}"
            ],
            "vmatrix": [
                "|",
                "|"
            ],
            "Vmatrix": [
                "\\Vert",
                "\\Vert"
            ]
        }[context.envName.replace("*", "")];
        var colAlign = "c";
        var payload = {
            hskipBeforeAndAfter: false,
            cols: [
                {
                    type: "align",
                    align: colAlign
                }
            ]
        };
        if (context.envName.charAt(context.envName.length - 1) === "*") {
            var parser = context.parser;
            parser.consumeSpaces();
            if (parser.fetch().text === "[") {
                parser.consume();
                parser.consumeSpaces();
                colAlign = parser.fetch().text;
                if ("lcr".indexOf(colAlign) === -1) {
                    throw new ParseError("Expected l or c or r", parser.nextToken);
                }
                parser.consume();
                parser.consumeSpaces();
                parser.expect("]");
                parser.consume();
                payload.cols = [
                    {
                        type: "align",
                        align: colAlign
                    }
                ];
            }
        }
        var res = parseArray(context.parser, payload, dCellStyle(context.envName));
        var numCols = Math.max(0, ...res.body.map((row)=>row.length));
        res.cols = new Array(numCols).fill({
            type: "align",
            align: colAlign
        });
        return delimiters ? {
            type: "leftright",
            mode: context.mode,
            body: [
                res
            ],
            left: delimiters[0],
            right: delimiters[1],
            rightColor: undefined
        } : res;
    },
    htmlBuilder: htmlBuilder$6,
    mathmlBuilder: mathmlBuilder$5
});
defineEnvironment({
    type: "array",
    names: [
        "smallmatrix"
    ],
    props: {
        numArgs: 0
    },
    handler (context) {
        var payload = {
            arraystretch: 0.5
        };
        var res = parseArray(context.parser, payload, "script");
        res.colSeparationType = "small";
        return res;
    },
    htmlBuilder: htmlBuilder$6,
    mathmlBuilder: mathmlBuilder$5
});
defineEnvironment({
    type: "array",
    names: [
        "subarray"
    ],
    props: {
        numArgs: 1
    },
    handler (context, args) {
        var symNode = checkSymbolNodeType(args[0]);
        var colalign = symNode ? [
            args[0]
        ] : assertNodeType(args[0], "ordgroup").body;
        var cols = colalign.map(function(nde) {
            var node = assertSymbolNodeType(nde);
            var ca = node.text;
            if ("lc".indexOf(ca) !== -1) {
                return {
                    type: "align",
                    align: ca
                };
            }
            throw new ParseError("Unknown column alignment: " + ca, nde);
        });
        if (cols.length > 1) {
            throw new ParseError("{subarray} can contain only one column");
        }
        var res = {
            cols,
            hskipBeforeAndAfter: false,
            arraystretch: 0.5
        };
        res = parseArray(context.parser, res, "script");
        if (res.body.length > 0 && res.body[0].length > 1) {
            throw new ParseError("{subarray} can contain only one column");
        }
        return res;
    },
    htmlBuilder: htmlBuilder$6,
    mathmlBuilder: mathmlBuilder$5
});
defineEnvironment({
    type: "array",
    names: [
        "cases",
        "dcases",
        "rcases",
        "drcases"
    ],
    props: {
        numArgs: 0
    },
    handler (context) {
        var payload = {
            arraystretch: 1.2,
            cols: [
                {
                    type: "align",
                    align: "l",
                    pregap: 0,
                    postgap: 1.0
                },
                {
                    type: "align",
                    align: "l",
                    pregap: 0,
                    postgap: 0
                }
            ]
        };
        var res = parseArray(context.parser, payload, dCellStyle(context.envName));
        return {
            type: "leftright",
            mode: context.mode,
            body: [
                res
            ],
            left: context.envName.indexOf("r") > -1 ? "." : "\\{",
            right: context.envName.indexOf("r") > -1 ? "\\}" : ".",
            rightColor: undefined
        };
    },
    htmlBuilder: htmlBuilder$6,
    mathmlBuilder: mathmlBuilder$5
});
defineEnvironment({
    type: "array",
    names: [
        "align",
        "align*",
        "aligned",
        "split"
    ],
    props: {
        numArgs: 0
    },
    handler: alignedHandler,
    htmlBuilder: htmlBuilder$6,
    mathmlBuilder: mathmlBuilder$5
});
defineEnvironment({
    type: "array",
    names: [
        "gathered",
        "gather",
        "gather*"
    ],
    props: {
        numArgs: 0
    },
    handler (context) {
        if (utils.contains([
            "gather",
            "gather*"
        ], context.envName)) {
            validateAmsEnvironmentContext(context);
        }
        var res = {
            cols: [
                {
                    type: "align",
                    align: "c"
                }
            ],
            addJot: true,
            colSeparationType: "gather",
            autoTag: getAutoTag(context.envName),
            emptySingleRow: true,
            leqno: context.parser.settings.leqno
        };
        return parseArray(context.parser, res, "display");
    },
    htmlBuilder: htmlBuilder$6,
    mathmlBuilder: mathmlBuilder$5
});
defineEnvironment({
    type: "array",
    names: [
        "alignat",
        "alignat*",
        "alignedat"
    ],
    props: {
        numArgs: 1
    },
    handler: alignedHandler,
    htmlBuilder: htmlBuilder$6,
    mathmlBuilder: mathmlBuilder$5
});
defineEnvironment({
    type: "array",
    names: [
        "equation",
        "equation*"
    ],
    props: {
        numArgs: 0
    },
    handler (context) {
        validateAmsEnvironmentContext(context);
        var res = {
            autoTag: getAutoTag(context.envName),
            emptySingleRow: true,
            singleRow: true,
            maxNumCols: 1,
            leqno: context.parser.settings.leqno
        };
        return parseArray(context.parser, res, "display");
    },
    htmlBuilder: htmlBuilder$6,
    mathmlBuilder: mathmlBuilder$5
});
defineEnvironment({
    type: "array",
    names: [
        "CD"
    ],
    props: {
        numArgs: 0
    },
    handler (context) {
        validateAmsEnvironmentContext(context);
        return parseCD(context.parser);
    },
    htmlBuilder: htmlBuilder$6,
    mathmlBuilder: mathmlBuilder$5
});
defineMacro("\\nonumber", "\\gdef\\@eqnsw{0}");
defineMacro("\\notag", "\\nonumber");
defineFunction({
    type: "text",
    names: [
        "\\hline",
        "\\hdashline"
    ],
    props: {
        numArgs: 0,
        allowedInText: true,
        allowedInMath: true
    },
    handler (context, args) {
        throw new ParseError(context.funcName + " valid only within array environment");
    }
});
var environments = _environments;
defineFunction({
    type: "environment",
    names: [
        "\\begin",
        "\\end"
    ],
    props: {
        numArgs: 1,
        argTypes: [
            "text"
        ]
    },
    handler (_ref, args) {
        var { parser , funcName  } = _ref;
        var nameGroup = args[0];
        if (nameGroup.type !== "ordgroup") {
            throw new ParseError("Invalid environment name", nameGroup);
        }
        var envName = "";
        for(var i = 0; i < nameGroup.body.length; ++i){
            envName += assertNodeType(nameGroup.body[i], "textord").text;
        }
        if (funcName === "\\begin") {
            if (!environments.hasOwnProperty(envName)) {
                throw new ParseError("No such environment: " + envName, nameGroup);
            }
            var env = environments[envName];
            var { args: _args , optArgs  } = parser.parseArguments("\\begin{" + envName + "}", env);
            var context = {
                mode: parser.mode,
                envName,
                parser
            };
            var result = env.handler(context, _args, optArgs);
            parser.expect("\\end", false);
            var endNameToken = parser.nextToken;
            var end = assertNodeType(parser.parseFunction(), "environment");
            if (end.name !== envName) {
                throw new ParseError("Mismatch: \\begin{" + envName + "} matched by \\end{" + end.name + "}", endNameToken);
            }
            return result;
        }
        return {
            type: "environment",
            mode: parser.mode,
            name: envName,
            nameGroup
        };
    }
});
var htmlBuilder$5 = (group, options)=>{
    var font = group.font;
    var newOptions = options.withFont(font);
    return buildGroup$1(group.body, newOptions);
};
var mathmlBuilder$4 = (group, options)=>{
    var font = group.font;
    var newOptions = options.withFont(font);
    return buildGroup(group.body, newOptions);
};
var fontAliases = {
    "\\Bbb": "\\mathbb",
    "\\bold": "\\mathbf",
    "\\frak": "\\mathfrak",
    "\\bm": "\\boldsymbol"
};
defineFunction({
    type: "font",
    names: [
        "\\mathrm",
        "\\mathit",
        "\\mathbf",
        "\\mathnormal",
        "\\mathbb",
        "\\mathcal",
        "\\mathfrak",
        "\\mathscr",
        "\\mathsf",
        "\\mathtt",
        "\\Bbb",
        "\\bold",
        "\\frak"
    ],
    props: {
        numArgs: 1,
        allowedInArgument: true
    },
    handler: (_ref, args)=>{
        var { parser , funcName  } = _ref;
        var body = normalizeArgument(args[0]);
        var func = funcName;
        if (func in fontAliases) {
            func = fontAliases[func];
        }
        return {
            type: "font",
            mode: parser.mode,
            font: func.slice(1),
            body
        };
    },
    htmlBuilder: htmlBuilder$5,
    mathmlBuilder: mathmlBuilder$4
});
defineFunction({
    type: "mclass",
    names: [
        "\\boldsymbol",
        "\\bm"
    ],
    props: {
        numArgs: 1
    },
    handler: (_ref2, args)=>{
        var { parser  } = _ref2;
        var body = args[0];
        var isCharacterBox = utils.isCharacterBox(body);
        return {
            type: "mclass",
            mode: parser.mode,
            mclass: binrelClass(body),
            body: [
                {
                    type: "font",
                    mode: parser.mode,
                    font: "boldsymbol",
                    body
                }
            ],
            isCharacterBox: isCharacterBox
        };
    }
});
defineFunction({
    type: "font",
    names: [
        "\\rm",
        "\\sf",
        "\\tt",
        "\\bf",
        "\\it",
        "\\cal"
    ],
    props: {
        numArgs: 0,
        allowedInText: true
    },
    handler: (_ref3, args)=>{
        var { parser , funcName , breakOnTokenText  } = _ref3;
        var { mode  } = parser;
        var body = parser.parseExpression(true, breakOnTokenText);
        var style = "math" + funcName.slice(1);
        return {
            type: "font",
            mode: mode,
            font: style,
            body: {
                type: "ordgroup",
                mode: parser.mode,
                body
            }
        };
    },
    htmlBuilder: htmlBuilder$5,
    mathmlBuilder: mathmlBuilder$4
});
var adjustStyle = (size, originalStyle)=>{
    var style = originalStyle;
    if (size === "display") {
        style = style.id >= Style$1.SCRIPT.id ? style.text() : Style$1.DISPLAY;
    } else if (size === "text" && style.size === Style$1.DISPLAY.size) {
        style = Style$1.TEXT;
    } else if (size === "script") {
        style = Style$1.SCRIPT;
    } else if (size === "scriptscript") {
        style = Style$1.SCRIPTSCRIPT;
    }
    return style;
};
var htmlBuilder$4 = (group, options)=>{
    var style = adjustStyle(group.size, options.style);
    var nstyle = style.fracNum();
    var dstyle = style.fracDen();
    var newOptions;
    newOptions = options.havingStyle(nstyle);
    var numerm = buildGroup$1(group.numer, newOptions, options);
    if (group.continued) {
        var hStrut = 8.5 / options.fontMetrics().ptPerEm;
        var dStrut = 3.5 / options.fontMetrics().ptPerEm;
        numerm.height = numerm.height < hStrut ? hStrut : numerm.height;
        numerm.depth = numerm.depth < dStrut ? dStrut : numerm.depth;
    }
    newOptions = options.havingStyle(dstyle);
    var denomm = buildGroup$1(group.denom, newOptions, options);
    var rule;
    var ruleWidth;
    var ruleSpacing;
    if (group.hasBarLine) {
        if (group.barSize) {
            ruleWidth = calculateSize(group.barSize, options);
            rule = buildCommon.makeLineSpan("frac-line", options, ruleWidth);
        } else {
            rule = buildCommon.makeLineSpan("frac-line", options);
        }
        ruleWidth = rule.height;
        ruleSpacing = rule.height;
    } else {
        rule = null;
        ruleWidth = 0;
        ruleSpacing = options.fontMetrics().defaultRuleThickness;
    }
    var numShift;
    var clearance;
    var denomShift;
    if (style.size === Style$1.DISPLAY.size || group.size === "display") {
        numShift = options.fontMetrics().num1;
        if (ruleWidth > 0) {
            clearance = 3 * ruleSpacing;
        } else {
            clearance = 7 * ruleSpacing;
        }
        denomShift = options.fontMetrics().denom1;
    } else {
        if (ruleWidth > 0) {
            numShift = options.fontMetrics().num2;
            clearance = ruleSpacing;
        } else {
            numShift = options.fontMetrics().num3;
            clearance = 3 * ruleSpacing;
        }
        denomShift = options.fontMetrics().denom2;
    }
    var frac;
    if (!rule) {
        var candidateClearance = numShift - numerm.depth - (denomm.height - denomShift);
        if (candidateClearance < clearance) {
            numShift += 0.5 * (clearance - candidateClearance);
            denomShift += 0.5 * (clearance - candidateClearance);
        }
        frac = buildCommon.makeVList({
            positionType: "individualShift",
            children: [
                {
                    type: "elem",
                    elem: denomm,
                    shift: denomShift
                },
                {
                    type: "elem",
                    elem: numerm,
                    shift: -numShift
                }
            ]
        }, options);
    } else {
        var axisHeight = options.fontMetrics().axisHeight;
        if (numShift - numerm.depth - (axisHeight + 0.5 * ruleWidth) < clearance) {
            numShift += clearance - (numShift - numerm.depth - (axisHeight + 0.5 * ruleWidth));
        }
        if (axisHeight - 0.5 * ruleWidth - (denomm.height - denomShift) < clearance) {
            denomShift += clearance - (axisHeight - 0.5 * ruleWidth - (denomm.height - denomShift));
        }
        var midShift = -(axisHeight - 0.5 * ruleWidth);
        frac = buildCommon.makeVList({
            positionType: "individualShift",
            children: [
                {
                    type: "elem",
                    elem: denomm,
                    shift: denomShift
                },
                {
                    type: "elem",
                    elem: rule,
                    shift: midShift
                },
                {
                    type: "elem",
                    elem: numerm,
                    shift: -numShift
                }
            ]
        }, options);
    }
    newOptions = options.havingStyle(style);
    frac.height *= newOptions.sizeMultiplier / options.sizeMultiplier;
    frac.depth *= newOptions.sizeMultiplier / options.sizeMultiplier;
    var delimSize;
    if (style.size === Style$1.DISPLAY.size) {
        delimSize = options.fontMetrics().delim1;
    } else if (style.size === Style$1.SCRIPTSCRIPT.size) {
        delimSize = options.havingStyle(Style$1.SCRIPT).fontMetrics().delim2;
    } else {
        delimSize = options.fontMetrics().delim2;
    }
    var leftDelim;
    var rightDelim;
    if (group.leftDelim == null) {
        leftDelim = makeNullDelimiter(options, [
            "mopen"
        ]);
    } else {
        leftDelim = delimiter.customSizedDelim(group.leftDelim, delimSize, true, options.havingStyle(style), group.mode, [
            "mopen"
        ]);
    }
    if (group.continued) {
        rightDelim = buildCommon.makeSpan([]);
    } else if (group.rightDelim == null) {
        rightDelim = makeNullDelimiter(options, [
            "mclose"
        ]);
    } else {
        rightDelim = delimiter.customSizedDelim(group.rightDelim, delimSize, true, options.havingStyle(style), group.mode, [
            "mclose"
        ]);
    }
    return buildCommon.makeSpan([
        "mord"
    ].concat(newOptions.sizingClasses(options)), [
        leftDelim,
        buildCommon.makeSpan([
            "mfrac"
        ], [
            frac
        ]),
        rightDelim
    ], options);
};
var mathmlBuilder$3 = (group, options)=>{
    var node = new mathMLTree.MathNode("mfrac", [
        buildGroup(group.numer, options),
        buildGroup(group.denom, options)
    ]);
    if (!group.hasBarLine) {
        node.setAttribute("linethickness", "0px");
    } else if (group.barSize) {
        var ruleWidth = calculateSize(group.barSize, options);
        node.setAttribute("linethickness", makeEm(ruleWidth));
    }
    var style = adjustStyle(group.size, options.style);
    if (style.size !== options.style.size) {
        node = new mathMLTree.MathNode("mstyle", [
            node
        ]);
        var isDisplay = style.size === Style$1.DISPLAY.size ? "true" : "false";
        node.setAttribute("displaystyle", isDisplay);
        node.setAttribute("scriptlevel", "0");
    }
    if (group.leftDelim != null || group.rightDelim != null) {
        var withDelims = [];
        if (group.leftDelim != null) {
            var leftOp = new mathMLTree.MathNode("mo", [
                new mathMLTree.TextNode(group.leftDelim.replace("\\", ""))
            ]);
            leftOp.setAttribute("fence", "true");
            withDelims.push(leftOp);
        }
        withDelims.push(node);
        if (group.rightDelim != null) {
            var rightOp = new mathMLTree.MathNode("mo", [
                new mathMLTree.TextNode(group.rightDelim.replace("\\", ""))
            ]);
            rightOp.setAttribute("fence", "true");
            withDelims.push(rightOp);
        }
        return makeRow(withDelims);
    }
    return node;
};
defineFunction({
    type: "genfrac",
    names: [
        "\\dfrac",
        "\\frac",
        "\\tfrac",
        "\\dbinom",
        "\\binom",
        "\\tbinom",
        "\\\\atopfrac",
        "\\\\bracefrac",
        "\\\\brackfrac"
    ],
    props: {
        numArgs: 2,
        allowedInArgument: true
    },
    handler: (_ref, args)=>{
        var { parser , funcName  } = _ref;
        var numer = args[0];
        var denom = args[1];
        var hasBarLine;
        var leftDelim = null;
        var rightDelim = null;
        var size = "auto";
        switch(funcName){
            case "\\dfrac":
            case "\\frac":
            case "\\tfrac":
                hasBarLine = true;
                break;
            case "\\\\atopfrac":
                hasBarLine = false;
                break;
            case "\\dbinom":
            case "\\binom":
            case "\\tbinom":
                hasBarLine = false;
                leftDelim = "(";
                rightDelim = ")";
                break;
            case "\\\\bracefrac":
                hasBarLine = false;
                leftDelim = "\\{";
                rightDelim = "\\}";
                break;
            case "\\\\brackfrac":
                hasBarLine = false;
                leftDelim = "[";
                rightDelim = "]";
                break;
            default:
                throw new Error("Unrecognized genfrac command");
        }
        switch(funcName){
            case "\\dfrac":
            case "\\dbinom":
                size = "display";
                break;
            case "\\tfrac":
            case "\\tbinom":
                size = "text";
                break;
        }
        return {
            type: "genfrac",
            mode: parser.mode,
            continued: false,
            numer,
            denom,
            hasBarLine,
            leftDelim,
            rightDelim,
            size,
            barSize: null
        };
    },
    htmlBuilder: htmlBuilder$4,
    mathmlBuilder: mathmlBuilder$3
});
defineFunction({
    type: "genfrac",
    names: [
        "\\cfrac"
    ],
    props: {
        numArgs: 2
    },
    handler: (_ref2, args)=>{
        var { parser , funcName  } = _ref2;
        var numer = args[0];
        var denom = args[1];
        return {
            type: "genfrac",
            mode: parser.mode,
            continued: true,
            numer,
            denom,
            hasBarLine: true,
            leftDelim: null,
            rightDelim: null,
            size: "display",
            barSize: null
        };
    }
});
defineFunction({
    type: "infix",
    names: [
        "\\over",
        "\\choose",
        "\\atop",
        "\\brace",
        "\\brack"
    ],
    props: {
        numArgs: 0,
        infix: true
    },
    handler (_ref3) {
        var { parser , funcName , token  } = _ref3;
        var replaceWith;
        switch(funcName){
            case "\\over":
                replaceWith = "\\frac";
                break;
            case "\\choose":
                replaceWith = "\\binom";
                break;
            case "\\atop":
                replaceWith = "\\\\atopfrac";
                break;
            case "\\brace":
                replaceWith = "\\\\bracefrac";
                break;
            case "\\brack":
                replaceWith = "\\\\brackfrac";
                break;
            default:
                throw new Error("Unrecognized infix genfrac command");
        }
        return {
            type: "infix",
            mode: parser.mode,
            replaceWith,
            token
        };
    }
});
var stylArray = [
    "display",
    "text",
    "script",
    "scriptscript"
];
var delimFromValue = function delimFromValue(delimString) {
    var delim = null;
    if (delimString.length > 0) {
        delim = delimString;
        delim = delim === "." ? null : delim;
    }
    return delim;
};
defineFunction({
    type: "genfrac",
    names: [
        "\\genfrac"
    ],
    props: {
        numArgs: 6,
        allowedInArgument: true,
        argTypes: [
            "math",
            "math",
            "size",
            "text",
            "math",
            "math"
        ]
    },
    handler (_ref4, args) {
        var { parser  } = _ref4;
        var numer = args[4];
        var denom = args[5];
        var leftNode = normalizeArgument(args[0]);
        var leftDelim = leftNode.type === "atom" && leftNode.family === "open" ? delimFromValue(leftNode.text) : null;
        var rightNode = normalizeArgument(args[1]);
        var rightDelim = rightNode.type === "atom" && rightNode.family === "close" ? delimFromValue(rightNode.text) : null;
        var barNode = assertNodeType(args[2], "size");
        var hasBarLine;
        var barSize = null;
        if (barNode.isBlank) {
            hasBarLine = true;
        } else {
            barSize = barNode.value;
            hasBarLine = barSize.number > 0;
        }
        var size = "auto";
        var styl = args[3];
        if (styl.type === "ordgroup") {
            if (styl.body.length > 0) {
                var textOrd = assertNodeType(styl.body[0], "textord");
                size = stylArray[Number(textOrd.text)];
            }
        } else {
            styl = assertNodeType(styl, "textord");
            size = stylArray[Number(styl.text)];
        }
        return {
            type: "genfrac",
            mode: parser.mode,
            numer,
            denom,
            continued: false,
            hasBarLine,
            barSize,
            leftDelim,
            rightDelim,
            size
        };
    },
    htmlBuilder: htmlBuilder$4,
    mathmlBuilder: mathmlBuilder$3
});
defineFunction({
    type: "infix",
    names: [
        "\\above"
    ],
    props: {
        numArgs: 1,
        argTypes: [
            "size"
        ],
        infix: true
    },
    handler (_ref5, args) {
        var { parser , funcName , token  } = _ref5;
        return {
            type: "infix",
            mode: parser.mode,
            replaceWith: "\\\\abovefrac",
            size: assertNodeType(args[0], "size").value,
            token
        };
    }
});
defineFunction({
    type: "genfrac",
    names: [
        "\\\\abovefrac"
    ],
    props: {
        numArgs: 3,
        argTypes: [
            "math",
            "size",
            "math"
        ]
    },
    handler: (_ref6, args)=>{
        var { parser , funcName  } = _ref6;
        var numer = args[0];
        var barSize = assert(assertNodeType(args[1], "infix").size);
        var denom = args[2];
        var hasBarLine = barSize.number > 0;
        return {
            type: "genfrac",
            mode: parser.mode,
            numer,
            denom,
            continued: false,
            hasBarLine,
            barSize,
            leftDelim: null,
            rightDelim: null,
            size: "auto"
        };
    },
    htmlBuilder: htmlBuilder$4,
    mathmlBuilder: mathmlBuilder$3
});
var htmlBuilder$3 = (grp, options)=>{
    var style = options.style;
    var supSubGroup;
    var group;
    if (grp.type === "supsub") {
        supSubGroup = grp.sup ? buildGroup$1(grp.sup, options.havingStyle(style.sup()), options) : buildGroup$1(grp.sub, options.havingStyle(style.sub()), options);
        group = assertNodeType(grp.base, "horizBrace");
    } else {
        group = assertNodeType(grp, "horizBrace");
    }
    var body = buildGroup$1(group.base, options.havingBaseStyle(Style$1.DISPLAY));
    var braceBody = stretchy.svgSpan(group, options);
    var vlist;
    if (group.isOver) {
        vlist = buildCommon.makeVList({
            positionType: "firstBaseline",
            children: [
                {
                    type: "elem",
                    elem: body
                },
                {
                    type: "kern",
                    size: 0.1
                },
                {
                    type: "elem",
                    elem: braceBody
                }
            ]
        }, options);
        vlist.children[0].children[0].children[1].classes.push("svg-align");
    } else {
        vlist = buildCommon.makeVList({
            positionType: "bottom",
            positionData: body.depth + 0.1 + braceBody.height,
            children: [
                {
                    type: "elem",
                    elem: braceBody
                },
                {
                    type: "kern",
                    size: 0.1
                },
                {
                    type: "elem",
                    elem: body
                }
            ]
        }, options);
        vlist.children[0].children[0].children[0].classes.push("svg-align");
    }
    if (supSubGroup) {
        var vSpan = buildCommon.makeSpan([
            "mord",
            group.isOver ? "mover" : "munder"
        ], [
            vlist
        ], options);
        if (group.isOver) {
            vlist = buildCommon.makeVList({
                positionType: "firstBaseline",
                children: [
                    {
                        type: "elem",
                        elem: vSpan
                    },
                    {
                        type: "kern",
                        size: 0.2
                    },
                    {
                        type: "elem",
                        elem: supSubGroup
                    }
                ]
            }, options);
        } else {
            vlist = buildCommon.makeVList({
                positionType: "bottom",
                positionData: vSpan.depth + 0.2 + supSubGroup.height + supSubGroup.depth,
                children: [
                    {
                        type: "elem",
                        elem: supSubGroup
                    },
                    {
                        type: "kern",
                        size: 0.2
                    },
                    {
                        type: "elem",
                        elem: vSpan
                    }
                ]
            }, options);
        }
    }
    return buildCommon.makeSpan([
        "mord",
        group.isOver ? "mover" : "munder"
    ], [
        vlist
    ], options);
};
var mathmlBuilder$2 = (group, options)=>{
    var accentNode = stretchy.mathMLnode(group.label);
    return new mathMLTree.MathNode(group.isOver ? "mover" : "munder", [
        buildGroup(group.base, options),
        accentNode
    ]);
};
defineFunction({
    type: "horizBrace",
    names: [
        "\\overbrace",
        "\\underbrace"
    ],
    props: {
        numArgs: 1
    },
    handler (_ref, args) {
        var { parser , funcName  } = _ref;
        return {
            type: "horizBrace",
            mode: parser.mode,
            label: funcName,
            isOver: /^\\over/.test(funcName),
            base: args[0]
        };
    },
    htmlBuilder: htmlBuilder$3,
    mathmlBuilder: mathmlBuilder$2
});
defineFunction({
    type: "href",
    names: [
        "\\href"
    ],
    props: {
        numArgs: 2,
        argTypes: [
            "url",
            "original"
        ],
        allowedInText: true
    },
    handler: (_ref, args)=>{
        var { parser  } = _ref;
        var body = args[1];
        var href = assertNodeType(args[0], "url").url;
        if (!parser.settings.isTrusted({
            command: "\\href",
            url: href
        })) {
            return parser.formatUnsupportedCmd("\\href");
        }
        return {
            type: "href",
            mode: parser.mode,
            href,
            body: ordargument(body)
        };
    },
    htmlBuilder: (group, options)=>{
        var elements = buildExpression$1(group.body, options, false);
        return buildCommon.makeAnchor(group.href, [], elements, options);
    },
    mathmlBuilder: (group, options)=>{
        var math = buildExpressionRow(group.body, options);
        if (!(math instanceof MathNode)) {
            math = new MathNode("mrow", [
                math
            ]);
        }
        math.setAttribute("href", group.href);
        return math;
    }
});
defineFunction({
    type: "href",
    names: [
        "\\url"
    ],
    props: {
        numArgs: 1,
        argTypes: [
            "url"
        ],
        allowedInText: true
    },
    handler: (_ref2, args)=>{
        var { parser  } = _ref2;
        var href = assertNodeType(args[0], "url").url;
        if (!parser.settings.isTrusted({
            command: "\\url",
            url: href
        })) {
            return parser.formatUnsupportedCmd("\\url");
        }
        var chars = [];
        for(var i = 0; i < href.length; i++){
            var c = href[i];
            if (c === "~") {
                c = "\\textasciitilde";
            }
            chars.push({
                type: "textord",
                mode: "text",
                text: c
            });
        }
        var body = {
            type: "text",
            mode: parser.mode,
            font: "\\texttt",
            body: chars
        };
        return {
            type: "href",
            mode: parser.mode,
            href,
            body: ordargument(body)
        };
    }
});
defineFunction({
    type: "hbox",
    names: [
        "\\hbox"
    ],
    props: {
        numArgs: 1,
        argTypes: [
            "text"
        ],
        allowedInText: true,
        primitive: true
    },
    handler (_ref, args) {
        var { parser  } = _ref;
        return {
            type: "hbox",
            mode: parser.mode,
            body: ordargument(args[0])
        };
    },
    htmlBuilder (group, options) {
        var elements = buildExpression$1(group.body, options, false);
        return buildCommon.makeFragment(elements);
    },
    mathmlBuilder (group, options) {
        return new mathMLTree.MathNode("mrow", buildExpression(group.body, options));
    }
});
defineFunction({
    type: "html",
    names: [
        "\\htmlClass",
        "\\htmlId",
        "\\htmlStyle",
        "\\htmlData"
    ],
    props: {
        numArgs: 2,
        argTypes: [
            "raw",
            "original"
        ],
        allowedInText: true
    },
    handler: (_ref, args)=>{
        var { parser , funcName , token  } = _ref;
        var value = assertNodeType(args[0], "raw").string;
        var body = args[1];
        if (parser.settings.strict) {
            parser.settings.reportNonstrict("htmlExtension", "HTML extension is disabled on strict mode");
        }
        var trustContext;
        var attributes = {};
        switch(funcName){
            case "\\htmlClass":
                attributes.class = value;
                trustContext = {
                    command: "\\htmlClass",
                    class: value
                };
                break;
            case "\\htmlId":
                attributes.id = value;
                trustContext = {
                    command: "\\htmlId",
                    id: value
                };
                break;
            case "\\htmlStyle":
                attributes.style = value;
                trustContext = {
                    command: "\\htmlStyle",
                    style: value
                };
                break;
            case "\\htmlData":
                {
                    var data = value.split(",");
                    for(var i = 0; i < data.length; i++){
                        var keyVal = data[i].split("=");
                        if (keyVal.length !== 2) {
                            throw new ParseError("Error parsing key-value for \\htmlData");
                        }
                        attributes["data-" + keyVal[0].trim()] = keyVal[1].trim();
                    }
                    trustContext = {
                        command: "\\htmlData",
                        attributes
                    };
                    break;
                }
            default:
                throw new Error("Unrecognized html command");
        }
        if (!parser.settings.isTrusted(trustContext)) {
            return parser.formatUnsupportedCmd(funcName);
        }
        return {
            type: "html",
            mode: parser.mode,
            attributes,
            body: ordargument(body)
        };
    },
    htmlBuilder: (group, options)=>{
        var elements = buildExpression$1(group.body, options, false);
        var classes = [
            "enclosing"
        ];
        if (group.attributes.class) {
            classes.push(...group.attributes.class.trim().split(/\s+/));
        }
        var span = buildCommon.makeSpan(classes, elements, options);
        for(var attr in group.attributes){
            if (attr !== "class" && group.attributes.hasOwnProperty(attr)) {
                span.setAttribute(attr, group.attributes[attr]);
            }
        }
        return span;
    },
    mathmlBuilder: (group, options)=>{
        return buildExpressionRow(group.body, options);
    }
});
defineFunction({
    type: "htmlmathml",
    names: [
        "\\html@mathml"
    ],
    props: {
        numArgs: 2,
        allowedInText: true
    },
    handler: (_ref, args)=>{
        var { parser  } = _ref;
        return {
            type: "htmlmathml",
            mode: parser.mode,
            html: ordargument(args[0]),
            mathml: ordargument(args[1])
        };
    },
    htmlBuilder: (group, options)=>{
        var elements = buildExpression$1(group.html, options, false);
        return buildCommon.makeFragment(elements);
    },
    mathmlBuilder: (group, options)=>{
        return buildExpressionRow(group.mathml, options);
    }
});
var sizeData = function sizeData(str) {
    if (/^[-+]? *(\d+(\.\d*)?|\.\d+)$/.test(str)) {
        return {
            number: +str,
            unit: "bp"
        };
    } else {
        var match = /([-+]?) *(\d+(?:\.\d*)?|\.\d+) *([a-z]{2})/.exec(str);
        if (!match) {
            throw new ParseError("Invalid size: '" + str + "' in \\includegraphics");
        }
        var data = {
            number: +(match[1] + match[2]),
            unit: match[3]
        };
        if (!validUnit(data)) {
            throw new ParseError("Invalid unit: '" + data.unit + "' in \\includegraphics.");
        }
        return data;
    }
};
defineFunction({
    type: "includegraphics",
    names: [
        "\\includegraphics"
    ],
    props: {
        numArgs: 1,
        numOptionalArgs: 1,
        argTypes: [
            "raw",
            "url"
        ],
        allowedInText: false
    },
    handler: (_ref, args, optArgs)=>{
        var { parser  } = _ref;
        var width = {
            number: 0,
            unit: "em"
        };
        var height = {
            number: 0.9,
            unit: "em"
        };
        var totalheight = {
            number: 0,
            unit: "em"
        };
        var alt = "";
        if (optArgs[0]) {
            var attributeStr = assertNodeType(optArgs[0], "raw").string;
            var attributes = attributeStr.split(",");
            for(var i = 0; i < attributes.length; i++){
                var keyVal = attributes[i].split("=");
                if (keyVal.length === 2) {
                    var str = keyVal[1].trim();
                    switch(keyVal[0].trim()){
                        case "alt":
                            alt = str;
                            break;
                        case "width":
                            width = sizeData(str);
                            break;
                        case "height":
                            height = sizeData(str);
                            break;
                        case "totalheight":
                            totalheight = sizeData(str);
                            break;
                        default:
                            throw new ParseError("Invalid key: '" + keyVal[0] + "' in \\includegraphics.");
                    }
                }
            }
        }
        var src = assertNodeType(args[0], "url").url;
        if (alt === "") {
            alt = src;
            alt = alt.replace(/^.*[\\/]/, '');
            alt = alt.substring(0, alt.lastIndexOf('.'));
        }
        if (!parser.settings.isTrusted({
            command: "\\includegraphics",
            url: src
        })) {
            return parser.formatUnsupportedCmd("\\includegraphics");
        }
        return {
            type: "includegraphics",
            mode: parser.mode,
            alt: alt,
            width: width,
            height: height,
            totalheight: totalheight,
            src: src
        };
    },
    htmlBuilder: (group, options)=>{
        var height = calculateSize(group.height, options);
        var depth = 0;
        if (group.totalheight.number > 0) {
            depth = calculateSize(group.totalheight, options) - height;
        }
        var width = 0;
        if (group.width.number > 0) {
            width = calculateSize(group.width, options);
        }
        var style = {
            height: makeEm(height + depth)
        };
        if (width > 0) {
            style.width = makeEm(width);
        }
        if (depth > 0) {
            style.verticalAlign = makeEm(-depth);
        }
        var node = new Img(group.src, group.alt, style);
        node.height = height;
        node.depth = depth;
        return node;
    },
    mathmlBuilder: (group, options)=>{
        var node = new mathMLTree.MathNode("mglyph", []);
        node.setAttribute("alt", group.alt);
        var height = calculateSize(group.height, options);
        var depth = 0;
        if (group.totalheight.number > 0) {
            depth = calculateSize(group.totalheight, options) - height;
            node.setAttribute("valign", makeEm(-depth));
        }
        node.setAttribute("height", makeEm(height + depth));
        if (group.width.number > 0) {
            var width = calculateSize(group.width, options);
            node.setAttribute("width", makeEm(width));
        }
        node.setAttribute("src", group.src);
        return node;
    }
});
defineFunction({
    type: "kern",
    names: [
        "\\kern",
        "\\mkern",
        "\\hskip",
        "\\mskip"
    ],
    props: {
        numArgs: 1,
        argTypes: [
            "size"
        ],
        primitive: true,
        allowedInText: true
    },
    handler (_ref, args) {
        var { parser , funcName  } = _ref;
        var size = assertNodeType(args[0], "size");
        if (parser.settings.strict) {
            var mathFunction = funcName[1] === 'm';
            var muUnit = size.value.unit === 'mu';
            if (mathFunction) {
                if (!muUnit) {
                    parser.settings.reportNonstrict("mathVsTextUnits", "LaTeX's " + funcName + " supports only mu units, " + ("not " + size.value.unit + " units"));
                }
                if (parser.mode !== "math") {
                    parser.settings.reportNonstrict("mathVsTextUnits", "LaTeX's " + funcName + " works only in math mode");
                }
            } else {
                if (muUnit) {
                    parser.settings.reportNonstrict("mathVsTextUnits", "LaTeX's " + funcName + " doesn't support mu units");
                }
            }
        }
        return {
            type: "kern",
            mode: parser.mode,
            dimension: size.value
        };
    },
    htmlBuilder (group, options) {
        return buildCommon.makeGlue(group.dimension, options);
    },
    mathmlBuilder (group, options) {
        var dimension = calculateSize(group.dimension, options);
        return new mathMLTree.SpaceNode(dimension);
    }
});
defineFunction({
    type: "lap",
    names: [
        "\\mathllap",
        "\\mathrlap",
        "\\mathclap"
    ],
    props: {
        numArgs: 1,
        allowedInText: true
    },
    handler: (_ref, args)=>{
        var { parser , funcName  } = _ref;
        var body = args[0];
        return {
            type: "lap",
            mode: parser.mode,
            alignment: funcName.slice(5),
            body
        };
    },
    htmlBuilder: (group, options)=>{
        var inner;
        if (group.alignment === "clap") {
            inner = buildCommon.makeSpan([], [
                buildGroup$1(group.body, options)
            ]);
            inner = buildCommon.makeSpan([
                "inner"
            ], [
                inner
            ], options);
        } else {
            inner = buildCommon.makeSpan([
                "inner"
            ], [
                buildGroup$1(group.body, options)
            ]);
        }
        var fix = buildCommon.makeSpan([
            "fix"
        ], []);
        var node = buildCommon.makeSpan([
            group.alignment
        ], [
            inner,
            fix
        ], options);
        var strut = buildCommon.makeSpan([
            "strut"
        ]);
        strut.style.height = makeEm(node.height + node.depth);
        if (node.depth) {
            strut.style.verticalAlign = makeEm(-node.depth);
        }
        node.children.unshift(strut);
        node = buildCommon.makeSpan([
            "thinbox"
        ], [
            node
        ], options);
        return buildCommon.makeSpan([
            "mord",
            "vbox"
        ], [
            node
        ], options);
    },
    mathmlBuilder: (group, options)=>{
        var node = new mathMLTree.MathNode("mpadded", [
            buildGroup(group.body, options)
        ]);
        if (group.alignment !== "rlap") {
            var offset = group.alignment === "llap" ? "-1" : "-0.5";
            node.setAttribute("lspace", offset + "width");
        }
        node.setAttribute("width", "0px");
        return node;
    }
});
defineFunction({
    type: "styling",
    names: [
        "\\(",
        "$"
    ],
    props: {
        numArgs: 0,
        allowedInText: true,
        allowedInMath: false
    },
    handler (_ref, args) {
        var { funcName , parser  } = _ref;
        var outerMode = parser.mode;
        parser.switchMode("math");
        var close = funcName === "\\(" ? "\\)" : "$";
        var body = parser.parseExpression(false, close);
        parser.expect(close);
        parser.switchMode(outerMode);
        return {
            type: "styling",
            mode: parser.mode,
            style: "text",
            body
        };
    }
});
defineFunction({
    type: "text",
    names: [
        "\\)",
        "\\]"
    ],
    props: {
        numArgs: 0,
        allowedInText: true,
        allowedInMath: false
    },
    handler (context, args) {
        throw new ParseError("Mismatched " + context.funcName);
    }
});
var chooseMathStyle = (group, options)=>{
    switch(options.style.size){
        case Style$1.DISPLAY.size:
            return group.display;
        case Style$1.TEXT.size:
            return group.text;
        case Style$1.SCRIPT.size:
            return group.script;
        case Style$1.SCRIPTSCRIPT.size:
            return group.scriptscript;
        default:
            return group.text;
    }
};
defineFunction({
    type: "mathchoice",
    names: [
        "\\mathchoice"
    ],
    props: {
        numArgs: 4,
        primitive: true
    },
    handler: (_ref, args)=>{
        var { parser  } = _ref;
        return {
            type: "mathchoice",
            mode: parser.mode,
            display: ordargument(args[0]),
            text: ordargument(args[1]),
            script: ordargument(args[2]),
            scriptscript: ordargument(args[3])
        };
    },
    htmlBuilder: (group, options)=>{
        var body = chooseMathStyle(group, options);
        var elements = buildExpression$1(body, options, false);
        return buildCommon.makeFragment(elements);
    },
    mathmlBuilder: (group, options)=>{
        var body = chooseMathStyle(group, options);
        return buildExpressionRow(body, options);
    }
});
var assembleSupSub = (base, supGroup, subGroup, options, style, slant, baseShift)=>{
    base = buildCommon.makeSpan([], [
        base
    ]);
    var subIsSingleCharacter = subGroup && utils.isCharacterBox(subGroup);
    var sub;
    var sup;
    if (supGroup) {
        var elem = buildGroup$1(supGroup, options.havingStyle(style.sup()), options);
        sup = {
            elem,
            kern: Math.max(options.fontMetrics().bigOpSpacing1, options.fontMetrics().bigOpSpacing3 - elem.depth)
        };
    }
    if (subGroup) {
        var _elem = buildGroup$1(subGroup, options.havingStyle(style.sub()), options);
        sub = {
            elem: _elem,
            kern: Math.max(options.fontMetrics().bigOpSpacing2, options.fontMetrics().bigOpSpacing4 - _elem.height)
        };
    }
    var finalGroup;
    if (sup && sub) {
        var bottom = options.fontMetrics().bigOpSpacing5 + sub.elem.height + sub.elem.depth + sub.kern + base.depth + baseShift;
        finalGroup = buildCommon.makeVList({
            positionType: "bottom",
            positionData: bottom,
            children: [
                {
                    type: "kern",
                    size: options.fontMetrics().bigOpSpacing5
                },
                {
                    type: "elem",
                    elem: sub.elem,
                    marginLeft: makeEm(-slant)
                },
                {
                    type: "kern",
                    size: sub.kern
                },
                {
                    type: "elem",
                    elem: base
                },
                {
                    type: "kern",
                    size: sup.kern
                },
                {
                    type: "elem",
                    elem: sup.elem,
                    marginLeft: makeEm(slant)
                },
                {
                    type: "kern",
                    size: options.fontMetrics().bigOpSpacing5
                }
            ]
        }, options);
    } else if (sub) {
        var top = base.height - baseShift;
        finalGroup = buildCommon.makeVList({
            positionType: "top",
            positionData: top,
            children: [
                {
                    type: "kern",
                    size: options.fontMetrics().bigOpSpacing5
                },
                {
                    type: "elem",
                    elem: sub.elem,
                    marginLeft: makeEm(-slant)
                },
                {
                    type: "kern",
                    size: sub.kern
                },
                {
                    type: "elem",
                    elem: base
                }
            ]
        }, options);
    } else if (sup) {
        var _bottom = base.depth + baseShift;
        finalGroup = buildCommon.makeVList({
            positionType: "bottom",
            positionData: _bottom,
            children: [
                {
                    type: "elem",
                    elem: base
                },
                {
                    type: "kern",
                    size: sup.kern
                },
                {
                    type: "elem",
                    elem: sup.elem,
                    marginLeft: makeEm(slant)
                },
                {
                    type: "kern",
                    size: options.fontMetrics().bigOpSpacing5
                }
            ]
        }, options);
    } else {
        return base;
    }
    var parts = [
        finalGroup
    ];
    if (sub && slant !== 0 && !subIsSingleCharacter) {
        var spacer = buildCommon.makeSpan([
            "mspace"
        ], [], options);
        spacer.style.marginRight = makeEm(slant);
        parts.unshift(spacer);
    }
    return buildCommon.makeSpan([
        "mop",
        "op-limits"
    ], parts, options);
};
var noSuccessor = [
    "\\smallint"
];
var htmlBuilder$2 = (grp, options)=>{
    var supGroup;
    var subGroup;
    var hasLimits = false;
    var group;
    if (grp.type === "supsub") {
        supGroup = grp.sup;
        subGroup = grp.sub;
        group = assertNodeType(grp.base, "op");
        hasLimits = true;
    } else {
        group = assertNodeType(grp, "op");
    }
    var style = options.style;
    var large = false;
    if (style.size === Style$1.DISPLAY.size && group.symbol && !utils.contains(noSuccessor, group.name)) {
        large = true;
    }
    var base;
    if (group.symbol) {
        var fontName = large ? "Size2-Regular" : "Size1-Regular";
        var stash = "";
        if (group.name === "\\oiint" || group.name === "\\oiiint") {
            stash = group.name.slice(1);
            group.name = stash === "oiint" ? "\\iint" : "\\iiint";
        }
        base = buildCommon.makeSymbol(group.name, fontName, "math", options, [
            "mop",
            "op-symbol",
            large ? "large-op" : "small-op"
        ]);
        if (stash.length > 0) {
            var italic = base.italic;
            var oval = buildCommon.staticSvg(stash + "Size" + (large ? "2" : "1"), options);
            base = buildCommon.makeVList({
                positionType: "individualShift",
                children: [
                    {
                        type: "elem",
                        elem: base,
                        shift: 0
                    },
                    {
                        type: "elem",
                        elem: oval,
                        shift: large ? 0.08 : 0
                    }
                ]
            }, options);
            group.name = "\\" + stash;
            base.classes.unshift("mop");
            base.italic = italic;
        }
    } else if (group.body) {
        var inner = buildExpression$1(group.body, options, true);
        if (inner.length === 1 && inner[0] instanceof SymbolNode) {
            base = inner[0];
            base.classes[0] = "mop";
        } else {
            base = buildCommon.makeSpan([
                "mop"
            ], inner, options);
        }
    } else {
        var output = [];
        for(var i = 1; i < group.name.length; i++){
            output.push(buildCommon.mathsym(group.name[i], group.mode, options));
        }
        base = buildCommon.makeSpan([
            "mop"
        ], output, options);
    }
    var baseShift = 0;
    var slant = 0;
    if ((base instanceof SymbolNode || group.name === "\\oiint" || group.name === "\\oiiint") && !group.suppressBaseShift) {
        baseShift = (base.height - base.depth) / 2 - options.fontMetrics().axisHeight;
        slant = base.italic;
    }
    if (hasLimits) {
        return assembleSupSub(base, supGroup, subGroup, options, style, slant, baseShift);
    } else {
        if (baseShift) {
            base.style.position = "relative";
            base.style.top = makeEm(baseShift);
        }
        return base;
    }
};
var mathmlBuilder$1 = (group, options)=>{
    var node;
    if (group.symbol) {
        node = new MathNode("mo", [
            makeText(group.name, group.mode)
        ]);
        if (utils.contains(noSuccessor, group.name)) {
            node.setAttribute("largeop", "false");
        }
    } else if (group.body) {
        node = new MathNode("mo", buildExpression(group.body, options));
    } else {
        node = new MathNode("mi", [
            new TextNode(group.name.slice(1))
        ]);
        var operator = new MathNode("mo", [
            makeText("\u2061", "text")
        ]);
        if (group.parentIsSupSub) {
            node = new MathNode("mrow", [
                node,
                operator
            ]);
        } else {
            node = newDocumentFragment([
                node,
                operator
            ]);
        }
    }
    return node;
};
var singleCharBigOps = {
    "\u220F": "\\prod",
    "\u2210": "\\coprod",
    "\u2211": "\\sum",
    "\u22c0": "\\bigwedge",
    "\u22c1": "\\bigvee",
    "\u22c2": "\\bigcap",
    "\u22c3": "\\bigcup",
    "\u2a00": "\\bigodot",
    "\u2a01": "\\bigoplus",
    "\u2a02": "\\bigotimes",
    "\u2a04": "\\biguplus",
    "\u2a06": "\\bigsqcup"
};
defineFunction({
    type: "op",
    names: [
        "\\coprod",
        "\\bigvee",
        "\\bigwedge",
        "\\biguplus",
        "\\bigcap",
        "\\bigcup",
        "\\intop",
        "\\prod",
        "\\sum",
        "\\bigotimes",
        "\\bigoplus",
        "\\bigodot",
        "\\bigsqcup",
        "\\smallint",
        "\u220F",
        "\u2210",
        "\u2211",
        "\u22c0",
        "\u22c1",
        "\u22c2",
        "\u22c3",
        "\u2a00",
        "\u2a01",
        "\u2a02",
        "\u2a04",
        "\u2a06"
    ],
    props: {
        numArgs: 0
    },
    handler: (_ref, args)=>{
        var { parser , funcName  } = _ref;
        var fName = funcName;
        if (fName.length === 1) {
            fName = singleCharBigOps[fName];
        }
        return {
            type: "op",
            mode: parser.mode,
            limits: true,
            parentIsSupSub: false,
            symbol: true,
            name: fName
        };
    },
    htmlBuilder: htmlBuilder$2,
    mathmlBuilder: mathmlBuilder$1
});
defineFunction({
    type: "op",
    names: [
        "\\mathop"
    ],
    props: {
        numArgs: 1,
        primitive: true
    },
    handler: (_ref2, args)=>{
        var { parser  } = _ref2;
        var body = args[0];
        return {
            type: "op",
            mode: parser.mode,
            limits: false,
            parentIsSupSub: false,
            symbol: false,
            body: ordargument(body)
        };
    },
    htmlBuilder: htmlBuilder$2,
    mathmlBuilder: mathmlBuilder$1
});
var singleCharIntegrals = {
    "\u222b": "\\int",
    "\u222c": "\\iint",
    "\u222d": "\\iiint",
    "\u222e": "\\oint",
    "\u222f": "\\oiint",
    "\u2230": "\\oiiint"
};
defineFunction({
    type: "op",
    names: [
        "\\arcsin",
        "\\arccos",
        "\\arctan",
        "\\arctg",
        "\\arcctg",
        "\\arg",
        "\\ch",
        "\\cos",
        "\\cosec",
        "\\cosh",
        "\\cot",
        "\\cotg",
        "\\coth",
        "\\csc",
        "\\ctg",
        "\\cth",
        "\\deg",
        "\\dim",
        "\\exp",
        "\\hom",
        "\\ker",
        "\\lg",
        "\\ln",
        "\\log",
        "\\sec",
        "\\sin",
        "\\sinh",
        "\\sh",
        "\\tan",
        "\\tanh",
        "\\tg",
        "\\th"
    ],
    props: {
        numArgs: 0
    },
    handler (_ref3) {
        var { parser , funcName  } = _ref3;
        return {
            type: "op",
            mode: parser.mode,
            limits: false,
            parentIsSupSub: false,
            symbol: false,
            name: funcName
        };
    },
    htmlBuilder: htmlBuilder$2,
    mathmlBuilder: mathmlBuilder$1
});
defineFunction({
    type: "op",
    names: [
        "\\det",
        "\\gcd",
        "\\inf",
        "\\lim",
        "\\max",
        "\\min",
        "\\Pr",
        "\\sup"
    ],
    props: {
        numArgs: 0
    },
    handler (_ref4) {
        var { parser , funcName  } = _ref4;
        return {
            type: "op",
            mode: parser.mode,
            limits: true,
            parentIsSupSub: false,
            symbol: false,
            name: funcName
        };
    },
    htmlBuilder: htmlBuilder$2,
    mathmlBuilder: mathmlBuilder$1
});
defineFunction({
    type: "op",
    names: [
        "\\int",
        "\\iint",
        "\\iiint",
        "\\oint",
        "\\oiint",
        "\\oiiint",
        "\u222b",
        "\u222c",
        "\u222d",
        "\u222e",
        "\u222f",
        "\u2230"
    ],
    props: {
        numArgs: 0
    },
    handler (_ref5) {
        var { parser , funcName  } = _ref5;
        var fName = funcName;
        if (fName.length === 1) {
            fName = singleCharIntegrals[fName];
        }
        return {
            type: "op",
            mode: parser.mode,
            limits: false,
            parentIsSupSub: false,
            symbol: true,
            name: fName
        };
    },
    htmlBuilder: htmlBuilder$2,
    mathmlBuilder: mathmlBuilder$1
});
var htmlBuilder$1 = (grp, options)=>{
    var supGroup;
    var subGroup;
    var hasLimits = false;
    var group;
    if (grp.type === "supsub") {
        supGroup = grp.sup;
        subGroup = grp.sub;
        group = assertNodeType(grp.base, "operatorname");
        hasLimits = true;
    } else {
        group = assertNodeType(grp, "operatorname");
    }
    var base;
    if (group.body.length > 0) {
        var body = group.body.map((child)=>{
            var childText = child.text;
            if (typeof childText === "string") {
                return {
                    type: "textord",
                    mode: child.mode,
                    text: childText
                };
            } else {
                return child;
            }
        });
        var expression = buildExpression$1(body, options.withFont("mathrm"), true);
        for(var i = 0; i < expression.length; i++){
            var child = expression[i];
            if (child instanceof SymbolNode) {
                child.text = child.text.replace(/\u2212/, "-").replace(/\u2217/, "*");
            }
        }
        base = buildCommon.makeSpan([
            "mop"
        ], expression, options);
    } else {
        base = buildCommon.makeSpan([
            "mop"
        ], [], options);
    }
    if (hasLimits) {
        return assembleSupSub(base, supGroup, subGroup, options, options.style, 0, 0);
    } else {
        return base;
    }
};
var mathmlBuilder = (group, options)=>{
    var expression = buildExpression(group.body, options.withFont("mathrm"));
    var isAllString = true;
    for(var i = 0; i < expression.length; i++){
        var node = expression[i];
        if (node instanceof mathMLTree.SpaceNode) ;
        else if (node instanceof mathMLTree.MathNode) {
            switch(node.type){
                case "mi":
                case "mn":
                case "ms":
                case "mspace":
                case "mtext":
                    break;
                case "mo":
                    {
                        var child = node.children[0];
                        if (node.children.length === 1 && child instanceof mathMLTree.TextNode) {
                            child.text = child.text.replace(/\u2212/, "-").replace(/\u2217/, "*");
                        } else {
                            isAllString = false;
                        }
                        break;
                    }
                default:
                    isAllString = false;
            }
        } else {
            isAllString = false;
        }
    }
    if (isAllString) {
        var word = expression.map((node)=>node.toText()).join("");
        expression = [
            new mathMLTree.TextNode(word)
        ];
    }
    var identifier = new mathMLTree.MathNode("mi", expression);
    identifier.setAttribute("mathvariant", "normal");
    var operator = new mathMLTree.MathNode("mo", [
        makeText("\u2061", "text")
    ]);
    if (group.parentIsSupSub) {
        return new mathMLTree.MathNode("mrow", [
            identifier,
            operator
        ]);
    } else {
        return mathMLTree.newDocumentFragment([
            identifier,
            operator
        ]);
    }
};
defineFunction({
    type: "operatorname",
    names: [
        "\\operatorname@",
        "\\operatornamewithlimits"
    ],
    props: {
        numArgs: 1
    },
    handler: (_ref, args)=>{
        var { parser , funcName  } = _ref;
        var body = args[0];
        return {
            type: "operatorname",
            mode: parser.mode,
            body: ordargument(body),
            alwaysHandleSupSub: funcName === "\\operatornamewithlimits",
            limits: false,
            parentIsSupSub: false
        };
    },
    htmlBuilder: htmlBuilder$1,
    mathmlBuilder
});
defineMacro("\\operatorname", "\\@ifstar\\operatornamewithlimits\\operatorname@");
defineFunctionBuilders({
    type: "ordgroup",
    htmlBuilder (group, options) {
        if (group.semisimple) {
            return buildCommon.makeFragment(buildExpression$1(group.body, options, false));
        }
        return buildCommon.makeSpan([
            "mord"
        ], buildExpression$1(group.body, options, true), options);
    },
    mathmlBuilder (group, options) {
        return buildExpressionRow(group.body, options, true);
    }
});
defineFunction({
    type: "overline",
    names: [
        "\\overline"
    ],
    props: {
        numArgs: 1
    },
    handler (_ref, args) {
        var { parser  } = _ref;
        var body = args[0];
        return {
            type: "overline",
            mode: parser.mode,
            body
        };
    },
    htmlBuilder (group, options) {
        var innerGroup = buildGroup$1(group.body, options.havingCrampedStyle());
        var line = buildCommon.makeLineSpan("overline-line", options);
        var defaultRuleThickness = options.fontMetrics().defaultRuleThickness;
        var vlist = buildCommon.makeVList({
            positionType: "firstBaseline",
            children: [
                {
                    type: "elem",
                    elem: innerGroup
                },
                {
                    type: "kern",
                    size: 3 * defaultRuleThickness
                },
                {
                    type: "elem",
                    elem: line
                },
                {
                    type: "kern",
                    size: defaultRuleThickness
                }
            ]
        }, options);
        return buildCommon.makeSpan([
            "mord",
            "overline"
        ], [
            vlist
        ], options);
    },
    mathmlBuilder (group, options) {
        var operator = new mathMLTree.MathNode("mo", [
            new mathMLTree.TextNode("\u203e")
        ]);
        operator.setAttribute("stretchy", "true");
        var node = new mathMLTree.MathNode("mover", [
            buildGroup(group.body, options),
            operator
        ]);
        node.setAttribute("accent", "true");
        return node;
    }
});
defineFunction({
    type: "phantom",
    names: [
        "\\phantom"
    ],
    props: {
        numArgs: 1,
        allowedInText: true
    },
    handler: (_ref, args)=>{
        var { parser  } = _ref;
        var body = args[0];
        return {
            type: "phantom",
            mode: parser.mode,
            body: ordargument(body)
        };
    },
    htmlBuilder: (group, options)=>{
        var elements = buildExpression$1(group.body, options.withPhantom(), false);
        return buildCommon.makeFragment(elements);
    },
    mathmlBuilder: (group, options)=>{
        var inner = buildExpression(group.body, options);
        return new mathMLTree.MathNode("mphantom", inner);
    }
});
defineFunction({
    type: "hphantom",
    names: [
        "\\hphantom"
    ],
    props: {
        numArgs: 1,
        allowedInText: true
    },
    handler: (_ref2, args)=>{
        var { parser  } = _ref2;
        var body = args[0];
        return {
            type: "hphantom",
            mode: parser.mode,
            body
        };
    },
    htmlBuilder: (group, options)=>{
        var node = buildCommon.makeSpan([], [
            buildGroup$1(group.body, options.withPhantom())
        ]);
        node.height = 0;
        node.depth = 0;
        if (node.children) {
            for(var i = 0; i < node.children.length; i++){
                node.children[i].height = 0;
                node.children[i].depth = 0;
            }
        }
        node = buildCommon.makeVList({
            positionType: "firstBaseline",
            children: [
                {
                    type: "elem",
                    elem: node
                }
            ]
        }, options);
        return buildCommon.makeSpan([
            "mord"
        ], [
            node
        ], options);
    },
    mathmlBuilder: (group, options)=>{
        var inner = buildExpression(ordargument(group.body), options);
        var phantom = new mathMLTree.MathNode("mphantom", inner);
        var node = new mathMLTree.MathNode("mpadded", [
            phantom
        ]);
        node.setAttribute("height", "0px");
        node.setAttribute("depth", "0px");
        return node;
    }
});
defineFunction({
    type: "vphantom",
    names: [
        "\\vphantom"
    ],
    props: {
        numArgs: 1,
        allowedInText: true
    },
    handler: (_ref3, args)=>{
        var { parser  } = _ref3;
        var body = args[0];
        return {
            type: "vphantom",
            mode: parser.mode,
            body
        };
    },
    htmlBuilder: (group, options)=>{
        var inner = buildCommon.makeSpan([
            "inner"
        ], [
            buildGroup$1(group.body, options.withPhantom())
        ]);
        var fix = buildCommon.makeSpan([
            "fix"
        ], []);
        return buildCommon.makeSpan([
            "mord",
            "rlap"
        ], [
            inner,
            fix
        ], options);
    },
    mathmlBuilder: (group, options)=>{
        var inner = buildExpression(ordargument(group.body), options);
        var phantom = new mathMLTree.MathNode("mphantom", inner);
        var node = new mathMLTree.MathNode("mpadded", [
            phantom
        ]);
        node.setAttribute("width", "0px");
        return node;
    }
});
defineFunction({
    type: "raisebox",
    names: [
        "\\raisebox"
    ],
    props: {
        numArgs: 2,
        argTypes: [
            "size",
            "hbox"
        ],
        allowedInText: true
    },
    handler (_ref, args) {
        var { parser  } = _ref;
        var amount = assertNodeType(args[0], "size").value;
        var body = args[1];
        return {
            type: "raisebox",
            mode: parser.mode,
            dy: amount,
            body
        };
    },
    htmlBuilder (group, options) {
        var body = buildGroup$1(group.body, options);
        var dy = calculateSize(group.dy, options);
        return buildCommon.makeVList({
            positionType: "shift",
            positionData: -dy,
            children: [
                {
                    type: "elem",
                    elem: body
                }
            ]
        }, options);
    },
    mathmlBuilder (group, options) {
        var node = new mathMLTree.MathNode("mpadded", [
            buildGroup(group.body, options)
        ]);
        var dy = group.dy.number + group.dy.unit;
        node.setAttribute("voffset", dy);
        return node;
    }
});
defineFunction({
    type: "internal",
    names: [
        "\\relax"
    ],
    props: {
        numArgs: 0,
        allowedInText: true
    },
    handler (_ref) {
        var { parser  } = _ref;
        return {
            type: "internal",
            mode: parser.mode
        };
    }
});
defineFunction({
    type: "rule",
    names: [
        "\\rule"
    ],
    props: {
        numArgs: 2,
        numOptionalArgs: 1,
        argTypes: [
            "size",
            "size",
            "size"
        ]
    },
    handler (_ref, args, optArgs) {
        var { parser  } = _ref;
        var shift = optArgs[0];
        var width = assertNodeType(args[0], "size");
        var height = assertNodeType(args[1], "size");
        return {
            type: "rule",
            mode: parser.mode,
            shift: shift && assertNodeType(shift, "size").value,
            width: width.value,
            height: height.value
        };
    },
    htmlBuilder (group, options) {
        var rule = buildCommon.makeSpan([
            "mord",
            "rule"
        ], [], options);
        var width = calculateSize(group.width, options);
        var height = calculateSize(group.height, options);
        var shift = group.shift ? calculateSize(group.shift, options) : 0;
        rule.style.borderRightWidth = makeEm(width);
        rule.style.borderTopWidth = makeEm(height);
        rule.style.bottom = makeEm(shift);
        rule.width = width;
        rule.height = height + shift;
        rule.depth = -shift;
        rule.maxFontSize = height * 1.125 * options.sizeMultiplier;
        return rule;
    },
    mathmlBuilder (group, options) {
        var width = calculateSize(group.width, options);
        var height = calculateSize(group.height, options);
        var shift = group.shift ? calculateSize(group.shift, options) : 0;
        var color = options.color && options.getColor() || "black";
        var rule = new mathMLTree.MathNode("mspace");
        rule.setAttribute("mathbackground", color);
        rule.setAttribute("width", makeEm(width));
        rule.setAttribute("height", makeEm(height));
        var wrapper = new mathMLTree.MathNode("mpadded", [
            rule
        ]);
        if (shift >= 0) {
            wrapper.setAttribute("height", makeEm(shift));
        } else {
            wrapper.setAttribute("height", makeEm(shift));
            wrapper.setAttribute("depth", makeEm(-shift));
        }
        wrapper.setAttribute("voffset", makeEm(shift));
        return wrapper;
    }
});
function sizingGroup(value, options, baseOptions) {
    var inner = buildExpression$1(value, options, false);
    var multiplier = options.sizeMultiplier / baseOptions.sizeMultiplier;
    for(var i = 0; i < inner.length; i++){
        var pos = inner[i].classes.indexOf("sizing");
        if (pos < 0) {
            Array.prototype.push.apply(inner[i].classes, options.sizingClasses(baseOptions));
        } else if (inner[i].classes[pos + 1] === "reset-size" + options.size) {
            inner[i].classes[pos + 1] = "reset-size" + baseOptions.size;
        }
        inner[i].height *= multiplier;
        inner[i].depth *= multiplier;
    }
    return buildCommon.makeFragment(inner);
}
var sizeFuncs = [
    "\\tiny",
    "\\sixptsize",
    "\\scriptsize",
    "\\footnotesize",
    "\\small",
    "\\normalsize",
    "\\large",
    "\\Large",
    "\\LARGE",
    "\\huge",
    "\\Huge"
];
var htmlBuilder = (group, options)=>{
    var newOptions = options.havingSize(group.size);
    return sizingGroup(group.body, newOptions, options);
};
defineFunction({
    type: "sizing",
    names: sizeFuncs,
    props: {
        numArgs: 0,
        allowedInText: true
    },
    handler: (_ref, args)=>{
        var { breakOnTokenText , funcName , parser  } = _ref;
        var body = parser.parseExpression(false, breakOnTokenText);
        return {
            type: "sizing",
            mode: parser.mode,
            size: sizeFuncs.indexOf(funcName) + 1,
            body
        };
    },
    htmlBuilder,
    mathmlBuilder: (group, options)=>{
        var newOptions = options.havingSize(group.size);
        var inner = buildExpression(group.body, newOptions);
        var node = new mathMLTree.MathNode("mstyle", inner);
        node.setAttribute("mathsize", makeEm(newOptions.sizeMultiplier));
        return node;
    }
});
defineFunction({
    type: "smash",
    names: [
        "\\smash"
    ],
    props: {
        numArgs: 1,
        numOptionalArgs: 1,
        allowedInText: true
    },
    handler: (_ref, args, optArgs)=>{
        var { parser  } = _ref;
        var smashHeight = false;
        var smashDepth = false;
        var tbArg = optArgs[0] && assertNodeType(optArgs[0], "ordgroup");
        if (tbArg) {
            var letter = "";
            for(var i = 0; i < tbArg.body.length; ++i){
                var node = tbArg.body[i];
                letter = node.text;
                if (letter === "t") {
                    smashHeight = true;
                } else if (letter === "b") {
                    smashDepth = true;
                } else {
                    smashHeight = false;
                    smashDepth = false;
                    break;
                }
            }
        } else {
            smashHeight = true;
            smashDepth = true;
        }
        var body = args[0];
        return {
            type: "smash",
            mode: parser.mode,
            body,
            smashHeight,
            smashDepth
        };
    },
    htmlBuilder: (group, options)=>{
        var node = buildCommon.makeSpan([], [
            buildGroup$1(group.body, options)
        ]);
        if (!group.smashHeight && !group.smashDepth) {
            return node;
        }
        if (group.smashHeight) {
            node.height = 0;
            if (node.children) {
                for(var i = 0; i < node.children.length; i++){
                    node.children[i].height = 0;
                }
            }
        }
        if (group.smashDepth) {
            node.depth = 0;
            if (node.children) {
                for(var _i = 0; _i < node.children.length; _i++){
                    node.children[_i].depth = 0;
                }
            }
        }
        var smashedNode = buildCommon.makeVList({
            positionType: "firstBaseline",
            children: [
                {
                    type: "elem",
                    elem: node
                }
            ]
        }, options);
        return buildCommon.makeSpan([
            "mord"
        ], [
            smashedNode
        ], options);
    },
    mathmlBuilder: (group, options)=>{
        var node = new mathMLTree.MathNode("mpadded", [
            buildGroup(group.body, options)
        ]);
        if (group.smashHeight) {
            node.setAttribute("height", "0px");
        }
        if (group.smashDepth) {
            node.setAttribute("depth", "0px");
        }
        return node;
    }
});
defineFunction({
    type: "sqrt",
    names: [
        "\\sqrt"
    ],
    props: {
        numArgs: 1,
        numOptionalArgs: 1
    },
    handler (_ref, args, optArgs) {
        var { parser  } = _ref;
        var index = optArgs[0];
        var body = args[0];
        return {
            type: "sqrt",
            mode: parser.mode,
            body,
            index
        };
    },
    htmlBuilder (group, options) {
        var inner = buildGroup$1(group.body, options.havingCrampedStyle());
        if (inner.height === 0) {
            inner.height = options.fontMetrics().xHeight;
        }
        inner = buildCommon.wrapFragment(inner, options);
        var metrics = options.fontMetrics();
        var theta = metrics.defaultRuleThickness;
        var phi = theta;
        if (options.style.id < Style$1.TEXT.id) {
            phi = options.fontMetrics().xHeight;
        }
        var lineClearance = theta + phi / 4;
        var minDelimiterHeight = inner.height + inner.depth + lineClearance + theta;
        var { span: img , ruleWidth , advanceWidth  } = delimiter.sqrtImage(minDelimiterHeight, options);
        var delimDepth = img.height - ruleWidth;
        if (delimDepth > inner.height + inner.depth + lineClearance) {
            lineClearance = (lineClearance + delimDepth - inner.height - inner.depth) / 2;
        }
        var imgShift = img.height - inner.height - lineClearance - ruleWidth;
        inner.style.paddingLeft = makeEm(advanceWidth);
        var body = buildCommon.makeVList({
            positionType: "firstBaseline",
            children: [
                {
                    type: "elem",
                    elem: inner,
                    wrapperClasses: [
                        "svg-align"
                    ]
                },
                {
                    type: "kern",
                    size: -(inner.height + imgShift)
                },
                {
                    type: "elem",
                    elem: img
                },
                {
                    type: "kern",
                    size: ruleWidth
                }
            ]
        }, options);
        if (!group.index) {
            return buildCommon.makeSpan([
                "mord",
                "sqrt"
            ], [
                body
            ], options);
        } else {
            var newOptions = options.havingStyle(Style$1.SCRIPTSCRIPT);
            var rootm = buildGroup$1(group.index, newOptions, options);
            var toShift = 0.6 * (body.height - body.depth);
            var rootVList = buildCommon.makeVList({
                positionType: "shift",
                positionData: -toShift,
                children: [
                    {
                        type: "elem",
                        elem: rootm
                    }
                ]
            }, options);
            var rootVListWrap = buildCommon.makeSpan([
                "root"
            ], [
                rootVList
            ]);
            return buildCommon.makeSpan([
                "mord",
                "sqrt"
            ], [
                rootVListWrap,
                body
            ], options);
        }
    },
    mathmlBuilder (group, options) {
        var { body , index  } = group;
        return index ? new mathMLTree.MathNode("mroot", [
            buildGroup(body, options),
            buildGroup(index, options)
        ]) : new mathMLTree.MathNode("msqrt", [
            buildGroup(body, options)
        ]);
    }
});
var styleMap = {
    "display": Style$1.DISPLAY,
    "text": Style$1.TEXT,
    "script": Style$1.SCRIPT,
    "scriptscript": Style$1.SCRIPTSCRIPT
};
defineFunction({
    type: "styling",
    names: [
        "\\displaystyle",
        "\\textstyle",
        "\\scriptstyle",
        "\\scriptscriptstyle"
    ],
    props: {
        numArgs: 0,
        allowedInText: true,
        primitive: true
    },
    handler (_ref, args) {
        var { breakOnTokenText , funcName , parser  } = _ref;
        var body = parser.parseExpression(true, breakOnTokenText);
        var style = funcName.slice(1, funcName.length - 5);
        return {
            type: "styling",
            mode: parser.mode,
            style,
            body
        };
    },
    htmlBuilder (group, options) {
        var newStyle = styleMap[group.style];
        var newOptions = options.havingStyle(newStyle).withFont('');
        return sizingGroup(group.body, newOptions, options);
    },
    mathmlBuilder (group, options) {
        var newStyle = styleMap[group.style];
        var newOptions = options.havingStyle(newStyle);
        var inner = buildExpression(group.body, newOptions);
        var node = new mathMLTree.MathNode("mstyle", inner);
        var styleAttributes = {
            "display": [
                "0",
                "true"
            ],
            "text": [
                "0",
                "false"
            ],
            "script": [
                "1",
                "false"
            ],
            "scriptscript": [
                "2",
                "false"
            ]
        };
        var attr = styleAttributes[group.style];
        node.setAttribute("scriptlevel", attr[0]);
        node.setAttribute("displaystyle", attr[1]);
        return node;
    }
});
var htmlBuilderDelegate = function htmlBuilderDelegate(group, options) {
    var base = group.base;
    if (!base) {
        return null;
    } else if (base.type === "op") {
        var delegate = base.limits && (options.style.size === Style$1.DISPLAY.size || base.alwaysHandleSupSub);
        return delegate ? htmlBuilder$2 : null;
    } else if (base.type === "operatorname") {
        var _delegate = base.alwaysHandleSupSub && (options.style.size === Style$1.DISPLAY.size || base.limits);
        return _delegate ? htmlBuilder$1 : null;
    } else if (base.type === "accent") {
        return utils.isCharacterBox(base.base) ? htmlBuilder$a : null;
    } else if (base.type === "horizBrace") {
        var isSup = !group.sub;
        return isSup === base.isOver ? htmlBuilder$3 : null;
    } else {
        return null;
    }
};
defineFunctionBuilders({
    type: "supsub",
    htmlBuilder (group, options) {
        var builderDelegate = htmlBuilderDelegate(group, options);
        if (builderDelegate) {
            return builderDelegate(group, options);
        }
        var { base: valueBase , sup: valueSup , sub: valueSub  } = group;
        var base = buildGroup$1(valueBase, options);
        var supm;
        var subm;
        var metrics = options.fontMetrics();
        var supShift = 0;
        var subShift = 0;
        var isCharacterBox = valueBase && utils.isCharacterBox(valueBase);
        if (valueSup) {
            var newOptions = options.havingStyle(options.style.sup());
            supm = buildGroup$1(valueSup, newOptions, options);
            if (!isCharacterBox) {
                supShift = base.height - newOptions.fontMetrics().supDrop * newOptions.sizeMultiplier / options.sizeMultiplier;
            }
        }
        if (valueSub) {
            var _newOptions = options.havingStyle(options.style.sub());
            subm = buildGroup$1(valueSub, _newOptions, options);
            if (!isCharacterBox) {
                subShift = base.depth + _newOptions.fontMetrics().subDrop * _newOptions.sizeMultiplier / options.sizeMultiplier;
            }
        }
        var minSupShift;
        if (options.style === Style$1.DISPLAY) {
            minSupShift = metrics.sup1;
        } else if (options.style.cramped) {
            minSupShift = metrics.sup3;
        } else {
            minSupShift = metrics.sup2;
        }
        var multiplier = options.sizeMultiplier;
        var marginRight = makeEm(0.5 / metrics.ptPerEm / multiplier);
        var marginLeft = null;
        if (subm) {
            var isOiint = group.base && group.base.type === "op" && group.base.name && (group.base.name === "\\oiint" || group.base.name === "\\oiiint");
            if (base instanceof SymbolNode || isOiint) {
                marginLeft = makeEm(-base.italic);
            }
        }
        var supsub;
        if (supm && subm) {
            supShift = Math.max(supShift, minSupShift, supm.depth + 0.25 * metrics.xHeight);
            subShift = Math.max(subShift, metrics.sub2);
            var ruleWidth = metrics.defaultRuleThickness;
            var maxWidth = 4 * ruleWidth;
            if (supShift - supm.depth - (subm.height - subShift) < maxWidth) {
                subShift = maxWidth - (supShift - supm.depth) + subm.height;
                var psi = 0.8 * metrics.xHeight - (supShift - supm.depth);
                if (psi > 0) {
                    supShift += psi;
                    subShift -= psi;
                }
            }
            var vlistElem = [
                {
                    type: "elem",
                    elem: subm,
                    shift: subShift,
                    marginRight,
                    marginLeft
                },
                {
                    type: "elem",
                    elem: supm,
                    shift: -supShift,
                    marginRight
                }
            ];
            supsub = buildCommon.makeVList({
                positionType: "individualShift",
                children: vlistElem
            }, options);
        } else if (subm) {
            subShift = Math.max(subShift, metrics.sub1, subm.height - 0.8 * metrics.xHeight);
            var _vlistElem = [
                {
                    type: "elem",
                    elem: subm,
                    marginLeft,
                    marginRight
                }
            ];
            supsub = buildCommon.makeVList({
                positionType: "shift",
                positionData: subShift,
                children: _vlistElem
            }, options);
        } else if (supm) {
            supShift = Math.max(supShift, minSupShift, supm.depth + 0.25 * metrics.xHeight);
            supsub = buildCommon.makeVList({
                positionType: "shift",
                positionData: -supShift,
                children: [
                    {
                        type: "elem",
                        elem: supm,
                        marginRight
                    }
                ]
            }, options);
        } else {
            throw new Error("supsub must have either sup or sub.");
        }
        var mclass = getTypeOfDomTree(base, "right") || "mord";
        return buildCommon.makeSpan([
            mclass
        ], [
            base,
            buildCommon.makeSpan([
                "msupsub"
            ], [
                supsub
            ])
        ], options);
    },
    mathmlBuilder (group, options) {
        var isBrace = false;
        var isOver;
        var isSup;
        if (group.base && group.base.type === "horizBrace") {
            isSup = !!group.sup;
            if (isSup === group.base.isOver) {
                isBrace = true;
                isOver = group.base.isOver;
            }
        }
        if (group.base && (group.base.type === "op" || group.base.type === "operatorname")) {
            group.base.parentIsSupSub = true;
        }
        var children = [
            buildGroup(group.base, options)
        ];
        if (group.sub) {
            children.push(buildGroup(group.sub, options));
        }
        if (group.sup) {
            children.push(buildGroup(group.sup, options));
        }
        var nodeType;
        if (isBrace) {
            nodeType = isOver ? "mover" : "munder";
        } else if (!group.sub) {
            var base = group.base;
            if (base && base.type === "op" && base.limits && (options.style === Style$1.DISPLAY || base.alwaysHandleSupSub)) {
                nodeType = "mover";
            } else if (base && base.type === "operatorname" && base.alwaysHandleSupSub && (base.limits || options.style === Style$1.DISPLAY)) {
                nodeType = "mover";
            } else {
                nodeType = "msup";
            }
        } else if (!group.sup) {
            var _base = group.base;
            if (_base && _base.type === "op" && _base.limits && (options.style === Style$1.DISPLAY || _base.alwaysHandleSupSub)) {
                nodeType = "munder";
            } else if (_base && _base.type === "operatorname" && _base.alwaysHandleSupSub && (_base.limits || options.style === Style$1.DISPLAY)) {
                nodeType = "munder";
            } else {
                nodeType = "msub";
            }
        } else {
            var _base2 = group.base;
            if (_base2 && _base2.type === "op" && _base2.limits && options.style === Style$1.DISPLAY) {
                nodeType = "munderover";
            } else if (_base2 && _base2.type === "operatorname" && _base2.alwaysHandleSupSub && (options.style === Style$1.DISPLAY || _base2.limits)) {
                nodeType = "munderover";
            } else {
                nodeType = "msubsup";
            }
        }
        return new mathMLTree.MathNode(nodeType, children);
    }
});
defineFunctionBuilders({
    type: "atom",
    htmlBuilder (group, options) {
        return buildCommon.mathsym(group.text, group.mode, options, [
            "m" + group.family
        ]);
    },
    mathmlBuilder (group, options) {
        var node = new mathMLTree.MathNode("mo", [
            makeText(group.text, group.mode)
        ]);
        if (group.family === "bin") {
            var variant = getVariant(group, options);
            if (variant === "bold-italic") {
                node.setAttribute("mathvariant", variant);
            }
        } else if (group.family === "punct") {
            node.setAttribute("separator", "true");
        } else if (group.family === "open" || group.family === "close") {
            node.setAttribute("stretchy", "false");
        }
        return node;
    }
});
var defaultVariant = {
    "mi": "italic",
    "mn": "normal",
    "mtext": "normal"
};
defineFunctionBuilders({
    type: "mathord",
    htmlBuilder (group, options) {
        return buildCommon.makeOrd(group, options, "mathord");
    },
    mathmlBuilder (group, options) {
        var node = new mathMLTree.MathNode("mi", [
            makeText(group.text, group.mode, options)
        ]);
        var variant = getVariant(group, options) || "italic";
        if (variant !== defaultVariant[node.type]) {
            node.setAttribute("mathvariant", variant);
        }
        return node;
    }
});
defineFunctionBuilders({
    type: "textord",
    htmlBuilder (group, options) {
        return buildCommon.makeOrd(group, options, "textord");
    },
    mathmlBuilder (group, options) {
        var text = makeText(group.text, group.mode, options);
        var variant = getVariant(group, options) || "normal";
        var node;
        if (group.mode === 'text') {
            node = new mathMLTree.MathNode("mtext", [
                text
            ]);
        } else if (/[0-9]/.test(group.text)) {
            node = new mathMLTree.MathNode("mn", [
                text
            ]);
        } else if (group.text === "\\prime") {
            node = new mathMLTree.MathNode("mo", [
                text
            ]);
        } else {
            node = new mathMLTree.MathNode("mi", [
                text
            ]);
        }
        if (variant !== defaultVariant[node.type]) {
            node.setAttribute("mathvariant", variant);
        }
        return node;
    }
});
var cssSpace = {
    "\\nobreak": "nobreak",
    "\\allowbreak": "allowbreak"
};
var regularSpace = {
    " ": {},
    "\\ ": {},
    "~": {
        className: "nobreak"
    },
    "\\space": {},
    "\\nobreakspace": {
        className: "nobreak"
    }
};
defineFunctionBuilders({
    type: "spacing",
    htmlBuilder (group, options) {
        if (regularSpace.hasOwnProperty(group.text)) {
            var className = regularSpace[group.text].className || "";
            if (group.mode === "text") {
                var ord = buildCommon.makeOrd(group, options, "textord");
                ord.classes.push(className);
                return ord;
            } else {
                return buildCommon.makeSpan([
                    "mspace",
                    className
                ], [
                    buildCommon.mathsym(group.text, group.mode, options)
                ], options);
            }
        } else if (cssSpace.hasOwnProperty(group.text)) {
            return buildCommon.makeSpan([
                "mspace",
                cssSpace[group.text]
            ], [], options);
        } else {
            throw new ParseError("Unknown type of space \"" + group.text + "\"");
        }
    },
    mathmlBuilder (group, options) {
        var node;
        if (regularSpace.hasOwnProperty(group.text)) {
            node = new mathMLTree.MathNode("mtext", [
                new mathMLTree.TextNode("\u00a0")
            ]);
        } else if (cssSpace.hasOwnProperty(group.text)) {
            return new mathMLTree.MathNode("mspace");
        } else {
            throw new ParseError("Unknown type of space \"" + group.text + "\"");
        }
        return node;
    }
});
var pad = ()=>{
    var padNode = new mathMLTree.MathNode("mtd", []);
    padNode.setAttribute("width", "50%");
    return padNode;
};
defineFunctionBuilders({
    type: "tag",
    mathmlBuilder (group, options) {
        var table = new mathMLTree.MathNode("mtable", [
            new mathMLTree.MathNode("mtr", [
                pad(),
                new mathMLTree.MathNode("mtd", [
                    buildExpressionRow(group.body, options)
                ]),
                pad(),
                new mathMLTree.MathNode("mtd", [
                    buildExpressionRow(group.tag, options)
                ])
            ])
        ]);
        table.setAttribute("width", "100%");
        return table;
    }
});
var textFontFamilies = {
    "\\text": undefined,
    "\\textrm": "textrm",
    "\\textsf": "textsf",
    "\\texttt": "texttt",
    "\\textnormal": "textrm"
};
var textFontWeights = {
    "\\textbf": "textbf",
    "\\textmd": "textmd"
};
var textFontShapes = {
    "\\textit": "textit",
    "\\textup": "textup"
};
var optionsWithFont = (group, options)=>{
    var font = group.font;
    if (!font) {
        return options;
    } else if (textFontFamilies[font]) {
        return options.withTextFontFamily(textFontFamilies[font]);
    } else if (textFontWeights[font]) {
        return options.withTextFontWeight(textFontWeights[font]);
    } else {
        return options.withTextFontShape(textFontShapes[font]);
    }
};
defineFunction({
    type: "text",
    names: [
        "\\text",
        "\\textrm",
        "\\textsf",
        "\\texttt",
        "\\textnormal",
        "\\textbf",
        "\\textmd",
        "\\textit",
        "\\textup"
    ],
    props: {
        numArgs: 1,
        argTypes: [
            "text"
        ],
        allowedInArgument: true,
        allowedInText: true
    },
    handler (_ref, args) {
        var { parser , funcName  } = _ref;
        var body = args[0];
        return {
            type: "text",
            mode: parser.mode,
            body: ordargument(body),
            font: funcName
        };
    },
    htmlBuilder (group, options) {
        var newOptions = optionsWithFont(group, options);
        var inner = buildExpression$1(group.body, newOptions, true);
        return buildCommon.makeSpan([
            "mord",
            "text"
        ], inner, newOptions);
    },
    mathmlBuilder (group, options) {
        var newOptions = optionsWithFont(group, options);
        return buildExpressionRow(group.body, newOptions);
    }
});
defineFunction({
    type: "underline",
    names: [
        "\\underline"
    ],
    props: {
        numArgs: 1,
        allowedInText: true
    },
    handler (_ref, args) {
        var { parser  } = _ref;
        return {
            type: "underline",
            mode: parser.mode,
            body: args[0]
        };
    },
    htmlBuilder (group, options) {
        var innerGroup = buildGroup$1(group.body, options);
        var line = buildCommon.makeLineSpan("underline-line", options);
        var defaultRuleThickness = options.fontMetrics().defaultRuleThickness;
        var vlist = buildCommon.makeVList({
            positionType: "top",
            positionData: innerGroup.height,
            children: [
                {
                    type: "kern",
                    size: defaultRuleThickness
                },
                {
                    type: "elem",
                    elem: line
                },
                {
                    type: "kern",
                    size: 3 * defaultRuleThickness
                },
                {
                    type: "elem",
                    elem: innerGroup
                }
            ]
        }, options);
        return buildCommon.makeSpan([
            "mord",
            "underline"
        ], [
            vlist
        ], options);
    },
    mathmlBuilder (group, options) {
        var operator = new mathMLTree.MathNode("mo", [
            new mathMLTree.TextNode("\u203e")
        ]);
        operator.setAttribute("stretchy", "true");
        var node = new mathMLTree.MathNode("munder", [
            buildGroup(group.body, options),
            operator
        ]);
        node.setAttribute("accentunder", "true");
        return node;
    }
});
defineFunction({
    type: "vcenter",
    names: [
        "\\vcenter"
    ],
    props: {
        numArgs: 1,
        argTypes: [
            "original"
        ],
        allowedInText: false
    },
    handler (_ref, args) {
        var { parser  } = _ref;
        return {
            type: "vcenter",
            mode: parser.mode,
            body: args[0]
        };
    },
    htmlBuilder (group, options) {
        var body = buildGroup$1(group.body, options);
        var axisHeight = options.fontMetrics().axisHeight;
        var dy = 0.5 * (body.height - axisHeight - (body.depth + axisHeight));
        return buildCommon.makeVList({
            positionType: "shift",
            positionData: dy,
            children: [
                {
                    type: "elem",
                    elem: body
                }
            ]
        }, options);
    },
    mathmlBuilder (group, options) {
        return new mathMLTree.MathNode("mpadded", [
            buildGroup(group.body, options)
        ], [
            "vcenter"
        ]);
    }
});
defineFunction({
    type: "verb",
    names: [
        "\\verb"
    ],
    props: {
        numArgs: 0,
        allowedInText: true
    },
    handler (context, args, optArgs) {
        throw new ParseError("\\verb ended by end of line instead of matching delimiter");
    },
    htmlBuilder (group, options) {
        var text = makeVerb(group);
        var body = [];
        var newOptions = options.havingStyle(options.style.text());
        for(var i = 0; i < text.length; i++){
            var c = text[i];
            if (c === '~') {
                c = '\\textasciitilde';
            }
            body.push(buildCommon.makeSymbol(c, "Typewriter-Regular", group.mode, newOptions, [
                "mord",
                "texttt"
            ]));
        }
        return buildCommon.makeSpan([
            "mord",
            "text"
        ].concat(newOptions.sizingClasses(options)), buildCommon.tryCombineChars(body), newOptions);
    },
    mathmlBuilder (group, options) {
        var text = new mathMLTree.TextNode(makeVerb(group));
        var node = new mathMLTree.MathNode("mtext", [
            text
        ]);
        node.setAttribute("mathvariant", "monospace");
        return node;
    }
});
var makeVerb = (group)=>group.body.replace(/ /g, group.star ? '\u2423' : '\xA0');
var functions = _functions;
var spaceRegexString = "[ \r\n\t]";
var controlWordRegexString = "\\\\[a-zA-Z@]+";
var controlSymbolRegexString = "\\\\[^\uD800-\uDFFF]";
var controlWordWhitespaceRegexString = "(" + controlWordRegexString + ")" + spaceRegexString + "*";
var controlSpaceRegexString = "\\\\(\n|[ \r\t]+\n?)[ \r\t]*";
var combiningDiacriticalMarkString = "[\u0300-\u036f]";
var combiningDiacriticalMarksEndRegex = new RegExp(combiningDiacriticalMarkString + "+$");
var tokenRegexString = "(" + spaceRegexString + "+)|" + (controlSpaceRegexString + "|") + "([!-\\[\\]-\u2027\u202A-\uD7FF\uF900-\uFFFF]" + (combiningDiacriticalMarkString + "*") + "|[\uD800-\uDBFF][\uDC00-\uDFFF]" + (combiningDiacriticalMarkString + "*") + "|\\\\verb\\*([^]).*?\\4" + "|\\\\verb([^*a-zA-Z]).*?\\5" + ("|" + controlWordWhitespaceRegexString) + ("|" + controlSymbolRegexString + ")");
class Lexer {
    constructor(input, settings){
        this.input = void 0;
        this.settings = void 0;
        this.tokenRegex = void 0;
        this.catcodes = void 0;
        this.input = input;
        this.settings = settings;
        this.tokenRegex = new RegExp(tokenRegexString, 'g');
        this.catcodes = {
            "%": 14,
            "~": 13
        };
    }
    setCatcode(__char, code) {
        this.catcodes[__char] = code;
    }
    lex() {
        var input = this.input;
        var pos = this.tokenRegex.lastIndex;
        if (pos === input.length) {
            return new Token("EOF", new SourceLocation(this, pos, pos));
        }
        var match = this.tokenRegex.exec(input);
        if (match === null || match.index !== pos) {
            throw new ParseError("Unexpected character: '" + input[pos] + "'", new Token(input[pos], new SourceLocation(this, pos, pos + 1)));
        }
        var text = match[6] || match[3] || (match[2] ? "\\ " : " ");
        if (this.catcodes[text] === 14) {
            var nlIndex = input.indexOf('\n', this.tokenRegex.lastIndex);
            if (nlIndex === -1) {
                this.tokenRegex.lastIndex = input.length;
                this.settings.reportNonstrict("commentAtEnd", "% comment has no terminating newline; LaTeX would " + "fail because of commenting the end of math mode (e.g. $)");
            } else {
                this.tokenRegex.lastIndex = nlIndex + 1;
            }
            return this.lex();
        }
        return new Token(text, new SourceLocation(this, pos, this.tokenRegex.lastIndex));
    }
}
class Namespace {
    constructor(builtins, globalMacros){
        if (builtins === void 0) {
            builtins = {};
        }
        if (globalMacros === void 0) {
            globalMacros = {};
        }
        this.current = void 0;
        this.builtins = void 0;
        this.undefStack = void 0;
        this.current = globalMacros;
        this.builtins = builtins;
        this.undefStack = [];
    }
    beginGroup() {
        this.undefStack.push({});
    }
    endGroup() {
        if (this.undefStack.length === 0) {
            throw new ParseError("Unbalanced namespace destruction: attempt " + "to pop global namespace; please report this as a bug");
        }
        var undefs = this.undefStack.pop();
        for(var undef in undefs){
            if (undefs.hasOwnProperty(undef)) {
                if (undefs[undef] == null) {
                    delete this.current[undef];
                } else {
                    this.current[undef] = undefs[undef];
                }
            }
        }
    }
    endGroups() {
        while(this.undefStack.length > 0){
            this.endGroup();
        }
    }
    has(name) {
        return this.current.hasOwnProperty(name) || this.builtins.hasOwnProperty(name);
    }
    get(name) {
        if (this.current.hasOwnProperty(name)) {
            return this.current[name];
        } else {
            return this.builtins[name];
        }
    }
    set(name, value, global) {
        if (global === void 0) {
            global = false;
        }
        if (global) {
            for(var i = 0; i < this.undefStack.length; i++){
                delete this.undefStack[i][name];
            }
            if (this.undefStack.length > 0) {
                this.undefStack[this.undefStack.length - 1][name] = value;
            }
        } else {
            var top = this.undefStack[this.undefStack.length - 1];
            if (top && !top.hasOwnProperty(name)) {
                top[name] = this.current[name];
            }
        }
        if (value == null) {
            delete this.current[name];
        } else {
            this.current[name] = value;
        }
    }
}
var macros = _macros;
defineMacro("\\noexpand", function(context) {
    var t = context.popToken();
    if (context.isExpandable(t.text)) {
        t.noexpand = true;
        t.treatAsRelax = true;
    }
    return {
        tokens: [
            t
        ],
        numArgs: 0
    };
});
defineMacro("\\expandafter", function(context) {
    var t = context.popToken();
    context.expandOnce(true);
    return {
        tokens: [
            t
        ],
        numArgs: 0
    };
});
defineMacro("\\@firstoftwo", function(context) {
    var args = context.consumeArgs(2);
    return {
        tokens: args[0],
        numArgs: 0
    };
});
defineMacro("\\@secondoftwo", function(context) {
    var args = context.consumeArgs(2);
    return {
        tokens: args[1],
        numArgs: 0
    };
});
defineMacro("\\@ifnextchar", function(context) {
    var args = context.consumeArgs(3);
    context.consumeSpaces();
    var nextToken = context.future();
    if (args[0].length === 1 && args[0][0].text === nextToken.text) {
        return {
            tokens: args[1],
            numArgs: 0
        };
    } else {
        return {
            tokens: args[2],
            numArgs: 0
        };
    }
});
defineMacro("\\@ifstar", "\\@ifnextchar *{\\@firstoftwo{#1}}");
defineMacro("\\TextOrMath", function(context) {
    var args = context.consumeArgs(2);
    if (context.mode === 'text') {
        return {
            tokens: args[0],
            numArgs: 0
        };
    } else {
        return {
            tokens: args[1],
            numArgs: 0
        };
    }
});
var digitToNumber = {
    "0": 0,
    "1": 1,
    "2": 2,
    "3": 3,
    "4": 4,
    "5": 5,
    "6": 6,
    "7": 7,
    "8": 8,
    "9": 9,
    "a": 10,
    "A": 10,
    "b": 11,
    "B": 11,
    "c": 12,
    "C": 12,
    "d": 13,
    "D": 13,
    "e": 14,
    "E": 14,
    "f": 15,
    "F": 15
};
defineMacro("\\char", function(context) {
    var token = context.popToken();
    var base;
    var number = '';
    if (token.text === "'") {
        base = 8;
        token = context.popToken();
    } else if (token.text === '"') {
        base = 16;
        token = context.popToken();
    } else if (token.text === "`") {
        token = context.popToken();
        if (token.text[0] === "\\") {
            number = token.text.charCodeAt(1);
        } else if (token.text === "EOF") {
            throw new ParseError("\\char` missing argument");
        } else {
            number = token.text.charCodeAt(0);
        }
    } else {
        base = 10;
    }
    if (base) {
        number = digitToNumber[token.text];
        if (number == null || number >= base) {
            throw new ParseError("Invalid base-" + base + " digit " + token.text);
        }
        var digit;
        while((digit = digitToNumber[context.future().text]) != null && digit < base){
            number *= base;
            number += digit;
            context.popToken();
        }
    }
    return "\\@char{" + number + "}";
});
var newcommand = (context, existsOK, nonexistsOK)=>{
    var arg = context.consumeArg().tokens;
    if (arg.length !== 1) {
        throw new ParseError("\\newcommand's first argument must be a macro name");
    }
    var name = arg[0].text;
    var exists = context.isDefined(name);
    if (exists && !existsOK) {
        throw new ParseError("\\newcommand{" + name + "} attempting to redefine " + (name + "; use \\renewcommand"));
    }
    if (!exists && !nonexistsOK) {
        throw new ParseError("\\renewcommand{" + name + "} when command " + name + " " + "does not yet exist; use \\newcommand");
    }
    var numArgs = 0;
    arg = context.consumeArg().tokens;
    if (arg.length === 1 && arg[0].text === "[") {
        var argText = '';
        var token = context.expandNextToken();
        while(token.text !== "]" && token.text !== "EOF"){
            argText += token.text;
            token = context.expandNextToken();
        }
        if (!argText.match(/^\s*[0-9]+\s*$/)) {
            throw new ParseError("Invalid number of arguments: " + argText);
        }
        numArgs = parseInt(argText);
        arg = context.consumeArg().tokens;
    }
    context.macros.set(name, {
        tokens: arg,
        numArgs
    });
    return '';
};
defineMacro("\\newcommand", (context)=>newcommand(context, false, true));
defineMacro("\\renewcommand", (context)=>newcommand(context, true, false));
defineMacro("\\providecommand", (context)=>newcommand(context, true, true));
defineMacro("\\message", (context)=>{
    var arg = context.consumeArgs(1)[0];
    console.log(arg.reverse().map((token)=>token.text).join(""));
    return '';
});
defineMacro("\\errmessage", (context)=>{
    var arg = context.consumeArgs(1)[0];
    console.error(arg.reverse().map((token)=>token.text).join(""));
    return '';
});
defineMacro("\\show", (context)=>{
    var tok = context.popToken();
    var name = tok.text;
    console.log(tok, context.macros.get(name), functions[name], symbols.math[name], symbols.text[name]);
    return '';
});
defineMacro("\\bgroup", "{");
defineMacro("\\egroup", "}");
defineMacro("~", "\\nobreakspace");
defineMacro("\\lq", "`");
defineMacro("\\rq", "'");
defineMacro("\\aa", "\\r a");
defineMacro("\\AA", "\\r A");
defineMacro("\\textcopyright", "\\html@mathml{\\textcircled{c}}{\\char`©}");
defineMacro("\\copyright", "\\TextOrMath{\\textcopyright}{\\text{\\textcopyright}}");
defineMacro("\\textregistered", "\\html@mathml{\\textcircled{\\scriptsize R}}{\\char`®}");
defineMacro("\u212C", "\\mathscr{B}");
defineMacro("\u2130", "\\mathscr{E}");
defineMacro("\u2131", "\\mathscr{F}");
defineMacro("\u210B", "\\mathscr{H}");
defineMacro("\u2110", "\\mathscr{I}");
defineMacro("\u2112", "\\mathscr{L}");
defineMacro("\u2133", "\\mathscr{M}");
defineMacro("\u211B", "\\mathscr{R}");
defineMacro("\u212D", "\\mathfrak{C}");
defineMacro("\u210C", "\\mathfrak{H}");
defineMacro("\u2128", "\\mathfrak{Z}");
defineMacro("\\Bbbk", "\\Bbb{k}");
defineMacro("\u00b7", "\\cdotp");
defineMacro("\\llap", "\\mathllap{\\textrm{#1}}");
defineMacro("\\rlap", "\\mathrlap{\\textrm{#1}}");
defineMacro("\\clap", "\\mathclap{\\textrm{#1}}");
defineMacro("\\mathstrut", "\\vphantom{(}");
defineMacro("\\underbar", "\\underline{\\text{#1}}");
defineMacro("\\not", '\\html@mathml{\\mathrel{\\mathrlap\\@not}}{\\char"338}');
defineMacro("\\neq", "\\html@mathml{\\mathrel{\\not=}}{\\mathrel{\\char`≠}}");
defineMacro("\\ne", "\\neq");
defineMacro("\u2260", "\\neq");
defineMacro("\\notin", "\\html@mathml{\\mathrel{{\\in}\\mathllap{/\\mskip1mu}}}" + "{\\mathrel{\\char`∉}}");
defineMacro("\u2209", "\\notin");
defineMacro("\u2258", "\\html@mathml{" + "\\mathrel{=\\kern{-1em}\\raisebox{0.4em}{$\\scriptsize\\frown$}}" + "}{\\mathrel{\\char`\u2258}}");
defineMacro("\u2259", "\\html@mathml{\\stackrel{\\tiny\\wedge}{=}}{\\mathrel{\\char`\u2258}}");
defineMacro("\u225A", "\\html@mathml{\\stackrel{\\tiny\\vee}{=}}{\\mathrel{\\char`\u225A}}");
defineMacro("\u225B", "\\html@mathml{\\stackrel{\\scriptsize\\star}{=}}" + "{\\mathrel{\\char`\u225B}}");
defineMacro("\u225D", "\\html@mathml{\\stackrel{\\tiny\\mathrm{def}}{=}}" + "{\\mathrel{\\char`\u225D}}");
defineMacro("\u225E", "\\html@mathml{\\stackrel{\\tiny\\mathrm{m}}{=}}" + "{\\mathrel{\\char`\u225E}}");
defineMacro("\u225F", "\\html@mathml{\\stackrel{\\tiny?}{=}}{\\mathrel{\\char`\u225F}}");
defineMacro("\u27C2", "\\perp");
defineMacro("\u203C", "\\mathclose{!\\mkern-0.8mu!}");
defineMacro("\u220C", "\\notni");
defineMacro("\u231C", "\\ulcorner");
defineMacro("\u231D", "\\urcorner");
defineMacro("\u231E", "\\llcorner");
defineMacro("\u231F", "\\lrcorner");
defineMacro("\u00A9", "\\copyright");
defineMacro("\u00AE", "\\textregistered");
defineMacro("\uFE0F", "\\textregistered");
defineMacro("\\ulcorner", "\\html@mathml{\\@ulcorner}{\\mathop{\\char\"231c}}");
defineMacro("\\urcorner", "\\html@mathml{\\@urcorner}{\\mathop{\\char\"231d}}");
defineMacro("\\llcorner", "\\html@mathml{\\@llcorner}{\\mathop{\\char\"231e}}");
defineMacro("\\lrcorner", "\\html@mathml{\\@lrcorner}{\\mathop{\\char\"231f}}");
defineMacro("\\vdots", "\\mathord{\\varvdots\\rule{0pt}{15pt}}");
defineMacro("\u22ee", "\\vdots");
defineMacro("\\varGamma", "\\mathit{\\Gamma}");
defineMacro("\\varDelta", "\\mathit{\\Delta}");
defineMacro("\\varTheta", "\\mathit{\\Theta}");
defineMacro("\\varLambda", "\\mathit{\\Lambda}");
defineMacro("\\varXi", "\\mathit{\\Xi}");
defineMacro("\\varPi", "\\mathit{\\Pi}");
defineMacro("\\varSigma", "\\mathit{\\Sigma}");
defineMacro("\\varUpsilon", "\\mathit{\\Upsilon}");
defineMacro("\\varPhi", "\\mathit{\\Phi}");
defineMacro("\\varPsi", "\\mathit{\\Psi}");
defineMacro("\\varOmega", "\\mathit{\\Omega}");
defineMacro("\\substack", "\\begin{subarray}{c}#1\\end{subarray}");
defineMacro("\\colon", "\\nobreak\\mskip2mu\\mathpunct{}" + "\\mathchoice{\\mkern-3mu}{\\mkern-3mu}{}{}{:}\\mskip6mu\\relax");
defineMacro("\\boxed", "\\fbox{$\\displaystyle{#1}$}");
defineMacro("\\iff", "\\DOTSB\\;\\Longleftrightarrow\\;");
defineMacro("\\implies", "\\DOTSB\\;\\Longrightarrow\\;");
defineMacro("\\impliedby", "\\DOTSB\\;\\Longleftarrow\\;");
var dotsByToken = {
    ',': '\\dotsc',
    '\\not': '\\dotsb',
    '+': '\\dotsb',
    '=': '\\dotsb',
    '<': '\\dotsb',
    '>': '\\dotsb',
    '-': '\\dotsb',
    '*': '\\dotsb',
    ':': '\\dotsb',
    '\\DOTSB': '\\dotsb',
    '\\coprod': '\\dotsb',
    '\\bigvee': '\\dotsb',
    '\\bigwedge': '\\dotsb',
    '\\biguplus': '\\dotsb',
    '\\bigcap': '\\dotsb',
    '\\bigcup': '\\dotsb',
    '\\prod': '\\dotsb',
    '\\sum': '\\dotsb',
    '\\bigotimes': '\\dotsb',
    '\\bigoplus': '\\dotsb',
    '\\bigodot': '\\dotsb',
    '\\bigsqcup': '\\dotsb',
    '\\And': '\\dotsb',
    '\\longrightarrow': '\\dotsb',
    '\\Longrightarrow': '\\dotsb',
    '\\longleftarrow': '\\dotsb',
    '\\Longleftarrow': '\\dotsb',
    '\\longleftrightarrow': '\\dotsb',
    '\\Longleftrightarrow': '\\dotsb',
    '\\mapsto': '\\dotsb',
    '\\longmapsto': '\\dotsb',
    '\\hookrightarrow': '\\dotsb',
    '\\doteq': '\\dotsb',
    '\\mathbin': '\\dotsb',
    '\\mathrel': '\\dotsb',
    '\\relbar': '\\dotsb',
    '\\Relbar': '\\dotsb',
    '\\xrightarrow': '\\dotsb',
    '\\xleftarrow': '\\dotsb',
    '\\DOTSI': '\\dotsi',
    '\\int': '\\dotsi',
    '\\oint': '\\dotsi',
    '\\iint': '\\dotsi',
    '\\iiint': '\\dotsi',
    '\\iiiint': '\\dotsi',
    '\\idotsint': '\\dotsi',
    '\\DOTSX': '\\dotsx'
};
defineMacro("\\dots", function(context) {
    var thedots = '\\dotso';
    var next = context.expandAfterFuture().text;
    if (next in dotsByToken) {
        thedots = dotsByToken[next];
    } else if (next.slice(0, 4) === '\\not') {
        thedots = '\\dotsb';
    } else if (next in symbols.math) {
        if (utils.contains([
            'bin',
            'rel'
        ], symbols.math[next].group)) {
            thedots = '\\dotsb';
        }
    }
    return thedots;
});
var spaceAfterDots = {
    ')': true,
    ']': true,
    '\\rbrack': true,
    '\\}': true,
    '\\rbrace': true,
    '\\rangle': true,
    '\\rceil': true,
    '\\rfloor': true,
    '\\rgroup': true,
    '\\rmoustache': true,
    '\\right': true,
    '\\bigr': true,
    '\\biggr': true,
    '\\Bigr': true,
    '\\Biggr': true,
    '$': true,
    ';': true,
    '.': true,
    ',': true
};
defineMacro("\\dotso", function(context) {
    var next = context.future().text;
    if (next in spaceAfterDots) {
        return "\\ldots\\,";
    } else {
        return "\\ldots";
    }
});
defineMacro("\\dotsc", function(context) {
    var next = context.future().text;
    if (next in spaceAfterDots && next !== ',') {
        return "\\ldots\\,";
    } else {
        return "\\ldots";
    }
});
defineMacro("\\cdots", function(context) {
    var next = context.future().text;
    if (next in spaceAfterDots) {
        return "\\@cdots\\,";
    } else {
        return "\\@cdots";
    }
});
defineMacro("\\dotsb", "\\cdots");
defineMacro("\\dotsm", "\\cdots");
defineMacro("\\dotsi", "\\!\\cdots");
defineMacro("\\dotsx", "\\ldots\\,");
defineMacro("\\DOTSI", "\\relax");
defineMacro("\\DOTSB", "\\relax");
defineMacro("\\DOTSX", "\\relax");
defineMacro("\\tmspace", "\\TextOrMath{\\kern#1#3}{\\mskip#1#2}\\relax");
defineMacro("\\,", "\\tmspace+{3mu}{.1667em}");
defineMacro("\\thinspace", "\\,");
defineMacro("\\>", "\\mskip{4mu}");
defineMacro("\\:", "\\tmspace+{4mu}{.2222em}");
defineMacro("\\medspace", "\\:");
defineMacro("\\;", "\\tmspace+{5mu}{.2777em}");
defineMacro("\\thickspace", "\\;");
defineMacro("\\!", "\\tmspace-{3mu}{.1667em}");
defineMacro("\\negthinspace", "\\!");
defineMacro("\\negmedspace", "\\tmspace-{4mu}{.2222em}");
defineMacro("\\negthickspace", "\\tmspace-{5mu}{.277em}");
defineMacro("\\enspace", "\\kern.5em ");
defineMacro("\\enskip", "\\hskip.5em\\relax");
defineMacro("\\quad", "\\hskip1em\\relax");
defineMacro("\\qquad", "\\hskip2em\\relax");
defineMacro("\\tag", "\\@ifstar\\tag@literal\\tag@paren");
defineMacro("\\tag@paren", "\\tag@literal{({#1})}");
defineMacro("\\tag@literal", (context)=>{
    if (context.macros.get("\\df@tag")) {
        throw new ParseError("Multiple \\tag");
    }
    return "\\gdef\\df@tag{\\text{#1}}";
});
defineMacro("\\bmod", "\\mathchoice{\\mskip1mu}{\\mskip1mu}{\\mskip5mu}{\\mskip5mu}" + "\\mathbin{\\rm mod}" + "\\mathchoice{\\mskip1mu}{\\mskip1mu}{\\mskip5mu}{\\mskip5mu}");
defineMacro("\\pod", "\\allowbreak" + "\\mathchoice{\\mkern18mu}{\\mkern8mu}{\\mkern8mu}{\\mkern8mu}(#1)");
defineMacro("\\pmod", "\\pod{{\\rm mod}\\mkern6mu#1}");
defineMacro("\\mod", "\\allowbreak" + "\\mathchoice{\\mkern18mu}{\\mkern12mu}{\\mkern12mu}{\\mkern12mu}" + "{\\rm mod}\\,\\,#1");
defineMacro("\\newline", "\\\\\\relax");
defineMacro("\\TeX", "\\textrm{\\html@mathml{" + "T\\kern-.1667em\\raisebox{-.5ex}{E}\\kern-.125emX" + "}{TeX}}");
var latexRaiseA = makeEm(fontMetricsData['Main-Regular']["T".charCodeAt(0)][1] - 0.7 * fontMetricsData['Main-Regular']["A".charCodeAt(0)][1]);
defineMacro("\\LaTeX", "\\textrm{\\html@mathml{" + ("L\\kern-.36em\\raisebox{" + latexRaiseA + "}{\\scriptstyle A}") + "\\kern-.15em\\TeX}{LaTeX}}");
defineMacro("\\KaTeX", "\\textrm{\\html@mathml{" + ("K\\kern-.17em\\raisebox{" + latexRaiseA + "}{\\scriptstyle A}") + "\\kern-.15em\\TeX}{KaTeX}}");
defineMacro("\\hspace", "\\@ifstar\\@hspacer\\@hspace");
defineMacro("\\@hspace", "\\hskip #1\\relax");
defineMacro("\\@hspacer", "\\rule{0pt}{0pt}\\hskip #1\\relax");
defineMacro("\\ordinarycolon", ":");
defineMacro("\\vcentcolon", "\\mathrel{\\mathop\\ordinarycolon}");
defineMacro("\\dblcolon", "\\html@mathml{" + "\\mathrel{\\vcentcolon\\mathrel{\\mkern-.9mu}\\vcentcolon}}" + "{\\mathop{\\char\"2237}}");
defineMacro("\\coloneqq", "\\html@mathml{" + "\\mathrel{\\vcentcolon\\mathrel{\\mkern-1.2mu}=}}" + "{\\mathop{\\char\"2254}}");
defineMacro("\\Coloneqq", "\\html@mathml{" + "\\mathrel{\\dblcolon\\mathrel{\\mkern-1.2mu}=}}" + "{\\mathop{\\char\"2237\\char\"3d}}");
defineMacro("\\coloneq", "\\html@mathml{" + "\\mathrel{\\vcentcolon\\mathrel{\\mkern-1.2mu}\\mathrel{-}}}" + "{\\mathop{\\char\"3a\\char\"2212}}");
defineMacro("\\Coloneq", "\\html@mathml{" + "\\mathrel{\\dblcolon\\mathrel{\\mkern-1.2mu}\\mathrel{-}}}" + "{\\mathop{\\char\"2237\\char\"2212}}");
defineMacro("\\eqqcolon", "\\html@mathml{" + "\\mathrel{=\\mathrel{\\mkern-1.2mu}\\vcentcolon}}" + "{\\mathop{\\char\"2255}}");
defineMacro("\\Eqqcolon", "\\html@mathml{" + "\\mathrel{=\\mathrel{\\mkern-1.2mu}\\dblcolon}}" + "{\\mathop{\\char\"3d\\char\"2237}}");
defineMacro("\\eqcolon", "\\html@mathml{" + "\\mathrel{\\mathrel{-}\\mathrel{\\mkern-1.2mu}\\vcentcolon}}" + "{\\mathop{\\char\"2239}}");
defineMacro("\\Eqcolon", "\\html@mathml{" + "\\mathrel{\\mathrel{-}\\mathrel{\\mkern-1.2mu}\\dblcolon}}" + "{\\mathop{\\char\"2212\\char\"2237}}");
defineMacro("\\colonapprox", "\\html@mathml{" + "\\mathrel{\\vcentcolon\\mathrel{\\mkern-1.2mu}\\approx}}" + "{\\mathop{\\char\"3a\\char\"2248}}");
defineMacro("\\Colonapprox", "\\html@mathml{" + "\\mathrel{\\dblcolon\\mathrel{\\mkern-1.2mu}\\approx}}" + "{\\mathop{\\char\"2237\\char\"2248}}");
defineMacro("\\colonsim", "\\html@mathml{" + "\\mathrel{\\vcentcolon\\mathrel{\\mkern-1.2mu}\\sim}}" + "{\\mathop{\\char\"3a\\char\"223c}}");
defineMacro("\\Colonsim", "\\html@mathml{" + "\\mathrel{\\dblcolon\\mathrel{\\mkern-1.2mu}\\sim}}" + "{\\mathop{\\char\"2237\\char\"223c}}");
defineMacro("\u2237", "\\dblcolon");
defineMacro("\u2239", "\\eqcolon");
defineMacro("\u2254", "\\coloneqq");
defineMacro("\u2255", "\\eqqcolon");
defineMacro("\u2A74", "\\Coloneqq");
defineMacro("\\ratio", "\\vcentcolon");
defineMacro("\\coloncolon", "\\dblcolon");
defineMacro("\\colonequals", "\\coloneqq");
defineMacro("\\coloncolonequals", "\\Coloneqq");
defineMacro("\\equalscolon", "\\eqqcolon");
defineMacro("\\equalscoloncolon", "\\Eqqcolon");
defineMacro("\\colonminus", "\\coloneq");
defineMacro("\\coloncolonminus", "\\Coloneq");
defineMacro("\\minuscolon", "\\eqcolon");
defineMacro("\\minuscoloncolon", "\\Eqcolon");
defineMacro("\\coloncolonapprox", "\\Colonapprox");
defineMacro("\\coloncolonsim", "\\Colonsim");
defineMacro("\\simcolon", "\\mathrel{\\sim\\mathrel{\\mkern-1.2mu}\\vcentcolon}");
defineMacro("\\simcoloncolon", "\\mathrel{\\sim\\mathrel{\\mkern-1.2mu}\\dblcolon}");
defineMacro("\\approxcolon", "\\mathrel{\\approx\\mathrel{\\mkern-1.2mu}\\vcentcolon}");
defineMacro("\\approxcoloncolon", "\\mathrel{\\approx\\mathrel{\\mkern-1.2mu}\\dblcolon}");
defineMacro("\\notni", "\\html@mathml{\\not\\ni}{\\mathrel{\\char`\u220C}}");
defineMacro("\\limsup", "\\DOTSB\\operatorname*{lim\\,sup}");
defineMacro("\\liminf", "\\DOTSB\\operatorname*{lim\\,inf}");
defineMacro("\\injlim", "\\DOTSB\\operatorname*{inj\\,lim}");
defineMacro("\\projlim", "\\DOTSB\\operatorname*{proj\\,lim}");
defineMacro("\\varlimsup", "\\DOTSB\\operatorname*{\\overline{lim}}");
defineMacro("\\varliminf", "\\DOTSB\\operatorname*{\\underline{lim}}");
defineMacro("\\varinjlim", "\\DOTSB\\operatorname*{\\underrightarrow{lim}}");
defineMacro("\\varprojlim", "\\DOTSB\\operatorname*{\\underleftarrow{lim}}");
defineMacro("\\gvertneqq", "\\html@mathml{\\@gvertneqq}{\u2269}");
defineMacro("\\lvertneqq", "\\html@mathml{\\@lvertneqq}{\u2268}");
defineMacro("\\ngeqq", "\\html@mathml{\\@ngeqq}{\u2271}");
defineMacro("\\ngeqslant", "\\html@mathml{\\@ngeqslant}{\u2271}");
defineMacro("\\nleqq", "\\html@mathml{\\@nleqq}{\u2270}");
defineMacro("\\nleqslant", "\\html@mathml{\\@nleqslant}{\u2270}");
defineMacro("\\nshortmid", "\\html@mathml{\\@nshortmid}{∤}");
defineMacro("\\nshortparallel", "\\html@mathml{\\@nshortparallel}{∦}");
defineMacro("\\nsubseteqq", "\\html@mathml{\\@nsubseteqq}{\u2288}");
defineMacro("\\nsupseteqq", "\\html@mathml{\\@nsupseteqq}{\u2289}");
defineMacro("\\varsubsetneq", "\\html@mathml{\\@varsubsetneq}{⊊}");
defineMacro("\\varsubsetneqq", "\\html@mathml{\\@varsubsetneqq}{⫋}");
defineMacro("\\varsupsetneq", "\\html@mathml{\\@varsupsetneq}{⊋}");
defineMacro("\\varsupsetneqq", "\\html@mathml{\\@varsupsetneqq}{⫌}");
defineMacro("\\imath", "\\html@mathml{\\@imath}{\u0131}");
defineMacro("\\jmath", "\\html@mathml{\\@jmath}{\u0237}");
defineMacro("\\llbracket", "\\html@mathml{" + "\\mathopen{[\\mkern-3.2mu[}}" + "{\\mathopen{\\char`\u27e6}}");
defineMacro("\\rrbracket", "\\html@mathml{" + "\\mathclose{]\\mkern-3.2mu]}}" + "{\\mathclose{\\char`\u27e7}}");
defineMacro("\u27e6", "\\llbracket");
defineMacro("\u27e7", "\\rrbracket");
defineMacro("\\lBrace", "\\html@mathml{" + "\\mathopen{\\{\\mkern-3.2mu[}}" + "{\\mathopen{\\char`\u2983}}");
defineMacro("\\rBrace", "\\html@mathml{" + "\\mathclose{]\\mkern-3.2mu\\}}}" + "{\\mathclose{\\char`\u2984}}");
defineMacro("\u2983", "\\lBrace");
defineMacro("\u2984", "\\rBrace");
defineMacro("\\minuso", "\\mathbin{\\html@mathml{" + "{\\mathrlap{\\mathchoice{\\kern{0.145em}}{\\kern{0.145em}}" + "{\\kern{0.1015em}}{\\kern{0.0725em}}\\circ}{-}}}" + "{\\char`⦵}}");
defineMacro("⦵", "\\minuso");
defineMacro("\\darr", "\\downarrow");
defineMacro("\\dArr", "\\Downarrow");
defineMacro("\\Darr", "\\Downarrow");
defineMacro("\\lang", "\\langle");
defineMacro("\\rang", "\\rangle");
defineMacro("\\uarr", "\\uparrow");
defineMacro("\\uArr", "\\Uparrow");
defineMacro("\\Uarr", "\\Uparrow");
defineMacro("\\N", "\\mathbb{N}");
defineMacro("\\R", "\\mathbb{R}");
defineMacro("\\Z", "\\mathbb{Z}");
defineMacro("\\alef", "\\aleph");
defineMacro("\\alefsym", "\\aleph");
defineMacro("\\Alpha", "\\mathrm{A}");
defineMacro("\\Beta", "\\mathrm{B}");
defineMacro("\\bull", "\\bullet");
defineMacro("\\Chi", "\\mathrm{X}");
defineMacro("\\clubs", "\\clubsuit");
defineMacro("\\cnums", "\\mathbb{C}");
defineMacro("\\Complex", "\\mathbb{C}");
defineMacro("\\Dagger", "\\ddagger");
defineMacro("\\diamonds", "\\diamondsuit");
defineMacro("\\empty", "\\emptyset");
defineMacro("\\Epsilon", "\\mathrm{E}");
defineMacro("\\Eta", "\\mathrm{H}");
defineMacro("\\exist", "\\exists");
defineMacro("\\harr", "\\leftrightarrow");
defineMacro("\\hArr", "\\Leftrightarrow");
defineMacro("\\Harr", "\\Leftrightarrow");
defineMacro("\\hearts", "\\heartsuit");
defineMacro("\\image", "\\Im");
defineMacro("\\infin", "\\infty");
defineMacro("\\Iota", "\\mathrm{I}");
defineMacro("\\isin", "\\in");
defineMacro("\\Kappa", "\\mathrm{K}");
defineMacro("\\larr", "\\leftarrow");
defineMacro("\\lArr", "\\Leftarrow");
defineMacro("\\Larr", "\\Leftarrow");
defineMacro("\\lrarr", "\\leftrightarrow");
defineMacro("\\lrArr", "\\Leftrightarrow");
defineMacro("\\Lrarr", "\\Leftrightarrow");
defineMacro("\\Mu", "\\mathrm{M}");
defineMacro("\\natnums", "\\mathbb{N}");
defineMacro("\\Nu", "\\mathrm{N}");
defineMacro("\\Omicron", "\\mathrm{O}");
defineMacro("\\plusmn", "\\pm");
defineMacro("\\rarr", "\\rightarrow");
defineMacro("\\rArr", "\\Rightarrow");
defineMacro("\\Rarr", "\\Rightarrow");
defineMacro("\\real", "\\Re");
defineMacro("\\reals", "\\mathbb{R}");
defineMacro("\\Reals", "\\mathbb{R}");
defineMacro("\\Rho", "\\mathrm{P}");
defineMacro("\\sdot", "\\cdot");
defineMacro("\\sect", "\\S");
defineMacro("\\spades", "\\spadesuit");
defineMacro("\\sub", "\\subset");
defineMacro("\\sube", "\\subseteq");
defineMacro("\\supe", "\\supseteq");
defineMacro("\\Tau", "\\mathrm{T}");
defineMacro("\\thetasym", "\\vartheta");
defineMacro("\\weierp", "\\wp");
defineMacro("\\Zeta", "\\mathrm{Z}");
defineMacro("\\argmin", "\\DOTSB\\operatorname*{arg\\,min}");
defineMacro("\\argmax", "\\DOTSB\\operatorname*{arg\\,max}");
defineMacro("\\plim", "\\DOTSB\\mathop{\\operatorname{plim}}\\limits");
defineMacro("\\bra", "\\mathinner{\\langle{#1}|}");
defineMacro("\\ket", "\\mathinner{|{#1}\\rangle}");
defineMacro("\\braket", "\\mathinner{\\langle{#1}\\rangle}");
defineMacro("\\Bra", "\\left\\langle#1\\right|");
defineMacro("\\Ket", "\\left|#1\\right\\rangle");
var braketHelper = (one)=>(context)=>{
        var left = context.consumeArg().tokens;
        var middle = context.consumeArg().tokens;
        var middleDouble = context.consumeArg().tokens;
        var right = context.consumeArg().tokens;
        var oldMiddle = context.macros.get("|");
        var oldMiddleDouble = context.macros.get("\\|");
        context.macros.beginGroup();
        var midMacro = (__double)=>(context)=>{
                if (one) {
                    context.macros.set("|", oldMiddle);
                    if (middleDouble.length) {
                        context.macros.set("\\|", oldMiddleDouble);
                    }
                }
                var doubled = __double;
                if (!__double && middleDouble.length) {
                    var nextToken = context.future();
                    if (nextToken.text === "|") {
                        context.popToken();
                        doubled = true;
                    }
                }
                return {
                    tokens: doubled ? middleDouble : middle,
                    numArgs: 0
                };
            };
        context.macros.set("|", midMacro(false));
        if (middleDouble.length) {
            context.macros.set("\\|", midMacro(true));
        }
        var arg = context.consumeArg().tokens;
        var expanded = context.expandTokens([
            ...right,
            ...arg,
            ...left
        ]);
        context.macros.endGroup();
        return {
            tokens: expanded.reverse(),
            numArgs: 0
        };
    };
defineMacro("\\bra@ket", braketHelper(false));
defineMacro("\\bra@set", braketHelper(true));
defineMacro("\\Braket", "\\bra@ket{\\left\\langle}" + "{\\,\\middle\\vert\\,}{\\,\\middle\\vert\\,}{\\right\\rangle}");
defineMacro("\\Set", "\\bra@set{\\left\\{\\:}" + "{\\;\\middle\\vert\\;}{\\;\\middle\\Vert\\;}{\\:\\right\\}}");
defineMacro("\\set", "\\bra@set{\\{\\,}{\\mid}{}{\\,\\}}");
defineMacro("\\angln", "{\\angl n}");
defineMacro("\\blue", "\\textcolor{##6495ed}{#1}");
defineMacro("\\orange", "\\textcolor{##ffa500}{#1}");
defineMacro("\\pink", "\\textcolor{##ff00af}{#1}");
defineMacro("\\red", "\\textcolor{##df0030}{#1}");
defineMacro("\\green", "\\textcolor{##28ae7b}{#1}");
defineMacro("\\gray", "\\textcolor{gray}{#1}");
defineMacro("\\purple", "\\textcolor{##9d38bd}{#1}");
defineMacro("\\blueA", "\\textcolor{##ccfaff}{#1}");
defineMacro("\\blueB", "\\textcolor{##80f6ff}{#1}");
defineMacro("\\blueC", "\\textcolor{##63d9ea}{#1}");
defineMacro("\\blueD", "\\textcolor{##11accd}{#1}");
defineMacro("\\blueE", "\\textcolor{##0c7f99}{#1}");
defineMacro("\\tealA", "\\textcolor{##94fff5}{#1}");
defineMacro("\\tealB", "\\textcolor{##26edd5}{#1}");
defineMacro("\\tealC", "\\textcolor{##01d1c1}{#1}");
defineMacro("\\tealD", "\\textcolor{##01a995}{#1}");
defineMacro("\\tealE", "\\textcolor{##208170}{#1}");
defineMacro("\\greenA", "\\textcolor{##b6ffb0}{#1}");
defineMacro("\\greenB", "\\textcolor{##8af281}{#1}");
defineMacro("\\greenC", "\\textcolor{##74cf70}{#1}");
defineMacro("\\greenD", "\\textcolor{##1fab54}{#1}");
defineMacro("\\greenE", "\\textcolor{##0d923f}{#1}");
defineMacro("\\goldA", "\\textcolor{##ffd0a9}{#1}");
defineMacro("\\goldB", "\\textcolor{##ffbb71}{#1}");
defineMacro("\\goldC", "\\textcolor{##ff9c39}{#1}");
defineMacro("\\goldD", "\\textcolor{##e07d10}{#1}");
defineMacro("\\goldE", "\\textcolor{##a75a05}{#1}");
defineMacro("\\redA", "\\textcolor{##fca9a9}{#1}");
defineMacro("\\redB", "\\textcolor{##ff8482}{#1}");
defineMacro("\\redC", "\\textcolor{##f9685d}{#1}");
defineMacro("\\redD", "\\textcolor{##e84d39}{#1}");
defineMacro("\\redE", "\\textcolor{##bc2612}{#1}");
defineMacro("\\maroonA", "\\textcolor{##ffbde0}{#1}");
defineMacro("\\maroonB", "\\textcolor{##ff92c6}{#1}");
defineMacro("\\maroonC", "\\textcolor{##ed5fa6}{#1}");
defineMacro("\\maroonD", "\\textcolor{##ca337c}{#1}");
defineMacro("\\maroonE", "\\textcolor{##9e034e}{#1}");
defineMacro("\\purpleA", "\\textcolor{##ddd7ff}{#1}");
defineMacro("\\purpleB", "\\textcolor{##c6b9fc}{#1}");
defineMacro("\\purpleC", "\\textcolor{##aa87ff}{#1}");
defineMacro("\\purpleD", "\\textcolor{##7854ab}{#1}");
defineMacro("\\purpleE", "\\textcolor{##543b78}{#1}");
defineMacro("\\mintA", "\\textcolor{##f5f9e8}{#1}");
defineMacro("\\mintB", "\\textcolor{##edf2df}{#1}");
defineMacro("\\mintC", "\\textcolor{##e0e5cc}{#1}");
defineMacro("\\grayA", "\\textcolor{##f6f7f7}{#1}");
defineMacro("\\grayB", "\\textcolor{##f0f1f2}{#1}");
defineMacro("\\grayC", "\\textcolor{##e3e5e6}{#1}");
defineMacro("\\grayD", "\\textcolor{##d6d8da}{#1}");
defineMacro("\\grayE", "\\textcolor{##babec2}{#1}");
defineMacro("\\grayF", "\\textcolor{##888d93}{#1}");
defineMacro("\\grayG", "\\textcolor{##626569}{#1}");
defineMacro("\\grayH", "\\textcolor{##3b3e40}{#1}");
defineMacro("\\grayI", "\\textcolor{##21242c}{#1}");
defineMacro("\\kaBlue", "\\textcolor{##314453}{#1}");
defineMacro("\\kaGreen", "\\textcolor{##71B307}{#1}");
var implicitCommands = {
    "^": true,
    "_": true,
    "\\limits": true,
    "\\nolimits": true
};
class MacroExpander {
    constructor(input, settings, mode){
        this.settings = void 0;
        this.expansionCount = void 0;
        this.lexer = void 0;
        this.macros = void 0;
        this.stack = void 0;
        this.mode = void 0;
        this.settings = settings;
        this.expansionCount = 0;
        this.feed(input);
        this.macros = new Namespace(macros, settings.macros);
        this.mode = mode;
        this.stack = [];
    }
    feed(input) {
        this.lexer = new Lexer(input, this.settings);
    }
    switchMode(newMode) {
        this.mode = newMode;
    }
    beginGroup() {
        this.macros.beginGroup();
    }
    endGroup() {
        this.macros.endGroup();
    }
    endGroups() {
        this.macros.endGroups();
    }
    future() {
        if (this.stack.length === 0) {
            this.pushToken(this.lexer.lex());
        }
        return this.stack[this.stack.length - 1];
    }
    popToken() {
        this.future();
        return this.stack.pop();
    }
    pushToken(token) {
        this.stack.push(token);
    }
    pushTokens(tokens) {
        this.stack.push(...tokens);
    }
    scanArgument(isOptional) {
        var start;
        var end;
        var tokens;
        if (isOptional) {
            this.consumeSpaces();
            if (this.future().text !== "[") {
                return null;
            }
            start = this.popToken();
            ({ tokens , end  } = this.consumeArg([
                "]"
            ]));
        } else {
            ({ tokens , start , end  } = this.consumeArg());
        }
        this.pushToken(new Token("EOF", end.loc));
        this.pushTokens(tokens);
        return start.range(end, "");
    }
    consumeSpaces() {
        for(;;){
            var token = this.future();
            if (token.text === " ") {
                this.stack.pop();
            } else {
                break;
            }
        }
    }
    consumeArg(delims) {
        var tokens = [];
        var isDelimited = delims && delims.length > 0;
        if (!isDelimited) {
            this.consumeSpaces();
        }
        var start = this.future();
        var tok;
        var depth = 0;
        var match = 0;
        do {
            tok = this.popToken();
            tokens.push(tok);
            if (tok.text === "{") {
                ++depth;
            } else if (tok.text === "}") {
                --depth;
                if (depth === -1) {
                    throw new ParseError("Extra }", tok);
                }
            } else if (tok.text === "EOF") {
                throw new ParseError("Unexpected end of input in a macro argument" + ", expected '" + (delims && isDelimited ? delims[match] : "}") + "'", tok);
            }
            if (delims && isDelimited) {
                if ((depth === 0 || depth === 1 && delims[match] === "{") && tok.text === delims[match]) {
                    ++match;
                    if (match === delims.length) {
                        tokens.splice(-match, match);
                        break;
                    }
                } else {
                    match = 0;
                }
            }
        }while (depth !== 0 || isDelimited)
        if (start.text === "{" && tokens[tokens.length - 1].text === "}") {
            tokens.pop();
            tokens.shift();
        }
        tokens.reverse();
        return {
            tokens,
            start,
            end: tok
        };
    }
    consumeArgs(numArgs, delimiters) {
        if (delimiters) {
            if (delimiters.length !== numArgs + 1) {
                throw new ParseError("The length of delimiters doesn't match the number of args!");
            }
            var delims = delimiters[0];
            for(var i = 0; i < delims.length; i++){
                var tok = this.popToken();
                if (delims[i] !== tok.text) {
                    throw new ParseError("Use of the macro doesn't match its definition", tok);
                }
            }
        }
        var args = [];
        for(var _i = 0; _i < numArgs; _i++){
            args.push(this.consumeArg(delimiters && delimiters[_i + 1]).tokens);
        }
        return args;
    }
    expandOnce(expandableOnly) {
        var topToken = this.popToken();
        var name = topToken.text;
        var expansion = !topToken.noexpand ? this._getExpansion(name) : null;
        if (expansion == null || expandableOnly && expansion.unexpandable) {
            if (expandableOnly && expansion == null && name[0] === "\\" && !this.isDefined(name)) {
                throw new ParseError("Undefined control sequence: " + name);
            }
            this.pushToken(topToken);
            return false;
        }
        this.expansionCount++;
        if (this.expansionCount > this.settings.maxExpand) {
            throw new ParseError("Too many expansions: infinite loop or " + "need to increase maxExpand setting");
        }
        var tokens = expansion.tokens;
        var args = this.consumeArgs(expansion.numArgs, expansion.delimiters);
        if (expansion.numArgs) {
            tokens = tokens.slice();
            for(var i = tokens.length - 1; i >= 0; --i){
                var tok = tokens[i];
                if (tok.text === "#") {
                    if (i === 0) {
                        throw new ParseError("Incomplete placeholder at end of macro body", tok);
                    }
                    tok = tokens[--i];
                    if (tok.text === "#") {
                        tokens.splice(i + 1, 1);
                    } else if (/^[1-9]$/.test(tok.text)) {
                        tokens.splice(i, 2, ...args[+tok.text - 1]);
                    } else {
                        throw new ParseError("Not a valid argument number", tok);
                    }
                }
            }
        }
        this.pushTokens(tokens);
        return tokens.length;
    }
    expandAfterFuture() {
        this.expandOnce();
        return this.future();
    }
    expandNextToken() {
        for(;;){
            if (this.expandOnce() === false) {
                var token = this.stack.pop();
                if (token.treatAsRelax) {
                    token.text = "\\relax";
                }
                return token;
            }
        }
        throw new Error();
    }
    expandMacro(name) {
        return this.macros.has(name) ? this.expandTokens([
            new Token(name)
        ]) : undefined;
    }
    expandTokens(tokens) {
        var output = [];
        var oldStackLength = this.stack.length;
        this.pushTokens(tokens);
        while(this.stack.length > oldStackLength){
            if (this.expandOnce(true) === false) {
                var token = this.stack.pop();
                if (token.treatAsRelax) {
                    token.noexpand = false;
                    token.treatAsRelax = false;
                }
                output.push(token);
            }
        }
        return output;
    }
    expandMacroAsText(name) {
        var tokens = this.expandMacro(name);
        if (tokens) {
            return tokens.map((token)=>token.text).join("");
        } else {
            return tokens;
        }
    }
    _getExpansion(name) {
        var definition = this.macros.get(name);
        if (definition == null) {
            return definition;
        }
        if (name.length === 1) {
            var catcode = this.lexer.catcodes[name];
            if (catcode != null && catcode !== 13) {
                return;
            }
        }
        var expansion = typeof definition === "function" ? definition(this) : definition;
        if (typeof expansion === "string") {
            var numArgs = 0;
            if (expansion.indexOf("#") !== -1) {
                var stripped = expansion.replace(/##/g, "");
                while(stripped.indexOf("#" + (numArgs + 1)) !== -1){
                    ++numArgs;
                }
            }
            var bodyLexer = new Lexer(expansion, this.settings);
            var tokens = [];
            var tok = bodyLexer.lex();
            while(tok.text !== "EOF"){
                tokens.push(tok);
                tok = bodyLexer.lex();
            }
            tokens.reverse();
            var expanded = {
                tokens,
                numArgs
            };
            return expanded;
        }
        return expansion;
    }
    isDefined(name) {
        return this.macros.has(name) || functions.hasOwnProperty(name) || symbols.math.hasOwnProperty(name) || symbols.text.hasOwnProperty(name) || implicitCommands.hasOwnProperty(name);
    }
    isExpandable(name) {
        var macro = this.macros.get(name);
        return macro != null ? typeof macro === "string" || typeof macro === "function" || !macro.unexpandable : functions.hasOwnProperty(name) && !functions[name].primitive;
    }
}
var unicodeSubRegEx = /^[₊₋₌₍₎₀₁₂₃₄₅₆₇₈₉ₐₑₕᵢⱼₖₗₘₙₒₚᵣₛₜᵤᵥₓᵦᵧᵨᵩᵪ]/;
var uSubsAndSups = Object.freeze({
    '₊': '+',
    '₋': '-',
    '₌': '=',
    '₍': '(',
    '₎': ')',
    '₀': '0',
    '₁': '1',
    '₂': '2',
    '₃': '3',
    '₄': '4',
    '₅': '5',
    '₆': '6',
    '₇': '7',
    '₈': '8',
    '₉': '9',
    '\u2090': 'a',
    '\u2091': 'e',
    '\u2095': 'h',
    '\u1D62': 'i',
    '\u2C7C': 'j',
    '\u2096': 'k',
    '\u2097': 'l',
    '\u2098': 'm',
    '\u2099': 'n',
    '\u2092': 'o',
    '\u209A': 'p',
    '\u1D63': 'r',
    '\u209B': 's',
    '\u209C': 't',
    '\u1D64': 'u',
    '\u1D65': 'v',
    '\u2093': 'x',
    '\u1D66': 'β',
    '\u1D67': 'γ',
    '\u1D68': 'ρ',
    '\u1D69': '\u03d5',
    '\u1D6A': 'χ',
    '⁺': '+',
    '⁻': '-',
    '⁼': '=',
    '⁽': '(',
    '⁾': ')',
    '⁰': '0',
    '¹': '1',
    '²': '2',
    '³': '3',
    '⁴': '4',
    '⁵': '5',
    '⁶': '6',
    '⁷': '7',
    '⁸': '8',
    '⁹': '9',
    '\u1D2C': 'A',
    '\u1D2E': 'B',
    '\u1D30': 'D',
    '\u1D31': 'E',
    '\u1D33': 'G',
    '\u1D34': 'H',
    '\u1D35': 'I',
    '\u1D36': 'J',
    '\u1D37': 'K',
    '\u1D38': 'L',
    '\u1D39': 'M',
    '\u1D3A': 'N',
    '\u1D3C': 'O',
    '\u1D3E': 'P',
    '\u1D3F': 'R',
    '\u1D40': 'T',
    '\u1D41': 'U',
    '\u2C7D': 'V',
    '\u1D42': 'W',
    '\u1D43': 'a',
    '\u1D47': 'b',
    '\u1D9C': 'c',
    '\u1D48': 'd',
    '\u1D49': 'e',
    '\u1DA0': 'f',
    '\u1D4D': 'g',
    '\u02B0': 'h',
    '\u2071': 'i',
    '\u02B2': 'j',
    '\u1D4F': 'k',
    '\u02E1': 'l',
    '\u1D50': 'm',
    '\u207F': 'n',
    '\u1D52': 'o',
    '\u1D56': 'p',
    '\u02B3': 'r',
    '\u02E2': 's',
    '\u1D57': 't',
    '\u1D58': 'u',
    '\u1D5B': 'v',
    '\u02B7': 'w',
    '\u02E3': 'x',
    '\u02B8': 'y',
    '\u1DBB': 'z',
    '\u1D5D': 'β',
    '\u1D5E': 'γ',
    '\u1D5F': 'δ',
    '\u1D60': '\u03d5',
    '\u1D61': 'χ',
    '\u1DBF': 'θ'
});
var unicodeAccents = {
    "́": {
        "text": "\\'",
        "math": "\\acute"
    },
    "̀": {
        "text": "\\`",
        "math": "\\grave"
    },
    "̈": {
        "text": "\\\"",
        "math": "\\ddot"
    },
    "̃": {
        "text": "\\~",
        "math": "\\tilde"
    },
    "̄": {
        "text": "\\=",
        "math": "\\bar"
    },
    "̆": {
        "text": "\\u",
        "math": "\\breve"
    },
    "̌": {
        "text": "\\v",
        "math": "\\check"
    },
    "̂": {
        "text": "\\^",
        "math": "\\hat"
    },
    "̇": {
        "text": "\\.",
        "math": "\\dot"
    },
    "̊": {
        "text": "\\r",
        "math": "\\mathring"
    },
    "̋": {
        "text": "\\H"
    },
    "̧": {
        "text": "\\c"
    }
};
var unicodeSymbols = {
    "á": "á",
    "à": "à",
    "ä": "ä",
    "ǟ": "ǟ",
    "ã": "ã",
    "ā": "ā",
    "ă": "ă",
    "ắ": "ắ",
    "ằ": "ằ",
    "ẵ": "ẵ",
    "ǎ": "ǎ",
    "â": "â",
    "ấ": "ấ",
    "ầ": "ầ",
    "ẫ": "ẫ",
    "ȧ": "ȧ",
    "ǡ": "ǡ",
    "å": "å",
    "ǻ": "ǻ",
    "ḃ": "ḃ",
    "ć": "ć",
    "ḉ": "ḉ",
    "č": "č",
    "ĉ": "ĉ",
    "ċ": "ċ",
    "ç": "ç",
    "ď": "ď",
    "ḋ": "ḋ",
    "ḑ": "ḑ",
    "é": "é",
    "è": "è",
    "ë": "ë",
    "ẽ": "ẽ",
    "ē": "ē",
    "ḗ": "ḗ",
    "ḕ": "ḕ",
    "ĕ": "ĕ",
    "ḝ": "ḝ",
    "ě": "ě",
    "ê": "ê",
    "ế": "ế",
    "ề": "ề",
    "ễ": "ễ",
    "ė": "ė",
    "ȩ": "ȩ",
    "ḟ": "ḟ",
    "ǵ": "ǵ",
    "ḡ": "ḡ",
    "ğ": "ğ",
    "ǧ": "ǧ",
    "ĝ": "ĝ",
    "ġ": "ġ",
    "ģ": "ģ",
    "ḧ": "ḧ",
    "ȟ": "ȟ",
    "ĥ": "ĥ",
    "ḣ": "ḣ",
    "ḩ": "ḩ",
    "í": "í",
    "ì": "ì",
    "ï": "ï",
    "ḯ": "ḯ",
    "ĩ": "ĩ",
    "ī": "ī",
    "ĭ": "ĭ",
    "ǐ": "ǐ",
    "î": "î",
    "ǰ": "ǰ",
    "ĵ": "ĵ",
    "ḱ": "ḱ",
    "ǩ": "ǩ",
    "ķ": "ķ",
    "ĺ": "ĺ",
    "ľ": "ľ",
    "ļ": "ļ",
    "ḿ": "ḿ",
    "ṁ": "ṁ",
    "ń": "ń",
    "ǹ": "ǹ",
    "ñ": "ñ",
    "ň": "ň",
    "ṅ": "ṅ",
    "ņ": "ņ",
    "ó": "ó",
    "ò": "ò",
    "ö": "ö",
    "ȫ": "ȫ",
    "õ": "õ",
    "ṍ": "ṍ",
    "ṏ": "ṏ",
    "ȭ": "ȭ",
    "ō": "ō",
    "ṓ": "ṓ",
    "ṑ": "ṑ",
    "ŏ": "ŏ",
    "ǒ": "ǒ",
    "ô": "ô",
    "ố": "ố",
    "ồ": "ồ",
    "ỗ": "ỗ",
    "ȯ": "ȯ",
    "ȱ": "ȱ",
    "ő": "ő",
    "ṕ": "ṕ",
    "ṗ": "ṗ",
    "ŕ": "ŕ",
    "ř": "ř",
    "ṙ": "ṙ",
    "ŗ": "ŗ",
    "ś": "ś",
    "ṥ": "ṥ",
    "š": "š",
    "ṧ": "ṧ",
    "ŝ": "ŝ",
    "ṡ": "ṡ",
    "ş": "ş",
    "ẗ": "ẗ",
    "ť": "ť",
    "ṫ": "ṫ",
    "ţ": "ţ",
    "ú": "ú",
    "ù": "ù",
    "ü": "ü",
    "ǘ": "ǘ",
    "ǜ": "ǜ",
    "ǖ": "ǖ",
    "ǚ": "ǚ",
    "ũ": "ũ",
    "ṹ": "ṹ",
    "ū": "ū",
    "ṻ": "ṻ",
    "ŭ": "ŭ",
    "ǔ": "ǔ",
    "û": "û",
    "ů": "ů",
    "ű": "ű",
    "ṽ": "ṽ",
    "ẃ": "ẃ",
    "ẁ": "ẁ",
    "ẅ": "ẅ",
    "ŵ": "ŵ",
    "ẇ": "ẇ",
    "ẘ": "ẘ",
    "ẍ": "ẍ",
    "ẋ": "ẋ",
    "ý": "ý",
    "ỳ": "ỳ",
    "ÿ": "ÿ",
    "ỹ": "ỹ",
    "ȳ": "ȳ",
    "ŷ": "ŷ",
    "ẏ": "ẏ",
    "ẙ": "ẙ",
    "ź": "ź",
    "ž": "ž",
    "ẑ": "ẑ",
    "ż": "ż",
    "Á": "Á",
    "À": "À",
    "Ä": "Ä",
    "Ǟ": "Ǟ",
    "Ã": "Ã",
    "Ā": "Ā",
    "Ă": "Ă",
    "Ắ": "Ắ",
    "Ằ": "Ằ",
    "Ẵ": "Ẵ",
    "Ǎ": "Ǎ",
    "Â": "Â",
    "Ấ": "Ấ",
    "Ầ": "Ầ",
    "Ẫ": "Ẫ",
    "Ȧ": "Ȧ",
    "Ǡ": "Ǡ",
    "Å": "Å",
    "Ǻ": "Ǻ",
    "Ḃ": "Ḃ",
    "Ć": "Ć",
    "Ḉ": "Ḉ",
    "Č": "Č",
    "Ĉ": "Ĉ",
    "Ċ": "Ċ",
    "Ç": "Ç",
    "Ď": "Ď",
    "Ḋ": "Ḋ",
    "Ḑ": "Ḑ",
    "É": "É",
    "È": "È",
    "Ë": "Ë",
    "Ẽ": "Ẽ",
    "Ē": "Ē",
    "Ḗ": "Ḗ",
    "Ḕ": "Ḕ",
    "Ĕ": "Ĕ",
    "Ḝ": "Ḝ",
    "Ě": "Ě",
    "Ê": "Ê",
    "Ế": "Ế",
    "Ề": "Ề",
    "Ễ": "Ễ",
    "Ė": "Ė",
    "Ȩ": "Ȩ",
    "Ḟ": "Ḟ",
    "Ǵ": "Ǵ",
    "Ḡ": "Ḡ",
    "Ğ": "Ğ",
    "Ǧ": "Ǧ",
    "Ĝ": "Ĝ",
    "Ġ": "Ġ",
    "Ģ": "Ģ",
    "Ḧ": "Ḧ",
    "Ȟ": "Ȟ",
    "Ĥ": "Ĥ",
    "Ḣ": "Ḣ",
    "Ḩ": "Ḩ",
    "Í": "Í",
    "Ì": "Ì",
    "Ï": "Ï",
    "Ḯ": "Ḯ",
    "Ĩ": "Ĩ",
    "Ī": "Ī",
    "Ĭ": "Ĭ",
    "Ǐ": "Ǐ",
    "Î": "Î",
    "İ": "İ",
    "Ĵ": "Ĵ",
    "Ḱ": "Ḱ",
    "Ǩ": "Ǩ",
    "Ķ": "Ķ",
    "Ĺ": "Ĺ",
    "Ľ": "Ľ",
    "Ļ": "Ļ",
    "Ḿ": "Ḿ",
    "Ṁ": "Ṁ",
    "Ń": "Ń",
    "Ǹ": "Ǹ",
    "Ñ": "Ñ",
    "Ň": "Ň",
    "Ṅ": "Ṅ",
    "Ņ": "Ņ",
    "Ó": "Ó",
    "Ò": "Ò",
    "Ö": "Ö",
    "Ȫ": "Ȫ",
    "Õ": "Õ",
    "Ṍ": "Ṍ",
    "Ṏ": "Ṏ",
    "Ȭ": "Ȭ",
    "Ō": "Ō",
    "Ṓ": "Ṓ",
    "Ṑ": "Ṑ",
    "Ŏ": "Ŏ",
    "Ǒ": "Ǒ",
    "Ô": "Ô",
    "Ố": "Ố",
    "Ồ": "Ồ",
    "Ỗ": "Ỗ",
    "Ȯ": "Ȯ",
    "Ȱ": "Ȱ",
    "Ő": "Ő",
    "Ṕ": "Ṕ",
    "Ṗ": "Ṗ",
    "Ŕ": "Ŕ",
    "Ř": "Ř",
    "Ṙ": "Ṙ",
    "Ŗ": "Ŗ",
    "Ś": "Ś",
    "Ṥ": "Ṥ",
    "Š": "Š",
    "Ṧ": "Ṧ",
    "Ŝ": "Ŝ",
    "Ṡ": "Ṡ",
    "Ş": "Ş",
    "Ť": "Ť",
    "Ṫ": "Ṫ",
    "Ţ": "Ţ",
    "Ú": "Ú",
    "Ù": "Ù",
    "Ü": "Ü",
    "Ǘ": "Ǘ",
    "Ǜ": "Ǜ",
    "Ǖ": "Ǖ",
    "Ǚ": "Ǚ",
    "Ũ": "Ũ",
    "Ṹ": "Ṹ",
    "Ū": "Ū",
    "Ṻ": "Ṻ",
    "Ŭ": "Ŭ",
    "Ǔ": "Ǔ",
    "Û": "Û",
    "Ů": "Ů",
    "Ű": "Ű",
    "Ṽ": "Ṽ",
    "Ẃ": "Ẃ",
    "Ẁ": "Ẁ",
    "Ẅ": "Ẅ",
    "Ŵ": "Ŵ",
    "Ẇ": "Ẇ",
    "Ẍ": "Ẍ",
    "Ẋ": "Ẋ",
    "Ý": "Ý",
    "Ỳ": "Ỳ",
    "Ÿ": "Ÿ",
    "Ỹ": "Ỹ",
    "Ȳ": "Ȳ",
    "Ŷ": "Ŷ",
    "Ẏ": "Ẏ",
    "Ź": "Ź",
    "Ž": "Ž",
    "Ẑ": "Ẑ",
    "Ż": "Ż",
    "ά": "ά",
    "ὰ": "ὰ",
    "ᾱ": "ᾱ",
    "ᾰ": "ᾰ",
    "έ": "έ",
    "ὲ": "ὲ",
    "ή": "ή",
    "ὴ": "ὴ",
    "ί": "ί",
    "ὶ": "ὶ",
    "ϊ": "ϊ",
    "ΐ": "ΐ",
    "ῒ": "ῒ",
    "ῑ": "ῑ",
    "ῐ": "ῐ",
    "ό": "ό",
    "ὸ": "ὸ",
    "ύ": "ύ",
    "ὺ": "ὺ",
    "ϋ": "ϋ",
    "ΰ": "ΰ",
    "ῢ": "ῢ",
    "ῡ": "ῡ",
    "ῠ": "ῠ",
    "ώ": "ώ",
    "ὼ": "ὼ",
    "Ύ": "Ύ",
    "Ὺ": "Ὺ",
    "Ϋ": "Ϋ",
    "Ῡ": "Ῡ",
    "Ῠ": "Ῠ",
    "Ώ": "Ώ",
    "Ὼ": "Ὼ"
};
class Parser {
    constructor(input, settings){
        this.mode = void 0;
        this.gullet = void 0;
        this.settings = void 0;
        this.leftrightDepth = void 0;
        this.nextToken = void 0;
        this.mode = "math";
        this.gullet = new MacroExpander(input, settings, this.mode);
        this.settings = settings;
        this.leftrightDepth = 0;
    }
    expect(text, consume) {
        if (consume === void 0) {
            consume = true;
        }
        if (this.fetch().text !== text) {
            throw new ParseError("Expected '" + text + "', got '" + this.fetch().text + "'", this.fetch());
        }
        if (consume) {
            this.consume();
        }
    }
    consume() {
        this.nextToken = null;
    }
    fetch() {
        if (this.nextToken == null) {
            this.nextToken = this.gullet.expandNextToken();
        }
        return this.nextToken;
    }
    switchMode(newMode) {
        this.mode = newMode;
        this.gullet.switchMode(newMode);
    }
    parse() {
        if (!this.settings.globalGroup) {
            this.gullet.beginGroup();
        }
        if (this.settings.colorIsTextColor) {
            this.gullet.macros.set("\\color", "\\textcolor");
        }
        try {
            var parse = this.parseExpression(false);
            this.expect("EOF");
            if (!this.settings.globalGroup) {
                this.gullet.endGroup();
            }
            return parse;
        } finally{
            this.gullet.endGroups();
        }
    }
    subparse(tokens) {
        var oldToken = this.nextToken;
        this.consume();
        this.gullet.pushToken(new Token("}"));
        this.gullet.pushTokens(tokens);
        var parse = this.parseExpression(false);
        this.expect("}");
        this.nextToken = oldToken;
        return parse;
    }
    parseExpression(breakOnInfix, breakOnTokenText) {
        var body = [];
        while(true){
            if (this.mode === "math") {
                this.consumeSpaces();
            }
            var lex = this.fetch();
            if (Parser.endOfExpression.indexOf(lex.text) !== -1) {
                break;
            }
            if (breakOnTokenText && lex.text === breakOnTokenText) {
                break;
            }
            if (breakOnInfix && functions[lex.text] && functions[lex.text].infix) {
                break;
            }
            var atom = this.parseAtom(breakOnTokenText);
            if (!atom) {
                break;
            } else if (atom.type === "internal") {
                continue;
            }
            body.push(atom);
        }
        if (this.mode === "text") {
            this.formLigatures(body);
        }
        return this.handleInfixNodes(body);
    }
    handleInfixNodes(body) {
        var overIndex = -1;
        var funcName;
        for(var i = 0; i < body.length; i++){
            if (body[i].type === "infix") {
                if (overIndex !== -1) {
                    throw new ParseError("only one infix operator per group", body[i].token);
                }
                overIndex = i;
                funcName = body[i].replaceWith;
            }
        }
        if (overIndex !== -1 && funcName) {
            var numerNode;
            var denomNode;
            var numerBody = body.slice(0, overIndex);
            var denomBody = body.slice(overIndex + 1);
            if (numerBody.length === 1 && numerBody[0].type === "ordgroup") {
                numerNode = numerBody[0];
            } else {
                numerNode = {
                    type: "ordgroup",
                    mode: this.mode,
                    body: numerBody
                };
            }
            if (denomBody.length === 1 && denomBody[0].type === "ordgroup") {
                denomNode = denomBody[0];
            } else {
                denomNode = {
                    type: "ordgroup",
                    mode: this.mode,
                    body: denomBody
                };
            }
            var node;
            if (funcName === "\\\\abovefrac") {
                node = this.callFunction(funcName, [
                    numerNode,
                    body[overIndex],
                    denomNode
                ], []);
            } else {
                node = this.callFunction(funcName, [
                    numerNode,
                    denomNode
                ], []);
            }
            return [
                node
            ];
        } else {
            return body;
        }
    }
    handleSupSubscript(name) {
        var symbolToken = this.fetch();
        var symbol = symbolToken.text;
        this.consume();
        this.consumeSpaces();
        var group = this.parseGroup(name);
        if (!group) {
            throw new ParseError("Expected group after '" + symbol + "'", symbolToken);
        }
        return group;
    }
    formatUnsupportedCmd(text) {
        var textordArray = [];
        for(var i = 0; i < text.length; i++){
            textordArray.push({
                type: "textord",
                mode: "text",
                text: text[i]
            });
        }
        var textNode = {
            type: "text",
            mode: this.mode,
            body: textordArray
        };
        var colorNode = {
            type: "color",
            mode: this.mode,
            color: this.settings.errorColor,
            body: [
                textNode
            ]
        };
        return colorNode;
    }
    parseAtom(breakOnTokenText) {
        var base = this.parseGroup("atom", breakOnTokenText);
        if (this.mode === "text") {
            return base;
        }
        var superscript;
        var subscript;
        while(true){
            this.consumeSpaces();
            var lex = this.fetch();
            if (lex.text === "\\limits" || lex.text === "\\nolimits") {
                if (base && base.type === "op") {
                    var limits = lex.text === "\\limits";
                    base.limits = limits;
                    base.alwaysHandleSupSub = true;
                } else if (base && base.type === "operatorname") {
                    if (base.alwaysHandleSupSub) {
                        base.limits = lex.text === "\\limits";
                    }
                } else {
                    throw new ParseError("Limit controls must follow a math operator", lex);
                }
                this.consume();
            } else if (lex.text === "^") {
                if (superscript) {
                    throw new ParseError("Double superscript", lex);
                }
                superscript = this.handleSupSubscript("superscript");
            } else if (lex.text === "_") {
                if (subscript) {
                    throw new ParseError("Double subscript", lex);
                }
                subscript = this.handleSupSubscript("subscript");
            } else if (lex.text === "'") {
                if (superscript) {
                    throw new ParseError("Double superscript", lex);
                }
                var prime = {
                    type: "textord",
                    mode: this.mode,
                    text: "\\prime"
                };
                var primes = [
                    prime
                ];
                this.consume();
                while(this.fetch().text === "'"){
                    primes.push(prime);
                    this.consume();
                }
                if (this.fetch().text === "^") {
                    primes.push(this.handleSupSubscript("superscript"));
                }
                superscript = {
                    type: "ordgroup",
                    mode: this.mode,
                    body: primes
                };
            } else if (uSubsAndSups[lex.text]) {
                var str = uSubsAndSups[lex.text];
                var isSub = unicodeSubRegEx.test(lex.text);
                this.consume();
                while(true){
                    var token = this.fetch().text;
                    if (!uSubsAndSups[token]) {
                        break;
                    }
                    if (unicodeSubRegEx.test(token) !== isSub) {
                        break;
                    }
                    this.consume();
                    str += uSubsAndSups[token];
                }
                var body = new Parser(str, this.settings).parse();
                if (isSub) {
                    subscript = {
                        type: "ordgroup",
                        mode: "math",
                        body
                    };
                } else {
                    superscript = {
                        type: "ordgroup",
                        mode: "math",
                        body
                    };
                }
            } else {
                break;
            }
        }
        if (superscript || subscript) {
            return {
                type: "supsub",
                mode: this.mode,
                base: base,
                sup: superscript,
                sub: subscript
            };
        } else {
            return base;
        }
    }
    parseFunction(breakOnTokenText, name) {
        var token = this.fetch();
        var func = token.text;
        var funcData = functions[func];
        if (!funcData) {
            return null;
        }
        this.consume();
        if (name && name !== "atom" && !funcData.allowedInArgument) {
            throw new ParseError("Got function '" + func + "' with no arguments" + (name ? " as " + name : ""), token);
        } else if (this.mode === "text" && !funcData.allowedInText) {
            throw new ParseError("Can't use function '" + func + "' in text mode", token);
        } else if (this.mode === "math" && funcData.allowedInMath === false) {
            throw new ParseError("Can't use function '" + func + "' in math mode", token);
        }
        var { args , optArgs  } = this.parseArguments(func, funcData);
        return this.callFunction(func, args, optArgs, token, breakOnTokenText);
    }
    callFunction(name, args, optArgs, token, breakOnTokenText) {
        var context = {
            funcName: name,
            parser: this,
            token,
            breakOnTokenText
        };
        var func = functions[name];
        if (func && func.handler) {
            return func.handler(context, args, optArgs);
        } else {
            throw new ParseError("No function handler for " + name);
        }
    }
    parseArguments(func, funcData) {
        var totalArgs = funcData.numArgs + funcData.numOptionalArgs;
        if (totalArgs === 0) {
            return {
                args: [],
                optArgs: []
            };
        }
        var args = [];
        var optArgs = [];
        for(var i = 0; i < totalArgs; i++){
            var argType = funcData.argTypes && funcData.argTypes[i];
            var isOptional = i < funcData.numOptionalArgs;
            if (funcData.primitive && argType == null || funcData.type === "sqrt" && i === 1 && optArgs[0] == null) {
                argType = "primitive";
            }
            var arg = this.parseGroupOfType("argument to '" + func + "'", argType, isOptional);
            if (isOptional) {
                optArgs.push(arg);
            } else if (arg != null) {
                args.push(arg);
            } else {
                throw new ParseError("Null argument, please report this as a bug");
            }
        }
        return {
            args,
            optArgs
        };
    }
    parseGroupOfType(name, type, optional) {
        switch(type){
            case "color":
                return this.parseColorGroup(optional);
            case "size":
                return this.parseSizeGroup(optional);
            case "url":
                return this.parseUrlGroup(optional);
            case "math":
            case "text":
                return this.parseArgumentGroup(optional, type);
            case "hbox":
                {
                    var group = this.parseArgumentGroup(optional, "text");
                    return group != null ? {
                        type: "styling",
                        mode: group.mode,
                        body: [
                            group
                        ],
                        style: "text"
                    } : null;
                }
            case "raw":
                {
                    var token = this.parseStringGroup("raw", optional);
                    return token != null ? {
                        type: "raw",
                        mode: "text",
                        string: token.text
                    } : null;
                }
            case "primitive":
                {
                    if (optional) {
                        throw new ParseError("A primitive argument cannot be optional");
                    }
                    var _group = this.parseGroup(name);
                    if (_group == null) {
                        throw new ParseError("Expected group as " + name, this.fetch());
                    }
                    return _group;
                }
            case "original":
            case null:
            case undefined:
                return this.parseArgumentGroup(optional);
            default:
                throw new ParseError("Unknown group type as " + name, this.fetch());
        }
    }
    consumeSpaces() {
        while(this.fetch().text === " "){
            this.consume();
        }
    }
    parseStringGroup(modeName, optional) {
        var argToken = this.gullet.scanArgument(optional);
        if (argToken == null) {
            return null;
        }
        var str = "";
        var nextToken;
        while((nextToken = this.fetch()).text !== "EOF"){
            str += nextToken.text;
            this.consume();
        }
        this.consume();
        argToken.text = str;
        return argToken;
    }
    parseRegexGroup(regex, modeName) {
        var firstToken = this.fetch();
        var lastToken = firstToken;
        var str = "";
        var nextToken;
        while((nextToken = this.fetch()).text !== "EOF" && regex.test(str + nextToken.text)){
            lastToken = nextToken;
            str += lastToken.text;
            this.consume();
        }
        if (str === "") {
            throw new ParseError("Invalid " + modeName + ": '" + firstToken.text + "'", firstToken);
        }
        return firstToken.range(lastToken, str);
    }
    parseColorGroup(optional) {
        var res = this.parseStringGroup("color", optional);
        if (res == null) {
            return null;
        }
        var match = /^(#[a-f0-9]{3}|#?[a-f0-9]{6}|[a-z]+)$/i.exec(res.text);
        if (!match) {
            throw new ParseError("Invalid color: '" + res.text + "'", res);
        }
        var color = match[0];
        if (/^[0-9a-f]{6}$/i.test(color)) {
            color = "#" + color;
        }
        return {
            type: "color-token",
            mode: this.mode,
            color
        };
    }
    parseSizeGroup(optional) {
        var res;
        var isBlank = false;
        this.gullet.consumeSpaces();
        if (!optional && this.gullet.future().text !== "{") {
            res = this.parseRegexGroup(/^[-+]? *(?:$|\d+|\d+\.\d*|\.\d*) *[a-z]{0,2} *$/, "size");
        } else {
            res = this.parseStringGroup("size", optional);
        }
        if (!res) {
            return null;
        }
        if (!optional && res.text.length === 0) {
            res.text = "0pt";
            isBlank = true;
        }
        var match = /([-+]?) *(\d+(?:\.\d*)?|\.\d+) *([a-z]{2})/.exec(res.text);
        if (!match) {
            throw new ParseError("Invalid size: '" + res.text + "'", res);
        }
        var data = {
            number: +(match[1] + match[2]),
            unit: match[3]
        };
        if (!validUnit(data)) {
            throw new ParseError("Invalid unit: '" + data.unit + "'", res);
        }
        return {
            type: "size",
            mode: this.mode,
            value: data,
            isBlank
        };
    }
    parseUrlGroup(optional) {
        this.gullet.lexer.setCatcode("%", 13);
        this.gullet.lexer.setCatcode("~", 12);
        var res = this.parseStringGroup("url", optional);
        this.gullet.lexer.setCatcode("%", 14);
        this.gullet.lexer.setCatcode("~", 13);
        if (res == null) {
            return null;
        }
        var url = res.text.replace(/\\([#$%&~_^{}])/g, '$1');
        return {
            type: "url",
            mode: this.mode,
            url
        };
    }
    parseArgumentGroup(optional, mode) {
        var argToken = this.gullet.scanArgument(optional);
        if (argToken == null) {
            return null;
        }
        var outerMode = this.mode;
        if (mode) {
            this.switchMode(mode);
        }
        this.gullet.beginGroup();
        var expression = this.parseExpression(false, "EOF");
        this.expect("EOF");
        this.gullet.endGroup();
        var result = {
            type: "ordgroup",
            mode: this.mode,
            loc: argToken.loc,
            body: expression
        };
        if (mode) {
            this.switchMode(outerMode);
        }
        return result;
    }
    parseGroup(name, breakOnTokenText) {
        var firstToken = this.fetch();
        var text = firstToken.text;
        var result;
        if (text === "{" || text === "\\begingroup") {
            this.consume();
            var groupEnd = text === "{" ? "}" : "\\endgroup";
            this.gullet.beginGroup();
            var expression = this.parseExpression(false, groupEnd);
            var lastToken = this.fetch();
            this.expect(groupEnd);
            this.gullet.endGroup();
            result = {
                type: "ordgroup",
                mode: this.mode,
                loc: SourceLocation.range(firstToken, lastToken),
                body: expression,
                semisimple: text === "\\begingroup" || undefined
            };
        } else {
            result = this.parseFunction(breakOnTokenText, name) || this.parseSymbol();
            if (result == null && text[0] === "\\" && !implicitCommands.hasOwnProperty(text)) {
                if (this.settings.throwOnError) {
                    throw new ParseError("Undefined control sequence: " + text, firstToken);
                }
                result = this.formatUnsupportedCmd(text);
                this.consume();
            }
        }
        return result;
    }
    formLigatures(group) {
        var n = group.length - 1;
        for(var i = 0; i < n; ++i){
            var a = group[i];
            var v = a.text;
            if (v === "-" && group[i + 1].text === "-") {
                if (i + 1 < n && group[i + 2].text === "-") {
                    group.splice(i, 3, {
                        type: "textord",
                        mode: "text",
                        loc: SourceLocation.range(a, group[i + 2]),
                        text: "---"
                    });
                    n -= 2;
                } else {
                    group.splice(i, 2, {
                        type: "textord",
                        mode: "text",
                        loc: SourceLocation.range(a, group[i + 1]),
                        text: "--"
                    });
                    n -= 1;
                }
            }
            if ((v === "'" || v === "`") && group[i + 1].text === v) {
                group.splice(i, 2, {
                    type: "textord",
                    mode: "text",
                    loc: SourceLocation.range(a, group[i + 1]),
                    text: v + v
                });
                n -= 1;
            }
        }
    }
    parseSymbol() {
        var nucleus = this.fetch();
        var text = nucleus.text;
        if (/^\\verb[^a-zA-Z]/.test(text)) {
            this.consume();
            var arg = text.slice(5);
            var star = arg.charAt(0) === "*";
            if (star) {
                arg = arg.slice(1);
            }
            if (arg.length < 2 || arg.charAt(0) !== arg.slice(-1)) {
                throw new ParseError("\\verb assertion failed --\n                    please report what input caused this bug");
            }
            arg = arg.slice(1, -1);
            return {
                type: "verb",
                mode: "text",
                body: arg,
                star
            };
        }
        if (unicodeSymbols.hasOwnProperty(text[0]) && !symbols[this.mode][text[0]]) {
            if (this.settings.strict && this.mode === "math") {
                this.settings.reportNonstrict("unicodeTextInMathMode", "Accented Unicode text character \"" + text[0] + "\" used in " + "math mode", nucleus);
            }
            text = unicodeSymbols[text[0]] + text.slice(1);
        }
        var match = combiningDiacriticalMarksEndRegex.exec(text);
        if (match) {
            text = text.substring(0, match.index);
            if (text === 'i') {
                text = '\u0131';
            } else if (text === 'j') {
                text = '\u0237';
            }
        }
        var symbol;
        if (symbols[this.mode][text]) {
            if (this.settings.strict && this.mode === 'math' && extraLatin.indexOf(text) >= 0) {
                this.settings.reportNonstrict("unicodeTextInMathMode", "Latin-1/Unicode text character \"" + text[0] + "\" used in " + "math mode", nucleus);
            }
            var group = symbols[this.mode][text].group;
            var loc = SourceLocation.range(nucleus);
            var s;
            if (ATOMS.hasOwnProperty(group)) {
                var family = group;
                s = {
                    type: "atom",
                    mode: this.mode,
                    family,
                    loc,
                    text
                };
            } else {
                s = {
                    type: group,
                    mode: this.mode,
                    loc,
                    text
                };
            }
            symbol = s;
        } else if (text.charCodeAt(0) >= 0x80) {
            if (this.settings.strict) {
                if (!supportedCodepoint(text.charCodeAt(0))) {
                    this.settings.reportNonstrict("unknownSymbol", "Unrecognized Unicode character \"" + text[0] + "\"" + (" (" + text.charCodeAt(0) + ")"), nucleus);
                } else if (this.mode === "math") {
                    this.settings.reportNonstrict("unicodeTextInMathMode", "Unicode text character \"" + text[0] + "\" used in math mode", nucleus);
                }
            }
            symbol = {
                type: "textord",
                mode: "text",
                loc: SourceLocation.range(nucleus),
                text
            };
        } else {
            return null;
        }
        this.consume();
        if (match) {
            for(var i = 0; i < match[0].length; i++){
                var accent = match[0][i];
                if (!unicodeAccents[accent]) {
                    throw new ParseError("Unknown accent ' " + accent + "'", nucleus);
                }
                var command = unicodeAccents[accent][this.mode] || unicodeAccents[accent].text;
                if (!command) {
                    throw new ParseError("Accent " + accent + " unsupported in " + this.mode + " mode", nucleus);
                }
                symbol = {
                    type: "accent",
                    mode: this.mode,
                    loc: SourceLocation.range(nucleus),
                    label: command,
                    isStretchy: false,
                    isShifty: true,
                    base: symbol
                };
            }
        }
        return symbol;
    }
}
Parser.endOfExpression = [
    "}",
    "\\endgroup",
    "\\end",
    "\\right",
    "&"
];
var parseTree = function parseTree(toParse, settings) {
    if (!(typeof toParse === 'string' || toParse instanceof String)) {
        throw new TypeError('KaTeX can only parse string typed expression');
    }
    var parser = new Parser(toParse, settings);
    delete parser.gullet.macros.current["\\df@tag"];
    var tree = parser.parse();
    delete parser.gullet.macros.current["\\current@color"];
    delete parser.gullet.macros.current["\\color"];
    if (parser.gullet.macros.get("\\df@tag")) {
        if (!settings.displayMode) {
            throw new ParseError("\\tag works only in display equations");
        }
        tree = [
            {
                type: "tag",
                mode: "text",
                body: tree,
                tag: parser.subparse([
                    new Token("\\df@tag")
                ])
            }
        ];
    }
    return tree;
};
var render = function render(expression, baseNode, options) {
    baseNode.textContent = "";
    var node = renderToDomTree(expression, options).toNode();
    baseNode.appendChild(node);
};
if (typeof document !== "undefined") {
    if (document.compatMode !== "CSS1Compat") {
        typeof console !== "undefined" && console.warn("Warning: KaTeX doesn't work in quirks mode. Make sure your " + "website has a suitable doctype.");
        render = function render() {
            throw new ParseError("KaTeX doesn't work in quirks mode.");
        };
    }
}
var renderToString = function renderToString(expression, options) {
    var markup = renderToDomTree(expression, options).toMarkup();
    return markup;
};
var generateParseTree = function generateParseTree(expression, options) {
    var settings = new Settings(options);
    return parseTree(expression, settings);
};
var renderError = function renderError(error, expression, options) {
    if (options.throwOnError || !(error instanceof ParseError)) {
        throw error;
    }
    var node = buildCommon.makeSpan([
        "katex-error"
    ], [
        new SymbolNode(expression)
    ]);
    node.setAttribute("title", error.toString());
    node.setAttribute("style", "color:" + options.errorColor);
    return node;
};
var renderToDomTree = function renderToDomTree(expression, options) {
    var settings = new Settings(options);
    try {
        var tree = parseTree(expression, settings);
        return buildTree(tree, expression, settings);
    } catch (error) {
        return renderError(error, expression, settings);
    }
};
var renderToHTMLTree = function renderToHTMLTree(expression, options) {
    var settings = new Settings(options);
    try {
        var tree = parseTree(expression, settings);
        return buildHTMLTree(tree, expression, settings);
    } catch (error) {
        return renderError(error, expression, settings);
    }
};
var katex = {
    version: "0.16.9",
    render,
    renderToString,
    ParseError,
    SETTINGS_SCHEMA,
    __parse: generateParseTree,
    __renderToDomTree: renderToDomTree,
    __renderToHTMLTree: renderToHTMLTree,
    __setFontMetrics: setFontMetrics,
    __defineSymbol: defineSymbol,
    __defineFunction: defineFunction,
    __defineMacro: defineMacro,
    __domTree: {
        Span,
        Anchor,
        SymbolNode,
        SvgNode,
        PathNode,
        LineNode
    }
};
export { katex as default };

