/* BonitoDocumenter client behaviour: theme, sidebar, copy, highlight, outline, search */
(function () {
  // ---- theme (apply ASAP to avoid flash) ----
  function preferred() {
    var s = localStorage.getItem("docs-theme");
    if (s) return s;
    return window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
  }
  function applyTheme(t) {
    document.documentElement.classList.toggle("dark", t === "dark");
  }
  applyTheme(preferred());

  function onReady(fn) {
    if (document.readyState !== "loading") fn();
    else document.addEventListener("DOMContentLoaded", fn);
  }

  // ---- highlight.js (loaded lazily from CDN; degrades gracefully offline) ----
  var HLJS_VERSION = "11.9.0";
  var HLJS_BASE = "https://cdnjs.cloudflare.com/ajax/libs/highlight.js/" + HLJS_VERSION;
  function setHljsTheme() {
    var link = document.getElementById("hljs-theme");
    if (!link) return;
    var dark = document.documentElement.classList.contains("dark");
    link.href = HLJS_BASE + "/styles/" + (dark ? "github-dark" : "github") + ".min.css";
  }
  function loadHljs(cb) {
    if (window.hljs) { cb(); return; }
    var link = document.createElement("link");
    link.rel = "stylesheet";
    link.id = "hljs-theme";
    document.head.appendChild(link);
    setHljsTheme();
    var s = document.createElement("script");
    s.src = HLJS_BASE + "/highlight.min.js";
    s.onload = function () {
      // The cdnjs "common" build omits some languages (Julia included), so pull
      // in the extra grammars our docs use before highlighting.
      var langs = ["julia", "julia-repl", "toml", "bash", "python"];
      var remaining = langs.length;
      function done() { if (--remaining <= 0) cb(); }
      langs.forEach(function (lang) {
        var ls = document.createElement("script");
        ls.src = HLJS_BASE + "/languages/" + lang + ".min.js";
        ls.onload = done;
        ls.onerror = done;
        document.head.appendChild(ls);
      });
    };
    s.onerror = function () { /* offline: leave code unhighlighted */ };
    document.head.appendChild(s);
  }
  function highlightAll() {
    if (!window.hljs) return;
    document.querySelectorAll('div[class*="language-"] code').forEach(function (el) {
      if (el.dataset.highlighted) return;
      try { window.hljs.highlightElement(el); } catch (e) {}
    });
  }

  onReady(function () {
    // theme toggle
    document.querySelectorAll("[data-toggle-theme]").forEach(function (btn) {
      btn.addEventListener("click", function () {
        var dark = document.documentElement.classList.toggle("dark");
        localStorage.setItem("docs-theme", dark ? "dark" : "light");
        setHljsTheme();
      });
    });

    // sidebar toggle (mobile)
    var sb = document.querySelector(".VPSidebar");
    var bd = document.querySelector(".VPSidebar-backdrop");
    function closeSidebar() { sb && sb.classList.remove("open"); bd && bd.classList.remove("open"); }
    document.querySelectorAll("[data-toggle-sidebar]").forEach(function (b) {
      b.addEventListener("click", function () {
        sb && sb.classList.toggle("open");
        bd && bd.classList.toggle("open");
      });
    });
    bd && bd.addEventListener("click", closeSidebar);

    // version dropdown
    document.querySelectorAll(".VPVersion .trigger").forEach(function (t) {
      t.addEventListener("click", function (e) {
        e.stopPropagation();
        t.closest(".VPVersion").classList.toggle("open");
      });
    });
    document.addEventListener("click", function () {
      document.querySelectorAll(".VPVersion.open").forEach(function (v) { v.classList.remove("open"); });
    });

    // copy buttons
    document.querySelectorAll(".vp-doc .copy").forEach(function (btn) {
      btn.addEventListener("click", function () {
        var wrap = btn.closest('div[class*="language-"]');
        var code = wrap && wrap.querySelector("code");
        if (!code) return;
        navigator.clipboard.writeText(code.innerText).then(function () {
          btn.classList.add("copied");
          setTimeout(function () { btn.classList.remove("copied"); }, 1500);
        });
      });
    });

    loadHljs(highlightAll);
    initOutline();
    initSearch();
    initVersions();
    renderMath();
  });

  function initVersions() {
    var menu = document.querySelector(".VPVersion .menu");
    if (!menu) return;
    // `versions.js` is written by Documenter's `deploydocs` at the docs root and
    // defines `DOC_VERSIONS` (an array of version folder names).
    var versions = window.DOC_VERSIONS;
    if (!Array.isArray(versions) || !versions.length) return;
    menu.innerHTML = versions.map(function (v) {
      return '<a href="../' + v + '/">' + esc(v) + "</a>";
    }).join("");
  }

  function renderMath() {
    if (typeof window.renderMathInElement !== "function") return;
    try {
      window.renderMathInElement(document.querySelector(".vp-doc") || document.body, {
        delimiters: [
          { left: "\\[", right: "\\]", display: true },
          { left: "\\(", right: "\\)", display: false },
        ],
        throwOnError: false,
      });
    } catch (e) {}
  }

  function initOutline() {
    var links = Array.prototype.slice.call(document.querySelectorAll(".VPAside .outline a"));
    if (!links.length) return;
    var map = new Map();
    links.forEach(function (a) {
      var id = decodeURIComponent(a.getAttribute("href").slice(1));
      var el = document.getElementById(id);
      if (el) map.set(el, a);
    });
    var obs = new IntersectionObserver(function (entries) {
      entries.forEach(function (e) {
        if (e.isIntersecting) {
          links.forEach(function (l) { l.classList.remove("active"); });
          var a = map.get(e.target);
          a && a.classList.add("active");
        }
      });
    }, { rootMargin: "0px 0px -75% 0px" });
    map.forEach(function (a, el) { obs.observe(el); });
  }

  function esc(s) {
    return (s || "").replace(/[&<>]/g, function (c) {
      return { "&": "&amp;", "<": "&lt;", ">": "&gt;" }[c];
    });
  }

  function initSearch() {
    var data = window.__DOCS_SEARCH__ || [];
    var bd = document.querySelector(".VPSearch-backdrop");
    var input = document.querySelector(".VPSearch input");
    var results = document.querySelector(".VPSearch .results");
    if (!bd || !input || !results) return;
    var active = -1, items = [];

    function open() { bd.classList.add("open"); input.value = ""; render(""); setTimeout(function () { input.focus(); }, 0); }
    function close() { bd.classList.remove("open"); }

    function render(q) {
      q = q.trim().toLowerCase();
      var matches = q
        ? data.filter(function (d) {
            return d.title.toLowerCase().indexOf(q) >= 0 || d.text.toLowerCase().indexOf(q) >= 0;
          }).slice(0, 30)
        : data.slice(0, 8);
      items = matches;
      active = matches.length ? 0 : -1;
      if (!matches.length) { results.innerHTML = '<div class="empty">No results</div>'; return; }
      results.innerHTML = matches.map(function (m, i) {
        return '<a class="result ' + (i === 0 ? "active" : "") + '" href="' + m.url + '">' +
          '<div class="r-title">' + esc(m.title) + "</div>" +
          '<div class="r-context">' + esc(m.text.slice(0, 120)) + "</div></a>";
      }).join("");
    }

    input.addEventListener("input", function () { render(input.value); });
    input.addEventListener("keydown", function (e) {
      var els = Array.prototype.slice.call(results.querySelectorAll(".result"));
      if (e.key === "ArrowDown") { e.preventDefault(); active = Math.min(active + 1, els.length - 1); }
      else if (e.key === "ArrowUp") { e.preventDefault(); active = Math.max(active - 1, 0); }
      else if (e.key === "Enter") { if (items[active]) window.location.href = items[active].url; return; }
      else if (e.key === "Escape") { close(); return; }
      els.forEach(function (el, i) { el.classList.toggle("active", i === active); });
      els[active] && els[active].scrollIntoView({ block: "nearest" });
    });
    bd.addEventListener("click", function (e) { if (e.target === bd) close(); });
    document.querySelectorAll("[data-open-search]").forEach(function (b) { b.addEventListener("click", open); });
    document.addEventListener("keydown", function (e) {
      if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === "k") { e.preventDefault(); open(); }
    });
  }
})();
