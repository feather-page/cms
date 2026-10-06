// @editorjs/embed@2.7.6 downloaded from https://ga.jspm.io/npm:@editorjs/embed@2.7.6/dist/embed.mjs

(function(){try{if(typeof document<"u"){var e=document.createElement("style");e.appendChild(document.createTextNode('.embed-tool--loading .embed-tool__caption{display:none}.embed-tool--loading .embed-tool__preloader{display:block}.embed-tool--loading .embed-tool__content{display:none}.embed-tool__preloader{display:none;position:relative;height:200px;box-sizing:border-box;border-radius:5px;border:1px solid #e6e9eb}.embed-tool__preloader:before{content:"";position:absolute;z-index:3;left:50%;top:50%;width:30px;height:30px;margin-top:-25px;margin-left:-15px;border-radius:50%;border:2px solid #cdd1e0;border-top-color:#388ae5;box-sizing:border-box;animation:embed-preloader-spin 2s infinite linear}.embed-tool__url{position:absolute;bottom:20px;left:50%;transform:translate(-50%);max-width:250px;color:#7b7e89;font-size:11px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.embed-tool__content{width:100%}.embed-tool__caption{margin-top:7px}.embed-tool__caption[contentEditable=true][data-placeholder]:before{position:absolute;content:attr(data-placeholder);color:#707684;font-weight:400;opacity:0}.embed-tool__caption[contentEditable=true][data-placeholder]:empty:before{opacity:1}.embed-tool__caption[contentEditable=true][data-placeholder]:empty:focus:before{opacity:0}@keyframes embed-preloader-spin{0%{transform:rotate(0)}to{transform:rotate(360deg)}}')),document.head.appendChild(e)}}catch(e){console.error("vite-plugin-css-injected-by-js",e)}})();const e={vimeo:{regex:/(?:http[s]?:\/\/)?(?:www.)?(?:player.)?vimeo\.co(?:.+\/([^\/]\d+)(?:#t=[\d]+)?s?$)/,embedUrl:"https://player.vimeo.com/video/<%= remote_id %>?title=0&byline=0",html:'<iframe style="width:100%;" height="320" frameborder="0"></iframe>',height:320,width:580},youtube:{regex:/(?:https?:\/\/)?(?:www\.)?(?:(?:youtu\.be\/)|(?:youtube\.com)\/(?:v\/|u\/\w\/|embed\/|watch))(?:(?:\?v=)?([^#&?=]*))?((?:[?&]\w*=\w*)*)/,embedUrl:"https://www.youtube.com/embed/<%= remote_id %>",html:'<iframe style="width:100%;" height="320" frameborder="0" allowfullscreen></iframe>',height:320,width:580,id:([e,t])=>{if(!t&&e)return e;const i={start:"start",end:"end",t:"start",time_continue:"start",list:"list"};let r=t.slice(1).split("&").map((t=>{const[r,o]=t.split("=");return e||r!=="v"?!i[r]||o==="LL"||o.startsWith("RDMM")||o.startsWith("FL")?null:`${i[r]}=${o}`:(e=o,null)})).filter((e=>!!e));return e+"?"+r.join("&")}},coub:{regex:/https?:\/\/coub\.com\/view\/([^\/\?\&]+)/,embedUrl:"https://coub.com/embed/<%= remote_id %>",html:'<iframe style="width:100%;" height="320" frameborder="0" allowfullscreen></iframe>',height:320,width:580},vine:{regex:/https?:\/\/vine\.co\/v\/([^\/\?\&]+)/,embedUrl:"https://vine.co/v/<%= remote_id %>/embed/simple/",html:'<iframe style="width:100%;" height="320" frameborder="0" allowfullscreen></iframe>',height:320,width:580},imgur:{regex:/https?:\/\/(?:i\.)?imgur\.com.*\/([a-zA-Z0-9]+)(?:\.gifv)?/,embedUrl:"http://imgur.com/<%= remote_id %>/embed",html:'<iframe allowfullscreen="true" scrolling="no" id="imgur-embed-iframe-pub-<%= remote_id %>" class="imgur-embed-iframe-pub" style="height: 500px; width: 100%; border: 1px solid #000"></iframe>',height:500,width:540},gfycat:{regex:/https?:\/\/gfycat\.com(?:\/detail)?\/([a-zA-Z]+)/,embedUrl:"https://gfycat.com/ifr/<%= remote_id %>",html:"<iframe frameborder='0' scrolling='no' style=\"width:100%;\" height='436' allowfullscreen ></iframe>",height:436,width:580},"twitch-channel":{regex:/https?:\/\/www\.twitch\.tv\/([^\/\?\&]*)\/?$/,embedUrl:"https://player.twitch.tv/?channel=<%= remote_id %>",html:'<iframe frameborder="0" allowfullscreen="true" scrolling="no" height="366" style="width:100%;"></iframe>',height:366,width:600},"twitch-video":{regex:/https?:\/\/www\.twitch\.tv\/(?:[^\/\?\&]*\/v|videos)\/([0-9]*)/,embedUrl:"https://player.twitch.tv/?video=v<%= remote_id %>",html:'<iframe frameborder="0" allowfullscreen="true" scrolling="no" height="366" style="width:100%;"></iframe>',height:366,width:600},"yandex-music-album":{regex:/https?:\/\/music\.yandex\.ru\/album\/([0-9]*)\/?$/,embedUrl:"https://music.yandex.ru/iframe/#album/<%= remote_id %>/",html:'<iframe frameborder="0" style="border:none;width:540px;height:400px;" style="width:100%;" height="400"></iframe>',height:400,width:540},"yandex-music-track":{regex:/https?:\/\/music\.yandex\.ru\/album\/([0-9]*)\/track\/([0-9]*)/,embedUrl:"https://music.yandex.ru/iframe/#track/<%= remote_id %>/",html:'<iframe frameborder="0" style="border:none;width:540px;height:100px;" style="width:100%;" height="100"></iframe>',height:100,width:540,id:e=>e.join("/")},"yandex-music-playlist":{regex:/https?:\/\/music\.yandex\.ru\/users\/([^\/\?\&]*)\/playlists\/([0-9]*)/,embedUrl:"https://music.yandex.ru/iframe/#playlist/<%= remote_id %>/show/cover/description/",html:'<iframe frameborder="0" style="border:none;width:540px;height:400px;" width="540" height="400"></iframe>',height:400,width:540,id:e=>e.join("/")},codepen:{regex:/https?:\/\/codepen\.io\/([^\/\?\&]*)\/pen\/([^\/\?\&]*)/,embedUrl:"https://codepen.io/<%= remote_id %>?height=300&theme-id=0&default-tab=css,result&embed-version=2",html:"<iframe height='300' scrolling='no' frameborder='no' allowtransparency='true' allowfullscreen='true' style='width: 100%;'></iframe>",height:300,width:600,id:e=>e.join("/embed/")},instagram:{regex:/^https:\/\/(?:www\.)?instagram\.com\/(?:reel|p)\/(.*)/,embedUrl:"https://www.instagram.com/p/<%= remote_id %>/embed",html:'<iframe width="400" height="505" style="margin: 0 auto;" frameborder="0" scrolling="no" allowtransparency="true"></iframe>',height:505,width:400,id:e=>{var t;return(t=e==null?void 0:e[0])==null?void 0:t.split("/")[0]}},twitter:{regex:/^https?:\/\/(www\.)?(?:twitter\.com|x\.com)\/.+\/status\/(\d+)/,embedUrl:"https://platform.twitter.com/embed/Tweet.html?id=<%= remote_id %>",html:'<iframe width="600" height="600" style="margin: 0 auto;" frameborder="0" scrolling="no" allowtransparency="true"></iframe>',height:300,width:600,id:e=>e[1]},pinterest:{regex:/https?:\/\/([^\/\?\&]*).pinterest.com\/pin\/([^\/\?\&]*)\/?$/,embedUrl:"https://assets.pinterest.com/ext/embed.html?id=<%= remote_id %>",html:"<iframe scrolling='no' frameborder='no' allowtransparency='true' allowfullscreen='true' style='width: 100%; min-height: 400px; max-height: 1000px;'></iframe>",id:e=>e[1]},facebook:{regex:/https?:\/\/www.facebook.com\/([^\/\?\&]*)\/(.*)/,embedUrl:"https://www.facebook.com/plugins/post.php?href=https://www.facebook.com/<%= remote_id %>&width=500",html:"<iframe scrolling='no' frameborder='no' allowtransparency='true' allowfullscreen='true' style='width: 100%; min-height: 500px; max-height: 1000px;'></iframe>",id:e=>e.join("/")},aparat:{regex:/(?:http[s]?:\/\/)?(?:www.)?aparat\.com\/v\/([^\/\?\&]+)\/?/,embedUrl:"https://www.aparat.com/video/video/embed/videohash/<%= remote_id %>/vt/frame",html:'<iframe width="600" height="300" style="margin: 0 auto;" frameborder="0" scrolling="no" allowtransparency="true"></iframe>',height:300,width:600},miro:{regex:/https:\/\/miro.com\/\S+(\S{12})\/(\S+)?/,embedUrl:"https://miro.com/app/live-embed/<%= remote_id %>",html:'<iframe width="700" height="500" style="margin: 0 auto;" allowFullScreen frameBorder="0" scrolling="no"></iframe>'},github:{regex:/https?:\/\/gist.github.com\/([^\/\?\&]*)\/([^\/\?\&]*)/,embedUrl:'data:text/html;charset=utf-8,<head><base target="_blank" /></head><body><script src="https://gist.github.com/<%= remote_id %>" ><\/script></body>',html:'<iframe width="100%" height="350" frameborder="0" style="margin: 0 auto;"></iframe>',height:300,width:600,id:e=>`${e.join("/")}.js`}};function p(e,t,i){var r,o,a,l,d;t==null&&(t=100);function n(){var s=Date.now()-l;s<t&&s>=0?r=setTimeout(n,t-s):(r=null,i||(d=e.apply(a,o),a=o=null))}var h=function(){a=this,o=arguments,l=Date.now();var s=i&&!r;return r||(r=setTimeout(n,t)),s&&(d=e.apply(a,o),a=o=null),d};return h.clear=function(){r&&(clearTimeout(r),r=null)},h.flush=function(){r&&(d=e.apply(a,o),a=o=null,clearTimeout(r),r=null)},h}p.debounce=p;var t=p;class m{
/**
   * @param {{data: EmbedData, config: EmbedConfig, api: object}}
   *   data — previously saved data
   *   config - user config for Tool
   *   api - Editor.js API
   *   readOnly - read-only mode flag
   */
constructor({data:e,api:t,readOnly:i}){this.api=t,this._data={},this.element=null,this.readOnly=i,this.data=e
/**
   * @param {EmbedData} data - embed data
   * @param {RegExp} [data.regex] - pattern of source URLs
   * @param {string} [data.embedUrl] - URL scheme to embedded page. Use '<%= remote_id %>' to define a place to insert resource id
   * @param {string} [data.html] - iframe which contains embedded content
   * @param {number} [data.height] - iframe height
   * @param {number} [data.width] - iframe width
   * @param {string} [data.caption] - caption
   */}set data(e){var t;if(!(e instanceof Object))throw Error("Embed Tool data should be object");const{service:i,source:r,embed:o,width:a,height:l,caption:d=""}=e;this._data={service:i||this.data.service,source:r||this.data.source,embed:o||this.data.embed,width:a||this.data.width,height:l||this.data.height,caption:d||this.data.caption||""};const s=this.element;s&&((t=s.parentNode)==null||t.replaceChild(this.render(),s))}
/**
   * @returns {EmbedData}
   */get data(){if(this.element){const e=this.element.querySelector(`.${this.api.styles.input}`);this._data.caption=e?e.innerHTML:""}return this._data}
/**
   * Get plugin styles
   *
   * @returns {object}
   */get CSS(){return{baseClass:this.api.styles.block,input:this.api.styles.input,container:"embed-tool",containerLoading:"embed-tool--loading",preloader:"embed-tool__preloader",caption:"embed-tool__caption",url:"embed-tool__url",content:"embed-tool__content"}}
/**
   * Render Embed tool content
   *
   * @returns {HTMLElement}
   */render(){if(!this.data.service){const e=document.createElement("div");return this.element=e,e}const{html:e}=m.services[this.data.service],t=document.createElement("div"),i=document.createElement("div"),r=document.createElement("template"),o=this.createPreloader();t.classList.add(this.CSS.baseClass,this.CSS.container,this.CSS.containerLoading),i.classList.add(this.CSS.input,this.CSS.caption),t.appendChild(o),i.contentEditable=(!this.readOnly).toString(),i.dataset.placeholder=this.api.i18n.t("Enter a caption"),i.innerHTML=this.data.caption||"",r.innerHTML=e,r.content.firstChild.setAttribute("src",this.data.embed),r.content.firstChild.classList.add(this.CSS.content);const a=this.embedIsReady(t);return r.content.firstChild&&t.appendChild(r.content.firstChild),t.appendChild(i),a.then((()=>{t.classList.remove(this.CSS.containerLoading)})),this.element=t,t
/**
   * Creates preloader to append to container while data is loading
   *
   * @returns {HTMLElement}
   */}createPreloader(){const e=document.createElement("preloader"),t=document.createElement("div");return t.textContent=this.data.source,e.classList.add(this.CSS.preloader),t.classList.add(this.CSS.url),e.appendChild(t),e
/**
   * Save current content and return EmbedData object
   *
   * @returns {EmbedData}
   */}save(){return this.data}
/**
   * Handle pasted url and return Service object
   *
   * @param {PasteEvent} event - event with pasted data
   */onPaste(e){var t;const{key:i,data:r}=e.detail,{regex:o,embedUrl:a,width:l,height:d,id:s=(e=>e.shift()||"")}=m.services[i],c=(t=o.exec(r))==null?void 0:t.slice(1),u=c?a.replace(/<%= remote_id %>/g,s(c)):"";this.data={service:i,source:r,embed:u,width:l,height:d}}
/**
   * Analyze provided config and make object with services to use
   *
   * @param {EmbedConfig} config - configuration of embed block element
   */static prepare({config:t={}}){const{services:i={}}=t;let r=Object.entries(e);const o=Object.entries(i).filter((([e,t])=>typeof t=="boolean"&&t===!0)).map((([e])=>e)),a=Object.entries(i).filter((([e,t])=>typeof t=="object")).filter((([e,t])=>m.checkServiceConfig(t))).map((([e,t])=>{const{regex:i,embedUrl:r,html:o,height:a,width:l,id:d}=t;return[e,{regex:i,embedUrl:r,html:o,height:a,width:l,id:d}]}));o.length&&(r=r.filter((([e])=>o.includes(e)))),r=r.concat(a),m.services=r.reduce(((e,[t,i])=>t in e?(e[t]=Object.assign({},e[t],i),e):(e[t]=i,e)),{}),m.patterns=r.reduce(((e,[t,i])=>(i&&typeof i!="boolean"&&(e[t]=i.regex),e)),{})
/**
   * Check if Service config is valid
   *
   * @param {Service} config - configuration of embed block element
   * @returns {boolean}
   */}static checkServiceConfig(e){const{regex:t,embedUrl:i,html:r,height:o,width:a,id:l}=e;let d=!!(t&&t instanceof RegExp)&&!!(i&&typeof i=="string")&&!!(r&&typeof r=="string");return d=d&&(l===void 0||l instanceof Function),d=d&&(o===void 0||Number.isFinite(o)),d=d&&(a===void 0||Number.isFinite(a)),d
/**
   * Paste configuration to enable pasted URLs processing by Editor
   *
   * @returns {object} - object of patterns which contain regx for pasteConfig
   */}static get pasteConfig(){return{patterns:m.patterns}}
/**
   * Notify core that read-only mode is supported
   *
   * @returns {boolean}
   */static get isReadOnlySupported(){return!0}
/**
   * Checks that mutations in DOM have finished after appending iframe content
   *
   * @param {HTMLElement} targetNode - HTML-element mutations of which to listen
   * @returns {Promise<any>} - result that all mutations have finished
   */embedIsReady(e){let i;return new Promise(((r,o)=>{i=new MutationObserver(t.debounce(r,450)),i.observe(e,{childList:!0,subtree:!0})})).then((()=>{i.disconnect()}))}}export{m as default};

