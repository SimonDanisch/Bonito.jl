import{_ as i,c as a,o as l,aA as t}from"./chunks/framework.CGxuVltW.js";const r=JSON.parse('{"title":"Components","description":"","frontmatter":{},"headers":[],"relativePath":"components.md","filePath":"components.md","lastUpdated":null}'),n={name:"components.md"};function d(e,s,h,p,y,c){return l(),a("div",null,s[0]||(s[0]=[t(`<h1 id="components" tabindex="-1">Components <a class="header-anchor" href="#components" aria-label="Permalink to &quot;Components&quot;">​</a></h1><p>Components in Bonito are meant to be re-usable, easily shareable types and functions to create complex Bonito Apps. We invite everyone to share their Components by turning them into a Julia library.</p><p>There are two ways of defining components in Bonito:</p><ol><li><p>Write a function which returns <code>DOM</code> objects</p></li><li><p>Overload <code>jsrender</code> for a type</p></li></ol><p>The first is a very lightweight form of defining reusable components, which should be preferred if possible.</p><p>But, for e.g. widgets the second form is unavoidable, since you will want to return a type that the user can register interactions with. Also, the second form is great for integrating existing types into Bonito like plot objects. How to do the latter for Plotly is described in <a href="/Bonito.jl/plotting#Plotting">Plotting</a>.</p><p>Let&#39;s start with the simple function based components that reuses existing Bonito components:</p><div class="language-julia vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang">julia</span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">using</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> Dates</span></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">function</span><span style="--shiki-light:#6F42C1;--shiki-dark:#B392F0;"> CurrentMonth</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(date</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">now</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(); style</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">Styles</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(), div_attributes</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">...</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">)</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">    current_day </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> Dates</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">day</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(date)</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">    month </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> Dates</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">monthname</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(date)</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">    ndays </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> Dates</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">daysinmonth</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(date)</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">    current_day_style </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> Styles</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(style, </span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;background-color&quot;</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;"> =&gt;</span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;"> &quot;gray&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">, </span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;color&quot;</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;"> =&gt;</span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;"> &quot;white&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">)</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">    days </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> map</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">1</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">:</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">ndays) </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">do</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> day</span></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">        if</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> day </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">==</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> current_day</span></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">            return</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> Card</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">Centered</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(day); style</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">current_day_style)</span></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">        else</span></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">            return</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> Card</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">Centered</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(day); style</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">style)</span></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">        end</span></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">    end</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">    grid </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> Grid</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(days</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">...</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">; columns</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;repeat(7, 1fr)&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">)</span></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">    return</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> DOM</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">div</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(DOM</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">h2</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(month), grid; style</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">Styles</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;width&quot;</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;"> =&gt;</span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;"> &quot;400px&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">, </span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;margin&quot;</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;"> =&gt;</span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;"> &quot;5px&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">))</span></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">end</span></span>
<span class="line"></span>
<span class="line"></span>
<span class="line"><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">App</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(()</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">-&gt;</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> CurrentMonth</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">())</span></span></code></pre></div><div><div>
  <div class="bonito-fragment" id="cfd50b70-766b-4a0b-9666-15899d87035a" data-jscall-id="root">
    <div>
      <script src="bonito/js/Bonito.bundled15432232505923397289.js" type="module"><\/script>
      <style></style>
    </div>
    <div>
      <script type="module">Bonito.lock_loading(() => Bonito.init_session('cfd50b70-766b-4a0b-9666-15899d87035a', null, 'root', false))<\/script>
      <span></span>
    </div>
  </div>
  <div class="bonito-fragment" id="d4f4c13c-103d-4144-a4fa-9d4030f284f8" data-jscall-id="subsession-application-dom">
    <div>
      <style>.style_2 {
  justify-items: center;
  align-items: center;
  height: 100%;
  display: grid;
  align-content: center;
  grid-gap: 10px;
  grid-template-rows: none;
  justify-content: center;
  grid-template-columns: 1fr;
  width: 100%;
  grid-template-areas: none;
}
.style_3 {
  width: 400px;
  margin: 5px;
}
.style_4 {
  justify-items: legacy;
  align-items: legacy;
  height: 100%;
  display: grid;
  align-content: normal;
  grid-gap: 10px;
  grid-template-rows: none;
  justify-content: normal;
  grid-template-columns: repeat(7, 1fr);
  width: 100%;
  grid-template-areas: none;
}
.style_5 {
  height: auto;
  padding: 12px;
  background-color: rgba(255.0, 255.0, 255.0, 0.2);
  box-shadow: 0 4px 8px rgba(0.0, 0.0, 51.0, 0.2);
  width: auto;
  border-radius: 10px;
  margin: 2px;
}
.style_6 {
  height: auto;
  padding: 12px;
  background-color: gray;
  box-shadow: 0 4px 8px rgba(0.0, 0.0, 51.0, 0.2);
  color: white;
  width: auto;
  border-radius: 10px;
  margin: 2px;
}
</style>
    </div>
    <div>
      <script type="module">Bonito.lock_loading(() => Bonito.init_session('d4f4c13c-103d-4144-a4fa-9d4030f284f8', null, 'sub', false))<\/script>
      <div class=" style_3" style="" data-jscall-id="1">
        <h2 data-jscall-id="2">March</h2>
        <div class=" style_4" style="" data-jscall-id="3">
          <div class=" style_5" style="" data-jscall-id="4">
            <div class=" style_2" style="" data-jscall-id="5">1</div>
          </div>
          <div class=" style_5" style="" data-jscall-id="6">
            <div class=" style_2" style="" data-jscall-id="7">2</div>
          </div>
          <div class=" style_5" style="" data-jscall-id="8">
            <div class=" style_2" style="" data-jscall-id="9">3</div>
          </div>
          <div class=" style_5" style="" data-jscall-id="10">
            <div class=" style_2" style="" data-jscall-id="11">4</div>
          </div>
          <div class=" style_5" style="" data-jscall-id="12">
            <div class=" style_2" style="" data-jscall-id="13">5</div>
          </div>
          <div class=" style_5" style="" data-jscall-id="14">
            <div class=" style_2" style="" data-jscall-id="15">6</div>
          </div>
          <div class=" style_5" style="" data-jscall-id="16">
            <div class=" style_2" style="" data-jscall-id="17">7</div>
          </div>
          <div class=" style_5" style="" data-jscall-id="18">
            <div class=" style_2" style="" data-jscall-id="19">8</div>
          </div>
          <div class=" style_5" style="" data-jscall-id="20">
            <div class=" style_2" style="" data-jscall-id="21">9</div>
          </div>
          <div class=" style_5" style="" data-jscall-id="22">
            <div class=" style_2" style="" data-jscall-id="23">10</div>
          </div>
          <div class=" style_5" style="" data-jscall-id="24">
            <div class=" style_2" style="" data-jscall-id="25">11</div>
          </div>
          <div class=" style_5" style="" data-jscall-id="26">
            <div class=" style_2" style="" data-jscall-id="27">12</div>
          </div>
          <div class=" style_5" style="" data-jscall-id="28">
            <div class=" style_2" style="" data-jscall-id="29">13</div>
          </div>
          <div class=" style_5" style="" data-jscall-id="30">
            <div class=" style_2" style="" data-jscall-id="31">14</div>
          </div>
          <div class=" style_5" style="" data-jscall-id="32">
            <div class=" style_2" style="" data-jscall-id="33">15</div>
          </div>
          <div class=" style_5" style="" data-jscall-id="34">
            <div class=" style_2" style="" data-jscall-id="35">16</div>
          </div>
          <div class=" style_5" style="" data-jscall-id="36">
            <div class=" style_2" style="" data-jscall-id="37">17</div>
          </div>
          <div class=" style_5" style="" data-jscall-id="38">
            <div class=" style_2" style="" data-jscall-id="39">18</div>
          </div>
          <div class=" style_5" style="" data-jscall-id="40">
            <div class=" style_2" style="" data-jscall-id="41">19</div>
          </div>
          <div class=" style_5" style="" data-jscall-id="42">
            <div class=" style_2" style="" data-jscall-id="43">20</div>
          </div>
          <div class=" style_5" style="" data-jscall-id="44">
            <div class=" style_2" style="" data-jscall-id="45">21</div>
          </div>
          <div class=" style_5" style="" data-jscall-id="46">
            <div class=" style_2" style="" data-jscall-id="47">22</div>
          </div>
          <div class=" style_5" style="" data-jscall-id="48">
            <div class=" style_2" style="" data-jscall-id="49">23</div>
          </div>
          <div class=" style_5" style="" data-jscall-id="50">
            <div class=" style_2" style="" data-jscall-id="51">24</div>
          </div>
          <div class=" style_6" style="" data-jscall-id="52">
            <div class=" style_2" style="" data-jscall-id="53">25</div>
          </div>
          <div class=" style_5" style="" data-jscall-id="54">
            <div class=" style_2" style="" data-jscall-id="55">26</div>
          </div>
          <div class=" style_5" style="" data-jscall-id="56">
            <div class=" style_2" style="" data-jscall-id="57">27</div>
          </div>
          <div class=" style_5" style="" data-jscall-id="58">
            <div class=" style_2" style="" data-jscall-id="59">28</div>
          </div>
          <div class=" style_5" style="" data-jscall-id="60">
            <div class=" style_2" style="" data-jscall-id="61">29</div>
          </div>
          <div class=" style_5" style="" data-jscall-id="62">
            <div class=" style_2" style="" data-jscall-id="63">30</div>
          </div>
          <div class=" style_5" style="" data-jscall-id="64">
            <div class=" style_2" style="" data-jscall-id="65">31</div>
          </div>
        </div>
      </div>
    </div>
  </div>
</div></div><p>Now, we could define the same kind of rendering via overloading <code>jsrender</code>, if a date is spliced into a DOM:</p><div class="language-julia vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang">julia</span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">function</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> Bonito</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#6F42C1;--shiki-dark:#B392F0;">jsrender</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(session</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">::</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">Session</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">, date</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">::</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">DateTime</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">)</span></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">    return</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> Bonito</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">jsrender</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(session, </span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">CurrentMonth</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(date))</span></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">end</span></span>
<span class="line"><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">App</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">() </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">do</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">    DOM</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">div</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">now</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">())</span></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">end</span></span></code></pre></div><div><div class="bonito-fragment" id="3e6d79c8-77d3-4b11-ac3f-513a612bd2ae" data-jscall-id="subsession-application-dom">
  <div>
    <style>.style_7 {
  justify-items: center;
  align-items: center;
  height: 100%;
  display: grid;
  align-content: center;
  grid-gap: 10px;
  grid-template-rows: none;
  justify-content: center;
  grid-template-columns: 1fr;
  width: 100%;
  grid-template-areas: none;
}
.style_8 {
  width: 400px;
  margin: 5px;
}
.style_9 {
  justify-items: legacy;
  align-items: legacy;
  height: 100%;
  display: grid;
  align-content: normal;
  grid-gap: 10px;
  grid-template-rows: none;
  justify-content: normal;
  grid-template-columns: repeat(7, 1fr);
  width: 100%;
  grid-template-areas: none;
}
.style_10 {
  height: auto;
  padding: 12px;
  background-color: rgba(255.0, 255.0, 255.0, 0.2);
  box-shadow: 0 4px 8px rgba(0.0, 0.0, 51.0, 0.2);
  width: auto;
  border-radius: 10px;
  margin: 2px;
}
.style_11 {
  height: auto;
  padding: 12px;
  background-color: gray;
  box-shadow: 0 4px 8px rgba(0.0, 0.0, 51.0, 0.2);
  color: white;
  width: auto;
  border-radius: 10px;
  margin: 2px;
}
</style>
  </div>
  <div>
    <script type="module">Bonito.lock_loading(() => Bonito.init_session('3e6d79c8-77d3-4b11-ac3f-513a612bd2ae', null, 'sub', false))<\/script>
    <div data-jscall-id="66">
      <div class=" style_8" style="" data-jscall-id="67">
        <h2 data-jscall-id="68">March</h2>
        <div class=" style_9" style="" data-jscall-id="69">
          <div class=" style_10" style="" data-jscall-id="70">
            <div class=" style_7" style="" data-jscall-id="71">1</div>
          </div>
          <div class=" style_10" style="" data-jscall-id="72">
            <div class=" style_7" style="" data-jscall-id="73">2</div>
          </div>
          <div class=" style_10" style="" data-jscall-id="74">
            <div class=" style_7" style="" data-jscall-id="75">3</div>
          </div>
          <div class=" style_10" style="" data-jscall-id="76">
            <div class=" style_7" style="" data-jscall-id="77">4</div>
          </div>
          <div class=" style_10" style="" data-jscall-id="78">
            <div class=" style_7" style="" data-jscall-id="79">5</div>
          </div>
          <div class=" style_10" style="" data-jscall-id="80">
            <div class=" style_7" style="" data-jscall-id="81">6</div>
          </div>
          <div class=" style_10" style="" data-jscall-id="82">
            <div class=" style_7" style="" data-jscall-id="83">7</div>
          </div>
          <div class=" style_10" style="" data-jscall-id="84">
            <div class=" style_7" style="" data-jscall-id="85">8</div>
          </div>
          <div class=" style_10" style="" data-jscall-id="86">
            <div class=" style_7" style="" data-jscall-id="87">9</div>
          </div>
          <div class=" style_10" style="" data-jscall-id="88">
            <div class=" style_7" style="" data-jscall-id="89">10</div>
          </div>
          <div class=" style_10" style="" data-jscall-id="90">
            <div class=" style_7" style="" data-jscall-id="91">11</div>
          </div>
          <div class=" style_10" style="" data-jscall-id="92">
            <div class=" style_7" style="" data-jscall-id="93">12</div>
          </div>
          <div class=" style_10" style="" data-jscall-id="94">
            <div class=" style_7" style="" data-jscall-id="95">13</div>
          </div>
          <div class=" style_10" style="" data-jscall-id="96">
            <div class=" style_7" style="" data-jscall-id="97">14</div>
          </div>
          <div class=" style_10" style="" data-jscall-id="98">
            <div class=" style_7" style="" data-jscall-id="99">15</div>
          </div>
          <div class=" style_10" style="" data-jscall-id="100">
            <div class=" style_7" style="" data-jscall-id="101">16</div>
          </div>
          <div class=" style_10" style="" data-jscall-id="102">
            <div class=" style_7" style="" data-jscall-id="103">17</div>
          </div>
          <div class=" style_10" style="" data-jscall-id="104">
            <div class=" style_7" style="" data-jscall-id="105">18</div>
          </div>
          <div class=" style_10" style="" data-jscall-id="106">
            <div class=" style_7" style="" data-jscall-id="107">19</div>
          </div>
          <div class=" style_10" style="" data-jscall-id="108">
            <div class=" style_7" style="" data-jscall-id="109">20</div>
          </div>
          <div class=" style_10" style="" data-jscall-id="110">
            <div class=" style_7" style="" data-jscall-id="111">21</div>
          </div>
          <div class=" style_10" style="" data-jscall-id="112">
            <div class=" style_7" style="" data-jscall-id="113">22</div>
          </div>
          <div class=" style_10" style="" data-jscall-id="114">
            <div class=" style_7" style="" data-jscall-id="115">23</div>
          </div>
          <div class=" style_10" style="" data-jscall-id="116">
            <div class=" style_7" style="" data-jscall-id="117">24</div>
          </div>
          <div class=" style_11" style="" data-jscall-id="118">
            <div class=" style_7" style="" data-jscall-id="119">25</div>
          </div>
          <div class=" style_10" style="" data-jscall-id="120">
            <div class=" style_7" style="" data-jscall-id="121">26</div>
          </div>
          <div class=" style_10" style="" data-jscall-id="122">
            <div class=" style_7" style="" data-jscall-id="123">27</div>
          </div>
          <div class=" style_10" style="" data-jscall-id="124">
            <div class=" style_7" style="" data-jscall-id="125">28</div>
          </div>
          <div class=" style_10" style="" data-jscall-id="126">
            <div class=" style_7" style="" data-jscall-id="127">29</div>
          </div>
          <div class=" style_10" style="" data-jscall-id="128">
            <div class=" style_7" style="" data-jscall-id="129">30</div>
          </div>
          <div class=" style_10" style="" data-jscall-id="130">
            <div class=" style_7" style="" data-jscall-id="131">31</div>
          </div>
        </div>
      </div>
    </div>
  </div>
</div></div><p>Please note, that <code>jsrender</code> is not applied recursively on its own, so one needs to apply it manually on the return value. It&#39;s not needed for simple divs and other Hyperscript elements, but e.g. <code>Styles</code> requires a pass through <code>jsrender</code> to do the deduplication etc.</p>`,13)]))}const o=i(n,[["render",d]]);export{r as __pageData,o as default};
