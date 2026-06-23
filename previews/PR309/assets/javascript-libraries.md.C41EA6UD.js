import{_ as i,c as a,o as n,aA as t}from"./chunks/framework.CGxuVltW.js";const o=JSON.parse('{"title":"Javascript","description":"","frontmatter":{},"headers":[],"relativePath":"javascript-libraries.md","filePath":"javascript-libraries.md","lastUpdated":null}'),p={name:"javascript-libraries.md"};function l(h,s,e,k,r,d){return n(),a("div",null,s[0]||(s[0]=[t(`<h1 id="javascript" tabindex="-1">Javascript <a class="header-anchor" href="#javascript" aria-label="Permalink to &quot;Javascript&quot;">​</a></h1><h2 id="Wrapping-Javascript-Libraries" tabindex="-1">Wrapping Javascript Libraries <a class="header-anchor" href="#Wrapping-Javascript-Libraries" aria-label="Permalink to &quot;Wrapping Javascript Libraries {#Wrapping-Javascript-Libraries}&quot;">​</a></h2><div class="language-julia vp-adaptive-theme"><button title="Copy Code" class="copy"></button><span class="lang">julia</span><pre class="shiki shiki-themes github-light github-dark vp-code" tabindex="0"><code><span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">leafletjs </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> Bonito</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">ES6Module</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;https://esm.sh/v133/leaflet@1.9.4/es2022/leaflet.mjs&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">)</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">leafletcss </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> Bonito</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">Asset</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;https://unpkg.com/leaflet@1.9.4/dist/leaflet.css&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">)</span></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">struct</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> LeafletMap</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">    position</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">::</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">NTuple{2,Float64}</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">    zoom</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">::</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">Int</span></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">end</span></span>
<span class="line"></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">function</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> Bonito</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#6F42C1;--shiki-dark:#B392F0;">jsrender</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(session</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">::</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">Session</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">, map</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">::</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">LeafletMap</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">)</span></span>
<span class="line"></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">    map_div </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> DOM</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">div</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(id</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;map&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">; style</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=</span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;height: 500px;&quot;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">)</span></span>
<span class="line"></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">    return</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> Bonito</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">jsrender</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(session, DOM</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">.</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">div</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">        leafletcss,</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">        leafletjs,</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">        map_div,</span></span>
<span class="line"><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">        js</span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&quot;&quot;&quot;</span></span>
<span class="line"><span style="--shiki-light:#6F42C1;--shiki-dark:#B392F0;">            $</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(leafletjs).</span><span style="--shiki-light:#6F42C1;--shiki-dark:#B392F0;">then</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#E36209;--shiki-dark:#FFAB70;">L</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">=&gt;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;"> {</span></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">                const</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> map</span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;"> =</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> L</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">.</span><span style="--shiki-light:#6F42C1;--shiki-dark:#B392F0;">map</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&#39;map&#39;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">).</span><span style="--shiki-light:#6F42C1;--shiki-dark:#B392F0;">setView</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span><span style="--shiki-light:#6F42C1;--shiki-dark:#B392F0;">$</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(map.position), </span><span style="--shiki-light:#6F42C1;--shiki-dark:#B392F0;">$</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(map.zoom));</span></span>
<span class="line"><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">                L</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">.</span><span style="--shiki-light:#6F42C1;--shiki-dark:#B392F0;">tileLayer</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(</span></span>
<span class="line"><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">                    &#39;https://tile.openstreetmap.org/{z}/{x}/{y}.png&#39;</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">, {</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">                    maxZoom: </span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">19</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">,</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">                    attribution: </span><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">&#39;&amp;copy; &lt;a href=&quot;http://www.openstreetmap.org/copyright&quot;&gt;OpenStreetMap&lt;/a&gt;&#39;</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">                }).</span><span style="--shiki-light:#6F42C1;--shiki-dark:#B392F0;">addTo</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">(map);</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">            })</span></span>
<span class="line"></span>
<span class="line"><span style="--shiki-light:#032F62;--shiki-dark:#9ECBFF;">        &quot;&quot;&quot;</span></span>
<span class="line"><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">    ))</span></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">end</span></span>
<span class="line"></span>
<span class="line"></span>
<span class="line"><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">App</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">() </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">do</span></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">    return</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;"> LeafletMap</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">((</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">51.505</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">, </span><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">-</span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">0.09</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">), </span><span style="--shiki-light:#005CC5;--shiki-dark:#79B8FF;">13</span><span style="--shiki-light:#24292E;--shiki-dark:#E1E4E8;">)</span></span>
<span class="line"><span style="--shiki-light:#D73A49;--shiki-dark:#F97583;">end</span></span></code></pre></div><div><div>
  <div class="bonito-fragment" id="83092dca-ae60-4e18-badc-915ffeaf35b2" data-jscall-id="root">
    <div>
      <script src="bonito/js/Bonito.bundled15432232505923397289.js" type="module"><\/script>
      <style></style>
    </div>
    <div>
      <script type="module">Bonito.lock_loading(() => Bonito.init_session('83092dca-ae60-4e18-badc-915ffeaf35b2', null, 'root', false))<\/script>
      <span></span>
    </div>
  </div>
  <div class="bonito-fragment" id="f7df8159-8552-4172-8eaf-6958dd32c48b" data-jscall-id="subsession-application-dom">
    <div>
      <style></style>
      <link href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" rel="stylesheet" type="text/css" />
      <script src="https://esm.sh/v133/leaflet@1.9.4/es2022/leaflet.mjs" type="module"><\/script>
    </div>
    <div>
      <script type="module">Bonito.lock_loading(() => Bonito.init_session('f7df8159-8552-4172-8eaf-6958dd32c48b', null, 'sub', false))<\/script>
      <div data-jscall-id="1">
        <div id="map" data-jscall-id="2" style="height: 500px;"></div>
        <script type="module">// JSCode from javascript-libraries.md:26
Bonito.lock_loading(() => {
    return Bonito.fetch_binary('bonito/bin/3eafc500d1348d3bd1a3d114d0cff5e459ad5022-17661011806085596922.bin').then(bin_messages=>{
        const objects = Bonito.decode_binary(bin_messages, false);
        const __lookup_interpolated = (id) => objects[id]
            import('https://esm.sh/v133/leaflet@1.9.4/es2022/leaflet.mjs').then(L=> {
        const map = L.map('map').setView(__lookup_interpolated('1931559942742559920'), 13);
        L.tileLayer(
            'https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
            maxZoom: 19,
            attribution: '&copy; <a href="http://www.openstreetmap.org/copyright">OpenStreetMap</a>'
        }).addTo(map);
    })


    })
})
<\/script>
      </div>
    </div>
  </div>
</div></div>`,4)]))}const g=i(p,[["render",l]]);export{o as __pageData,g as default};
