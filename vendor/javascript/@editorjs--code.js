var t="undefined"!==typeof globalThis?globalThis:"undefined"!==typeof self?self:global;var a={};!function(t,i){a=i()}(window,(function(){return function(t){var a={};function n(i){if(a[i])return a[i].exports;var l=a[i]={i:i,l:!1,exports:{}};return t[i].call(l.exports,l,l.exports,n),l.l=!0,l.exports}return n.m=t,n.c=a,n.d=function(t,a,i){n.o(t,a)||Object.defineProperty(t,a,{enumerable:!0,get:i})},n.r=function(t){"undefined"!=typeof Symbol&&Symbol.toStringTag&&Object.defineProperty(t,Symbol.toStringTag,{value:"Module"}),Object.defineProperty(t,"__esModule",{value:!0})},n.t=function(t,a){if(1&a&&(t=n(t)),8&a)return t;if(4&a&&"object"==typeof t&&t&&t.__esModule)return t;var i=Object.create(null);if(n.r(i),Object.defineProperty(i,"default",{enumerable:!0,value:t}),2&a&&"string"!=typeof t)for(var l in t)n.d(i,l,function(a){return t[a]}.bind(null,l));return i},n.n=function(t){var a=t&&t.__esModule?function(){return t.default}:function(){return t};return n.d(a,"a",a),a},n.o=function(t,a){return Object.prototype.hasOwnProperty.call(t,a)},n.p="/",n(n.s=4)}([function(t,a,i){var l=i(1),d=i(2);"string"==typeof(d=d.__esModule?d.default:d)&&(d=[[t.i,d,""]]);var h={insert:"head",singleton:!1};l(d,h);t.exports=d.locals||{}},function(t,a,i){var l,o=function(){return void 0===l&&(l=Boolean(window&&document&&document.all&&!window.atob)),l},d=function(){var t={};return function(a){if(void 0===t[a]){var i=document.querySelector(a);if(window.HTMLIFrameElement&&i instanceof window.HTMLIFrameElement)try{i=i.contentDocument.head}catch(t){i=null}t[a]=i}return t[a]}}(),h=[];function c(t){for(var a=-1,i=0;i<h.length;i++)if(h[i].identifier===t){a=i;break}return a}function s(t,a){for(var i={},l=[],d=0;d<t.length;d++){var v=t[d],g=a.base?v[0]+a.base:v[0],y=i[g]||0,m="".concat(g," ").concat(y);i[g]=y+1;var w=c(m),x={css:v[1],media:v[2],sourceMap:v[3]};-1!==w?(h[w].references++,h[w].updater(x)):h.push({identifier:m,updater:b(x,a),references:1}),l.push(m)}return l}function u(t){var a=document.createElement("style"),l=t.attributes||{};if(void 0===l.nonce){var h=i.nc;h&&(l.nonce=h)}if(Object.keys(l).forEach((function(t){a.setAttribute(t,l[t])})),"function"==typeof t.insert)t.insert(a);else{var v=d(t.insert||"head");if(!v)throw new Error("Couldn't find a style target. This probably means that the value for the 'insert' parameter is invalid.");v.appendChild(a)}return a}var v,g=(v=[],function(t,a){return v[t]=a,v.filter(Boolean).join("\n")});function f(t,a,i,l){var d=i?"":l.media?"@media ".concat(l.media," {").concat(l.css,"}"):l.css;if(t.styleSheet)t.styleSheet.cssText=g(a,d);else{var h=document.createTextNode(d),v=t.childNodes;v[a]&&t.removeChild(v[a]),v.length?t.insertBefore(h,v[a]):t.appendChild(h)}}function p(t,a,i){var l=i.css,d=i.media,h=i.sourceMap;if(d?t.setAttribute("media",d):t.removeAttribute("media"),h&&btoa&&(l+="\n/*# sourceMappingURL=data:application/json;base64,".concat(btoa(unescape(encodeURIComponent(JSON.stringify(h))))," */")),t.styleSheet)t.styleSheet.cssText=l;else{for(;t.firstChild;)t.removeChild(t.firstChild);t.appendChild(document.createTextNode(l))}}var y=null,m=0;function b(t,a){var i,l,d;if(a.singleton){var h=m++;i=y||(y=u(a)),l=f.bind(null,i,h,!1),d=f.bind(null,i,h,!0)}else i=u(a),l=p.bind(null,i,a),d=function(){!function(t){if(null===t.parentNode)return!1;t.parentNode.removeChild(t)}(i)};return l(t),function(a){if(a){if(a.css===t.css&&a.media===t.media&&a.sourceMap===t.sourceMap)return;l(t=a)}else d()}}t.exports=function(t,a){(a=a||{}).singleton||"boolean"==typeof a.singleton||(a.singleton=o());var i=s(t=t||[],a);return function(t){if(t=t||[],"[object Array]"===Object.prototype.toString.call(t)){for(var l=0;l<i.length;l++){var d=c(i[l]);h[d].references--}for(var v=s(t,a),g=0;g<i.length;g++){var y=c(i[g]);0===h[y].references&&(h[y].updater(),h.splice(y,1))}i=v}}}},function(t,a,i){(a=i(3)(!1)).push([t.i,".ce-code__textarea {\n    min-height: 200px;\n    font-family: Menlo, Monaco, Consolas, Courier New, monospace;\n    color: #41314e;\n    line-height: 1.6em;\n    font-size: 12px;\n    background: #f8f7fa;\n    border: 1px solid #f1f1f4;\n    box-shadow: none;\n    white-space: pre;\n    word-wrap: normal;\n    overflow-x: auto;\n    resize: vertical;\n}\n",""]),t.exports=a},function(a,i,l){a.exports=function(a){var i=[];return i.toString=function(){return this.map((function(t){var i=function(t,a){var i=t[1]||"",l=t[3];if(!l)return i;if(a&&"function"==typeof btoa){var d=(v=l,g=btoa(unescape(encodeURIComponent(JSON.stringify(v)))),y="sourceMappingURL=data:application/json;charset=utf-8;base64,".concat(g),"/*# ".concat(y," */")),h=l.sources.map((function(t){return"/*# sourceURL=".concat(l.sourceRoot||"").concat(t," */")}));return[i].concat(h).concat([d]).join("\n")}var v,g,y;return[i].join("\n")}(t,a);return t[2]?"@media ".concat(t[2]," {").concat(i,"}"):i})).join("")},i.i=function(a,l,d){"string"==typeof a&&(a=[[null,a,""]]);var h={};if(d)for(var v=0;v<(this||t).length;v++){var g=(this||t)[v][0];null!=g&&(h[g]=!0)}for(var y=0;y<a.length;y++){var m=[].concat(a[y]);d&&h[m[0]]||(l&&(m[2]?m[2]="".concat(l," and ").concat(m[2]):m[2]=l),i.push(m))}},i}},function(a,i,l){l.r(i),l.d(i,"default",(function(){return d}));l(0);function r(t,a){for(var i=0;i<a.length;i++){var l=a[i];l.enumerable=l.enumerable||!1,l.configurable=!0,"value"in l&&(l.writable=!0),Object.defineProperty(t,l.key,l)}}function o(t,a,i){return a&&r(t.prototype,a),i&&r(t,i),t
/**
     * CodeTool for Editor.js
     *
     * @author CodeX (team@ifmo.su)
     * @copyright CodeX 2018
     * @license MIT
     * @version 2.0.0
     */}var d=function(){function e(a){var i=a.data,l=a.config,d=a.api,h=a.readOnly;!function(t,a){if(!(t instanceof a))throw new TypeError("Cannot call a class as a function")}(this||t,e),(this||t).api=d,(this||t).readOnly=h,(this||t).placeholder=(this||t).api.i18n.t(l.placeholder||e.DEFAULT_PLACEHOLDER),(this||t).CSS={baseClass:(this||t).api.styles.block,input:(this||t).api.styles.input,wrapper:"ce-code",textarea:"ce-code__textarea"},(this||t).nodes={holder:null,textarea:null},(this||t).data={code:i.code||""},(this||t).nodes.holder=this.drawView()}return o(e,null,[{key:"isReadOnlySupported",get:function(){return!0}},{key:"enableLineBreaks",get:function(){return!0}}]),o(e,[{key:"drawView",value:function(){var a=this||t,i=document.createElement("div"),l=document.createElement("textarea");return i.classList.add((this||t).CSS.baseClass,(this||t).CSS.wrapper),l.classList.add((this||t).CSS.textarea,(this||t).CSS.input),l.textContent=(this||t).data.code,l.placeholder=(this||t).placeholder,(this||t).readOnly&&(l.disabled=!0),i.appendChild(l),l.addEventListener("keydown",(function(t){switch(t.code){case"Tab":a.tabHandler(t)}})),(this||t).nodes.textarea=l,i}},{key:"render",value:function(){return(this||t).nodes.holder}},{key:"save",value:function(t){return{code:t.querySelector("textarea").value}}},{key:"onPaste",value:function(a){var i=a.detail.data;(this||t).data={code:i.textContent}}},{key:"tabHandler",value:function(t){t.stopPropagation(),t.preventDefault();var a,i=t.target,l=t.shiftKey,d=i.selectionStart,h=i.value;if(l){var v=function(t,a){for(var i="";"\n"!==i&&a>0;)a-=1,i=t.substr(a,1);return"\n"===i&&(a+=1),a}(h,d);if("  "!==h.substr(v,"  ".length))return;i.value=h.substring(0,v)+h.substring(v+"  ".length),a=d-"  ".length}else a=d+"  ".length,i.value=h.substring(0,d)+"  "+h.substring(d);i.setSelectionRange(a,a)}},{key:"data",get:function(){return(this||t)._data},set:function(a){(this||t)._data=a,(this||t).nodes.textarea&&((this||t).nodes.textarea.textContent=a.code)}}],[{key:"toolbox",get:function(){return{icon:'<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" fill="none" viewBox="0 0 24 24"><path stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 8L5 12L9 16"/><path stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 8L19 12L15 16"/></svg>',title:"Code"}}},{key:"DEFAULT_PLACEHOLDER",get:function(){return"Enter a code"}},{key:"pasteConfig",get:function(){return{tags:["pre"]}}},{key:"sanitize",get:function(){return{code:!0}}}]),e}()}]).default}));var i=a;const l=a.CodeTool;export{l as CodeTool,i as default};

