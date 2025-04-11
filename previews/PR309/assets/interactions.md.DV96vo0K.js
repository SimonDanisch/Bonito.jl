import{_ as i,c as a,o as l,aA as n}from"./chunks/framework.CGxuVltW.js";const c=JSON.parse('{"title":"Interactions","description":"","frontmatter":{},"headers":[],"relativePath":"interactions.md","filePath":"interactions.md","lastUpdated":null}'),t={name:"interactions.md"};function h(k,s,e,p,d,r){return l(),a("div",null,s[0]||(s[0]=[n(`<h1 id="interactions" tabindex="-1">Interactions <a class="header-anchor" href="#interactions" aria-label="Permalink to &quot;Interactions&quot;">​</a></h1><p>Animations in Bonito are done via Observables.jl, much like it&#39;s the case for Makie.jl, so the same docs apply:</p><ul><li><p><a href="https://docs.makie.org/stable/documentation/nodes/index.html" target="_blank" rel="noreferrer">observables</a></p></li><li><p><a href="https://docs.makie.org/stable/documentation/animation/index.html" target="_blank" rel="noreferrer">animation</a></p></li></ul><p>But lets quickly get started with a Bonito specific example:</p><div class="language-julia vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang">julia</span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">App</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">() </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">do</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> session</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">    s </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> Slider</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">1</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">:</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">3</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">)</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">    value </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> map</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(s</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">value) </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">do</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> x</span></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">        return</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> x </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">^</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> 2</span></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">    end</span></span>
<span class="line"><span style="--shiki-light:#6A737D;--shiki-dark:#6A737D;">    # Record states is an experimental feature to record all states generated in the Julia session and allow the slider to stay interactive in the statically hosted docs!</span></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">    return</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> Bonito</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">record_states</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(session, DOM</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">div</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(s, value))</span></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">end</span></span></code></pre></div><div><div>
  <div class="bonito-fragment" id="0ae601f8-f5b2-4534-85f2-65cedf70c595" data-jscall-id="root">
    <div>
      <script src="bonito/js/Bonito.bundled15432232505923397289.js" type="module"><\/script>
      <style></style>
    </div>
    <div>
      <script type="module">Bonito.lock_loading(() => Bonito.init_session('0ae601f8-f5b2-4534-85f2-65cedf70c595', null, 'root', false))<\/script>
      <span></span>
    </div>
  </div>
  <div class="bonito-fragment" id="50097a8f-5719-4c28-b395-20a9f27e793e" data-jscall-id="subsession-application-dom">
    <div>
      <style></style>
    </div>
    <div>
      <script type="module">    Bonito.lock_loading(() => {
        return Bonito.fetch_binary('bonito/bin/3e2cefaeb8abcd39525687d6e8a1afb5ccd96642-1326466668084247773.bin').then(msgs=> Bonito.init_session('50097a8f-5719-4c28-b395-20a9f27e793e', msgs, 'sub', false));
    })
<\/script>
      <div data-jscall-id="1">
        <input step="1" max="3" min="1" style="styles" data-jscall-id="2" value="1" oninput="" type="range" />
        <span data-jscall-id="3">1</span>
      </div>
    </div>
  </div>
</div></div><p>The <code>s.value</code> is an <code>Observable</code> which can be <code>mapp&#39;ed</code> to take on new values, and one can insert observables as an input to <code>DOM.tag</code> or as any attribute. The value of the <code>observable</code> will be rendered via <code>jssrender(session, observable[])</code>, and then updated whenever the value changes. So anything that supports being inserted into the <code>DOM</code> can be inside an observable, and the fallback is to use the display system (so plots etc. work as well). This way, one can also return <code>DOM</code> elements as the result of an observable:</p><div class="language-julia vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang">julia</span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">App</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">() </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">do</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> session</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">    s </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> Slider</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">1</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">:</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">3</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">)</span></span>
<span class="line"><span style="--shiki-light:#6A737D;--shiki-dark:#6A737D;">    # use map!(result_observable, ...)</span></span>
<span class="line"><span style="--shiki-light:#6A737D;--shiki-dark:#6A737D;">    # To use any as the result type, otherwise you can&#39;t return</span></span>
<span class="line"><span style="--shiki-light:#6A737D;--shiki-dark:#6A737D;">    # different types from the map callback</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">    value </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> map!</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">Observable{Any}</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(), s</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">value) </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">do</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> x</span></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">        if</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> x </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">==</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> 1</span></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">            return</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> DOM</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">h1</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;hello from slider: </span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">$(x)</span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">)</span></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">        elseif</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> x </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">==</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> 2</span></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">            return</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> DOM</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">img</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(src</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;https://docs.makie.org/stable/logo.svg&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">, width</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;200px&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">)</span></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">        else</span></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">            return</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> x</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">^</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">2</span></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">        end</span></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">    end</span></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">    return</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> Bonito</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">record_states</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(session, DOM</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">div</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(s, value))</span></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">end</span></span></code></pre></div><div><div class="bonito-fragment" id="e96f76c4-8f12-4f1d-933a-9fe090f0918d" data-jscall-id="subsession-application-dom">
  <div>
    <style></style>
  </div>
  <div>
    <script type="module">    Bonito.lock_loading(() => {
        return Bonito.fetch_binary('bonito/bin/adfb027b48e40436900d1adff0e07392f5dc64da-6456747924043939103.bin').then(msgs=> Bonito.init_session('e96f76c4-8f12-4f1d-933a-9fe090f0918d', msgs, 'sub', false));
    })
<\/script>
    <div data-jscall-id="4">
      <input step="1" max="3" min="1" style="styles" data-jscall-id="5" value="1" oninput="" type="range" />
      <span data-jscall-id="7">
        <div class="bonito-fragment" id="cbcb966f-2c78-4cc9-8d80-1d420bd229fc" data-jscall-id="subsession-application-dom">
          <div data-jscall-id="8">
            <style data-jscall-id="9"></style>
          </div>
          <div data-jscall-id="10">
            <script data-jscall-id="11" type="module">Bonito.lock_loading(() => Bonito.init_session('cbcb966f-2c78-4cc9-8d80-1d420bd229fc', null, 'sub', false))<\/script>
            <h1 data-jscall-id="6">hello from slider: 1</h1>
          </div>
        </div>
      </span>
    </div>
  </div>
</div></div><p>In other words, the whole app can just be one big observable:</p><div class="language-julia vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang">julia</span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">import</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> Bonito</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">TailwindDashboard </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">as</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> D</span></span>
<span class="line"><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">App</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">() </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">do</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> session</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">    s </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> D</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">Slider</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;Slider: &quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">, </span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">1</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">:</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">3</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">)</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">    checkbox </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> D</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">Checkbox</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;Chose:&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">, </span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">true</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">)</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">    menu </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> D</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">Dropdown</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;Menu: &quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">, [sin, tan, cos])</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">    app </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> map</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(checkbox</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">widget</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">value, s</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">widget</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">value, menu</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">widget</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">value) </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">do</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> checkboxval, sliderval, menuval</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">        DOM</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">div</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(checkboxval, sliderval, menuval)</span></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">    end</span></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">    return</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> Bonito</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">record_states</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(session, D</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">FlexRow</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">        D</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">Card</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(D</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">FlexCol</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(checkbox, s, menu)),</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">        D</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">Card</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(app)</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">    ))</span></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">end</span></span></code></pre></div><div><div class="bonito-fragment" id="e955dc85-20be-4d30-9d6d-63fd867b1b87" data-jscall-id="subsession-application-dom">
  <div>
    <style>.style_2 {
  min-width: 8rem;
  font-weight: 600;
  padding-right: 0.75rem;
  border-color: #9CA3AF;
  padding-bottom: 0.25rem;
  box-shadow: rgba(0, 0, 0, 0) 0px 0px 0px 0px, rgba(0, 0, 0, 0) 0px 0px 0px 0px, rgba(0, 0, 0, 0.1) 0px 1px 3px 0px, rgba(0, 0, 0, 0.1) 0px 1px 2px -1px;
  border-radius: 0.25rem;
  font-size: 1rem;
  background-color: white;
  border-width: 1px;
  padding-left: 0.75rem;
  padding-top: 0.25rem;
  cursor: pointer;
  margin: 0.25rem;
}
.style_3:focus {
  outline-offset: 1px;
  box-shadow: rgba(66, 153, 225, 0.5) 0px 0px 0px 1px;
  outline: 1px solid transparent;
}
.style_4 {
  min-width: auto;
  font-weight: 600;
  padding-right: 0.75rem;
  border-color: #9CA3AF;
  padding-bottom: 0.25rem;
  box-shadow: rgba(0, 0, 0, 0) 0px 0px 0px 0px, rgba(0, 0, 0, 0) 0px 0px 0px 0px, rgba(0, 0, 0, 0.1) 0px 1px 3px 0px, rgba(0, 0, 0, 0.1) 0px 1px 2px -1px;
  border-radius: 0.25rem;
  font-size: 1rem;
  background-color: white;
  border-width: 1px;
  padding-left: 0.75rem;
  padding-top: 0.25rem;
  cursor: pointer;
  margin: 0.25rem;
  transform: scale(1.5);
}
.style_5:hover {
  background-color: #F9FAFB;
  box-shadow: rgba(0, 0, 0, 0) 0px 0px 0px 0px, rgba(0, 0, 0, 0) 0px 0px 0px 0px, rgba(0, 0, 0, 0.1) 0px 1px 3px 0px, rgba(0, 0, 0, 0.1) 0px 1px 2px -1px;
}
</style>
    <link href="bonito/css/tailwind.min8774971868340764599.css" rel="stylesheet" type="text/css" />
  </div>
  <div>
    <script type="module">    Bonito.lock_loading(() => {
        return Bonito.fetch_binary('bonito/bin/5bb5e09ad7a24cecfe2b09fd090df6b0e7ca9ff2-2082815445715808928.bin').then(msgs=> Bonito.init_session('e955dc85-20be-4d30-9d6d-63fd867b1b87', msgs, 'sub', false));
    })
<\/script>
    <div class="mx-2 flex flex-row " data-jscall-id="12">
      <div class="rounded-md p-2 m-2 shadow " style="width: fit-content; height: fit-content; " data-jscall-id="13">
        <div class="my-2 flex flex-col " data-jscall-id="14">
          <div class="flex-row, mb-1 mt-1 " data-jscall-id="15">
            <h2 class="font-semibold " data-jscall-id="16">Chose:</h2>
            <input checked="true" style="" data-jscall-id="17" onchange="" type="checkbox" />
          </div>
          <div class="flex-row, mb-1 mt-1 " data-jscall-id="18">
            <h2 class="font-semibold " data-jscall-id="19">
              <div data-jscall-id="20">Slider: 
                <div class="float-right text-right text w-32" data-jscall-id="21">
                  <span data-jscall-id="22">1</span>
                </div>
              </div>
            </h2>
            <input step="1" max="3" min="1" style="width: 100%;" data-jscall-id="23" value="1" oninput="" type="range" />
          </div>
          <div class="flex-row, mb-1 mt-1 " data-jscall-id="24">
            <h2 class="font-semibold " data-jscall-id="25">Menu: </h2>
            <select class=" focus:outline-none focus:shadow-outline focus:border-blue-300 bg-white bg-gray-100 hover:bg-white text-gray-800 font-semibold m-1 py-1 px-3 border border-gray-400 rounded shadow" style="" data-jscall-id="26">
              <option data-jscall-id="27">sin</option>
              <option data-jscall-id="28">tan</option>
              <option data-jscall-id="29">cos</option>
            </select>
          </div>
        </div>
      </div>
      <div class="rounded-md p-2 m-2 shadow " style="width: fit-content; height: fit-content; " data-jscall-id="30">
        <span data-jscall-id="32">
          <div class="bonito-fragment" id="f1c9212b-5315-437f-864f-3a7e1f7c0116" data-jscall-id="subsession-application-dom">
            <div data-jscall-id="33">
              <style data-jscall-id="34"></style>
            </div>
            <div data-jscall-id="35">
              <script data-jscall-id="36" type="module">Bonito.lock_loading(() => Bonito.init_session('f1c9212b-5315-437f-864f-3a7e1f7c0116', null, 'sub', false))<\/script>
              <div data-jscall-id="31">true1
                <p data-jscall-id="37">sin &#40;generic function with 14 methods&#41;</p>
              </div>
            </div>
          </div>
        </span>
      </div>
    </div>
  </div>
</div></div><p>Likes this one create interactive examples like this:</p><div class="language-julia vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang">julia</span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">import</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> Bonito</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">TailwindDashboard </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">as</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> D</span></span>
<span class="line"></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">function</span><span style="--shiki-light:#6F42C1;--shiki-dark:#B392F0;"> create_svg</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(sl_nsamples, sl_sample_step, sl_phase, sl_radii, color)</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">    width, height </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> 900</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">, </span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">300</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">    cxs_unscaled </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> [i</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">*</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">sl_sample_step </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">+</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> sl_phase </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">for</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> i </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">in</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> 1</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">:</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">sl_nsamples]</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">    cys </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> sin</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">.(cxs_unscaled) </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.*</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> height</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">/</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">3</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;"> .+</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> height</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">/</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">2</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">    cxs </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> cxs_unscaled </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.*</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> width</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">/</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">4pi</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">    rr </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> sl_radii</span></span>
<span class="line"><span style="--shiki-light:#6A737D;--shiki-dark:#6A737D;">    # DOM.div/svg/etc is just a convenience in Bonito for using Hyperscript, but circle isn&#39;t wrapped like that yet</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">    geom </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> [SVG</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">circle</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(cx</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">cxs[i], cy</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">cys[i], r</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">rr, fill</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">color</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(i)) </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">for</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> i </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">in</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> 1</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">:</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">sl_nsamples[]]</span></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">    return</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> SVG</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">svg</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(SVG</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">g</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(geom</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">...</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">);</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">        width</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">width, height</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">height</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">    )</span></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">end</span></span>
<span class="line"></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">app </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> App</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">() </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">do</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> session</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">    colors </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> [</span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;black&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">, </span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;gray&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">, </span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;silver&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">, </span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;maroon&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">, </span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;red&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">, </span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;olive&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">, </span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;yellow&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">, </span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;green&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">, </span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;lime&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">, </span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;teal&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">, </span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;aqua&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">, </span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;navy&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">, </span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;blue&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">, </span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;purple&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">, </span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;fuchsia&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">]</span></span>
<span class="line"><span style="--shiki-light:#6F42C1;--shiki-dark:#B392F0;">    color</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(i) </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> colors[i</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">%</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">length</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(colors)</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">+</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">1</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">]</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">    sl_nsamples </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> D</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">Slider</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;nsamples&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">, </span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">1</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">:</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">200</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">, value</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">100</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">)</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">    sl_sample_step </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> D</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">Slider</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;sample step&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">, </span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">0.01</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">:</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">0.01</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">:</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">1.0</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">, value</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">0.1</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">)</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">    sl_phase </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> D</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">Slider</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;phase&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">, </span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">0.0</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">:</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">0.1</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">:</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">6.0</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">, value</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">0.0</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">)</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">    sl_radii </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> D</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">Slider</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;radii&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">, </span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">0.1</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">:</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">0.1</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">:</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">60</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">, value</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">10.0</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">)</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">    svg </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> map</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(create_svg, sl_nsamples</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">value, sl_sample_step</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">value, sl_phase</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">value, sl_radii</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">value, color)</span></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">    return</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> DOM</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">div</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(D</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">FlexRow</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(D</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">FlexCol</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(sl_nsamples, sl_sample_step, sl_phase, sl_radii), svg))</span></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">end</span></span></code></pre></div><div><div class="bonito-fragment" id="292c8888-c6ea-404a-bec6-4da447f4f94a" data-jscall-id="subsession-application-dom">
  <div>
    <style></style>
    <link href="bonito/css/tailwind.min8774971868340764599.css" rel="stylesheet" type="text/css" />
  </div>
  <div>
    <script type="module">    Bonito.lock_loading(() => {
        return Bonito.fetch_binary('bonito/bin/c51b9143dadd5ea27044ccb1e231a27340695fad-7841532894766677665.bin').then(msgs=> Bonito.init_session('292c8888-c6ea-404a-bec6-4da447f4f94a', msgs, 'sub', false));
    })
<\/script>
    <div data-jscall-id="398">
      <div class="mx-2 flex flex-row " data-jscall-id="399">
        <div class="my-2 flex flex-col " data-jscall-id="400">
          <div class="flex-row, mb-1 mt-1 " data-jscall-id="401">
            <h2 class="font-semibold " data-jscall-id="402">
              <div data-jscall-id="403">nsamples
                <div class="float-right text-right text w-32" data-jscall-id="404">
                  <span data-jscall-id="405">100</span>
                </div>
              </div>
            </h2>
            <input step="1" max="200" min="1" style="width: 100%;" data-jscall-id="406" value="100" oninput="" type="range" />
          </div>
          <div class="flex-row, mb-1 mt-1 " data-jscall-id="407">
            <h2 class="font-semibold " data-jscall-id="408">
              <div data-jscall-id="409">sample step
                <div class="float-right text-right text w-32" data-jscall-id="410">
                  <span data-jscall-id="411">0.1</span>
                </div>
              </div>
            </h2>
            <input step="1" max="100" min="1" style="width: 100%;" data-jscall-id="412" value="10" oninput="" type="range" />
          </div>
          <div class="flex-row, mb-1 mt-1 " data-jscall-id="413">
            <h2 class="font-semibold " data-jscall-id="414">
              <div data-jscall-id="415">phase
                <div class="float-right text-right text w-32" data-jscall-id="416">
                  <span data-jscall-id="417">0.0</span>
                </div>
              </div>
            </h2>
            <input step="1" max="61" min="1" style="width: 100%;" data-jscall-id="418" value="1" oninput="" type="range" />
          </div>
          <div class="flex-row, mb-1 mt-1 " data-jscall-id="419">
            <h2 class="font-semibold " data-jscall-id="420">
              <div data-jscall-id="421">radii
                <div class="float-right text-right text w-32" data-jscall-id="422">
                  <span data-jscall-id="423">10.0</span>
                </div>
              </div>
            </h2>
            <input step="1" max="600" min="1" style="width: 100%;" data-jscall-id="424" value="100" oninput="" type="range" />
          </div>
        </div>
        <span data-jscall-id="527">
          <div class="bonito-fragment" id="61760d85-bb0e-4024-bc08-bd39ba2b3dc1" data-jscall-id="subsession-application-dom">
            <div data-jscall-id="528">
              <style data-jscall-id="529"></style>
            </div>
            <div data-jscall-id="530">
              <script data-jscall-id="531" type="module">Bonito.lock_loading(() => Bonito.init_session('61760d85-bb0e-4024-bc08-bd39ba2b3dc1', null, 'sub', false))<\/script>
              <svg height="300" juliasvgnode="true" data-jscall-id="425" width="900">
                <g juliasvgnode="true" data-jscall-id="426">
                  <circle cy="159.98334166468283" juliasvgnode="true" data-jscall-id="427" r="10.0" fill="gray" cx="7.16197243913529" />
                  <circle cy="169.8669330795061" juliasvgnode="true" data-jscall-id="428" r="10.0" fill="silver" cx="14.32394487827058" />
                  <circle cy="179.55202066613396" juliasvgnode="true" data-jscall-id="429" r="10.0" fill="maroon" cx="21.485917317405875" />
                  <circle cy="188.94183423086506" juliasvgnode="true" data-jscall-id="430" r="10.0" fill="red" cx="28.64788975654116" />
                  <circle cy="197.9425538604203" juliasvgnode="true" data-jscall-id="431" r="10.0" fill="olive" cx="35.80986219567645" />
                  <circle cy="206.46424733950354" juliasvgnode="true" data-jscall-id="432" r="10.0" fill="yellow" cx="42.97183463481175" />
                  <circle cy="214.4217687237691" juliasvgnode="true" data-jscall-id="433" r="10.0" fill="green" cx="50.13380707394704" />
                  <circle cy="221.73560908995228" juliasvgnode="true" data-jscall-id="434" r="10.0" fill="lime" cx="57.29577951308232" />
                  <circle cy="228.33269096274836" juliasvgnode="true" data-jscall-id="435" r="10.0" fill="teal" cx="64.45775195221762" />
                  <circle cy="234.14709848078965" juliasvgnode="true" data-jscall-id="436" r="10.0" fill="aqua" cx="71.6197243913529" />
                  <circle cy="239.12073600614355" juliasvgnode="true" data-jscall-id="437" r="10.0" fill="navy" cx="78.7816968304882" />
                  <circle cy="243.2039085967226" juliasvgnode="true" data-jscall-id="438" r="10.0" fill="blue" cx="85.9436692696235" />
                  <circle cy="246.35581854171932" juliasvgnode="true" data-jscall-id="439" r="10.0" fill="purple" cx="93.10564170875878" />
                  <circle cy="248.54497299884605" juliasvgnode="true" data-jscall-id="440" r="10.0" fill="fuchsia" cx="100.26761414789408" />
                  <circle cy="249.74949866040544" juliasvgnode="true" data-jscall-id="441" r="10.0" fill="black" cx="107.42958658702936" />
                  <circle cy="249.95736030415048" juliasvgnode="true" data-jscall-id="442" r="10.0" fill="gray" cx="114.59155902616465" />
                  <circle cy="249.16648104524688" juliasvgnode="true" data-jscall-id="443" r="10.0" fill="silver" cx="121.75353146529996" />
                  <circle cy="247.38476308781952" juliasvgnode="true" data-jscall-id="444" r="10.0" fill="maroon" cx="128.91550390443524" />
                  <circle cy="244.63000876874145" juliasvgnode="true" data-jscall-id="445" r="10.0" fill="red" cx="136.07747634357054" />
                  <circle cy="240.9297426825682" juliasvgnode="true" data-jscall-id="446" r="10.0" fill="olive" cx="143.2394487827058" />
                  <circle cy="236.32093666488737" juliasvgnode="true" data-jscall-id="447" r="10.0" fill="yellow" cx="150.4014212218411" />
                  <circle cy="230.849640381959" juliasvgnode="true" data-jscall-id="448" r="10.0" fill="green" cx="157.5633936609764" />
                  <circle cy="224.57052121767202" juliasvgnode="true" data-jscall-id="449" r="10.0" fill="lime" cx="164.72536610011173" />
                  <circle cy="217.54631805511508" juliasvgnode="true" data-jscall-id="450" r="10.0" fill="teal" cx="171.887338539247" />
                  <circle cy="209.84721441039565" juliasvgnode="true" data-jscall-id="451" r="10.0" fill="aqua" cx="179.04931097838227" />
                  <circle cy="201.55013718214641" juliasvgnode="true" data-jscall-id="452" r="10.0" fill="navy" cx="186.21128341751756" />
                  <circle cy="192.73798802338297" juliasvgnode="true" data-jscall-id="453" r="10.0" fill="blue" cx="193.37325585665283" />
                  <circle cy="183.49881501559048" juliasvgnode="true" data-jscall-id="454" r="10.0" fill="purple" cx="200.53522829578816" />
                  <circle cy="173.9249329213982" juliasvgnode="true" data-jscall-id="455" r="10.0" fill="fuchsia" cx="207.69720073492346" />
                  <circle cy="164.11200080598672" juliasvgnode="true" data-jscall-id="456" r="10.0" fill="black" cx="214.85917317405872" />
                  <circle cy="154.15806624332905" juliasvgnode="true" data-jscall-id="457" r="10.0" fill="gray" cx="222.021145613194" />
                  <circle cy="144.162585657242" juliasvgnode="true" data-jscall-id="458" r="10.0" fill="silver" cx="229.1831180523293" />
                  <circle cy="134.22543058567513" juliasvgnode="true" data-jscall-id="459" r="10.0" fill="maroon" cx="236.34509049146462" />
                  <circle cy="124.44588979731684" juliasvgnode="true" data-jscall-id="460" r="10.0" fill="red" cx="243.50706293059991" />
                  <circle cy="114.92167723103802" juliasvgnode="true" data-jscall-id="461" r="10.0" fill="olive" cx="250.66903536973516" />
                  <circle cy="105.74795567051476" juliasvgnode="true" data-jscall-id="462" r="10.0" fill="yellow" cx="257.8310078088705" />
                  <circle cy="97.01638590915067" juliasvgnode="true" data-jscall-id="463" r="10.0" fill="green" cx="264.9929802480057" />
                  <circle cy="88.81421090572806" juliasvgnode="true" data-jscall-id="464" r="10.0" fill="lime" cx="272.1549526871411" />
                  <circle cy="81.22338408160259" juliasvgnode="true" data-jscall-id="465" r="10.0" fill="teal" cx="279.3169251262764" />
                  <circle cy="74.31975046920718" juliasvgnode="true" data-jscall-id="466" r="10.0" fill="aqua" cx="286.4788975654116" />
                  <circle cy="68.17228889355893" juliasvgnode="true" data-jscall-id="467" r="10.0" fill="navy" cx="293.64087000454697" />
                  <circle cy="62.84242275864118" juliasvgnode="true" data-jscall-id="468" r="10.0" fill="blue" cx="300.8028424436822" />
                  <circle cy="58.38340632505451" juliasvgnode="true" data-jscall-id="469" r="10.0" fill="purple" cx="307.9648148828175" />
                  <circle cy="54.83979261104838" juliasvgnode="true" data-jscall-id="470" r="10.0" fill="fuchsia" cx="315.1267873219528" />
                  <circle cy="52.2469882334903" juliasvgnode="true" data-jscall-id="471" r="10.0" fill="black" cx="322.28875976108804" />
                  <circle cy="50.63089963665355" juliasvgnode="true" data-jscall-id="472" r="10.0" fill="gray" cx="329.45073220022346" />
                  <circle cy="50.00767424358992" juliasvgnode="true" data-jscall-id="473" r="10.0" fill="silver" cx="336.61270463935864" />
                  <circle cy="50.383539116415946" juliasvgnode="true" data-jscall-id="474" r="10.0" fill="maroon" cx="343.774677078494" />
                  <circle cy="51.754738737566754" juliasvgnode="true" data-jscall-id="475" r="10.0" fill="red" cx="350.93664951762923" />
                  <circle cy="54.10757253368615" juliasvgnode="true" data-jscall-id="476" r="10.0" fill="olive" cx="358.09862195676453" />
                  <circle cy="57.418531767226796" juliasvgnode="true" data-jscall-id="477" r="10.0" fill="yellow" cx="365.2605943958999" />
                  <circle cy="61.654534427984686" juliasvgnode="true" data-jscall-id="478" r="10.0" fill="green" cx="372.4225668350351" />
                  <circle cy="66.77325577760992" juliasvgnode="true" data-jscall-id="479" r="10.0" fill="lime" cx="379.5845392741705" />
                  <circle cy="72.72355124440129" juliasvgnode="true" data-jscall-id="480" r="10.0" fill="teal" cx="386.74651171330567" />
                  <circle cy="79.44596744296081" juliasvgnode="true" data-jscall-id="481" r="10.0" fill="aqua" cx="393.90848415244096" />
                  <circle cy="86.87333621276792" juliasvgnode="true" data-jscall-id="482" r="10.0" fill="navy" cx="401.0704565915763" />
                  <circle cy="94.93144574023623" juliasvgnode="true" data-jscall-id="483" r="10.0" fill="blue" cx="408.23242903071156" />
                  <circle cy="103.53978205862435" juliasvgnode="true" data-jscall-id="484" r="10.0" fill="purple" cx="415.3944014698469" />
                  <circle cy="112.6123335169764" juliasvgnode="true" data-jscall-id="485" r="10.0" fill="fuchsia" cx="422.55637390898215" />
                  <circle cy="122.05845018010741" juliasvgnode="true" data-jscall-id="486" r="10.0" fill="black" cx="429.71834634811745" />
                  <circle cy="131.7837495727905" juliasvgnode="true" data-jscall-id="487" r="10.0" fill="gray" cx="436.8803187872528" />
                  <circle cy="141.69105971825036" juliasvgnode="true" data-jscall-id="488" r="10.0" fill="silver" cx="444.042291226388" />
                  <circle cy="151.68139004843505" juliasvgnode="true" data-jscall-id="489" r="10.0" fill="maroon" cx="451.20426366552334" />
                  <circle cy="161.65492048504936" juliasvgnode="true" data-jscall-id="490" r="10.0" fill="red" cx="458.3662361046586" />
                  <circle cy="171.51199880878156" juliasvgnode="true" data-jscall-id="491" r="10.0" fill="olive" cx="465.5282085437939" />
                  <circle cy="181.15413635133785" juliasvgnode="true" data-jscall-id="492" r="10.0" fill="yellow" cx="472.69018098292923" />
                  <circle cy="190.48499206165982" juliasvgnode="true" data-jscall-id="493" r="10.0" fill="green" cx="479.8521534220645" />
                  <circle cy="199.4113351138609" juliasvgnode="true" data-jscall-id="494" r="10.0" fill="lime" cx="487.01412586119983" />
                  <circle cy="207.84397643882002" juliasvgnode="true" data-jscall-id="495" r="10.0" fill="teal" cx="494.176098300335" />
                  <circle cy="215.6986598718789" juliasvgnode="true" data-jscall-id="496" r="10.0" fill="aqua" cx="501.3380707394703" />
                  <circle cy="222.89690401258764" juliasvgnode="true" data-jscall-id="497" r="10.0" fill="navy" cx="508.50004317860567" />
                  <circle cy="229.36678638491532" juliasvgnode="true" data-jscall-id="498" r="10.0" fill="blue" cx="515.662015617741" />
                  <circle cy="235.04366206285647" juliasvgnode="true" data-jscall-id="499" r="10.0" fill="purple" cx="522.8239880568763" />
                  <circle cy="239.8708095811627" juliasvgnode="true" data-jscall-id="500" r="10.0" fill="fuchsia" cx="529.9859604960114" />
                  <circle cy="243.79999767747387" juliasvgnode="true" data-jscall-id="501" r="10.0" fill="black" cx="537.1479329351467" />
                  <circle cy="246.79196720314866" juliasvgnode="true" data-jscall-id="502" r="10.0" fill="gray" cx="544.3099053742822" />
                  <circle cy="248.81682338770003" juliasvgnode="true" data-jscall-id="503" r="10.0" fill="silver" cx="551.4718778134173" />
                  <circle cy="249.8543345374605" juliasvgnode="true" data-jscall-id="504" r="10.0" fill="maroon" cx="558.6338502525527" />
                  <circle cy="249.8941341839772" juliasvgnode="true" data-jscall-id="505" r="10.0" fill="red" cx="565.7958226916879" />
                  <circle cy="248.93582466233818" juliasvgnode="true" data-jscall-id="506" r="10.0" fill="olive" cx="572.9577951308232" />
                  <circle cy="246.98898108450862" juliasvgnode="true" data-jscall-id="507" r="10.0" fill="yellow" cx="580.1197675699585" />
                  <circle cy="244.07305566797726" juliasvgnode="true" data-jscall-id="508" r="10.0" fill="green" cx="587.2817400090939" />
                  <circle cy="240.2171833756293" juliasvgnode="true" data-jscall-id="509" r="10.0" fill="lime" cx="594.4437124482291" />
                  <circle cy="235.45989080882805" juliasvgnode="true" data-jscall-id="510" r="10.0" fill="teal" cx="601.6056848873644" />
                  <circle cy="229.848711262349" juliasvgnode="true" data-jscall-id="511" r="10.0" fill="aqua" cx="608.7676573264997" />
                  <circle cy="223.43970978741135" juliasvgnode="true" data-jscall-id="512" r="10.0" fill="navy" cx="615.929629765635" />
                  <circle cy="216.2969230082182" juliasvgnode="true" data-jscall-id="513" r="10.0" fill="blue" cx="623.0916022047703" />
                  <circle cy="208.49171928917616" juliasvgnode="true" data-jscall-id="514" r="10.0" fill="purple" cx="630.2535746439056" />
                  <circle cy="200.10208564578846" juliasvgnode="true" data-jscall-id="515" r="10.0" fill="fuchsia" cx="637.4155470830408" />
                  <circle cy="191.21184852417565" juliasvgnode="true" data-jscall-id="516" r="10.0" fill="black" cx="644.5775195221761" />
                  <circle cy="181.9098362349352" juliasvgnode="true" data-jscall-id="517" r="10.0" fill="gray" cx="651.7394919613114" />
                  <circle cy="172.2889914100246" juliasvgnode="true" data-jscall-id="518" r="10.0" fill="silver" cx="658.9014644004469" />
                  <circle cy="162.44544235070617" juliasvgnode="true" data-jscall-id="519" r="10.0" fill="maroon" cx="666.063436839582" />
                  <circle cy="152.47754254533578" juliasvgnode="true" data-jscall-id="520" r="10.0" fill="red" cx="673.2254092787173" />
                  <circle cy="142.48488795381908" juliasvgnode="true" data-jscall-id="521" r="10.0" fill="olive" cx="680.3873817178526" />
                  <circle cy="132.56732187770186" juliasvgnode="true" data-jscall-id="522" r="10.0" fill="yellow" cx="687.549354156988" />
                  <circle cy="122.82393735890558" juliasvgnode="true" data-jscall-id="523" r="10.0" fill="green" cx="694.7113265961233" />
                  <circle cy="113.35208707480717" juliasvgnode="true" data-jscall-id="524" r="10.0" fill="lime" cx="701.8732990352585" />
                  <circle cy="104.24641062246786" juliasvgnode="true" data-jscall-id="525" r="10.0" fill="teal" cx="709.0352714743938" />
                  <circle cy="95.59788891106302" juliasvgnode="true" data-jscall-id="526" r="10.0" fill="aqua" cx="716.1972439135291" />
                </g>
              </svg>
            </div>
          </div>
        </span>
      </div>
    </div>
  </div>
</div></div><p>As you notice, when exporting this example to the docs which get statically hosted, all interactions requiring Julia cease to exist. One way to create interactive examples that stay active is to move the parts that need Julia to Javascript:</p><div class="language-julia vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang">julia</span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">app </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> App</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">() </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">do</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> session</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">    colors </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> [</span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;black&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">, </span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;gray&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">, </span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;silver&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">, </span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;maroon&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">, </span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;red&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">, </span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;olive&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">, </span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;yellow&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">, </span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;green&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">, </span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;lime&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">, </span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;teal&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">, </span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;aqua&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">, </span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;navy&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">, </span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;blue&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">, </span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;purple&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">, </span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;fuchsia&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">]</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">    nsamples </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> D</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">Slider</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;nsamples&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">, </span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">1</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">:</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">200</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">, value</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">100</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">)</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">    nsamples</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">widget[] </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> 100</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">    sample_step </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> D</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">Slider</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;sample step&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">, </span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">0.01</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">:</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">0.01</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">:</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">1.0</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">, value</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">0.1</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">)</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">    sample_step</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">widget[] </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> 0.1</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">    phase </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> D</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">Slider</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;phase&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">, </span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">0.0</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">:</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">0.1</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">:</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">6.0</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">, value</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">0.0</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">)</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">    radii </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> D</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">Slider</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;radii&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">, </span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">0.1</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">:</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">0.1</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">:</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">60</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">, value</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">10.0</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">)</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">    radii</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">widget[] </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> 10</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">    svg </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> DOM</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">div</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">()</span></span>
<span class="line"><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">    evaljs</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(session, </span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">js</span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;&quot;&quot;</span></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">        const</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> [</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">width</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">, </span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">height</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">] </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> [</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">900</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">, </span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">300</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">]</span></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">        const</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> colors</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;"> =</span><span style="--shiki-light:#6F42C1;--shiki-dark:#B392F0;"> $</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(colors)</span></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">        const</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> observables</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;"> =</span><span style="--shiki-light:#6F42C1;--shiki-dark:#B392F0;"> $</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">([nsamples.value, sample_step.value, phase.value, radii.value])</span></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">        function</span><span style="--shiki-light:#6F42C1;--shiki-dark:#B392F0;"> update_svg</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#E36209;--shiki-dark:#FFAB70;">args</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">) {</span></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">            const</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> [</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">nsamples</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">, </span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">sample_step</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">, </span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">phase</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">, </span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">radii</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">] </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> args;</span></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">            const</span><span style="--shiki-light:#6F42C1;--shiki-dark:#B392F0;"> svg</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;"> =</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> (</span><span style="--shiki-light:#E36209;--shiki-dark:#FFAB70;">tag</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">, </span><span style="--shiki-light:#E36209;--shiki-dark:#FFAB70;">attr</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">) </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=&gt;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> {</span></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">                const</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> el</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;"> =</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> document.</span><span style="--shiki-light:#6F42C1;--shiki-dark:#B392F0;">createElementNS</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&#39;http://www.w3.org/2000/svg&#39;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">, tag);</span></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">                for</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> (</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">const</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> key</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;"> in</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> attr) {</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">                    el.</span><span style="--shiki-light:#6F42C1;--shiki-dark:#B392F0;">setAttributeNS</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">null</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">, key, attr[key]);</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">                }</span></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">                return</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> el</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">            }</span></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">            const</span><span style="--shiki-light:#6F42C1;--shiki-dark:#B392F0;"> color</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;"> =</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> (</span><span style="--shiki-light:#E36209;--shiki-dark:#FFAB70;">i</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">) </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=&gt;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> colors[i </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">%</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> colors.</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">length</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">]</span></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">            const</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> svg_node</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;"> =</span><span style="--shiki-light:#6F42C1;--shiki-dark:#B392F0;"> svg</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&#39;svg&#39;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">, {width: width, height: height});</span></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">            for</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> (</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">let</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> i</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">0</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">; i</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">&lt;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">nsamples; i</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">++</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">) {</span></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">                const</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> cxs_unscaled</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;"> =</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> (i </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">+</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> 1</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">) </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">*</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> sample_step </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">+</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> phase;</span></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">                const</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> cys</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;"> =</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> Math.</span><span style="--shiki-light:#6F42C1;--shiki-dark:#B392F0;">sin</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(cxs_unscaled) </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">*</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> (height </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">/</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> 3.0</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">) </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">+</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> (height </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">/</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> 2.0</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">);</span></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">                const</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> cxs</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;"> =</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> cxs_unscaled </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">*</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> width </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">/</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> (</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">4</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;"> *</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> Math.</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">PI</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">);</span></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">                const</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> circle</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;"> =</span><span style="--shiki-light:#6F42C1;--shiki-dark:#B392F0;"> svg</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&#39;circle&#39;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">, {cx: cxs, cy: cys, r: radii, fill: </span><span style="--shiki-light:#6F42C1;--shiki-dark:#B392F0;">color</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(i)});</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">                svg_node.</span><span style="--shiki-light:#6F42C1;--shiki-dark:#B392F0;">appendChild</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(circle);</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">            }</span></span>
<span class="line"><span style="--shiki-light:#6F42C1;--shiki-dark:#B392F0;">            $</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(svg).</span><span style="--shiki-light:#6F42C1;--shiki-dark:#B392F0;">replaceChildren</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(svg_node);</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">        }</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">        Bonito.</span><span style="--shiki-light:#6F42C1;--shiki-dark:#B392F0;">onany</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(observables, update_svg)</span></span>
<span class="line"><span style="--shiki-light:#6F42C1;--shiki-dark:#B392F0;">        update_svg</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(observables.</span><span style="--shiki-light:#6F42C1;--shiki-dark:#B392F0;">map</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#E36209;--shiki-dark:#FFAB70;">x</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=&gt;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> x.value))</span></span>
<span class="line"><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">        &quot;&quot;&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">)</span></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">    return</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> DOM</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">div</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(D</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">FlexRow</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(D</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">FlexCol</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(nsamples, sample_step, phase, radii), svg))</span></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">end</span></span></code></pre></div><div><div class="bonito-fragment" id="1841e9bd-f297-410d-b029-30b1e26978df" data-jscall-id="subsession-application-dom">
  <div>
    <style></style>
    <link href="bonito/css/tailwind.min8774971868340764599.css" rel="stylesheet" type="text/css" />
  </div>
  <div>
    <script type="module">    Bonito.lock_loading(() => {
        return Bonito.fetch_binary('bonito/bin/3a5d1a5a7dc82f0b28fde5fb947615f6ca000e1a-3048189428106613676.bin').then(msgs=> Bonito.init_session('1841e9bd-f297-410d-b029-30b1e26978df', msgs, 'sub', false));
    })
<\/script>
    <div data-jscall-id="533">
      <div class="mx-2 flex flex-row " data-jscall-id="534">
        <div class="my-2 flex flex-col " data-jscall-id="535">
          <div class="flex-row, mb-1 mt-1 " data-jscall-id="536">
            <h2 class="font-semibold " data-jscall-id="537">
              <div data-jscall-id="538">nsamples
                <div class="float-right text-right text w-32" data-jscall-id="539">
                  <span data-jscall-id="540">100</span>
                </div>
              </div>
            </h2>
            <input step="1" max="200" min="1" style="width: 100%;" data-jscall-id="541" value="100" oninput="" type="range" />
          </div>
          <div class="flex-row, mb-1 mt-1 " data-jscall-id="542">
            <h2 class="font-semibold " data-jscall-id="543">
              <div data-jscall-id="544">sample step
                <div class="float-right text-right text w-32" data-jscall-id="545">
                  <span data-jscall-id="546">0.1</span>
                </div>
              </div>
            </h2>
            <input step="1" max="100" min="1" style="width: 100%;" data-jscall-id="547" value="10" oninput="" type="range" />
          </div>
          <div class="flex-row, mb-1 mt-1 " data-jscall-id="548">
            <h2 class="font-semibold " data-jscall-id="549">
              <div data-jscall-id="550">phase
                <div class="float-right text-right text w-32" data-jscall-id="551">
                  <span data-jscall-id="552">0.0</span>
                </div>
              </div>
            </h2>
            <input step="1" max="61" min="1" style="width: 100%;" data-jscall-id="553" value="1" oninput="" type="range" />
          </div>
          <div class="flex-row, mb-1 mt-1 " data-jscall-id="554">
            <h2 class="font-semibold " data-jscall-id="555">
              <div data-jscall-id="556">radii
                <div class="float-right text-right text w-32" data-jscall-id="557">
                  <span data-jscall-id="558">10.0</span>
                </div>
              </div>
            </h2>
            <input step="1" max="600" min="1" style="width: 100%;" data-jscall-id="559" value="100" oninput="" type="range" />
          </div>
        </div>
        <div data-jscall-id="532"></div>
      </div>
    </div>
  </div>
</div></div><p>This works, because the Javascript side of Bonito, will still update the observables in Javascript (which are mirrored from Julia), and therefore keep working without a running Julia process. You can use <code>js_observable.on(value=&gt; ....)</code> and <code>Bonito.onany(array_of_js_observables, values=&gt; ...)</code> to create interactions, pretty similar to how you would work with Observables in Julia.</p>`,19)]))}const g=i(t,[["render",h]]);export{c as __pageData,g as default};
