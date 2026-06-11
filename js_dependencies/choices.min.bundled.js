var __getOwnPropNames = Object.getOwnPropertyNames;
var __commonJS = (cb, mod) => function __require() {
  return mod || (0, cb[__getOwnPropNames(cb)[0]])((mod = { exports: {} }).exports, mod), mod.exports;
};

// dev/Bonito/js_dependencies/choices.min.js
var require_choices_min = __commonJS({
  "dev/Bonito/js_dependencies/choices.min.js"(exports, module) {
    !function(e, t) {
      "object" == typeof exports && "undefined" != typeof module ? module.exports = t() : "function" == typeof define && define.amd ? define(t) : (e = "undefined" != typeof globalThis ? globalThis : e || self).Choices = t();
    }(exports, function() {
      "use strict";
      var e = function(t2, i2) {
        return e = Object.setPrototypeOf || { __proto__: [] } instanceof Array && function(e2, t3) {
          e2.__proto__ = t3;
        } || function(e2, t3) {
          for (var i3 in t3) Object.prototype.hasOwnProperty.call(t3, i3) && (e2[i3] = t3[i3]);
        }, e(t2, i2);
      };
      function t(t2, i2) {
        if ("function" != typeof i2 && null !== i2) throw new TypeError("Class extends value " + String(i2) + " is not a constructor or null");
        function n2() {
          this.constructor = t2;
        }
        e(t2, i2), t2.prototype = null === i2 ? Object.create(i2) : (n2.prototype = i2.prototype, new n2());
      }
      var i = function() {
        return i = Object.assign || function(e2) {
          for (var t2, i2 = 1, n2 = arguments.length; i2 < n2; i2++) for (var s2 in t2 = arguments[i2]) Object.prototype.hasOwnProperty.call(t2, s2) && (e2[s2] = t2[s2]);
          return e2;
        }, i.apply(this, arguments);
      };
      function n(e2, t2, i2) {
        if (i2 || 2 === arguments.length) for (var n2, s2 = 0, o2 = t2.length; s2 < o2; s2++) !n2 && s2 in t2 || (n2 || (n2 = Array.prototype.slice.call(t2, 0, s2)), n2[s2] = t2[s2]);
        return e2.concat(n2 || Array.prototype.slice.call(t2));
      }
      "function" == typeof SuppressedError && SuppressedError;
      var s, o = "ADD_CHOICE", r = "REMOVE_CHOICE", c = "FILTER_CHOICES", a = "ACTIVATE_CHOICES", h = "CLEAR_CHOICES", l = "ADD_GROUP", u = "ADD_ITEM", d = "REMOVE_ITEM", p = "HIGHLIGHT_ITEM", f = "search", m = "removeItem", g = "highlightItem", v = ["fuseOptions", "classNames"], _ = "select-one", y = "select-multiple", b = function(e2) {
        return { type: o, choice: e2 };
      }, E = function(e2) {
        return { type: u, item: e2 };
      }, C = function(e2) {
        return { type: d, item: e2 };
      }, S = function(e2, t2) {
        return { type: p, item: e2, highlighted: t2 };
      }, w = function(e2) {
        return Array.from({ length: e2 }, function() {
          return Math.floor(36 * Math.random() + 0).toString(36);
        }).join("");
      }, I = function(e2) {
        if ("string" != typeof e2) {
          if (null == e2) return "";
          if ("object" == typeof e2) {
            if ("raw" in e2) return I(e2.raw);
            if ("trusted" in e2) return e2.trusted;
          }
          return e2;
        }
        return e2.replace(/&/g, "&amp;").replace(/>/g, "&gt;").replace(/</g, "&lt;").replace(/'/g, "&#039;").replace(/"/g, "&quot;");
      }, A = (s = document.createElement("div"), function(e2) {
        s.innerHTML = e2.trim();
        for (var t2 = s.children[0]; s.firstChild; ) s.removeChild(s.firstChild);
        return t2;
      }), x = function(e2, t2) {
        return "function" == typeof e2 ? e2(I(t2), t2) : e2;
      }, O = function(e2) {
        return "function" == typeof e2 ? e2() : e2;
      }, L = function(e2) {
        if ("string" == typeof e2) return e2;
        if ("object" == typeof e2) {
          if ("trusted" in e2) return e2.trusted;
          if ("raw" in e2) return e2.raw;
        }
        return "";
      }, M = function(e2) {
        if ("string" == typeof e2) return e2;
        if ("object" == typeof e2) {
          if ("escaped" in e2) return e2.escaped;
          if ("trusted" in e2) return e2.trusted;
        }
        return "";
      }, T = function(e2, t2) {
        return e2 ? M(t2) : I(t2);
      }, N = function(e2, t2, i2) {
        e2.innerHTML = T(t2, i2);
      }, k = function(e2, t2) {
        return e2.rank - t2.rank;
      }, F = function(e2) {
        return Array.isArray(e2) ? e2 : [e2];
      }, D = function(e2) {
        return e2 && Array.isArray(e2) ? e2.map(function(e3) {
          return ".".concat(e3);
        }).join("") : ".".concat(e2);
      }, P = function(e2, t2) {
        var i2;
        (i2 = e2.classList).add.apply(i2, F(t2));
      }, j = function(e2, t2) {
        var i2;
        (i2 = e2.classList).remove.apply(i2, F(t2));
      }, R = function(e2) {
        if (void 0 !== e2) try {
          return JSON.parse(e2);
        } catch (t2) {
          return e2;
        }
        return {};
      }, K = function() {
        function e2(e3) {
          var t2 = e3.type, i2 = e3.classNames;
          this.element = e3.element, this.classNames = i2, this.type = t2, this.isActive = false;
        }
        return e2.prototype.show = function() {
          return P(this.element, this.classNames.activeState), this.element.setAttribute("aria-expanded", "true"), this.isActive = true, this;
        }, e2.prototype.hide = function() {
          return j(this.element, this.classNames.activeState), this.element.setAttribute("aria-expanded", "false"), this.isActive = false, this;
        }, e2;
      }(), V = function() {
        function e2(e3) {
          var t2 = e3.type, i2 = e3.classNames, n2 = e3.position;
          this.element = e3.element, this.classNames = i2, this.type = t2, this.position = n2, this.isOpen = false, this.isFlipped = false, this.isDisabled = false, this.isLoading = false;
        }
        return e2.prototype.shouldFlip = function(e3, t2) {
          var i2 = false;
          return "auto" === this.position ? i2 = this.element.getBoundingClientRect().top - t2 >= 0 && !window.matchMedia("(min-height: ".concat(e3 + 1, "px)")).matches : "top" === this.position && (i2 = true), i2;
        }, e2.prototype.setActiveDescendant = function(e3) {
          this.element.setAttribute("aria-activedescendant", e3);
        }, e2.prototype.removeActiveDescendant = function() {
          this.element.removeAttribute("aria-activedescendant");
        }, e2.prototype.open = function(e3, t2) {
          P(this.element, this.classNames.openState), this.element.setAttribute("aria-expanded", "true"), this.isOpen = true, this.shouldFlip(e3, t2) && (P(this.element, this.classNames.flippedState), this.isFlipped = true);
        }, e2.prototype.close = function() {
          j(this.element, this.classNames.openState), this.element.setAttribute("aria-expanded", "false"), this.removeActiveDescendant(), this.isOpen = false, this.isFlipped && (j(this.element, this.classNames.flippedState), this.isFlipped = false);
        }, e2.prototype.addFocusState = function() {
          P(this.element, this.classNames.focusState);
        }, e2.prototype.removeFocusState = function() {
          j(this.element, this.classNames.focusState);
        }, e2.prototype.enable = function() {
          j(this.element, this.classNames.disabledState), this.element.removeAttribute("aria-disabled"), this.type === _ && this.element.setAttribute("tabindex", "0"), this.isDisabled = false;
        }, e2.prototype.disable = function() {
          P(this.element, this.classNames.disabledState), this.element.setAttribute("aria-disabled", "true"), this.type === _ && this.element.setAttribute("tabindex", "-1"), this.isDisabled = true;
        }, e2.prototype.wrap = function(e3) {
          var t2 = this.element, i2 = e3.parentNode;
          i2 && (e3.nextSibling ? i2.insertBefore(t2, e3.nextSibling) : i2.appendChild(t2)), t2.appendChild(e3);
        }, e2.prototype.unwrap = function(e3) {
          var t2 = this.element, i2 = t2.parentNode;
          i2 && (i2.insertBefore(e3, t2), i2.removeChild(t2));
        }, e2.prototype.addLoadingState = function() {
          P(this.element, this.classNames.loadingState), this.element.setAttribute("aria-busy", "true"), this.isLoading = true;
        }, e2.prototype.removeLoadingState = function() {
          j(this.element, this.classNames.loadingState), this.element.removeAttribute("aria-busy"), this.isLoading = false;
        }, e2;
      }(), B = function() {
        function e2(e3) {
          var t2 = e3.element, i2 = e3.type, n2 = e3.classNames, s2 = e3.preventPaste;
          this.element = t2, this.type = i2, this.classNames = n2, this.preventPaste = s2, this.isFocussed = this.element.isEqualNode(document.activeElement), this.isDisabled = t2.disabled, this._onPaste = this._onPaste.bind(this), this._onInput = this._onInput.bind(this), this._onFocus = this._onFocus.bind(this), this._onBlur = this._onBlur.bind(this);
        }
        return Object.defineProperty(e2.prototype, "placeholder", { set: function(e3) {
          this.element.placeholder = e3;
        }, enumerable: false, configurable: true }), Object.defineProperty(e2.prototype, "value", { get: function() {
          return this.element.value;
        }, set: function(e3) {
          this.element.value = e3;
        }, enumerable: false, configurable: true }), e2.prototype.addEventListeners = function() {
          var e3 = this.element;
          e3.addEventListener("paste", this._onPaste), e3.addEventListener("input", this._onInput, { passive: true }), e3.addEventListener("focus", this._onFocus, { passive: true }), e3.addEventListener("blur", this._onBlur, { passive: true });
        }, e2.prototype.removeEventListeners = function() {
          var e3 = this.element;
          e3.removeEventListener("input", this._onInput), e3.removeEventListener("paste", this._onPaste), e3.removeEventListener("focus", this._onFocus), e3.removeEventListener("blur", this._onBlur);
        }, e2.prototype.enable = function() {
          this.element.removeAttribute("disabled"), this.isDisabled = false;
        }, e2.prototype.disable = function() {
          this.element.setAttribute("disabled", ""), this.isDisabled = true;
        }, e2.prototype.focus = function() {
          this.isFocussed || this.element.focus();
        }, e2.prototype.blur = function() {
          this.isFocussed && this.element.blur();
        }, e2.prototype.clear = function(e3) {
          return void 0 === e3 && (e3 = true), this.element.value = "", e3 && this.setWidth(), this;
        }, e2.prototype.setWidth = function() {
          var e3 = this.element;
          e3.style.minWidth = "".concat(e3.placeholder.length + 1, "ch"), e3.style.width = "".concat(e3.value.length + 1, "ch");
        }, e2.prototype.setActiveDescendant = function(e3) {
          this.element.setAttribute("aria-activedescendant", e3);
        }, e2.prototype.removeActiveDescendant = function() {
          this.element.removeAttribute("aria-activedescendant");
        }, e2.prototype._onInput = function() {
          this.type !== _ && this.setWidth();
        }, e2.prototype._onPaste = function(e3) {
          this.preventPaste && e3.preventDefault();
        }, e2.prototype._onFocus = function() {
          this.isFocussed = true;
        }, e2.prototype._onBlur = function() {
          this.isFocussed = false;
        }, e2;
      }(), H = function() {
        function e2(e3) {
          this.element = e3.element, this.scrollPos = this.element.scrollTop, this.height = this.element.offsetHeight;
        }
        return e2.prototype.prepend = function(e3) {
          var t2 = this.element.firstElementChild;
          t2 ? this.element.insertBefore(e3, t2) : this.element.append(e3);
        }, e2.prototype.scrollToTop = function() {
          this.element.scrollTop = 0;
        }, e2.prototype.scrollToChildElement = function(e3, t2) {
          var i2 = this;
          if (e3) {
            var n2 = t2 > 0 ? this.element.scrollTop + (e3.offsetTop + e3.offsetHeight) - (this.element.scrollTop + this.element.offsetHeight) : e3.offsetTop;
            requestAnimationFrame(function() {
              i2._animateScroll(n2, t2);
            });
          }
        }, e2.prototype._scrollDown = function(e3, t2, i2) {
          var n2 = (i2 - e3) / t2;
          this.element.scrollTop = e3 + (n2 > 1 ? n2 : 1);
        }, e2.prototype._scrollUp = function(e3, t2, i2) {
          var n2 = (e3 - i2) / t2;
          this.element.scrollTop = e3 - (n2 > 1 ? n2 : 1);
        }, e2.prototype._animateScroll = function(e3, t2) {
          var i2 = this, n2 = this.element.scrollTop, s2 = false;
          t2 > 0 ? (this._scrollDown(n2, 4, e3), n2 < e3 && (s2 = true)) : (this._scrollUp(n2, 4, e3), n2 > e3 && (s2 = true)), s2 && requestAnimationFrame(function() {
            i2._animateScroll(e3, t2);
          });
        }, e2;
      }(), $ = function() {
        function e2(e3) {
          var t2 = e3.classNames;
          this.element = e3.element, this.classNames = t2, this.isDisabled = false;
        }
        return Object.defineProperty(e2.prototype, "isActive", { get: function() {
          return "active" === this.element.dataset.choice;
        }, enumerable: false, configurable: true }), Object.defineProperty(e2.prototype, "dir", { get: function() {
          return this.element.dir;
        }, enumerable: false, configurable: true }), Object.defineProperty(e2.prototype, "value", { get: function() {
          return this.element.value;
        }, set: function(e3) {
          this.element.setAttribute("value", e3), this.element.value = e3;
        }, enumerable: false, configurable: true }), e2.prototype.conceal = function() {
          var e3 = this.element;
          P(e3, this.classNames.input), e3.hidden = true, e3.tabIndex = -1;
          var t2 = e3.getAttribute("style");
          t2 && e3.setAttribute("data-choice-orig-style", t2), e3.setAttribute("data-choice", "active");
        }, e2.prototype.reveal = function() {
          var e3 = this.element;
          j(e3, this.classNames.input), e3.hidden = false, e3.removeAttribute("tabindex");
          var t2 = e3.getAttribute("data-choice-orig-style");
          t2 ? (e3.removeAttribute("data-choice-orig-style"), e3.setAttribute("style", t2)) : e3.removeAttribute("style"), e3.removeAttribute("data-choice");
        }, e2.prototype.enable = function() {
          this.element.removeAttribute("disabled"), this.element.disabled = false, this.isDisabled = false;
        }, e2.prototype.disable = function() {
          this.element.setAttribute("disabled", ""), this.element.disabled = true, this.isDisabled = true;
        }, e2.prototype.triggerEvent = function(e3, t2) {
          var i2;
          void 0 === (i2 = t2 || {}) && (i2 = null), this.element.dispatchEvent(new CustomEvent(e3, { detail: i2, bubbles: true, cancelable: true }));
        }, e2;
      }(), q = function(e2) {
        function i2() {
          return null !== e2 && e2.apply(this, arguments) || this;
        }
        return t(i2, e2), i2;
      }($), W = function(e2, t2) {
        return void 0 === t2 && (t2 = true), void 0 === e2 ? t2 : !!e2;
      }, U = function(e2) {
        if ("string" == typeof e2 && (e2 = e2.split(" ").filter(function(e3) {
          return e3.length;
        })), Array.isArray(e2) && e2.length) return e2;
      }, G = function(e2, t2, i2) {
        if (void 0 === i2 && (i2 = true), "string" == typeof e2) {
          var n2 = I(e2);
          return G({ value: e2, label: i2 || n2 === e2 ? e2 : { escaped: n2, raw: e2 }, selected: true }, false);
        }
        var s2 = e2;
        if ("choices" in s2) {
          if (!t2) throw new TypeError("optGroup is not allowed");
          var o2 = s2, r2 = o2.choices.map(function(e3) {
            return G(e3, false);
          });
          return { id: 0, label: L(o2.label) || o2.value, active: !!r2.length, disabled: !!o2.disabled, choices: r2 };
        }
        var c2 = s2;
        return { id: 0, group: null, score: 0, rank: 0, value: c2.value, label: c2.label || c2.value, active: W(c2.active), selected: W(c2.selected, false), disabled: W(c2.disabled, false), placeholder: W(c2.placeholder, false), highlighted: false, labelClass: U(c2.labelClass), labelDescription: c2.labelDescription, customProperties: c2.customProperties };
      }, z = function(e2) {
        return "SELECT" === e2.tagName;
      }, J = function(e2) {
        function i2(t2) {
          var i3 = t2.template, n2 = t2.extractPlaceholder, s2 = e2.call(this, { element: t2.element, classNames: t2.classNames }) || this;
          return s2.template = i3, s2.extractPlaceholder = n2, s2;
        }
        return t(i2, e2), Object.defineProperty(i2.prototype, "placeholderOption", { get: function() {
          return this.element.querySelector('option[value=""]') || this.element.querySelector("option[placeholder]");
        }, enumerable: false, configurable: true }), i2.prototype.addOptions = function(e3) {
          var t2 = this, i3 = document.createDocumentFragment();
          e3.forEach(function(e4) {
            var n2 = e4;
            if (!n2.element) {
              var s2 = t2.template(n2);
              i3.appendChild(s2), n2.element = s2;
            }
          }), this.element.appendChild(i3);
        }, i2.prototype.optionsAsChoices = function() {
          var e3 = this, t2 = [];
          return this.element.querySelectorAll(":scope > option, :scope > optgroup").forEach(function(i3) {
            !function(e4) {
              return "OPTION" === e4.tagName;
            }(i3) ? function(e4) {
              return "OPTGROUP" === e4.tagName;
            }(i3) && t2.push(e3._optgroupToChoice(i3)) : t2.push(e3._optionToChoice(i3));
          }), t2;
        }, i2.prototype._optionToChoice = function(e3) {
          return !e3.hasAttribute("value") && e3.hasAttribute("placeholder") && (e3.setAttribute("value", ""), e3.value = ""), { id: 0, group: null, score: 0, rank: 0, value: e3.value, label: e3.label, element: e3, active: true, selected: this.extractPlaceholder ? e3.selected : e3.hasAttribute("selected"), disabled: e3.disabled, highlighted: false, placeholder: this.extractPlaceholder && (!e3.value || e3.hasAttribute("placeholder")), labelClass: void 0 !== e3.dataset.labelClass ? U(e3.dataset.labelClass) : void 0, labelDescription: void 0 !== e3.dataset.labelDescription ? e3.dataset.labelDescription : void 0, customProperties: R(e3.dataset.customProperties) };
        }, i2.prototype._optgroupToChoice = function(e3) {
          var t2 = this, i3 = e3.querySelectorAll("option"), n2 = Array.from(i3).map(function(e4) {
            return t2._optionToChoice(e4);
          });
          return { id: 0, label: e3.label || "", element: e3, active: !!n2.length, disabled: e3.disabled, choices: n2 };
        }, i2;
      }($), X = { items: [], choices: [], silent: false, renderChoiceLimit: -1, maxItemCount: -1, closeDropdownOnSelect: "auto", singleModeForMultiSelect: false, addChoices: false, addItems: true, addItemFilter: function(e2) {
        return !!e2 && "" !== e2;
      }, removeItems: true, removeItemButton: false, removeItemButtonAlignLeft: false, editItems: false, allowHTML: false, allowHtmlUserInput: false, duplicateItemsAllowed: true, delimiter: ",", paste: true, searchEnabled: true, searchChoices: true, searchFloor: 1, searchResultLimit: 4, searchFields: ["label", "value"], position: "auto", resetScrollPosition: true, shouldSort: true, shouldSortItems: false, sorter: function(e2, t2) {
        var i2 = e2.label, n2 = t2.label, s2 = void 0 === n2 ? t2.value : n2;
        return L(void 0 === i2 ? e2.value : i2).localeCompare(L(s2), [], { sensitivity: "base", ignorePunctuation: true, numeric: true });
      }, shadowRoot: null, placeholder: true, placeholderValue: null, searchPlaceholderValue: null, prependValue: null, appendValue: null, renderSelectedChoices: "auto", loadingText: "Loading...", noResultsText: "No results found", noChoicesText: "No choices to choose from", itemSelectText: "Press to select", uniqueItemText: "Only unique values can be added", customAddItemText: "Only values matching specific conditions can be added", addItemText: function(e2) {
        return 'Press Enter to add <b>"'.concat(e2, '"</b>');
      }, removeItemIconText: function() {
        return "Remove item";
      }, removeItemLabelText: function(e2) {
        return "Remove item: ".concat(e2);
      }, maxItemText: function(e2) {
        return "Only ".concat(e2, " values can be added");
      }, valueComparer: function(e2, t2) {
        return e2 === t2;
      }, fuseOptions: { includeScore: true }, labelId: "", callbackOnInit: null, callbackOnCreateTemplates: null, classNames: { containerOuter: ["choices"], containerInner: ["choices__inner"], input: ["choices__input"], inputCloned: ["choices__input--cloned"], list: ["choices__list"], listItems: ["choices__list--multiple"], listSingle: ["choices__list--single"], listDropdown: ["choices__list--dropdown"], item: ["choices__item"], itemSelectable: ["choices__item--selectable"], itemDisabled: ["choices__item--disabled"], itemChoice: ["choices__item--choice"], description: ["choices__description"], placeholder: ["choices__placeholder"], group: ["choices__group"], groupHeading: ["choices__heading"], button: ["choices__button"], activeState: ["is-active"], focusState: ["is-focused"], openState: ["is-open"], disabledState: ["is-disabled"], highlightedState: ["is-highlighted"], selectedState: ["is-selected"], flippedState: ["is-flipped"], loadingState: ["is-loading"], notice: ["choices__notice"], addChoice: ["choices__item--selectable", "add-choice"], noResults: ["has-no-results"], noChoices: ["has-no-choices"] }, appendGroupInSearch: false }, Q = function(e2) {
        var t2 = e2.itemEl;
        t2 && (t2.remove(), e2.itemEl = void 0);
      }, Y = { groups: function(e2, t2) {
        var i2 = e2, n2 = true;
        switch (t2.type) {
          case l:
            i2.push(t2.group);
            break;
          case h:
            i2 = [];
            break;
          default:
            n2 = false;
        }
        return { state: i2, update: n2 };
      }, items: function(e2, t2, i2) {
        var n2 = e2, s2 = true;
        switch (t2.type) {
          case u:
            t2.item.selected = true, (o2 = t2.item.element) && (o2.selected = true, o2.setAttribute("selected", "")), n2.push(t2.item);
            break;
          case d:
            var o2;
            if (t2.item.selected = false, o2 = t2.item.element) {
              o2.selected = false, o2.removeAttribute("selected");
              var c2 = o2.parentElement;
              c2 && z(c2) && c2.type === _ && (c2.value = "");
            }
            Q(t2.item), n2 = n2.filter(function(e3) {
              return e3.id !== t2.item.id;
            });
            break;
          case r:
            Q(t2.choice), n2 = n2.filter(function(e3) {
              return e3.id !== t2.choice.id;
            });
            break;
          case p:
            var a2 = t2.highlighted, h2 = n2.find(function(e3) {
              return e3.id === t2.item.id;
            });
            h2 && h2.highlighted !== a2 && (h2.highlighted = a2, i2 && function(e3, t3, i3) {
              var n3 = e3.itemEl;
              n3 && (j(n3, i3), P(n3, t3));
            }(h2, a2 ? i2.classNames.highlightedState : i2.classNames.selectedState, a2 ? i2.classNames.selectedState : i2.classNames.highlightedState));
            break;
          default:
            s2 = false;
        }
        return { state: n2, update: s2 };
      }, choices: function(e2, t2, i2) {
        var n2 = e2, s2 = true;
        switch (t2.type) {
          case o:
            n2.push(t2.choice);
            break;
          case r:
            t2.choice.choiceEl = void 0, t2.choice.group && (t2.choice.group.choices = t2.choice.group.choices.filter(function(e3) {
              return e3.id !== t2.choice.id;
            })), n2 = n2.filter(function(e3) {
              return e3.id !== t2.choice.id;
            });
            break;
          case u:
          case d:
            t2.item.choiceEl = void 0;
            break;
          case c:
            var l2 = [];
            t2.results.forEach(function(e3) {
              l2[e3.item.id] = e3;
            }), n2.forEach(function(e3) {
              var t3 = l2[e3.id];
              void 0 !== t3 ? (e3.score = t3.score, e3.rank = t3.rank, e3.active = true) : (e3.score = 0, e3.rank = 0, e3.active = false), i2 && i2.appendGroupInSearch && (e3.choiceEl = void 0);
            });
            break;
          case a:
            n2.forEach(function(e3) {
              e3.active = t2.active, i2 && i2.appendGroupInSearch && (e3.choiceEl = void 0);
            });
            break;
          case h:
            n2 = [];
            break;
          default:
            s2 = false;
        }
        return { state: n2, update: s2 };
      } }, Z = function() {
        function e2(e3) {
          this._state = this.defaultState, this._listeners = [], this._txn = 0, this._context = e3;
        }
        return Object.defineProperty(e2.prototype, "defaultState", { get: function() {
          return { groups: [], items: [], choices: [] };
        }, enumerable: false, configurable: true }), e2.prototype.changeSet = function(e3) {
          return { groups: e3, items: e3, choices: e3 };
        }, e2.prototype.reset = function() {
          this._state = this.defaultState;
          var e3 = this.changeSet(true);
          this._txn ? this._changeSet = e3 : this._listeners.forEach(function(t2) {
            return t2(e3);
          });
        }, e2.prototype.subscribe = function(e3) {
          return this._listeners.push(e3), this;
        }, e2.prototype.dispatch = function(e3) {
          var t2 = this, i2 = this._state, n2 = false, s2 = this._changeSet || this.changeSet(false);
          Object.keys(Y).forEach(function(o2) {
            var r2 = Y[o2](i2[o2], e3, t2._context);
            r2.update && (n2 = true, s2[o2] = true, i2[o2] = r2.state);
          }), n2 && (this._txn ? this._changeSet = s2 : this._listeners.forEach(function(e4) {
            return e4(s2);
          }));
        }, e2.prototype.withTxn = function(e3) {
          this._txn++;
          try {
            e3();
          } finally {
            if (this._txn = Math.max(0, this._txn - 1), !this._txn) {
              var t2 = this._changeSet;
              t2 && (this._changeSet = void 0, this._listeners.forEach(function(e4) {
                return e4(t2);
              }));
            }
          }
        }, Object.defineProperty(e2.prototype, "state", { get: function() {
          return this._state;
        }, enumerable: false, configurable: true }), Object.defineProperty(e2.prototype, "items", { get: function() {
          return this.state.items;
        }, enumerable: false, configurable: true }), Object.defineProperty(e2.prototype, "highlightedActiveItems", { get: function() {
          return this.items.filter(function(e3) {
            return e3.active && e3.highlighted;
          });
        }, enumerable: false, configurable: true }), Object.defineProperty(e2.prototype, "choices", { get: function() {
          return this.state.choices;
        }, enumerable: false, configurable: true }), Object.defineProperty(e2.prototype, "activeChoices", { get: function() {
          return this.choices.filter(function(e3) {
            return e3.active;
          });
        }, enumerable: false, configurable: true }), Object.defineProperty(e2.prototype, "searchableChoices", { get: function() {
          return this.choices.filter(function(e3) {
            return !e3.disabled && !e3.placeholder;
          });
        }, enumerable: false, configurable: true }), Object.defineProperty(e2.prototype, "groups", { get: function() {
          return this.state.groups;
        }, enumerable: false, configurable: true }), Object.defineProperty(e2.prototype, "activeGroups", { get: function() {
          var e3 = this;
          return this.state.groups.filter(function(t2) {
            var i2 = t2.active && !t2.disabled, n2 = e3.state.choices.some(function(e4) {
              return e4.active && !e4.disabled;
            });
            return i2 && n2;
          }, []);
        }, enumerable: false, configurable: true }), e2.prototype.inTxn = function() {
          return this._txn > 0;
        }, e2.prototype.getChoiceById = function(e3) {
          return this.activeChoices.find(function(t2) {
            return t2.id === e3;
          });
        }, e2.prototype.getGroupById = function(e3) {
          return this.groups.find(function(t2) {
            return t2.id === e3;
          });
        }, e2;
      }(), ee = "no-choices", te = "no-results", ie = "add-choice";
      function ne(e2, t2, i2) {
        return (t2 = function(e3) {
          var t3 = function(e4) {
            if ("object" != typeof e4 || !e4) return e4;
            var t4 = e4[Symbol.toPrimitive];
            if (void 0 !== t4) {
              var i3 = t4.call(e4, "string");
              if ("object" != typeof i3) return i3;
              throw new TypeError("@@toPrimitive must return a primitive value.");
            }
            return String(e4);
          }(e3);
          return "symbol" == typeof t3 ? t3 : t3 + "";
        }(t2)) in e2 ? Object.defineProperty(e2, t2, { value: i2, enumerable: true, configurable: true, writable: true }) : e2[t2] = i2, e2;
      }
      function se(e2, t2) {
        var i2 = Object.keys(e2);
        if (Object.getOwnPropertySymbols) {
          var n2 = Object.getOwnPropertySymbols(e2);
          t2 && (n2 = n2.filter(function(t3) {
            return Object.getOwnPropertyDescriptor(e2, t3).enumerable;
          })), i2.push.apply(i2, n2);
        }
        return i2;
      }
      function oe(e2) {
        for (var t2 = 1; t2 < arguments.length; t2++) {
          var i2 = null != arguments[t2] ? arguments[t2] : {};
          t2 % 2 ? se(Object(i2), true).forEach(function(t3) {
            ne(e2, t3, i2[t3]);
          }) : Object.getOwnPropertyDescriptors ? Object.defineProperties(e2, Object.getOwnPropertyDescriptors(i2)) : se(Object(i2)).forEach(function(t3) {
            Object.defineProperty(e2, t3, Object.getOwnPropertyDescriptor(i2, t3));
          });
        }
        return e2;
      }
      function re(e2) {
        return Array.isArray ? Array.isArray(e2) : "[object Array]" === de(e2);
      }
      function ce(e2) {
        return "string" == typeof e2;
      }
      function ae(e2) {
        return "number" == typeof e2;
      }
      function he(e2) {
        return "object" == typeof e2;
      }
      function le(e2) {
        return null != e2;
      }
      function ue(e2) {
        return !e2.trim().length;
      }
      function de(e2) {
        return null == e2 ? void 0 === e2 ? "[object Undefined]" : "[object Null]" : Object.prototype.toString.call(e2);
      }
      const pe = (e2) => `Missing ${e2} property in key`, fe = (e2) => `Property 'weight' in key '${e2}' must be a positive integer`, me = Object.prototype.hasOwnProperty;
      class ge {
        constructor(e2) {
          this._keys = [], this._keyMap = {};
          let t2 = 0;
          e2.forEach((e3) => {
            let i2 = ve(e3);
            this._keys.push(i2), this._keyMap[i2.id] = i2, t2 += i2.weight;
          }), this._keys.forEach((e3) => {
            e3.weight /= t2;
          });
        }
        get(e2) {
          return this._keyMap[e2];
        }
        keys() {
          return this._keys;
        }
        toJSON() {
          return JSON.stringify(this._keys);
        }
      }
      function ve(e2) {
        let t2 = null, i2 = null, n2 = null, s2 = 1, o2 = null;
        if (ce(e2) || re(e2)) n2 = e2, t2 = _e(e2), i2 = ye(e2);
        else {
          if (!me.call(e2, "name")) throw new Error(pe("name"));
          const r2 = e2.name;
          if (n2 = r2, me.call(e2, "weight") && (s2 = e2.weight, s2 <= 0)) throw new Error(fe(r2));
          t2 = _e(r2), i2 = ye(r2), o2 = e2.getFn;
        }
        return { path: t2, id: i2, weight: s2, src: n2, getFn: o2 };
      }
      function _e(e2) {
        return re(e2) ? e2 : e2.split(".");
      }
      function ye(e2) {
        return re(e2) ? e2.join(".") : e2;
      }
      const be = { useExtendedSearch: false, getFn: function(e2, t2) {
        let i2 = [], n2 = false;
        const s2 = (e3, t3, o2) => {
          if (le(e3)) if (t3[o2]) {
            const r2 = e3[t3[o2]];
            if (!le(r2)) return;
            if (o2 === t3.length - 1 && (ce(r2) || ae(r2) || function(e4) {
              return true === e4 || false === e4 || function(e5) {
                return he(e5) && null !== e5;
              }(e4) && "[object Boolean]" == de(e4);
            }(r2))) i2.push(function(e4) {
              return null == e4 ? "" : function(e5) {
                if ("string" == typeof e5) return e5;
                let t4 = e5 + "";
                return "0" == t4 && 1 / e5 == -1 / 0 ? "-0" : t4;
              }(e4);
            }(r2));
            else if (re(r2)) {
              n2 = true;
              for (let e4 = 0, i3 = r2.length; e4 < i3; e4 += 1) s2(r2[e4], t3, o2 + 1);
            } else t3.length && s2(r2, t3, o2 + 1);
          } else i2.push(e3);
        };
        return s2(e2, ce(t2) ? t2.split(".") : t2, 0), n2 ? i2 : i2[0];
      }, ignoreLocation: false, ignoreFieldNorm: false, fieldNormWeight: 1 };
      var Ee = oe(oe(oe(oe({}, { isCaseSensitive: false, includeScore: false, keys: [], shouldSort: true, sortFn: (e2, t2) => e2.score === t2.score ? e2.idx < t2.idx ? -1 : 1 : e2.score < t2.score ? -1 : 1 }), { includeMatches: false, findAllMatches: false, minMatchCharLength: 1 }), { location: 0, threshold: 0.6, distance: 100 }), be);
      const Ce = /[^ ]+/g;
      class Se {
        constructor({ getFn: e2 = Ee.getFn, fieldNormWeight: t2 = Ee.fieldNormWeight } = {}) {
          this.norm = function(e3 = 1, t3 = 3) {
            const i2 = /* @__PURE__ */ new Map(), n2 = Math.pow(10, t3);
            return { get(t4) {
              const s2 = t4.match(Ce).length;
              if (i2.has(s2)) return i2.get(s2);
              const o2 = 1 / Math.pow(s2, 0.5 * e3), r2 = parseFloat(Math.round(o2 * n2) / n2);
              return i2.set(s2, r2), r2;
            }, clear() {
              i2.clear();
            } };
          }(t2, 3), this.getFn = e2, this.isCreated = false, this.setIndexRecords();
        }
        setSources(e2 = []) {
          this.docs = e2;
        }
        setIndexRecords(e2 = []) {
          this.records = e2;
        }
        setKeys(e2 = []) {
          this.keys = e2, this._keysMap = {}, e2.forEach((e3, t2) => {
            this._keysMap[e3.id] = t2;
          });
        }
        create() {
          !this.isCreated && this.docs.length && (this.isCreated = true, ce(this.docs[0]) ? this.docs.forEach((e2, t2) => {
            this._addString(e2, t2);
          }) : this.docs.forEach((e2, t2) => {
            this._addObject(e2, t2);
          }), this.norm.clear());
        }
        add(e2) {
          const t2 = this.size();
          ce(e2) ? this._addString(e2, t2) : this._addObject(e2, t2);
        }
        removeAt(e2) {
          this.records.splice(e2, 1);
          for (let t2 = e2, i2 = this.size(); t2 < i2; t2 += 1) this.records[t2].i -= 1;
        }
        getValueForItemAtKeyId(e2, t2) {
          return e2[this._keysMap[t2]];
        }
        size() {
          return this.records.length;
        }
        _addString(e2, t2) {
          if (!le(e2) || ue(e2)) return;
          let i2 = { v: e2, i: t2, n: this.norm.get(e2) };
          this.records.push(i2);
        }
        _addObject(e2, t2) {
          let i2 = { i: t2, $: {} };
          this.keys.forEach((t3, n2) => {
            let s2 = t3.getFn ? t3.getFn(e2) : this.getFn(e2, t3.path);
            if (le(s2)) {
              if (re(s2)) {
                let e3 = [];
                const t4 = [{ nestedArrIndex: -1, value: s2 }];
                for (; t4.length; ) {
                  const { nestedArrIndex: i3, value: n3 } = t4.pop();
                  if (le(n3)) if (ce(n3) && !ue(n3)) {
                    let t5 = { v: n3, i: i3, n: this.norm.get(n3) };
                    e3.push(t5);
                  } else re(n3) && n3.forEach((e4, i4) => {
                    t4.push({ nestedArrIndex: i4, value: e4 });
                  });
                }
                i2.$[n2] = e3;
              } else if (ce(s2) && !ue(s2)) {
                let e3 = { v: s2, n: this.norm.get(s2) };
                i2.$[n2] = e3;
              }
            }
          }), this.records.push(i2);
        }
        toJSON() {
          return { keys: this.keys, records: this.records };
        }
      }
      function we(e2, t2, { getFn: i2 = Ee.getFn, fieldNormWeight: n2 = Ee.fieldNormWeight } = {}) {
        const s2 = new Se({ getFn: i2, fieldNormWeight: n2 });
        return s2.setKeys(e2.map(ve)), s2.setSources(t2), s2.create(), s2;
      }
      function Ie(e2, { errors: t2 = 0, currentLocation: i2 = 0, expectedLocation: n2 = 0, distance: s2 = Ee.distance, ignoreLocation: o2 = Ee.ignoreLocation } = {}) {
        const r2 = t2 / e2.length;
        if (o2) return r2;
        const c2 = Math.abs(n2 - i2);
        return s2 ? r2 + c2 / s2 : c2 ? 1 : r2;
      }
      const Ae = 32;
      function xe(e2) {
        let t2 = {};
        for (let i2 = 0, n2 = e2.length; i2 < n2; i2 += 1) {
          const s2 = e2.charAt(i2);
          t2[s2] = (t2[s2] || 0) | 1 << n2 - i2 - 1;
        }
        return t2;
      }
      class Oe {
        constructor(e2, { location: t2 = Ee.location, threshold: i2 = Ee.threshold, distance: n2 = Ee.distance, includeMatches: s2 = Ee.includeMatches, findAllMatches: o2 = Ee.findAllMatches, minMatchCharLength: r2 = Ee.minMatchCharLength, isCaseSensitive: c2 = Ee.isCaseSensitive, ignoreLocation: a2 = Ee.ignoreLocation } = {}) {
          if (this.options = { location: t2, threshold: i2, distance: n2, includeMatches: s2, findAllMatches: o2, minMatchCharLength: r2, isCaseSensitive: c2, ignoreLocation: a2 }, this.pattern = c2 ? e2 : e2.toLowerCase(), this.chunks = [], !this.pattern.length) return;
          const h2 = (e3, t3) => {
            this.chunks.push({ pattern: e3, alphabet: xe(e3), startIndex: t3 });
          }, l2 = this.pattern.length;
          if (l2 > Ae) {
            let e3 = 0;
            const t3 = l2 % Ae, i3 = l2 - t3;
            for (; e3 < i3; ) h2(this.pattern.substr(e3, Ae), e3), e3 += Ae;
            if (t3) {
              const e4 = l2 - Ae;
              h2(this.pattern.substr(e4), e4);
            }
          } else h2(this.pattern, 0);
        }
        searchIn(e2) {
          const { isCaseSensitive: t2, includeMatches: i2 } = this.options;
          if (t2 || (e2 = e2.toLowerCase()), this.pattern === e2) {
            let t3 = { isMatch: true, score: 0 };
            return i2 && (t3.indices = [[0, e2.length - 1]]), t3;
          }
          const { location: n2, distance: s2, threshold: o2, findAllMatches: r2, minMatchCharLength: c2, ignoreLocation: a2 } = this.options;
          let h2 = [], l2 = 0, u2 = false;
          this.chunks.forEach(({ pattern: t3, alphabet: d3, startIndex: p2 }) => {
            const { isMatch: f2, score: m2, indices: g2 } = function(e3, t4, i3, { location: n3 = Ee.location, distance: s3 = Ee.distance, threshold: o3 = Ee.threshold, findAllMatches: r3 = Ee.findAllMatches, minMatchCharLength: c3 = Ee.minMatchCharLength, includeMatches: a3 = Ee.includeMatches, ignoreLocation: h3 = Ee.ignoreLocation } = {}) {
              if (t4.length > Ae) throw new Error("Pattern length exceeds max of 32.");
              const l3 = t4.length, u3 = e3.length, d4 = Math.max(0, Math.min(n3, u3));
              let p3 = o3, f3 = d4;
              const m3 = c3 > 1 || a3, g3 = m3 ? Array(u3) : [];
              let v2;
              for (; (v2 = e3.indexOf(t4, f3)) > -1; ) {
                let e4 = Ie(t4, { currentLocation: v2, expectedLocation: d4, distance: s3, ignoreLocation: h3 });
                if (p3 = Math.min(e4, p3), f3 = v2 + l3, m3) {
                  let e5 = 0;
                  for (; e5 < l3; ) g3[v2 + e5] = 1, e5 += 1;
                }
              }
              f3 = -1;
              let _2 = [], y2 = 1, b2 = l3 + u3;
              const E2 = 1 << l3 - 1;
              for (let n4 = 0; n4 < l3; n4 += 1) {
                let o4 = 0, c4 = b2;
                for (; o4 < c4; ) Ie(t4, { errors: n4, currentLocation: d4 + c4, expectedLocation: d4, distance: s3, ignoreLocation: h3 }) <= p3 ? o4 = c4 : b2 = c4, c4 = Math.floor((b2 - o4) / 2 + o4);
                b2 = c4;
                let a4 = Math.max(1, d4 - c4 + 1), v3 = r3 ? u3 : Math.min(d4 + c4, u3) + l3, C3 = Array(v3 + 2);
                C3[v3 + 1] = (1 << n4) - 1;
                for (let o5 = v3; o5 >= a4; o5 -= 1) {
                  let r4 = o5 - 1, c5 = i3[e3.charAt(r4)];
                  if (m3 && (g3[r4] = +!!c5), C3[o5] = (C3[o5 + 1] << 1 | 1) & c5, n4 && (C3[o5] |= (_2[o5 + 1] | _2[o5]) << 1 | 1 | _2[o5 + 1]), C3[o5] & E2 && (y2 = Ie(t4, { errors: n4, currentLocation: r4, expectedLocation: d4, distance: s3, ignoreLocation: h3 }), y2 <= p3)) {
                    if (p3 = y2, f3 = r4, f3 <= d4) break;
                    a4 = Math.max(1, 2 * d4 - f3);
                  }
                }
                if (Ie(t4, { errors: n4 + 1, currentLocation: d4, expectedLocation: d4, distance: s3, ignoreLocation: h3 }) > p3) break;
                _2 = C3;
              }
              const C2 = { isMatch: f3 >= 0, score: Math.max(1e-3, y2) };
              if (m3) {
                const e4 = function(e5 = [], t5 = Ee.minMatchCharLength) {
                  let i4 = [], n4 = -1, s4 = -1, o4 = 0;
                  for (let r4 = e5.length; o4 < r4; o4 += 1) {
                    let r5 = e5[o4];
                    r5 && -1 === n4 ? n4 = o4 : r5 || -1 === n4 || (s4 = o4 - 1, s4 - n4 + 1 >= t5 && i4.push([n4, s4]), n4 = -1);
                  }
                  return e5[o4 - 1] && o4 - n4 >= t5 && i4.push([n4, o4 - 1]), i4;
                }(g3, c3);
                e4.length ? a3 && (C2.indices = e4) : C2.isMatch = false;
              }
              return C2;
            }(e2, t3, d3, { location: n2 + p2, distance: s2, threshold: o2, findAllMatches: r2, minMatchCharLength: c2, includeMatches: i2, ignoreLocation: a2 });
            f2 && (u2 = true), l2 += m2, f2 && g2 && (h2 = [...h2, ...g2]);
          });
          let d2 = { isMatch: u2, score: u2 ? l2 / this.chunks.length : 1 };
          return u2 && i2 && (d2.indices = h2), d2;
        }
      }
      class Le {
        constructor(e2) {
          this.pattern = e2;
        }
        static isMultiMatch(e2) {
          return Me(e2, this.multiRegex);
        }
        static isSingleMatch(e2) {
          return Me(e2, this.singleRegex);
        }
        search() {
        }
      }
      function Me(e2, t2) {
        const i2 = e2.match(t2);
        return i2 ? i2[1] : null;
      }
      class Te extends Le {
        constructor(e2, { location: t2 = Ee.location, threshold: i2 = Ee.threshold, distance: n2 = Ee.distance, includeMatches: s2 = Ee.includeMatches, findAllMatches: o2 = Ee.findAllMatches, minMatchCharLength: r2 = Ee.minMatchCharLength, isCaseSensitive: c2 = Ee.isCaseSensitive, ignoreLocation: a2 = Ee.ignoreLocation } = {}) {
          super(e2), this._bitapSearch = new Oe(e2, { location: t2, threshold: i2, distance: n2, includeMatches: s2, findAllMatches: o2, minMatchCharLength: r2, isCaseSensitive: c2, ignoreLocation: a2 });
        }
        static get type() {
          return "fuzzy";
        }
        static get multiRegex() {
          return /^"(.*)"$/;
        }
        static get singleRegex() {
          return /^(.*)$/;
        }
        search(e2) {
          return this._bitapSearch.searchIn(e2);
        }
      }
      class Ne extends Le {
        constructor(e2) {
          super(e2);
        }
        static get type() {
          return "include";
        }
        static get multiRegex() {
          return /^'"(.*)"$/;
        }
        static get singleRegex() {
          return /^'(.*)$/;
        }
        search(e2) {
          let t2, i2 = 0;
          const n2 = [], s2 = this.pattern.length;
          for (; (t2 = e2.indexOf(this.pattern, i2)) > -1; ) i2 = t2 + s2, n2.push([t2, i2 - 1]);
          const o2 = !!n2.length;
          return { isMatch: o2, score: o2 ? 0 : 1, indices: n2 };
        }
      }
      const ke = [class extends Le {
        constructor(e2) {
          super(e2);
        }
        static get type() {
          return "exact";
        }
        static get multiRegex() {
          return /^="(.*)"$/;
        }
        static get singleRegex() {
          return /^=(.*)$/;
        }
        search(e2) {
          const t2 = e2 === this.pattern;
          return { isMatch: t2, score: t2 ? 0 : 1, indices: [0, this.pattern.length - 1] };
        }
      }, Ne, class extends Le {
        constructor(e2) {
          super(e2);
        }
        static get type() {
          return "prefix-exact";
        }
        static get multiRegex() {
          return /^\^"(.*)"$/;
        }
        static get singleRegex() {
          return /^\^(.*)$/;
        }
        search(e2) {
          const t2 = e2.startsWith(this.pattern);
          return { isMatch: t2, score: t2 ? 0 : 1, indices: [0, this.pattern.length - 1] };
        }
      }, class extends Le {
        constructor(e2) {
          super(e2);
        }
        static get type() {
          return "inverse-prefix-exact";
        }
        static get multiRegex() {
          return /^!\^"(.*)"$/;
        }
        static get singleRegex() {
          return /^!\^(.*)$/;
        }
        search(e2) {
          const t2 = !e2.startsWith(this.pattern);
          return { isMatch: t2, score: t2 ? 0 : 1, indices: [0, e2.length - 1] };
        }
      }, class extends Le {
        constructor(e2) {
          super(e2);
        }
        static get type() {
          return "inverse-suffix-exact";
        }
        static get multiRegex() {
          return /^!"(.*)"\$$/;
        }
        static get singleRegex() {
          return /^!(.*)\$$/;
        }
        search(e2) {
          const t2 = !e2.endsWith(this.pattern);
          return { isMatch: t2, score: t2 ? 0 : 1, indices: [0, e2.length - 1] };
        }
      }, class extends Le {
        constructor(e2) {
          super(e2);
        }
        static get type() {
          return "suffix-exact";
        }
        static get multiRegex() {
          return /^"(.*)"\$$/;
        }
        static get singleRegex() {
          return /^(.*)\$$/;
        }
        search(e2) {
          const t2 = e2.endsWith(this.pattern);
          return { isMatch: t2, score: t2 ? 0 : 1, indices: [e2.length - this.pattern.length, e2.length - 1] };
        }
      }, class extends Le {
        constructor(e2) {
          super(e2);
        }
        static get type() {
          return "inverse-exact";
        }
        static get multiRegex() {
          return /^!"(.*)"$/;
        }
        static get singleRegex() {
          return /^!(.*)$/;
        }
        search(e2) {
          const t2 = -1 === e2.indexOf(this.pattern);
          return { isMatch: t2, score: t2 ? 0 : 1, indices: [0, e2.length - 1] };
        }
      }, Te], Fe = ke.length, De = / +(?=(?:[^\"]*\"[^\"]*\")*[^\"]*$)/, Pe = /* @__PURE__ */ new Set([Te.type, Ne.type]);
      const je = [];
      function Re(e2, t2) {
        for (let i2 = 0, n2 = je.length; i2 < n2; i2 += 1) {
          let n3 = je[i2];
          if (n3.condition(e2, t2)) return new n3(e2, t2);
        }
        return new Oe(e2, t2);
      }
      const Ke = "$and", Ve = "$path", Be = (e2) => !(!e2[Ke] && !e2.$or), He = (e2) => ({ [Ke]: Object.keys(e2).map((t2) => ({ [t2]: e2[t2] })) });
      function $e(e2, t2, { auto: i2 = true } = {}) {
        const n2 = (e3) => {
          let s2 = Object.keys(e3);
          const o2 = ((e4) => !!e4[Ve])(e3);
          if (!o2 && s2.length > 1 && !Be(e3)) return n2(He(e3));
          if (((e4) => !re(e4) && he(e4) && !Be(e4))(e3)) {
            const n3 = o2 ? e3[Ve] : s2[0], r3 = o2 ? e3.$val : e3[n3];
            if (!ce(r3)) throw new Error(((e4) => `Invalid value for key ${e4}`)(n3));
            const c2 = { keyId: ye(n3), pattern: r3 };
            return i2 && (c2.searcher = Re(r3, t2)), c2;
          }
          let r2 = { children: [], operator: s2[0] };
          return s2.forEach((t3) => {
            const i3 = e3[t3];
            re(i3) && i3.forEach((e4) => {
              r2.children.push(n2(e4));
            });
          }), r2;
        };
        return Be(e2) || (e2 = He(e2)), n2(e2);
      }
      function qe(e2, t2) {
        const i2 = e2.matches;
        t2.matches = [], le(i2) && i2.forEach((e3) => {
          if (!le(e3.indices) || !e3.indices.length) return;
          const { indices: i3, value: n2 } = e3;
          let s2 = { indices: i3, value: n2 };
          e3.key && (s2.key = e3.key.src), e3.idx > -1 && (s2.refIndex = e3.idx), t2.matches.push(s2);
        });
      }
      function We(e2, t2) {
        t2.score = e2.score;
      }
      class Ue {
        constructor(e2, t2 = {}, i2) {
          this.options = oe(oe({}, Ee), t2), this._keyStore = new ge(this.options.keys), this.setCollection(e2, i2);
        }
        setCollection(e2, t2) {
          if (this._docs = e2, t2 && !(t2 instanceof Se)) throw new Error("Incorrect 'index' type");
          this._myIndex = t2 || we(this.options.keys, this._docs, { getFn: this.options.getFn, fieldNormWeight: this.options.fieldNormWeight });
        }
        add(e2) {
          le(e2) && (this._docs.push(e2), this._myIndex.add(e2));
        }
        remove(e2 = () => false) {
          const t2 = [];
          for (let i2 = 0, n2 = this._docs.length; i2 < n2; i2 += 1) {
            const s2 = this._docs[i2];
            e2(s2, i2) && (this.removeAt(i2), i2 -= 1, n2 -= 1, t2.push(s2));
          }
          return t2;
        }
        removeAt(e2) {
          this._docs.splice(e2, 1), this._myIndex.removeAt(e2);
        }
        getIndex() {
          return this._myIndex;
        }
        search(e2, { limit: t2 = -1 } = {}) {
          const { includeMatches: i2, includeScore: n2, shouldSort: s2, sortFn: o2, ignoreFieldNorm: r2 } = this.options;
          let c2 = ce(e2) ? ce(this._docs[0]) ? this._searchStringList(e2) : this._searchObjectList(e2) : this._searchLogical(e2);
          return function(e3, { ignoreFieldNorm: t3 = Ee.ignoreFieldNorm }) {
            e3.forEach((e4) => {
              let i3 = 1;
              e4.matches.forEach(({ key: e5, norm: n3, score: s3 }) => {
                const o3 = e5 ? e5.weight : null;
                i3 *= Math.pow(0 === s3 && o3 ? Number.EPSILON : s3, (o3 || 1) * (t3 ? 1 : n3));
              }), e4.score = i3;
            });
          }(c2, { ignoreFieldNorm: r2 }), s2 && c2.sort(o2), ae(t2) && t2 > -1 && (c2 = c2.slice(0, t2)), function(e3, t3, { includeMatches: i3 = Ee.includeMatches, includeScore: n3 = Ee.includeScore } = {}) {
            const s3 = [];
            return i3 && s3.push(qe), n3 && s3.push(We), e3.map((e4) => {
              const { idx: i4 } = e4, n4 = { item: t3[i4], refIndex: i4 };
              return s3.length && s3.forEach((t4) => {
                t4(e4, n4);
              }), n4;
            });
          }(c2, this._docs, { includeMatches: i2, includeScore: n2 });
        }
        _searchStringList(e2) {
          const t2 = Re(e2, this.options), { records: i2 } = this._myIndex, n2 = [];
          return i2.forEach(({ v: e3, i: i3, n: s2 }) => {
            if (!le(e3)) return;
            const { isMatch: o2, score: r2, indices: c2 } = t2.searchIn(e3);
            o2 && n2.push({ item: e3, idx: i3, matches: [{ score: r2, value: e3, norm: s2, indices: c2 }] });
          }), n2;
        }
        _searchLogical(e2) {
          const t2 = $e(e2, this.options), i2 = (e3, t3, n3) => {
            if (!e3.children) {
              const { keyId: i3, searcher: s4 } = e3, o2 = this._findMatches({ key: this._keyStore.get(i3), value: this._myIndex.getValueForItemAtKeyId(t3, i3), searcher: s4 });
              return o2 && o2.length ? [{ idx: n3, item: t3, matches: o2 }] : [];
            }
            const s3 = [];
            for (let o2 = 0, r2 = e3.children.length; o2 < r2; o2 += 1) {
              const r3 = i2(e3.children[o2], t3, n3);
              if (r3.length) s3.push(...r3);
              else if (e3.operator === Ke) return [];
            }
            return s3;
          }, n2 = {}, s2 = [];
          return this._myIndex.records.forEach(({ $: e3, i: o2 }) => {
            if (le(e3)) {
              let r2 = i2(t2, e3, o2);
              r2.length && (n2[o2] || (n2[o2] = { idx: o2, item: e3, matches: [] }, s2.push(n2[o2])), r2.forEach(({ matches: e4 }) => {
                n2[o2].matches.push(...e4);
              }));
            }
          }), s2;
        }
        _searchObjectList(e2) {
          const t2 = Re(e2, this.options), { keys: i2, records: n2 } = this._myIndex, s2 = [];
          return n2.forEach(({ $: e3, i: n3 }) => {
            if (!le(e3)) return;
            let o2 = [];
            i2.forEach((i3, n4) => {
              o2.push(...this._findMatches({ key: i3, value: e3[n4], searcher: t2 }));
            }), o2.length && s2.push({ idx: n3, item: e3, matches: o2 });
          }), s2;
        }
        _findMatches({ key: e2, value: t2, searcher: i2 }) {
          if (!le(t2)) return [];
          let n2 = [];
          if (re(t2)) t2.forEach(({ v: t3, i: s2, n: o2 }) => {
            if (!le(t3)) return;
            const { isMatch: r2, score: c2, indices: a2 } = i2.searchIn(t3);
            r2 && n2.push({ score: c2, key: e2, value: t3, idx: s2, norm: o2, indices: a2 });
          });
          else {
            const { v: s2, n: o2 } = t2, { isMatch: r2, score: c2, indices: a2 } = i2.searchIn(s2);
            r2 && n2.push({ score: c2, key: e2, value: s2, norm: o2, indices: a2 });
          }
          return n2;
        }
      }
      Ue.version = "7.0.0", Ue.createIndex = we, Ue.parseIndex = function(e2, { getFn: t2 = Ee.getFn, fieldNormWeight: i2 = Ee.fieldNormWeight } = {}) {
        const { keys: n2, records: s2 } = e2, o2 = new Se({ getFn: t2, fieldNormWeight: i2 });
        return o2.setKeys(n2), o2.setIndexRecords(s2), o2;
      }, Ue.config = Ee, Ue.parseQuery = $e, function(...e2) {
        je.push(...e2);
      }(class {
        constructor(e2, { isCaseSensitive: t2 = Ee.isCaseSensitive, includeMatches: i2 = Ee.includeMatches, minMatchCharLength: n2 = Ee.minMatchCharLength, ignoreLocation: s2 = Ee.ignoreLocation, findAllMatches: o2 = Ee.findAllMatches, location: r2 = Ee.location, threshold: c2 = Ee.threshold, distance: a2 = Ee.distance } = {}) {
          this.query = null, this.options = { isCaseSensitive: t2, includeMatches: i2, minMatchCharLength: n2, findAllMatches: o2, ignoreLocation: s2, location: r2, threshold: c2, distance: a2 }, this.pattern = t2 ? e2 : e2.toLowerCase(), this.query = function(e3, t3 = {}) {
            return e3.split("|").map((e4) => {
              let i3 = e4.trim().split(De).filter((e5) => e5 && !!e5.trim()), n3 = [];
              for (let e5 = 0, s3 = i3.length; e5 < s3; e5 += 1) {
                const s4 = i3[e5];
                let o3 = false, r3 = -1;
                for (; !o3 && ++r3 < Fe; ) {
                  const e6 = ke[r3];
                  let i4 = e6.isMultiMatch(s4);
                  i4 && (n3.push(new e6(i4, t3)), o3 = true);
                }
                if (!o3) for (r3 = -1; ++r3 < Fe; ) {
                  const e6 = ke[r3];
                  let i4 = e6.isSingleMatch(s4);
                  if (i4) {
                    n3.push(new e6(i4, t3));
                    break;
                  }
                }
              }
              return n3;
            });
          }(this.pattern, this.options);
        }
        static condition(e2, t2) {
          return t2.useExtendedSearch;
        }
        searchIn(e2) {
          const t2 = this.query;
          if (!t2) return { isMatch: false, score: 1 };
          const { includeMatches: i2, isCaseSensitive: n2 } = this.options;
          e2 = n2 ? e2 : e2.toLowerCase();
          let s2 = 0, o2 = [], r2 = 0;
          for (let n3 = 0, c2 = t2.length; n3 < c2; n3 += 1) {
            const c3 = t2[n3];
            o2.length = 0, s2 = 0;
            for (let t3 = 0, n4 = c3.length; t3 < n4; t3 += 1) {
              const n5 = c3[t3], { isMatch: a2, indices: h2, score: l2 } = n5.search(e2);
              if (!a2) {
                r2 = 0, s2 = 0, o2.length = 0;
                break;
              }
              s2 += 1, r2 += l2, i2 && (Pe.has(n5.constructor.type) ? o2 = [...o2, ...h2] : o2.push(h2));
            }
            if (s2) {
              let e3 = { isMatch: true, score: r2 / s2 };
              return i2 && (e3.indices = o2), e3;
            }
          }
          return { isMatch: false, score: 1 };
        }
      });
      var Ge = function() {
        function e2(e3) {
          this._haystack = [], this._fuseOptions = i(i({}, e3.fuseOptions), { keys: n([], e3.searchFields, true), includeMatches: true });
        }
        return e2.prototype.index = function(e3) {
          this._haystack = e3, this._fuse && this._fuse.setCollection(e3);
        }, e2.prototype.reset = function() {
          this._haystack = [], this._fuse = void 0;
        }, e2.prototype.isEmptyIndex = function() {
          return !this._haystack.length;
        }, e2.prototype.search = function(e3) {
          return this._fuse || (this._fuse = new Ue(this._haystack, this._fuseOptions)), this._fuse.search(e3).map(function(e4, t2) {
            return { item: e4.item, score: e4.score || 0, rank: t2 + 1 };
          });
        }, e2;
      }(), ze = function(e2, t2, i2) {
        var n2 = e2.dataset, s2 = t2.customProperties, o2 = t2.labelClass, r2 = t2.labelDescription;
        o2 && (n2.labelClass = F(o2).join(" ")), r2 && (n2.labelDescription = r2), i2 && s2 && ("string" == typeof s2 ? n2.customProperties = s2 : "object" != typeof s2 || function(e3) {
          for (var t3 in e3) if (Object.prototype.hasOwnProperty.call(e3, t3)) return false;
          return true;
        }(s2) || (n2.customProperties = JSON.stringify(s2)));
      }, Je = function(e2, t2, i2) {
        var n2 = t2 && e2.querySelector("label[for='".concat(t2, "']")), s2 = n2 && n2.innerText;
        s2 && i2.setAttribute("aria-label", s2);
      }, Xe = { containerOuter: function(e2, t2, i2, n2, s2, o2, r2) {
        var c2 = e2.classNames.containerOuter, a2 = document.createElement("div");
        return P(a2, c2), a2.dataset.type = o2, t2 && (a2.dir = t2), n2 && (a2.tabIndex = 0), i2 && (a2.setAttribute("role", s2 ? "combobox" : "listbox"), s2 ? a2.setAttribute("aria-autocomplete", "list") : r2 || Je(this._docRoot, this.passedElement.element.id, a2), a2.setAttribute("aria-haspopup", "true"), a2.setAttribute("aria-expanded", "false")), r2 && a2.setAttribute("aria-labelledby", r2), a2;
      }, containerInner: function(e2) {
        var t2 = e2.classNames.containerInner, i2 = document.createElement("div");
        return P(i2, t2), i2;
      }, itemList: function(e2, t2) {
        var i2 = e2.searchEnabled, n2 = e2.classNames, s2 = n2.list, o2 = n2.listSingle, r2 = n2.listItems, c2 = document.createElement("div");
        return P(c2, s2), P(c2, t2 ? o2 : r2), this._isSelectElement && i2 && c2.setAttribute("role", "listbox"), c2;
      }, placeholder: function(e2, t2) {
        var i2 = e2.allowHTML, n2 = e2.classNames.placeholder, s2 = document.createElement("div");
        return P(s2, n2), N(s2, i2, t2), s2;
      }, item: function(e2, t2, i2) {
        var n2 = e2.allowHTML, s2 = e2.removeItemButtonAlignLeft, o2 = e2.removeItemIconText, r2 = e2.removeItemLabelText, c2 = e2.classNames, a2 = c2.item, h2 = c2.button, l2 = c2.highlightedState, u2 = c2.itemSelectable, d2 = c2.placeholder, p2 = L(t2.value), f2 = document.createElement("div");
        if (P(f2, a2), t2.labelClass) {
          var m2 = document.createElement("span");
          N(m2, n2, t2.label), P(m2, t2.labelClass), f2.appendChild(m2);
        } else N(f2, n2, t2.label);
        if (f2.dataset.item = "", f2.dataset.id = t2.id, f2.dataset.value = p2, ze(f2, t2, true), (t2.disabled || this.containerOuter.isDisabled) && f2.setAttribute("aria-disabled", "true"), this._isSelectElement && (f2.setAttribute("aria-selected", "true"), f2.setAttribute("role", "option")), t2.placeholder && (P(f2, d2), f2.dataset.placeholder = ""), P(f2, t2.highlighted ? l2 : u2), i2) {
          t2.disabled && j(f2, u2), f2.dataset.deletable = "";
          var g2 = document.createElement("button");
          g2.type = "button", P(g2, h2), N(g2, true, x(o2, t2.value));
          var v2 = x(r2, t2.value);
          v2 && g2.setAttribute("aria-label", v2), g2.dataset.button = "", s2 ? f2.insertAdjacentElement("afterbegin", g2) : f2.appendChild(g2);
        }
        return f2;
      }, choiceList: function(e2, t2) {
        var i2 = e2.classNames.list, n2 = document.createElement("div");
        return P(n2, i2), t2 || n2.setAttribute("aria-multiselectable", "true"), n2.setAttribute("role", "listbox"), n2;
      }, choiceGroup: function(e2, t2) {
        var i2 = e2.allowHTML, n2 = e2.classNames, s2 = n2.group, o2 = n2.groupHeading, r2 = n2.itemDisabled, c2 = t2.id, a2 = t2.label, h2 = t2.disabled, l2 = L(a2), u2 = document.createElement("div");
        P(u2, s2), h2 && P(u2, r2), u2.setAttribute("role", "group"), u2.dataset.group = "", u2.dataset.id = c2, u2.dataset.value = l2, h2 && u2.setAttribute("aria-disabled", "true");
        var d2 = document.createElement("div");
        return P(d2, o2), N(d2, i2, a2 || ""), u2.appendChild(d2), u2;
      }, choice: function(e2, t2, i2, n2) {
        var s2 = e2.allowHTML, o2 = e2.classNames, r2 = o2.item, c2 = o2.itemChoice, a2 = o2.itemSelectable, h2 = o2.selectedState, l2 = o2.itemDisabled, u2 = o2.description, d2 = o2.placeholder, p2 = t2.label, f2 = L(t2.value), m2 = document.createElement("div");
        m2.id = t2.elementId, P(m2, r2), P(m2, c2), n2 && "string" == typeof p2 && (p2 = T(s2, p2), p2 = { trusted: p2 += " (".concat(n2, ")") });
        var g2 = m2;
        if (t2.labelClass) {
          var v2 = document.createElement("span");
          N(v2, s2, p2), P(v2, t2.labelClass), g2 = v2, m2.appendChild(v2);
        } else N(m2, s2, p2);
        if (t2.labelDescription) {
          var _2 = "".concat(t2.elementId, "-description");
          g2.setAttribute("aria-describedby", _2);
          var y2 = document.createElement("span");
          N(y2, s2, t2.labelDescription), y2.id = _2, P(y2, u2), m2.appendChild(y2);
        }
        return t2.selected && P(m2, h2), t2.placeholder && P(m2, d2), m2.setAttribute("role", t2.group ? "treeitem" : "option"), m2.dataset.choice = "", m2.dataset.id = t2.id, m2.dataset.value = f2, i2 && (m2.dataset.selectText = i2), t2.group && (m2.dataset.groupId = "".concat(t2.group.id)), ze(m2, t2, false), t2.disabled ? (P(m2, l2), m2.dataset.choiceDisabled = "", m2.setAttribute("aria-disabled", "true")) : (P(m2, a2), m2.dataset.choiceSelectable = ""), m2;
      }, input: function(e2, t2) {
        var i2 = e2.classNames, n2 = i2.input, s2 = i2.inputCloned, o2 = e2.labelId, r2 = document.createElement("input");
        return r2.type = "search", P(r2, n2), P(r2, s2), r2.autocomplete = "off", r2.autocapitalize = "off", r2.spellcheck = false, r2.setAttribute("aria-autocomplete", "list"), t2 ? r2.setAttribute("aria-label", t2) : o2 || Je(this._docRoot, this.passedElement.element.id, r2), r2;
      }, dropdown: function(e2) {
        var t2 = e2.classNames, i2 = t2.list, n2 = t2.listDropdown, s2 = document.createElement("div");
        return P(s2, i2), P(s2, n2), s2.setAttribute("aria-expanded", "false"), s2;
      }, notice: function(e2, t2, i2) {
        var n2 = e2.classNames, s2 = n2.item, o2 = n2.itemChoice, r2 = n2.addChoice, c2 = n2.noResults, a2 = n2.noChoices, h2 = n2.notice;
        void 0 === i2 && (i2 = "");
        var l2 = document.createElement("div");
        switch (N(l2, true, t2), P(l2, s2), P(l2, o2), P(l2, h2), i2) {
          case ie:
            P(l2, r2);
            break;
          case te:
            P(l2, c2);
            break;
          case ee:
            P(l2, a2);
        }
        return i2 === ie && (l2.dataset.choiceSelectable = "", l2.dataset.choice = ""), l2;
      }, option: function(e2) {
        var t2 = L(e2.label), i2 = new Option(t2, e2.value, false, e2.selected);
        return ze(i2, e2, true), i2.disabled = e2.disabled, e2.selected && i2.setAttribute("selected", ""), i2;
      } }, Qe = "-ms-scroll-limit" in document.documentElement.style && "-ms-ime-align" in document.documentElement.style, Ye = {}, Ze = function(e2) {
        if (e2) return e2.dataset.id ? parseInt(e2.dataset.id, 10) : void 0;
      }, et = "[data-choice-selectable]";
      return function() {
        function e2(t2, n2) {
          void 0 === t2 && (t2 = "[data-choice]"), void 0 === n2 && (n2 = {});
          var s2 = this;
          this.initialisedOK = void 0, this._hasNonChoicePlaceholder = false, this._lastAddedChoiceId = 0, this._lastAddedGroupId = 0;
          var o2 = e2.defaults;
          this.config = i(i(i({}, o2.allOptions), o2.options), n2), v.forEach(function(e3) {
            s2.config[e3] = i(i(i({}, o2.allOptions[e3]), o2.options[e3]), n2[e3]);
          });
          var r2 = this.config;
          r2.silent || this._validateConfig();
          var c2 = r2.shadowRoot || document.documentElement;
          this._docRoot = c2;
          var a2 = "string" == typeof t2 ? c2.querySelector(t2) : t2;
          if (!a2 || "object" != typeof a2 || "INPUT" !== a2.tagName && !z(a2)) {
            if (!a2 && "string" == typeof t2) throw TypeError("Selector ".concat(t2, " failed to find an element"));
            throw TypeError("Expected one of the following types text|select-one|select-multiple");
          }
          var h2 = a2.type, l2 = "text" === h2;
          (l2 || 1 !== r2.maxItemCount) && (r2.singleModeForMultiSelect = false), r2.singleModeForMultiSelect && (h2 = y);
          var u2 = h2 === _, d2 = h2 === y, p2 = u2 || d2;
          if (this._elementType = h2, this._isTextElement = l2, this._isSelectOneElement = u2, this._isSelectMultipleElement = d2, this._isSelectElement = u2 || d2, this._canAddUserChoices = l2 && r2.addItems || p2 && r2.addChoices, "boolean" != typeof r2.renderSelectedChoices && (r2.renderSelectedChoices = "always" === r2.renderSelectedChoices || u2), r2.closeDropdownOnSelect = "auto" === r2.closeDropdownOnSelect ? l2 || u2 || r2.singleModeForMultiSelect : W(r2.closeDropdownOnSelect), r2.placeholder && (r2.placeholderValue ? this._hasNonChoicePlaceholder = true : a2.dataset.placeholder && (this._hasNonChoicePlaceholder = true, r2.placeholderValue = a2.dataset.placeholder)), n2.addItemFilter && "function" != typeof n2.addItemFilter) {
            var f2 = n2.addItemFilter instanceof RegExp ? n2.addItemFilter : new RegExp(n2.addItemFilter);
            r2.addItemFilter = f2.test.bind(f2);
          }
          if (this.passedElement = this._isTextElement ? new q({ element: a2, classNames: r2.classNames }) : new J({ element: a2, classNames: r2.classNames, template: function(e3) {
            return s2._templates.option(e3);
          }, extractPlaceholder: r2.placeholder && !this._hasNonChoicePlaceholder }), this.initialised = false, this._store = new Z(r2), this._currentValue = "", r2.searchEnabled = !l2 && r2.searchEnabled || d2, this._canSearch = r2.searchEnabled, this._isScrollingOnIe = false, this._highlightPosition = 0, this._wasTap = true, this._placeholderValue = this._generatePlaceholderValue(), this._baseId = function(e3) {
            var t3 = e3.id || e3.name && "".concat(e3.name, "-").concat(w(2)) || w(4);
            return t3 = t3.replace(/(:|\.|\[|\]|,)/g, ""), "".concat("choices-", "-").concat(t3);
          }(a2), this._direction = a2.dir, !this._direction) {
            var m2 = window.getComputedStyle(a2).direction;
            m2 !== window.getComputedStyle(document.documentElement).direction && (this._direction = m2);
          }
          if (this._idNames = { itemChoice: "item-choice" }, this._templates = o2.templates, this._render = this._render.bind(this), this._onFocus = this._onFocus.bind(this), this._onBlur = this._onBlur.bind(this), this._onKeyUp = this._onKeyUp.bind(this), this._onKeyDown = this._onKeyDown.bind(this), this._onInput = this._onInput.bind(this), this._onClick = this._onClick.bind(this), this._onTouchMove = this._onTouchMove.bind(this), this._onTouchEnd = this._onTouchEnd.bind(this), this._onMouseDown = this._onMouseDown.bind(this), this._onMouseOver = this._onMouseOver.bind(this), this._onFormReset = this._onFormReset.bind(this), this._onSelectKey = this._onSelectKey.bind(this), this._onEnterKey = this._onEnterKey.bind(this), this._onEscapeKey = this._onEscapeKey.bind(this), this._onDirectionKey = this._onDirectionKey.bind(this), this._onDeleteKey = this._onDeleteKey.bind(this), this.passedElement.isActive) return r2.silent || console.warn("Trying to initialise Choices on element already initialised", { element: t2 }), this.initialised = true, void (this.initialisedOK = false);
          this.init(), this._initialItems = this._store.items.map(function(e3) {
            return e3.value;
          });
        }
        return Object.defineProperty(e2, "defaults", { get: function() {
          return Object.preventExtensions({ get options() {
            return Ye;
          }, get allOptions() {
            return X;
          }, get templates() {
            return Xe;
          } });
        }, enumerable: false, configurable: true }), e2.prototype.init = function() {
          if (!this.initialised && void 0 === this.initialisedOK) {
            this._searcher = new Ge(this.config), this._loadChoices(), this._createTemplates(), this._createElements(), this._createStructure(), this._isTextElement && !this.config.addItems || this.passedElement.element.hasAttribute("disabled") || this.passedElement.element.closest("fieldset:disabled") ? this.disable() : (this.enable(), this._addEventListeners()), this._initStore(), this.initialised = true, this.initialisedOK = true;
            var e3 = this.config.callbackOnInit;
            "function" == typeof e3 && e3.call(this);
          }
        }, e2.prototype.destroy = function() {
          this.initialised && (this._removeEventListeners(), this.passedElement.reveal(), this.containerOuter.unwrap(this.passedElement.element), this._store._listeners = [], this.clearStore(false), this._stopSearch(), this._templates = e2.defaults.templates, this.initialised = false, this.initialisedOK = void 0);
        }, e2.prototype.enable = function() {
          return this.passedElement.isDisabled && this.passedElement.enable(), this.containerOuter.isDisabled && (this._addEventListeners(), this.input.enable(), this.containerOuter.enable()), this;
        }, e2.prototype.disable = function() {
          return this.passedElement.isDisabled || this.passedElement.disable(), this.containerOuter.isDisabled || (this._removeEventListeners(), this.input.disable(), this.containerOuter.disable()), this;
        }, e2.prototype.highlightItem = function(e3, t2) {
          if (void 0 === t2 && (t2 = true), !e3 || !e3.id) return this;
          var i2 = this._store.items.find(function(t3) {
            return t3.id === e3.id;
          });
          return !i2 || i2.highlighted || (this._store.dispatch(S(i2, true)), t2 && this.passedElement.triggerEvent(g, this._getChoiceForOutput(i2))), this;
        }, e2.prototype.unhighlightItem = function(e3, t2) {
          if (void 0 === t2 && (t2 = true), !e3 || !e3.id) return this;
          var i2 = this._store.items.find(function(t3) {
            return t3.id === e3.id;
          });
          return i2 && i2.highlighted ? (this._store.dispatch(S(i2, false)), t2 && this.passedElement.triggerEvent("unhighlightItem", this._getChoiceForOutput(i2)), this) : this;
        }, e2.prototype.highlightAll = function() {
          var e3 = this;
          return this._store.withTxn(function() {
            e3._store.items.forEach(function(t2) {
              t2.highlighted || (e3._store.dispatch(S(t2, true)), e3.passedElement.triggerEvent(g, e3._getChoiceForOutput(t2)));
            });
          }), this;
        }, e2.prototype.unhighlightAll = function() {
          var e3 = this;
          return this._store.withTxn(function() {
            e3._store.items.forEach(function(t2) {
              t2.highlighted && (e3._store.dispatch(S(t2, false)), e3.passedElement.triggerEvent(g, e3._getChoiceForOutput(t2)));
            });
          }), this;
        }, e2.prototype.removeActiveItemsByValue = function(e3) {
          var t2 = this;
          return this._store.withTxn(function() {
            t2._store.items.filter(function(t3) {
              return t3.value === e3;
            }).forEach(function(e4) {
              return t2._removeItem(e4);
            });
          }), this;
        }, e2.prototype.removeActiveItems = function(e3) {
          var t2 = this;
          return this._store.withTxn(function() {
            t2._store.items.filter(function(t3) {
              return t3.id !== e3;
            }).forEach(function(e4) {
              return t2._removeItem(e4);
            });
          }), this;
        }, e2.prototype.removeHighlightedItems = function(e3) {
          var t2 = this;
          return void 0 === e3 && (e3 = false), this._store.withTxn(function() {
            t2._store.highlightedActiveItems.forEach(function(i2) {
              t2._removeItem(i2), e3 && t2._triggerChange(i2.value);
            });
          }), this;
        }, e2.prototype.showDropdown = function(e3) {
          var t2 = this;
          return this.dropdown.isActive || (void 0 === e3 && (e3 = !this._canSearch), requestAnimationFrame(function() {
            t2.dropdown.show();
            var i2 = t2.dropdown.element.getBoundingClientRect();
            t2.containerOuter.open(i2.bottom, i2.height), e3 || t2.input.focus(), t2.passedElement.triggerEvent("showDropdown");
          })), this;
        }, e2.prototype.hideDropdown = function(e3) {
          var t2 = this;
          return this.dropdown.isActive ? (requestAnimationFrame(function() {
            t2.dropdown.hide(), t2.containerOuter.close(), !e3 && t2._canSearch && (t2.input.removeActiveDescendant(), t2.input.blur()), t2.passedElement.triggerEvent("hideDropdown");
          }), this) : this;
        }, e2.prototype.getValue = function(e3) {
          var t2 = this, i2 = this._store.items.map(function(i3) {
            return e3 ? i3.value : t2._getChoiceForOutput(i3);
          });
          return this._isSelectOneElement || this.config.singleModeForMultiSelect ? i2[0] : i2;
        }, e2.prototype.setValue = function(e3) {
          var t2 = this;
          return this.initialisedOK ? (this._store.withTxn(function() {
            e3.forEach(function(e4) {
              e4 && t2._addChoice(G(e4, false));
            });
          }), this._searcher.reset(), this) : (this._warnChoicesInitFailed("setValue"), this);
        }, e2.prototype.setChoiceByValue = function(e3) {
          var t2 = this;
          return this.initialisedOK ? (this._isTextElement || (this._store.withTxn(function() {
            (Array.isArray(e3) ? e3 : [e3]).forEach(function(e4) {
              return t2._findAndSelectChoiceByValue(e4);
            }), t2.unhighlightAll();
          }), this._searcher.reset()), this) : (this._warnChoicesInitFailed("setChoiceByValue"), this);
        }, e2.prototype.setChoices = function(e3, t2, n2, s2, o2, r2) {
          var c2 = this;
          if (void 0 === e3 && (e3 = []), void 0 === t2 && (t2 = "value"), void 0 === n2 && (n2 = "label"), void 0 === s2 && (s2 = false), void 0 === o2 && (o2 = true), void 0 === r2 && (r2 = false), !this.initialisedOK) return this._warnChoicesInitFailed("setChoices"), this;
          if (!this._isSelectElement) throw new TypeError("setChoices can't be used with INPUT based Choices");
          if ("string" != typeof t2 || !t2) throw new TypeError("value parameter must be a name of 'value' field in passed objects");
          if ("function" == typeof e3) {
            var a2 = e3(this);
            if ("function" == typeof Promise && a2 instanceof Promise) return new Promise(function(e4) {
              return requestAnimationFrame(e4);
            }).then(function() {
              return c2._handleLoadingState(true);
            }).then(function() {
              return a2;
            }).then(function(e4) {
              return c2.setChoices(e4, t2, n2, s2, o2, r2);
            }).catch(function(e4) {
              c2.config.silent || console.error(e4);
            }).then(function() {
              return c2._handleLoadingState(false);
            }).then(function() {
              return c2;
            });
            if (!Array.isArray(a2)) throw new TypeError(".setChoices first argument function must return either array of choices or Promise, got: ".concat(typeof a2));
            return this.setChoices(a2, t2, n2, false);
          }
          if (!Array.isArray(e3)) throw new TypeError(".setChoices must be called either with array of choices with a function resulting into Promise of array of choices");
          return this.containerOuter.removeLoadingState(), this._store.withTxn(function() {
            o2 && (c2._isSearching = false), s2 && c2.clearChoices(true, r2);
            var a3 = "value" === t2, h2 = "label" === n2;
            e3.forEach(function(e4) {
              if ("choices" in e4) {
                var s3 = e4;
                h2 || (s3 = i(i({}, s3), { label: s3[n2] })), c2._addGroup(G(s3, true));
              } else {
                var o3 = e4;
                h2 && a3 || (o3 = i(i({}, o3), { value: o3[t2], label: o3[n2] }));
                var r3 = G(o3, false);
                c2._addChoice(r3), r3.placeholder && !c2._hasNonChoicePlaceholder && (c2._placeholderValue = M(r3.label));
              }
            }), c2.unhighlightAll();
          }), this._searcher.reset(), this;
        }, e2.prototype.refresh = function(e3, t2, i2) {
          var n2 = this;
          return void 0 === e3 && (e3 = false), void 0 === t2 && (t2 = false), void 0 === i2 && (i2 = false), this._isSelectElement ? (this._store.withTxn(function() {
            var s2 = n2.passedElement.optionsAsChoices(), o2 = {};
            i2 || n2._store.items.forEach(function(e4) {
              e4.id && e4.active && e4.selected && (o2[e4.value] = true);
            }), n2.clearStore(false);
            var r2 = function(e4) {
              i2 ? n2._store.dispatch(C(e4)) : o2[e4.value] && (e4.selected = true);
            };
            s2.forEach(function(e4) {
              "choices" in e4 ? e4.choices.forEach(r2) : r2(e4);
            }), n2._addPredefinedChoices(s2, t2, e3), n2._isSearching && n2._searchChoices(n2.input.value);
          }), this) : (this.config.silent || console.warn("refresh method can only be used on choices backed by a <select> element"), this);
        }, e2.prototype.removeChoice = function(e3) {
          var t2 = this._store.choices.find(function(t3) {
            return t3.value === e3;
          });
          return t2 ? (this._clearNotice(), this._store.dispatch(/* @__PURE__ */ function(e4) {
            return { type: r, choice: e4 };
          }(t2)), this._searcher.reset(), t2.selected && this.passedElement.triggerEvent(m, this._getChoiceForOutput(t2)), this) : this;
        }, e2.prototype.clearChoices = function(e3, t2) {
          var i2 = this;
          return void 0 === e3 && (e3 = true), void 0 === t2 && (t2 = false), e3 && (t2 ? this.passedElement.element.replaceChildren("") : this.passedElement.element.querySelectorAll(":not([selected])").forEach(function(e4) {
            e4.remove();
          })), this.itemList.element.replaceChildren(""), this.choiceList.element.replaceChildren(""), this._clearNotice(), this._store.withTxn(function() {
            var e4 = t2 ? [] : i2._store.items;
            i2._store.reset(), e4.forEach(function(e5) {
              i2._store.dispatch(b(e5)), i2._store.dispatch(E(e5));
            });
          }), this._searcher.reset(), this;
        }, e2.prototype.clearStore = function(e3) {
          return void 0 === e3 && (e3 = true), this.clearChoices(e3, true), this._stopSearch(), this._lastAddedChoiceId = 0, this._lastAddedGroupId = 0, this;
        }, e2.prototype.clearInput = function() {
          return this.input.clear(!this._isSelectOneElement), this._stopSearch(), this;
        }, e2.prototype._validateConfig = function() {
          var e3, t2, i2, n2 = this.config, s2 = (e3 = X, t2 = Object.keys(n2).sort(), i2 = Object.keys(e3).sort(), t2.filter(function(e4) {
            return i2.indexOf(e4) < 0;
          }));
          s2.length && console.warn("Unknown config option(s) passed", s2.join(", ")), n2.allowHTML && n2.allowHtmlUserInput && (n2.addItems && console.warn("Warning: allowHTML/allowHtmlUserInput/addItems all being true is strongly not recommended and may lead to XSS attacks"), n2.addChoices && console.warn("Warning: allowHTML/allowHtmlUserInput/addChoices all being true is strongly not recommended and may lead to XSS attacks"));
        }, e2.prototype._render = function(e3) {
          void 0 === e3 && (e3 = { choices: true, groups: true, items: true }), this._store.inTxn() || (this._isSelectElement && (e3.choices || e3.groups) && this._renderChoices(), e3.items && this._renderItems());
        }, e2.prototype._renderChoices = function() {
          var e3 = this;
          if (this._canAddItems()) {
            var t2 = this.config, i2 = this._isSearching, n2 = this._store, s2 = n2.activeGroups, o2 = n2.activeChoices, r2 = 0;
            if (i2 && t2.searchResultLimit > 0 ? r2 = t2.searchResultLimit : t2.renderChoiceLimit > 0 && (r2 = t2.renderChoiceLimit), this._isSelectElement) {
              var c2 = o2.filter(function(e4) {
                return !e4.element;
              });
              c2.length && this.passedElement.addOptions(c2);
            }
            var a2 = document.createDocumentFragment(), h2 = function(e4) {
              return e4.filter(function(e5) {
                return !e5.placeholder && (i2 ? !!e5.rank : t2.renderSelectedChoices || !e5.selected);
              });
            }, l2 = false, u2 = function(n3, s3, o3) {
              i2 ? n3.sort(k) : t2.shouldSort && n3.sort(t2.sorter);
              var c3 = n3.length;
              c3 = !s3 && r2 && c3 > r2 ? r2 : c3, c3--, n3.every(function(n4, s4) {
                var r3 = n4.choiceEl || e3._templates.choice(t2, n4, t2.itemSelectText, o3);
                return n4.choiceEl = r3, a2.appendChild(r3), !i2 && n4.selected || (l2 = true), s4 < c3;
              });
            };
            o2.length && (t2.resetScrollPosition && requestAnimationFrame(function() {
              return e3.choiceList.scrollToTop();
            }), this._hasNonChoicePlaceholder || i2 || !this._isSelectOneElement || u2(o2.filter(function(e4) {
              return e4.placeholder && !e4.group;
            }), false, void 0), s2.length && !i2 ? (t2.shouldSort && s2.sort(t2.sorter), u2(o2.filter(function(e4) {
              return !e4.placeholder && !e4.group;
            }), false, void 0), s2.forEach(function(n3) {
              var s3 = h2(n3.choices);
              if (s3.length) {
                if (n3.label) {
                  var o3 = n3.groupEl || e3._templates.choiceGroup(e3.config, n3);
                  n3.groupEl = o3, o3.remove(), a2.appendChild(o3);
                }
                u2(s3, true, t2.appendGroupInSearch && i2 ? n3.label : void 0);
              }
            })) : u2(h2(o2), false, void 0)), l2 || !i2 && a2.children.length && t2.renderSelectedChoices || (this._notice || (this._notice = { text: O(i2 ? t2.noResultsText : t2.noChoicesText), type: i2 ? te : ee }), a2.replaceChildren("")), this._renderNotice(a2), this.choiceList.element.replaceChildren(a2), l2 && this._highlightChoice();
          }
        }, e2.prototype._renderItems = function() {
          var e3 = this, t2 = this._store.items || [], i2 = this.itemList.element, n2 = this.config, s2 = document.createDocumentFragment(), o2 = function(e4) {
            return i2.querySelector('[data-item][data-id="'.concat(e4.id, '"]'));
          }, r2 = function(t3) {
            var i3 = t3.itemEl;
            i3 && i3.parentElement || (i3 = o2(t3) || e3._templates.item(n2, t3, n2.removeItemButton), t3.itemEl = i3, s2.appendChild(i3));
          };
          t2.forEach(r2);
          var c2 = !!s2.childNodes.length;
          if (this._isSelectOneElement) {
            var a2 = i2.children.length;
            if (c2 || a2 > 1) {
              var h2 = i2.querySelector(D(n2.classNames.placeholder));
              h2 && h2.remove();
            } else c2 || a2 || !this._placeholderValue || (c2 = true, r2(G({ selected: true, value: "", label: this._placeholderValue, placeholder: true }, false)));
          }
          c2 && (i2.append(s2), n2.shouldSortItems && !this._isSelectOneElement && (t2.sort(n2.sorter), t2.forEach(function(e4) {
            var t3 = o2(e4);
            t3 && (t3.remove(), s2.append(t3));
          }), i2.append(s2))), this._isTextElement && (this.passedElement.value = t2.map(function(e4) {
            return e4.value;
          }).join(n2.delimiter));
        }, e2.prototype._displayNotice = function(e3, t2, i2) {
          void 0 === i2 && (i2 = true);
          var n2 = this._notice;
          n2 && (n2.type === t2 && n2.text === e3 || n2.type === ie && (t2 === te || t2 === ee)) ? i2 && this.showDropdown(true) : (this._clearNotice(), this._notice = e3 ? { text: e3, type: t2 } : void 0, this._renderNotice(), i2 && e3 && this.showDropdown(true));
        }, e2.prototype._clearNotice = function() {
          if (this._notice) {
            var e3 = this.choiceList.element.querySelector(D(this.config.classNames.notice));
            e3 && e3.remove(), this._notice = void 0;
          }
        }, e2.prototype._renderNotice = function(e3) {
          var t2 = this._notice;
          if (t2) {
            var i2 = this._templates.notice(this.config, t2.text, t2.type);
            e3 ? e3.append(i2) : this.choiceList.prepend(i2);
          }
        }, e2.prototype._getChoiceForOutput = function(e3, t2) {
          return { id: e3.id, highlighted: e3.highlighted, labelClass: e3.labelClass, labelDescription: e3.labelDescription, customProperties: e3.customProperties, disabled: e3.disabled, active: e3.active, label: e3.label, placeholder: e3.placeholder, value: e3.value, groupValue: e3.group ? e3.group.label : void 0, element: e3.element, keyCode: t2 };
        }, e2.prototype._triggerChange = function(e3) {
          null != e3 && this.passedElement.triggerEvent("change", { value: e3 });
        }, e2.prototype._handleButtonAction = function(e3) {
          var t2 = this, i2 = this._store.items;
          if (i2.length && this.config.removeItems && this.config.removeItemButton) {
            var n2 = e3 && Ze(e3.parentElement), s2 = n2 && i2.find(function(e4) {
              return e4.id === n2;
            });
            s2 && this._store.withTxn(function() {
              if (t2._removeItem(s2), t2._triggerChange(s2.value), t2._isSelectOneElement && !t2._hasNonChoicePlaceholder) {
                var e4 = (t2.config.shouldSort ? t2._store.choices.reverse() : t2._store.choices).find(function(e5) {
                  return e5.placeholder;
                });
                e4 && (t2._addItem(e4), t2.unhighlightAll(), e4.value && t2._triggerChange(e4.value));
              }
            });
          }
        }, e2.prototype._handleItemAction = function(e3, t2) {
          var i2 = this;
          void 0 === t2 && (t2 = false);
          var n2 = this._store.items;
          if (n2.length && this.config.removeItems && !this._isSelectOneElement) {
            var s2 = Ze(e3);
            s2 && (n2.forEach(function(e4) {
              e4.id !== s2 || e4.highlighted ? !t2 && e4.highlighted && i2.unhighlightItem(e4) : i2.highlightItem(e4);
            }), this.input.focus());
          }
        }, e2.prototype._handleChoiceAction = function(e3) {
          var t2 = this, i2 = Ze(e3), n2 = i2 && this._store.getChoiceById(i2);
          if (!n2 || n2.disabled) return false;
          var s2 = this.dropdown.isActive;
          if (!n2.selected) {
            if (!this._canAddItems()) return true;
            this._store.withTxn(function() {
              t2._addItem(n2, true, true), t2.clearInput(), t2.unhighlightAll();
            }), this._triggerChange(n2.value);
          }
          return s2 && this.config.closeDropdownOnSelect && (this.hideDropdown(true), this.containerOuter.element.focus()), true;
        }, e2.prototype._handleBackspace = function(e3) {
          var t2 = this.config;
          if (t2.removeItems && e3.length) {
            var i2 = e3[e3.length - 1], n2 = e3.some(function(e4) {
              return e4.highlighted;
            });
            t2.editItems && !n2 && i2 ? (this.input.value = i2.value, this.input.setWidth(), this._removeItem(i2), this._triggerChange(i2.value)) : (n2 || this.highlightItem(i2, false), this.removeHighlightedItems(true));
          }
        }, e2.prototype._loadChoices = function() {
          var e3, t2 = this, i2 = this.config;
          if (this._isTextElement) {
            if (this._presetChoices = i2.items.map(function(e4) {
              return G(e4, false);
            }), this.passedElement.value) {
              var n2 = this.passedElement.value.split(i2.delimiter).map(function(e4) {
                return G(e4, false, t2.config.allowHtmlUserInput);
              });
              this._presetChoices = this._presetChoices.concat(n2);
            }
            this._presetChoices.forEach(function(e4) {
              e4.selected = true;
            });
          } else if (this._isSelectElement) {
            this._presetChoices = i2.choices.map(function(e4) {
              return G(e4, true);
            });
            var s2 = this.passedElement.optionsAsChoices();
            s2 && (e3 = this._presetChoices).push.apply(e3, s2);
          }
        }, e2.prototype._handleLoadingState = function(e3) {
          void 0 === e3 && (e3 = true);
          var t2 = this.itemList.element;
          e3 ? (this.disable(), this.containerOuter.addLoadingState(), this._isSelectOneElement ? t2.replaceChildren(this._templates.placeholder(this.config, this.config.loadingText)) : this.input.placeholder = this.config.loadingText) : (this.enable(), this.containerOuter.removeLoadingState(), this._isSelectOneElement ? (t2.replaceChildren(""), this._render()) : this.input.placeholder = this._placeholderValue || "");
        }, e2.prototype._handleSearch = function(e3) {
          if (this.input.isFocussed) if (null != e3 && e3.length >= this.config.searchFloor) {
            var t2 = this.config.searchChoices ? this._searchChoices(e3) : 0;
            null !== t2 && this.passedElement.triggerEvent(f, { value: e3, resultCount: t2 });
          } else this._store.choices.some(function(e4) {
            return !e4.active;
          }) && this._stopSearch();
        }, e2.prototype._canAddItems = function() {
          var e3 = this.config, t2 = e3.maxItemCount, i2 = e3.maxItemText;
          return !e3.singleModeForMultiSelect && t2 > 0 && t2 <= this._store.items.length ? (this.choiceList.element.replaceChildren(""), this._notice = void 0, this._displayNotice("function" == typeof i2 ? i2(t2) : i2, ie), false) : (this._notice && this._notice.type === ie && this._clearNotice(), true);
        }, e2.prototype._canCreateItem = function(e3) {
          var t2 = this.config, i2 = true, n2 = "";
          if (i2 && "function" == typeof t2.addItemFilter && !t2.addItemFilter(e3) && (i2 = false, n2 = x(t2.customAddItemText, e3)), i2 && this._store.choices.find(function(i3) {
            return t2.valueComparer(i3.value, e3);
          })) {
            if (this._isSelectElement) return this._displayNotice("", ie), false;
            t2.duplicateItemsAllowed || (i2 = false, n2 = x(t2.uniqueItemText, e3));
          }
          return i2 && (n2 = x(t2.addItemText, e3)), n2 && this._displayNotice(n2, ie), i2;
        }, e2.prototype._searchChoices = function(e3) {
          var t2 = e3.trim().replace(/\s{2,}/, " ");
          if (!t2.length || t2 === this._currentValue) return null;
          var i2 = this._searcher;
          i2.isEmptyIndex() && i2.index(this._store.searchableChoices);
          var n2 = i2.search(t2);
          this._currentValue = t2, this._highlightPosition = 0, this._isSearching = true;
          var s2 = this._notice;
          return (s2 && s2.type) !== ie && (n2.length ? this._clearNotice() : this._displayNotice(O(this.config.noResultsText), te)), this._store.dispatch(/* @__PURE__ */ function(e4) {
            return { type: c, results: e4 };
          }(n2)), n2.length;
        }, e2.prototype._stopSearch = function() {
          this._isSearching && (this._currentValue = "", this._isSearching = false, this._clearNotice(), this._store.dispatch({ type: a, active: true }), this.passedElement.triggerEvent(f, { value: "", resultCount: 0 }));
        }, e2.prototype._addEventListeners = function() {
          var e3 = this._docRoot, t2 = this.containerOuter.element, i2 = this.input.element;
          e3.addEventListener("touchend", this._onTouchEnd, true), t2.addEventListener("keydown", this._onKeyDown, true), t2.addEventListener("mousedown", this._onMouseDown, true), e3.addEventListener("click", this._onClick, { passive: true }), e3.addEventListener("touchmove", this._onTouchMove, { passive: true }), this.dropdown.element.addEventListener("mouseover", this._onMouseOver, { passive: true }), this._isSelectOneElement && (t2.addEventListener("focus", this._onFocus, { passive: true }), t2.addEventListener("blur", this._onBlur, { passive: true })), i2.addEventListener("keyup", this._onKeyUp, { passive: true }), i2.addEventListener("input", this._onInput, { passive: true }), i2.addEventListener("focus", this._onFocus, { passive: true }), i2.addEventListener("blur", this._onBlur, { passive: true }), i2.form && i2.form.addEventListener("reset", this._onFormReset, { passive: true }), this.input.addEventListeners();
        }, e2.prototype._removeEventListeners = function() {
          var e3 = this._docRoot, t2 = this.containerOuter.element, i2 = this.input.element;
          e3.removeEventListener("touchend", this._onTouchEnd, true), t2.removeEventListener("keydown", this._onKeyDown, true), t2.removeEventListener("mousedown", this._onMouseDown, true), e3.removeEventListener("click", this._onClick), e3.removeEventListener("touchmove", this._onTouchMove), this.dropdown.element.removeEventListener("mouseover", this._onMouseOver), this._isSelectOneElement && (t2.removeEventListener("focus", this._onFocus), t2.removeEventListener("blur", this._onBlur)), i2.removeEventListener("keyup", this._onKeyUp), i2.removeEventListener("input", this._onInput), i2.removeEventListener("focus", this._onFocus), i2.removeEventListener("blur", this._onBlur), i2.form && i2.form.removeEventListener("reset", this._onFormReset), this.input.removeEventListeners();
        }, e2.prototype._onKeyDown = function(e3) {
          var t2 = e3.keyCode, i2 = this.dropdown.isActive, n2 = 1 === e3.key.length || 2 === e3.key.length && e3.key.charCodeAt(0) >= 55296 || "Unidentified" === e3.key;
          switch (this._isTextElement || i2 || 27 === t2 || 9 === t2 || 16 === t2 || (this.showDropdown(), !this.input.isFocussed && n2 && (this.input.value += e3.key, " " === e3.key && e3.preventDefault())), t2) {
            case 65:
              return this._onSelectKey(e3, this.itemList.element.hasChildNodes());
            case 13:
              return this._onEnterKey(e3, i2);
            case 27:
              return this._onEscapeKey(e3, i2);
            case 38:
            case 33:
            case 40:
            case 34:
              return this._onDirectionKey(e3, i2);
            case 8:
            case 46:
              return this._onDeleteKey(e3, this._store.items, this.input.isFocussed);
          }
        }, e2.prototype._onKeyUp = function() {
          this._canSearch = this.config.searchEnabled;
        }, e2.prototype._onInput = function() {
          var e3 = this.input.value;
          e3 ? this._canAddItems() && (this._canSearch && this._handleSearch(e3), this._canAddUserChoices && (this._canCreateItem(e3), this._isSelectElement && (this._highlightPosition = 0, this._highlightChoice()))) : this._isTextElement ? this.hideDropdown(true) : this._stopSearch();
        }, e2.prototype._onSelectKey = function(e3, t2) {
          (e3.ctrlKey || e3.metaKey) && t2 && (this._canSearch = false, this.config.removeItems && !this.input.value && this.input.element === document.activeElement && this.highlightAll());
        }, e2.prototype._onEnterKey = function(e3, t2) {
          var i2 = this, n2 = this.input.value, s2 = e3.target;
          if (e3.preventDefault(), s2 && s2.hasAttribute("data-button")) this._handleButtonAction(s2);
          else if (t2) {
            var o2 = this.dropdown.element.querySelector(D(this.config.classNames.highlightedState));
            if (!o2 || !this._handleChoiceAction(o2)) if (s2 && n2) {
              if (this._canAddItems()) {
                var r2 = false;
                this._store.withTxn(function() {
                  if (!(r2 = i2._findAndSelectChoiceByValue(n2, true))) {
                    if (!i2._canAddUserChoices) return;
                    if (!i2._canCreateItem(n2)) return;
                    i2._addChoice(G(n2, false, i2.config.allowHtmlUserInput), true, true), r2 = true;
                  }
                  i2.clearInput(), i2.unhighlightAll();
                }), r2 && (this._triggerChange(n2), this.config.closeDropdownOnSelect && this.hideDropdown(true));
              }
            } else this.hideDropdown(true);
          } else (this._isSelectElement || this._notice) && this.showDropdown();
        }, e2.prototype._onEscapeKey = function(e3, t2) {
          t2 && (e3.stopPropagation(), this.hideDropdown(true), this._stopSearch(), this.containerOuter.element.focus());
        }, e2.prototype._onDirectionKey = function(e3, t2) {
          var i2, n2, s2, o2 = e3.keyCode;
          if (t2 || this._isSelectOneElement) {
            this.showDropdown(), this._canSearch = false;
            var r2 = 40 === o2 || 34 === o2 ? 1 : -1, c2 = void 0;
            if (e3.metaKey || 34 === o2 || 33 === o2) c2 = this.dropdown.element.querySelector(r2 > 0 ? "".concat(et, ":last-of-type") : et);
            else {
              var a2 = this.dropdown.element.querySelector(D(this.config.classNames.highlightedState));
              c2 = a2 ? function(e4, t3, i3) {
                void 0 === i3 && (i3 = 1);
                for (var n3 = "".concat(i3 > 0 ? "next" : "previous", "ElementSibling"), s3 = e4[n3]; s3; ) {
                  if (s3.matches(t3)) return s3;
                  s3 = s3[n3];
                }
                return null;
              }(a2, et, r2) : this.dropdown.element.querySelector(et);
            }
            c2 && (i2 = c2, n2 = this.choiceList.element, void 0 === (s2 = r2) && (s2 = 1), (s2 > 0 ? n2.scrollTop + n2.offsetHeight >= i2.offsetTop + i2.offsetHeight : i2.offsetTop >= n2.scrollTop) || this.choiceList.scrollToChildElement(c2, r2), this._highlightChoice(c2)), e3.preventDefault();
          }
        }, e2.prototype._onDeleteKey = function(e3, t2, i2) {
          this._isSelectOneElement || e3.target.value || !i2 || (this._handleBackspace(t2), e3.preventDefault());
        }, e2.prototype._onTouchMove = function() {
          this._wasTap && (this._wasTap = false);
        }, e2.prototype._onTouchEnd = function(e3) {
          var t2 = (e3 || e3.touches[0]).target;
          this._wasTap && this.containerOuter.element.contains(t2) && ((t2 === this.containerOuter.element || t2 === this.containerInner.element) && (this._isTextElement ? this.input.focus() : this._isSelectMultipleElement && this.showDropdown()), e3.stopPropagation()), this._wasTap = true;
        }, e2.prototype._onMouseDown = function(e3) {
          var t2 = e3.target;
          if (t2 instanceof HTMLElement) {
            if (Qe && this.choiceList.element.contains(t2)) {
              var i2 = this.choiceList.element.firstElementChild;
              this._isScrollingOnIe = "ltr" === this._direction ? e3.offsetX >= i2.offsetWidth : e3.offsetX < i2.offsetLeft;
            }
            if (t2 !== this.input.element) {
              var n2 = t2.closest("[data-button],[data-item],[data-choice]");
              n2 instanceof HTMLElement && ("button" in n2.dataset ? this._handleButtonAction(n2) : "item" in n2.dataset ? this._handleItemAction(n2, e3.shiftKey) : "choice" in n2.dataset && this._handleChoiceAction(n2)), e3.preventDefault();
            }
          }
        }, e2.prototype._onMouseOver = function(e3) {
          var t2 = e3.target;
          t2 instanceof HTMLElement && "choice" in t2.dataset && this._highlightChoice(t2);
        }, e2.prototype._onClick = function(e3) {
          var t2 = e3.target, i2 = this.containerOuter;
          i2.element.contains(t2) ? this.dropdown.isActive || i2.isDisabled ? this._isSelectOneElement && t2 !== this.input.element && !this.dropdown.element.contains(t2) && this.hideDropdown() : this._isTextElement ? document.activeElement !== this.input.element && this.input.focus() : (this.showDropdown(), i2.element.focus()) : (i2.removeFocusState(), this.hideDropdown(true), this.unhighlightAll());
        }, e2.prototype._onFocus = function(e3) {
          var t2 = e3.target, i2 = this.containerOuter;
          if (t2 && i2.element.contains(t2)) {
            var n2 = t2 === this.input.element;
            this._isTextElement ? n2 && i2.addFocusState() : this._isSelectMultipleElement ? n2 && (this.showDropdown(true), i2.addFocusState()) : (i2.addFocusState(), n2 && this.showDropdown(true));
          }
        }, e2.prototype._onBlur = function(e3) {
          var t2 = e3.target, i2 = this.containerOuter;
          t2 && i2.element.contains(t2) && !this._isScrollingOnIe ? t2 === this.input.element ? (i2.removeFocusState(), this.hideDropdown(true), (this._isTextElement || this._isSelectMultipleElement) && this.unhighlightAll()) : t2 === this.containerOuter.element && (i2.removeFocusState(), this._canSearch || this.hideDropdown(true)) : (this._isScrollingOnIe = false, this.input.element.focus());
        }, e2.prototype._onFormReset = function() {
          var e3 = this;
          this._store.withTxn(function() {
            e3.clearInput(), e3.hideDropdown(), e3.refresh(false, false, true), e3._initialItems.length && e3.setChoiceByValue(e3._initialItems);
          });
        }, e2.prototype._highlightChoice = function(e3) {
          void 0 === e3 && (e3 = null);
          var t2 = Array.from(this.dropdown.element.querySelectorAll(et));
          if (t2.length) {
            var i2 = e3, n2 = this.config.classNames.highlightedState;
            Array.from(this.dropdown.element.querySelectorAll(D(n2))).forEach(function(e4) {
              j(e4, n2), e4.setAttribute("aria-selected", "false");
            }), i2 ? this._highlightPosition = t2.indexOf(i2) : (i2 = t2.length > this._highlightPosition ? t2[this._highlightPosition] : t2[t2.length - 1]) || (i2 = t2[0]), P(i2, n2), i2.setAttribute("aria-selected", "true"), this.passedElement.triggerEvent("highlightChoice", { el: i2 }), this.dropdown.isActive && (this.input.setActiveDescendant(i2.id), this.containerOuter.setActiveDescendant(i2.id));
          }
        }, e2.prototype._addItem = function(e3, t2, i2) {
          if (void 0 === t2 && (t2 = true), void 0 === i2 && (i2 = false), !e3.id) throw new TypeError("item.id must be set before _addItem is called for a choice/item");
          (this.config.singleModeForMultiSelect || this._isSelectOneElement) && this.removeActiveItems(e3.id), this._store.dispatch(E(e3)), t2 && (this.passedElement.triggerEvent("addItem", this._getChoiceForOutput(e3)), i2 && this.passedElement.triggerEvent("choice", this._getChoiceForOutput(e3)));
        }, e2.prototype._removeItem = function(e3) {
          if (e3.id) {
            this._store.dispatch(C(e3));
            var t2 = this._notice;
            t2 && t2.type === ee && this._clearNotice(), this.passedElement.triggerEvent(m, this._getChoiceForOutput(e3));
          }
        }, e2.prototype._addChoice = function(e3, t2, i2) {
          if (void 0 === t2 && (t2 = true), void 0 === i2 && (i2 = false), e3.id) throw new TypeError("Can not re-add a choice which has already been added");
          var n2 = this.config;
          if (n2.duplicateItemsAllowed || !this._store.choices.find(function(t3) {
            return n2.valueComparer(t3.value, e3.value);
          })) {
            this._lastAddedChoiceId++, e3.id = this._lastAddedChoiceId, e3.elementId = "".concat(this._baseId, "-").concat(this._idNames.itemChoice, "-").concat(e3.id);
            var s2 = n2.prependValue, o2 = n2.appendValue;
            s2 && (e3.value = s2 + e3.value), o2 && (e3.value += o2.toString()), (s2 || o2) && e3.element && (e3.element.value = e3.value), this._clearNotice(), this._store.dispatch(b(e3)), e3.selected && this._addItem(e3, t2, i2);
          }
        }, e2.prototype._addGroup = function(e3, t2) {
          var i2 = this;
          if (void 0 === t2 && (t2 = true), e3.id) throw new TypeError("Can not re-add a group which has already been added");
          this._store.dispatch(/* @__PURE__ */ function(e4) {
            return { type: l, group: e4 };
          }(e3)), e3.choices && (this._lastAddedGroupId++, e3.id = this._lastAddedGroupId, e3.choices.forEach(function(n2) {
            n2.group = e3, e3.disabled && (n2.disabled = true), i2._addChoice(n2, t2);
          }));
        }, e2.prototype._createTemplates = function() {
          var e3 = this, t2 = this.config.callbackOnCreateTemplates, i2 = {};
          "function" == typeof t2 && (i2 = t2.call(this, A, T, F));
          var n2 = {};
          Object.keys(this._templates).forEach(function(t3) {
            n2[t3] = t3 in i2 ? i2[t3].bind(e3) : e3._templates[t3].bind(e3);
          }), this._templates = n2;
        }, e2.prototype._createElements = function() {
          var e3 = this._templates, t2 = this.config, i2 = this._isSelectOneElement, n2 = t2.position, s2 = t2.classNames, o2 = this._elementType;
          this.containerOuter = new V({ element: e3.containerOuter(t2, this._direction, this._isSelectElement, i2, t2.searchEnabled, o2, t2.labelId), classNames: s2, type: o2, position: n2 }), this.containerInner = new V({ element: e3.containerInner(t2), classNames: s2, type: o2, position: n2 }), this.input = new B({ element: e3.input(t2, this._placeholderValue), classNames: s2, type: o2, preventPaste: !t2.paste }), this.choiceList = new H({ element: e3.choiceList(t2, i2) }), this.itemList = new H({ element: e3.itemList(t2, i2) }), this.dropdown = new K({ element: e3.dropdown(t2), classNames: s2, type: o2 });
        }, e2.prototype._createStructure = function() {
          var e3 = this, t2 = e3.containerInner, i2 = e3.containerOuter, n2 = e3.passedElement, s2 = this.dropdown.element;
          n2.conceal(), t2.wrap(n2.element), i2.wrap(t2.element), this._isSelectOneElement ? this.input.placeholder = this.config.searchPlaceholderValue || "" : (this._placeholderValue && (this.input.placeholder = this._placeholderValue), this.input.setWidth()), i2.element.appendChild(t2.element), i2.element.appendChild(s2), t2.element.appendChild(this.itemList.element), s2.appendChild(this.choiceList.element), this._isSelectOneElement ? this.config.searchEnabled && s2.insertBefore(this.input.element, s2.firstChild) : t2.element.appendChild(this.input.element), this._highlightPosition = 0, this._isSearching = false;
        }, e2.prototype._initStore = function() {
          var e3 = this;
          this._store.subscribe(this._render).withTxn(function() {
            e3._addPredefinedChoices(e3._presetChoices, e3._isSelectOneElement && !e3._hasNonChoicePlaceholder, false);
          }), (!this._store.choices.length || this._isSelectOneElement && this._hasNonChoicePlaceholder) && this._render();
        }, e2.prototype._addPredefinedChoices = function(e3, t2, i2) {
          var n2 = this;
          void 0 === t2 && (t2 = false), void 0 === i2 && (i2 = true), t2 && -1 === e3.findIndex(function(e4) {
            return e4.selected;
          }) && e3.some(function(e4) {
            return !e4.disabled && !("choices" in e4) && (e4.selected = true, true);
          }), e3.forEach(function(e4) {
            "choices" in e4 ? n2._isSelectElement && n2._addGroup(e4, i2) : n2._addChoice(e4, i2);
          });
        }, e2.prototype._findAndSelectChoiceByValue = function(e3, t2) {
          var i2 = this;
          void 0 === t2 && (t2 = false);
          var n2 = this._store.choices.find(function(t3) {
            return i2.config.valueComparer(t3.value, e3);
          });
          return !(!n2 || n2.disabled || n2.selected || (this._addItem(n2, true, t2), 0));
        }, e2.prototype._generatePlaceholderValue = function() {
          var e3 = this.config;
          if (!e3.placeholder) return null;
          if (this._hasNonChoicePlaceholder) return e3.placeholderValue;
          if (this._isSelectElement) {
            var t2 = this.passedElement.placeholderOption;
            return t2 ? t2.text : null;
          }
          return null;
        }, e2.prototype._warnChoicesInitFailed = function(e3) {
          if (!this.config.silent) {
            if (!this.initialised) throw new TypeError("".concat(e3, " called on a non-initialised instance of Choices"));
            if (!this.initialisedOK) throw new TypeError("".concat(e3, " called for an element which has multiple instances of Choices initialised on it"));
          }
        }, e2.version = "11.1.0", e2;
      }();
    });
  }
});
export default require_choices_min();
/*! choices.js v11.1.0 | © 2025 Josh Johnson | https://github.com/jshjohnson/Choices#readme */
