// @editorjs/image@2.10.2 downloaded from https://ga.jspm.io/npm:@editorjs/image@2.10.2/dist/image.mjs

(function(){try{if(typeof document<"u"){var e=document.createElement("style");e.appendChild(document.createTextNode('.image-tool{--bg-color: #cdd1e0;--front-color: #388ae5;--border-color: #e8e8eb}.image-tool__image{border-radius:3px;overflow:hidden;margin-bottom:10px;padding-bottom:0}.image-tool__image-picture{max-width:100%;vertical-align:bottom;display:block}.image-tool__image-preloader{width:50px;height:50px;border-radius:50%;background-size:cover;margin:auto;position:relative;background-color:var(--bg-color);background-position:center center}.image-tool__image-preloader:after{content:"";position:absolute;z-index:3;width:60px;height:60px;border-radius:50%;border:2px solid var(--bg-color);border-top-color:var(--front-color);left:50%;top:50%;margin-top:-30px;margin-left:-30px;animation:image-preloader-spin 2s infinite linear;box-sizing:border-box}.image-tool__caption{visibility:hidden;position:absolute;bottom:0;left:0;margin-bottom:10px}.image-tool__caption[contentEditable=true][data-placeholder]:before{position:absolute!important;content:attr(data-placeholder);color:#707684;font-weight:400;display:none}.image-tool__caption[contentEditable=true][data-placeholder]:empty:before{display:block}.image-tool__caption[contentEditable=true][data-placeholder]:empty:focus:before{display:none}.image-tool--empty .image-tool__image,.image-tool--empty .image-tool__image-preloader{display:none}.image-tool--empty .image-tool__caption,.image-tool--uploading .image-tool__caption{visibility:hidden!important}.image-tool .cdx-button{display:flex;align-items:center;justify-content:center}.image-tool .cdx-button svg{height:auto;margin:0 6px 0 0}.image-tool--filled .cdx-button,.image-tool--filled .image-tool__image-preloader{display:none}.image-tool--uploading .image-tool__image{min-height:200px;display:flex;border:1px solid var(--border-color);background-color:#fff}.image-tool--uploading .image-tool__image-picture,.image-tool--uploading .cdx-button{display:none}.image-tool--withBorder .image-tool__image{border:1px solid var(--border-color)}.image-tool--withBackground .image-tool__image{padding:15px;background:var(--bg-color)}.image-tool--withBackground .image-tool__image-picture{max-width:60%;margin:0 auto}.image-tool--stretched .image-tool__image-picture{width:100%}.image-tool--caption .image-tool__caption{visibility:visible}.image-tool--caption{padding-bottom:50px}@keyframes image-preloader-spin{0%{transform:rotate(0)}to{transform:rotate(360deg)}}')),document.head.appendChild(e)}}catch(e){console.error("vite-plugin-css-injected-by-js",e)}})();const e='<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" fill="none" viewBox="0 0 24 24"><path stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 19V19C9.13623 19 8.20435 19 7.46927 18.6955C6.48915 18.2895 5.71046 17.5108 5.30448 16.5307C5 15.7956 5 14.8638 5 13V12C5 9.19108 5 7.78661 5.67412 6.77772C5.96596 6.34096 6.34096 5.96596 6.77772 5.67412C7.78661 5 9.19108 5 12 5H13.5C14.8956 5 15.5933 5 16.1611 5.17224C17.4395 5.56004 18.44 6.56046 18.8278 7.83886C19 8.40666 19 9.10444 19 10.5V10.5"/><path stroke="currentColor" stroke-linecap="round" stroke-width="2" d="M16 13V16M16 19V16M19 16H16M16 16H13"/><path stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6.5 17.5L17.5 6.5"/><path stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M18.9919 10.5H19.0015"/><path stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.9919 19H11.0015"/><path stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13L13 5"/></svg>',a='<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" fill="none" viewBox="0 0 24 24"><path stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M18.9919 9.5H19.0015"/><path stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14.5 5H14.5096"/><path stroke="currentColor" stroke-linecap="round" stroke-width="2" d="M14.625 5H15C17.2091 5 19 6.79086 19 9V9.375"/><path stroke="currentColor" stroke-width="2" d="M9.375 5L9 5C6.79086 5 5 6.79086 5 9V9.375"/><path stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.3725 5H9.38207"/><path stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 9.5H5.00957"/><path stroke="currentColor" stroke-width="2" d="M9.375 19H9C6.79086 19 5 17.2091 5 15V14.625"/><path stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.3725 19H9.38207"/><path stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 14.55H5.00957"/><path stroke="currentColor" stroke-linecap="round" stroke-width="2" d="M16 13V16M16 19V16M19 16H16M16 16H13"/></svg>',s='<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" fill="none" viewBox="0 0 24 24"><rect width="14" height="14" x="5" y="5" stroke="currentColor" stroke-width="2" rx="4"/><path stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5.13968 15.32L8.69058 11.5661C9.02934 11.2036 9.48873 11 9.96774 11C10.4467 11 10.9061 11.2036 11.2449 11.5661L15.3871 16M13.5806 14.0664L15.0132 12.533C15.3519 12.1705 15.8113 11.9668 16.2903 11.9668C16.7693 11.9668 17.2287 12.1705 17.5675 12.533L18.841 13.9634"/><path stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.7778 9.33331H13.7867"/></svg>',u='<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" fill="none" viewBox="0 0 24 24"><path stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 9L20 12L17 15"/><path stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14 12H20"/><path stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 9L4 12L7 15"/><path stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 12H10"/></svg>',k='<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" fill="none" viewBox="0 0 24 24"><path stroke="currentColor" stroke-linecap="round" stroke-width="2" d="M8 9V7.2C8 7.08954 8.08954 7 8.2 7L12 7M16 9V7.2C16 7.08954 15.9105 7 15.8 7L12 7M12 7L12 17M12 17H10M12 17H14"/></svg>';function S(e,a=null,s={}){const u=document.createElement(e);Array.isArray(a)?u.classList.add(...a):a!==null&&u.classList.add(a);for(const e in s)s.hasOwnProperty(e)&&(u[e]=s[e]);return u}var _=(e=>(e.Empty="empty",e.Uploading="uploading",e.Filled="filled",e))(_||{});class D{
/**
   * @param ui - image tool Ui module
   * @param ui.api - Editor.js API
   * @param ui.config - user config
   * @param ui.onSelectFile - callback for clicks on Select file button
   * @param ui.readOnly - read-only mode flag
   */
constructor({api:e,config:a,onSelectFile:s,readOnly:u}){this.api=e,this.config=a,this.onSelectFile=s,this.readOnly=u,this.nodes={wrapper:S("div",[this.CSS.baseClass,this.CSS.wrapper]),imageContainer:S("div",[this.CSS.imageContainer]),fileButton:this.createFileButton(),imageEl:void 0,imagePreloader:S("div",this.CSS.imagePreloader),caption:S("div",[this.CSS.input,this.CSS.caption],{contentEditable:!this.readOnly})},this.nodes.caption.dataset.placeholder=this.config.captionPlaceholder,this.nodes.imageContainer.appendChild(this.nodes.imagePreloader),this.nodes.wrapper.appendChild(this.nodes.imageContainer),this.nodes.wrapper.appendChild(this.nodes.caption),this.nodes.wrapper.appendChild(this.nodes.fileButton)
/**
   * Apply visual representation of activated tune
   * @param tuneName - one of available tunes {@link Tunes.tunes}
   * @param status - true for enable, false for disable
   */}applyTune(e,a){this.nodes.wrapper.classList.toggle(`${this.CSS.wrapper}--${e}`,a)}render(){return this.toggleStatus("empty"),this.nodes.wrapper
/**
   * Shows uploading preloader
   * @param src - preview source
   */}showPreloader(e){this.nodes.imagePreloader.style.backgroundImage=`url(${e})`,this.toggleStatus("uploading")}hidePreloader(){this.nodes.imagePreloader.style.backgroundImage="",this.toggleStatus("empty")
/**
   * Shows an image
   * @param url - image source
   */}fillImage(e){const a=/\.mp4$/.test(e)?"VIDEO":"IMG",s={src:e};let u="load";a==="VIDEO"&&(s.autoplay=!0,s.loop=!0,s.muted=!0,s.playsinline=!0,u="loadeddata"),this.nodes.imageEl=S(a,this.CSS.imageEl,s),this.nodes.imageEl.addEventListener(u,(()=>{this.toggleStatus("filled"),this.nodes.imagePreloader!==void 0&&(this.nodes.imagePreloader.style.backgroundImage="")})),this.nodes.imageContainer.appendChild(this.nodes.imageEl)
/**
   * Shows caption input
   * @param text - caption content text
   */}fillCaption(e){this.nodes.caption!==void 0&&(this.nodes.caption.innerHTML=e)}
/**
   * Changes UI status
   * @param status - see {@link Ui.status} constants
   */toggleStatus(e){for(const a in _)if(Object.prototype.hasOwnProperty.call(_,a)){const s=_[a];this.nodes.wrapper.classList.toggle(`${this.CSS.wrapper}--${s}`,s===e)}}get CSS(){return{baseClass:this.api.styles.block,loading:this.api.styles.loader,input:this.api.styles.input,button:this.api.styles.button,wrapper:"image-tool",imageContainer:"image-tool__image",imagePreloader:"image-tool__image-preloader",imageEl:"image-tool__image-picture",caption:"image-tool__caption"}}createFileButton(){const e=S("div",[this.CSS.button]);return e.innerHTML=this.config.buttonContent??`${s} ${this.api.i18n.t("Select an Image")}`,e.addEventListener("click",(()=>{this.onSelectFile()})),e}}function U(e){return e&&e.__esModule&&Object.prototype.hasOwnProperty.call(e,"default")?e.default:e}var C={exports:{}};(function(e){(function(a,s){e.exports=s()})(window,(function(){return function(e){var a={};function r(s){if(a[s])return a[s].exports;var u=a[s]={i:s,l:!1,exports:{}};return e[s].call(u.exports,u,u.exports,r),u.l=!0,u.exports}return r.m=e,r.c=a,r.d=function(e,a,s){r.o(e,a)||Object.defineProperty(e,a,{enumerable:!0,get:s})},r.r=function(e){typeof Symbol<"u"&&Symbol.toStringTag&&Object.defineProperty(e,Symbol.toStringTag,{value:"Module"}),Object.defineProperty(e,"__esModule",{value:!0})},r.t=function(e,a){if(1&a&&(e=r(e)),8&a||4&a&&typeof e=="object"&&e&&e.__esModule)return e;var s=Object.create(null);if(r.r(s),Object.defineProperty(s,"default",{enumerable:!0,value:e}),2&a&&typeof e!="string")for(var u in e)r.d(s,u,function(a){return e[a]}.bind(null,u));return s},r.n=function(e){var a=e&&e.__esModule?function(){return e.default}:function(){return e};return r.d(a,"a",a),a},r.o=function(e,a){return Object.prototype.hasOwnProperty.call(e,a)},r.p="",r(r.s=3)}([function(e,a){var s;s=function(){return this}();try{s=s||new Function("return this")()}catch{typeof window=="object"&&(s=window)}e.exports=s},function(e,a,s){(function(e){var u=s(2),k=setTimeout;function v(){}function l(e){if(!(this instanceof l))throw new TypeError("Promises must be constructed via new");if(typeof e!="function")throw new TypeError("not a function");this._state=0,this._handled=!1,this._value=void 0,this._deferreds=[],t(e,this)}function f(e,a){for(;e._state===3;)e=e._value;e._state!==0?(e._handled=!0,l._immediateFn((function(){var s=e._state===1?a.onFulfilled:a.onRejected;if(s!==null){var u;try{u=s(e._value)}catch(e){return void y(a.promise,e)}p(a.promise,u)}else(e._state===1?p:y)(a.promise,e._value)}))):e._deferreds.push(a)}function p(e,a){try{if(a===e)throw new TypeError("A promise cannot be resolved with itself.");if(a&&(typeof a=="object"||typeof a=="function")){var s=a.then;if(a instanceof l)return e._state=3,e._value=a,void w(e);if(typeof s=="function")return void t((u=s,k=a,function(){u.apply(k,arguments)}),e)}e._state=1,e._value=a,w(e)}catch(a){y(e,a)}var u,k}function y(e,a){e._state=2,e._value=a,w(e)}function w(e){e._state===2&&e._deferreds.length===0&&l._immediateFn((function(){e._handled||l._unhandledRejectionFn(e._value)}));for(var a=0,s=e._deferreds.length;a<s;a++)f(e,e._deferreds[a]);e._deferreds=null}function b(e,a,s){this.onFulfilled=typeof e=="function"?e:null,this.onRejected=typeof a=="function"?a:null,this.promise=s}function t(e,a){var s=!1;try{e((function(e){s||(s=!0,p(a,e))}),(function(e){s||(s=!0,y(a,e))}))}catch(e){if(s)return;s=!0,y(a,e)}}l.prototype.catch=function(e){return this.then(null,e)},l.prototype.then=function(e,a){var s=new this.constructor(v);return f(this,new b(e,a,s)),s},l.prototype.finally=u.a,l.all=function(e){return new l((function(a,s){if(!e||e.length===void 0)throw new TypeError("Promise.all accepts an array");var u=Array.prototype.slice.call(e);if(u.length===0)return a([]);var k=u.length;function h(e,_){try{if(_&&(typeof _=="object"||typeof _=="function")){var C=_.then;if(typeof C=="function")return void C.call(_,(function(a){h(e,a)}),s)}u[e]=_,--k==0&&a(u)}catch(e){s(e)}}for(var _=0;_<u.length;_++)h(_,u[_])}))},l.resolve=function(e){return e&&typeof e=="object"&&e.constructor===l?e:new l((function(a){a(e)}))},l.reject=function(e){return new l((function(a,s){s(e)}))},l.race=function(e){return new l((function(a,s){for(var u=0,k=e.length;u<k;u++)e[u].then(a,s)}))},l._immediateFn=typeof e=="function"&&function(a){e(a)}||function(e){k(e,0)},l._unhandledRejectionFn=function(e){typeof console<"u"&&console&&console.warn("Possible Unhandled Promise Rejection:",e)},a.a=l}).call(this,s(5).setImmediate)},function(e,a,s){a.a=function(e){var a=this.constructor;return this.then((function(s){return a.resolve(e()).then((function(){return s}))}),(function(s){return a.resolve(e()).then((function(){return a.reject(s)}))}))}},function(e,a,s){function o(e){return(o=typeof Symbol=="function"&&typeof Symbol.iterator=="symbol"?function(e){return typeof e}:function(e){return e&&typeof Symbol=="function"&&e.constructor===Symbol&&e!==Symbol.prototype?"symbol":typeof e})(e)}s(4);var u,k,_,C,E,T,j,M=s(8),F=(k=function(e){return new Promise((function(a,s){e=C(e),(e=E(e)).beforeSend&&e.beforeSend();var u=window.XMLHttpRequest?new window.XMLHttpRequest:new window.ActiveXObject("Microsoft.XMLHTTP");u.open(e.method,e.url),u.setRequestHeader("X-Requested-With","XMLHttpRequest"),Object.keys(e.headers).forEach((function(a){var s=e.headers[a];u.setRequestHeader(a,s)}));var k=e.ratio;u.upload.addEventListener("progress",(function(a){var s=Math.round(a.loaded/a.total*100),u=Math.ceil(s*k/100);e.progress(Math.min(u,100))}),!1),u.addEventListener("progress",(function(a){var s=Math.round(a.loaded/a.total*100),u=Math.ceil(s*(100-k)/100)+k;e.progress(Math.min(u,100))}),!1),u.onreadystatechange=function(){if(u.readyState===4){var e=u.response;try{e=JSON.parse(e)}catch{}var k=M.parseHeaders(u.getAllResponseHeaders()),_={body:e,code:u.status,headers:k};j(u.status)?a(_):s(_)}},u.send(e.data)}))},_=function(e){return e.method="POST",k(e)},C=function(){var e=arguments.length>0&&arguments[0]!==void 0?arguments[0]:{};if(e.url&&typeof e.url!="string")throw new Error("Url must be a string");if(e.url=e.url||"",e.method&&typeof e.method!="string")throw new Error("`method` must be a string or null");if(e.method=e.method?e.method.toUpperCase():"GET",e.headers&&o(e.headers)!=="object")throw new Error("`headers` must be an object or null");if(e.headers=e.headers||{},e.type&&(typeof e.type!="string"||!Object.values(u).includes(e.type)))throw new Error("`type` must be taken from module's «contentType» library");if(e.progress&&typeof e.progress!="function")throw new Error("`progress` must be a function or null");if(e.progress=e.progress||function(e){},e.beforeSend=e.beforeSend||function(e){},e.ratio&&typeof e.ratio!="number")throw new Error("`ratio` must be a number");if(e.ratio<0||e.ratio>100)throw new Error("`ratio` must be in a 0-100 interval");if(e.ratio=e.ratio||90,e.accept&&typeof e.accept!="string")throw new Error("`accept` must be a string with a list of allowed mime-types");if(e.accept=e.accept||"*/*",e.multiple&&typeof e.multiple!="boolean")throw new Error("`multiple` must be a true or false");if(e.multiple=e.multiple||!1,e.fieldName&&typeof e.fieldName!="string")throw new Error("`fieldName` must be a string");return e.fieldName=e.fieldName||"files",e},E=function(e){switch(e.method){case"GET":var a=T(e.data,u.URLENCODED);delete e.data,e.url=/\?/.test(e.url)?e.url+"&"+a:e.url+"?"+a;break;case"POST":case"PUT":case"DELETE":case"UPDATE":var s=function(){return(arguments.length>0&&arguments[0]!==void 0?arguments[0]:{}).type||u.JSON}(e);(M.isFormData(e.data)||M.isFormElement(e.data))&&(s=u.FORM),e.data=T(e.data,s),s!==F.contentType.FORM&&(e.headers["content-type"]=s)}return e},T=function(){var e=arguments.length>0&&arguments[0]!==void 0?arguments[0]:{};switch(arguments.length>1?arguments[1]:void 0){case u.URLENCODED:return M.urlEncode(e);case u.JSON:return M.jsonEncode(e);case u.FORM:return M.formEncode(e);default:return e}},j=function(e){return e>=200&&e<300},{contentType:u={URLENCODED:"application/x-www-form-urlencoded; charset=utf-8",FORM:"multipart/form-data",JSON:"application/json; charset=utf-8"},request:k,get:function(e){return e.method="GET",k(e)},post:_,transport:function(e){return e=C(e),M.selectFiles(e).then((function(a){for(var s=new FormData,u=0;u<a.length;u++)s.append(e.fieldName,a[u],a[u].name);M.isObject(e.data)&&Object.keys(e.data).forEach((function(a){var u=e.data[a];s.append(a,u)}));var k=e.beforeSend;return e.beforeSend=function(){return k(a)},e.data=s,_(e)}))},selectFiles:function(e){return delete(e=C(e)).beforeSend,M.selectFiles(e)}});e.exports=F},function(e,a,s){s.r(a);var u=s(1);window.Promise=window.Promise||u.a},function(e,a,s){(function(e){var u=e!==void 0&&e||typeof self<"u"&&self||window,k=Function.prototype.apply;function v(e,a){this._id=e,this._clearFn=a}a.setTimeout=function(){return new v(k.call(setTimeout,u,arguments),clearTimeout)},a.setInterval=function(){return new v(k.call(setInterval,u,arguments),clearInterval)},a.clearTimeout=a.clearInterval=function(e){e&&e.close()},v.prototype.unref=v.prototype.ref=function(){},v.prototype.close=function(){this._clearFn.call(u,this._id)},a.enroll=function(e,a){clearTimeout(e._idleTimeoutId),e._idleTimeout=a},a.unenroll=function(e){clearTimeout(e._idleTimeoutId),e._idleTimeout=-1},a._unrefActive=a.active=function(e){clearTimeout(e._idleTimeoutId);var a=e._idleTimeout;a>=0&&(e._idleTimeoutId=setTimeout((function(){e._onTimeout&&e._onTimeout()}),a))},s(6),a.setImmediate=typeof self<"u"&&self.setImmediate||e!==void 0&&e.setImmediate||this&&this.setImmediate,a.clearImmediate=typeof self<"u"&&self.clearImmediate||e!==void 0&&e.clearImmediate||this&&this.clearImmediate}).call(this,s(0))},function(e,a,s){(function(e,a){(function(e,s){if(!e.setImmediate){var u,k,_,C,E,T=1,j={},M=!1,F=e.document,x=Object.getPrototypeOf&&Object.getPrototypeOf(e);x=x&&x.setTimeout?x:e,{}.toString.call(e.process)==="[object process]"?u=function(e){a.nextTick((function(){m(e)}))}:function(){if(e.postMessage&&!e.importScripts){var a=!0,s=e.onmessage;return e.onmessage=function(){a=!1},e.postMessage("","*"),e.onmessage=s,a}}()?(C="setImmediate$"+Math.random()+"$",E=function(a){a.source===e&&typeof a.data=="string"&&a.data.indexOf(C)===0&&m(+a.data.slice(C.length))},e.addEventListener?e.addEventListener("message",E,!1):e.attachEvent("onmessage",E),u=function(a){e.postMessage(C+a,"*")}):e.MessageChannel?((_=new MessageChannel).port1.onmessage=function(e){m(e.data)},u=function(e){_.port2.postMessage(e)}):F&&"onreadystatechange"in F.createElement("script")?(k=F.documentElement,u=function(e){var a=F.createElement("script");a.onreadystatechange=function(){m(e),a.onreadystatechange=null,k.removeChild(a),a=null},k.appendChild(a)}):u=function(e){setTimeout(m,0,e)},x.setImmediate=function(e){typeof e!="function"&&(e=new Function(""+e));for(var a=new Array(arguments.length-1),s=0;s<a.length;s++)a[s]=arguments[s+1];var k={callback:e,args:a};return j[T]=k,u(T),T++},x.clearImmediate=g}function g(e){delete j[e]}function m(e){if(M)setTimeout(m,0,e);else{var a=j[e];if(a){M=!0;try{(function(e){var a=e.callback,u=e.args;switch(u.length){case 0:a();break;case 1:a(u[0]);break;case 2:a(u[0],u[1]);break;case 3:a(u[0],u[1],u[2]);break;default:a.apply(s,u)}})(a)}finally{g(e),M=!1}}}}})(typeof self>"u"?e===void 0?this:e:self)}).call(this,s(0),s(7))},function(e,a){var s,u,k=e.exports={};function d(){throw new Error("setTimeout has not been defined")}function v(){throw new Error("clearTimeout has not been defined")}function l(e){if(s===setTimeout)return setTimeout(e,0);if((s===d||!s)&&setTimeout)return s=setTimeout,setTimeout(e,0);try{return s(e,0)}catch{try{return s.call(null,e,0)}catch{return s.call(this,e,0)}}}(function(){try{s=typeof setTimeout=="function"?setTimeout:d}catch{s=d}try{u=typeof clearTimeout=="function"?clearTimeout:v}catch{u=v}})();var _,C=[],E=!1,T=-1;function b(){E&&_&&(E=!1,_.length?C=_.concat(C):T=-1,C.length&&t())}function t(){if(!E){var e=l(b);E=!0;for(var a=C.length;a;){for(_=C,C=[];++T<a;)_&&_[T].run();T=-1,a=C.length}_=null,E=!1,function(e){if(u===clearTimeout)return clearTimeout(e);if((u===v||!u)&&clearTimeout)return u=clearTimeout,clearTimeout(e);try{u(e)}catch{try{return u.call(null,e)}catch{return u.call(this,e)}}}(e)}}function n(e,a){this.fun=e,this.array=a}function c(){}k.nextTick=function(e){var a=new Array(arguments.length-1);if(arguments.length>1)for(var s=1;s<arguments.length;s++)a[s-1]=arguments[s];C.push(new n(e,a)),C.length!==1||E||l(t)},n.prototype.run=function(){this.fun.apply(null,this.array)},k.title="browser",k.browser=!0,k.env={},k.argv=[],k.version="",k.versions={},k.on=c,k.addListener=c,k.once=c,k.off=c,k.removeListener=c,k.removeAllListeners=c,k.emit=c,k.prependListener=c,k.prependOnceListener=c,k.listeners=function(e){return[]},k.binding=function(e){throw new Error("process.binding is not supported")},k.cwd=function(){return"/"},k.chdir=function(e){throw new Error("process.chdir is not supported")},k.umask=function(){return 0}},function(e,a,s){function o(e,a){for(var s=0;s<a.length;s++){var u=a[s];u.enumerable=u.enumerable||!1,u.configurable=!0,"value"in u&&(u.writable=!0),Object.defineProperty(e,u.key,u)}}var u=s(9);e.exports=function(){function d(){(function(e,a){if(!(e instanceof a))throw new TypeError("Cannot call a class as a function")})(this,d)}var e,a,s;return e=d,s=[{key:"urlEncode",value:function(e){return u(e)}},{key:"jsonEncode",value:function(e){return JSON.stringify(e)}},{key:"formEncode",value:function(e){if(this.isFormData(e))return e;if(this.isFormElement(e))return new FormData(e);if(this.isObject(e)){var a=new FormData;return Object.keys(e).forEach((function(s){var u=e[s];a.append(s,u)})),a}throw new Error("`data` must be an instance of Object, FormData or <FORM> HTMLElement")}},{key:"isObject",value:function(e){return Object.prototype.toString.call(e)==="[object Object]"}},{key:"isFormData",value:function(e){return e instanceof FormData}},{key:"isFormElement",value:function(e){return e instanceof HTMLFormElement}},{key:"selectFiles",value:function(){var e=arguments.length>0&&arguments[0]!==void 0?arguments[0]:{};return new Promise((function(a,s){var u=document.createElement("INPUT");u.type="file",e.multiple&&u.setAttribute("multiple","multiple"),e.accept&&u.setAttribute("accept",e.accept),u.style.display="none",document.body.appendChild(u),u.addEventListener("change",(function(e){var s=e.target.files;a(s),document.body.removeChild(u)}),!1),u.click()}))}},{key:"parseHeaders",value:function(e){var a=e.trim().split(/[\r\n]+/),s={};return a.forEach((function(e){var a=e.split(": "),u=a.shift(),k=a.join(": ");u&&(s[u]=k)})),s}}],(a=null)&&o(e.prototype,a),s&&o(e,s),d}()},function(e,a){var r=function(e){return encodeURIComponent(e).replace(/[!'()*]/g,escape).replace(/%20/g,"+")},o=function(e,a,s,u){return a=a||null,s=s||"&",u=u||null,e?function(e){for(var a=new Array,s=0;s<e.length;s++)e[s]&&a.push(e[s]);return a}(Object.keys(e).map((function(k){var _,C,E=k;if(u&&(E=u+"["+E+"]"),typeof e[k]=="object"&&e[k]!==null)_=o(e[k],null,s,E);else{a&&(C=E,E=!isNaN(parseFloat(C))&&isFinite(C)?a+Number(E):E);var T=e[k];T=(T=(T=(T=T===!0?"1":T)===!1?"0":T)===0?"0":T)||"",_=r(E)+"="+r(T)}return _}))).join(s).replace(/[!'()*]/g,""):""};e.exports=o}])}))})(C);var E=C.exports;const T=U(E);function O(e){return e!==void 0&&typeof e.then=="function"}class A{
/**
   * @param params - uploader module params
   * @param params.config - image tool config
   * @param params.onUpload - one callback for all uploading (file, url, d-n-d, pasting)
   * @param params.onError - callback for uploading errors
   */
constructor({config:e,onUpload:a,onError:s}){this.config=e,this.onUpload=a,this.onError=s
/**
   * Handle clicks on the upload file button
   * Fires ajax.transport()
   * @param onPreview - callback fired when preview is ready
   */}uploadSelectedFile({onPreview:e}){const i=function(a){const s=new FileReader;s.readAsDataURL(a),s.onload=a=>{e(a.target.result)}};let a;if(this.config.uploader&&typeof this.config.uploader.uploadByFile=="function"){const e=this.config.uploader.uploadByFile;a=T.selectFiles({accept:this.config.types??"image/*"}).then((a=>{i(a[0]);const s=e(a[0]);return O(s)||console.warn("Custom uploader method uploadByFile should return a Promise"),s}))}else a=T.transport({url:this.config.endpoints.byFile,data:this.config.additionalRequestData,accept:this.config.types??"image/*",headers:this.config.additionalRequestHeaders,beforeSend:e=>{i(e[0])},fieldName:this.config.field??"image"}).then((e=>e.body));a.then((e=>{this.onUpload(e)})).catch((e=>{this.onError(e)}))}
/**
   * Handle clicks on the upload file button
   * Fires ajax.post()
   * @param url - image source url
   */uploadByUrl(e){let a;this.config.uploader&&typeof this.config.uploader.uploadByUrl=="function"?(a=this.config.uploader.uploadByUrl(e),O(a)||console.warn("Custom uploader method uploadByUrl should return a Promise")):a=T.post({url:this.config.endpoints.byUrl,data:Object.assign({url:e},this.config.additionalRequestData),type:T.contentType.JSON,headers:this.config.additionalRequestHeaders}).then((e=>e.body)),a.then((e=>{this.onUpload(e)})).catch((e=>{this.onError(e)}))
/**
   * Handle clicks on the upload file button
   * Fires ajax.post()
   * @param file - file pasted by drag-n-drop
   * @param onPreview - file pasted by drag-n-drop
   */}uploadByFile(e,{onPreview:a}){const s=new FileReader;s.readAsDataURL(e),s.onload=e=>{a(e.target.result)};let u;if(this.config.uploader&&typeof this.config.uploader.uploadByFile=="function")u=this.config.uploader.uploadByFile(e),O(u)||console.warn("Custom uploader method uploadByFile should return a Promise");else{const a=new FormData;a.append(this.config.field??"image",e),this.config.additionalRequestData&&Object.keys(this.config.additionalRequestData).length&&Object.entries(this.config.additionalRequestData).forEach((([e,s])=>{a.append(e,s)})),u=T.post({url:this.config.endpoints.byFile,data:a,type:T.contentType.JSON,headers:this.config.additionalRequestHeaders}).then((e=>e.body))}u.then((e=>{this.onUpload(e)})).catch((e=>{this.onError(e)}))}}
/**
 * Image Tool for the Editor.js
 * @author CodeX <team@codex.so>
 * @license MIT
 * @see {@link https://github.com/editor-js/image}
 *
 * To developers.
 * To simplify Tool structure, we split it to 4 parts:
 *  1) index.ts — main Tool's interface, public API and methods for working with data
 *  2) uploader.ts — module that has methods for sending files via AJAX: from device, by URL or File pasting
 *  3) ui.ts — module for UI manipulations: render, showing preloader, etc
 *
 * For debug purposes there is a testing server
 * that can save uploaded files and return a Response {@link UploadResponseFormat}
 *
 *       $ node dev/server.js
 *
 * It will expose 8008 port, so you can pass http://localhost:8008 with the Tools config:
 *
 * image: {
 *   class: ImageTool,
 *   config: {
 *     endpoints: {
 *       byFile: 'http://localhost:8008/uploadFile',
 *       byUrl: 'http://localhost:8008/fetchUrl',
 *     }
 *   },
 * },
 */class P{
/**
   * @param tool - tool properties got from editor.js
   * @param tool.data - previously saved data
   * @param tool.config - user config for Tool
   * @param tool.api - Editor.js API
   * @param tool.readOnly - read-only mode flag
   * @param tool.block - current Block API
   */
constructor({data:e,config:a,api:s,readOnly:u,block:k}){this.isCaptionEnabled=null,this.api=s,this.block=k,this.config={endpoints:a.endpoints,additionalRequestData:a.additionalRequestData,additionalRequestHeaders:a.additionalRequestHeaders,field:a.field,types:a.types,captionPlaceholder:this.api.i18n.t(a.captionPlaceholder??"Caption"),buttonContent:a.buttonContent,uploader:a.uploader,actions:a.actions,features:a.features||{}},this.uploader=new A({config:this.config,onUpload:e=>this.onUpload(e),onError:e=>this.uploadingFailed(e)}),this.ui=new D({api:s,config:this.config,onSelectFile:()=>{this.uploader.uploadSelectedFile({onPreview:e=>{this.ui.showPreloader(e)}})},readOnly:u}),this._data={caption:"",withBorder:!1,withBackground:!1,stretched:!1,file:{url:""}},this.data=e}static get isReadOnlySupported(){return!0}static get toolbox(){return{icon:s,title:"Image"}}static get tunes(){return[{name:"withBorder",icon:a,title:"With border",toggle:!0},{name:"stretched",icon:u,title:"Stretch image",toggle:!0},{name:"withBackground",icon:e,title:"With background",toggle:!0}]}render(){var e,a,s;return(((e=this.config.features)==null?void 0:e.caption)===!0||((a=this.config.features)==null?void 0:a.caption)===void 0||((s=this.config.features)==null?void 0:s.caption)==="optional"&&this.data.caption)&&(this.isCaptionEnabled=!0),this.ui.render()
/**
   * Validate data: check if Image exists
   * @param savedData — data received after saving
   * @returns false if saved data is not correct, otherwise true
   */}validate(e){return!!e.file.url}save(){const e=this.ui.nodes.caption;return this._data.caption=e.innerHTML,this.data
/**
   * Returns configuration for block tunes: add background, add border, stretch image
   * @returns TunesMenuConfig
   */}renderSettings(){var e;const a=P.tunes.concat(this.config.actions||[]),s={border:"withBorder",background:"withBackground",stretch:"stretched",caption:"caption"};((e=this.config.features)==null?void 0:e.caption)==="optional"&&a.push({name:"caption",icon:k,title:"With caption",toggle:!0});const u=a.filter((e=>{var a,u;const k=Object.keys(s).find((a=>s[a]===e.name));return k==="caption"?((a=this.config.features)==null?void 0:a.caption)!==!1:k==null||((u=this.config.features)==null?void 0:u[k])!==!1})),r=e=>{let a=this.data[e.name];return e.name==="caption"&&(a=this.isCaptionEnabled??a),a};return u.map((e=>({icon:e.icon,label:this.api.i18n.t(e.title),name:e.name,toggle:e.toggle,isActive:r(e),onActivate:()=>{if(typeof e.action=="function"){e.action(e.name);return}let a=!r(e);e.name==="caption"&&(this.isCaptionEnabled=!(this.isCaptionEnabled??!1),a=this.isCaptionEnabled),this.tuneToggled(e.name,a)}})))}appendCallback(){this.ui.nodes.fileButton.click()}static get pasteConfig(){return{tags:[{img:{src:!0}}],patterns:{image:/https?:\/\/\S+\.(gif|jpe?g|tiff|png|svg|webp)(\?[a-z0-9=]*)?$/i},files:{mimeTypes:["image/*"]}}}
/**
   * Specify paste handlers
   * @see {@link https://github.com/codex-team/editor.js/blob/master/docs/tools.md#paste-handling}
   * @param event - editor.js custom paste event
   *                              {@link https://github.com/codex-team/editor.js/blob/master/types/tools/paste-events.d.ts}
   */async onPaste(e){switch(e.type){case"tag":{const a=e.detail.data;if(/^blob:/.test(a.src)){const e=await(await fetch(a.src)).blob();this.uploadFile(e);break}this.uploadUrl(a.src);break}case"pattern":{const a=e.detail.data;this.uploadUrl(a);break}case"file":{const a=e.detail.file;this.uploadFile(a);break}}}
/**
   * Stores all Tool's data
   * @param data - data in Image Tool format
   */set data(e){this.image=e.file,this._data.caption=e.caption||"",this.ui.fillCaption(this._data.caption),P.tunes.forEach((({name:a})=>{const s=typeof e[a]<"u"&&(e[a]===!0||e[a]==="true");this.setTune(a,s)})),e.caption&&this.setTune("caption",!0)}get data(){return this._data}
/**
   * Set new image file
   * @param file - uploaded file data
   */set image(e){this._data.file=e||{url:""},e&&e.url&&this.ui.fillImage(e.url)
/**
   * File uploading callback
   * @param response - uploading server response
   */}onUpload(e){e.success&&e.file?this.image=e.file:this.uploadingFailed("incorrect response: "+JSON.stringify(e))}
/**
   * Handle uploader errors
   * @param errorText - uploading error info
   */uploadingFailed(e){console.log("Image Tool: uploading failed because of",e),this.api.notifier.show({message:this.api.i18n.t("Couldn’t upload image. Please try another."),style:"error"}),this.ui.hidePreloader()
/**
   * Callback fired when Block Tune is activated
   * @param tuneName - tune that has been clicked
   * @param state - new state
   */}tuneToggled(e,a){e==="caption"?(this.ui.applyTune(e,a),a==!1&&(this._data.caption="",this.ui.fillCaption(""))):this.setTune(e,a)}
/**
   * Set one tune
   * @param tuneName - {@link Tunes.tunes}
   * @param value - tune state
   */setTune(e,a){this._data[e]=a,this.ui.applyTune(e,a),e==="stretched"&&Promise.resolve().then((()=>{this.block.stretched=a})).catch((e=>{console.error(e)}))
/**
   * Show preloader and upload image file
   * @param file - file that is currently uploading (from paste)
   */}uploadFile(e){this.uploader.uploadByFile(e,{onPreview:e=>{this.ui.showPreloader(e)}})}
/**
   * Show preloader and upload image by target url
   * @param url - url pasted
   */uploadUrl(e){this.ui.showPreloader(e),this.uploader.uploadByUrl(e)}}export{P as default};

