import { defineConfig } from 'vitepress'
import { tabsMarkdownPlugin } from 'vitepress-plugin-tabs'
import mathjax3 from "markdown-it-mathjax3";
import footnote from "markdown-it-footnote";
import path from 'path'

function getBaseRepository(base: string): string {
  if (!base || base === '/') return '/';
  const parts = base.split('/').filter(Boolean);
  return parts.length > 0 ? `/${parts[0]}/` : '/';
}

const baseTemp = {
  base: '/Bonito.jl/',// TODO: replace this in makedocs!
}

const navTemp = {
  nav: [
{ text: 'Home', link: '/index' },
{ text: 'Components', collapsed: false, items: [
{ text: 'Styling', link: '/styling' },
{ text: 'Components', link: '/components' },
{ text: 'Layouting', link: '/layouting' },
{ text: 'Widgets', link: '/widgets' },
{ text: 'Interactions', link: '/interactions' }]
 },
{ text: 'Examples', collapsed: false, items: [
{ text: 'Plotting', link: '/plotting' },
{ text: 'Wrapping JS libraries', link: '/javascript-libraries' },
{ text: 'Assets', link: '/assets' },
{ text: 'Extending', link: '/extending' }]
 },
{ text: 'Deployment', link: '/deployment' },
{ text: 'Static Sites', link: '/static' },
{ text: 'Api', link: '/api' }
]
,
}

const nav = [
  ...navTemp.nav,
  {
    component: 'VersionPicker'
  }
]

// https://vitepress.dev/reference/site-config
export default defineConfig({
  base: '/Bonito.jl/',// TODO: replace this in makedocs!
  title: 'Bonito',
  description: 'Documentation for Bonito.jl',
  lastUpdated: true,
  cleanUrls: true,
  outDir: '../final_site', // This is required for MarkdownVitepress to work correctly...
  head: [
    
    ['script', {src: `${getBaseRepository(baseTemp.base)}versions.js`}],
    // ['script', {src: '/versions.js'], for custom domains, I guess if deploy_url is available.
    ['script', {src: `${baseTemp.base}siteinfo.js`}]
  ],
  
  vite: {
    resolve: {
      alias: {
        '@': path.resolve(__dirname, '../components')
      }
    },
    optimizeDeps: {
      exclude: [ 
        '@nolebase/vitepress-plugin-enhanced-readabilities/client',
        'vitepress',
        '@nolebase/ui',
      ], 
    }, 
    ssr: { 
      noExternal: [ 
        // If there are other packages that need to be processed by Vite, you can add them here.
        '@nolebase/vitepress-plugin-enhanced-readabilities',
        '@nolebase/ui',
      ], 
    },
  },
  markdown: {
    math: true,
    config(md) {
      md.use(tabsMarkdownPlugin),
      md.use(mathjax3),
      md.use(footnote),
      md.options.html = true
    },
    theme: {
      light: "github-light",
      dark: "github-dark"}
  },
  themeConfig: {
    outline: 'deep',
    
    search: {
      provider: 'local',
      options: {
        detailedView: true
      }
    },
    nav,
    sidebar: [
{ text: 'Home', link: '/index' },
{ text: 'Components', collapsed: false, items: [
{ text: 'Styling', link: '/styling' },
{ text: 'Components', link: '/components' },
{ text: 'Layouting', link: '/layouting' },
{ text: 'Widgets', link: '/widgets' },
{ text: 'Interactions', link: '/interactions' }]
 },
{ text: 'Examples', collapsed: false, items: [
{ text: 'Plotting', link: '/plotting' },
{ text: 'Wrapping JS libraries', link: '/javascript-libraries' },
{ text: 'Assets', link: '/assets' },
{ text: 'Extending', link: '/extending' }]
 },
{ text: 'Deployment', link: '/deployment' },
{ text: 'Static Sites', link: '/static' },
{ text: 'Api', link: '/api' }
]
,
    editLink: { pattern: "https://github.com/SimonDanisch/Bonito.jl/edit/master/docs/src/:path" },
    socialLinks: [
      { icon: 'github', link: 'https://github.com/SimonDanisch/Bonito.jl' }
    ],
    footer: {
      message: 'Made with <a href="https://luxdl.github.io/DocumenterVitepress.jl/dev/" target="_blank"><strong>DocumenterVitepress.jl</strong></a><br>',
      copyright: `© Copyright ${new Date().getUTCFullYear()}.`
    }
  }
})
