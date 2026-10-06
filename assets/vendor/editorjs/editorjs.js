// @editorjs/editorjs@2.31.0 downloaded from https://ga.jspm.io/npm:@editorjs/editorjs@2.31.0/dist/editorjs.mjs

(function(){try{if(typeof document<"u"){var e=document.createElement("style");e.appendChild(document.createTextNode(".ce-hint--align-start{text-align:left}.ce-hint--align-center{text-align:center}.ce-hint__description{opacity:.6;margin-top:3px}")),document.head.appendChild(e)}}catch(e){console.error("vite-plugin-css-injected-by-js",e)}})();var e=typeof globalThis<"u"?globalThis:typeof window<"u"?window:typeof global<"u"?global:typeof self<"u"?self:{};function t(e){return e&&e.__esModule&&Object.prototype.hasOwnProperty.call(e,"default")?e.default:e}function o(e){if(e.__esModule)return e;var t=e.default;if(typeof t=="function"){var o=function e(){return this instanceof e?Reflect.construct(t,arguments,this.constructor):t.apply(this,arguments)};o.prototype=t.prototype}else o={};return Object.defineProperty(o,"__esModule",{value:!0}),Object.keys(e).forEach((function(t){var n=Object.getOwnPropertyDescriptor(e,t);Object.defineProperty(o,t,n.get?n:{enumerable:!0,get:function(){return e[t]}})})),o}function n(){}Object.assign(n,{default:n,register:n,revert:function(){},__esModule:!0});Element.prototype.matches||(Element.prototype.matches=Element.prototype.matchesSelector||Element.prototype.mozMatchesSelector||Element.prototype.msMatchesSelector||Element.prototype.oMatchesSelector||Element.prototype.webkitMatchesSelector||function(e){const t=(this.document||this.ownerDocument).querySelectorAll(e);let o=t.length;for(;--o>=0&&t.item(o)!==this;);return o>-1});Element.prototype.closest||(Element.prototype.closest=function(e){let t=this;if(!document.documentElement.contains(t))return null;do{if(t.matches(e))return t;t=t.parentElement||t.parentNode}while(t!==null);return null});Element.prototype.prepend||(Element.prototype.prepend=function(e){const t=document.createDocumentFragment();Array.isArray(e)||(e=[e]),e.forEach((e=>{const o=e instanceof Node;t.appendChild(o?e:document.createTextNode(e))})),this.insertBefore(t,this.firstChild)});Element.prototype.scrollIntoViewIfNeeded||(Element.prototype.scrollIntoViewIfNeeded=function(e){e=arguments.length===0||!!e;const t=this.parentNode,o=window.getComputedStyle(t,null),n=parseInt(o.getPropertyValue("border-top-width")),i=parseInt(o.getPropertyValue("border-left-width")),r=this.offsetTop-t.offsetTop<t.scrollTop,a=this.offsetTop-t.offsetTop+this.clientHeight-n>t.scrollTop+t.clientHeight,l=this.offsetLeft-t.offsetLeft<t.scrollLeft,c=this.offsetLeft-t.offsetLeft+this.clientWidth-i>t.scrollLeft+t.clientWidth,d=r&&!a;(r||a)&&e&&(t.scrollTop=this.offsetTop-t.offsetTop-t.clientHeight/2-n+this.clientHeight/2),(l||c)&&e&&(t.scrollLeft=this.offsetLeft-t.offsetLeft-t.clientWidth/2-i+this.clientWidth/2),(r||a||l||c)&&!e&&this.scrollIntoView(d)});window.requestIdleCallback=window.requestIdleCallback||function(e){const t=Date.now();return setTimeout((function(){e({didTimeout:!1,timeRemaining:function(){return Math.max(0,50-(Date.now()-t))}})}),1)};window.cancelIdleCallback=window.cancelIdleCallback||function(e){clearTimeout(e)};let i=(e=21)=>crypto.getRandomValues(new Uint8Array(e)).reduce(((e,t)=>(t&=63,e+=t<36?t.toString(36):t<62?(t-26).toString(36).toUpperCase():t>62?"-":"_",e)),"");var r=(e=>(e.VERBOSE="VERBOSE",e.INFO="INFO",e.WARN="WARN",e.ERROR="ERROR",e))(r||{});const a={BACKSPACE:8,TAB:9,ENTER:13,SHIFT:16,CTRL:17,ALT:18,ESC:27,SPACE:32,LEFT:37,UP:38,DOWN:40,RIGHT:39,DELETE:46,META:91,SLASH:191},l={LEFT:0,WHEEL:1,RIGHT:2,BACKWARD:3,FORWARD:4};function c(e,t,o="log",n,i="color: inherit"){if(!("console"in window)||!window.console[o])return;const r=["info","log","warn","error"].includes(o),a=[];switch(c.logLevel){case"ERROR":if(o!=="error")return;break;case"WARN":if(!["error","warn"].includes(o))return;break;case"INFO":if(!r||e)return;break}n&&a.push(n);const l="Editor.js 2.31.0",d="line-height: 1em;\n            color: #006FEA;\n            display: inline-block;\n            font-size: 11px;\n            line-height: 1em;\n            background-color: #fff;\n            padding: 4px 9px;\n            border-radius: 30px;\n            border: 1px solid rgba(56, 138, 229, 0.16);\n            margin: 4px 5px 4px 0;";e&&(r?(a.unshift(d,i),t=`%c${l}%c ${t}`):t=`( ${l} )${t}`);try{r?n?console[o](`${t} %o`,...a):console[o](t,...a):console[o](t)}catch{}}c.logLevel="VERBOSE";function d(e){c.logLevel=e}const h=c.bind(window,!1),p=c.bind(window,!0);function f(e){return Object.prototype.toString.call(e).match(/\s([a-zA-Z]+)/)[1].toLowerCase()}function g(e){return f(e)==="function"||f(e)==="asyncfunction"}function m(e){return f(e)==="object"}function v(e){return f(e)==="string"}function k(e){return f(e)==="boolean"}function y(e){return f(e)==="number"}function w(e){return f(e)==="undefined"}function x(e){return!e||Object.keys(e).length===0&&e.constructor===Object}function C(e){return e>47&&e<58||e===32||e===13||e===229||e>64&&e<91||e>95&&e<112||e>185&&e<193||e>218&&e<223}async function B(e,t=()=>{},o=()=>{}){async function n(e,t,o){try{await e.function(e.data),await t(w(e.data)?{}:e.data)}catch{o(w(e.data)?{}:e.data)}}return e.reduce((async(e,i)=>(await e,n(i,t,o))),Promise.resolve())}function T(e){return Array.prototype.slice.call(e)}function S(e,t){return function(){const o=this,n=arguments;window.setTimeout((()=>e.apply(o,n)),t)}}function I(e){return e.name.split(".").pop()}function O(e){return/^[-\w]+\/([-+\w]+|\*)$/.test(e)}function _(e,t,o){let n;return(...i)=>{const r=this,a=()=>{n=null,o||e.apply(r,i)},l=o&&!n;window.clearTimeout(n),n=window.setTimeout(a,t),l&&e.apply(r,i)}}function M(e,t,o=void 0){let n,i,r,a=null,l=0;o||(o={});const c=function(){l=o.leading===!1?0:Date.now(),a=null,r=e.apply(n,i),a||(n=i=null)};return function(){const d=Date.now();!l&&o.leading===!1&&(l=d);const h=t-(d-l);return n=this,i=arguments,h<=0||h>t?(a&&(clearTimeout(a),a=null),l=d,r=e.apply(n,i),a||(n=i=null)):!a&&o.trailing!==!1&&(a=setTimeout(c,h)),r}}function A(){const e={win:!1,mac:!1,x11:!1,linux:!1},t=Object.keys(e).find((e=>window.navigator.appVersion.toLowerCase().indexOf(e)!==-1));return t&&(e[t]=!0),e}function L(e){return e[0].toUpperCase()+e.slice(1)}function P(e,...t){if(!t.length)return e;const o=t.shift();if(m(e)&&m(o))for(const t in o)m(o[t])?(e[t]||Object.assign(e,{[t]:{}}),P(e[t],o[t])):Object.assign(e,{[t]:o[t]});return P(e,...t)}function N(e){const t=A();return e=e.replace(/shift/gi,"⇧").replace(/backspace/gi,"⌫").replace(/enter/gi,"⏎").replace(/up/gi,"↑").replace(/left/gi,"→").replace(/down/gi,"↓").replace(/right/gi,"←").replace(/escape/gi,"⎋").replace(/insert/gi,"Ins").replace(/delete/gi,"␡").replace(/\+/gi," + "),e=t.mac?e.replace(/ctrl|cmd/gi,"⌘").replace(/alt/gi,"⌥"):e.replace(/cmd/gi,"Ctrl").replace(/windows/gi,"WIN"),e}function D(e){try{return new URL(e).href}catch{}return e.substring(0,2)==="//"?window.location.protocol+e:window.location.origin+e}function F(){return i(10)}function H(e){window.open(e,"_blank")}function z(e=""){return`${e}${Math.floor(Math.random()*1e8).toString(16)}`}function U(e,t,o){const n=`«${t}» is deprecated and will be removed in the next major release. Please use the «${o}» instead.`;e&&p(n,"warn")}function $(e,t,o){const n=o.value?"value":"get",i=o[n],r=`#${t}Cache`;if(o[n]=function(...e){return this[r]===void 0&&(this[r]=i.apply(this,...e)),this[r]},n==="get"&&o.set){const t=o.set;o.set=function(o){delete e[r],t.apply(this,o)}}return o}const W=650;function Y(){return window.matchMedia(`(max-width: ${W}px)`).matches}const K=typeof window<"u"&&window.navigator&&window.navigator.platform&&(/iP(ad|hone|od)/.test(window.navigator.platform)||window.navigator.platform==="MacIntel"&&window.navigator.maxTouchPoints>1);function X(e,t){const o=Array.isArray(e)||m(e),n=Array.isArray(t)||m(t);return o||n?JSON.stringify(e)===JSON.stringify(t):e===t}class u{
/**
   * Check if passed tag has no closed tag
   *
   * @param {HTMLElement} tag - element to check
   * @returns {boolean}
   */
static isSingleTag(e){return e.tagName&&["AREA","BASE","BR","COL","COMMAND","EMBED","HR","IMG","INPUT","KEYGEN","LINK","META","PARAM","SOURCE","TRACK","WBR"].includes(e.tagName)}
/**
   * Check if element is BR or WBR
   *
   * @param {HTMLElement} element - element to check
   * @returns {boolean}
   */static isLineBreakTag(e){return e&&e.tagName&&["BR","WBR"].includes(e.tagName)}
/**
   * Helper for making Elements with class name and attributes
   *
   * @param  {string} tagName - new Element tag name
   * @param  {string[]|string} [classNames] - list or name of CSS class name(s)
   * @param  {object} [attributes] - any attributes
   * @returns {HTMLElement}
   */static make(e,t=null,o={}){const n=document.createElement(e);if(Array.isArray(t)){const e=t.filter((e=>e!==void 0));n.classList.add(...e)}else t&&n.classList.add(t);for(const e in o)Object.prototype.hasOwnProperty.call(o,e)&&(n[e]=o[e]);return n}
/**
   * Creates Text Node with the passed content
   *
   * @param {string} content - text content
   * @returns {Text}
   */static text(e){return document.createTextNode(e)}
/**
   * Append one or several elements to the parent
   *
   * @param  {Element|DocumentFragment} parent - where to append
   * @param  {Element|Element[]|DocumentFragment|Text|Text[]} elements - element or elements list
   */static append(e,t){Array.isArray(t)?t.forEach((t=>e.appendChild(t))):e.appendChild(t)}
/**
   * Append element or a couple to the beginning of the parent elements
   *
   * @param {Element} parent - where to append
   * @param {Element|Element[]} elements - element or elements list
   */static prepend(e,t){Array.isArray(t)?(t=t.reverse(),t.forEach((t=>e.prepend(t)))):e.prepend(t)}
/**
   * Swap two elements in parent
   *
   * @param {HTMLElement} el1 - from
   * @param {HTMLElement} el2 - to
   * @deprecated
   */static swap(e,t){const o=document.createElement("div"),n=e.parentNode;n.insertBefore(o,e),n.insertBefore(e,t),n.insertBefore(t,o),n.removeChild(o)
/**
   * Selector Decorator
   *
   * Returns first match
   *
   * @param {Element} el - element we searching inside. Default - DOM Document
   * @param {string} selector - searching string
   * @returns {Element}
   */}static find(e=document,t){return e.querySelector(t)}
/**
   * Get Element by Id
   *
   * @param {string} id - id to find
   * @returns {HTMLElement | null}
   */static get(e){return document.getElementById(e)}
/**
   * Selector Decorator.
   *
   * Returns all matches
   *
   * @param {Element|Document} el - element we searching inside. Default - DOM Document
   * @param {string} selector - searching string
   * @returns {NodeList}
   */static findAll(e=document,t){return e.querySelectorAll(t)}static get allInputsSelector(){return"[contenteditable=true], textarea, input:not([type]), "+["text","password","email","number","search","tel","url"].map((e=>`input[type="${e}"]`)).join(", ")}
/**
   * Find all contenteditable, textarea and editable input elements passed holder contains
   *
   * @param holder - element where to find inputs
   */static findAllInputs(e){return T(e.querySelectorAll(u.allInputsSelector)).reduce(((e,t)=>u.isNativeInput(t)||u.containsOnlyInlineElements(t)?[...e,t]:[...e,...u.getDeepestBlockElements(t)]),[])}
/**
   * Search for deepest node which is Leaf.
   * Leaf is the vertex that doesn't have any child nodes
   *
   * @description Method recursively goes throw the all Node until it finds the Leaf
   * @param {Node} node - root Node. From this vertex we start Deep-first search
   *                      {@link https://en.wikipedia.org/wiki/Depth-first_search}
   * @param {boolean} [atLast] - find last text node
   * @returns - it can be text Node or Element Node, so that caret will able to work with it
   *            Can return null if node is Document or DocumentFragment, or node is not attached to the DOM
   */static getDeepestNode(e,t=!1){const o=t?"lastChild":"firstChild",n=t?"previousSibling":"nextSibling";if(e&&e.nodeType===Node.ELEMENT_NODE&&e[o]){let i=e[o];if(u.isSingleTag(i)&&!u.isNativeInput(i)&&!u.isLineBreakTag(i))if(i[n])i=i[n];else{if(!i.parentNode[n])return i.parentNode;i=i.parentNode[n]}return this.getDeepestNode(i,t)}return e}
/**
   * Check if object is DOM node
   *
   * @param {*} node - object to check
   * @returns {boolean}
   */
static isElement(e){return!y(e)&&(e&&e.nodeType&&e.nodeType===Node.ELEMENT_NODE)}
/**
   * Check if object is DocumentFragment node
   *
   * @param {object} node - object to check
   * @returns {boolean}
   */
static isFragment(e){return!y(e)&&(e&&e.nodeType&&e.nodeType===Node.DOCUMENT_FRAGMENT_NODE)}
/**
   * Check if passed element is contenteditable
   *
   * @param {HTMLElement} element - html element to check
   * @returns {boolean}
   */static isContentEditable(e){return e.contentEditable==="true"}
/**
   * Checks target if it is native input
   *
   * @param {*} target - HTML element or string
   * @returns {boolean}
   */
static isNativeInput(e){const t=["INPUT","TEXTAREA"];return!(!e||!e.tagName)&&t.includes(e.tagName)}
/**
   * Checks if we can set caret
   *
   * @param {HTMLElement} target - target to check
   * @returns {boolean}
   */static canSetCaret(e){let t=!0;if(u.isNativeInput(e))switch(e.type){case"file":case"checkbox":case"radio":case"hidden":case"submit":case"button":case"image":case"reset":t=!1;break}else t=u.isContentEditable(e);return t}
/**
   * Checks node if it is empty
   *
   * @description Method checks simple Node without any childs for emptiness
   * If you have Node with 2 or more children id depth, you better use {@link Dom#isEmpty} method
   * @param {Node} node - node to check
   * @param {string} [ignoreChars] - char or substring to treat as empty
   * @returns {boolean} true if it is empty
   */static isNodeEmpty(e,t){let o;return!(this.isSingleTag(e)&&!this.isLineBreakTag(e))&&(o=this.isElement(e)&&this.isNativeInput(e)?e.value:e.textContent.replace("​",""),t&&(o=o.replace(new RegExp(t,"g"),"")),o.length===0
/**
   * checks node if it is doesn't have any child nodes
   *
   * @param {Node} node - node to check
   * @returns {boolean}
   */)}static isLeaf(e){return!!e&&e.childNodes.length===0}
/**
   * breadth-first search (BFS)
   * {@link https://en.wikipedia.org/wiki/Breadth-first_search}
   *
   * @description Pushes to stack all DOM leafs and checks for emptiness
   * @param {Node} node - node to check
   * @param {string} [ignoreChars] - char or substring to treat as empty
   * @returns {boolean}
   */static isEmpty(e,t){const o=[e];for(;o.length>0;)if(e=o.shift(),!!e){if(this.isLeaf(e)&&!this.isNodeEmpty(e,t))return!1;e.childNodes&&o.push(...Array.from(e.childNodes))}return!0}
/**
   * Check if string contains html elements
   *
   * @param {string} str - string to check
   * @returns {boolean}
   */static isHTMLString(e){const t=u.make("div");return t.innerHTML=e,t.childElementCount>0
/**
   * Return length of node`s text content
   *
   * @param {Node} node - node with content
   * @returns {number}
   */}static getContentLength(e){return u.isNativeInput(e)?e.value.length:e.nodeType===Node.TEXT_NODE?e.length:e.textContent.length}
/**
   * Return array of names of block html elements
   *
   * @returns {string[]}
   */static get blockElements(){return["address","article","aside","blockquote","canvas","div","dl","dt","fieldset","figcaption","figure","footer","form","h1","h2","h3","h4","h5","h6","header","hgroup","hr","li","main","nav","noscript","ol","output","p","pre","ruby","section","table","tbody","thead","tr","tfoot","ul","video"]}
/**
   * Check if passed content includes only inline elements
   *
   * @param {string|HTMLElement} data - element or html string
   * @returns {boolean}
   */static containsOnlyInlineElements(e){let t;v(e)?(t=document.createElement("div"),t.innerHTML=e):t=e;const o=e=>!u.blockElements.includes(e.tagName.toLowerCase())&&Array.from(e.children).every(o);return Array.from(t.children).every(o)}
/**
   * Find and return all block elements in the passed parent (including subtree)
   *
   * @param {HTMLElement} parent - root element
   * @returns {HTMLElement[]}
   */static getDeepestBlockElements(e){return u.containsOnlyInlineElements(e)?[e]:Array.from(e.children).reduce(((e,t)=>[...e,...u.getDeepestBlockElements(t)]),[])}
/**
   * Helper for get holder from {string} or return HTMLElement
   *
   * @param {string | HTMLElement} element - holder's id or holder's HTML Element
   * @returns {HTMLElement}
   */static getHolder(e){return v(e)?document.getElementById(e):e}
/**
   * Returns true if element is anchor (is A tag)
   *
   * @param {Element} element - element to check
   * @returns {boolean}
   */static isAnchor(e){return e.tagName.toLowerCase()==="a"}
/**
   * Return element's offset related to the document
   *
   * @todo handle case when editor initialized in scrollable popup
   * @param el - element to compute offset
   */static offset(e){const t=e.getBoundingClientRect(),o=window.pageXOffset||document.documentElement.scrollLeft,n=window.pageYOffset||document.documentElement.scrollTop,i=t.top+n,r=t.left+o;return{top:i,left:r,bottom:i+t.height,right:r+t.width}}
/**
   * Find text node and offset by total content offset
   *
   * @param {Node} root - root node to start search from
   * @param {number} totalOffset - offset relative to the root node content
   * @returns {{node: Node | null, offset: number}} - node and offset inside node
   */static getNodeByOffset(e,t){let o=0,n=null;const i=document.createTreeWalker(e,NodeFilter.SHOW_TEXT,null);let r=i.nextNode();for(;r;){const e=r.textContent,a=e===null?0:e.length;if(n=r,o+a>=t)break;o+=a,r=i.nextNode()}if(!n)return{node:null,offset:0};const a=n.textContent;if(a===null||a.length===0)return{node:null,offset:0};const l=Math.min(t-o,a.length);return{node:n,offset:l}}}function V(e){return!/[^\t\n\r ]/.test(e)}function q(e){const t=window.getComputedStyle(e),o=parseFloat(t.fontSize),n=parseFloat(t.lineHeight)||o*1.2,i=parseFloat(t.paddingTop),r=parseFloat(t.borderTopWidth),a=parseFloat(t.marginTop),l=o*.8,c=(n-o)/2;return a+r+i+c+l}function Z(e){e.dataset.empty=u.isEmpty(e)?"true":"false"}const G={blockTunes:{toggler:{"Click to tune":"","or drag to move":""}},inlineToolbar:{converter:{"Convert to":""}},toolbar:{toolbox:{Add:""}},popover:{Filter:"","Nothing found":"","Convert to":""}},Q={Text:"",Link:"",Bold:"",Italic:""},J={link:{"Add a link":""},stub:{"The block can not be displayed correctly.":""}},ee={delete:{Delete:"","Click to delete":""},moveUp:{"Move up":""},moveDown:{"Move down":""}},te={ui:G,toolNames:Q,tools:J,blockTunes:ee},oe=class he{
/**
   * Type-safe translation for internal UI texts:
   * Perform translation of the string by namespace and a key
   *
   * @example I18n.ui(I18nInternalNS.ui.blockTunes.toggler, 'Click to tune')
   * @param internalNamespace - path to translated string in dictionary
   * @param dictKey - dictionary key. Better to use default locale original text
   */
static ui(e,t){return he._t(e,t)}
/**
   * Translate for external strings that is not presented in default dictionary.
   * For example, for user-specified tool names
   *
   * @param namespace - path to translated string in dictionary
   * @param dictKey - dictionary key. Better to use default locale original text
   */static t(e,t){return he._t(e,t)}
/**
   * Adjust module for using external dictionary
   *
   * @param dictionary - new messages list to override default
   */static setDictionary(e){he.currentDictionary=e}
/**
   * Perform translation both for internal and external namespaces
   * If there is no translation found, returns passed key as a translated message
   *
   * @param namespace - path to translated string in dictionary
   * @param dictKey - dictionary key. Better to use default locale original text
   */static _t(e,t){const o=he.getNamespace(e);return o&&o[t]?o[t]:t}
/**
   * Find messages section by namespace path
   *
   * @param namespace - path to section
   */static getNamespace(e){return e.split(".").reduce(((e,t)=>e&&Object.keys(e).length?e[t]:{}),he.currentDictionary)}};oe.currentDictionary=te;let ne=oe;class Ho extends Error{}class Oe{constructor(){this.subscribers={}}
/**
   * Subscribe any event on callback
   *
   * @param eventName - event name
   * @param callback - subscriber
   */on(e,t){e in this.subscribers||(this.subscribers[e]=[]),this.subscribers[e].push(t)
/**
   * Subscribe any event on callback. Callback will be called once and be removed from subscribers array after call.
   *
   * @param eventName - event name
   * @param callback - subscriber
   */}once(e,t){e in this.subscribers||(this.subscribers[e]=[]);const o=n=>{const i=t(n),r=this.subscribers[e].indexOf(o);return r!==-1&&this.subscribers[e].splice(r,1),i};this.subscribers[e].push(o)}
/**
   * Emit callbacks with passed data
   *
   * @param eventName - event name
   * @param data - subscribers get this data when they were fired
   */emit(e,t){x(this.subscribers)||!this.subscribers[e]||this.subscribers[e].reduce(((e,t)=>{const o=t(e);return o!==void 0?o:e}),t)}
/**
   * Unsubscribe callback from event
   *
   * @param eventName - event name
   * @param callback - event handler
   */off(e,t){if(this.subscribers[e]!==void 0){for(let o=0;o<this.subscribers[e].length;o++)if(this.subscribers[e][o]===t){delete this.subscribers[e][o];break}}else console.warn(`EventDispatcher .off(): there is no subscribers for event "${e.toString()}". Probably, .off() called before .on()`)}destroy(){this.subscribers={}}}function ie(e){Object.setPrototypeOf(this,{
/**
     * Block id
     *
     * @returns {string}
     */
get id(){return e.id},
/**
     * Tool name
     *
     * @returns {string}
     */
get name(){return e.name},
/**
     * Tool config passed on Editor's initialization
     *
     * @returns {ToolConfig}
     */
get config(){return e.config},
/**
     * .ce-block element, that wraps plugin contents
     *
     * @returns {HTMLElement}
     */
get holder(){return e.holder},
/**
     * True if Block content is empty
     *
     * @returns {boolean}
     */
get isEmpty(){return e.isEmpty},
/**
     * True if Block is selected with Cross-Block selection
     *
     * @returns {boolean}
     */
get selected(){return e.selected},
/**
     * Set Block's stretch state
     *
     * @param {boolean} state — state to set
     */
set stretched(t){e.stretched=t},
/**
     * True if Block is stretched
     *
     * @returns {boolean}
     */
get stretched(){return e.stretched},get focusable(){return e.focusable},
/**
     * Call Tool method with errors handler under-the-hood
     *
     * @param {string} methodName - method to call
     * @param {object} param - object with parameters
     * @returns {unknown}
     */
call(t,o){return e.call(t,o)},
/**
     * Save Block content
     *
     * @returns {Promise<void|SavedData>}
     */
save(){return e.save()},
/**
     * Validate Block data
     *
     * @param {BlockToolData} data - data to validate
     * @returns {Promise<boolean>}
     */
validate(t){return e.validate(t)},dispatchChange(){e.dispatchChange()},getActiveToolboxEntry(){return e.getActiveToolboxEntry()}})}class _e{constructor(){this.allListeners=[]}
/**
   * Assigns event listener on element and returns unique identifier
   *
   * @param {EventTarget} element - DOM element that needs to be listened
   * @param {string} eventType - event type
   * @param {Function} handler - method that will be fired on event
   * @param {boolean|AddEventListenerOptions} options - useCapture or {capture, passive, once}
   */on(e,t,o,n=!1){const i=z("l"),r={id:i,element:e,eventType:t,handler:o,options:n};if(!this.findOne(e,t,o))return this.allListeners.push(r),e.addEventListener(t,o,n),i
/**
   * Removes event listener from element
   *
   * @param {EventTarget} element - DOM element that we removing listener
   * @param {string} eventType - event type
   * @param {Function} handler - remove handler, if element listens several handlers on the same event type
   * @param {boolean|AddEventListenerOptions} options - useCapture or {capture, passive, once}
   */}off(e,t,o,n){const i=this.findAll(e,t,o);i.forEach(((e,t)=>{const o=this.allListeners.indexOf(i[t]);o>-1&&(this.allListeners.splice(o,1),e.element.removeEventListener(e.eventType,e.handler,e.options))}))}
/**
   * Removes listener by id
   *
   * @param {string} id - listener identifier
   */offById(e){const t=this.findById(e);t&&t.element.removeEventListener(t.eventType,t.handler,t.options)}
/**
   * Finds and returns first listener by passed params
   *
   * @param {EventTarget} element - event target
   * @param {string} [eventType] - event type
   * @param {Function} [handler] - event handler
   * @returns {ListenerData|null}
   */findOne(e,t,o){const n=this.findAll(e,t,o);return n.length>0?n[0]:null}
/**
   * Return all stored listeners by passed params
   *
   * @param {EventTarget} element - event target
   * @param {string} eventType - event type
   * @param {Function} handler - event handler
   * @returns {ListenerData[]}
   */findAll(e,t,o){let n;const i=e?this.findByEventTarget(e):[];return n=e&&t&&o?i.filter((e=>e.eventType===t&&e.handler===o)):e&&t?i.filter((e=>e.eventType===t)):i,n}removeAll(){this.allListeners.map((e=>{e.element.removeEventListener(e.eventType,e.handler,e.options)})),this.allListeners=[]}destroy(){this.removeAll()}
/**
   * Search method: looks for listener by passed element
   *
   * @param {EventTarget} element - searching element
   * @returns {Array} listeners that found on element
   */findByEventTarget(e){return this.allListeners.filter((t=>{if(t.element===e)return t}))}
/**
   * Search method: looks for listener by passed event type
   *
   * @param {string} eventType - event type
   * @returns {ListenerData[]} listeners that found on element
   */findByType(e){return this.allListeners.filter((t=>{if(t.eventType===e)return t}))}
/**
   * Search method: looks for listener by passed handler
   *
   * @param {Function} handler - event handler
   * @returns {ListenerData[]} listeners that found on element
   */findByHandler(e){return this.allListeners.filter((t=>{if(t.handler===e)return t}))}
/**
   * Returns listener data found by id
   *
   * @param {string} id - listener identifier
   * @returns {ListenerData}
   */findById(e){return this.allListeners.find((t=>t.id===e))}}class E{
/**
   * @class
   * @param options - Module options
   * @param options.config - Module config
   * @param options.eventsDispatcher - Common event bus
   */
constructor({config:e,eventsDispatcher:t}){if(this.nodes={},this.listeners=new _e,this.readOnlyMutableListeners={
/**
       * Assigns event listener on DOM element and pushes into special array that might be removed
       *
       * @param {EventTarget} element - DOM Element
       * @param {string} eventType - Event name
       * @param {Function} handler - Event handler
       * @param {boolean|AddEventListenerOptions} options - Listening options
       */
on:(e,t,o,n=!1)=>{this.mutableListenerIds.push(this.listeners.on(e,t,o,n))},clearAll:()=>{for(const e of this.mutableListenerIds)this.listeners.offById(e);this.mutableListenerIds=[]}},this.mutableListenerIds=[],new.target===E)throw new TypeError("Constructors for abstract class Module are not allowed.");this.config=e,this.eventsDispatcher=t
/**
   * Editor modules setter
   *
   * @param {EditorModules} Editor - Editor's Modules
   */}set state(e){this.Editor=e}removeAllNodes(){for(const e in this.nodes){const t=this.nodes[e];t instanceof HTMLElement&&t.remove()}}get isRtl(){return this.config.i18n.direction==="rtl"}}class b{constructor(){this.instance=null,this.selection=null,this.savedSelectionRange=null,this.isFakeBackgroundEnabled=!1,this.commandBackground="backColor",this.commandRemoveFormat="removeFormat"
/**
   * Editor styles
   *
   * @returns {{editorWrapper: string, editorZone: string}}
   */}static get CSS(){return{editorWrapper:"codex-editor",editorZone:"codex-editor__redactor"}}
/**
   * Returns selected anchor
   * {@link https://developer.mozilla.org/ru/docs/Web/API/Selection/anchorNode}
   *
   * @returns {Node|null}
   */static get anchorNode(){const e=window.getSelection();return e?e.anchorNode:null}
/**
   * Returns selected anchor element
   *
   * @returns {Element|null}
   */static get anchorElement(){const e=window.getSelection();if(!e)return null;const t=e.anchorNode;return t?u.isElement(t)?t:t.parentElement:null}
/**
   * Returns selection offset according to the anchor node
   * {@link https://developer.mozilla.org/ru/docs/Web/API/Selection/anchorOffset}
   *
   * @returns {number|null}
   */static get anchorOffset(){const e=window.getSelection();return e?e.anchorOffset:null}
/**
   * Is current selection range collapsed
   *
   * @returns {boolean|null}
   */static get isCollapsed(){const e=window.getSelection();return e?e.isCollapsed:null}
/**
   * Check current selection if it is at Editor's zone
   *
   * @returns {boolean}
   */static get isAtEditor(){return this.isSelectionAtEditor(b.get())}
/**
   * Check if passed selection is at Editor's zone
   *
   * @param selection - Selection object to check
   */static isSelectionAtEditor(e){if(!e)return!1;let t=e.anchorNode||e.focusNode;t&&t.nodeType===Node.TEXT_NODE&&(t=t.parentNode);let o=null;return t&&t instanceof Element&&(o=t.closest(`.${b.CSS.editorZone}`)),!!o&&o.nodeType===Node.ELEMENT_NODE
/**
   * Check if passed range at Editor zone
   *
   * @param range - range to check
   */}static isRangeAtEditor(e){if(!e)return;let t=e.startContainer;t&&t.nodeType===Node.TEXT_NODE&&(t=t.parentNode);let o=null;return t&&t instanceof Element&&(o=t.closest(`.${b.CSS.editorZone}`)),!!o&&o.nodeType===Node.ELEMENT_NODE}static get isSelectionExists(){return!!b.get().anchorNode}
/**
   * Return first range
   *
   * @returns {Range|null}
   */static get range(){return this.getRangeFromSelection(this.get())}
/**
   * Returns range from passed Selection object
   *
   * @param selection - Selection object to get Range from
   */static getRangeFromSelection(e){return e&&e.rangeCount?e.getRangeAt(0):null}
/**
   * Calculates position and size of selected text
   *
   * @returns {DOMRect | ClientRect}
   */static get rect(){let e,t=document.selection,o={x:0,y:0,width:0,height:0};if(t&&t.type!=="Control")return t,e=t.createRange(),o.x=e.boundingLeft,o.y=e.boundingTop,o.width=e.boundingWidth,o.height=e.boundingHeight,o;if(!window.getSelection)return h("Method window.getSelection is not supported","warn"),o;if(t=window.getSelection(),t.rangeCount===null||isNaN(t.rangeCount))return h("Method SelectionUtils.rangeCount is not supported","warn"),o;if(t.rangeCount===0)return o;if(e=t.getRangeAt(0).cloneRange(),e.getBoundingClientRect&&(o=e.getBoundingClientRect()),o.x===0&&o.y===0){const t=document.createElement("span");if(t.getBoundingClientRect){t.appendChild(document.createTextNode("​")),e.insertNode(t),o=t.getBoundingClientRect();const n=t.parentNode;n.removeChild(t),n.normalize()}}return o}
/**
   * Returns selected text as String
   *
   * @returns {string}
   */static get text(){return window.getSelection?window.getSelection().toString():""}
/**
   * Returns window SelectionUtils
   * {@link https://developer.mozilla.org/ru/docs/Web/API/Window/getSelection}
   *
   * @returns {Selection}
   */static get(){return window.getSelection()}
/**
   * Set focus to contenteditable or native input element
   *
   * @param element - element where to set focus
   * @param offset - offset of cursor
   */static setCursor(e,t=0){const o=document.createRange(),n=window.getSelection();return u.isNativeInput(e)?u.canSetCaret(e)?(e.focus(),e.selectionStart=e.selectionEnd=t,e.getBoundingClientRect()):void 0:(o.setStart(e,t),o.setEnd(e,t),n.removeAllRanges(),n.addRange(o),o.getBoundingClientRect()
/**
   * Check if current range exists and belongs to container
   *
   * @param container - where range should be
   */)}static isRangeInsideContainer(e){const t=b.range;return t!==null&&e.contains(t.startContainer)}static addFakeCursor(){const e=b.range;if(e===null)return;const t=u.make("span","codex-editor__fake-cursor");t.dataset.mutationFree="true",e.collapse(),e.insertNode(t)
/**
   * Check if passed element contains a fake cursor
   *
   * @param el - where to check
   */}static isFakeCursorInsideContainer(e){return u.find(e,".codex-editor__fake-cursor")!==null}
/**
   * Removes fake cursor from a container
   *
   * @param container - container to look for
   */static removeFakeCursor(e=document.body){const t=u.find(e,".codex-editor__fake-cursor");t&&t.remove()}removeFakeBackground(){this.isFakeBackgroundEnabled&&(this.isFakeBackgroundEnabled=!1,document.execCommand(this.commandRemoveFormat))}setFakeBackground(){document.execCommand(this.commandBackground,!1,"#a8d6ff"),this.isFakeBackgroundEnabled=!0}save(){this.savedSelectionRange=b.range}restore(){if(!this.savedSelectionRange)return;const e=window.getSelection();e.removeAllRanges(),e.addRange(this.savedSelectionRange)}clearSaved(){this.savedSelectionRange=null}collapseToEnd(){const e=window.getSelection(),t=document.createRange();t.selectNodeContents(e.focusNode),t.collapse(!1),e.removeAllRanges(),e.addRange(t)
/**
   * Looks ahead to find passed tag from current selection
   *
   * @param  {string} tagName       - tag to found
   * @param  {string} [className]   - tag's class name
   * @param  {number} [searchDepth] - count of tags that can be included. For better performance.
   * @returns {HTMLElement|null}
   */}findParentTag(e,t,o=10){const n=window.getSelection();let i=null;return n&&n.anchorNode&&n.focusNode?([n.anchorNode,n.focusNode].forEach((n=>{let r=o;for(;r>0&&n.parentNode&&!(n.tagName===e&&(i=n,t&&n.classList&&!n.classList.contains(t)&&(i=null),i));)n=n.parentNode,r--})),i
/**
   * Expands selection range to the passed parent node
   *
   * @param {HTMLElement} element - element which contents should be selected
   */):null}expandToTag(e){const t=window.getSelection();t.removeAllRanges();const o=document.createRange();o.selectNodeContents(e),t.addRange(o)}}function se(e,t){const{type:o,target:n,addedNodes:i,removedNodes:r}=e;return(e.type!=="attributes"||e.attributeName!=="data-empty")&&!!(t.contains(n)||o==="childList"&&(Array.from(i).some((e=>e===t))||Array.from(r).some((e=>e===t))))}const ae="redactor dom changed",le="block changed",de="fake cursor is about to be toggled",ue="fake cursor have been set",pe="editor mobile layout toggled";function fe(e,t){if(!e.conversionConfig)return!1;const o=e.conversionConfig[t];return g(o)||v(o)}function ge(e,t){return fe(e.tool,t)}function me(e,t){return Object.entries(e).some((([e,o])=>t[e]&&X(t[e],o)))}async function be(e,t){const o=(await e.save()).data,n=t.find((t=>t.name===e.name));return n===void 0||fe(n,"export")?t.reduce(((t,n)=>{if(!fe(n,"import")||n.toolbox===void 0)return t;const i=n.toolbox.filter((t=>{if(x(t)||t.icon===void 0)return!1;if(t.data!==void 0){if(me(t.data,o))return!1}else if(n.name===e.name)return!1;return!0}));return t.push({...n,toolbox:i}),t}),[]):[]}function ve(e,t){return!!e.mergeable&&(e.name===t.name||ge(t,"export")&&ge(e,"import"))}function ke(e,t){const o=t==null?void 0:t.export;return g(o)?o(e):v(o)?e[o]:(o!==void 0&&h("Conversion «export» property must be a string or function. String means key of saved data object to export. Function should export processed string to export."),"")}function ye(e,t,o){const n=t==null?void 0:t.import;return g(n)?n(e,o):v(n)?{[n]:e}:(n!==void 0&&h("Conversion «import» property must be a string or function. String means key of tool data to import. Function accepts a imported string and return composed tool data."),{})}var we=(e=>(e.Default="default",e.Separator="separator",e.Html="html",e))(we||{}),Ce=(e=>(e.APPEND_CALLBACK="appendCallback",e.RENDERED="rendered",e.MOVED="moved",e.UPDATED="updated",e.REMOVED="removed",e.ON_PASTE="onPaste",e))(Ce||{});class R extends Oe{
/**
   * @param options - block constructor options
   * @param [options.id] - block's id. Will be generated if omitted.
   * @param options.data - Tool's initial data
   * @param options.tool — block's tool
   * @param options.api - Editor API module for pass it to the Block Tunes
   * @param options.readOnly - Read-Only flag
   * @param [eventBus] - Editor common event bus. Allows to subscribe on some Editor events. Could be omitted when "virtual" Block is created. See BlocksAPI@composeBlockData.
   */
constructor({id:e=F(),data:t,tool:o,readOnly:n,tunesData:i},r){super(),this.cachedInputs=[],this.toolRenderedElement=null,this.tunesInstances=new Map,this.defaultTunesInstances=new Map,this.unavailableTunesData={},this.inputIndex=0,this.editorEventBus=null,this.handleFocus=()=>{this.dropInputsCache(),this.updateCurrentInput()},this.didMutated=(e=void 0)=>{const t=e===void 0,o=e instanceof InputEvent;!t&&!o&&this.detectToolRootChange(e);let n;n=!(!t&&!o)||!(e.length>0&&e.every((e=>{const{addedNodes:t,removedNodes:o,target:n}=e;return[...Array.from(t),...Array.from(o),n].some((e=>(u.isElement(e)||(e=e.parentElement),e&&e.closest('[data-mutation-free="true"]')!==null)))}))),n&&(this.dropInputsCache(),this.updateCurrentInput(),this.toggleInputsEmptyMark(),this.call("updated"),this.emit("didMutated",this))},this.name=o.name,this.id=e,this.settings=o.settings,this.config=o.settings.config||{},this.editorEventBus=r||null,this.blockAPI=new ie(this),this.tool=o,this.toolInstance=o.create(t,this.blockAPI,n),this.tunes=o.tunes,this.composeTunes(i),this.holder=this.compose(),window.requestIdleCallback((()=>{this.watchBlockMutations(),this.addInputEvents(),this.toggleInputsEmptyMark()}))
/**
   * CSS classes for the Block
   *
   * @returns {{wrapper: string, content: string}}
   */}static get CSS(){return{wrapper:"ce-block",wrapperStretched:"ce-block--stretched",content:"ce-block__content",selected:"ce-block--selected",dropTarget:"ce-block--drop-target"}}get inputs(){if(this.cachedInputs.length!==0)return this.cachedInputs;const e=u.findAllInputs(this.holder);return this.inputIndex>e.length-1&&(this.inputIndex=e.length-1),this.cachedInputs=e,e}get currentInput(){return this.inputs[this.inputIndex]}
/**
   * Set input index to the passed element
   *
   * @param element - HTML Element to set as current input
   */set currentInput(e){const t=this.inputs.findIndex((t=>t===e||t.contains(e)));t!==-1&&(this.inputIndex=t)}get firstInput(){return this.inputs[0]}get lastInput(){const e=this.inputs;return e[e.length-1]}get nextInput(){return this.inputs[this.inputIndex+1]}get previousInput(){return this.inputs[this.inputIndex-1]}
/**
   * Get Block's JSON data
   *
   * @returns {object}
   */get data(){return this.save().then((e=>e&&!x(e.data)?e.data:{}))}
/**
   * Returns tool's sanitizer config
   *
   * @returns {object}
   */get sanitize(){return this.tool.sanitizeConfig}
/**
   * is block mergeable
   * We plugin have merge function then we call it mergeable
   *
   * @returns {boolean}
   */get mergeable(){return g(this.toolInstance.merge)}get focusable(){return this.inputs.length!==0}
/**
   * Check block for emptiness
   *
   * @returns {boolean}
   */get isEmpty(){const e=u.isEmpty(this.pluginsContent,"/"),t=!this.hasMedia;return e&&t}
/**
   * Check if block has a media content such as images, iframe and other
   *
   * @returns {boolean}
   */get hasMedia(){const e=["img","iframe","video","audio","source","input","textarea","twitterwidget"];return!!this.holder.querySelector(e.join(","))}
/**
   * Set selected state
   * We don't need to mark Block as Selected when it is empty
   *
   * @param {boolean} state - 'true' to select, 'false' to remove selection
   */set selected(e){var t,o;this.holder.classList.toggle(R.CSS.selected,e);const n=e===!0&&b.isRangeInsideContainer(this.holder),i=e===!1&&b.isFakeCursorInsideContainer(this.holder);(n||i)&&((t=this.editorEventBus)==null||t.emit(de,{state:e}),n?b.addFakeCursor():b.removeFakeCursor(this.holder),(o=this.editorEventBus)==null||o.emit(ue,{state:e})
/**
   * Returns True if it is Selected
   *
   * @returns {boolean}
   */)}get selected(){return this.holder.classList.contains(R.CSS.selected)}
/**
   * Set stretched state
   *
   * @param {boolean} state - 'true' to enable, 'false' to disable stretched state
   */set stretched(e){this.holder.classList.toggle(R.CSS.wrapperStretched,e)}
/**
   * Return Block's stretched state
   *
   * @returns {boolean}
   */get stretched(){return this.holder.classList.contains(R.CSS.wrapperStretched)}
/**
   * Toggle drop target state
   *
   * @param {boolean} state - 'true' if block is drop target, false otherwise
   */set dropTarget(e){this.holder.classList.toggle(R.CSS.dropTarget,e)}
/**
   * Returns Plugins content
   *
   * @returns {HTMLElement}
   */get pluginsContent(){return this.toolRenderedElement}
/**
   * Calls Tool's method
   *
   * Method checks tool property {MethodName}. Fires method with passes params If it is instance of Function
   *
   * @param {string} methodName - method to call
   * @param {object} params - method argument
   */call(e,t){if(g(this.toolInstance[e])){e==="appendCallback"&&h("`appendCallback` hook is deprecated and will be removed in the next major release. Use `rendered` hook instead","warn");try{this.toolInstance[e].call(this.toolInstance,t)}catch(t){h(`Error during '${e}' call: ${t.message}`,"error")}}}
/**
   * Call plugins merge method
   *
   * @param {BlockToolData} data - data to merge
   */async mergeWith(e){await this.toolInstance.merge(e)}
/**
   * Extracts data from Block
   * Groups Tool's save processing time
   *
   * @returns {object}
   */async save(){const e=await this.toolInstance.save(this.pluginsContent),t=this.unavailableTunesData;[...this.tunesInstances.entries(),...this.defaultTunesInstances.entries()].forEach((([e,o])=>{if(g(o.save))try{t[e]=o.save()}catch(e){h(`Tune ${o.constructor.name} save method throws an Error %o`,"warn",e)}}));const o=window.performance.now();let n;return Promise.resolve(e).then((e=>(n=window.performance.now(),{id:this.id,tool:this.name,data:e,tunes:t,time:n-o}))).catch((e=>{h(`Saving process for ${this.name} tool failed due to the ${e}`,"log","red")}))}
/**
   * Uses Tool's validation method to check the correctness of output data
   * Tool's validation method is optional
   *
   * @description Method returns true|false whether data passed the validation or not
   * @param {BlockToolData} data - data to validate
   * @returns {Promise<boolean>} valid
   */async validate(e){let t=!0;return this.toolInstance.validate instanceof Function&&(t=await this.toolInstance.validate(e)),t}getTunes(){const e=[],t=[],o=typeof this.toolInstance.renderSettings=="function"?this.toolInstance.renderSettings():[];return u.isElement(o)?e.push({type:we.Html,element:o}):Array.isArray(o)?e.push(...o):e.push(o),[...this.tunesInstances.values(),...this.defaultTunesInstances.values()].map((e=>e.render())).forEach((e=>{u.isElement(e)?t.push({type:we.Html,element:e}):Array.isArray(e)?t.push(...e):t.push(e)})),{toolTunes:e,commonTunes:t}}updateCurrentInput(){this.currentInput=u.isNativeInput(document.activeElement)||!b.anchorNode?document.activeElement:b.anchorNode}dispatchChange(){this.didMutated()}destroy(){this.unwatchBlockMutations(),this.removeInputEvents(),super.destroy(),g(this.toolInstance.destroy)&&this.toolInstance.destroy()}async getActiveToolboxEntry(){const e=this.tool.toolbox;if(e.length===1)return Promise.resolve(this.tool.toolbox[0]);const t=await this.data,o=e;return o==null?void 0:o.find((e=>me(e.data,t)))}async exportDataAsString(){const e=await this.data;return ke(e,this.tool.conversionConfig)}
/**
   * Make default Block wrappers and put Tool`s content there
   *
   * @returns {HTMLDivElement}
   */compose(){const e=u.make("div",R.CSS.wrapper),t=u.make("div",R.CSS.content),o=this.toolInstance.render();e.dataset.id=this.id,this.toolRenderedElement=o,t.appendChild(this.toolRenderedElement);let n=t;return[...this.tunesInstances.values(),...this.defaultTunesInstances.values()].forEach((e=>{if(g(e.wrap))try{n=e.wrap(n)}catch(t){h(`Tune ${e.constructor.name} wrap method throws an Error %o`,"warn",t)}})),e.appendChild(n),e
/**
   * Instantiate Block Tunes
   *
   * @param tunesData - current Block tunes data
   * @private
   */}composeTunes(e){Array.from(this.tunes.values()).forEach((t=>{(t.isInternal?this.defaultTunesInstances:this.tunesInstances).set(t.name,t.create(e[t.name],this.blockAPI))})),Object.entries(e).forEach((([e,t])=>{this.tunesInstances.has(e)||(this.unavailableTunesData[e]=t)}))}addInputEvents(){this.inputs.forEach((e=>{e.addEventListener("focus",this.handleFocus),u.isNativeInput(e)&&e.addEventListener("input",this.didMutated)}))}removeInputEvents(){this.inputs.forEach((e=>{e.removeEventListener("focus",this.handleFocus),u.isNativeInput(e)&&e.removeEventListener("input",this.didMutated)}))}watchBlockMutations(){var e;this.redactorDomChangedCallback=e=>{const{mutations:t}=e;t.some((e=>se(e,this.toolRenderedElement)))&&this.didMutated(t)},(e=this.editorEventBus)==null||e.on(ae,this.redactorDomChangedCallback)}unwatchBlockMutations(){var e;(e=this.editorEventBus)==null||e.off(ae,this.redactorDomChangedCallback)}
/**
   * Sometimes Tool can replace own main element, for example H2 -> H4 or UL -> OL
   * We need to detect such changes and update a link to tools main element with the new one
   *
   * @param mutations - records of block content mutations
   */detectToolRootChange(e){e.forEach((e=>{if(Array.from(e.removedNodes).includes(this.toolRenderedElement)){const t=e.addedNodes[e.addedNodes.length-1];this.toolRenderedElement=t}}))}dropInputsCache(){this.cachedInputs=[]}toggleInputsEmptyMark(){this.inputs.forEach(Z)}}class gi extends E{constructor(){super(...arguments),this.insert=(e=this.config.defaultBlock,t={},o={},n,i,r,a)=>{const l=this.Editor.BlockManager.insert({id:a,tool:e,data:t,index:n,needToFocus:i,replace:r});return new ie(l)},this.composeBlockData=async e=>{const t=this.Editor.Tools.blockTools.get(e);return new R({tool:t,api:this.Editor.API,readOnly:!0,data:{},tunesData:{}}).data},this.update=async(e,t,o)=>{const{BlockManager:n}=this.Editor,i=n.getBlockById(e);if(i===void 0)throw new Error(`Block with id "${e}" not found`);const r=await n.update(i,t,o);return new ie(r)},this.convert=async(e,t,o)=>{var n,i;const{BlockManager:r,Tools:a}=this.Editor,l=r.getBlockById(e);if(!l)throw new Error(`Block with id "${e}" not found`);const c=a.blockTools.get(l.name),d=a.blockTools.get(t);if(!d)throw new Error(`Block Tool with type "${t}" not found`);const h=((n=c==null?void 0:c.conversionConfig)==null?void 0:n.export)!==void 0,p=((i=d.conversionConfig)==null?void 0:i.import)!==void 0;if(h&&p){const e=await r.convert(l,t,o);return new ie(e)}{const e=[!h&&L(l.name),!p&&L(t)].filter(Boolean).join(" and ");throw new Error(`Conversion from "${l.name}" to "${t}" is not possible. ${e} tool(s) should provide a "conversionConfig"`)}},this.insertMany=(e,t=this.Editor.BlockManager.blocks.length-1)=>{this.validateIndex(t);const o=e.map((({id:e,type:t,data:o})=>this.Editor.BlockManager.composeBlock({id:e,tool:t||this.config.defaultBlock,data:o})));return this.Editor.BlockManager.insertMany(o,t),o.map((e=>new ie(e)))}
/**
   * Available methods
   *
   * @returns {Blocks}
   */}get methods(){return{clear:()=>this.clear(),render:e=>this.render(e),renderFromHTML:e=>this.renderFromHTML(e),delete:e=>this.delete(e),swap:(e,t)=>this.swap(e,t),move:(e,t)=>this.move(e,t),getBlockByIndex:e=>this.getBlockByIndex(e),getById:e=>this.getById(e),getCurrentBlockIndex:()=>this.getCurrentBlockIndex(),getBlockIndex:e=>this.getBlockIndex(e),getBlocksCount:()=>this.getBlocksCount(),getBlockByElement:e=>this.getBlockByElement(e),stretchBlock:(e,t=!0)=>this.stretchBlock(e,t),insertNewBlock:()=>this.insertNewBlock(),insert:this.insert,insertMany:this.insertMany,update:this.update,composeBlockData:this.composeBlockData,convert:this.convert}}
/**
   * Returns Blocks count
   *
   * @returns {number}
   */getBlocksCount(){return this.Editor.BlockManager.blocks.length}
/**
   * Returns current block index
   *
   * @returns {number}
   */getCurrentBlockIndex(){return this.Editor.BlockManager.currentBlockIndex}
/**
   * Returns the index of Block by id;
   *
   * @param id - block id
   */getBlockIndex(e){const t=this.Editor.BlockManager.getBlockById(e);if(t)return this.Editor.BlockManager.getBlockIndex(t);p("There is no block with id `"+e+"`","warn")}
/**
   * Returns BlockAPI object by Block index
   *
   * @param {number} index - index to get
   */getBlockByIndex(e){const t=this.Editor.BlockManager.getBlockByIndex(e);if(t!==void 0)return new ie(t);p("There is no block at index `"+e+"`","warn")}
/**
   * Returns BlockAPI object by Block id
   *
   * @param id - id of block to get
   */getById(e){const t=this.Editor.BlockManager.getBlockById(e);return t===void 0?(p("There is no block with id `"+e+"`","warn"),null):new ie(t)}
/**
   * Get Block API object by any child html element
   *
   * @param element - html element to get Block by
   */getBlockByElement(e){const t=this.Editor.BlockManager.getBlock(e);if(t!==void 0)return new ie(t);p("There is no block corresponding to element `"+e+"`","warn")}
/**
   * Call Block Manager method that swap Blocks
   *
   * @param {number} fromIndex - position of first Block
   * @param {number} toIndex - position of second Block
   * @deprecated — use 'move' instead
   */swap(e,t){h("`blocks.swap()` method is deprecated and will be removed in the next major release. Use `block.move()` method instead","info"),this.Editor.BlockManager.swap(e,t)
/**
   * Move block from one index to another
   *
   * @param {number} toIndex - index to move to
   * @param {number} fromIndex - index to move from
   */}move(e,t){this.Editor.BlockManager.move(e,t)}
/**
   * Deletes Block
   *
   * @param {number} blockIndex - index of Block to delete
   */delete(e=this.Editor.BlockManager.currentBlockIndex){try{const t=this.Editor.BlockManager.getBlockByIndex(e);this.Editor.BlockManager.removeBlock(t)}catch(e){p(e,"warn");return}this.Editor.BlockManager.blocks.length===0&&this.Editor.BlockManager.insert(),this.Editor.BlockManager.currentBlock&&this.Editor.Caret.setToBlock(this.Editor.BlockManager.currentBlock,this.Editor.Caret.positions.END),this.Editor.Toolbar.close()}async clear(){await this.Editor.BlockManager.clear(!0),this.Editor.InlineToolbar.close()
/**
   * Fills Editor with Blocks data
   *
   * @param {OutputData} data — Saved Editor data
   */}async render(e){if(e===void 0||e.blocks===void 0)throw new Error("Incorrect data passed to the render() method");this.Editor.ModificationsObserver.disable(),await this.Editor.BlockManager.clear(),await this.Editor.Renderer.render(e.blocks),this.Editor.ModificationsObserver.enable()
/**
   * Render passed HTML string
   *
   * @param {string} data - HTML string to render
   * @returns {Promise<void>}
   */}async renderFromHTML(e){return await this.Editor.BlockManager.clear(),this.Editor.Paste.processText(e,!0)
/**
   * Stretch Block's content
   *
   * @param {number} index - index of Block to stretch
   * @param {boolean} status - true to enable, false to disable
   * @deprecated Use BlockAPI interface to stretch Blocks
   */}stretchBlock(e,t=!0){U(!0,"blocks.stretchBlock()","BlockAPI");const o=this.Editor.BlockManager.getBlockByIndex(e);o&&(o.stretched=t)}
/**
   * Insert new Block
   * After set caret to this Block
   *
   * @todo remove in 3.0.0
   * @deprecated with insert() method
   */insertNewBlock(){h("Method blocks.insertNewBlock() is deprecated and it will be removed in the next major release. Use blocks.insert() instead.","warn"),this.insert()
/**
   * Validated block index and throws an error if it's invalid
   *
   * @param index - index to validate
   */}validateIndex(e){if(typeof e!="number")throw new Error("Index should be a number");if(e<0)throw new Error("Index should be greater than or equal to 0");if(e===null)throw new Error("Index should be greater than or equal to 0")}}function Te(e,t){return typeof e=="number"?t.BlockManager.getBlockByIndex(e):typeof e=="string"?t.BlockManager.getBlockById(e):t.BlockManager.getBlockById(e.id)}class bi extends E{constructor(){super(...arguments),this.setToFirstBlock=(e=this.Editor.Caret.positions.DEFAULT,t=0)=>!!this.Editor.BlockManager.firstBlock&&(this.Editor.Caret.setToBlock(this.Editor.BlockManager.firstBlock,e,t),!0),this.setToLastBlock=(e=this.Editor.Caret.positions.DEFAULT,t=0)=>!!this.Editor.BlockManager.lastBlock&&(this.Editor.Caret.setToBlock(this.Editor.BlockManager.lastBlock,e,t),!0),this.setToPreviousBlock=(e=this.Editor.Caret.positions.DEFAULT,t=0)=>!!this.Editor.BlockManager.previousBlock&&(this.Editor.Caret.setToBlock(this.Editor.BlockManager.previousBlock,e,t),!0),this.setToNextBlock=(e=this.Editor.Caret.positions.DEFAULT,t=0)=>!!this.Editor.BlockManager.nextBlock&&(this.Editor.Caret.setToBlock(this.Editor.BlockManager.nextBlock,e,t),!0),this.setToBlock=(e,t=this.Editor.Caret.positions.DEFAULT,o=0)=>{const n=Te(e,this.Editor);return n!==void 0&&(this.Editor.Caret.setToBlock(n,t,o),!0)},this.focus=(e=!1)=>e?this.setToLastBlock(this.Editor.Caret.positions.END):this.setToFirstBlock(this.Editor.Caret.positions.START)
/**
   * Available methods
   *
   * @returns {Caret}
   */}get methods(){return{setToFirstBlock:this.setToFirstBlock,setToLastBlock:this.setToLastBlock,setToPreviousBlock:this.setToPreviousBlock,setToNextBlock:this.setToNextBlock,setToBlock:this.setToBlock,focus:this.focus}}}class vi extends E{
/**
   * Available methods
   *
   * @returns {Events}
   */
get methods(){return{emit:(e,t)=>this.emit(e,t),off:(e,t)=>this.off(e,t),on:(e,t)=>this.on(e,t)}}
/**
   * Subscribe on Events
   *
   * @param {string} eventName - event name to subscribe
   * @param {Function} callback - event handler
   */on(e,t){this.eventsDispatcher.on(e,t)}
/**
   * Emit event with data
   *
   * @param {string} eventName - event to emit
   * @param {object} data - event's data
   */emit(e,t){this.eventsDispatcher.emit(e,t)}
/**
   * Unsubscribe from Event
   *
   * @param {string} eventName - event to unsubscribe
   * @param {Function} callback - event handler
   */off(e,t){this.eventsDispatcher.off(e,t)}}class kt extends E{
/**
   * Return namespace section for tool or block tune
   *
   * @param toolName - tool name
   * @param isTune - is tool a block tune
   */
static getNamespace(e,t){return t?`blockTunes.${e}`:`tools.${e}`}get methods(){return{t:()=>{p("I18n.t() method can be accessed only from Tools","warn")}}}
/**
   * Return I18n API methods with tool namespaced dictionary
   *
   * @param toolName - tool name
   * @param isTune - is tool a block tune
   */getMethodsForTool(e,t){return Object.assign(this.methods,{t:o=>ne.t(kt.getNamespace(e,t),o)})}}class ki extends E{get methods(){return{blocks:this.Editor.BlocksAPI.methods,caret:this.Editor.CaretAPI.methods,tools:this.Editor.ToolsAPI.methods,events:this.Editor.EventsAPI.methods,listeners:this.Editor.ListenersAPI.methods,notifier:this.Editor.NotifierAPI.methods,sanitizer:this.Editor.SanitizerAPI.methods,saver:this.Editor.SaverAPI.methods,selection:this.Editor.SelectionAPI.methods,styles:this.Editor.StylesAPI.classes,toolbar:this.Editor.ToolbarAPI.methods,inlineToolbar:this.Editor.InlineToolbarAPI.methods,tooltip:this.Editor.TooltipAPI.methods,i18n:this.Editor.I18nAPI.methods,readOnly:this.Editor.ReadOnlyAPI.methods,ui:this.Editor.UiAPI.methods}}
/**
   * Returns Editor.js Core API methods for passed tool
   *
   * @param toolName - tool name
   * @param isTune - is tool a block tune
   */getMethodsForTool(e,t){return Object.assign(this.methods,{i18n:this.Editor.I18nAPI.getMethodsForTool(e,t)})}}class yi extends E{
/**
   * Available methods
   *
   * @returns {InlineToolbar}
   */
get methods(){return{close:()=>this.close(),open:()=>this.open()}}open(){this.Editor.InlineToolbar.tryToShow()}close(){this.Editor.InlineToolbar.close()}}class wi extends E{
/**
   * Available methods
   *
   * @returns {Listeners}
   */
get methods(){return{on:(e,t,o,n)=>this.on(e,t,o,n),off:(e,t,o,n)=>this.off(e,t,o,n),offById:e=>this.offById(e)}}
/**
   * Ads a DOM event listener. Return it's id.
   *
   * @param {HTMLElement} element - Element to set handler to
   * @param {string} eventType - event type
   * @param {() => void} handler - event handler
   * @param {boolean} useCapture - capture event or not
   */on(e,t,o,n){return this.listeners.on(e,t,o,n)}
/**
   * Removes DOM listener from element
   *
   * @param {Element} element - Element to remove handler from
   * @param eventType - event type
   * @param handler - event handler
   * @param {boolean} useCapture - capture event or not
   */off(e,t,o,n){this.listeners.off(e,t,o,n)}
/**
   * Removes DOM listener by the listener id
   *
   * @param id - id of the listener to remove
   */offById(e){this.listeners.offById(e)}}var Ie={exports:{}};(function(e){(function(t,o){e.exports=o()})(window,(function(){return function(e){var t={};function o(n){if(t[n])return t[n].exports;var i=t[n]={i:n,l:!1,exports:{}};return e[n].call(i.exports,i,i.exports,o),i.l=!0,i.exports}return o.m=e,o.c=t,o.d=function(e,t,n){o.o(e,t)||Object.defineProperty(e,t,{enumerable:!0,get:n})},o.r=function(e){typeof Symbol<"u"&&Symbol.toStringTag&&Object.defineProperty(e,Symbol.toStringTag,{value:"Module"}),Object.defineProperty(e,"__esModule",{value:!0})},o.t=function(e,t){if(1&t&&(e=o(e)),8&t||4&t&&typeof e=="object"&&e&&e.__esModule)return e;var n=Object.create(null);if(o.r(n),Object.defineProperty(n,"default",{enumerable:!0,value:e}),2&t&&typeof e!="string")for(var i in e)o.d(n,i,function(t){return e[t]}.bind(null,i));return n},o.n=function(e){var t=e&&e.__esModule?function(){return e.default}:function(){return e};return o.d(t,"a",t),t},o.o=function(e,t){return Object.prototype.hasOwnProperty.call(e,t)},o.p="/",o(o.s=0)}([function(e,t,o){o(1),e.exports=function(){var e=o(6),t="cdx-notify--bounce-in",n=null;return{show:function(o){if(o.message){(function(){if(n)return!0;n=e.getWrapper(),document.body.appendChild(n)})();var i=null,r=o.time||8e3;switch(o.type){case"confirm":i=e.confirm(o);break;case"prompt":i=e.prompt(o);break;default:i=e.alert(o),window.setTimeout((function(){i.remove()}),r)}n.appendChild(i),i.classList.add(t)}}}}()},function(e,t,o){var n=o(2);typeof n=="string"&&(n=[[e.i,n,""]]);var i={hmr:!0,transform:void 0,insertInto:void 0};o(4)(n,i),n.locals&&(e.exports=n.locals)},function(e,t,o){(e.exports=o(3)(!1)).push([e.i,'.cdx-notify--error{background:#fffbfb!important}.cdx-notify--error::before{background:#fb5d5d!important}.cdx-notify__input{max-width:130px;padding:5px 10px;background:#f7f7f7;border:0;border-radius:3px;font-size:13px;color:#656b7c;outline:0}.cdx-notify__input:-ms-input-placeholder{color:#656b7c}.cdx-notify__input::placeholder{color:#656b7c}.cdx-notify__input:focus:-ms-input-placeholder{color:rgba(101,107,124,.3)}.cdx-notify__input:focus::placeholder{color:rgba(101,107,124,.3)}.cdx-notify__button{border:none;border-radius:3px;font-size:13px;padding:5px 10px;cursor:pointer}.cdx-notify__button:last-child{margin-left:10px}.cdx-notify__button--cancel{background:#f2f5f7;box-shadow:0 2px 1px 0 rgba(16,19,29,0);color:#656b7c}.cdx-notify__button--cancel:hover{background:#eee}.cdx-notify__button--confirm{background:#34c992;box-shadow:0 1px 1px 0 rgba(18,49,35,.05);color:#fff}.cdx-notify__button--confirm:hover{background:#33b082}.cdx-notify__btns-wrapper{display:-ms-flexbox;display:flex;-ms-flex-flow:row nowrap;flex-flow:row nowrap;margin-top:5px}.cdx-notify__cross{position:absolute;top:5px;right:5px;width:10px;height:10px;padding:5px;opacity:.54;cursor:pointer}.cdx-notify__cross::after,.cdx-notify__cross::before{content:\'\';position:absolute;left:9px;top:5px;height:12px;width:2px;background:#575d67}.cdx-notify__cross::before{transform:rotate(-45deg)}.cdx-notify__cross::after{transform:rotate(45deg)}.cdx-notify__cross:hover{opacity:1}.cdx-notifies{position:fixed;z-index:2;bottom:20px;left:20px;font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Oxygen,Ubuntu,Cantarell,"Fira Sans","Droid Sans","Helvetica Neue",sans-serif}.cdx-notify{position:relative;width:220px;margin-top:15px;padding:13px 16px;background:#fff;box-shadow:0 11px 17px 0 rgba(23,32,61,.13);border-radius:5px;font-size:14px;line-height:1.4em;word-wrap:break-word}.cdx-notify::before{content:\'\';position:absolute;display:block;top:0;left:0;width:3px;height:calc(100% - 6px);margin:3px;border-radius:5px;background:0 0}@keyframes bounceIn{0%{opacity:0;transform:scale(.3)}50%{opacity:1;transform:scale(1.05)}70%{transform:scale(.9)}100%{transform:scale(1)}}.cdx-notify--bounce-in{animation-name:bounceIn;animation-duration:.6s;animation-iteration-count:1}.cdx-notify--success{background:#fafffe!important}.cdx-notify--success::before{background:#41ffb1!important}',""])},function(e,t){e.exports=function(e){var t=[];return t.toString=function(){return this.map((function(t){var o=function(e,t){var o=e[1]||"",n=e[3];if(!n)return o;if(t&&typeof btoa=="function"){var i=(a=n,"/*# sourceMappingURL=data:application/json;charset=utf-8;base64,"+btoa(unescape(encodeURIComponent(JSON.stringify(a))))+" */"),r=n.sources.map((function(e){return"/*# sourceURL="+n.sourceRoot+e+" */"}));return[o].concat(r).concat([i]).join("\n")}var a;return[o].join("\n")}(t,e);return t[2]?"@media "+t[2]+"{"+o+"}":o})).join("")},t.i=function(e,o){typeof e=="string"&&(e=[[null,e,""]]);for(var n={},i=0;i<this.length;i++){var r=this[i][0];typeof r=="number"&&(n[r]=!0)}for(i=0;i<e.length;i++){var a=e[i];typeof a[0]=="number"&&n[a[0]]||(o&&!a[2]?a[2]=o:o&&(a[2]="("+a[2]+") and ("+o+")"),t.push(a))}},t}},function(e,t,o){var n,i,r={},a=(n=function(){return window&&document&&document.all&&!window.atob},function(){return i===void 0&&(i=n.apply(this,arguments)),i}),l=function(){var e={};return function(t){if(typeof t=="function")return t();if(e[t]===void 0){var o=function(e){return document.querySelector(e)}.call(this,t);if(window.HTMLIFrameElement&&o instanceof window.HTMLIFrameElement)try{o=o.contentDocument.head}catch{o=null}e[t]=o}return e[t]}}(),c=null,d=0,h=[],p=o(5);function f(e,t){for(var o=0;o<e.length;o++){var n=e[o],i=r[n.id];if(i){i.refs++;for(var a=0;a<i.parts.length;a++)i.parts[a](n.parts[a]);for(;a<n.parts.length;a++)i.parts.push(w(n.parts[a],t))}else{var l=[];for(a=0;a<n.parts.length;a++)l.push(w(n.parts[a],t));r[n.id]={id:n.id,refs:1,parts:l}}}}function g(e,t){for(var o=[],n={},i=0;i<e.length;i++){var r=e[i],a=t.base?r[0]+t.base:r[0],l={css:r[1],media:r[2],sourceMap:r[3]};n[a]?n[a].parts.push(l):o.push(n[a]={id:a,parts:[l]})}return o}function m(e,t){var o=l(e.insertInto);if(!o)throw new Error("Couldn't find a style target. This probably means that the value for the 'insertInto' parameter is invalid.");var n=h[h.length-1];if(e.insertAt==="top")n?n.nextSibling?o.insertBefore(t,n.nextSibling):o.appendChild(t):o.insertBefore(t,o.firstChild),h.push(t);else if(e.insertAt==="bottom")o.appendChild(t);else{if(typeof e.insertAt!="object"||!e.insertAt.before)throw new Error("[Style Loader]\n\n Invalid value for parameter 'insertAt' ('options.insertAt') found.\n Must be 'top', 'bottom', or Object.\n (https://github.com/webpack-contrib/style-loader#insertat)\n");var i=l(e.insertInto+" "+e.insertAt.before);o.insertBefore(t,i)}}function v(e){if(e.parentNode===null)return!1;e.parentNode.removeChild(e);var t=h.indexOf(e);t>=0&&h.splice(t,1)}function k(e){var t=document.createElement("style");return e.attrs.type===void 0&&(e.attrs.type="text/css"),y(t,e.attrs),m(e,t),t}function y(e,t){Object.keys(t).forEach((function(o){e.setAttribute(o,t[o])}))}function w(e,t){var o,n,i,r;if(t.transform&&e.css){if(!(r=t.transform(e.css)))return function(){};e.css=r}if(t.singleton){var a=d++;o=c||(c=k(t)),n=B.bind(null,o,a,!1),i=B.bind(null,o,a,!0)}else e.sourceMap&&typeof URL=="function"&&typeof URL.createObjectURL=="function"&&typeof URL.revokeObjectURL=="function"&&typeof Blob=="function"&&typeof btoa=="function"?(o=function(e){var t=document.createElement("link");return e.attrs.type===void 0&&(e.attrs.type="text/css"),e.attrs.rel="stylesheet",y(t,e.attrs),m(e,t),t}(t),n=function(e,t,o){var n=o.css,i=o.sourceMap,r=t.convertToAbsoluteUrls===void 0&&i;(t.convertToAbsoluteUrls||r)&&(n=p(n)),i&&(n+="\n/*# sourceMappingURL=data:application/json;base64,"+btoa(unescape(encodeURIComponent(JSON.stringify(i))))+" */");var a=new Blob([n],{type:"text/css"}),l=e.href;e.href=URL.createObjectURL(a),l&&URL.revokeObjectURL(l)}.bind(null,o,t),i=function(){v(o),o.href&&URL.revokeObjectURL(o.href)}):(o=k(t),n=function(e,t){var o=t.css,n=t.media;if(n&&e.setAttribute("media",n),e.styleSheet)e.styleSheet.cssText=o;else{for(;e.firstChild;)e.removeChild(e.firstChild);e.appendChild(document.createTextNode(o))}}.bind(null,o),i=function(){v(o)});return n(e),function(t){if(t){if(t.css===e.css&&t.media===e.media&&t.sourceMap===e.sourceMap)return;n(e=t)}else i()}}e.exports=function(e,t){if(typeof DEBUG<"u"&&DEBUG&&typeof document!="object")throw new Error("The style-loader cannot be used in a non-browser environment");(t=t||{}).attrs=typeof t.attrs=="object"?t.attrs:{},t.singleton||typeof t.singleton=="boolean"||(t.singleton=a()),t.insertInto||(t.insertInto="head"),t.insertAt||(t.insertAt="bottom");var o=g(e,t);return f(o,t),function(e){for(var n=[],i=0;i<o.length;i++){var a=o[i];(l=r[a.id]).refs--,n.push(l)}for(e&&f(g(e,t),t),i=0;i<n.length;i++){var l;if((l=n[i]).refs===0){for(var c=0;c<l.parts.length;c++)l.parts[c]();delete r[l.id]}}}};var x,C=(x=[],function(e,t){return x[e]=t,x.filter(Boolean).join("\n")});function B(e,t,o,n){var i=o?"":n.css;if(e.styleSheet)e.styleSheet.cssText=C(t,i);else{var r=document.createTextNode(i),a=e.childNodes;a[t]&&e.removeChild(a[t]),a.length?e.insertBefore(r,a[t]):e.appendChild(r)}}},function(e,t){e.exports=function(e){var t=typeof window<"u"&&window.location;if(!t)throw new Error("fixUrls requires window.location");if(!e||typeof e!="string")return e;var o=t.protocol+"//"+t.host,n=o+t.pathname.replace(/\/[^\/]*$/,"/");return e.replace(/url\s*\(((?:[^)(]|\((?:[^)(]+|\([^)(]*\))*\))*)\)/gi,(function(e,t){var i,r=t.trim().replace(/^"(.*)"$/,(function(e,t){return t})).replace(/^'(.*)'$/,(function(e,t){return t}));return/^(#|data:|http:\/\/|https:\/\/|file:\/\/\/|\s*$)/i.test(r)?e:(i=r.indexOf("//")===0?r:r.indexOf("/")===0?o+r:n+r.replace(/^\.\//,""),"url("+JSON.stringify(i)+")")}))}},function(e,t,o){var n,i,r,a,l,c,d,h,p;e.exports=(n="cdx-notifies",i="cdx-notify",r="cdx-notify__cross",a="cdx-notify__button--confirm",l="cdx-notify__button--cancel",c="cdx-notify__input",d="cdx-notify__button",h="cdx-notify__btns-wrapper",{alert:p=function(e){var t=document.createElement("DIV"),o=document.createElement("DIV"),n=e.message,a=e.style;return t.classList.add(i),a&&t.classList.add(i+"--"+a),t.innerHTML=n,o.classList.add(r),o.addEventListener("click",t.remove.bind(t)),t.appendChild(o),t},confirm:function(e){var t=p(e),o=document.createElement("div"),n=document.createElement("button"),i=document.createElement("button"),c=t.querySelector("."+r),f=e.cancelHandler,g=e.okHandler;return o.classList.add(h),n.innerHTML=e.okText||"Confirm",i.innerHTML=e.cancelText||"Cancel",n.classList.add(d),i.classList.add(d),n.classList.add(a),i.classList.add(l),f&&typeof f=="function"&&(i.addEventListener("click",f),c.addEventListener("click",f)),g&&typeof g=="function"&&n.addEventListener("click",g),n.addEventListener("click",t.remove.bind(t)),i.addEventListener("click",t.remove.bind(t)),o.appendChild(n),o.appendChild(i),t.appendChild(o),t},prompt:function(e){var t=p(e),o=document.createElement("div"),n=document.createElement("button"),i=document.createElement("input"),l=t.querySelector("."+r),f=e.cancelHandler,g=e.okHandler;return o.classList.add(h),n.innerHTML=e.okText||"Ok",n.classList.add(d),n.classList.add(a),i.classList.add(c),e.placeholder&&i.setAttribute("placeholder",e.placeholder),e.default&&(i.value=e.default),e.inputType&&(i.type=e.inputType),f&&typeof f=="function"&&l.addEventListener("click",f),g&&typeof g=="function"&&n.addEventListener("click",(function(){g(i.value)})),n.addEventListener("click",t.remove.bind(t)),o.appendChild(i),o.appendChild(n),t.appendChild(o),t},getWrapper:function(){var e=document.createElement("DIV");return e.classList.add(n),e}})}])}))})(Ie);var Me=Ie.exports;const Ae=t(Me);class Bi{
/**
   * Show web notification
   *
   * @param {NotifierOptions | ConfirmNotifierOptions | PromptNotifierOptions} options - notification options
   */
show(e){Ae.show(e)}}class Ci extends E{
/**
   * @param moduleConfiguration - Module Configuration
   * @param moduleConfiguration.config - Editor's config
   * @param moduleConfiguration.eventsDispatcher - Editor's event dispatcher
   */
constructor({config:e,eventsDispatcher:t}){super({config:e,eventsDispatcher:t}),this.notifier=new Bi}get methods(){return{show:e=>this.show(e)}}
/**
   * Show notification
   *
   * @param {NotifierOptions} options - message option
   */show(e){return this.notifier.show(e)}}class Ti extends E{get methods(){const e=()=>this.isEnabled;return{toggle:e=>this.toggle(e),get isEnabled(){return e()}}}
/**
   * Set or toggle read-only state
   *
   * @param {boolean|undefined} state - set or toggle state
   * @returns {boolean} current value
   */toggle(e){return this.Editor.ReadOnly.toggle(e)}get isEnabled(){return this.Editor.ReadOnly.isEnabled}}var Le={exports:{}};(function(e){(function(t,o){e.exports=o()})(0,(function(){function e(e){var t=e.tags,o=Object.keys(t),n=o.map((function(e){return typeof t[e]})).every((function(e){return e==="object"||e==="boolean"||e==="function"}));if(!n)throw new Error("The configuration was invalid");this.config=e}var t=["P","LI","TD","TH","DIV","H1","H2","H3","H4","H5","H6","PRE"];function o(e){return t.indexOf(e.nodeName)!==-1}var n=["A","B","STRONG","I","EM","SUB","SUP","U","STRIKE"];function i(e){return n.indexOf(e.nodeName)!==-1}e.prototype.clean=function(e){const t=document.implementation.createHTMLDocument(),o=t.createElement("div");return o.innerHTML=e,this._sanitize(t,o),o.innerHTML},e.prototype._sanitize=function(e,t){var n=r(e,t),d=n.firstChild();if(d)do{if(d.nodeType!==Node.TEXT_NODE){if(d.nodeType===Node.COMMENT_NODE){t.removeChild(d),this._sanitize(e,t);break}var h,p=i(d);p&&(h=Array.prototype.some.call(d.childNodes,o));var f=!!t.parentNode,g=o(t)&&o(d)&&f,m=d.nodeName.toLowerCase(),v=a(this.config,m,d),k=p&&h;if(k||l(d,v)||!this.config.keepNestedBlockElements&&g){if(!(d.nodeName==="SCRIPT"||d.nodeName==="STYLE"))for(;d.childNodes.length>0;)t.insertBefore(d.childNodes[0],d);t.removeChild(d),this._sanitize(e,t);break}for(var y=0;y<d.attributes.length;y+=1){var w=d.attributes[y];c(w,v,d)&&(d.removeAttribute(w.name),y-=1)}this._sanitize(e,d)}else if(d.data.trim()===""&&(d.previousElementSibling&&o(d.previousElementSibling)||d.nextElementSibling&&o(d.nextElementSibling))){t.removeChild(d),this._sanitize(e,t);break}}while(d=n.nextSibling())};function r(e,t){return e.createTreeWalker(t,NodeFilter.SHOW_TEXT|NodeFilter.SHOW_ELEMENT|NodeFilter.SHOW_COMMENT,null,!1)}function a(e,t,o){return typeof e.tags[t]=="function"?e.tags[t](o):e.tags[t]}function l(e,t){return typeof t>"u"||typeof t=="boolean"&&!t}function c(e,t,o){var n=e.name.toLowerCase();return t!==!0&&(typeof t[n]=="function"?!t[n](e.value,o):typeof t[n]>"u"||t[n]===!1||typeof t[n]=="string"&&t[n]!==e.value)}return e}))})(Le);var Pe=Le.exports;const Ne=t(Pe);function Re(e,t){return e.map((e=>{const o=g(t)?t(e.tool):t;return x(o)||(e.data=je(e.data,o)),e}))}function De(e,t={}){const o={tags:t};return new Ne(o).clean(e)}function je(e,t){return Array.isArray(e)?Fe(e,t):m(e)?He(e,t):v(e)?ze(e,t):e}function Fe(e,t){return e.map((e=>je(e,t)))}function He(e,t){const o={};for(const n in e){if(!Object.prototype.hasOwnProperty.call(e,n))continue;const i=e[n],r=Ue(t[n])?t[n]:t;o[n]=je(i,r)}return o}function ze(e,t){return m(t)?De(e,t):t===!1?De(e,{}):e}function Ue(e){return m(e)||k(e)||g(e)}class Li extends E{
/**
   * Available methods
   *
   * @returns {SanitizerConfig}
   */
get methods(){return{clean:(e,t)=>this.clean(e,t)}}
/**
   * Perform sanitizing of a string
   *
   * @param {string} taintString - what to sanitize
   * @param {SanitizerConfig} config - sanitizer config
   * @returns {string}
   */clean(e,t){return De(e,t)}}class Pi extends E{
/**
   * Available methods
   *
   * @returns {Saver}
   */
get methods(){return{save:()=>this.save()}}
/**
   * Return Editor's data
   *
   * @returns {OutputData}
   */save(){const e="Editor's content can not be saved in read-only mode";return this.Editor.ReadOnly.isEnabled?(p(e,"warn"),Promise.reject(new Error(e))):this.Editor.Saver.save()}}class Ni extends E{constructor(){super(...arguments),this.selectionUtils=new b
/**
   * Available methods
   *
   * @returns {SelectionAPIInterface}
   */}get methods(){return{findParentTag:(e,t)=>this.findParentTag(e,t),expandToTag:e=>this.expandToTag(e),save:()=>this.selectionUtils.save(),restore:()=>this.selectionUtils.restore(),setFakeBackground:()=>this.selectionUtils.setFakeBackground(),removeFakeBackground:()=>this.selectionUtils.removeFakeBackground()}}
/**
   * Looks ahead from selection and find passed tag with class name
   *
   * @param {string} tagName - tag to find
   * @param {string} className - tag's class name
   * @returns {HTMLElement|null}
   */findParentTag(e,t){return this.selectionUtils.findParentTag(e,t)}
/**
   * Expand selection to passed tag
   *
   * @param {HTMLElement} node - tag that should contain selection
   */expandToTag(e){this.selectionUtils.expandToTag(e)}}class Ri extends E{get methods(){return{getBlockTools:()=>Array.from(this.Editor.Tools.blockTools.values())}}}class Di extends E{get classes(){return{block:"cdx-block",inlineToolButton:"ce-inline-tool",inlineToolButtonActive:"ce-inline-tool--active",input:"cdx-input",loader:"cdx-loader",button:"cdx-button",settingsButton:"cdx-settings-button",settingsButtonActive:"cdx-settings-button--active"}}}class Fi extends E{
/**
   * Available methods
   *
   * @returns {Toolbar}
   */
get methods(){return{close:()=>this.close(),open:()=>this.open(),toggleBlockSettings:e=>this.toggleBlockSettings(e),toggleToolbox:e=>this.toggleToolbox(e)}}open(){this.Editor.Toolbar.moveAndOpen()}close(){this.Editor.Toolbar.close()}
/**
   * Toggles Block Setting of the current block
   *
   * @param {boolean} openingState —  opening state of Block Setting
   */toggleBlockSettings(e){this.Editor.BlockManager.currentBlockIndex!==-1?e??!this.Editor.BlockSettings.opened?(this.Editor.Toolbar.moveAndOpen(),this.Editor.BlockSettings.open()):this.Editor.BlockSettings.close():p("Could't toggle the Toolbar because there is no block selected ","warn")}
/**
   * Open toolbox
   *
   * @param {boolean} openingState - Opening state of toolbox
   */toggleToolbox(e){this.Editor.BlockManager.currentBlockIndex!==-1?e??!this.Editor.Toolbar.toolbox.opened?(this.Editor.Toolbar.moveAndOpen(),this.Editor.Toolbar.toolbox.open()):this.Editor.Toolbar.toolbox.close():p("Could't toggle the Toolbox because there is no block selected ","warn")}}var $e={exports:{}};(function(e){(function(t,o){e.exports=o()})(window,(function(){return function(e){var t={};function o(n){if(t[n])return t[n].exports;var i=t[n]={i:n,l:!1,exports:{}};return e[n].call(i.exports,i,i.exports,o),i.l=!0,i.exports}return o.m=e,o.c=t,o.d=function(e,t,n){o.o(e,t)||Object.defineProperty(e,t,{enumerable:!0,get:n})},o.r=function(e){typeof Symbol<"u"&&Symbol.toStringTag&&Object.defineProperty(e,Symbol.toStringTag,{value:"Module"}),Object.defineProperty(e,"__esModule",{value:!0})},o.t=function(e,t){if(1&t&&(e=o(e)),8&t||4&t&&typeof e=="object"&&e&&e.__esModule)return e;var n=Object.create(null);if(o.r(n),Object.defineProperty(n,"default",{enumerable:!0,value:e}),2&t&&typeof e!="string")for(var i in e)o.d(n,i,function(t){return e[t]}.bind(null,i));return n},o.n=function(e){var t=e&&e.__esModule?function(){return e.default}:function(){return e};return o.d(t,"a",t),t},o.o=function(e,t){return Object.prototype.hasOwnProperty.call(e,t)},o.p="",o(o.s=0)}([function(e,t,o){e.exports=o(1)},function(e,t,o){o.r(t),o.d(t,"default",(function(){return s}));class s{constructor(){this.nodes={wrapper:null,content:null},this.showed=!1,this.offsetTop=10,this.offsetLeft=10,this.offsetRight=10,this.hidingDelay=0,this.handleWindowScroll=()=>{this.showed&&this.hide(!0)},this.loadStyles(),this.prepare(),window.addEventListener("scroll",this.handleWindowScroll,{passive:!0})}get CSS(){return{tooltip:"ct",tooltipContent:"ct__content",tooltipShown:"ct--shown",placement:{left:"ct--left",bottom:"ct--bottom",right:"ct--right",top:"ct--top"}}}show(e,t,o){this.nodes.wrapper||this.prepare(),this.hidingTimeout&&clearTimeout(this.hidingTimeout);const n=Object.assign({placement:"bottom",marginTop:0,marginLeft:0,marginRight:0,marginBottom:0,delay:70,hidingDelay:0},o);if(n.hidingDelay&&(this.hidingDelay=n.hidingDelay),this.nodes.content.innerHTML="",typeof t=="string")this.nodes.content.appendChild(document.createTextNode(t));else{if(!(t instanceof Node))throw Error("[CodeX Tooltip] Wrong type of «content» passed. It should be an instance of Node or String. But "+typeof t+" given.");this.nodes.content.appendChild(t)}switch(this.nodes.wrapper.classList.remove(...Object.values(this.CSS.placement)),n.placement){case"top":this.placeTop(e,n);break;case"left":this.placeLeft(e,n);break;case"right":this.placeRight(e,n);break;case"bottom":default:this.placeBottom(e,n)}n&&n.delay?this.showingTimeout=setTimeout((()=>{this.nodes.wrapper.classList.add(this.CSS.tooltipShown),this.showed=!0}),n.delay):(this.nodes.wrapper.classList.add(this.CSS.tooltipShown),this.showed=!0)}hide(e=!1){if(this.hidingDelay&&!e)return this.hidingTimeout&&clearTimeout(this.hidingTimeout),void(this.hidingTimeout=setTimeout((()=>{this.hide(!0)}),this.hidingDelay));this.nodes.wrapper.classList.remove(this.CSS.tooltipShown),this.showed=!1,this.showingTimeout&&clearTimeout(this.showingTimeout)}onHover(e,t,o){e.addEventListener("mouseenter",(()=>{this.show(e,t,o)})),e.addEventListener("mouseleave",(()=>{this.hide()}))}destroy(){this.nodes.wrapper.remove(),window.removeEventListener("scroll",this.handleWindowScroll)}prepare(){this.nodes.wrapper=this.make("div",this.CSS.tooltip),this.nodes.content=this.make("div",this.CSS.tooltipContent),this.append(this.nodes.wrapper,this.nodes.content),this.append(document.body,this.nodes.wrapper)}loadStyles(){const e="codex-tooltips-style";if(document.getElementById(e))return;const t=o(2),n=this.make("style",null,{textContent:t.toString(),id:e});this.prepend(document.head,n)}placeBottom(e,t){const o=e.getBoundingClientRect(),n=o.left+e.clientWidth/2-this.nodes.wrapper.offsetWidth/2,i=o.bottom+window.pageYOffset+this.offsetTop+t.marginTop;this.applyPlacement("bottom",n,i)}placeTop(e,t){const o=e.getBoundingClientRect(),n=o.left+e.clientWidth/2-this.nodes.wrapper.offsetWidth/2,i=o.top+window.pageYOffset-this.nodes.wrapper.clientHeight-this.offsetTop;this.applyPlacement("top",n,i)}placeLeft(e,t){const o=e.getBoundingClientRect(),n=o.left-this.nodes.wrapper.offsetWidth-this.offsetLeft-t.marginLeft,i=o.top+window.pageYOffset+e.clientHeight/2-this.nodes.wrapper.offsetHeight/2;this.applyPlacement("left",n,i)}placeRight(e,t){const o=e.getBoundingClientRect(),n=o.right+this.offsetRight+t.marginRight,i=o.top+window.pageYOffset+e.clientHeight/2-this.nodes.wrapper.offsetHeight/2;this.applyPlacement("right",n,i)}applyPlacement(e,t,o){this.nodes.wrapper.classList.add(this.CSS.placement[e]),this.nodes.wrapper.style.left=t+"px",this.nodes.wrapper.style.top=o+"px"}make(e,t=null,o={}){const n=document.createElement(e);Array.isArray(t)?n.classList.add(...t):t&&n.classList.add(t);for(const e in o)o.hasOwnProperty(e)&&(n[e]=o[e]);return n}append(e,t){Array.isArray(t)?t.forEach((t=>e.appendChild(t))):e.appendChild(t)}prepend(e,t){Array.isArray(t)?(t=t.reverse()).forEach((t=>e.prepend(t))):e.prepend(t)}}},function(e,t){e.exports='.ct{z-index:999;opacity:0;-webkit-user-select:none;-moz-user-select:none;-ms-user-select:none;user-select:none;pointer-events:none;-webkit-transition:opacity 50ms ease-in,-webkit-transform 70ms cubic-bezier(.215,.61,.355,1);transition:opacity 50ms ease-in,-webkit-transform 70ms cubic-bezier(.215,.61,.355,1);transition:opacity 50ms ease-in,transform 70ms cubic-bezier(.215,.61,.355,1);transition:opacity 50ms ease-in,transform 70ms cubic-bezier(.215,.61,.355,1),-webkit-transform 70ms cubic-bezier(.215,.61,.355,1);will-change:opacity,top,left;-webkit-box-shadow:0 8px 12px 0 rgba(29,32,43,.17),0 4px 5px -3px rgba(5,6,12,.49);box-shadow:0 8px 12px 0 rgba(29,32,43,.17),0 4px 5px -3px rgba(5,6,12,.49);border-radius:9px}.ct,.ct:before{position:absolute;top:0;left:0}.ct:before{content:"";bottom:0;right:0;background-color:#1d202b;z-index:-1;border-radius:4px}@supports(-webkit-mask-box-image:url("")){.ct:before{border-radius:0;-webkit-mask-box-image:url(\'data:image/svg+xml;charset=utf-8,<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24"><path d="M10.71 0h2.58c3.02 0 4.64.42 6.1 1.2a8.18 8.18 0 013.4 3.4C23.6 6.07 24 7.7 24 10.71v2.58c0 3.02-.42 4.64-1.2 6.1a8.18 8.18 0 01-3.4 3.4c-1.47.8-3.1 1.21-6.11 1.21H10.7c-3.02 0-4.64-.42-6.1-1.2a8.18 8.18 0 01-3.4-3.4C.4 17.93 0 16.3 0 13.29V10.7c0-3.02.42-4.64 1.2-6.1a8.18 8.18 0 013.4-3.4C6.07.4 7.7 0 10.71 0z"/></svg>\') 48% 41% 37.9% 53.3%}}@media (--mobile){.ct{display:none}}.ct__content{padding:6px 10px;color:#cdd1e0;font-size:12px;text-align:center;letter-spacing:.02em;line-height:1em}.ct:after{content:"";width:8px;height:8px;position:absolute;background-color:#1d202b;z-index:-1}.ct--bottom{-webkit-transform:translateY(5px);transform:translateY(5px)}.ct--bottom:after{top:-3px;left:50%;-webkit-transform:translateX(-50%) rotate(-45deg);transform:translateX(-50%) rotate(-45deg)}.ct--top{-webkit-transform:translateY(-5px);transform:translateY(-5px)}.ct--top:after{top:auto;bottom:-3px;left:50%;-webkit-transform:translateX(-50%) rotate(-45deg);transform:translateX(-50%) rotate(-45deg)}.ct--left{-webkit-transform:translateX(-5px);transform:translateX(-5px)}.ct--left:after{top:50%;left:auto;right:0;-webkit-transform:translate(41.6%,-50%) rotate(-45deg);transform:translate(41.6%,-50%) rotate(-45deg)}.ct--right{-webkit-transform:translateX(5px);transform:translateX(5px)}.ct--right:after{top:50%;left:0;-webkit-transform:translate(-41.6%,-50%) rotate(-45deg);transform:translate(-41.6%,-50%) rotate(-45deg)}.ct--shown{opacity:1;-webkit-transform:none;transform:none}'}]).default}))})($e);var We=$e.exports;const Ke=t(We);let Xe=null;function Ve(){Xe||(Xe=new Ke)}function qe(e,t,o){Ve(),Xe==null||Xe.show(e,t,o)}function Ze(e=!1){Ve(),Xe==null||Xe.hide(e)}function Ge(e,t,o){Ve(),Xe==null||Xe.onHover(e,t,o)}function Qe(){Xe==null||Xe.destroy(),Xe=null}class Ui extends E{
/**
   * @class
   * @param moduleConfiguration - Module Configuration
   * @param moduleConfiguration.config - Editor's config
   * @param moduleConfiguration.eventsDispatcher - Editor's event dispatcher
   */
constructor({config:e,eventsDispatcher:t}){super({config:e,eventsDispatcher:t})}get methods(){return{show:(e,t,o)=>this.show(e,t,o),hide:()=>this.hide(),onHover:(e,t,o)=>this.onHover(e,t,o)}}
/**
   * Method show tooltip on element with passed HTML content
   *
   * @param {HTMLElement} element - element on which tooltip should be shown
   * @param {TooltipContent} content - tooltip content
   * @param {TooltipOptions} options - tooltip options
   */show(e,t,o){qe(e,t,o)}hide(){Ze()}
/**
   * Decorator for showing Tooltip by mouseenter/mouseleave
   *
   * @param {HTMLElement} element - element on which tooltip should be shown
   * @param {TooltipContent} content - tooltip content
   * @param {TooltipOptions} options - tooltip options
   */onHover(e,t,o){Ge(e,t,o)}}class Wi extends E{get methods(){return{nodes:this.editorNodes}}get editorNodes(){return{wrapper:this.Editor.UI.nodes.wrapper,redactor:this.Editor.UI.nodes.redactor}}}function Je(e,t){const o={};return Object.entries(e).forEach((([e,n])=>{if(m(n)){const i=t?`${t}.${e}`:e;Object.values(n).every((e=>v(e)))?o[e]=i:o[e]=Je(n,i)}else o[e]=n})),o}const et=Je(te);function tt(e,t){const o={};return Object.keys(e).forEach((n=>{const i=t[n];i!==void 0?o[i]=e[n]:o[n]=e[n]})),o}const ot=class Ee{
/**
   * @param {HTMLElement[]} nodeList — the list of iterable HTML-items
   * @param {string} focusedCssClass - user-provided CSS-class that will be set in flipping process
   */
constructor(e,t){this.cursor=-1,this.items=[],this.items=e||[],this.focusedCssClass=t
/**
   * Returns Focused button Node
   *
   * @returns {HTMLElement}
   */}get currentItem(){return this.cursor===-1?null:this.items[this.cursor]}
/**
   * Sets cursor to specified position
   *
   * @param cursorPosition - new cursor position
   */setCursor(e){e<this.items.length&&e>=-1&&(this.dropCursor(),this.cursor=e,this.items[this.cursor].classList.add(this.focusedCssClass)
/**
   * Sets items. Can be used when iterable items changed dynamically
   *
   * @param {HTMLElement[]} nodeList - nodes to iterate
   */)}setItems(e){this.items=e}next(){this.cursor=this.leafNodesAndReturnIndex(Ee.directions.RIGHT)}previous(){this.cursor=this.leafNodesAndReturnIndex(Ee.directions.LEFT)}dropCursor(){this.cursor!==-1&&(this.items[this.cursor].classList.remove(this.focusedCssClass),this.cursor=-1
/**
   * Leafs nodes inside the target list from active element
   *
   * @param {string} direction - leaf direction. Can be 'left' or 'right'
   * @returns {number} index of focused node
   */)}leafNodesAndReturnIndex(e){if(this.items.length===0)return this.cursor;let t=this.cursor;return t===-1?t=e===Ee.directions.RIGHT?-1:0:this.items[t].classList.remove(this.focusedCssClass),t=e===Ee.directions.RIGHT?(t+1)%this.items.length:(this.items.length+t-1)%this.items.length,u.canSetCaret(this.items[t])&&S((()=>b.setCursor(this.items[t])),50)(),this.items[t].classList.add(this.focusedCssClass),t}};ot.directions={RIGHT:"right",LEFT:"left"};let nt=ot;class ce{
/**
   * @param options - different constructing settings
   */
constructor(e){this.iterator=null,this.activated=!1,this.flipCallbacks=[],this.onKeyDown=e=>{if(!(!this.isEventReadyForHandling(e)||e.shiftKey===!0))switch(ce.usedKeys.includes(e.keyCode)&&e.preventDefault(),e.keyCode){case a.TAB:this.handleTabPress(e);break;case a.LEFT:case a.UP:this.flipLeft();break;case a.RIGHT:case a.DOWN:this.flipRight();break;case a.ENTER:this.handleEnterPress(e);break}},this.iterator=new nt(e.items,e.focusedItemClass),this.activateCallback=e.activateCallback,this.allowedKeys=e.allowedKeys||ce.usedKeys}get isActivated(){return this.activated}static get usedKeys(){return[a.TAB,a.LEFT,a.RIGHT,a.ENTER,a.UP,a.DOWN]}
/**
   * Active tab/arrows handling by flipper
   *
   * @param items - Some modules (like, InlineToolbar, BlockSettings) might refresh buttons dynamically
   * @param cursorPosition - index of the item that should be focused once flipper is activated
   */activate(e,t){this.activated=!0,e&&this.iterator.setItems(e),t!==void 0&&this.iterator.setCursor(t),document.addEventListener("keydown",this.onKeyDown,!0)}deactivate(){this.activated=!1,this.dropCursor(),document.removeEventListener("keydown",this.onKeyDown)}focusFirst(){this.dropCursor(),this.flipRight()}flipLeft(){this.iterator.previous(),this.flipCallback()}flipRight(){this.iterator.next(),this.flipCallback()}hasFocus(){return!!this.iterator.currentItem}
/**
   * Registeres function that should be executed on each navigation action
   *
   * @param cb - function to execute
   */onFlip(e){this.flipCallbacks.push(e)}
/**
   * Unregisteres function that is executed on each navigation action
   *
   * @param cb - function to stop executing
   */removeOnFlip(e){this.flipCallbacks=this.flipCallbacks.filter((t=>t!==e))}dropCursor(){this.iterator.dropCursor()}
/**
   * This function is fired before handling flipper keycodes
   * The result of this function defines if it is need to be handled or not
   *
   * @param {KeyboardEvent} event - keydown keyboard event
   * @returns {boolean}
   */isEventReadyForHandling(e){return this.activated&&this.allowedKeys.includes(e.keyCode)}
/**
   * When flipper is activated tab press will leaf the items
   *
   * @param {KeyboardEvent} event - tab keydown event
   */handleTabPress(e){switch(e.shiftKey?nt.directions.LEFT:nt.directions.RIGHT){case nt.directions.RIGHT:this.flipRight();break;case nt.directions.LEFT:this.flipLeft();break}}
/**
   * Enter press will click current item if flipper is activated
   *
   * @param {KeyboardEvent} event - enter keydown event
   */handleEnterPress(e){this.activated&&(this.iterator.currentItem&&(e.stopPropagation(),e.preventDefault(),this.iterator.currentItem.click()),g(this.activateCallback)&&this.activateCallback(this.iterator.currentItem))}flipCallback(){this.iterator.currentItem&&this.iterator.currentItem.scrollIntoViewIfNeeded(),this.flipCallbacks.forEach((e=>e()))}}const it='<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" fill="none" viewBox="0 0 24 24"><path stroke="currentColor" stroke-linecap="round" stroke-width="2" d="M9 12L9 7.1C9 7.04477 9.04477 7 9.1 7H10.4C11.5 7 14 7.1 14 9.5C14 9.5 14 12 11 12M9 12V16.8C9 16.9105 9.08954 17 9.2 17H12.5C14 17 15 16 15 14.5C15 11.7046 11 12 11 12M9 12H11"/></svg>',st='<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" fill="none" viewBox="0 0 24 24"><path stroke="currentColor" stroke-linecap="round" stroke-width="2" d="M7 10L11.8586 14.8586C11.9367 14.9367 12.0633 14.9367 12.1414 14.8586L17 10"/></svg>',rt='<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" fill="none" viewBox="0 0 24 24"><path stroke="currentColor" stroke-linecap="round" stroke-width="2" d="M14.5 17.5L9.64142 12.6414C9.56331 12.5633 9.56331 12.4367 9.64142 12.3586L14.5 7.5"/></svg>',at='<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" fill="none" viewBox="0 0 24 24"><path stroke="currentColor" stroke-linecap="round" stroke-width="2" d="M9.58284 17.5L14.4414 12.6414C14.5195 12.5633 14.5195 12.4367 14.4414 12.3586L9.58284 7.5"/></svg>',lt='<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" fill="none" viewBox="0 0 24 24"><path stroke="currentColor" stroke-linecap="round" stroke-width="2" d="M7 15L11.8586 10.1414C11.9367 10.0633 12.0633 10.0633 12.1414 10.1414L17 15"/></svg>',dt='<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" fill="none" viewBox="0 0 24 24"><path stroke="currentColor" stroke-linecap="round" stroke-width="2" d="M8 8L12 12M12 12L16 16M12 12L16 8M12 12L8 16"/></svg>',ht='<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" fill="none" viewBox="0 0 24 24"><circle cx="12" cy="12" r="4" stroke="currentColor" stroke-width="2"/></svg>',ut='<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" fill="none" viewBox="0 0 24 24"><path stroke="currentColor" stroke-linecap="round" stroke-width="2" d="M13.34 10C12.4223 12.7337 11 17 11 17"/><path stroke="currentColor" stroke-linecap="round" stroke-width="2" d="M14.21 7H14.2"/></svg>',pt='<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" fill="none" viewBox="0 0 24 24"><path stroke="currentColor" stroke-linecap="round" stroke-width="2" d="M7.69998 12.6L7.67896 12.62C6.53993 13.7048 6.52012 15.5155 7.63516 16.625V16.625C8.72293 17.7073 10.4799 17.7102 11.5712 16.6314L13.0263 15.193C14.0703 14.1609 14.2141 12.525 13.3662 11.3266L13.22 11.12"/><path stroke="currentColor" stroke-linecap="round" stroke-width="2" d="M16.22 11.12L16.3564 10.9805C17.2895 10.0265 17.3478 8.5207 16.4914 7.49733V7.49733C15.5691 6.39509 13.9269 6.25143 12.8271 7.17675L11.3901 8.38588C10.0935 9.47674 9.95706 11.4241 11.0888 12.6852L11.12 12.72"/></svg>',ft='<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" fill="none" viewBox="0 0 24 24"><path stroke="currentColor" stroke-linecap="round" stroke-width="2.6" d="M9.40999 7.29999H9.4"/><path stroke="currentColor" stroke-linecap="round" stroke-width="2.6" d="M14.6 7.29999H14.59"/><path stroke="currentColor" stroke-linecap="round" stroke-width="2.6" d="M9.30999 12H9.3"/><path stroke="currentColor" stroke-linecap="round" stroke-width="2.6" d="M14.6 12H14.59"/><path stroke="currentColor" stroke-linecap="round" stroke-width="2.6" d="M9.40999 16.7H9.4"/><path stroke="currentColor" stroke-linecap="round" stroke-width="2.6" d="M14.6 16.7H14.59"/></svg>',gt='<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" fill="none" viewBox="0 0 24 24"><path stroke="currentColor" stroke-linecap="round" stroke-width="2" d="M12 7V12M12 17V12M17 12H12M12 12H7"/></svg>',mt='<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" fill="none" viewBox="0 0 24 24"><path stroke="currentColor" stroke-linecap="round" stroke-width="2" d="M11.5 17.5L5 11M5 11V15.5M5 11H9.5"/><path stroke="currentColor" stroke-linecap="round" stroke-width="2" d="M12.5 6.5L19 13M19 13V8.5M19 13H14.5"/></svg>',bt='<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" fill="none" viewBox="0 0 24 24"><circle cx="10.5" cy="10.5" r="5.5" stroke="currentColor" stroke-width="2"/><line x1="15.4142" x2="19" y1="15" y2="18.5858" stroke="currentColor" stroke-linecap="round" stroke-width="2"/></svg>',vt='<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" fill="none" viewBox="0 0 24 24"><path stroke="currentColor" stroke-linecap="round" stroke-width="2" d="M15.7795 11.5C15.7795 11.5 16.053 11.1962 16.5497 10.6722C17.4442 9.72856 17.4701 8.2475 16.5781 7.30145V7.30145C15.6482 6.31522 14.0873 6.29227 13.1288 7.25073L11.8796 8.49999"/><path stroke="currentColor" stroke-linecap="round" stroke-width="2" d="M8.24517 12.3883C8.24517 12.3883 7.97171 12.6922 7.47504 13.2161C6.58051 14.1598 6.55467 15.6408 7.44666 16.5869V16.5869C8.37653 17.5731 9.93744 17.5961 10.8959 16.6376L12.1452 15.3883"/><path stroke="currentColor" stroke-linecap="round" stroke-width="2" d="M17.7802 15.1032L16.597 14.9422C16.0109 14.8624 15.4841 15.3059 15.4627 15.8969L15.4199 17.0818"/><path stroke="currentColor" stroke-linecap="round" stroke-width="2" d="M6.39064 9.03238L7.58432 9.06668C8.17551 9.08366 8.6522 8.58665 8.61056 7.99669L8.5271 6.81397"/><line x1="12.1142" x2="11.7" y1="12.2" y2="11.7858" stroke="currentColor" stroke-linecap="round" stroke-width="2"/></svg>',yt='<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" fill="none" viewBox="0 0 24 24"><rect width="14" height="14" x="5" y="5" stroke="currentColor" stroke-width="2" rx="4"/><line x1="12" x2="12" y1="9" y2="12" stroke="currentColor" stroke-linecap="round" stroke-width="2"/><path stroke="currentColor" stroke-linecap="round" stroke-width="2" d="M12 15.02V15.01"/></svg>',wt="__",Et="--";function Ct(e){return(t,o)=>[[e,t].filter((e=>!!e)).join(wt),o].filter((e=>!!e)).join(Et)}const Bt=Ct("ce-hint"),St={root:Bt(),alignedStart:Bt(null,"align-left"),alignedCenter:Bt(null,"align-center"),title:Bt("title"),description:Bt("description")};class as{
/**
   * Constructs the hint content instance
   *
   * @param params - hint content parameters
   */
constructor(e){this.nodes={root:u.make("div",[St.root,e.alignment==="center"?St.alignedCenter:St.alignedStart]),title:u.make("div",St.title,{textContent:e.title})},this.nodes.root.appendChild(this.nodes.title),e.description!==void 0&&(this.nodes.description=u.make("div",St.description,{textContent:e.description}),this.nodes.root.appendChild(this.nodes.description))}getElement(){return this.nodes.root}}class xt{
/**
   * Constructs the instance
   *
   * @param params - instance parameters
   */
constructor(e){this.params=e}get name(){if(this.params!==void 0&&"name"in this.params)return this.params.name}destroy(){Ze()}onChildrenOpen(){var e;this.params!==void 0&&"children"in this.params&&typeof((e=this.params.children)==null?void 0:e.onOpen)=="function"&&this.params.children.onOpen()}onChildrenClose(){var e;this.params!==void 0&&"children"in this.params&&typeof((e=this.params.children)==null?void 0:e.onClose)=="function"&&this.params.children.onClose()}handleClick(){var e,t;this.params!==void 0&&"onActivate"in this.params&&((t=(e=this.params).onActivate)==null||t.call(e,this.params))}
/**
   * Adds hint to the item element if hint data is provided
   *
   * @param itemElement - popover item root element to add hint to
   * @param hintData - hint data
   */addHint(e,t){const o=new as(t);Ge(e,o.getElement(),{placement:t.position,hidingDelay:100})}get children(){var e;return this.params!==void 0&&"children"in this.params&&((e=this.params.children)==null?void 0:e.items)!==void 0?this.params.children.items:[]}get hasChildren(){return this.children.length>0}get isChildrenOpen(){var e;return this.params!==void 0&&"children"in this.params&&((e=this.params.children)==null?void 0:e.isOpen)===!0}get isChildrenFlippable(){var e;return!(this.params===void 0||!("children"in this.params)||((e=this.params.children)==null?void 0:e.isFlippable)===!1)}get isChildrenSearchable(){var e;return this.params!==void 0&&"children"in this.params&&((e=this.params.children)==null?void 0:e.searchable)===!0}get closeOnActivate(){return this.params!==void 0&&"closeOnActivate"in this.params&&this.params.closeOnActivate}get isActive(){return this.params!==void 0&&"isActive"in this.params&&(typeof this.params.isActive=="function"?this.params.isActive():this.params.isActive===!0)}}const It=Ct("ce-popover-item"),Ot={container:It(),active:It(null,"active"),disabled:It(null,"disabled"),focused:It(null,"focused"),hidden:It(null,"hidden"),confirmationState:It(null,"confirmation"),noHover:It(null,"no-hover"),noFocus:It(null,"no-focus"),title:It("title"),secondaryTitle:It("secondary-title"),icon:It("icon"),iconTool:It("icon","tool"),iconChevronRight:It("icon","chevron-right"),wobbleAnimation:Ct("wobble")()};class re extends xt{
/**
   * Constructs popover item instance
   *
   * @param params - popover item construction params
   * @param renderParams - popover item render params.
   * The parameters that are not set by user via popover api but rather depend on technical implementation
   */
constructor(e,t){super(e),this.params=e,this.nodes={root:null,icon:null},this.confirmationState=null,this.removeSpecialFocusBehavior=()=>{var e;(e=this.nodes.root)==null||e.classList.remove(Ot.noFocus)},this.removeSpecialHoverBehavior=()=>{var e;(e=this.nodes.root)==null||e.classList.remove(Ot.noHover)},this.onErrorAnimationEnd=()=>{var e,t;(e=this.nodes.icon)==null||e.classList.remove(Ot.wobbleAnimation),(t=this.nodes.icon)==null||t.removeEventListener("animationend",this.onErrorAnimationEnd)},this.nodes.root=this.make(e,t)}get isDisabled(){return this.params.isDisabled===!0}get toggle(){return this.params.toggle}get title(){return this.params.title}get isConfirmationStateEnabled(){return this.confirmationState!==null}get isFocused(){return this.nodes.root!==null&&this.nodes.root.classList.contains(Ot.focused)}getElement(){return this.nodes.root}handleClick(){this.isConfirmationStateEnabled&&this.confirmationState!==null?this.activateOrEnableConfirmationMode(this.confirmationState):this.activateOrEnableConfirmationMode(this.params)}
/**
   * Toggles item active state
   *
   * @param isActive - true if item should strictly should become active
   */toggleActive(e){var t;(t=this.nodes.root)==null||t.classList.toggle(Ot.active,e)}
/**
   * Toggles item hidden state
   *
   * @param isHidden - true if item should be hidden
   */toggleHidden(e){var t;(t=this.nodes.root)==null||t.classList.toggle(Ot.hidden,e)}reset(){this.isConfirmationStateEnabled&&this.disableConfirmationMode()}onFocus(){this.disableSpecialHoverAndFocusBehavior()}
/**
   * Constructs HTML element corresponding to popover item params
   *
   * @param params - item construction params
   * @param renderParams - popover item render params
   */make(e,t){var o,n;const i=(t==null?void 0:t.wrapperTag)||"div",r=u.make(i,Ot.container,{type:i==="button"?"button":void 0});return e.name&&(r.dataset.itemName=e.name),this.nodes.icon=u.make("div",[Ot.icon,Ot.iconTool],{innerHTML:e.icon||ht}),r.appendChild(this.nodes.icon),e.title!==void 0&&r.appendChild(u.make("div",Ot.title,{innerHTML:e.title||""})),e.secondaryLabel&&r.appendChild(u.make("div",Ot.secondaryTitle,{textContent:e.secondaryLabel})),this.hasChildren&&r.appendChild(u.make("div",[Ot.icon,Ot.iconChevronRight],{innerHTML:at})),this.isActive&&r.classList.add(Ot.active),e.isDisabled&&r.classList.add(Ot.disabled),e.hint!==void 0&&((o=t==null?void 0:t.hint)==null?void 0:o.enabled)!==!1&&this.addHint(r,{...e.hint,position:((n=t==null?void 0:t.hint)==null?void 0:n.position)||"right"}),r
/**
   * Activates confirmation mode for the item.
   *
   * @param newState - new popover item params that should be applied
   */}enableConfirmationMode(e){if(this.nodes.root===null)return;const t={...this.params,...e,confirmation:"confirmation"in e?e.confirmation:void 0},o=this.make(t);this.nodes.root.innerHTML=o.innerHTML,this.nodes.root.classList.add(Ot.confirmationState),this.confirmationState=e,this.enableSpecialHoverAndFocusBehavior()}disableConfirmationMode(){if(this.nodes.root===null)return;const e=this.make(this.params);this.nodes.root.innerHTML=e.innerHTML,this.nodes.root.classList.remove(Ot.confirmationState),this.confirmationState=null,this.disableSpecialHoverAndFocusBehavior()}enableSpecialHoverAndFocusBehavior(){var e,t,o;(e=this.nodes.root)==null||e.classList.add(Ot.noHover),(t=this.nodes.root)==null||t.classList.add(Ot.noFocus),(o=this.nodes.root)==null||o.addEventListener("mouseleave",this.removeSpecialHoverBehavior,{once:!0})}disableSpecialHoverAndFocusBehavior(){var e;this.removeSpecialFocusBehavior(),this.removeSpecialHoverBehavior(),(e=this.nodes.root)==null||e.removeEventListener("mouseleave",this.removeSpecialHoverBehavior)
/**
   * Executes item's onActivate callback if the item has no confirmation configured
   *
   * @param item - item to activate or bring to confirmation mode
   */}activateOrEnableConfirmationMode(e){var t;if("confirmation"in e&&e.confirmation!==void 0)this.enableConfirmationMode(e.confirmation);else try{(t=e.onActivate)==null||t.call(e,e),this.disableConfirmationMode()}catch{this.animateError()}}animateError(){var e,t,o;(e=this.nodes.icon)!=null&&e.classList.contains(Ot.wobbleAnimation)||((t=this.nodes.icon)==null||t.classList.add(Ot.wobbleAnimation),(o=this.nodes.icon)==null||o.addEventListener("animationend",this.onErrorAnimationEnd))}}const _t=Ct("ce-popover-item-separator"),Mt={container:_t(),line:_t("line"),hidden:_t(null,"hidden")};class Qo extends xt{constructor(){super(),this.nodes={root:u.make("div",Mt.container),line:u.make("div",Mt.line)},this.nodes.root.appendChild(this.nodes.line)}getElement(){return this.nodes.root}
/**
   * Toggles item hidden state
   *
   * @param isHidden - true if item should be hidden
   */toggleHidden(e){var t;(t=this.nodes.root)==null||t.classList.toggle(Mt.hidden,e)}}var At=(e=>(e.Closed="closed",e.ClosedOnActivate="closed-on-activate",e))(At||{});const Lt=Ct("ce-popover"),Pt={popover:Lt(),popoverContainer:Lt("container"),popoverOpenTop:Lt(null,"open-top"),popoverOpenLeft:Lt(null,"open-left"),popoverOpened:Lt(null,"opened"),search:Lt("search"),nothingFoundMessage:Lt("nothing-found-message"),nothingFoundMessageDisplayed:Lt("nothing-found-message","displayed"),items:Lt("items"),overlay:Lt("overlay"),overlayHidden:Lt("overlay","hidden"),popoverNested:Lt(null,"nested"),getPopoverNestedClass:e=>Lt(null,`nested-level-${e.toString()}`),popoverInline:Lt(null,"inline"),popoverHeader:Lt("header")};var Nt=(e=>(e.NestingLevel="--nesting-level",e.PopoverHeight="--popover-height",e.InlinePopoverWidth="--inline-popover-width",e.TriggerItemLeft="--trigger-item-left",e.TriggerItemTop="--trigger-item-top",e))(Nt||{});const Rt=Ct("ce-popover-item-html"),Dt={root:Rt(),hidden:Rt(null,"hidden")};class Se extends xt{
/**
   * Constructs the instance
   *
   * @param params – instance parameters
   * @param renderParams – popover item render params.
   * The parameters that are not set by user via popover api but rather depend on technical implementation
   */
constructor(e,t){var o,n;super(e),this.nodes={root:u.make("div",Dt.root)},this.nodes.root.appendChild(e.element),e.name&&(this.nodes.root.dataset.itemName=e.name),e.hint!==void 0&&((o=t==null?void 0:t.hint)==null?void 0:o.enabled)!==!1&&this.addHint(this.nodes.root,{...e.hint,position:((n=t==null?void 0:t.hint)==null?void 0:n.position)||"right"})}getElement(){return this.nodes.root}
/**
   * Toggles item hidden state
   *
   * @param isHidden - true if item should be hidden
   */toggleHidden(e){var t;(t=this.nodes.root)==null||t.classList.toggle(Dt.hidden,e)}getControls(){const e=this.nodes.root.querySelectorAll(`button, ${u.allInputsSelector}`);return Array.from(e)}}class Jo extends Oe{
/**
   * Constructs the instance
   *
   * @param params - popover construction params
   * @param itemsRenderParams - popover item render params.
   * The parameters that are not set by user via popover api but rather depend on technical implementation
   */
constructor(e,t={}){super(),this.params=e,this.itemsRenderParams=t,this.listeners=new _e,this.messages={nothingFound:"Nothing found",search:"Search"},this.items=this.buildItems(e.items),e.messages&&(this.messages={...this.messages,...e.messages}),this.nodes={},this.nodes.popoverContainer=u.make("div",[Pt.popoverContainer]),this.nodes.nothingFoundMessage=u.make("div",[Pt.nothingFoundMessage],{textContent:this.messages.nothingFound}),this.nodes.popoverContainer.appendChild(this.nodes.nothingFoundMessage),this.nodes.items=u.make("div",[Pt.items]),this.items.forEach((e=>{const t=e.getElement();t!==null&&this.nodes.items.appendChild(t)})),this.nodes.popoverContainer.appendChild(this.nodes.items),this.listeners.on(this.nodes.popoverContainer,"click",(e=>this.handleClick(e))),this.nodes.popover=u.make("div",[Pt.popover,this.params.class]),this.nodes.popover.appendChild(this.nodes.popoverContainer)}get itemsDefault(){return this.items.filter((e=>e instanceof re))}getElement(){return this.nodes.popover}show(){this.nodes.popover.classList.add(Pt.popoverOpened),this.search!==void 0&&this.search.focus()}hide(){this.nodes.popover.classList.remove(Pt.popoverOpened),this.nodes.popover.classList.remove(Pt.popoverOpenTop),this.itemsDefault.forEach((e=>e.reset())),this.search!==void 0&&this.search.clear(),this.emit(At.Closed)}destroy(){var e;this.items.forEach((e=>e.destroy())),this.nodes.popover.remove(),this.listeners.removeAll(),(e=this.search)==null||e.destroy()
/**
   * Looks for the item by name and imitates click on it
   *
   * @param name - name of the item to activate
   */}activateItemByName(e){const t=this.items.find((t=>t.name===e));this.handleItemClick(t)}
/**
   * Factory method for creating popover items
   *
   * @param items - list of items params
   */buildItems(e){return e.map((e=>{switch(e.type){case we.Separator:return new Qo;case we.Html:return new Se(e,this.itemsRenderParams[we.Html]);default:return new re(e,this.itemsRenderParams[we.Default])}}))}
/**
   * Retrieves popover item that is the target of the specified event
   *
   * @param event - event to retrieve popover item from
   */getTargetItem(e){return this.items.filter((e=>e instanceof re||e instanceof Se)).find((t=>{const o=t.getElement();return o!==null&&e.composedPath().includes(o)}))}
/**
   * Handles popover item click
   *
   * @param item - item to handle click of
   */handleItemClick(e){if(!("isDisabled"in e&&e.isDisabled)){if(e.hasChildren){this.showNestedItems(e),"handleClick"in e&&typeof e.handleClick=="function"&&e.handleClick();return}this.itemsDefault.filter((t=>t!==e)).forEach((e=>e.reset())),"handleClick"in e&&typeof e.handleClick=="function"&&e.handleClick(),this.toggleItemActivenessIfNeeded(e),e.closeOnActivate&&(this.hide(),this.emit(At.ClosedOnActivate))}}
/**
   * Handles clicks inside popover
   *
   * @param event - item to handle click of
   */handleClick(e){const t=this.getTargetItem(e);t!==void 0&&this.handleItemClick(t)}
/**
   * - Toggles item active state, if clicked popover item has property 'toggle' set to true.
   *
   * - Performs radiobutton-like behavior if the item has property 'toggle' set to string key.
   * (All the other items with the same key get inactive, and the item gets active)
   *
   * @param clickedItem - popover item that was clicked
   */toggleItemActivenessIfNeeded(e){if(e instanceof re&&(e.toggle===!0&&e.toggleActive(),typeof e.toggle=="string")){const t=this.itemsDefault.filter((t=>t.toggle===e.toggle));if(t.length===1){e.toggleActive();return}t.forEach((t=>{t.toggleActive(t===e)}))}}}var jt=(e=>(e.Search="search",e))(jt||{});const Ft=Ct("cdx-search-field"),Ht={wrapper:Ft(),icon:Ft("icon"),input:Ft("input")};class ls extends Oe{
/**
   * @param options - available config
   * @param options.items - searchable items list
   * @param options.placeholder - input placeholder
   */
constructor({items:e,placeholder:t}){super(),this.listeners=new _e,this.items=e,this.wrapper=u.make("div",Ht.wrapper);const o=u.make("div",Ht.icon,{innerHTML:bt});this.input=u.make("input",Ht.input,{placeholder:t,tabIndex:-1}),this.wrapper.appendChild(o),this.wrapper.appendChild(this.input),this.listeners.on(this.input,"input",(()=>{this.searchQuery=this.input.value,this.emit(jt.Search,{query:this.searchQuery,items:this.foundItems})}))}getElement(){return this.wrapper}focus(){this.input.focus()}clear(){this.input.value="",this.searchQuery="",this.emit(jt.Search,{query:"",items:this.foundItems})}destroy(){this.listeners.removeAll()}get foundItems(){return this.items.filter((e=>this.checkItem(e)))}
/**
   * Contains logic for checking whether passed item conforms the search query
   *
   * @param item - item to be checked
   */checkItem(e){var t,o;const n=((t=e.title)==null?void 0:t.toLowerCase())||"",i=(o=this.searchQuery)==null?void 0:o.toLowerCase();return i!==void 0&&n.includes(i)}}var zt=Object.defineProperty,Ut=Object.getOwnPropertyDescriptor,$t=(e,t,o,n)=>{for(var i,r=n>1?void 0:n?Ut(t,o):t,a=e.length-1;a>=0;a--)(i=e[a])&&(r=(n?i(t,o,r):i(r))||r);return n&&r&&zt(t,o,r),r};const Wt=class tn extends Jo{
/**
   * Construct the instance
   *
   * @param params - popover params
   * @param itemsRenderParams – popover item render params.
   * The parameters that are not set by user via popover api but rather depend on technical implementation
   */
constructor(e,t){super(e,t),this.nestingLevel=0,this.nestedPopoverTriggerItem=null,this.previouslyHoveredItem=null,this.scopeElement=document.body,this.hide=()=>{var e;super.hide(),this.destroyNestedPopoverIfExists(),(e=this.flipper)==null||e.deactivate(),this.previouslyHoveredItem=null},this.onFlip=()=>{const e=this.itemsDefault.find((e=>e.isFocused));e==null||e.onFocus()},this.onSearch=e=>{var t;const o=e.query==="",n=e.items.length===0;this.items.forEach((t=>{let i=!1;t instanceof re?i=!e.items.includes(t):(t instanceof Qo||t instanceof Se)&&(i=n||!o),t.toggleHidden(i)})),this.toggleNothingFoundMessage(n);const i=e.query===""?this.flippableElements:e.items.map((e=>e.getElement()));(t=this.flipper)!=null&&t.isActivated&&(this.flipper.deactivate(),this.flipper.activate(i))},e.nestingLevel!==void 0&&(this.nestingLevel=e.nestingLevel),this.nestingLevel>0&&this.nodes.popover.classList.add(Pt.popoverNested),e.scopeElement!==void 0&&(this.scopeElement=e.scopeElement),this.nodes.popoverContainer!==null&&this.listeners.on(this.nodes.popoverContainer,"mouseover",(e=>this.handleHover(e))),e.searchable&&this.addSearch(),e.flippable!==!1&&(this.flipper=new ce({items:this.flippableElements,focusedItemClass:Ot.focused,allowedKeys:[a.TAB,a.UP,a.DOWN,a.ENTER]}),this.flipper.onFlip(this.onFlip))}hasFocus(){return this.flipper!==void 0&&this.flipper.hasFocus()}get scrollTop(){return this.nodes.items===null?0:this.nodes.items.scrollTop}get offsetTop(){return this.nodes.popoverContainer===null?0:this.nodes.popoverContainer.offsetTop}show(){var e;this.nodes.popover.style.setProperty(Nt.PopoverHeight,this.size.height+"px"),this.shouldOpenBottom||this.nodes.popover.classList.add(Pt.popoverOpenTop),this.shouldOpenRight||this.nodes.popover.classList.add(Pt.popoverOpenLeft),super.show(),(e=this.flipper)==null||e.activate(this.flippableElements)}destroy(){this.hide(),super.destroy()
/**
   * Handles displaying nested items for the item.
   *
   * @param item – item to show nested popover for
   */}showNestedItems(e){this.nestedPopover!==null&&this.nestedPopover!==void 0||(this.nestedPopoverTriggerItem=e,this.showNestedPopoverForItem(e)
/**
   * Handles hover events inside popover items container
   *
   * @param event - hover event data
   */)}handleHover(e){const t=this.getTargetItem(e);t!==void 0&&this.previouslyHoveredItem!==t&&(this.destroyNestedPopoverIfExists(),this.previouslyHoveredItem=t,t.hasChildren&&this.showNestedPopoverForItem(t)
/**
   * Sets CSS variable with position of item near which nested popover should be displayed.
   * Is used for correct positioning of the nested popover
   *
   * @param nestedPopoverEl - nested popover element
   * @param item – item near which nested popover should be displayed
   */)}setTriggerItemPosition(e,t){const o=t.getElement(),n=(o?o.offsetTop:0)-this.scrollTop,i=this.offsetTop+n;e.style.setProperty(Nt.TriggerItemTop,i+"px")}destroyNestedPopoverIfExists(){var e,t;this.nestedPopover===void 0||this.nestedPopover===null||(this.nestedPopover.off(At.ClosedOnActivate,this.hide),this.nestedPopover.hide(),this.nestedPopover.destroy(),this.nestedPopover.getElement().remove(),this.nestedPopover=null,(e=this.flipper)==null||e.activate(this.flippableElements),(t=this.nestedPopoverTriggerItem)==null||t.onChildrenClose()
/**
   * Creates and displays nested popover for specified item.
   * Is used only on desktop
   *
   * @param item - item to display nested popover by
   */)}showNestedPopoverForItem(e){var t;this.nestedPopover=new tn({searchable:e.isChildrenSearchable,items:e.children,nestingLevel:this.nestingLevel+1,flippable:e.isChildrenFlippable,messages:this.messages}),e.onChildrenOpen(),this.nestedPopover.on(At.ClosedOnActivate,this.hide);const o=this.nestedPopover.getElement();return this.nodes.popover.appendChild(o),this.setTriggerItemPosition(o,e),o.style.setProperty(Nt.NestingLevel,this.nestedPopover.nestingLevel.toString()),this.nestedPopover.show(),(t=this.flipper)==null||t.deactivate(),this.nestedPopover}get shouldOpenBottom(){if(this.nodes.popover===void 0||this.nodes.popover===null)return!1;const e=this.nodes.popoverContainer.getBoundingClientRect(),t=this.scopeElement.getBoundingClientRect(),o=this.size.height,n=e.top+o,i=e.top-o,r=Math.min(window.innerHeight,t.bottom);return i<t.top||n<=r}get shouldOpenRight(){if(this.nodes.popover===void 0||this.nodes.popover===null)return!1;const e=this.nodes.popover.getBoundingClientRect(),t=this.scopeElement.getBoundingClientRect(),o=this.size.width,n=e.right+o,i=e.left-o,r=Math.min(window.innerWidth,t.right);return i<t.left||n<=r}get size(){var e;const t={height:0,width:0};if(this.nodes.popover===null)return t;const o=this.nodes.popover.cloneNode(!0);o.style.visibility="hidden",o.style.position="absolute",o.style.top="-1000px",o.classList.add(Pt.popoverOpened),(e=o.querySelector("."+Pt.popoverNested))==null||e.remove(),document.body.appendChild(o);const n=o.querySelector("."+Pt.popoverContainer);return t.height=n.offsetHeight,t.width=n.offsetWidth,o.remove(),t}get flippableElements(){return this.items.map((e=>e instanceof re?e.getElement():e instanceof Se?e.getControls():void 0)).flat().filter((e=>e!=null))}addSearch(){this.search=new ls({items:this.itemsDefault,placeholder:this.messages.search}),this.search.on(jt.Search,this.onSearch);const e=this.search.getElement();e.classList.add(Pt.search),this.nodes.popoverContainer.insertBefore(e,this.nodes.popoverContainer.firstChild)
/**
   * Toggles nothing found message visibility
   *
   * @param isDisplayed - true if the message should be displayed
   */}toggleNothingFoundMessage(e){this.nodes.nothingFoundMessage.classList.toggle(Pt.nothingFoundMessageDisplayed,e)}};$t([$],Wt.prototype,"size",1);let Yt=Wt;class hs extends Yt{
/**
   * Constructs the instance
   *
   * @param params - instance parameters
   */
constructor(e){const t=!Y();super({...e,class:Pt.popoverInline},{[we.Default]:{wrapperTag:"button",hint:{position:"top",alignment:"center",enabled:t}},[we.Html]:{hint:{position:"top",alignment:"center",enabled:t}}}),this.items.forEach((e=>{!(e instanceof re)&&!(e instanceof Se)||e.hasChildren&&e.isChildrenOpen&&this.showNestedItems(e)}))}get offsetLeft(){return this.nodes.popoverContainer===null?0:this.nodes.popoverContainer.offsetLeft}show(){this.nestingLevel===0&&this.nodes.popover.style.setProperty(Nt.InlinePopoverWidth,this.size.width+"px"),super.show()}handleHover(){}
/**
   * Sets CSS variable with position of item near which nested popover should be displayed.
   * Is used to position nested popover right below clicked item
   *
   * @param nestedPopoverEl - nested popover element
   * @param item – item near which nested popover should be displayed
   */setTriggerItemPosition(e,t){const o=t.getElement(),n=o?o.offsetLeft:0,i=this.offsetLeft+n;e.style.setProperty(Nt.TriggerItemLeft,i+"px")}
/**
   * Handles displaying nested items for the item.
   * Overriding in order to add toggling behaviour
   *
   * @param item – item to toggle nested popover for
   */showNestedItems(e){this.nestedPopoverTriggerItem!==e?super.showNestedItems(e):(this.destroyNestedPopoverIfExists(),this.nestedPopoverTriggerItem=null)}
/**
   * Creates and displays nested popover for specified item.
   * Is used only on desktop
   *
   * @param item - item to display nested popover by
   */showNestedPopoverForItem(e){const t=super.showNestedPopoverForItem(e);return t.getElement().classList.add(Pt.getPopoverNestedClass(t.nestingLevel)),t
/**
   * Overrides default item click handling.
   * Helps to close nested popover once other item is clicked.
   *
   * @param item - clicked item
   */}handleItemClick(e){var t;e!==this.nestedPopoverTriggerItem&&((t=this.nestedPopoverTriggerItem)==null||t.handleClick(),super.destroyNestedPopoverIfExists()),super.handleItemClick(e)}}const Kt=class xe{constructor(){this.scrollPosition=null}lock(){K?this.lockHard():document.body.classList.add(xe.CSS.scrollLocked)}unlock(){K?this.unlockHard():document.body.classList.remove(xe.CSS.scrollLocked)}lockHard(){this.scrollPosition=window.pageYOffset,document.documentElement.style.setProperty("--window-scroll-offset",`${this.scrollPosition}px`),document.body.classList.add(xe.CSS.scrollLockedHard)}unlockHard(){document.body.classList.remove(xe.CSS.scrollLockedHard),this.scrollPosition!==null&&window.scrollTo(0,this.scrollPosition),this.scrollPosition=null}};Kt.CSS={scrollLocked:"ce-scroll-locked",scrollLockedHard:"ce-scroll-locked--hard"};let Xt=Kt;const Vt=Ct("ce-popover-header"),qt={root:Vt(),text:Vt("text"),backButton:Vt("back-button")};class fs{
/**
   * Constructs the instance
   *
   * @param params - popover header params
   */
constructor({text:e,onBackButtonClick:t}){this.listeners=new _e,this.text=e,this.onBackButtonClick=t,this.nodes={root:u.make("div",[qt.root]),backButton:u.make("button",[qt.backButton]),text:u.make("div",[qt.text])},this.nodes.backButton.innerHTML=rt,this.nodes.root.appendChild(this.nodes.backButton),this.listeners.on(this.nodes.backButton,"click",this.onBackButtonClick),this.nodes.text.innerText=this.text,this.nodes.root.appendChild(this.nodes.text)}getElement(){return this.nodes.root}destroy(){this.nodes.root.remove(),this.listeners.destroy()}}class gs{constructor(){this.history=[]}
/**
   * Push new popover state
   *
   * @param state - new state
   */push(e){this.history.push(e)}pop(){return this.history.pop()}get currentTitle(){return this.history.length===0?"":this.history[this.history.length-1].title}get currentItems(){return this.history.length===0?[]:this.history[this.history.length-1].items}reset(){for(;this.history.length>1;)this.pop()}}class nn extends Jo{
/**
   * Construct the instance
   *
   * @param params - popover params
   */
constructor(e){super(e,{[we.Default]:{hint:{enabled:!1}},[we.Html]:{hint:{enabled:!1}}}),this.scrollLocker=new Xt,this.history=new gs,this.isHidden=!0,this.nodes.overlay=u.make("div",[Pt.overlay,Pt.overlayHidden]),this.nodes.popover.insertBefore(this.nodes.overlay,this.nodes.popover.firstChild),this.listeners.on(this.nodes.overlay,"click",(()=>{this.hide()})),this.history.push({items:e.items})}show(){this.nodes.overlay.classList.remove(Pt.overlayHidden),super.show(),this.scrollLocker.lock(),this.isHidden=!1}hide(){this.isHidden||(super.hide(),this.nodes.overlay.classList.add(Pt.overlayHidden),this.scrollLocker.unlock(),this.history.reset(),this.isHidden=!0)}destroy(){super.destroy(),this.scrollLocker.unlock()
/**
   * Handles displaying nested items for the item
   *
   * @param item – item to show nested popover for
   */}showNestedItems(e){this.updateItemsAndHeader(e.children,e.title),this.history.push({title:e.title,items:e.children})
/**
   * Removes rendered popover items and header and displays new ones
   *
   * @param items - new popover items
   * @param title - new popover header text
   */}updateItemsAndHeader(e,t){if(this.header!==null&&this.header!==void 0&&(this.header.destroy(),this.header=null),t!==void 0){this.header=new fs({text:t,onBackButtonClick:()=>{this.history.pop(),this.updateItemsAndHeader(this.history.currentItems,this.history.currentTitle)}});const e=this.header.getElement();e!==null&&this.nodes.popoverContainer.insertBefore(e,this.nodes.popoverContainer.firstChild)}this.items.forEach((e=>{var t;return(t=e.getElement())==null?void 0:t.remove()})),this.items=this.buildItems(e),this.items.forEach((e=>{var t;const o=e.getElement();o!==null&&((t=this.nodes.items)==null||t.appendChild(o))}))}}class ms extends E{constructor(){super(...arguments),this.opened=!1,this.selection=new b,this.popover=null,this.close=()=>{this.opened&&(this.opened=!1,b.isAtEditor||this.selection.restore(),this.selection.clearSaved(),!this.Editor.CrossBlockSelection.isCrossBlockSelectionStarted&&this.Editor.BlockManager.currentBlock&&this.Editor.BlockSelection.unselectBlock(this.Editor.BlockManager.currentBlock),this.eventsDispatcher.emit(this.events.closed),this.popover&&(this.popover.off(At.Closed,this.onPopoverClose),this.popover.destroy(),this.popover.getElement().remove(),this.popover=null))},this.onPopoverClose=()=>{this.close()}}get events(){return{opened:"block-settings-opened",closed:"block-settings-closed"}}get CSS(){return{settings:"ce-settings"}}get flipper(){var e;if(this.popover!==null)return"flipper"in this.popover?(e=this.popover)==null?void 0:e.flipper:void 0}make(){this.nodes.wrapper=u.make("div",[this.CSS.settings]),this.eventsDispatcher.on(pe,this.close)}destroy(){this.removeAllNodes(),this.listeners.destroy(),this.eventsDispatcher.off(pe,this.close)
/**
   * Open Block Settings pane
   *
   * @param targetBlock - near which Block we should open BlockSettings
   */}async open(e=this.Editor.BlockManager.currentBlock){var t;this.opened=!0,this.selection.save(),this.Editor.BlockSelection.selectBlock(e),this.Editor.BlockSelection.clearCache();const{toolTunes:o,commonTunes:n}=e.getTunes();this.eventsDispatcher.emit(this.events.opened);const i=Y()?nn:Yt;this.popover=new i({searchable:!0,items:await this.getTunesItems(e,n,o),scopeElement:this.Editor.API.methods.ui.nodes.redactor,messages:{nothingFound:ne.ui(et.ui.popover,"Nothing found"),search:ne.ui(et.ui.popover,"Filter")}}),this.popover.on(At.Closed,this.onPopoverClose),(t=this.nodes.wrapper)==null||t.append(this.popover.getElement()),this.popover.show()}getElement(){return this.nodes.wrapper}
/**
   * Returns list of items to be displayed in block tunes menu.
   * Merges tool specific tunes, conversion menu and common tunes in one list in predefined order
   *
   * @param currentBlock –  block we are about to open block tunes for
   * @param commonTunes – common tunes
   * @param toolTunes - tool specific tunes
   */async getTunesItems(e,t,o){const n=[];o!==void 0&&o.length>0&&(n.push(...o),n.push({type:we.Separator}));const i=Array.from(this.Editor.Tools.blockTools.values()),r=(await be(e,i)).reduce(((t,o)=>(o.toolbox.forEach((n=>{t.push({icon:n.icon,title:ne.t(et.toolNames,n.title),name:o.name,closeOnActivate:!0,onActivate:async()=>{const{BlockManager:t,Caret:i,Toolbar:r}=this.Editor,a=await t.convert(e,o.name,n.data);r.close(),i.setToBlock(a,i.positions.END)}})})),t)),[]);return r.length>0&&(n.push({icon:mt,name:"convert-to",title:ne.ui(et.ui.popover,"Convert to"),children:{searchable:!0,items:r}}),n.push({type:we.Separator})),n.push(...t),n.map((e=>this.resolveTuneAliases(e)))
/**
   * Resolves aliases in tunes menu items
   *
   * @param item - item with resolved aliases
   */}resolveTuneAliases(e){if(e.type===we.Separator||e.type===we.Html)return e;const t=tt(e,{label:"title"});return e.confirmation&&(t.confirmation=this.resolveTuneAliases(e.confirmation)),t}}var Zt={exports:{}};
/*!
 * Library for handling keyboard shortcuts
 * @copyright CodeX (https://codex.so)
 * @license MIT
 * @author CodeX (https://codex.so)
 * @version 1.2.0
 */(function(e){(function(t,o){e.exports=o()})(window,(function(){return function(e){var t={};function o(n){if(t[n])return t[n].exports;var i=t[n]={i:n,l:!1,exports:{}};return e[n].call(i.exports,i,i.exports,o),i.l=!0,i.exports}return o.m=e,o.c=t,o.d=function(e,t,n){o.o(e,t)||Object.defineProperty(e,t,{enumerable:!0,get:n})},o.r=function(e){typeof Symbol<"u"&&Symbol.toStringTag&&Object.defineProperty(e,Symbol.toStringTag,{value:"Module"}),Object.defineProperty(e,"__esModule",{value:!0})},o.t=function(e,t){if(1&t&&(e=o(e)),8&t||4&t&&typeof e=="object"&&e&&e.__esModule)return e;var n=Object.create(null);if(o.r(n),Object.defineProperty(n,"default",{enumerable:!0,value:e}),2&t&&typeof e!="string")for(var i in e)o.d(n,i,function(t){return e[t]}.bind(null,i));return n},o.n=function(e){var t=e&&e.__esModule?function(){return e.default}:function(){return e};return o.d(t,"a",t),t},o.o=function(e,t){return Object.prototype.hasOwnProperty.call(e,t)},o.p="",o(o.s=0)}([function(e,t,o){function n(e,t){for(var o=0;o<t.length;o++){var n=t[o];n.enumerable=n.enumerable||!1,n.configurable=!0,"value"in n&&(n.writable=!0),Object.defineProperty(e,n.key,n)}}function i(e,t,o){return t&&n(e.prototype,t),o&&n(e,o),e}o.r(t);var r=function(){function e(t){var o=this;(function(e,t){if(!(e instanceof t))throw new TypeError("Cannot call a class as a function")})(this,e),this.commands={},this.keys={},this.name=t.name,this.parseShortcutName(t.name),this.element=t.on,this.callback=t.callback,this.executeShortcut=function(e){o.execute(e)},this.element.addEventListener("keydown",this.executeShortcut,!1)}return i(e,null,[{key:"supportedCommands",get:function(){return{SHIFT:["SHIFT"],CMD:["CMD","CONTROL","COMMAND","WINDOWS","CTRL"],ALT:["ALT","OPTION"]}}},{key:"keyCodes",get:function(){return{0:48,1:49,2:50,3:51,4:52,5:53,6:54,7:55,8:56,9:57,A:65,B:66,C:67,D:68,E:69,F:70,G:71,H:72,I:73,J:74,K:75,L:76,M:77,N:78,O:79,P:80,Q:81,R:82,S:83,T:84,U:85,V:86,W:87,X:88,Y:89,Z:90,BACKSPACE:8,ENTER:13,ESCAPE:27,LEFT:37,UP:38,RIGHT:39,DOWN:40,INSERT:45,DELETE:46,".":190}}}]),i(e,[{key:"parseShortcutName",value:function(t){t=t.split("+");for(var o=0;o<t.length;o++){t[o]=t[o].toUpperCase();var n=!1;for(var i in e.supportedCommands)if(e.supportedCommands[i].includes(t[o])){n=this.commands[i]=!0;break}n||(this.keys[t[o]]=!0)}for(var r in e.supportedCommands)this.commands[r]||(this.commands[r]=!1)}},{key:"execute",value:function(t){var o,n={CMD:t.ctrlKey||t.metaKey,SHIFT:t.shiftKey,ALT:t.altKey},i=!0;for(o in this.commands)this.commands[o]!==n[o]&&(i=!1);var r,a=!0;for(r in this.keys)a=a&&t.keyCode===e.keyCodes[r];i&&a&&this.callback(t)}},{key:"remove",value:function(){this.element.removeEventListener("keydown",this.executeShortcut)}}]),e}();t.default=r}]).default}))})(Zt);var Gt=Zt.exports;const Qt=t(Gt);class ks{constructor(){this.registeredShortcuts=new Map}
/**
   * Register shortcut
   *
   * @param shortcut - shortcut options
   */add(e){if(this.findShortcut(e.on,e.name))throw Error(`Shortcut ${e.name} is already registered for ${e.on}. Please remove it before add a new handler.`);const t=new Qt({name:e.name,on:e.on,callback:e.handler}),o=this.registeredShortcuts.get(e.on)||[];this.registeredShortcuts.set(e.on,[...o,t])}
/**
   * Remove shortcut
   *
   * @param element - Element shortcut is set for
   * @param name - shortcut name
   */remove(e,t){const o=this.findShortcut(e,t);if(!o)return;o.remove();const n=this.registeredShortcuts.get(e).filter((e=>e!==o));n.length!==0?this.registeredShortcuts.set(e,n):this.registeredShortcuts.delete(e)}
/**
   * Get Shortcut instance if exist
   *
   * @param element - Element shorcut is set for
   * @param shortcut - shortcut name
   * @returns {number} index - shortcut index if exist
   */findShortcut(e,t){return(this.registeredShortcuts.get(e)||[]).find((({name:e})=>e===t))}}const Jt=new ks;var eo=Object.defineProperty,to=Object.getOwnPropertyDescriptor,oo=(e,t,o,n)=>{for(var i,r=n>1?void 0:n?to(t,o):t,a=e.length-1;a>=0;a--)(i=e[a])&&(r=(n?i(t,o,r):i(r))||r);return n&&r&&eo(t,o,r),r},no=(e=>(e.Opened="toolbox-opened",e.Closed="toolbox-closed",e.BlockAdded="toolbox-block-added",e))(no||{});const io=class an extends Oe{
/**
   * Toolbox constructor
   *
   * @param options - available parameters
   * @param options.api - Editor API methods
   * @param options.tools - Tools available to check whether some of them should be displayed at the Toolbox or not
   */
constructor({api:e,tools:t,i18nLabels:o}){super(),this.opened=!1,this.listeners=new _e,this.popover=null,this.handleMobileLayoutToggle=()=>{this.destroyPopover(),this.initPopover()},this.onPopoverClose=()=>{this.opened=!1,this.emit("toolbox-closed")},this.api=e,this.tools=t,this.i18nLabels=o,this.enableShortcuts(),this.nodes={toolbox:u.make("div",an.CSS.toolbox)},this.initPopover(),this.api.events.on(pe,this.handleMobileLayoutToggle)
/**
   * Returns True if Toolbox is Empty and nothing to show
   *
   * @returns {boolean}
   */}get isEmpty(){return this.toolsToBeDisplayed.length===0}static get CSS(){return{toolbox:"ce-toolbox"}}getElement(){return this.nodes.toolbox}hasFocus(){if(this.popover!==null)return"hasFocus"in this.popover?this.popover.hasFocus():void 0}destroy(){var e;super.destroy(),this.nodes&&this.nodes.toolbox&&this.nodes.toolbox.remove(),this.removeAllShortcuts(),(e=this.popover)==null||e.off(At.Closed,this.onPopoverClose),this.listeners.destroy(),this.api.events.off(pe,this.handleMobileLayoutToggle)
/**
   * Toolbox Tool's button click handler
   *
   * @param toolName - tool type to be activated
   * @param blockDataOverrides - Block data predefined by the activated Toolbox item
   */}toolButtonActivated(e,t){this.insertNewBlock(e,t)}open(){var e;this.isEmpty||((e=this.popover)==null||e.show(),this.opened=!0,this.emit("toolbox-opened"))}close(){var e;(e=this.popover)==null||e.hide(),this.opened=!1,this.emit("toolbox-closed")}toggle(){this.opened?this.close():this.open()}initPopover(){var e;const t=Y()?nn:Yt;this.popover=new t({scopeElement:this.api.ui.nodes.redactor,searchable:!0,messages:{nothingFound:this.i18nLabels.nothingFound,search:this.i18nLabels.filter},items:this.toolboxItemsToBeDisplayed}),this.popover.on(At.Closed,this.onPopoverClose),(e=this.nodes.toolbox)==null||e.append(this.popover.getElement())}destroyPopover(){this.popover!==null&&(this.popover.hide(),this.popover.off(At.Closed,this.onPopoverClose),this.popover.destroy(),this.popover=null),this.nodes.toolbox!==null&&(this.nodes.toolbox.innerHTML="")}get toolsToBeDisplayed(){const e=[];return this.tools.forEach((t=>{t.toolbox&&e.push(t)})),e}get toolboxItemsToBeDisplayed(){const e=(e,t,o=!0)=>({icon:e.icon,title:ne.t(et.toolNames,e.title||L(t.name)),name:t.name,onActivate:()=>{this.toolButtonActivated(t.name,e.data)},secondaryLabel:t.shortcut&&o?N(t.shortcut):""});return this.toolsToBeDisplayed.reduce(((t,o)=>(Array.isArray(o.toolbox)?o.toolbox.forEach(((n,i)=>{t.push(e(n,o,i===0))})):o.toolbox!==void 0&&t.push(e(o.toolbox,o)),t)),[])}enableShortcuts(){this.toolsToBeDisplayed.forEach((e=>{const t=e.shortcut;t&&this.enableShortcutForTool(e.name,t)}))}
/**
   * Enable shortcut Block Tool implemented shortcut
   *
   * @param {string} toolName - Tool name
   * @param {string} shortcut - shortcut according to the ShortcutData Module format
   */enableShortcutForTool(e,t){Jt.add({name:t,on:this.api.ui.nodes.redactor,handler:async t=>{t.preventDefault();const o=this.api.blocks.getCurrentBlockIndex(),n=this.api.blocks.getBlockByIndex(o);if(n)try{const t=await this.api.blocks.convert(n.id,e);this.api.caret.setToBlock(t,"end");return}catch{}this.insertNewBlock(e)}})}removeAllShortcuts(){this.toolsToBeDisplayed.forEach((e=>{const t=e.shortcut;t&&Jt.remove(this.api.ui.nodes.redactor,t)}))}
/**
   * Inserts new block
   * Can be called when button clicked on Toolbox or by ShortcutData
   *
   * @param {string} toolName - Tool name
   * @param blockDataOverrides - predefined Block data
   */async insertNewBlock(e,t){const o=this.api.blocks.getCurrentBlockIndex(),n=this.api.blocks.getBlockByIndex(o);if(!n)return;const i=n.isEmpty?o:o+1;let r;if(t){const o=await this.api.blocks.composeBlockData(e);r=Object.assign(o,t)}const a=this.api.blocks.insert(e,r,void 0,i,void 0,n.isEmpty);a.call(Ce.APPEND_CALLBACK),this.api.caret.setToBlock(i),this.emit("toolbox-block-added",{block:a}),this.api.toolbar.close()}};oo([$],io.prototype,"toolsToBeDisplayed",1);oo([$],io.prototype,"toolboxItemsToBeDisplayed",1);let so=io;const ro="block hovered";async function ao(e,t){const o=navigator.keyboard;if(!o)return t;try{return(await o.getLayoutMap()).get(e)||t}catch(e){return console.error(e),t}}class Bs extends E{
/**
   * @class
   * @param moduleConfiguration - Module Configuration
   * @param moduleConfiguration.config - Editor's config
   * @param moduleConfiguration.eventsDispatcher - Editor's event dispatcher
   */
constructor({config:e,eventsDispatcher:t}){super({config:e,eventsDispatcher:t}),this.toolboxInstance=null
/**
   * CSS styles
   *
   * @returns {object}
   */}get CSS(){return{toolbar:"ce-toolbar",content:"ce-toolbar__content",actions:"ce-toolbar__actions",actionsOpened:"ce-toolbar__actions--opened",toolbarOpened:"ce-toolbar--opened",openedToolboxHolderModifier:"codex-editor--toolbox-opened",plusButton:"ce-toolbar__plus",plusButtonShortcut:"ce-toolbar__plus-shortcut",settingsToggler:"ce-toolbar__settings-btn",settingsTogglerHidden:"ce-toolbar__settings-btn--hidden"}}
/**
   * Returns the Toolbar opening state
   *
   * @returns {boolean}
   */get opened(){return this.nodes.wrapper.classList.contains(this.CSS.toolbarOpened)}get toolbox(){var e;return{opened:(e=this.toolboxInstance)==null?void 0:e.opened,close:()=>{var e;(e=this.toolboxInstance)==null||e.close()},open:()=>{this.toolboxInstance!==null?(this.Editor.BlockManager.currentBlock=this.hoveredBlock,this.toolboxInstance.open()):h("toolbox.open() called before initialization is finished","warn")},toggle:()=>{this.toolboxInstance!==null?this.toolboxInstance.toggle():h("toolbox.toggle() called before initialization is finished","warn")},hasFocus:()=>{var e;return(e=this.toolboxInstance)==null?void 0:e.hasFocus()}}}get blockActions(){return{hide:()=>{this.nodes.actions.classList.remove(this.CSS.actionsOpened)},show:()=>{this.nodes.actions.classList.add(this.CSS.actionsOpened)}}}get blockTunesToggler(){return{hide:()=>this.nodes.settingsToggler.classList.add(this.CSS.settingsTogglerHidden),show:()=>this.nodes.settingsToggler.classList.remove(this.CSS.settingsTogglerHidden)}}
/**
   * Toggles read-only mode
   *
   * @param {boolean} readOnlyEnabled - read-only mode
   */toggleReadOnly(e){e?(this.destroy(),this.Editor.BlockSettings.destroy(),this.disableModuleBindings()):window.requestIdleCallback((()=>{this.drawUI(),this.enableModuleBindings()}),{timeout:2e3})}
/**
   * Move Toolbar to the passed (or current) Block
   *
   * @param block - block to move Toolbar near it
   */moveAndOpen(e=this.Editor.BlockManager.currentBlock){if(this.toolboxInstance===null){h("Can't open Toolbar since Editor initialization is not finished yet","warn");return}if(this.toolboxInstance.opened&&this.toolboxInstance.close(),this.Editor.BlockSettings.opened&&this.Editor.BlockSettings.close(),!e)return;this.hoveredBlock=e;const t=e.holder,{isMobile:o}=this.Editor.UI;let n;const i=20,r=e.firstInput,a=t.getBoundingClientRect(),l=r!==void 0?r.getBoundingClientRect():null,c=l!==null?l.top-a.top:null,d=c!==null?c>i:void 0;if(o)n=t.offsetTop+t.offsetHeight;else if(r===void 0||d){const o=parseInt(window.getComputedStyle(e.pluginsContent).paddingTop);n=t.offsetTop+o}else{const e=q(r),o=parseInt(window.getComputedStyle(this.nodes.plusButton).height,10),i=8;n=t.offsetTop+e-o+i+c}this.nodes.wrapper.style.top=`${Math.floor(n)}px`,this.Editor.BlockManager.blocks.length===1&&e.isEmpty?this.blockTunesToggler.hide():this.blockTunesToggler.show(),this.open()}close(){var e,t;this.Editor.ReadOnly.isEnabled||((e=this.nodes.wrapper)==null||e.classList.remove(this.CSS.toolbarOpened),this.blockActions.hide(),(t=this.toolboxInstance)==null||t.close(),this.Editor.BlockSettings.close(),this.reset())}reset(){this.nodes.wrapper.style.top="unset"}
/**
   * Open Toolbar with Plus Button and Actions
   *
   * @param {boolean} withBlockActions - by default, Toolbar opens with Block Actions.
   *                                     This flag allows to open Toolbar without Actions.
   */open(e=!0){this.nodes.wrapper.classList.add(this.CSS.toolbarOpened),e?this.blockActions.show():this.blockActions.hide()}async make(){this.nodes.wrapper=u.make("div",this.CSS.toolbar),["content","actions"].forEach((e=>{this.nodes[e]=u.make("div",this.CSS[e])})),u.append(this.nodes.wrapper,this.nodes.content),u.append(this.nodes.content,this.nodes.actions),this.nodes.plusButton=u.make("div",this.CSS.plusButton,{innerHTML:gt}),u.append(this.nodes.actions,this.nodes.plusButton),this.readOnlyMutableListeners.on(this.nodes.plusButton,"click",(()=>{Ze(!0),this.plusButtonClicked()}),!1);const e=u.make("div");e.appendChild(document.createTextNode(ne.ui(et.ui.toolbar.toolbox,"Add"))),e.appendChild(u.make("div",this.CSS.plusButtonShortcut,{textContent:"/"})),Ge(this.nodes.plusButton,e,{hidingDelay:400}),this.nodes.settingsToggler=u.make("span",this.CSS.settingsToggler,{innerHTML:ft}),u.append(this.nodes.actions,this.nodes.settingsToggler);const t=u.make("div"),o=u.text(ne.ui(et.ui.blockTunes.toggler,"Click to tune")),n=await ao("Slash","/");t.appendChild(o),t.appendChild(u.make("div",this.CSS.plusButtonShortcut,{textContent:N(`CMD + ${n}`)})),Ge(this.nodes.settingsToggler,t,{hidingDelay:400}),u.append(this.nodes.actions,this.makeToolbox()),u.append(this.nodes.actions,this.Editor.BlockSettings.getElement()),u.append(this.Editor.UI.nodes.wrapper,this.nodes.wrapper)}makeToolbox(){return this.toolboxInstance=new so({api:this.Editor.API.methods,tools:this.Editor.Tools.blockTools,i18nLabels:{filter:ne.ui(et.ui.popover,"Filter"),nothingFound:ne.ui(et.ui.popover,"Nothing found")}}),this.toolboxInstance.on(no.Opened,(()=>{this.Editor.UI.nodes.wrapper.classList.add(this.CSS.openedToolboxHolderModifier)})),this.toolboxInstance.on(no.Closed,(()=>{this.Editor.UI.nodes.wrapper.classList.remove(this.CSS.openedToolboxHolderModifier)})),this.toolboxInstance.on(no.BlockAdded,(({block:e})=>{const{BlockManager:t,Caret:o}=this.Editor,n=t.getBlockById(e.id);n.inputs.length===0&&(n===t.lastBlock?(t.insertAtEnd(),o.setToBlock(t.lastBlock)):o.setToBlock(t.nextBlock))})),this.toolboxInstance.getElement()}plusButtonClicked(){var e;this.Editor.BlockManager.currentBlock=this.hoveredBlock,(e=this.toolboxInstance)==null||e.toggle()}enableModuleBindings(){this.readOnlyMutableListeners.on(this.nodes.settingsToggler,"mousedown",(e=>{var t;e.stopPropagation(),this.settingsTogglerClicked(),(t=this.toolboxInstance)!=null&&t.opened&&this.toolboxInstance.close(),Ze(!0)}),!0),Y()||this.eventsDispatcher.on(ro,(e=>{var t;this.Editor.BlockSettings.opened||(t=this.toolboxInstance)!=null&&t.opened||this.moveAndOpen(e.block)}))}disableModuleBindings(){this.readOnlyMutableListeners.clearAll()}settingsTogglerClicked(){this.Editor.BlockManager.currentBlock=this.hoveredBlock,this.Editor.BlockSettings.opened?this.Editor.BlockSettings.close():this.Editor.BlockSettings.open(this.hoveredBlock)}drawUI(){this.Editor.BlockSettings.make(),this.make()}destroy(){this.removeAllNodes(),this.toolboxInstance&&this.toolboxInstance.destroy()}}var lo=(e=>(e[e.Block=0]="Block",e[e.Inline=1]="Inline",e[e.Tune=2]="Tune",e))(lo||{}),co=(e=>(e.Shortcut="shortcut",e.Toolbox="toolbox",e.EnabledInlineTools="inlineToolbar",e.EnabledBlockTunes="tunes",e.Config="config",e))(co||{}),ho=(e=>(e.Shortcut="shortcut",e.SanitizeConfig="sanitize",e))(ho||{}),uo=(e=>(e.IsEnabledLineBreaks="enableLineBreaks",e.Toolbox="toolbox",e.ConversionConfig="conversionConfig",e.IsReadOnlySupported="isReadOnlySupported",e.PasteConfig="pasteConfig",e))(uo||{}),po=(e=>(e.IsInline="isInline",e.Title="title",e.IsReadOnlySupported="isReadOnlySupported",e))(po||{}),ko=(e=>(e.IsTune="isTune",e))(ko||{});class Tt{
/**
   * @class
   * @param {ConstructorOptions} options - Constructor options
   */
constructor({name:e,constructable:t,config:o,api:n,isDefault:i,isInternal:r=!1,defaultPlaceholder:a}){this.api=n,this.name=e,this.constructable=t,this.config=o,this.isDefault=i,this.isInternal=r,this.defaultPlaceholder=a}get settings(){const e=this.config.config||{};return this.isDefault&&!("placeholder"in e)&&this.defaultPlaceholder&&(e.placeholder=this.defaultPlaceholder),e}reset(){if(g(this.constructable.reset))return this.constructable.reset()}prepare(){if(g(this.constructable.prepare))return this.constructable.prepare({toolName:this.name,config:this.settings})}get shortcut(){const e=this.constructable.shortcut;return this.config.shortcut||e}get sanitizeConfig(){return this.constructable.sanitize||{}}isInline(){return this.type===lo.Inline}isBlock(){return this.type===lo.Block}isTune(){return this.type===lo.Tune}}class Cs extends E{
/**
   * @param moduleConfiguration - Module Configuration
   * @param moduleConfiguration.config - Editor's config
   * @param moduleConfiguration.eventsDispatcher - Editor's event dispatcher
   */
constructor({config:e,eventsDispatcher:t}){super({config:e,eventsDispatcher:t}),this.CSS={inlineToolbar:"ce-inline-toolbar"},this.opened=!1,this.popover=null,this.toolbarVerticalMargin=Y()?20:6,this.tools=new Map,window.requestIdleCallback((()=>{this.make()}),{timeout:2e3})
/**
   * Shows Inline Toolbar if something is selected
   *
   * @param [needToClose] - pass true to close toolbar if it is not allowed.
   *                                  Avoid to use it just for closing IT, better call .close() clearly.
   */}async tryToShow(e=!1){e&&this.close(),this.allowedToShow()&&(await this.open(),this.Editor.Toolbar.close())}close(){var e,t;if(this.opened){for(const[e,t]of this.tools){const o=this.getToolShortcut(e.name);o!==void 0&&Jt.remove(this.Editor.UI.nodes.redactor,o),g(t.clear)&&t.clear()}this.tools=new Map,this.reset(),this.opened=!1,(e=this.popover)==null||e.hide(),(t=this.popover)==null||t.destroy(),this.popover=null}}
/**
   * Check if node is contained by Inline Toolbar
   *
   * @param {Node} node — node to check
   */containsNode(e){return this.nodes.wrapper!==void 0&&this.nodes.wrapper.contains(e)}destroy(){var e;this.removeAllNodes(),(e=this.popover)==null||e.destroy(),this.popover=null}make(){this.nodes.wrapper=u.make("div",[this.CSS.inlineToolbar,...this.isRtl?[this.Editor.UI.CSS.editorRtlFix]:[]]),u.append(this.Editor.UI.nodes.wrapper,this.nodes.wrapper)}async open(){var e;if(this.opened)return;this.opened=!0,this.popover!==null&&this.popover.destroy(),this.createToolsInstances();const t=await this.getPopoverItems();this.popover=new hs({items:t,scopeElement:this.Editor.API.methods.ui.nodes.redactor,messages:{nothingFound:ne.ui(et.ui.popover,"Nothing found"),search:ne.ui(et.ui.popover,"Filter")}}),this.move(this.popover.size.width),(e=this.nodes.wrapper)==null||e.append(this.popover.getElement()),this.popover.show()
/**
   * Move Toolbar to the selected text
   *
   * @param popoverWidth - width of the toolbar popover
   */}move(e){const t=b.rect,o=this.Editor.UI.nodes.wrapper.getBoundingClientRect(),n={x:t.x-o.x,y:t.y+t.height-o.top+this.toolbarVerticalMargin};n.x+e+o.x>this.Editor.UI.contentRect.right&&(n.x=this.Editor.UI.contentRect.right-e-o.x),this.nodes.wrapper.style.left=Math.floor(n.x)+"px",this.nodes.wrapper.style.top=Math.floor(n.y)+"px"}reset(){this.nodes.wrapper.style.left="0",this.nodes.wrapper.style.top="0"}allowedToShow(){const e=["IMG","INPUT"],t=b.get(),o=b.text;if(!t||!t.anchorNode||t.isCollapsed||o.length<1)return!1;const n=u.isElement(t.anchorNode)?t.anchorNode:t.anchorNode.parentElement;if(n===null||t!==null&&e.includes(n.tagName))return!1;const i=this.Editor.BlockManager.getBlock(t.anchorNode);return!(!i||this.getTools().some((e=>i.tool.inlineTools.has(e.name)))===!1)&&n.closest("[contenteditable]")!==null}getTools(){const e=this.Editor.BlockManager.currentBlock;return e?Array.from(e.tool.inlineTools.values()).filter((e=>!(this.Editor.ReadOnly.isEnabled&&e.isReadOnlySupported!==!0))):[]}createToolsInstances(){this.tools=new Map,this.getTools().forEach((e=>{const t=e.create();this.tools.set(e,t)}))}async getPopoverItems(){const e=[];let t=0;for(const[o,n]of this.tools){const i=await n.render(),r=this.getToolShortcut(o.name);if(r!==void 0)try{this.enableShortcuts(o.name,r)}catch{}const a=r!==void 0?N(r):void 0,l=ne.t(et.toolNames,o.title||L(o.name));[i].flat().forEach((i=>{var r,c;const d={name:o.name,onActivate:()=>{this.toolClicked(n)},hint:{title:l,description:a}};if(u.isElement(i)){const t={...d,element:i,type:we.Html};if(g(n.renderActions)){const e=n.renderActions();t.children={isOpen:(r=n.checkState)==null?void 0:r.call(n,b.get()),isFlippable:!1,items:[{type:we.Html,element:e}]}}else(c=n.checkState)==null||c.call(n,b.get());e.push(t)}else if(i.type===we.Html)e.push({...d,...i,type:we.Html});else if(i.type===we.Separator)e.push({type:we.Separator});else{const o={...d,...i,type:we.Default};"children"in o&&t!==0&&e.push({type:we.Separator}),e.push(o),"children"in o&&t<this.tools.size-1&&e.push({type:we.Separator})}})),t++}return e}
/**
   * Get shortcut name for tool
   *
   * @param toolName — Tool name
   */getToolShortcut(e){const{Tools:t}=this.Editor,o=t.inlineTools.get(e),n=t.internal.inlineTools;return Array.from(n.keys()).includes(e)?this.inlineTools[e][ho.Shortcut]:o==null?void 0:o.shortcut}
/**
   * Enable Tool shortcut with Editor Shortcuts Module
   *
   * @param toolName - tool name
   * @param shortcut - shortcut according to the ShortcutData Module format
   */enableShortcuts(e,t){Jt.add({name:t,handler:t=>{var o;const{currentBlock:n}=this.Editor.BlockManager;n&&n.tool.enabledInlineTools&&(t.preventDefault(),(o=this.popover)==null||o.activateItemByName(e))},on:document})}
/**
   * Inline Tool button clicks
   *
   * @param tool - Tool's instance
   */toolClicked(e){var t;const o=b.range;(t=e.surround)==null||t.call(e,o),this.checkToolsState()}checkToolsState(){var e;(e=this.tools)==null||e.forEach((e=>{var t;(t=e.checkState)==null||t.call(e,b.get())}))}get inlineTools(){const e={};return Array.from(this.Editor.Tools.inlineTools.entries()).forEach((([t,o])=>{e[t]=o.create()})),e}}function yo(){const e=window.getSelection();if(e===null)return[null,0];let t=e.focusNode,o=e.focusOffset;return t===null?[null,0]:(t.nodeType!==Node.TEXT_NODE&&t.childNodes.length>0&&(t.childNodes[o]?(t=t.childNodes[o],o=0):(t=t.childNodes[o-1],o=t.textContent.length)),[t,o])}function wo(e,t,o,n){const i=document.createRange();n==="left"?(i.setStart(e,0),i.setEnd(t,o)):(i.setStart(t,o),i.setEnd(e,e.childNodes.length));const r=i.cloneContents(),a=document.createElement("div");a.appendChild(r);const l=a.textContent||"";return V(l)}function xo(e){const t=u.getDeepestNode(e);if(t===null||u.isEmpty(e))return!0;if(u.isNativeInput(t))return t.selectionEnd===0;if(u.isEmpty(e))return!0;const[o,n]=yo();return o!==null&&wo(e,o,n,"left")}function Eo(e){const t=u.getDeepestNode(e,!0);if(t===null)return!0;if(u.isNativeInput(t))return t.selectionEnd===t.value.length;const[o,n]=yo();return o!==null&&wo(e,o,n,"right")}var Co={},Bo={},To={},So={},Io={},Oo={};Object.defineProperty(Oo,"__esModule",{value:!0});Oo.allInputsSelector=_o;function _o(){var e=["text","password","email","number","search","tel","url"];return"[contenteditable=true], textarea, input:not([type]), "+e.map((function(e){return'input[type="'.concat(e,'"]')})).join(", ")}(function(e){Object.defineProperty(e,"__esModule",{value:!0}),e.allInputsSelector=void 0;var t=Oo;Object.defineProperty(e,"allInputsSelector",{enumerable:!0,get:function(){return t.allInputsSelector}})})(Io);var Mo={},Ao={};Object.defineProperty(Ao,"__esModule",{value:!0});Ao.isNativeInput=Lo;function Lo(e){var t=["INPUT","TEXTAREA"];return!(!e||!e.tagName)&&t.includes(e.tagName)}(function(e){Object.defineProperty(e,"__esModule",{value:!0}),e.isNativeInput=void 0;var t=Ao;Object.defineProperty(e,"isNativeInput",{enumerable:!0,get:function(){return t.isNativeInput}})})(Mo);var Po={},No={};Object.defineProperty(No,"__esModule",{value:!0});No.append=Ro;function Ro(e,t){Array.isArray(t)?t.forEach((function(t){e.appendChild(t)})):e.appendChild(t)}(function(e){Object.defineProperty(e,"__esModule",{value:!0}),e.append=void 0;var t=No;Object.defineProperty(e,"append",{enumerable:!0,get:function(){return t.append}})})(Po);var Do={},jo={};Object.defineProperty(jo,"__esModule",{value:!0});jo.blockElements=Fo;function Fo(){return["address","article","aside","blockquote","canvas","div","dl","dt","fieldset","figcaption","figure","footer","form","h1","h2","h3","h4","h5","h6","header","hgroup","hr","li","main","nav","noscript","ol","output","p","pre","ruby","section","table","tbody","thead","tr","tfoot","ul","video"]}(function(e){Object.defineProperty(e,"__esModule",{value:!0}),e.blockElements=void 0;var t=jo;Object.defineProperty(e,"blockElements",{enumerable:!0,get:function(){return t.blockElements}})})(Do);var zo={},Uo={};Object.defineProperty(Uo,"__esModule",{value:!0});Uo.calculateBaseline=$o;function $o(e){var t=window.getComputedStyle(e),o=parseFloat(t.fontSize),n=parseFloat(t.lineHeight)||o*1.2,i=parseFloat(t.paddingTop),r=parseFloat(t.borderTopWidth),a=parseFloat(t.marginTop),l=o*.8,c=(n-o)/2,d=a+r+i+c+l;return d}(function(e){Object.defineProperty(e,"__esModule",{value:!0}),e.calculateBaseline=void 0;var t=Uo;Object.defineProperty(e,"calculateBaseline",{enumerable:!0,get:function(){return t.calculateBaseline}})})(zo);var Wo={},Yo={},Ko={},Xo={};Object.defineProperty(Xo,"__esModule",{value:!0});Xo.isContentEditable=Vo;function Vo(e){return e.contentEditable==="true"}(function(e){Object.defineProperty(e,"__esModule",{value:!0}),e.isContentEditable=void 0;var t=Xo;Object.defineProperty(e,"isContentEditable",{enumerable:!0,get:function(){return t.isContentEditable}})})(Ko);Object.defineProperty(Yo,"__esModule",{value:!0});Yo.canSetCaret=Go;var qo=Mo,Zo=Ko;function Go(e){var t=!0;if((0,qo.isNativeInput)(e))switch(e.type){case"file":case"checkbox":case"radio":case"hidden":case"submit":case"button":case"image":case"reset":t=!1;break}else t=(0,Zo.isContentEditable)(e);return t}(function(e){Object.defineProperty(e,"__esModule",{value:!0}),e.canSetCaret=void 0;var t=Yo;Object.defineProperty(e,"canSetCaret",{enumerable:!0,get:function(){return t.canSetCaret}})})(Wo);var en={},on={};function sn(e,t,o){const n=o.value!==void 0?"value":"get",i=o[n],r=`#${t}Cache`;if(o[n]=function(...e){return this[r]===void 0&&(this[r]=i.apply(this,e)),this[r]},n==="get"&&o.set){const t=o.set;o.set=function(o){delete e[r],t.apply(this,o)}}return o}function rn(){const e={win:!1,mac:!1,x11:!1,linux:!1},t=Object.keys(e).find((e=>window.navigator.appVersion.toLowerCase().indexOf(e)!==-1));return t!==void 0&&(e[t]=!0),e}function ln(e){return e!=null&&e!==""&&(typeof e!="object"||Object.keys(e).length>0)}function cn(e){return!ln(e)}const dn=()=>typeof window<"u"&&window.navigator!==null&&ln(window.navigator.platform)&&(/iP(ad|hone|od)/.test(window.navigator.platform)||window.navigator.platform==="MacIntel"&&window.navigator.maxTouchPoints>1);function hn(e){const t=rn();return e=e.replace(/shift/gi,"⇧").replace(/backspace/gi,"⌫").replace(/enter/gi,"⏎").replace(/up/gi,"↑").replace(/left/gi,"→").replace(/down/gi,"↓").replace(/right/gi,"←").replace(/escape/gi,"⎋").replace(/insert/gi,"Ins").replace(/delete/gi,"␡").replace(/\+/gi,"+"),e=t.mac?e.replace(/ctrl|cmd/gi,"⌘").replace(/alt/gi,"⌥"):e.replace(/cmd/gi,"Ctrl").replace(/windows/gi,"WIN"),e}function un(e){return e[0].toUpperCase()+e.slice(1)}function pn(e){const t=document.createElement("div");t.style.position="absolute",t.style.left="-999px",t.style.bottom="-999px",t.innerHTML=e,document.body.appendChild(t);const o=window.getSelection(),n=document.createRange();if(n.selectNode(t),o===null)throw new Error("Cannot copy text to clipboard");o.removeAllRanges(),o.addRange(n),document.execCommand("copy"),document.body.removeChild(t)}function fn(e,t,o){let n;return(...i)=>{const r=this,a=()=>{n=void 0,o!==!0&&e.apply(r,i)},l=o===!0&&n!==void 0;window.clearTimeout(n),n=window.setTimeout(a,t),l&&e.apply(r,i)}}function gn(e){return Object.prototype.toString.call(e).match(/\s([a-zA-Z]+)/)[1].toLowerCase()}function mn(e){return gn(e)==="boolean"}function bn(e){return gn(e)==="function"||gn(e)==="asyncfunction"}function vn(e){return bn(e)&&/^\s*class\s+/.test(e.toString())}function kn(e){return gn(e)==="number"}function yn(e){return gn(e)==="object"}function wn(e){return Promise.resolve(e)===e}function xn(e){return gn(e)==="string"}function En(e){return gn(e)==="undefined"}function Cn(e,...t){if(!t.length)return e;const o=t.shift();if(yn(e)&&yn(o))for(const t in o)yn(o[t])?(e[t]===void 0&&Object.assign(e,{[t]:{}}),Cn(e[t],o[t])):Object.assign(e,{[t]:o[t]});return Cn(e,...t)}function Bn(e,t,o){const n=`«${t}» is deprecated and will be removed in the next major release. Please use the «${o}» instead.`;e&&console.warn(n)}function Tn(e){try{return new URL(e).href}catch{}return e.substring(0,2)==="//"?window.location.protocol+e:window.location.origin+e}function Sn(e){return e>47&&e<58||e===32||e===13||e===229||e>64&&e<91||e>95&&e<112||e>185&&e<193||e>218&&e<223}const In={BACKSPACE:8,TAB:9,ENTER:13,SHIFT:16,CTRL:17,ALT:18,ESC:27,SPACE:32,LEFT:37,UP:38,DOWN:40,RIGHT:39,DELETE:46,META:91,SLASH:191},On={LEFT:0,WHEEL:1,RIGHT:2,BACKWARD:3,FORWARD:4};let _n=class{constructor(){this.completed=Promise.resolve()}
/**
   * Add new promise to queue
   * @param operation - promise should be added to queue
   */add(e){return new Promise(((t,o)=>{this.completed=this.completed.then(e).then(t).catch(o)}))}};function Mn(e,t,o=void 0){let n,i,r,a=null,l=0;o||(o={});const c=function(){l=o.leading===!1?0:Date.now(),a=null,r=e.apply(n,i),a===null&&(n=i=null)};return function(){const d=Date.now();!l&&o.leading===!1&&(l=d);const h=t-(d-l);return n=this,i=arguments,h<=0||h>t?(a&&(clearTimeout(a),a=null),l=d,r=e.apply(n,i),a===null&&(n=i=null)):!a&&o.trailing!==!1&&(a=setTimeout(c,h)),r}}const An=Object.freeze(Object.defineProperty({__proto__:null,PromiseQueue:_n,beautifyShortcut:hn,cacheable:sn,capitalize:un,copyTextToClipboard:pn,debounce:fn,deepMerge:Cn,deprecationAssert:Bn,getUserOS:rn,getValidUrl:Tn,isBoolean:mn,isClass:vn,isEmpty:cn,isFunction:bn,isIosDevice:dn,isNumber:kn,isObject:yn,isPrintableKey:Sn,isPromise:wn,isString:xn,isUndefined:En,keyCodes:In,mouseButtons:On,notEmpty:ln,throttle:Mn,typeOf:gn},Symbol.toStringTag,{value:"Module"})),Ln=o(An);Object.defineProperty(on,"__esModule",{value:!0});on.containsOnlyInlineElements=Rn;var Pn=Ln,Nn=Do;function Rn(e){var t;(0,Pn.isString)(e)?(t=document.createElement("div"),t.innerHTML=e):t=e;var o=function(e){return!(0,Nn.blockElements)().includes(e.tagName.toLowerCase())&&Array.from(e.children).every(o)};return Array.from(t.children).every(o)}(function(e){Object.defineProperty(e,"__esModule",{value:!0}),e.containsOnlyInlineElements=void 0;var t=on;Object.defineProperty(e,"containsOnlyInlineElements",{enumerable:!0,get:function(){return t.containsOnlyInlineElements}})})(en);var Hn={},Yn={},Kn={},Xn={};Object.defineProperty(Xn,"__esModule",{value:!0});Xn.make=Vn;function Vn(e,t,o){var n;t===void 0&&(t=null),o===void 0&&(o={});var i=document.createElement(e);if(Array.isArray(t)){var r=t.filter((function(e){return e!==void 0}));(n=i.classList).add.apply(n,r)}else t!==null&&i.classList.add(t);for(var a in o)Object.prototype.hasOwnProperty.call(o,a)&&(i[a]=o[a]);return i}(function(e){Object.defineProperty(e,"__esModule",{value:!0}),e.make=void 0;var t=Xn;Object.defineProperty(e,"make",{enumerable:!0,get:function(){return t.make}})})(Kn);Object.defineProperty(Yn,"__esModule",{value:!0});Yn.fragmentToString=Zn;var qn=Kn;function Zn(e){var t=(0,qn.make)("div");return t.appendChild(e),t.innerHTML}(function(e){Object.defineProperty(e,"__esModule",{value:!0}),e.fragmentToString=void 0;var t=Yn;Object.defineProperty(e,"fragmentToString",{enumerable:!0,get:function(){return t.fragmentToString}})})(Hn);var Gn={},Qn={};Object.defineProperty(Qn,"__esModule",{value:!0});Qn.getContentLength=ei;var Jn=Mo;function ei(e){var t,o;return(0,Jn.isNativeInput)(e)?e.value.length:e.nodeType===Node.TEXT_NODE?e.length:(o=(t=e.textContent)===null||t===void 0?void 0:t.length)!==null&&o!==void 0?o:0}(function(e){Object.defineProperty(e,"__esModule",{value:!0}),e.getContentLength=void 0;var t=Qn;Object.defineProperty(e,"getContentLength",{enumerable:!0,get:function(){return t.getContentLength}})})(Gn);var ti={},oi={},ni=e&&e.__spreadArray||function(e,t,o){if(o||arguments.length===2)for(var n,i=0,r=t.length;i<r;i++)(n||!(i in t))&&(n||(n=Array.prototype.slice.call(t,0,i)),n[i]=t[i]);return e.concat(n||Array.prototype.slice.call(t))};Object.defineProperty(oi,"__esModule",{value:!0});oi.getDeepestBlockElements=si;var ii=en;function si(e){return(0,ii.containsOnlyInlineElements)(e)?[e]:Array.from(e.children).reduce((function(e,t){return ni(ni([],e,!0),si(t),!0)}),[])}(function(e){Object.defineProperty(e,"__esModule",{value:!0}),e.getDeepestBlockElements=void 0;var t=oi;Object.defineProperty(e,"getDeepestBlockElements",{enumerable:!0,get:function(){return t.getDeepestBlockElements}})})(ti);var ri={},ai={},li={},ci={};Object.defineProperty(ci,"__esModule",{value:!0});ci.isLineBreakTag=di;function di(e){return["BR","WBR"].includes(e.tagName)}(function(e){Object.defineProperty(e,"__esModule",{value:!0}),e.isLineBreakTag=void 0;var t=ci;Object.defineProperty(e,"isLineBreakTag",{enumerable:!0,get:function(){return t.isLineBreakTag}})})(li);var hi={},ui={};Object.defineProperty(ui,"__esModule",{value:!0});ui.isSingleTag=pi;function pi(e){return["AREA","BASE","BR","COL","COMMAND","EMBED","HR","IMG","INPUT","KEYGEN","LINK","META","PARAM","SOURCE","TRACK","WBR"].includes(e.tagName)}(function(e){Object.defineProperty(e,"__esModule",{value:!0}),e.isSingleTag=void 0;var t=ui;Object.defineProperty(e,"isSingleTag",{enumerable:!0,get:function(){return t.isSingleTag}})})(hi);Object.defineProperty(ai,"__esModule",{value:!0});ai.getDeepestNode=Ei;var fi=Mo,mi=li,xi=hi;function Ei(e,t){t===void 0&&(t=!1);var o=t?"lastChild":"firstChild",n=t?"previousSibling":"nextSibling";if(e.nodeType===Node.ELEMENT_NODE&&e[o]){var i=e[o];if((0,xi.isSingleTag)(i)&&!(0,fi.isNativeInput)(i)&&!(0,mi.isLineBreakTag)(i))if(i[n])i=i[n];else{if(i.parentNode===null||!i.parentNode[n])return i.parentNode;i=i.parentNode[n]}return Ei(i,t)}return e}(function(e){Object.defineProperty(e,"__esModule",{value:!0}),e.getDeepestNode=void 0;var t=ai;Object.defineProperty(e,"getDeepestNode",{enumerable:!0,get:function(){return t.getDeepestNode}})})(ri);var Si={},Ii={},Oi=e&&e.__spreadArray||function(e,t,o){if(o||arguments.length===2)for(var n,i=0,r=t.length;i<r;i++)(n||!(i in t))&&(n||(n=Array.prototype.slice.call(t,0,i)),n[i]=t[i]);return e.concat(n||Array.prototype.slice.call(t))};Object.defineProperty(Ii,"__esModule",{value:!0});Ii.findAllInputs=Hi;var _i=en,Mi=ti,Ai=Io,ji=Mo;function Hi(e){return Array.from(e.querySelectorAll((0,Ai.allInputsSelector)())).reduce((function(e,t){return(0,ji.isNativeInput)(t)||(0,_i.containsOnlyInlineElements)(t)?Oi(Oi([],e,!0),[t],!1):Oi(Oi([],e,!0),(0,Mi.getDeepestBlockElements)(t),!0)}),[])}(function(e){Object.defineProperty(e,"__esModule",{value:!0}),e.findAllInputs=void 0;var t=Ii;Object.defineProperty(e,"findAllInputs",{enumerable:!0,get:function(){return t.findAllInputs}})})(Si);var zi={},$i={};Object.defineProperty($i,"__esModule",{value:!0});$i.isCollapsedWhitespaces=Yi;function Yi(e){return!/[^\t\n\r ]/.test(e)}(function(e){Object.defineProperty(e,"__esModule",{value:!0}),e.isCollapsedWhitespaces=void 0;var t=$i;Object.defineProperty(e,"isCollapsedWhitespaces",{enumerable:!0,get:function(){return t.isCollapsedWhitespaces}})})(zi);var Ki={},Xi={};Object.defineProperty(Xi,"__esModule",{value:!0});Xi.isElement=qi;var Vi=Ln;function qi(e){return!(0,Vi.isNumber)(e)&&(!!e&&!!e.nodeType&&e.nodeType===Node.ELEMENT_NODE)}(function(e){Object.defineProperty(e,"__esModule",{value:!0}),e.isElement=void 0;var t=Xi;Object.defineProperty(e,"isElement",{enumerable:!0,get:function(){return t.isElement}})})(Ki);var Zi={},Gi={},Qi={},Ji={};Object.defineProperty(Ji,"__esModule",{value:!0});Ji.isLeaf=es;function es(e){return e!==null&&e.childNodes.length===0}(function(e){Object.defineProperty(e,"__esModule",{value:!0}),e.isLeaf=void 0;var t=Ji;Object.defineProperty(e,"isLeaf",{enumerable:!0,get:function(){return t.isLeaf}})})(Qi);var ts={},os={};Object.defineProperty(os,"__esModule",{value:!0});os.isNodeEmpty=cs;var ns=li,is=Ki,ss=Mo,rs=hi;function cs(e,t){var o="";return!((0,rs.isSingleTag)(e)&&!(0,ns.isLineBreakTag)(e))&&((0,is.isElement)(e)&&(0,ss.isNativeInput)(e)?o=e.value:e.textContent!==null&&(o=e.textContent.replace("​","")),t!==void 0&&(o=o.replace(new RegExp(t,"g"),"")),o.trim().length===0)}(function(e){Object.defineProperty(e,"__esModule",{value:!0}),e.isNodeEmpty=void 0;var t=os;Object.defineProperty(e,"isNodeEmpty",{enumerable:!0,get:function(){return t.isNodeEmpty}})})(ts);Object.defineProperty(Gi,"__esModule",{value:!0});Gi.isEmpty=ps;var ds=Qi,us=ts;function ps(e,t){e.normalize();for(var o=[e];o.length>0;){var n=o.shift();if(n){if(e=n,(0,ds.isLeaf)(e)&&!(0,us.isNodeEmpty)(e,t))return!1;o.push.apply(o,Array.from(e.childNodes))}}return!0}(function(e){Object.defineProperty(e,"__esModule",{value:!0}),e.isEmpty=void 0;var t=Gi;Object.defineProperty(e,"isEmpty",{enumerable:!0,get:function(){return t.isEmpty}})})(Zi);var bs={},vs={};Object.defineProperty(vs,"__esModule",{value:!0});vs.isFragment=ws;var ys=Ln;function ws(e){return!(0,ys.isNumber)(e)&&(!!e&&!!e.nodeType&&e.nodeType===Node.DOCUMENT_FRAGMENT_NODE)}(function(e){Object.defineProperty(e,"__esModule",{value:!0}),e.isFragment=void 0;var t=vs;Object.defineProperty(e,"isFragment",{enumerable:!0,get:function(){return t.isFragment}})})(bs);var xs={},Es={};Object.defineProperty(Es,"__esModule",{value:!0});Es.isHTMLString=Ss;var Ts=Kn;function Ss(e){var t=(0,Ts.make)("div");return t.innerHTML=e,t.childElementCount>0}(function(e){Object.defineProperty(e,"__esModule",{value:!0}),e.isHTMLString=void 0;var t=Es;Object.defineProperty(e,"isHTMLString",{enumerable:!0,get:function(){return t.isHTMLString}})})(xs);var Is={},Os={};Object.defineProperty(Os,"__esModule",{value:!0});Os.offset=_s;function _s(e){var t=e.getBoundingClientRect(),o=window.pageXOffset||document.documentElement.scrollLeft,n=window.pageYOffset||document.documentElement.scrollTop,i=t.top+n,r=t.left+o;return{top:i,left:r,bottom:i+t.height,right:r+t.width}}(function(e){Object.defineProperty(e,"__esModule",{value:!0}),e.offset=void 0;var t=Os;Object.defineProperty(e,"offset",{enumerable:!0,get:function(){return t.offset}})})(Is);var Ms={},As={};Object.defineProperty(As,"__esModule",{value:!0});As.prepend=Ls;function Ls(e,t){Array.isArray(t)?(t=t.reverse(),t.forEach((function(t){return e.prepend(t)}))):e.prepend(t)}(function(e){Object.defineProperty(e,"__esModule",{value:!0}),e.prepend=void 0;var t=As;Object.defineProperty(e,"prepend",{enumerable:!0,get:function(){return t.prepend}})})(Ms);(function(e){Object.defineProperty(e,"__esModule",{value:!0}),e.prepend=e.offset=e.make=e.isLineBreakTag=e.isSingleTag=e.isNodeEmpty=e.isLeaf=e.isHTMLString=e.isFragment=e.isEmpty=e.isElement=e.isContentEditable=e.isCollapsedWhitespaces=e.findAllInputs=e.isNativeInput=e.allInputsSelector=e.getDeepestNode=e.getDeepestBlockElements=e.getContentLength=e.fragmentToString=e.containsOnlyInlineElements=e.canSetCaret=e.calculateBaseline=e.blockElements=e.append=void 0;var t=Io;Object.defineProperty(e,"allInputsSelector",{enumerable:!0,get:function(){return t.allInputsSelector}});var o=Mo;Object.defineProperty(e,"isNativeInput",{enumerable:!0,get:function(){return o.isNativeInput}});var n=Po;Object.defineProperty(e,"append",{enumerable:!0,get:function(){return n.append}});var i=Do;Object.defineProperty(e,"blockElements",{enumerable:!0,get:function(){return i.blockElements}});var r=zo;Object.defineProperty(e,"calculateBaseline",{enumerable:!0,get:function(){return r.calculateBaseline}});var a=Wo;Object.defineProperty(e,"canSetCaret",{enumerable:!0,get:function(){return a.canSetCaret}});var l=en;Object.defineProperty(e,"containsOnlyInlineElements",{enumerable:!0,get:function(){return l.containsOnlyInlineElements}});var c=Hn;Object.defineProperty(e,"fragmentToString",{enumerable:!0,get:function(){return c.fragmentToString}});var d=Gn;Object.defineProperty(e,"getContentLength",{enumerable:!0,get:function(){return d.getContentLength}});var h=ti;Object.defineProperty(e,"getDeepestBlockElements",{enumerable:!0,get:function(){return h.getDeepestBlockElements}});var p=ri;Object.defineProperty(e,"getDeepestNode",{enumerable:!0,get:function(){return p.getDeepestNode}});var f=Si;Object.defineProperty(e,"findAllInputs",{enumerable:!0,get:function(){return f.findAllInputs}});var g=zi;Object.defineProperty(e,"isCollapsedWhitespaces",{enumerable:!0,get:function(){return g.isCollapsedWhitespaces}});var m=Ko;Object.defineProperty(e,"isContentEditable",{enumerable:!0,get:function(){return m.isContentEditable}});var v=Ki;Object.defineProperty(e,"isElement",{enumerable:!0,get:function(){return v.isElement}});var k=Zi;Object.defineProperty(e,"isEmpty",{enumerable:!0,get:function(){return k.isEmpty}});var y=bs;Object.defineProperty(e,"isFragment",{enumerable:!0,get:function(){return y.isFragment}});var w=xs;Object.defineProperty(e,"isHTMLString",{enumerable:!0,get:function(){return w.isHTMLString}});var x=Qi;Object.defineProperty(e,"isLeaf",{enumerable:!0,get:function(){return x.isLeaf}});var C=ts;Object.defineProperty(e,"isNodeEmpty",{enumerable:!0,get:function(){return C.isNodeEmpty}});var B=li;Object.defineProperty(e,"isLineBreakTag",{enumerable:!0,get:function(){return B.isLineBreakTag}});var T=hi;Object.defineProperty(e,"isSingleTag",{enumerable:!0,get:function(){return T.isSingleTag}});var S=Kn;Object.defineProperty(e,"make",{enumerable:!0,get:function(){return S.make}});var I=Is;Object.defineProperty(e,"offset",{enumerable:!0,get:function(){return I.offset}});var O=Ms;Object.defineProperty(e,"prepend",{enumerable:!0,get:function(){return O.prepend}})})(So);var Ps={};Object.defineProperty(Ps,"__esModule",{value:!0});Ps.getContenteditableSlice=Rs;var Ns=So;function Rs(e,t,o,n,i){var r;i===void 0&&(i=!1);var a=document.createRange();if(n==="left"?(a.setStart(e,0),a.setEnd(t,o)):(a.setStart(t,o),a.setEnd(e,e.childNodes.length)),i===!0){var l=a.extractContents();return(0,Ns.fragmentToString)(l)}var c=a.cloneContents(),d=document.createElement("div");d.appendChild(c);var h=(r=d.textContent)!==null&&r!==void 0?r:"";return h}Object.defineProperty(To,"__esModule",{value:!0});To.checkContenteditableSliceForEmptiness=Fs;var Ds=So,js=Ps;function Fs(e,t,o,n){var i=(0,js.getContenteditableSlice)(e,t,o,n);return(0,Ds.isCollapsedWhitespaces)(i)}(function(e){Object.defineProperty(e,"__esModule",{value:!0}),e.checkContenteditableSliceForEmptiness=void 0;var t=To;Object.defineProperty(e,"checkContenteditableSliceForEmptiness",{enumerable:!0,get:function(){return t.checkContenteditableSliceForEmptiness}})})(Bo);var Hs={};(function(e){Object.defineProperty(e,"__esModule",{value:!0}),e.getContenteditableSlice=void 0;var t=Ps;Object.defineProperty(e,"getContenteditableSlice",{enumerable:!0,get:function(){return t.getContenteditableSlice}})})(Hs);var zs={},Us={};Object.defineProperty(Us,"__esModule",{value:!0});Us.focus=Ws;var $s=So;function Ws(e,t){var o,n;if(t===void 0&&(t=!0),(0,$s.isNativeInput)(e)){e.focus();var i=t?0:e.value.length;e.setSelectionRange(i,i)}else{var r=document.createRange(),a=window.getSelection();if(!a)return;var l=function(e){var t=document.createTextNode("");e.appendChild(t),r.setStart(t,0),r.setEnd(t,0)},c=function(e){return e!=null},d=e.childNodes,h=t?d[0]:d[d.length-1];if(c(h)){for(;c(h)&&h.nodeType!==Node.TEXT_NODE;)h=t?h.firstChild:h.lastChild;if(c(h)&&h.nodeType===Node.TEXT_NODE){var p=(n=(o=h.textContent)===null||o===void 0?void 0:o.length)!==null&&n!==void 0?n:0;i=t?0:p;r.setStart(h,i),r.setEnd(h,i)}else l(e)}else l(e);a.removeAllRanges(),a.addRange(r)}}(function(e){Object.defineProperty(e,"__esModule",{value:!0}),e.focus=void 0;var t=Us;Object.defineProperty(e,"focus",{enumerable:!0,get:function(){return t.focus}})})(zs);var Ys={},Ks={};Object.defineProperty(Ks,"__esModule",{value:!0});Ks.getCaretNodeAndOffset=Xs;function Xs(){var e=window.getSelection();if(e===null)return[null,0];var t=e.focusNode,o=e.focusOffset;return t===null?[null,0]:(t.nodeType!==Node.TEXT_NODE&&t.childNodes.length>0&&(t.childNodes[o]!==void 0?(t=t.childNodes[o],o=0):(t=t.childNodes[o-1],t.textContent!==null&&(o=t.textContent.length))),[t,o])}(function(e){Object.defineProperty(e,"__esModule",{value:!0}),e.getCaretNodeAndOffset=void 0;var t=Ks;Object.defineProperty(e,"getCaretNodeAndOffset",{enumerable:!0,get:function(){return t.getCaretNodeAndOffset}})})(Ys);var Vs={},qs={};Object.defineProperty(qs,"__esModule",{value:!0});qs.getRange=Zs;function Zs(){var e=window.getSelection();return e&&e.rangeCount?e.getRangeAt(0):null}(function(e){Object.defineProperty(e,"__esModule",{value:!0}),e.getRange=void 0;var t=qs;Object.defineProperty(e,"getRange",{enumerable:!0,get:function(){return t.getRange}})})(Vs);var Gs={},Qs={};Object.defineProperty(Qs,"__esModule",{value:!0});Qs.isCaretAtEndOfInput=or;var Js=So,er=Ys,tr=Bo;function or(e){var t=(0,Js.getDeepestNode)(e,!0);if(t===null)return!0;if((0,Js.isNativeInput)(t))return t.selectionEnd===t.value.length;var o=(0,er.getCaretNodeAndOffset)(),n=o[0],i=o[1];return n!==null&&(0,tr.checkContenteditableSliceForEmptiness)(e,n,i,"right")}(function(e){Object.defineProperty(e,"__esModule",{value:!0}),e.isCaretAtEndOfInput=void 0;var t=Qs;Object.defineProperty(e,"isCaretAtEndOfInput",{enumerable:!0,get:function(){return t.isCaretAtEndOfInput}})})(Gs);var nr={},ir={};Object.defineProperty(ir,"__esModule",{value:!0});ir.isCaretAtStartOfInput=lr;var sr=So,rr=Ks,ar=To;function lr(e){var t=(0,sr.getDeepestNode)(e);if(t===null||(0,sr.isEmpty)(e))return!0;if((0,sr.isNativeInput)(t))return t.selectionEnd===0;if((0,sr.isEmpty)(e))return!0;var o=(0,rr.getCaretNodeAndOffset)(),n=o[0],i=o[1];return n!==null&&(0,ar.checkContenteditableSliceForEmptiness)(e,n,i,"left")}(function(e){Object.defineProperty(e,"__esModule",{value:!0}),e.isCaretAtStartOfInput=void 0;var t=ir;Object.defineProperty(e,"isCaretAtStartOfInput",{enumerable:!0,get:function(){return t.isCaretAtStartOfInput}})})(nr);var cr={},dr={};Object.defineProperty(dr,"__esModule",{value:!0});dr.save=pr;var hr=So,ur=qs;function pr(){var e=(0,ur.getRange)(),t=(0,hr.make)("span");if(t.id="cursor",t.hidden=!0,!!e)return e.insertNode(t),function(){var o=window.getSelection();o&&(e.setStartAfter(t),e.setEndAfter(t),o.removeAllRanges(),o.addRange(e),setTimeout((function(){t.remove()}),150))}}(function(e){Object.defineProperty(e,"__esModule",{value:!0}),e.save=void 0;var t=dr;Object.defineProperty(e,"save",{enumerable:!0,get:function(){return t.save}})})(cr);(function(e){Object.defineProperty(e,"__esModule",{value:!0}),e.save=e.isCaretAtStartOfInput=e.isCaretAtEndOfInput=e.getRange=e.getCaretNodeAndOffset=e.focus=e.getContenteditableSlice=e.checkContenteditableSliceForEmptiness=void 0;var t=Bo;Object.defineProperty(e,"checkContenteditableSliceForEmptiness",{enumerable:!0,get:function(){return t.checkContenteditableSliceForEmptiness}});var o=Hs;Object.defineProperty(e,"getContenteditableSlice",{enumerable:!0,get:function(){return o.getContenteditableSlice}});var n=zs;Object.defineProperty(e,"focus",{enumerable:!0,get:function(){return n.focus}});var i=Ys;Object.defineProperty(e,"getCaretNodeAndOffset",{enumerable:!0,get:function(){return i.getCaretNodeAndOffset}});var r=Vs;Object.defineProperty(e,"getRange",{enumerable:!0,get:function(){return r.getRange}});var a=Gs;Object.defineProperty(e,"isCaretAtEndOfInput",{enumerable:!0,get:function(){return a.isCaretAtEndOfInput}});var l=nr;Object.defineProperty(e,"isCaretAtStartOfInput",{enumerable:!0,get:function(){return l.isCaretAtStartOfInput}});var c=cr;Object.defineProperty(e,"save",{enumerable:!0,get:function(){return c.save}})})(Co);class na extends E{
/**
   * All keydowns on Block
   *
   * @param {KeyboardEvent} event - keydown
   */
keydown(e){switch(this.beforeKeydownProcessing(e),e.keyCode){case a.BACKSPACE:this.backspace(e);break;case a.DELETE:this.delete(e);break;case a.ENTER:this.enter(e);break;case a.DOWN:case a.RIGHT:this.arrowRightAndDown(e);break;case a.UP:case a.LEFT:this.arrowLeftAndUp(e);break;case a.TAB:this.tabPressed(e);break}e.key==="/"&&!e.ctrlKey&&!e.metaKey&&this.slashPressed(e),e.code==="Slash"&&(e.ctrlKey||e.metaKey)&&(e.preventDefault(),this.commandSlashPressed()
/**
   * Fires on keydown before event processing
   *
   * @param {KeyboardEvent} event - keydown
   */)}beforeKeydownProcessing(e){this.needToolbarClosing(e)&&C(e.keyCode)&&(this.Editor.Toolbar.close(),e.ctrlKey||e.metaKey||e.altKey||e.shiftKey||this.Editor.BlockSelection.clearSelection(e)
/**
   * Key up on Block:
   * - shows Inline Toolbar if something selected
   * - shows conversion toolbar with 85% of block selection
   *
   * @param {KeyboardEvent} event - keyup event
   */)}keyup(e){e.shiftKey||this.Editor.UI.checkEmptiness()}
/**
   * Add drop target styles
   *
   * @param {DragEvent} event - drag over event
   */dragOver(e){const t=this.Editor.BlockManager.getBlockByChildNode(e.target);t.dropTarget=!0}
/**
   * Remove drop target style
   *
   * @param {DragEvent} event - drag leave event
   */dragLeave(e){const t=this.Editor.BlockManager.getBlockByChildNode(e.target);t.dropTarget=!1}
/**
   * Copying selected blocks
   * Before putting to the clipboard we sanitize all blocks and then copy to the clipboard
   *
   * @param {ClipboardEvent} event - clipboard event
   */handleCommandC(e){const{BlockSelection:t}=this.Editor;t.anyBlockSelected&&t.copySelectedBlocks(e)}
/**
   * Copy and Delete selected Blocks
   *
   * @param {ClipboardEvent} event - clipboard event
   */handleCommandX(e){const{BlockSelection:t,BlockManager:o,Caret:n}=this.Editor;t.anyBlockSelected&&t.copySelectedBlocks(e).then((()=>{const i=o.removeSelectedBlocks(),r=o.insertDefaultBlockAtIndex(i,!0);n.setToBlock(r,n.positions.START),t.clearSelection(e)}))}
/**
   * Tab pressed inside a Block.
   *
   * @param {KeyboardEvent} event - keydown
   */tabPressed(e){const{InlineToolbar:t,Caret:o}=this.Editor;t.opened||(e.shiftKey?o.navigatePrevious(!0):o.navigateNext(!0))&&e.preventDefault()}commandSlashPressed(){this.Editor.BlockSelection.selectedBlocks.length>1||this.activateBlockSettings()}
/**
   * '/' keydown inside a Block
   *
   * @param event - keydown
   */slashPressed(e){!this.Editor.UI.nodes.wrapper.contains(e.target)||!this.Editor.BlockManager.currentBlock.isEmpty||(e.preventDefault(),this.Editor.Caret.insertContentAtCaretPosition("/"),this.activateToolbox()
/**
   * ENTER pressed on block
   *
   * @param {KeyboardEvent} event - keydown
   */)}enter(e){const{BlockManager:t,UI:o}=this.Editor,n=t.currentBlock;if(n===void 0||n.tool.isLineBreaksEnabled||o.someToolbarOpened&&o.someFlipperButtonFocused||e.shiftKey&&!K)return;let i=n;n.currentInput!==void 0&&xo(n.currentInput)&&!n.hasMedia?this.Editor.BlockManager.insertDefaultBlockAtIndex(this.Editor.BlockManager.currentBlockIndex):i=n.currentInput&&Eo(n.currentInput)?this.Editor.BlockManager.insertDefaultBlockAtIndex(this.Editor.BlockManager.currentBlockIndex+1):this.Editor.BlockManager.split(),this.Editor.Caret.setToBlock(i),this.Editor.Toolbar.moveAndOpen(i),e.preventDefault()
/**
   * Handle backspace keydown on Block
   *
   * @param {KeyboardEvent} event - keydown
   */}backspace(e){const{BlockManager:t,Caret:o}=this.Editor,{currentBlock:n,previousBlock:i}=t;if(n!==void 0&&b.isCollapsed&&n.currentInput&&xo(n.currentInput))if(e.preventDefault(),this.Editor.Toolbar.close(),n.currentInput===n.firstInput){if(i!==null)if(i.isEmpty)t.removeBlock(i);else if(n.isEmpty){t.removeBlock(n);const e=t.currentBlock;o.setToBlock(e,o.positions.END)}else ve(i,n)?this.mergeBlocks(i,n):o.setToBlock(i,o.positions.END)}else o.navigatePrevious()}
/**
   * Handles delete keydown on Block
   * Removes char after the caret.
   * If caret is at the end of the block, merge next block with current
   *
   * @param {KeyboardEvent} event - keydown
   */delete(e){const{BlockManager:t,Caret:o}=this.Editor,{currentBlock:n,nextBlock:i}=t;b.isCollapsed&&Eo(n.currentInput)&&(e.preventDefault(),this.Editor.Toolbar.close(),n.currentInput===n.lastInput?i!==null&&(i.isEmpty?t.removeBlock(i):n.isEmpty?(t.removeBlock(n),o.setToBlock(i,o.positions.START)):ve(n,i)?this.mergeBlocks(n,i):o.setToBlock(i,o.positions.START)):o.navigateNext())}
/**
   * Merge passed Blocks
   *
   * @param targetBlock - to which Block we want to merge
   * @param blockToMerge - what Block we want to merge
   */mergeBlocks(e,t){const{BlockManager:o,Toolbar:n}=this.Editor;e.lastInput!==void 0&&(Co.focus(e.lastInput,!1),o.mergeBlocks(e,t).then((()=>{n.close()}))
/**
   * Handle right and down keyboard keys
   *
   * @param {KeyboardEvent} event - keyboard event
   */)}arrowRightAndDown(e){const t=ce.usedKeys.includes(e.keyCode)&&(!e.shiftKey||e.keyCode===a.TAB);if(this.Editor.UI.someToolbarOpened&&t)return;this.Editor.Toolbar.close();const{currentBlock:o}=this.Editor.BlockManager,n=((o==null?void 0:o.currentInput)!==void 0?Eo(o.currentInput):void 0)||this.Editor.BlockSelection.anyBlockSelected;e.shiftKey&&e.keyCode===a.DOWN&&n?this.Editor.CrossBlockSelection.toggleBlockSelectedState():(e.keyCode===a.DOWN||e.keyCode===a.RIGHT&&!this.isRtl?this.Editor.Caret.navigateNext():this.Editor.Caret.navigatePrevious())?e.preventDefault():(S((()=>{this.Editor.BlockManager.currentBlock&&this.Editor.BlockManager.currentBlock.updateCurrentInput()}),20)(),this.Editor.BlockSelection.clearSelection(e)
/**
   * Handle left and up keyboard keys
   *
   * @param {KeyboardEvent} event - keyboard event
   */)}arrowLeftAndUp(e){if(this.Editor.UI.someToolbarOpened){if(ce.usedKeys.includes(e.keyCode)&&(!e.shiftKey||e.keyCode===a.TAB))return;this.Editor.UI.closeAllToolbars()}this.Editor.Toolbar.close();const{currentBlock:t}=this.Editor.BlockManager,o=((t==null?void 0:t.currentInput)!==void 0?xo(t.currentInput):void 0)||this.Editor.BlockSelection.anyBlockSelected;e.shiftKey&&e.keyCode===a.UP&&o?this.Editor.CrossBlockSelection.toggleBlockSelectedState(!1):(e.keyCode===a.UP||e.keyCode===a.LEFT&&!this.isRtl?this.Editor.Caret.navigatePrevious():this.Editor.Caret.navigateNext())?e.preventDefault():(S((()=>{this.Editor.BlockManager.currentBlock&&this.Editor.BlockManager.currentBlock.updateCurrentInput()}),20)(),this.Editor.BlockSelection.clearSelection(e)
/**
   * Cases when we need to close Toolbar
   *
   * @param {KeyboardEvent} event - keyboard event
   */)}needToolbarClosing(e){const t=e.keyCode===a.ENTER&&this.Editor.Toolbar.toolbox.opened,o=e.keyCode===a.ENTER&&this.Editor.BlockSettings.opened,n=e.keyCode===a.ENTER&&this.Editor.InlineToolbar.opened,i=e.keyCode===a.TAB;return!(e.shiftKey||i||t||o||n)}activateToolbox(){this.Editor.Toolbar.opened||this.Editor.Toolbar.moveAndOpen(),this.Editor.Toolbar.toolbox.open()}activateBlockSettings(){this.Editor.Toolbar.opened||this.Editor.Toolbar.moveAndOpen(),this.Editor.BlockSettings.opened||this.Editor.BlockSettings.open()}}class ct{
/**
   * @class
   * @param {HTMLElement} workingArea — editor`s working node
   */
constructor(e){this.blocks=[],this.workingArea=e
/**
   * Get length of Block instances array
   *
   * @returns {number}
   */}get length(){return this.blocks.length}
/**
   * Get Block instances array
   *
   * @returns {Block[]}
   */get array(){return this.blocks}
/**
   * Get blocks html elements array
   *
   * @returns {HTMLElement[]}
   */get nodes(){return T(this.workingArea.children)}
/**
   * Proxy trap to implement array-like setter
   *
   * @example
   * blocks[0] = new Block(...)
   * @param {Blocks} instance — Blocks instance
   * @param {PropertyKey} property — block index or any Blocks class property key to set
   * @param {Block} value — value to set
   * @returns {boolean}
   */static set(e,t,o){return isNaN(Number(t))?(Reflect.set(e,t,o),!0):(e.insert(+t,o),!0
/**
   * Proxy trap to implement array-like getter
   *
   * @param {Blocks} instance — Blocks instance
   * @param {PropertyKey} property — Blocks class property key
   * @returns {Block|*}
   */)}static get(e,t){return isNaN(Number(t))?Reflect.get(e,t):e.get(+t)}
/**
   * Push new Block to the blocks array and append it to working area
   *
   * @param {Block} block - Block to add
   */push(e){this.blocks.push(e),this.insertToDOM(e)
/**
   * Swaps blocks with indexes first and second
   *
   * @param {number} first - first block index
   * @param {number} second - second block index
   * @deprecated — use 'move' instead
   */}swap(e,t){const o=this.blocks[t];u.swap(this.blocks[e].holder,o.holder),this.blocks[t]=this.blocks[e],this.blocks[e]=o
/**
   * Move a block from one to another index
   *
   * @param {number} toIndex - new index of the block
   * @param {number} fromIndex - block to move
   */}move(e,t){const o=this.blocks.splice(t,1)[0],n=e-1,i=Math.max(0,n),r=this.blocks[i];e>0?this.insertToDOM(o,"afterend",r):this.insertToDOM(o,"beforebegin",r),this.blocks.splice(e,0,o);const a=this.composeBlockEvent("move",{fromIndex:t,toIndex:e});o.call(Ce.MOVED,a)}
/**
   * Insert new Block at passed index
   *
   * @param {number} index — index to insert Block
   * @param {Block} block — Block to insert
   * @param {boolean} replace — it true, replace block on given index
   */insert(e,t,o=!1){if(!this.length){this.push(t);return}e>this.length&&(e=this.length),o&&(this.blocks[e].holder.remove(),this.blocks[e].call(Ce.REMOVED));const n=o?1:0;if(this.blocks.splice(e,n,t),e>0){const o=this.blocks[e-1];this.insertToDOM(t,"afterend",o)}else{const o=this.blocks[e+1];o?this.insertToDOM(t,"beforebegin",o):this.insertToDOM(t)}}
/**
   * Replaces block under passed index with passed block
   *
   * @param index - index of existed block
   * @param block - new block
   */replace(e,t){if(this.blocks[e]===void 0)throw Error("Incorrect index");this.blocks[e].holder.replaceWith(t.holder),this.blocks[e]=t
/**
   * Inserts several blocks at once
   *
   * @param blocks - blocks to insert
   * @param index - index to insert blocks at
   */}insertMany(e,t){const o=new DocumentFragment;for(const t of e)o.appendChild(t.holder);if(this.length>0){if(t>0){const e=Math.min(t-1,this.length-1);this.blocks[e].holder.after(o)}else t===0&&this.workingArea.prepend(o);this.blocks.splice(t,0,...e)}else this.blocks.push(...e),this.workingArea.appendChild(o);e.forEach((e=>e.call(Ce.RENDERED)))}
/**
   * Remove block
   *
   * @param {number} index - index of Block to remove
   */remove(e){isNaN(e)&&(e=this.length-1),this.blocks[e].holder.remove(),this.blocks[e].call(Ce.REMOVED),this.blocks.splice(e,1)}removeAll(){this.workingArea.innerHTML="",this.blocks.forEach((e=>e.call(Ce.REMOVED))),this.blocks.length=0
/**
   * Insert Block after passed target
   *
   * @todo decide if this method is necessary
   * @param {Block} targetBlock — target after which Block should be inserted
   * @param {Block} newBlock — Block to insert
   */}insertAfter(e,t){const o=this.blocks.indexOf(e);this.insert(o+1,t)}
/**
   * Get Block by index
   *
   * @param {number} index — Block index
   * @returns {Block}
   */get(e){return this.blocks[e]}
/**
   * Return index of passed Block
   *
   * @param {Block} block - Block to find
   * @returns {number}
   */indexOf(e){return this.blocks.indexOf(e)}
/**
   * Insert new Block into DOM
   *
   * @param {Block} block - Block to insert
   * @param {InsertPosition} position — insert position (if set, will use insertAdjacentElement)
   * @param {Block} target — Block related to position
   */insertToDOM(e,t,o){t?o.holder.insertAdjacentElement(t,e.holder):this.workingArea.appendChild(e.holder),e.call(Ce.RENDERED)
/**
   * Composes Block event with passed type and details
   *
   * @param {string} type - event type
   * @param {object} detail - event detail
   */}composeBlockEvent(e,t){return new CustomEvent(e,{detail:t})}}const fr="block-removed",gr="block-added",mr="block-moved",br="block-changed";class sa{constructor(){this.completed=Promise.resolve()}
/**
   * Add new promise to queue
   *
   * @param operation - promise should be added to queue
   */add(e){return new Promise(((t,o)=>{this.completed=this.completed.then(e).then(t).catch(o)}))}}class ra extends E{constructor(){super(...arguments),this._currentBlockIndex=-1,this._blocks=null
/**
   * Returns current Block index
   *
   * @returns {number}
   */}get currentBlockIndex(){return this._currentBlockIndex}
/**
   * Set current Block index and fire Block lifecycle callbacks
   *
   * @param {number} newIndex - index of Block to set as current
   */set currentBlockIndex(e){this._currentBlockIndex=e}
/**
   * returns first Block
   *
   * @returns {Block}
   */get firstBlock(){return this._blocks[0]}
/**
   * returns last Block
   *
   * @returns {Block}
   */get lastBlock(){return this._blocks[this._blocks.length-1]}
/**
   * Get current Block instance
   *
   * @returns {Block}
   */get currentBlock(){return this._blocks[this.currentBlockIndex]}
/**
   * Set passed Block as a current
   *
   * @param block - block to set as a current
   */set currentBlock(e){this.currentBlockIndex=this.getBlockIndex(e)}
/**
   * Returns next Block instance
   *
   * @returns {Block|null}
   */get nextBlock(){return this.currentBlockIndex===this._blocks.length-1?null:this._blocks[this.currentBlockIndex+1]}
/**
   * Return first Block with inputs after current Block
   *
   * @returns {Block | undefined}
   */get nextContentfulBlock(){return this.blocks.slice(this.currentBlockIndex+1).find((e=>!!e.inputs.length))}
/**
   * Return first Block with inputs before current Block
   *
   * @returns {Block | undefined}
   */get previousContentfulBlock(){return this.blocks.slice(0,this.currentBlockIndex).reverse().find((e=>!!e.inputs.length))}
/**
   * Returns previous Block instance
   *
   * @returns {Block|null}
   */get previousBlock(){return this.currentBlockIndex===0?null:this._blocks[this.currentBlockIndex-1]}
/**
   * Get array of Block instances
   *
   * @returns {Block[]} {@link Blocks#array}
   */get blocks(){return this._blocks.array}
/**
   * Check if each Block is empty
   *
   * @returns {boolean}
   */get isEditorEmpty(){return this.blocks.every((e=>e.isEmpty))}prepare(){const e=new ct(this.Editor.UI.nodes.redactor);this._blocks=new Proxy(e,{set:ct.set,get:ct.get}),this.listeners.on(document,"copy",(e=>this.Editor.BlockEvents.handleCommandC(e)))
/**
   * Toggle read-only state
   *
   * If readOnly is true:
   *  - Unbind event handlers from created Blocks
   *
   * if readOnly is false:
   *  - Bind event handlers to all existing Blocks
   *
   * @param {boolean} readOnlyEnabled - "read only" state
   */}toggleReadOnly(e){e?this.disableModuleBindings():this.enableModuleBindings()}
/**
   * Creates Block instance by tool name
   *
   * @param {object} options - block creation options
   * @param {string} options.tool - tools passed in editor config {@link EditorConfig#tools}
   * @param {string} [options.id] - unique id for this block
   * @param {BlockToolData} [options.data] - constructor params
   * @returns {Block}
   */composeBlock({tool:e,data:t={},id:o,tunes:n={}}){const i=this.Editor.ReadOnly.isEnabled,r=this.Editor.Tools.blockTools.get(e),a=new R({id:o,data:t,tool:r,api:this.Editor.API,readOnly:i,tunesData:n},this.eventsDispatcher);return i||window.requestIdleCallback((()=>{this.bindBlockEvents(a)}),{timeout:2e3}),a
/**
   * Insert new block into _blocks
   *
   * @param {object} options - insert options
   * @param {string} [options.id] - block's unique id
   * @param {string} [options.tool] - plugin name, by default method inserts the default block type
   * @param {object} [options.data] - plugin data
   * @param {number} [options.index] - index where to insert new Block
   * @param {boolean} [options.needToFocus] - flag shows if needed to update current Block index
   * @param {boolean} [options.replace] - flag shows if block by passed index should be replaced with inserted one
   * @returns {Block}
   */}insert({id:e,tool:t=this.config.defaultBlock,data:o={},index:n,needToFocus:i=!0,replace:r=!1,tunes:a={}}={}){let l=n;l===void 0&&(l=this.currentBlockIndex+(r?0:1));const c=this.composeBlock({id:e,tool:t,data:o,tunes:a});return r&&this.blockDidMutated(fr,this.getBlockByIndex(l),{index:l}),this._blocks.insert(l,c,r),this.blockDidMutated(gr,c,{index:l}),i?this.currentBlockIndex=l:l<=this.currentBlockIndex&&this.currentBlockIndex++,c
/**
   * Inserts several blocks at once
   *
   * @param blocks - blocks to insert
   * @param index - index where to insert
   */}insertMany(e,t=0){this._blocks.insertMany(e,t)}
/**
   * Update Block data.
   *
   * Currently we don't have an 'update' method in the Tools API, so we just create a new block with the same id and type
   * Should not trigger 'block-removed' or 'block-added' events.
   *
   * If neither data nor tunes is provided, return the provided block instead.
   *
   * @param block - block to update
   * @param data - (optional) new data
   * @param tunes - (optional) tune data
   */async update(e,t,o){if(!t&&!o)return e;const n=await e.data,i=this.composeBlock({id:e.id,tool:e.name,data:Object.assign({},n,t??{}),tunes:o??e.tunes}),r=this.getBlockIndex(e);return this._blocks.replace(r,i),this.blockDidMutated(br,i,{index:r}),i
/**
   * Replace passed Block with the new one with specified Tool and data
   *
   * @param block - block to replace
   * @param newTool - new Tool name
   * @param data - new Tool data
   */}replace(e,t,o){const n=this.getBlockIndex(e);return this.insert({tool:t,data:o,index:n,replace:!0})}
/**
   * Insert pasted content. Call onPaste callback after insert.
   *
   * @param {string} toolName - name of Tool to insert
   * @param {PasteEvent} pasteEvent - pasted data
   * @param {boolean} replace - should replace current block
   */paste(e,t,o=!1){const n=this.insert({tool:e,replace:o});try{window.requestIdleCallback((()=>{n.call(Ce.ON_PASTE,t)}))}catch(t){h(`${e}: onPaste callback call is failed`,"error",t)}return n}
/**
   * Insert new default block at passed index
   *
   * @param {number} index - index where Block should be inserted
   * @param {boolean} needToFocus - if true, updates current Block index
   *
   * TODO: Remove method and use insert() with index instead (?)
   * @returns {Block} inserted Block
   */insertDefaultBlockAtIndex(e,t=!1){const o=this.composeBlock({tool:this.config.defaultBlock});return this._blocks[e]=o,this.blockDidMutated(gr,o,{index:e}),t?this.currentBlockIndex=e:e<=this.currentBlockIndex&&this.currentBlockIndex++,o
/**
   * Always inserts at the end
   *
   * @returns {Block}
   */}insertAtEnd(){return this.currentBlockIndex=this.blocks.length-1,this.insert()
/**
   * Merge two blocks
   *
   * @param {Block} targetBlock - previous block will be append to this block
   * @param {Block} blockToMerge - block that will be merged with target block
   * @returns {Promise} - the sequence that can be continued
   */}async mergeBlocks(e,t){let o;if(e.name===t.name&&e.mergeable){const n=await t.data;if(x(n)){console.error("Could not merge Block. Failed to extract original Block data.");return}const[i]=Re([n],e.tool.sanitizeConfig);o=i}else if(e.mergeable&&ge(t,"export")&&ge(e,"import")){const n=await t.exportDataAsString(),i=De(n,e.tool.sanitizeConfig);o=ye(i,e.tool.conversionConfig)}o!==void 0&&(await e.mergeWith(o),this.removeBlock(t),this.currentBlockIndex=this._blocks.indexOf(e)
/**
   * Remove passed Block
   *
   * @param block - Block to remove
   * @param addLastBlock - if true, adds new default block at the end. @todo remove this logic and use event-bus instead
   */)}removeBlock(e,t=!0){return new Promise((o=>{const n=this._blocks.indexOf(e);if(!this.validateIndex(n))throw new Error("Can't find a Block to remove");this._blocks.remove(n),e.destroy(),this.blockDidMutated(fr,e,{index:n}),this.currentBlockIndex>=n&&this.currentBlockIndex--,this.blocks.length?n===0&&(this.currentBlockIndex=0):(this.unsetCurrentBlock(),t&&this.insert()),o()}))}
/**
   * Remove only selected Blocks
   * and returns first Block index where started removing...
   *
   * @returns {number|undefined}
   */removeSelectedBlocks(){let e;for(let t=this.blocks.length-1;t>=0;t--)this.blocks[t].selected&&(this.removeBlock(this.blocks[t]),e=t);return e}removeAllBlocks(){for(let e=this.blocks.length-1;e>=0;e--)this._blocks.remove(e);this.unsetCurrentBlock(),this.insert(),this.currentBlock.firstInput.focus()
/**
   * Split current Block
   * 1. Extract content from Caret position to the Block`s end
   * 2. Insert a new Block below current one with extracted content
   *
   * @returns {Block}
   */}split(){const e=this.Editor.Caret.extractFragmentFromCaretPosition(),t=u.make("div");t.appendChild(e);const o={text:u.isEmpty(t)?"":t.innerHTML};return this.insert({data:o})}
/**
   * Returns Block by passed index
   *
   * @param {number} index - index to get. -1 to get last
   * @returns {Block}
   */getBlockByIndex(e){return e===-1&&(e=this._blocks.length-1),this._blocks[e]
/**
   * Returns an index for passed Block
   *
   * @param block - block to find index
   */}getBlockIndex(e){return this._blocks.indexOf(e)}
/**
   * Returns the Block by passed id
   *
   * @param id - id of block to get
   * @returns {Block}
   */getBlockById(e){return this._blocks.array.find((t=>t.id===e))}
/**
   * Get Block instance by html element
   *
   * @param {Node} element - html element to get Block by
   */getBlock(e){u.isElement(e)||(e=e.parentNode);const t=this._blocks.nodes,o=e.closest(`.${R.CSS.wrapper}`),n=t.indexOf(o);if(n>=0)return this._blocks[n]}
/**
   * 1) Find first-level Block from passed child Node
   * 2) Mark it as current
   *
   * @param {Node} childNode - look ahead from this node.
   * @returns {Block | undefined} can return undefined in case when the passed child note is not a part of the current editor instance
   */setCurrentBlockByChildNode(e){u.isElement(e)||(e=e.parentNode);const t=e.closest(`.${R.CSS.wrapper}`);if(!t)return;const o=t.closest(`.${this.Editor.UI.CSS.editorWrapper}`);return o!=null&&o.isEqualNode(this.Editor.UI.nodes.wrapper)?(this.currentBlockIndex=this._blocks.nodes.indexOf(t),this.currentBlock.updateCurrentInput(),this.currentBlock
/**
   * Return block which contents passed node
   *
   * @param {Node} childNode - node to get Block by
   * @returns {Block}
   */):void 0}getBlockByChildNode(e){if(!e||!(e instanceof Node))return;u.isElement(e)||(e=e.parentNode);const t=e.closest(`.${R.CSS.wrapper}`);return this.blocks.find((e=>e.holder===t))}
/**
   * Swap Blocks Position
   *
   * @param {number} fromIndex - index of first block
   * @param {number} toIndex - index of second block
   * @deprecated — use 'move' instead
   */swap(e,t){this._blocks.swap(e,t),this.currentBlockIndex=t
/**
   * Move a block to a new index
   *
   * @param {number} toIndex - index where to move Block
   * @param {number} fromIndex - index of Block to move
   */}move(e,t=this.currentBlockIndex){isNaN(e)||isNaN(t)?h("Warning during 'move' call: incorrect indices provided.","warn"):this.validateIndex(e)&&this.validateIndex(t)?(this._blocks.move(e,t),this.currentBlockIndex=e,this.blockDidMutated(mr,this.currentBlock,{fromIndex:t,toIndex:e})
/**
   * Converts passed Block to the new Tool
   * Uses Conversion Config
   *
   * @param blockToConvert - Block that should be converted
   * @param targetToolName - name of the Tool to convert to
   * @param blockDataOverrides - optional new Block data overrides
   */):h("Warning during 'move' call: indices cannot be lower than 0 or greater than the amount of blocks.","warn")}async convert(e,t,o){if(!await e.save())throw new Error("Could not convert Block. Failed to extract original Block data.");const n=this.Editor.Tools.blockTools.get(t);if(!n)throw new Error(`Could not convert Block. Tool «${t}» not found.`);const i=await e.exportDataAsString(),r=De(i,n.sanitizeConfig);let a=ye(r,n.conversionConfig,n.settings);return o&&(a=Object.assign(a,o)),this.replace(e,n.name,a)}unsetCurrentBlock(){this.currentBlockIndex=-1}
/**
   * Clears Editor
   *
   * @param {boolean} needToAddDefaultBlock - 1) in internal calls (for example, in api.blocks.render)
   *                                             we don't need to add an empty default block
   *                                        2) in api.blocks.clear we should add empty block
   */async clear(e=!1){const t=new sa;[...this.blocks].forEach((e=>{t.add((async()=>{await this.removeBlock(e,!1)}))})),await t.completed,this.unsetCurrentBlock(),e&&this.insert(),this.Editor.UI.checkEmptiness()}async destroy(){await Promise.all(this.blocks.map((e=>e.destroy())))}
/**
   * Bind Block events
   *
   * @param {Block} block - Block to which event should be bound
   */bindBlockEvents(e){const{BlockEvents:t}=this.Editor;this.readOnlyMutableListeners.on(e.holder,"keydown",(e=>{t.keydown(e)})),this.readOnlyMutableListeners.on(e.holder,"keyup",(e=>{t.keyup(e)})),this.readOnlyMutableListeners.on(e.holder,"dragover",(e=>{t.dragOver(e)})),this.readOnlyMutableListeners.on(e.holder,"dragleave",(e=>{t.dragLeave(e)})),e.on("didMutated",(e=>this.blockDidMutated(br,e,{index:this.getBlockIndex(e)})))}disableModuleBindings(){this.readOnlyMutableListeners.clearAll()}enableModuleBindings(){this.readOnlyMutableListeners.on(document,"cut",(e=>this.Editor.BlockEvents.handleCommandX(e))),this.blocks.forEach((e=>{this.bindBlockEvents(e)}))
/**
   * Validates that the given index is not lower than 0 or higher than the amount of blocks
   *
   * @param {number} index - index of blocks array to validate
   * @returns {boolean}
   */}validateIndex(e){return!(e<0||e>=this._blocks.length)}
/**
   * Block mutation callback
   *
   * @param mutationType - what happened with block
   * @param block - mutated block
   * @param detailData - additional data to pass with change event
   */blockDidMutated(e,t,o){const n=new CustomEvent(e,{detail:{target:new ie(t),...o}});return this.eventsDispatcher.emit(le,{event:n}),t}}class aa extends E{constructor(){super(...arguments),this.anyBlockSelectedCache=null,this.needToSelectAll=!1,this.nativeInputSelected=!1,this.readyToBlockSelection=!1
/**
   * Sanitizer Config
   *
   * @returns {SanitizerConfig}
   */}get sanitizerConfig(){return{p:{},h1:{},h2:{},h3:{},h4:{},h5:{},h6:{},ol:{},ul:{},li:{},br:!0,img:{src:!0,width:!0,height:!0},a:{href:!0},b:{},i:{},u:{}}}
/**
   * Flag that identifies all Blocks selection
   *
   * @returns {boolean}
   */get allBlocksSelected(){const{BlockManager:e}=this.Editor;return e.blocks.every((e=>e.selected===!0))}
/**
   * Set selected all blocks
   *
   * @param {boolean} state - state to set
   */set allBlocksSelected(e){const{BlockManager:t}=this.Editor;t.blocks.forEach((t=>{t.selected=e})),this.clearCache()
/**
   * Flag that identifies any Block selection
   *
   * @returns {boolean}
   */}get anyBlockSelected(){const{BlockManager:e}=this.Editor;return this.anyBlockSelectedCache===null&&(this.anyBlockSelectedCache=e.blocks.some((e=>e.selected===!0))),this.anyBlockSelectedCache
/**
   * Return selected Blocks array
   *
   * @returns {Block[]}
   */}get selectedBlocks(){return this.Editor.BlockManager.blocks.filter((e=>e.selected))}prepare(){this.selection=new b,Jt.add({name:"CMD+A",handler:e=>{const{BlockManager:t,ReadOnly:o}=this.Editor;o.isEnabled?(e.preventDefault(),this.selectAllBlocks()):t.currentBlock&&this.handleCommandA(e)},on:this.Editor.UI.nodes.redactor})}toggleReadOnly(){b.get().removeAllRanges(),this.allBlocksSelected=!1
/**
   * Remove selection of Block
   *
   * @param {number?} index - Block index according to the BlockManager's indexes
   */}unSelectBlockByIndex(e){const{BlockManager:t}=this.Editor;let o;o=isNaN(e)?t.currentBlock:t.getBlockByIndex(e),o.selected=!1,this.clearCache()
/**
   * Clear selection from Blocks
   *
   * @param {Event} reason - event caused clear of selection
   * @param {boolean} restoreSelection - if true, restore saved selection
   */}clearSelection(e,t=!1){const{BlockManager:o,Caret:n,RectangleSelection:i}=this.Editor;this.needToSelectAll=!1,this.nativeInputSelected=!1,this.readyToBlockSelection=!1;const r=e&&e instanceof KeyboardEvent,a=r&&C(e.keyCode);if(this.anyBlockSelected&&r&&a&&!b.isSelectionExists){const t=o.removeSelectedBlocks();o.insertDefaultBlockAtIndex(t,!0),n.setToBlock(o.currentBlock),S((()=>{const t=e.key;n.insertContentAtCaretPosition(t.length>1?"":t)}),20)()}this.Editor.CrossBlockSelection.clear(e),this.anyBlockSelected&&!i.isRectActivated()?(t&&this.selection.restore(),this.allBlocksSelected=!1
/**
   * Reduce each Block and copy its content
   *
   * @param {ClipboardEvent} e - copy/cut event
   * @returns {Promise<void>}
   */):this.Editor.RectangleSelection.clearSelection()}copySelectedBlocks(e){e.preventDefault();const t=u.make("div");this.selectedBlocks.forEach((e=>{const o=De(e.holder.innerHTML,this.sanitizerConfig),n=u.make("p");n.innerHTML=o,t.appendChild(n)}));const o=Array.from(t.childNodes).map((e=>e.textContent)).join("\n\n"),n=t.innerHTML;return e.clipboardData.setData("text/plain",o),e.clipboardData.setData("text/html",n),Promise.all(this.selectedBlocks.map((e=>e.save()))).then((t=>{try{e.clipboardData.setData(this.Editor.Paste.MIME_TYPE,JSON.stringify(t))}catch{}}))
/**
   * Select Block by its index
   *
   * @param {number?} index - Block index according to the BlockManager's indexes
   */}selectBlockByIndex(e){const{BlockManager:t}=this.Editor,o=t.getBlockByIndex(e);o!==void 0&&this.selectBlock(o)}
/**
   * Select passed Block
   *
   * @param {Block} block - Block to select
   */selectBlock(e){this.selection.save(),b.get().removeAllRanges(),e.selected=!0,this.clearCache(),this.Editor.InlineToolbar.close()
/**
   * Remove selection from passed Block
   *
   * @param {Block} block - Block to unselect
   */}unselectBlock(e){e.selected=!1,this.clearCache()}clearCache(){this.anyBlockSelectedCache=null}destroy(){Jt.remove(this.Editor.UI.nodes.redactor,"CMD+A")}
/**
   * First CMD+A selects all input content by native behaviour,
   * next CMD+A keypress selects all blocks
   *
   * @param {KeyboardEvent} event - keyboard event
   */handleCommandA(e){if(this.Editor.RectangleSelection.clearSelection(),u.isNativeInput(e.target)&&!this.readyToBlockSelection){this.readyToBlockSelection=!0;return}const t=this.Editor.BlockManager.getBlock(e.target),o=t.inputs;o.length>1&&!this.readyToBlockSelection?this.readyToBlockSelection=!0:o.length!==1||this.needToSelectAll?this.needToSelectAll?(e.preventDefault(),this.selectAllBlocks(),this.needToSelectAll=!1,this.readyToBlockSelection=!1):this.readyToBlockSelection&&(e.preventDefault(),this.selectBlock(t),this.needToSelectAll=!0):this.needToSelectAll=!0}selectAllBlocks(){this.selection.save(),b.get().removeAllRanges(),this.allBlocksSelected=!0,this.Editor.InlineToolbar.close()}}class Ye extends E{
/**
   * Allowed caret positions in input
   *
   * @static
   * @returns {{START: string, END: string, DEFAULT: string}}
   */
get positions(){return{START:"start",END:"end",DEFAULT:"default"}}static get CSS(){return{shadowCaret:"cdx-shadow-caret"}}
/**
   * Method gets Block instance and puts caret to the text node with offset
   * There two ways that method applies caret position:
   *   - first found text node: sets at the beginning, but you can pass an offset
   *   - last found text node: sets at the end of the node. Also, you can customize the behaviour
   *
   * @param {Block} block - Block class
   * @param {string} position - position where to set caret.
   *                            If default - leave default behaviour and apply offset if it's passed
   * @param {number} offset - caret offset regarding to the block content
   */setToBlock(e,t=this.positions.DEFAULT,o=0){var n;const{BlockManager:i,BlockSelection:r}=this.Editor;if(r.clearSelection(),!e.focusable){(n=window.getSelection())==null||n.removeAllRanges(),r.selectBlock(e),i.currentBlock=e;return}let a;switch(t){case this.positions.START:a=e.firstInput;break;case this.positions.END:a=e.lastInput;break;default:a=e.currentInput}if(!a)return;let l,c=o;if(t===this.positions.START)l=u.getDeepestNode(a,!1),c=0;else if(t===this.positions.END)l=u.getDeepestNode(a,!0),c=u.getContentLength(l);else{const{node:e,offset:t}=u.getNodeByOffset(a,o);e?(l=e,c=t):(l=u.getDeepestNode(a,!1),c=0)}this.set(l,c),i.setCurrentBlockByChildNode(e.holder),i.currentBlock.currentInput=a
/**
   * Set caret to the current input of current Block.
   *
   * @param {HTMLElement} input - input where caret should be set
   * @param {string} position - position of the caret.
   *                            If default - leave default behaviour and apply offset if it's passed
   * @param {number} offset - caret offset regarding to the text node
   */}setToInput(e,t=this.positions.DEFAULT,o=0){const{currentBlock:n}=this.Editor.BlockManager,i=u.getDeepestNode(e);switch(t){case this.positions.START:this.set(i,0);break;case this.positions.END:this.set(i,u.getContentLength(i));break;default:o&&this.set(i,o)}n.currentInput=e}
/**
   * Creates Document Range and sets caret to the element with offset
   *
   * @param {HTMLElement} element - target node.
   * @param {number} offset - offset
   */set(e,t=0){const{top:o,bottom:n}=b.setCursor(e,t),{innerHeight:i}=window;o<0?window.scrollBy(0,o-30):n>i&&window.scrollBy(0,n-i+30)}setToTheLastBlock(){const e=this.Editor.BlockManager.lastBlock;if(e)if(e.tool.isDefault&&e.isEmpty)this.setToBlock(e);else{const e=this.Editor.BlockManager.insertAtEnd();this.setToBlock(e)}}extractFragmentFromCaretPosition(){const e=b.get();if(e.rangeCount){const t=e.getRangeAt(0),o=this.Editor.BlockManager.currentBlock.currentInput;if(t.deleteContents(),o){if(u.isNativeInput(o)){const e=o,t=document.createDocumentFragment(),n=e.value.substring(0,e.selectionStart),i=e.value.substring(e.selectionStart);return t.textContent=i,e.value=n,t}{const e=t.cloneRange();return e.selectNodeContents(o),e.setStart(t.endContainer,t.endOffset),e.extractContents()}}}}
/**
   * Set's caret to the next Block or Tool`s input
   * Before moving caret, we should check if caret position is at the end of Plugins node
   * Using {@link Dom#getDeepestNode} to get a last node and match with current selection
   *
   * @param {boolean} force - pass true to skip check for caret position
   */navigateNext(e=!1){const{BlockManager:t}=this.Editor,{currentBlock:o,nextBlock:n}=t;if(o===void 0)return!1;const{nextInput:i,currentInput:r}=o,a=r!==void 0?Eo(r):void 0;let l=n;const c=e||a||!o.focusable;if(i&&c)return this.setToInput(i,this.positions.START),!0;if(l===null){if(o.tool.isDefault||!c)return!1;l=t.insertAtEnd()}return!!c&&(this.setToBlock(l,this.positions.START),!0)}
/**
   * Set's caret to the previous Tool`s input or Block
   * Before moving caret, we should check if caret position is start of the Plugins node
   * Using {@link Dom#getDeepestNode} to get a last node and match with current selection
   *
   * @param {boolean} force - pass true to skip check for caret position
   */navigatePrevious(e=!1){const{currentBlock:t,previousBlock:o}=this.Editor.BlockManager;if(!t)return!1;const{previousInput:n,currentInput:i}=t,r=i!==void 0?xo(i):void 0,a=e||r||!t.focusable;return n&&a?(this.setToInput(n,this.positions.END),!0):!(o===null||!a)&&(this.setToBlock(o,this.positions.END),!0)}
/**
   * Inserts shadow element after passed element where caret can be placed
   *
   * @param {Element} element - element after which shadow caret should be inserted
   */createShadow(e){const t=document.createElement("span");t.classList.add(Ye.CSS.shadowCaret),e.insertAdjacentElement("beforeend",t)
/**
   * Restores caret position
   *
   * @param {HTMLElement} element - element where caret should be restored
   */}restoreCaret(e){const t=e.querySelector(`.${Ye.CSS.shadowCaret}`);if(!t)return;(new b).expandToTag(t);const o=document.createRange();o.selectNode(t),o.extractContents()
/**
   * Inserts passed content at caret position
   *
   * @param {string} content - content to insert
   */}insertContentAtCaretPosition(e){const t=document.createDocumentFragment(),o=document.createElement("div"),n=b.get(),i=b.range;o.innerHTML=e,Array.from(o.childNodes).forEach((e=>t.appendChild(e))),t.childNodes.length===0&&t.appendChild(new Text);const r=t.lastChild;i.deleteContents(),i.insertNode(t);const a=document.createRange(),l=r.nodeType===Node.TEXT_NODE?r:r.firstChild;l!==null&&l.textContent!==null&&a.setStart(l,l.textContent.length),n.removeAllRanges(),n.addRange(a)}}class la extends E{constructor(){super(...arguments),this.onMouseUp=()=>{this.listeners.off(document,"mouseover",this.onMouseOver),this.listeners.off(document,"mouseup",this.onMouseUp)},this.onMouseOver=e=>{const{BlockManager:t,BlockSelection:o}=this.Editor;if(e.relatedTarget===null&&e.target===null)return;const n=t.getBlockByChildNode(e.relatedTarget)||this.lastSelectedBlock,i=t.getBlockByChildNode(e.target);if(!(!n||!i)&&i!==n){if(n===this.firstSelectedBlock){b.get().removeAllRanges(),n.selected=!0,i.selected=!0,o.clearCache();return}if(i===this.firstSelectedBlock){n.selected=!1,i.selected=!1,o.clearCache();return}this.Editor.InlineToolbar.close(),this.toggleBlocksSelectedState(n,i),this.lastSelectedBlock=i}}
/**
   * Module preparation
   *
   * @returns {Promise}
   */}async prepare(){this.listeners.on(document,"mousedown",(e=>{this.enableCrossBlockSelection(e)}))}
/**
   * Sets up listeners
   *
   * @param {MouseEvent} event - mouse down event
   */watchSelection(e){if(e.button!==l.LEFT)return;const{BlockManager:t}=this.Editor;this.firstSelectedBlock=t.getBlock(e.target),this.lastSelectedBlock=this.firstSelectedBlock,this.listeners.on(document,"mouseover",this.onMouseOver),this.listeners.on(document,"mouseup",this.onMouseUp)}get isCrossBlockSelectionStarted(){return!!this.firstSelectedBlock&&!!this.lastSelectedBlock&&this.firstSelectedBlock!==this.lastSelectedBlock}
/**
   * Change selection state of the next Block
   * Used for CBS via Shift + arrow keys
   *
   * @param {boolean} next - if true, toggle next block. Previous otherwise
   */toggleBlockSelectedState(e=!0){const{BlockManager:t,BlockSelection:o}=this.Editor;this.lastSelectedBlock||(this.lastSelectedBlock=this.firstSelectedBlock=t.currentBlock),this.firstSelectedBlock===this.lastSelectedBlock&&(this.firstSelectedBlock.selected=!0,o.clearCache(),b.get().removeAllRanges());const n=t.blocks.indexOf(this.lastSelectedBlock)+(e?1:-1),i=t.blocks[n];i&&(this.lastSelectedBlock.selected!==i.selected?(i.selected=!0,o.clearCache()):(this.lastSelectedBlock.selected=!1,o.clearCache()),this.lastSelectedBlock=i,this.Editor.InlineToolbar.close(),i.holder.scrollIntoView({block:"nearest"})
/**
   * Clear saved state
   *
   * @param {Event} reason - event caused clear of selection
   */)}clear(e){const{BlockManager:t,BlockSelection:o,Caret:n}=this.Editor,i=t.blocks.indexOf(this.firstSelectedBlock),r=t.blocks.indexOf(this.lastSelectedBlock);if(o.anyBlockSelected&&i>-1&&r>-1&&e&&e instanceof KeyboardEvent)switch(e.keyCode){case a.DOWN:case a.RIGHT:n.setToBlock(t.blocks[Math.max(i,r)],n.positions.END);break;case a.UP:case a.LEFT:n.setToBlock(t.blocks[Math.min(i,r)],n.positions.START);break;default:n.setToBlock(t.blocks[Math.max(i,r)],n.positions.END)}this.firstSelectedBlock=this.lastSelectedBlock=null}
/**
   * Enables Cross Block Selection
   *
   * @param {MouseEvent} event - mouse down event
   */enableCrossBlockSelection(e){const{UI:t}=this.Editor;b.isCollapsed||this.Editor.BlockSelection.clearSelection(e),t.nodes.redactor.contains(e.target)?this.watchSelection(e):this.Editor.BlockSelection.clearSelection(e)
/**
   * Change blocks selection state between passed two blocks.
   *
   * @param {Block} firstBlock - first block in range
   * @param {Block} lastBlock - last block in range
   */}toggleBlocksSelectedState(e,t){const{BlockManager:o,BlockSelection:n}=this.Editor,i=o.blocks.indexOf(e),r=o.blocks.indexOf(t),a=e.selected!==t.selected;for(let l=Math.min(i,r);l<=Math.max(i,r);l++){const i=o.blocks[l];i!==this.firstSelectedBlock&&i!==(a?e:t)&&(o.blocks[l].selected=!o.blocks[l].selected,n.clearCache())}}}class ca extends E{constructor(){super(...arguments),this.isStartedAtEditor=!1
/**
   * Toggle read-only state
   *
   * if state is true:
   *  - disable all drag-n-drop event handlers
   *
   * if state is false:
   *  - restore drag-n-drop event handlers
   *
   * @param {boolean} readOnlyEnabled - "read only" state
   */}toggleReadOnly(e){e?this.disableModuleBindings():this.enableModuleBindings()}enableModuleBindings(){const{UI:e}=this.Editor;this.readOnlyMutableListeners.on(e.nodes.holder,"drop",(async e=>{await this.processDrop(e)}),!0),this.readOnlyMutableListeners.on(e.nodes.holder,"dragstart",(()=>{this.processDragStart()})),this.readOnlyMutableListeners.on(e.nodes.holder,"dragover",(e=>{this.processDragOver(e)}),!0)}disableModuleBindings(){this.readOnlyMutableListeners.clearAll()}
/**
   * Handle drop event
   *
   * @param {DragEvent} dropEvent - drop event
   */async processDrop(e){const{BlockManager:t,Paste:o,Caret:n}=this.Editor;e.preventDefault(),t.blocks.forEach((e=>{e.dropTarget=!1})),b.isAtEditor&&!b.isCollapsed&&this.isStartedAtEditor&&document.execCommand("delete"),this.isStartedAtEditor=!1;const i=t.setCurrentBlockByChildNode(e.target);if(i)this.Editor.Caret.setToBlock(i,n.positions.END);else{const e=t.setCurrentBlockByChildNode(t.lastBlock.holder);this.Editor.Caret.setToBlock(e,n.positions.END)}await o.processDataTransfer(e.dataTransfer,!0)}processDragStart(){b.isAtEditor&&!b.isCollapsed&&(this.isStartedAtEditor=!0),this.Editor.InlineToolbar.close()
/**
   * @param {DragEvent} dragEvent - drag event
   */}processDragOver(e){e.preventDefault()}}const vr=180,kr=400;class ha extends E{
/**
   * Prepare the module
   *
   * @param options - options used by the modification observer module
   * @param options.config - Editor configuration object
   * @param options.eventsDispatcher - common Editor event bus
   */
constructor({config:e,eventsDispatcher:t}){super({config:e,eventsDispatcher:t}),this.disabled=!1,this.batchingTimeout=null,this.batchingOnChangeQueue=new Map,this.batchTime=kr,this.mutationObserver=new MutationObserver((e=>{this.redactorChanged(e)})),this.eventsDispatcher.on(le,(e=>{this.particularBlockChanged(e.event)})),this.eventsDispatcher.on(de,(()=>{this.disable()})),this.eventsDispatcher.on(ue,(()=>{this.enable()}))}enable(){this.mutationObserver.observe(this.Editor.UI.nodes.redactor,{childList:!0,subtree:!0,characterData:!0,attributes:!0}),this.disabled=!1}disable(){this.mutationObserver.disconnect(),this.disabled=!0
/**
   * Call onChange event passed to Editor.js configuration
   *
   * @param event - some of our custom change events
   */}particularBlockChanged(e){this.disabled||!g(this.config.onChange)||(this.batchingOnChangeQueue.set(`block:${e.detail.target.id}:event:${e.type}`,e),this.batchingTimeout&&clearTimeout(this.batchingTimeout),this.batchingTimeout=setTimeout((()=>{let e;e=this.batchingOnChangeQueue.size===1?this.batchingOnChangeQueue.values().next().value:Array.from(this.batchingOnChangeQueue.values()),this.config.onChange&&this.config.onChange(this.Editor.API.methods,e),this.batchingOnChangeQueue.clear()}),this.batchTime)
/**
   * Fired on every blocks wrapper dom change
   *
   * @param mutations - mutations happened
   */)}redactorChanged(e){this.eventsDispatcher.emit(ae,{mutations:e})}}const yr=class Dn extends E{constructor(){super(...arguments),this.MIME_TYPE="application/x-editor-js",this.toolsTags={},this.tagsByTool={},this.toolsPatterns=[],this.toolsFiles={},this.exceptionList=[],this.processTool=e=>{try{const t=e.create({},{},!1);if(e.pasteConfig===!1){this.exceptionList.push(e.name);return}if(!g(t.onPaste))return;this.getTagsConfig(e),this.getFilesConfig(e),this.getPatternsConfig(e)}catch(t){h(`Paste handling for «${e.name}» Tool hasn't been set up because of the error`,"warn",t)}},this.handlePasteEvent=async e=>{const{BlockManager:t,Toolbar:o}=this.Editor,n=t.setCurrentBlockByChildNode(e.target);!n||this.isNativeBehaviour(e.target)&&!e.clipboardData.types.includes("Files")||n&&this.exceptionList.includes(n.name)||(e.preventDefault(),this.processDataTransfer(e.clipboardData),o.close())}}async prepare(){this.processTools()}
/**
   * Set read-only state
   *
   * @param {boolean} readOnlyEnabled - read only flag value
   */toggleReadOnly(e){e?this.unsetCallback():this.setCallback()}
/**
   * Handle pasted or dropped data transfer object
   *
   * @param {DataTransfer} dataTransfer - pasted or dropped data transfer object
   * @param {boolean} isDragNDrop - true if data transfer comes from drag'n'drop events
   */async processDataTransfer(e,t=!1){const{Tools:o}=this.Editor,n=e.types;if((n.includes?n.includes("Files"):n.contains("Files"))&&!x(this.toolsFiles)){await this.processFiles(e.files);return}const i=e.getData(this.MIME_TYPE),r=e.getData("text/plain");let a=e.getData("text/html");if(i)try{this.insertEditorJSData(JSON.parse(i));return}catch{}t&&r.trim()&&a.trim()&&(a="<p>"+(a.trim()?a:r)+"</p>");const l=Object.keys(this.toolsTags).reduce(((e,t)=>(e[t.toLowerCase()]=this.toolsTags[t].sanitizationConfig??{},e)),{}),c=Object.assign({},l,o.getAllInlineToolsSanitizeConfig(),{br:{}}),d=De(a,c);d.trim()&&d.trim()!==r&&u.isHTMLString(d)?await this.processText(d,!0):await this.processText(r)}
/**
   * Process pasted text and divide them into Blocks
   *
   * @param {string} data - text to process. Can be HTML or plain.
   * @param {boolean} isHTML - if passed string is HTML, this parameter should be true
   */async processText(e,t=!1){const{Caret:o,BlockManager:n}=this.Editor,i=t?this.processHTML(e):this.processPlain(e);if(!i.length)return;if(i.length===1){i[0].isBlock?this.processSingleBlock(i.pop()):this.processInlinePaste(i.pop());return}const r=n.currentBlock&&n.currentBlock.tool.isDefault&&n.currentBlock.isEmpty;i.map((async(e,t)=>this.insertBlock(e,t===0&&r))),n.currentBlock&&o.setToBlock(n.currentBlock,o.positions.END)}setCallback(){this.listeners.on(this.Editor.UI.nodes.holder,"paste",this.handlePasteEvent)}unsetCallback(){this.listeners.off(this.Editor.UI.nodes.holder,"paste",this.handlePasteEvent)}processTools(){const e=this.Editor.Tools.blockTools;Array.from(e.values()).forEach(this.processTool)}
/**
   * Get tags name list from either tag name or sanitization config.
   *
   * @param {string | object} tagOrSanitizeConfig - tag name or sanitize config object.
   * @returns {string[]} array of tags.
   */collectTagNames(e){return v(e)?[e]:m(e)?Object.keys(e):[]}
/**
   * Get tags to substitute by Tool
   *
   * @param tool - BlockTool object
   */getTagsConfig(e){if(e.pasteConfig===!1)return;const t=e.pasteConfig.tags||[],o=[];t.forEach((t=>{const n=this.collectTagNames(t);o.push(...n),n.forEach((o=>{if(Object.prototype.hasOwnProperty.call(this.toolsTags,o)){h(`Paste handler for «${e.name}» Tool on «${o}» tag is skipped because it is already used by «${this.toolsTags[o].tool.name}» Tool.`,"warn");return}const n=m(t)?t[o]:null;this.toolsTags[o.toUpperCase()]={tool:e,sanitizationConfig:n}}))})),this.tagsByTool[e.name]=o.map((e=>e.toUpperCase()))
/**
   * Get files` types and extensions to substitute by Tool
   *
   * @param tool - BlockTool object
   */}getFilesConfig(e){if(e.pasteConfig===!1)return;const{files:t={}}=e.pasteConfig;let{extensions:o,mimeTypes:n}=t;!o&&!n||(o&&!Array.isArray(o)&&(h(`«extensions» property of the onDrop config for «${e.name}» Tool should be an array`),o=[]),n&&!Array.isArray(n)&&(h(`«mimeTypes» property of the onDrop config for «${e.name}» Tool should be an array`),n=[]),n&&(n=n.filter((t=>!!O(t)||(h(`MIME type value «${t}» for the «${e.name}» Tool is not a valid MIME type`,"warn"),!1)))),this.toolsFiles[e.name]={extensions:o||[],mimeTypes:n||[]}
/**
   * Get RegExp patterns to substitute by Tool
   *
   * @param tool - BlockTool object
   */)}getPatternsConfig(e){e.pasteConfig===!1||!e.pasteConfig.patterns||x(e.pasteConfig.patterns)||Object.entries(e.pasteConfig.patterns).forEach((([t,o])=>{o instanceof RegExp||h(`Pattern ${o} for «${e.name}» Tool is skipped because it should be a Regexp instance.`,"warn"),this.toolsPatterns.push({key:t,pattern:o,tool:e})}))}
/**
   * Check if browser behavior suits better
   *
   * @param {EventTarget} element - element where content has been pasted
   * @returns {boolean}
   */isNativeBehaviour(e){return u.isNativeInput(e)}
/**
   * Get files from data transfer object and insert related Tools
   *
   * @param {FileList} items - pasted or dropped items
   */async processFiles(e){const{BlockManager:t}=this.Editor;let o;o=await Promise.all(Array.from(e).map((e=>this.processFile(e)))),o=o.filter((e=>!!e));const n=t.currentBlock.tool.isDefault&&t.currentBlock.isEmpty;o.forEach(((e,o)=>{t.paste(e.type,e.event,o===0&&n)}))}
/**
   * Get information about file and find Tool to handle it
   *
   * @param {File} file - file to process
   */async processFile(e){const t=I(e),o=Object.entries(this.toolsFiles).find((([o,{mimeTypes:n,extensions:i}])=>{const[r,a]=e.type.split("/"),l=i.find((e=>e.toLowerCase()===t.toLowerCase())),c=n.find((e=>{const[t,o]=e.split("/");return t===r&&(o===a||o==="*")}));return!!l||!!c}));if(!o)return;const[n]=o;return{event:this.composePasteEvent("file",{file:e}),type:n}}
/**
   * Split HTML string to blocks and return it as array of Block data
   *
   * @param {string} innerHTML - html string to process
   * @returns {PasteData[]}
   */processHTML(e){const{Tools:t}=this.Editor,o=u.make("DIV");return o.innerHTML=e,this.getNodes(o).map((e=>{let o,n=t.defaultTool,i=!1;switch(e.nodeType){case Node.DOCUMENT_FRAGMENT_NODE:o=u.make("div"),o.appendChild(e);break;case Node.ELEMENT_NODE:o=e,i=!0,this.toolsTags[o.tagName]&&(n=this.toolsTags[o.tagName].tool);break}const{tags:r}=n.pasteConfig||{tags:[]},a=r.reduce(((e,t)=>(this.collectTagNames(t).forEach((o=>{const n=m(t)?t[o]:null;e[o.toLowerCase()]=n||{}})),e)),{}),l=Object.assign({},a,n.baseSanitizeConfig);if(o.tagName.toLowerCase()==="table"){const e=De(o.outerHTML,l);o=u.make("div",void 0,{innerHTML:e}).firstChild}else o.innerHTML=De(o.innerHTML,l);const c=this.composePasteEvent("tag",{data:o});return{content:o,isBlock:i,tool:n.name,event:c}})).filter((e=>{const t=u.isEmpty(e.content),o=u.isSingleTag(e.content);return!t||o}))
/**
   * Split plain text by new line symbols and return it as array of Block data
   *
   * @param {string} plain - string to process
   * @returns {PasteData[]}
   */}processPlain(e){const{defaultBlock:t}=this.config;if(!e)return[];const o=t;return e.split(/\r?\n/).filter((e=>e.trim())).map((e=>{const t=u.make("div");t.textContent=e;const n=this.composePasteEvent("tag",{data:t});return{content:t,tool:o,isBlock:!1,event:n}}))}
/**
   * Process paste of single Block tool content
   *
   * @param {PasteData} dataToInsert - data of Block to insert
   */async processSingleBlock(e){const{Caret:t,BlockManager:o}=this.Editor,{currentBlock:n}=o;n&&e.tool===n.name&&u.containsOnlyInlineElements(e.content.innerHTML)?t.insertContentAtCaretPosition(e.content.innerHTML):this.insertBlock(e,(n==null?void 0:n.tool.isDefault)&&n.isEmpty)}
/**
   * Process paste to single Block:
   * 1. Find patterns` matches
   * 2. Insert new block if it is not the same type as current one
   * 3. Just insert text if there is no substitutions
   *
   * @param {PasteData} dataToInsert - data of Block to insert
   */async processInlinePaste(e){const{BlockManager:t,Caret:o}=this.Editor,{content:n}=e;if(t.currentBlock&&t.currentBlock.tool.isDefault&&n.textContent.length<Dn.PATTERN_PROCESSING_MAX_LENGTH){const e=await this.processPattern(n.textContent);if(e){const n=t.currentBlock&&t.currentBlock.tool.isDefault&&t.currentBlock.isEmpty,i=t.paste(e.tool,e.event,n);o.setToBlock(i,o.positions.END);return}}if(t.currentBlock&&t.currentBlock.currentInput){const e=t.currentBlock.tool.baseSanitizeConfig;document.execCommand("insertHTML",!1,De(n.innerHTML,e))}else this.insertBlock(e)}
/**
   * Get patterns` matches
   *
   * @param {string} text - text to process
   * @returns {Promise<{event: PasteEvent, tool: string}>}
   */async processPattern(e){const t=this.toolsPatterns.find((t=>{const o=t.pattern.exec(e);return!!o&&e===o.shift()}));return t?{event:this.composePasteEvent("pattern",{key:t.key,data:e}),tool:t.tool.name}:void 0}
/**
   * Insert pasted Block content to Editor
   *
   * @param {PasteData} data - data to insert
   * @param {boolean} canReplaceCurrentBlock - if true and is current Block is empty, will replace current Block
   * @returns {void}
   */insertBlock(e,t=!1){const{BlockManager:o,Caret:n}=this.Editor,{currentBlock:i}=o;let r;t&&i&&i.isEmpty?(r=o.paste(e.tool,e.event,!0),n.setToBlock(r,n.positions.END)):(r=o.paste(e.tool,e.event),n.setToBlock(r,n.positions.END)
/**
   * Insert data passed as application/x-editor-js JSON
   *
   * @param {Array} blocks — Blocks' data to insert
   * @returns {void}
   */)}insertEditorJSData(e){const{BlockManager:t,Caret:o,Tools:n}=this.Editor;Re(e,(e=>n.blockTools.get(e).sanitizeConfig)).forEach((({tool:e,data:n},i)=>{let r=!1;i===0&&(r=t.currentBlock&&t.currentBlock.tool.isDefault&&t.currentBlock.isEmpty);const a=t.insert({tool:e,data:n,replace:r});o.setToBlock(a,o.positions.END)}))}
/**
   * Fetch nodes from Element node
   *
   * @param {Node} node - current node
   * @param {Node[]} nodes - processed nodes
   * @param {Node} destNode - destination node
   */processElementNode(e,t,o){const n=Object.keys(this.toolsTags),i=e,{tool:r}=this.toolsTags[i.tagName]||{},a=this.tagsByTool[r==null?void 0:r.name]||[],l=n.includes(i.tagName),c=u.blockElements.includes(i.tagName.toLowerCase()),d=Array.from(i.children).some((({tagName:e})=>n.includes(e)&&!a.includes(e))),h=Array.from(i.children).some((({tagName:e})=>u.blockElements.includes(e.toLowerCase())));return c||l||d?l&&!d||c&&!h&&!d?[...t,o,i]:void 0:(o.appendChild(i),[...t,o])}
/**
   * Recursively divide HTML string to two types of nodes:
   * 1. Block element
   * 2. Document Fragments contained text and markup tags like a, b, i etc.
   *
   * @param {Node} wrapper - wrapper of paster HTML content
   * @returns {Node[]}
   */getNodes(e){const t=Array.from(e.childNodes);let o;const n=(e,t)=>{if(u.isEmpty(t)&&!u.isSingleTag(t))return e;const i=e[e.length-1];let r=new DocumentFragment;switch(i&&u.isFragment(i)&&(r=e.pop()),t.nodeType){case Node.ELEMENT_NODE:if(o=this.processElementNode(t,e,r),o)return o;break;case Node.TEXT_NODE:return r.appendChild(t),[...e,r];default:return[...e,r]}return[...e,...Array.from(t.childNodes).reduce(n,[])]};return t.reduce(n,[])}
/**
   * Compose paste event with passed type and detail
   *
   * @param {string} type - event type
   * @param {PasteEventDetail} detail - event detail
   */composePasteEvent(e,t){return new CustomEvent(e,{detail:t})}};yr.PATTERN_PROCESSING_MAX_LENGTH=450;let wr=yr;class fa extends E{constructor(){super(...arguments),this.toolsDontSupportReadOnly=[],this.readOnlyEnabled=!1}get isEnabled(){return this.readOnlyEnabled}async prepare(){const{Tools:e}=this.Editor,{blockTools:t}=e,o=[];Array.from(t.entries()).forEach((([e,t])=>{t.isReadOnlySupported||o.push(e)})),this.toolsDontSupportReadOnly=o,this.config.readOnly&&o.length>0&&this.throwCriticalError(),this.toggle(this.config.readOnly,!0)
/**
   * Set read-only mode or toggle current state
   * Call all Modules `toggleReadOnly` method and re-render Editor
   *
   * @param state - (optional) read-only state or toggle
   * @param isInitial - (optional) true when editor is initializing
   */}async toggle(e=!this.readOnlyEnabled,t=!1){e&&this.toolsDontSupportReadOnly.length>0&&this.throwCriticalError();const o=this.readOnlyEnabled;this.readOnlyEnabled=e;for(const t in this.Editor)this.Editor[t].toggleReadOnly&&this.Editor[t].toggleReadOnly(e);if(o===e)return this.readOnlyEnabled;if(t)return this.readOnlyEnabled;this.Editor.ModificationsObserver.disable();const n=await this.Editor.Saver.save();return await this.Editor.BlockManager.clear(),await this.Editor.Renderer.render(n.blocks),this.Editor.ModificationsObserver.enable(),this.readOnlyEnabled}throwCriticalError(){throw new Ho(`To enable read-only mode all connected tools should support it. Tools ${this.toolsDontSupportReadOnly.join(", ")} don't support read-only mode.`)}}class Be extends E{constructor(){super(...arguments),this.isRectSelectionActivated=!1,this.SCROLL_SPEED=3,this.HEIGHT_OF_SCROLL_ZONE=40,this.BOTTOM_SCROLL_ZONE=1,this.TOP_SCROLL_ZONE=2,this.MAIN_MOUSE_BUTTON=0,this.mousedown=!1,this.isScrolling=!1,this.inScrollZone=null,this.startX=0,this.startY=0,this.mouseX=0,this.mouseY=0,this.stackOfSelected=[],this.listenerIds=[]
/**
   * CSS classes for the Block
   *
   * @returns {{wrapper: string, content: string}}
   */}static get CSS(){return{overlay:"codex-editor-overlay",overlayContainer:"codex-editor-overlay__container",rect:"codex-editor-overlay__rectangle",topScrollZone:"codex-editor-overlay__scroll-zone--top",bottomScrollZone:"codex-editor-overlay__scroll-zone--bottom"}}prepare(){this.enableModuleBindings()}
/**
   * Init rect params
   *
   * @param {number} pageX - X coord of mouse
   * @param {number} pageY - Y coord of mouse
   */startSelection(e,t){const o=document.elementFromPoint(e-window.pageXOffset,t-window.pageYOffset);o.closest(`.${this.Editor.Toolbar.CSS.toolbar}`)||(this.Editor.BlockSelection.allBlocksSelected=!1,this.clearSelection(),this.stackOfSelected=[]);const n=[`.${R.CSS.content}`,`.${this.Editor.Toolbar.CSS.toolbar}`,`.${this.Editor.InlineToolbar.CSS.inlineToolbar}`],i=o.closest("."+this.Editor.UI.CSS.editorWrapper),r=n.some((e=>!!o.closest(e)));!i||r||(this.mousedown=!0,this.startX=e,this.startY=t)}endSelection(){this.mousedown=!1,this.startX=0,this.startY=0,this.overlayRectangle.style.display="none"}isRectActivated(){return this.isRectSelectionActivated}clearSelection(){this.isRectSelectionActivated=!1}enableModuleBindings(){const{container:e}=this.genHTML();this.listeners.on(e,"mousedown",(e=>{this.processMouseDown(e)}),!1),this.listeners.on(document.body,"mousemove",M((e=>{this.processMouseMove(e)}),10),{passive:!0}),this.listeners.on(document.body,"mouseleave",(()=>{this.processMouseLeave()})),this.listeners.on(window,"scroll",M((e=>{this.processScroll(e)}),10),{passive:!0}),this.listeners.on(document.body,"mouseup",(()=>{this.processMouseUp()}),!1)
/**
   * Handle mouse down events
   *
   * @param {MouseEvent} mouseEvent - mouse event payload
   */}processMouseDown(e){e.button===this.MAIN_MOUSE_BUTTON&&(e.target.closest(u.allInputsSelector)!==null||this.startSelection(e.pageX,e.pageY))}
/**
   * Handle mouse move events
   *
   * @param {MouseEvent} mouseEvent - mouse event payload
   */processMouseMove(e){this.changingRectangle(e),this.scrollByZones(e.clientY)}processMouseLeave(){this.clearSelection(),this.endSelection()
/**
   * @param {MouseEvent} mouseEvent - mouse event payload
   */}processScroll(e){this.changingRectangle(e)}processMouseUp(){this.clearSelection(),this.endSelection()
/**
   * Scroll If mouse in scroll zone
   *
   * @param {number} clientY - Y coord of mouse
   */}scrollByZones(e){this.inScrollZone=null,e<=this.HEIGHT_OF_SCROLL_ZONE&&(this.inScrollZone=this.TOP_SCROLL_ZONE),document.documentElement.clientHeight-e<=this.HEIGHT_OF_SCROLL_ZONE&&(this.inScrollZone=this.BOTTOM_SCROLL_ZONE),this.inScrollZone?this.isScrolling||(this.scrollVertical(this.inScrollZone===this.TOP_SCROLL_ZONE?-this.SCROLL_SPEED:this.SCROLL_SPEED),this.isScrolling=!0
/**
   * Generates required HTML elements
   *
   * @returns {Object<string, Element>}
   */):this.isScrolling=!1}genHTML(){const{UI:e}=this.Editor,t=e.nodes.holder.querySelector("."+e.CSS.editorWrapper),o=u.make("div",Be.CSS.overlay,{}),n=u.make("div",Be.CSS.overlayContainer,{}),i=u.make("div",Be.CSS.rect,{});return n.appendChild(i),o.appendChild(n),t.appendChild(o),this.overlayRectangle=i,{container:t,overlay:o}
/**
   * Activates scrolling if blockSelection is active and mouse is in scroll zone
   *
   * @param {number} speed - speed of scrolling
   */}scrollVertical(e){if(!(this.inScrollZone&&this.mousedown))return;const t=window.pageYOffset;window.scrollBy(0,e),this.mouseY+=window.pageYOffset-t,setTimeout((()=>{this.scrollVertical(e)}),0)
/**
   * Handles the change in the rectangle and its effect
   *
   * @param {MouseEvent} event - mouse event
   */}changingRectangle(e){if(!this.mousedown)return;e.pageY!==void 0&&(this.mouseX=e.pageX,this.mouseY=e.pageY);const{rightPos:t,leftPos:o,index:n}=this.genInfoForMouseSelection(),i=this.startX>t&&this.mouseX>t,r=this.startX<o&&this.mouseX<o;this.rectCrossesBlocks=!(i||r),this.isRectSelectionActivated||(this.rectCrossesBlocks=!1,this.isRectSelectionActivated=!0,this.shrinkRectangleToPoint(),this.overlayRectangle.style.display="block"),this.updateRectangleSize(),this.Editor.Toolbar.close(),n!==void 0&&(this.trySelectNextBlock(n),this.inverseSelection(),b.get().removeAllRanges())}shrinkRectangleToPoint(){this.overlayRectangle.style.left=this.startX-window.pageXOffset+"px",this.overlayRectangle.style.top=this.startY-window.pageYOffset+"px",this.overlayRectangle.style.bottom=`calc(100% - ${this.startY-window.pageYOffset}px`,this.overlayRectangle.style.right=`calc(100% - ${this.startX-window.pageXOffset}px`}inverseSelection(){const e=this.Editor.BlockManager.getBlockByIndex(this.stackOfSelected[0]).selected;if(this.rectCrossesBlocks&&!e)for(const e of this.stackOfSelected)this.Editor.BlockSelection.selectBlockByIndex(e);if(!this.rectCrossesBlocks&&e)for(const e of this.stackOfSelected)this.Editor.BlockSelection.unSelectBlockByIndex(e)}updateRectangleSize(){this.mouseY>=this.startY?(this.overlayRectangle.style.top=this.startY-window.pageYOffset+"px",this.overlayRectangle.style.bottom=`calc(100% - ${this.mouseY-window.pageYOffset}px`):(this.overlayRectangle.style.bottom=`calc(100% - ${this.startY-window.pageYOffset}px`,this.overlayRectangle.style.top=this.mouseY-window.pageYOffset+"px"),this.mouseX>=this.startX?(this.overlayRectangle.style.left=this.startX-window.pageXOffset+"px",this.overlayRectangle.style.right=`calc(100% - ${this.mouseX-window.pageXOffset}px`):(this.overlayRectangle.style.right=`calc(100% - ${this.startX-window.pageXOffset}px`,this.overlayRectangle.style.left=this.mouseX-window.pageXOffset+"px"
/**
   * Collects information needed to determine the behavior of the rectangle
   *
   * @returns {object} index - index next Block, leftPos - start of left border of Block, rightPos - right border
   */)}genInfoForMouseSelection(){const e=document.body.offsetWidth/2,t=this.mouseY-window.pageYOffset,o=document.elementFromPoint(e,t),n=this.Editor.BlockManager.getBlockByChildNode(o);let i;n!==void 0&&(i=this.Editor.BlockManager.blocks.findIndex((e=>e.holder===n.holder)));const r=this.Editor.BlockManager.lastBlock.holder.querySelector("."+R.CSS.content),a=Number.parseInt(window.getComputedStyle(r).width,10)/2,l=e-a,c=e+a;return{index:i,leftPos:l,rightPos:c}}
/**
   * Select block with index index
   *
   * @param index - index of block in redactor
   */addBlockInSelection(e){this.rectCrossesBlocks&&this.Editor.BlockSelection.selectBlockByIndex(e),this.stackOfSelected.push(e)
/**
   * Adds a block to the selection and determines which blocks should be selected
   *
   * @param {object} index - index of new block in the reactor
   */}trySelectNextBlock(e){const t=this.stackOfSelected[this.stackOfSelected.length-1]===e,o=this.stackOfSelected.length,n=1,i=-1,r=0;if(t)return;const a=this.stackOfSelected[o-1]-this.stackOfSelected[o-2]>0;let l=r;o>1&&(l=a?n:i);const c=e>this.stackOfSelected[o-1]&&l===n,d=e<this.stackOfSelected[o-1]&&l===i,h=!(c||d||l===r);if(!h&&(e>this.stackOfSelected[o-1]||this.stackOfSelected[o-1]===void 0)){let t=this.stackOfSelected[o-1]+1||e;for(t;t<=e;t++)this.addBlockInSelection(t);return}if(!h&&e<this.stackOfSelected[o-1]){for(let t=this.stackOfSelected[o-1]-1;t>=e;t--)this.addBlockInSelection(t);return}if(!h)return;let p,f=o-1;for(p=e>this.stackOfSelected[o-1]?()=>e>this.stackOfSelected[f]:()=>e<this.stackOfSelected[f];p();)this.rectCrossesBlocks&&this.Editor.BlockSelection.unSelectBlockByIndex(this.stackOfSelected[f]),this.stackOfSelected.pop(),f--}}class ga extends E{
/**
   * Renders passed blocks as one batch
   *
   * @param blocksData - blocks to render
   */
async render(e){return new Promise((t=>{const{Tools:o,BlockManager:n}=this.Editor;if(e.length===0)n.insert();else{const t=e.map((({type:e,data:t,tunes:i,id:r})=>{o.available.has(e)===!1&&(p(`Tool «${e}» is not found. Check 'tools' property at the Editor.js config.`,"warn"),t=this.composeStubDataForTool(e,t,r),e=o.stubTool);let a;try{a=n.composeBlock({id:r,tool:e,data:t,tunes:i})}catch(l){h(`Block «${e}» skipped because of plugins error`,"error",{data:t,error:l}),t=this.composeStubDataForTool(e,t,r),e=o.stubTool,a=n.composeBlock({id:r,tool:e,data:t,tunes:i})}return a}));n.insertMany(t)}window.requestIdleCallback((()=>{t()}),{timeout:2e3})}))}
/**
   * Create data for the Stub Tool that will be used instead of unavailable tool
   *
   * @param tool - unavailable tool name to stub
   * @param data - data of unavailable block
   * @param [id] - id of unavailable block
   */composeStubDataForTool(e,t,o){const{Tools:n}=this.Editor;let i=e;if(n.unavailable.has(e)){const t=n.unavailable.get(e).toolbox;t!==void 0&&t[0].title!==void 0&&(i=t[0].title)}return{savedData:{id:o,type:e,data:t},title:i}}}class ma extends E{
/**
   * Composes new chain of Promises to fire them alternatelly
   *
   * @returns {OutputData}
   */
async save(){const{BlockManager:e,Tools:t}=this.Editor,o=e.blocks,n=[];try{o.forEach((e=>{n.push(this.getSavedData(e))}));const e=await Promise.all(n),i=await Re(e,(e=>t.blockTools.get(e).sanitizeConfig));return this.makeOutput(i)}catch(e){p("Saving failed due to the Error %o","error",e)}}
/**
   * Saves and validates
   *
   * @param {Block} block - Editor's Tool
   * @returns {ValidatedData} - Tool's validated data
   */async getSavedData(e){const t=await e.save(),o=t&&await e.validate(t.data);return{...t,isValid:o}}
/**
   * Creates output object with saved data, time and version of editor
   *
   * @param {ValidatedData} allExtractedData - data extracted from Blocks
   * @returns {OutputData}
   */makeOutput(e){const t=[];return e.forEach((({id:e,tool:o,data:n,tunes:i,isValid:r})=>{if(!r){h(`Block «${o}» skipped because saved data is invalid`);return}if(o===this.Editor.Tools.stubTool){t.push(n);return}const a={id:e,type:o,data:n,...!x(i)&&{tunes:i}};t.push(a)})),{time:+new Date,blocks:t,version:"2.31.0"}}}(function(){try{if(typeof document<"u"){var e=document.createElement("style");e.appendChild(document.createTextNode(".ce-paragraph{line-height:1.6em;outline:none}.ce-block:only-of-type .ce-paragraph[data-placeholder-active]:empty:before,.ce-block:only-of-type .ce-paragraph[data-placeholder-active][data-empty=true]:before{content:attr(data-placeholder-active)}.ce-paragraph p:first-of-type{margin-top:0}.ce-paragraph p:last-of-type{margin-bottom:0}")),document.head.appendChild(e)}}catch(e){console.error("vite-plugin-css-injected-by-js",e)}})();const xr='<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" fill="none" viewBox="0 0 24 24"><path stroke="currentColor" stroke-linecap="round" stroke-width="2" d="M8 9V7.2C8 7.08954 8.08954 7 8.2 7L12 7M16 9V7.2C16 7.08954 15.9105 7 15.8 7L12 7M12 7L12 17M12 17H10M12 17H14"/></svg>';function Er(e){const t=document.createElement("div");t.innerHTML=e.trim();const o=document.createDocumentFragment();return o.append(...Array.from(t.childNodes)),o
/**
 * Base Paragraph Block for the Editor.js.
 * Represents a regular text block
 *
 * @author CodeX (team@codex.so)
 * @copyright CodeX 2018
 * @license The MIT License (MIT)
 */}class fo{
/**
   * Default placeholder for Paragraph Tool
   *
   * @returns {string}
   * @class
   */
static get DEFAULT_PLACEHOLDER(){return""}
/**
   * Render plugin`s main Element and fill it with saved data
   *
   * @param {object} params - constructor params
   * @param {ParagraphData} params.data - previously saved data
   * @param {ParagraphConfig} params.config - user config for Tool
   * @param {object} params.api - editor.js api
   * @param {boolean} readOnly - read only mode flag
   */constructor({data:e,config:t,api:o,readOnly:n}){this.api=o,this.readOnly=n,this._CSS={block:this.api.styles.block,wrapper:"ce-paragraph"},this.readOnly||(this.onKeyUp=this.onKeyUp.bind(this)),this._placeholder=t.placeholder?t.placeholder:fo.DEFAULT_PLACEHOLDER,this._data=e??{},this._element=null,this._preserveBlank=t.preserveBlank??!1
/**
   * Check if text content is empty and set empty string to inner html.
   * We need this because some browsers (e.g. Safari) insert <br> into empty contenteditanle elements
   *
   * @param {KeyboardEvent} e - key up event
   */}onKeyUp(e){if(e.code!=="Backspace"&&e.code!=="Delete"||!this._element)return;const{textContent:t}=this._element;t===""&&(this._element.innerHTML="")}
/**
   * Create Tool's view
   *
   * @returns {HTMLDivElement}
   * @private
   */drawView(){const e=document.createElement("DIV");return e.classList.add(this._CSS.wrapper,this._CSS.block),e.contentEditable="false",e.dataset.placeholderActive=this.api.i18n.t(this._placeholder),this._data.text&&(e.innerHTML=this._data.text),this.readOnly||(e.contentEditable="true",e.addEventListener("keyup",this.onKeyUp)),e
/**
   * Return Tool's view
   *
   * @returns {HTMLDivElement}
   */}render(){return this._element=this.drawView(),this._element
/**
   * Method that specified how to merge two Text blocks.
   * Called by Editor.js by backspace at the beginning of the Block
   *
   * @param {ParagraphData} data
   * @public
   */}merge(e){if(!this._element)return;this._data.text+=e.text;const t=Er(e.text);this._element.appendChild(t),this._element.normalize()
/**
   * Validate Paragraph block data:
   * - check for emptiness
   *
   * @param {ParagraphData} savedData — data received after saving
   * @returns {boolean} false if saved data is not correct, otherwise true
   * @public
   */}validate(e){return!(e.text.trim()===""&&!this._preserveBlank)}
/**
   * Extract Tool's data from the view
   *
   * @param {HTMLDivElement} toolsContent - Paragraph tools rendered view
   * @returns {ParagraphData} - saved data
   * @public
   */save(e){return{text:e.innerHTML}}
/**
   * On paste callback fired from Editor.
   *
   * @param {HTMLPasteEvent} event - event with pasted data
   */onPaste(e){const t={text:e.detail.data.innerHTML};this._data=t,window.requestAnimationFrame((()=>{this._element&&(this._element.innerHTML=this._data.text||"")}))
/**
   * Enable Conversion Toolbar. Paragraph can be converted to/from other tools
   * @returns {ConversionConfig}
   */}static get conversionConfig(){return{export:"text",import:"text"}}
/**
   * Sanitizer rules
   * @returns {SanitizerConfig} - Edtior.js sanitizer config
   */static get sanitize(){return{text:{br:!0}}}
/**
   * Returns true to notify the core that read-only mode is supported
   *
   * @returns {boolean}
   */static get isReadOnlySupported(){return!0}
/**
   * Used by Editor paste handling API.
   * Provides configuration to handle P tags.
   *
   * @returns {PasteConfig} - Paragraph Paste Setting
   */static get pasteConfig(){return{tags:["P"]}}
/**
   * Icon and title for displaying at the Toolbox
   *
   * @returns {ToolboxConfig} - Paragraph Toolbox Setting
   */static get toolbox(){return{icon:xr,title:"Text"}}}class go{constructor(){this.commandName="bold"}
/**
   * Sanitizer Rule
   * Leave <b> tags
   *
   * @returns {object}
   */static get sanitize(){return{b:{}}}render(){return{icon:it,name:"bold",onActivate:()=>{document.execCommand(this.commandName)},isActive:()=>document.queryCommandState(this.commandName)}}
/**
   * Set a shortcut
   *
   * @returns {boolean}
   */get shortcut(){return"CMD+B"}}go.isInline=!0;go.title="Bold";class mo{constructor(){this.commandName="italic",this.CSS={button:"ce-inline-tool",buttonActive:"ce-inline-tool--active",buttonModifier:"ce-inline-tool--italic"},this.nodes={button:null}
/**
   * Sanitizer Rule
   * Leave <i> tags
   *
   * @returns {object}
   */}static get sanitize(){return{i:{}}}render(){return this.nodes.button=document.createElement("button"),this.nodes.button.type="button",this.nodes.button.classList.add(this.CSS.button,this.CSS.buttonModifier),this.nodes.button.innerHTML=ut,this.nodes.button}surround(){document.execCommand(this.commandName)}checkState(){const e=document.queryCommandState(this.commandName);return this.nodes.button.classList.toggle(this.CSS.buttonActive,e),e}get shortcut(){return"CMD+I"}}mo.isInline=!0;mo.title="Italic";class bo{
/**
   * @param api - Editor.js API
   */
constructor({api:e}){this.commandLink="createLink",this.commandUnlink="unlink",this.ENTER_KEY=13,this.CSS={button:"ce-inline-tool",buttonActive:"ce-inline-tool--active",buttonModifier:"ce-inline-tool--link",buttonUnlink:"ce-inline-tool--unlink",input:"ce-inline-tool-input",inputShowed:"ce-inline-tool-input--showed"},this.nodes={button:null,input:null},this.inputOpened=!1,this.toolbar=e.toolbar,this.inlineToolbar=e.inlineToolbar,this.notifier=e.notifier,this.i18n=e.i18n,this.selection=new b
/**
   * Sanitizer Rule
   * Leave <a> tags
   *
   * @returns {object}
   */}static get sanitize(){return{a:{href:!0,target:"_blank",rel:"nofollow"}}}render(){return this.nodes.button=document.createElement("button"),this.nodes.button.type="button",this.nodes.button.classList.add(this.CSS.button,this.CSS.buttonModifier),this.nodes.button.innerHTML=pt,this.nodes.button}renderActions(){return this.nodes.input=document.createElement("input"),this.nodes.input.placeholder=this.i18n.t("Add a link"),this.nodes.input.enterKeyHint="done",this.nodes.input.classList.add(this.CSS.input),this.nodes.input.addEventListener("keydown",(e=>{e.keyCode===this.ENTER_KEY&&this.enterPressed(e)})),this.nodes.input
/**
   * Handle clicks on the Inline Toolbar icon
   *
   * @param {Range} range - range to wrap with link
   */}surround(e){if(e){this.inputOpened?(this.selection.restore(),this.selection.removeFakeBackground()):(this.selection.setFakeBackground(),this.selection.save());const e=this.selection.findParentTag("A");if(e){this.selection.expandToTag(e),this.unlink(),this.closeActions(),this.checkState(),this.toolbar.close();return}}this.toggleActions()}checkState(){const e=this.selection.findParentTag("A");if(e){this.nodes.button.innerHTML=vt,this.nodes.button.classList.add(this.CSS.buttonUnlink),this.nodes.button.classList.add(this.CSS.buttonActive),this.openActions();const t=e.getAttribute("href");this.nodes.input.value=t!=="null"?t:"",this.selection.save()}else this.nodes.button.innerHTML=pt,this.nodes.button.classList.remove(this.CSS.buttonUnlink),this.nodes.button.classList.remove(this.CSS.buttonActive);return!!e}clear(){this.closeActions()}get shortcut(){return"CMD+K"}toggleActions(){this.inputOpened?this.closeActions(!1):this.openActions(!0)}
/**
   * @param {boolean} needFocus - on link creation we need to focus input. On editing - nope.
   */openActions(e=!1){this.nodes.input.classList.add(this.CSS.inputShowed),e&&this.nodes.input.focus(),this.inputOpened=!0
/**
   * Close input
   *
   * @param {boolean} clearSavedSelection — we don't need to clear saved selection
   *                                        on toggle-clicks on the icon of opened Toolbar
   */}closeActions(e=!0){if(this.selection.isFakeBackgroundEnabled){const e=new b;e.save(),this.selection.restore(),this.selection.removeFakeBackground(),e.restore()}this.nodes.input.classList.remove(this.CSS.inputShowed),this.nodes.input.value="",e&&this.selection.clearSaved(),this.inputOpened=!1
/**
   * Enter pressed on input
   *
   * @param {KeyboardEvent} event - enter keydown event
   */}enterPressed(e){let t=this.nodes.input.value||"";t.trim()?this.validateURL(t)?(t=this.prepareLink(t),this.selection.restore(),this.selection.removeFakeBackground(),this.insertLink(t),e.preventDefault(),e.stopPropagation(),e.stopImmediatePropagation(),this.selection.collapseToEnd(),this.inlineToolbar.close()
/**
   * Detects if passed string is URL
   *
   * @param {string} str - string to validate
   * @returns {boolean}
   */):(this.notifier.show({message:"Pasted link is not valid.",style:"error"}),h("Incorrect Link pasted","warn",t)):(this.selection.restore(),this.unlink(),e.preventDefault(),this.closeActions())}validateURL(e){return!/\s/.test(e)}
/**
   * Process link before injection
   * - sanitize
   * - add protocol for links like 'google.com'
   *
   * @param {string} link - raw user input
   */prepareLink(e){return e=e.trim(),e=this.addProtocol(e),e
/**
   * Add 'http' protocol to the links like 'vc.ru', 'google.com'
   *
   * @param {string} link - string to process
   */}addProtocol(e){if(/^(\w+):(\/\/)?/.test(e))return e;const t=/^\/[^/\s]/.test(e),o=e.substring(0,1)==="#",n=/^\/\/[^/\s]/.test(e);return!t&&!o&&!n&&(e="http://"+e),e
/**
   * Inserts <a> tag with "href"
   *
   * @param {string} link - "href" value
   */}insertLink(e){const t=this.selection.findParentTag("A");t&&this.selection.expandToTag(t),document.execCommand(this.commandLink,!1,e)}unlink(){document.execCommand(this.commandUnlink)}}bo.isInline=!0;bo.title="Link";class Fn{
/**
   * @param api - Editor.js API
   */
constructor({api:e}){this.i18nAPI=e.i18n,this.blocksAPI=e.blocks,this.selectionAPI=e.selection,this.toolsAPI=e.tools,this.caretAPI=e.caret}async render(){const e=b.get(),t=this.blocksAPI.getBlockByElement(e.anchorNode);if(t===void 0)return[];const o=this.toolsAPI.getBlockTools(),n=await be(t,o);if(n.length===0)return[];const i=n.reduce(((e,o)=>{var n;return(n=o.toolbox)==null||n.forEach((n=>{e.push({icon:n.icon,title:ne.t(et.toolNames,n.title),name:o.name,closeOnActivate:!0,onActivate:async()=>{const e=await this.blocksAPI.convert(t.id,o.name,n.data);this.caretAPI.setToBlock(e,"end")}})})),e}),[]),r=await t.getActiveToolboxEntry(),a=r!==void 0?r.icon:mt,l=!Y();return{icon:a,name:"convert-to",hint:{title:this.i18nAPI.t("Convert to")},children:{searchable:l,items:i,onOpen:()=>{l&&(this.selectionAPI.setFakeBackground(),this.selectionAPI.save())},onClose:()=>{l&&(this.selectionAPI.restore(),this.selectionAPI.removeFakeBackground())}}}}}Fn.isInline=!0;class jn{
/**
   * @param options - constructor options
   * @param options.data - stub tool data
   * @param options.api - Editor.js API
   */
constructor({data:e,api:t}){this.CSS={wrapper:"ce-stub",info:"ce-stub__info",title:"ce-stub__title",subtitle:"ce-stub__subtitle"},this.api=t,this.title=e.title||this.api.i18n.t("Error"),this.subtitle=this.api.i18n.t("The block can not be displayed correctly."),this.savedData=e.savedData,this.wrapper=this.make()
/**
   * Returns stub holder
   *
   * @returns {HTMLElement}
   */}render(){return this.wrapper}
/**
   * Return original Tool data
   *
   * @returns {BlockToolData}
   */save(){return this.savedData}
/**
   * Create Tool html markup
   *
   * @returns {HTMLElement}
   */make(){const e=u.make("div",this.CSS.wrapper),t=yt,o=u.make("div",this.CSS.info),n=u.make("div",this.CSS.title,{textContent:this.title}),i=u.make("div",this.CSS.subtitle,{textContent:this.subtitle});return e.innerHTML=t,o.appendChild(n),o.appendChild(i),e.appendChild(o),e}}jn.isReadOnlySupported=!0;class ka extends Tt{constructor(){super(...arguments),this.type=lo.Inline}get title(){return this.constructable[po.Title]}create(){return new this.constructable({api:this.api,config:this.settings})}get isReadOnlySupported(){return this.constructable[po.IsReadOnlySupported]??!1}}class ya extends Tt{constructor(){super(...arguments),this.type=lo.Tune
/**
   * Constructs new BlockTune instance from constructable
   *
   * @param data - Tune data
   * @param block - Block API object
   */}create(e,t){return new this.constructable({api:this.api,config:this.settings,block:t,data:e})}}class j extends Map{get blockTools(){const e=Array.from(this.entries()).filter((([,e])=>e.isBlock()));return new j(e)}get inlineTools(){const e=Array.from(this.entries()).filter((([,e])=>e.isInline()));return new j(e)}get blockTunes(){const e=Array.from(this.entries()).filter((([,e])=>e.isTune()));return new j(e)}get internalTools(){const e=Array.from(this.entries()).filter((([,e])=>e.isInternal));return new j(e)}get externalTools(){const e=Array.from(this.entries()).filter((([,e])=>!e.isInternal));return new j(e)}}var Cr=Object.defineProperty,Br=Object.getOwnPropertyDescriptor,Tr=(e,t,o,n)=>{for(var i,r=n>1?void 0:n?Br(t,o):t,a=e.length-1;a>=0;a--)(i=e[a])&&(r=(n?i(t,o,r):i(r))||r);return n&&r&&Cr(t,o,r),r};class vo extends Tt{constructor(){super(...arguments),this.type=lo.Block,this.inlineTools=new j,this.tunes=new j
/**
   * Creates new Tool instance
   *
   * @param data - Tool data
   * @param block - BlockAPI for current Block
   * @param readOnly - True if Editor is in read-only mode
   */}create(e,t,o){return new this.constructable({data:e,block:t,readOnly:o,api:this.api,config:this.settings})}get isReadOnlySupported(){return this.constructable[uo.IsReadOnlySupported]===!0}get isLineBreaksEnabled(){return this.constructable[uo.IsEnabledLineBreaks]}get toolbox(){const e=this.constructable[uo.Toolbox],t=this.config[co.Toolbox];if(!x(e)&&t!==!1)return t?Array.isArray(e)?Array.isArray(t)?t.map(((t,o)=>{const n=e[o];return n?{...n,...t}:t})):[t]:Array.isArray(t)?t:[{...e,...t}]:Array.isArray(e)?e:[e]}get conversionConfig(){return this.constructable[uo.ConversionConfig]}get enabledInlineTools(){return this.config[co.EnabledInlineTools]||!1}get enabledBlockTunes(){return this.config[co.EnabledBlockTunes]}get pasteConfig(){return this.constructable[uo.PasteConfig]??{}}get sanitizeConfig(){const e=super.sanitizeConfig,t=this.baseSanitizeConfig;if(x(e))return t;const o={};for(const n in e)if(Object.prototype.hasOwnProperty.call(e,n)){const i=e[n];m(i)?o[n]=Object.assign({},t,i):o[n]=i}return o}get baseSanitizeConfig(){const e={};return Array.from(this.inlineTools.values()).forEach((t=>Object.assign(e,t.sanitizeConfig))),Array.from(this.tunes.values()).forEach((t=>Object.assign(e,t.sanitizeConfig))),e}}Tr([$],vo.prototype,"sanitizeConfig",1);Tr([$],vo.prototype,"baseSanitizeConfig",1);class xa{
/**
   * @class
   * @param config - tools config
   * @param editorConfig - EditorJS config
   * @param api - EditorJS API module
   */
constructor(e,t,o){this.api=o,this.config=e,this.editorConfig=t
/**
   * Returns Tool object based on it's type
   *
   * @param name - tool name
   */}get(e){const{class:t,isInternal:o=!1,...n}=this.config[e],i=this.getConstructor(t),r=t[ko.IsTune];return new i({name:e,constructable:t,config:n,api:this.api.getMethodsForTool(e,r),isDefault:e===this.editorConfig.defaultBlock,defaultPlaceholder:this.editorConfig.placeholder,isInternal:o})}
/**
   * Find appropriate Tool object constructor for Tool constructable
   *
   * @param constructable - Tools constructable
   */getConstructor(e){switch(!0){case e[po.IsInline]:return ka;case e[ko.IsTune]:return ya;default:return vo}}}class $n{
/**
   * MoveDownTune constructor
   *
   * @param {API} api — Editor's API
   */
constructor({api:e}){this.CSS={animation:"wobble"},this.api=e}render(){return{icon:st,title:this.api.i18n.t("Move down"),onActivate:()=>this.handleClick(),name:"move-down"}}handleClick(){const e=this.api.blocks.getCurrentBlockIndex(),t=this.api.blocks.getBlockByIndex(e+1);if(!t)throw new Error("Unable to move Block down since it is already the last");const o=t.holder,n=o.getBoundingClientRect();let i=Math.abs(window.innerHeight-o.offsetHeight);n.top<window.innerHeight&&(i=window.scrollY+o.offsetHeight),window.scrollTo(0,i),this.api.blocks.move(e+1),this.api.toolbar.toggleBlockSettings(!0)}}$n.isTune=!0;class zn{
/**
   * DeleteTune constructor
   *
   * @param {API} api - Editor's API
   */
constructor({api:e}){this.api=e}render(){return{icon:dt,title:this.api.i18n.t("Delete"),name:"delete",confirmation:{title:this.api.i18n.t("Click to delete"),onActivate:()=>this.handleClick()}}}handleClick(){this.api.blocks.delete()}}zn.isTune=!0;class Un{
/**
   * MoveUpTune constructor
   *
   * @param {API} api - Editor's API
   */
constructor({api:e}){this.CSS={animation:"wobble"},this.api=e}render(){return{icon:lt,title:this.api.i18n.t("Move up"),onActivate:()=>this.handleClick(),name:"move-up"}}handleClick(){const e=this.api.blocks.getCurrentBlockIndex(),t=this.api.blocks.getBlockByIndex(e),o=this.api.blocks.getBlockByIndex(e-1);if(e===0||!t||!o)throw new Error("Unable to move Block up since it is already the first");const n=t.holder,i=o.holder,r=n.getBoundingClientRect(),a=i.getBoundingClientRect();let l;l=a.top>0?Math.abs(r.top)-Math.abs(a.top):Math.abs(r.top)+a.height,window.scrollBy(0,-1*l),this.api.blocks.move(e-1),this.api.toolbar.toggleBlockSettings(!0)}}Un.isTune=!0;var Sr=Object.defineProperty,Ir=Object.getOwnPropertyDescriptor,Or=(e,t,o,n)=>{for(var i,r=n>1?void 0:n?Ir(t,o):t,a=e.length-1;a>=0;a--)(i=e[a])&&(r=(n?i(t,o,r):i(r))||r);return n&&r&&Sr(t,o,r),r};class Wn extends E{constructor(){super(...arguments),this.stubTool="stub",this.toolsAvailable=new j,this.toolsUnavailable=new j}get available(){return this.toolsAvailable}get unavailable(){return this.toolsUnavailable}get inlineTools(){return this.available.inlineTools}get blockTools(){return this.available.blockTools}
/**
   * Return available Block Tunes
   *
   * @returns {object} - object of Inline Tool's classes
   */get blockTunes(){return this.available.blockTunes}get defaultTool(){return this.blockTools.get(this.config.defaultBlock)}get internal(){return this.available.internalTools}
/**
   * Creates instances via passed or default configuration
   *
   * @returns {Promise<void>}
   */async prepare(){if(this.validateTools(),this.config.tools=P({},this.internalTools,this.config.tools),!Object.prototype.hasOwnProperty.call(this.config,"tools")||Object.keys(this.config.tools).length===0)throw Error("Can't start without tools");const e=this.prepareConfig();this.factory=new xa(e,this.config,this.Editor.API);const t=this.getListOfPrepareFunctions(e);if(t.length===0)return Promise.resolve();await B(t,(e=>{this.toolPrepareMethodSuccess(e)}),(e=>{this.toolPrepareMethodFallback(e)})),this.prepareBlockTools()}getAllInlineToolsSanitizeConfig(){const e={};return Array.from(this.inlineTools.values()).forEach((t=>{Object.assign(e,t.sanitizeConfig)})),e}destroy(){Object.values(this.available).forEach((async e=>{g(e.reset)&&await e.reset()}))}get internalTools(){return{convertTo:{class:Fn,isInternal:!0},link:{class:bo,isInternal:!0},bold:{class:go,isInternal:!0},italic:{class:mo,isInternal:!0},paragraph:{class:fo,inlineToolbar:!0,isInternal:!0},stub:{class:jn,isInternal:!0},moveUp:{class:Un,isInternal:!0},delete:{class:zn,isInternal:!0},moveDown:{class:$n,isInternal:!0}}}
/**
   * Tool prepare method success callback
   *
   * @param {object} data - append tool to available list
   */toolPrepareMethodSuccess(e){const t=this.factory.get(e.toolName);if(t.isInline()){const e=["render"].filter((e=>!t.create()[e]));if(e.length){h(`Incorrect Inline Tool: ${t.name}. Some of required methods is not implemented %o`,"warn",e),this.toolsUnavailable.set(t.name,t);return}}this.toolsAvailable.set(t.name,t)}
/**
   * Tool prepare method fail callback
   *
   * @param {object} data - append tool to unavailable list
   */toolPrepareMethodFallback(e){this.toolsUnavailable.set(e.toolName,this.factory.get(e.toolName))}
/**
   * Binds prepare function of plugins with user or default config
   *
   * @returns {Array} list of functions that needs to be fired sequentially
   * @param config - tools config
   */getListOfPrepareFunctions(e){const t=[];return Object.entries(e).forEach((([e,o])=>{t.push({function:g(o.class.prepare)?o.class.prepare:()=>{},data:{toolName:e,config:o.config}})})),t}prepareBlockTools(){Array.from(this.blockTools.values()).forEach((e=>{this.assignInlineToolsToBlockTool(e),this.assignBlockTunesToBlockTool(e)}))}
/**
   * Assign enabled Inline Tools for Block Tool
   *
   * @param tool - Block Tool
   */assignInlineToolsToBlockTool(e){if(this.config.inlineToolbar!==!1){if(e.enabledInlineTools===!0){e.inlineTools=new j(Array.isArray(this.config.inlineToolbar)?this.config.inlineToolbar.map((e=>[e,this.inlineTools.get(e)])):Array.from(this.inlineTools.entries()));return}Array.isArray(e.enabledInlineTools)&&(e.inlineTools=new j(["convertTo",...e.enabledInlineTools].map((e=>[e,this.inlineTools.get(e)]))))}}
/**
   * Assign enabled Block Tunes for Block Tool
   *
   * @param tool — Block Tool
   */assignBlockTunesToBlockTool(e){if(e.enabledBlockTunes!==!1){if(Array.isArray(e.enabledBlockTunes)){const t=new j(e.enabledBlockTunes.map((e=>[e,this.blockTunes.get(e)])));e.tunes=new j([...t,...this.blockTunes.internalTools]);return}if(Array.isArray(this.config.tunes)){const t=new j(this.config.tunes.map((e=>[e,this.blockTunes.get(e)])));e.tunes=new j([...t,...this.blockTunes.internalTools]);return}e.tunes=this.blockTunes.internalTools}}validateTools(){for(const e in this.config.tools)if(Object.prototype.hasOwnProperty.call(this.config.tools,e)){if(e in this.internalTools)return;const t=this.config.tools[e];if(!g(t)&&!g(t.class))throw Error(`Tool «${e}» must be a constructor function or an object with function in the «class» property`)}}prepareConfig(){const e={};for(const t in this.config.tools)m(this.config.tools[t])?e[t]=this.config.tools[t]:e[t]={class:this.config.tools[t]};return e}}Or([$],Wn.prototype,"getAllInlineToolsSanitizeConfig",1);const _r=':root{--selectionColor: #e1f2ff;--inlineSelectionColor: #d4ecff;--bg-light: #eff2f5;--grayText: #707684;--color-dark: #1D202B;--color-active-icon: #388AE5;--color-gray-border: rgba(201, 201, 204, .48);--content-width: 650px;--narrow-mode-right-padding: 50px;--toolbox-buttons-size: 26px;--toolbox-buttons-size--mobile: 36px;--icon-size: 20px;--icon-size--mobile: 28px;--block-padding-vertical: .4em;--color-line-gray: #EFF0F1 }.codex-editor{position:relative;-webkit-box-sizing:border-box;box-sizing:border-box;z-index:1}.codex-editor .hide{display:none}.codex-editor__redactor [contenteditable]:empty:after{content:"\\feff"}@media (min-width: 651px){.codex-editor--narrow .codex-editor__redactor{margin-right:50px}}@media (min-width: 651px){.codex-editor--narrow.codex-editor--rtl .codex-editor__redactor{margin-left:50px;margin-right:0}}@media (min-width: 651px){.codex-editor--narrow .ce-toolbar__actions{right:-5px}}.codex-editor-copyable{position:absolute;height:1px;width:1px;top:-400%;opacity:.001}.codex-editor-overlay{position:fixed;top:0;left:0;right:0;bottom:0;z-index:999;pointer-events:none;overflow:hidden}.codex-editor-overlay__container{position:relative;pointer-events:auto;z-index:0}.codex-editor-overlay__rectangle{position:absolute;pointer-events:none;background-color:#2eaadc33;border:1px solid transparent}.codex-editor svg{max-height:100%}.codex-editor path{stroke:currentColor}.codex-editor ::-moz-selection{background-color:#d4ecff}.codex-editor ::selection{background-color:#d4ecff}.codex-editor--toolbox-opened [contentEditable=true][data-placeholder]:focus:before{opacity:0!important}.ce-scroll-locked{overflow:hidden}.ce-scroll-locked--hard{overflow:hidden;top:calc(-1 * var(--window-scroll-offset));position:fixed;width:100%}.ce-toolbar{position:absolute;left:0;right:0;top:0;-webkit-transition:opacity .1s ease;transition:opacity .1s ease;will-change:opacity,top;display:none}.ce-toolbar--opened{display:block}.ce-toolbar__content{max-width:650px;margin:0 auto;position:relative}.ce-toolbar__plus{color:#1d202b;cursor:pointer;width:26px;height:26px;border-radius:7px;display:-webkit-inline-box;display:-ms-inline-flexbox;display:inline-flex;-webkit-box-pack:center;-ms-flex-pack:center;justify-content:center;-webkit-box-align:center;-ms-flex-align:center;align-items:center;-webkit-user-select:none;-moz-user-select:none;-ms-user-select:none;user-select:none;-ms-flex-negative:0;flex-shrink:0}@media (max-width: 650px){.ce-toolbar__plus{width:36px;height:36px}}@media (hover: hover){.ce-toolbar__plus:hover{background-color:#eff2f5}}.ce-toolbar__plus--active{background-color:#eff2f5;-webkit-animation:bounceIn .75s 1;animation:bounceIn .75s 1;-webkit-animation-fill-mode:forwards;animation-fill-mode:forwards}.ce-toolbar__plus-shortcut{opacity:.6;word-spacing:-2px;margin-top:5px}@media (max-width: 650px){.ce-toolbar__plus{position:absolute;background-color:#fff;border:1px solid #E8E8EB;-webkit-box-shadow:0 3px 15px -3px rgba(13,20,33,.13);box-shadow:0 3px 15px -3px #0d142121;border-radius:6px;z-index:2;position:static}.ce-toolbar__plus--left-oriented:before{left:15px;margin-left:0}.ce-toolbar__plus--right-oriented:before{left:auto;right:15px;margin-left:0}}.ce-toolbar__actions{position:absolute;right:100%;opacity:0;display:-webkit-box;display:-ms-flexbox;display:flex;padding-right:5px}.ce-toolbar__actions--opened{opacity:1}@media (max-width: 650px){.ce-toolbar__actions{right:auto}}.ce-toolbar__settings-btn{color:#1d202b;width:26px;height:26px;border-radius:7px;display:-webkit-inline-box;display:-ms-inline-flexbox;display:inline-flex;-webkit-box-pack:center;-ms-flex-pack:center;justify-content:center;-webkit-box-align:center;-ms-flex-align:center;align-items:center;-webkit-user-select:none;-moz-user-select:none;-ms-user-select:none;margin-left:3px;cursor:pointer;user-select:none}@media (max-width: 650px){.ce-toolbar__settings-btn{width:36px;height:36px}}@media (hover: hover){.ce-toolbar__settings-btn:hover{background-color:#eff2f5}}.ce-toolbar__settings-btn--active{background-color:#eff2f5;-webkit-animation:bounceIn .75s 1;animation:bounceIn .75s 1;-webkit-animation-fill-mode:forwards;animation-fill-mode:forwards}@media (min-width: 651px){.ce-toolbar__settings-btn{width:24px}}.ce-toolbar__settings-btn--hidden{display:none}@media (max-width: 650px){.ce-toolbar__settings-btn{position:absolute;background-color:#fff;border:1px solid #E8E8EB;-webkit-box-shadow:0 3px 15px -3px rgba(13,20,33,.13);box-shadow:0 3px 15px -3px #0d142121;border-radius:6px;z-index:2;position:static}.ce-toolbar__settings-btn--left-oriented:before{left:15px;margin-left:0}.ce-toolbar__settings-btn--right-oriented:before{left:auto;right:15px;margin-left:0}}.ce-toolbar__plus svg,.ce-toolbar__settings-btn svg{width:24px;height:24px}@media (min-width: 651px){.codex-editor--narrow .ce-toolbar__plus{left:5px}}@media (min-width: 651px){.codex-editor--narrow .ce-toolbox .ce-popover{right:0;left:auto;left:initial}}.ce-inline-toolbar{--y-offset: 8px;--color-background-icon-active: rgba(56, 138, 229, .1);--color-text-icon-active: #388AE5;--color-text-primary: black;position:absolute;visibility:hidden;-webkit-transition:opacity .25s ease;transition:opacity .25s ease;will-change:opacity,left,top;top:0;left:0;z-index:3;opacity:1;visibility:visible}.ce-inline-toolbar [hidden]{display:none!important}.ce-inline-toolbar__toggler-and-button-wrapper{display:-webkit-box;display:-ms-flexbox;display:flex;width:100%;padding:0 6px}.ce-inline-toolbar__buttons{display:-webkit-box;display:-ms-flexbox;display:flex}.ce-inline-toolbar__dropdown{display:-webkit-box;display:-ms-flexbox;display:flex;padding:6px;margin:0 6px 0 -6px;-webkit-box-align:center;-ms-flex-align:center;align-items:center;cursor:pointer;border-right:1px solid rgba(201,201,204,.48);-webkit-box-sizing:border-box;box-sizing:border-box}@media (hover: hover){.ce-inline-toolbar__dropdown:hover{background:#eff2f5}}.ce-inline-toolbar__dropdown--hidden{display:none}.ce-inline-toolbar__dropdown-content,.ce-inline-toolbar__dropdown-arrow{display:-webkit-box;display:-ms-flexbox;display:flex}.ce-inline-toolbar__dropdown-content svg,.ce-inline-toolbar__dropdown-arrow svg{width:20px;height:20px}.ce-inline-toolbar__shortcut{opacity:.6;word-spacing:-3px;margin-top:3px}.ce-inline-tool{color:var(--color-text-primary);display:-webkit-box;display:-ms-flexbox;display:flex;-webkit-box-pack:center;-ms-flex-pack:center;justify-content:center;-webkit-box-align:center;-ms-flex-align:center;align-items:center;border:0;border-radius:4px;line-height:normal;height:100%;padding:0;width:28px;background-color:transparent;cursor:pointer}@media (max-width: 650px){.ce-inline-tool{width:36px;height:36px}}@media (hover: hover){.ce-inline-tool:hover{background-color:#f8f8f8}}.ce-inline-tool svg{display:block;width:20px;height:20px}@media (max-width: 650px){.ce-inline-tool svg{width:28px;height:28px}}.ce-inline-tool--link .icon--unlink,.ce-inline-tool--unlink .icon--link{display:none}.ce-inline-tool--unlink .icon--unlink{display:inline-block;margin-bottom:-1px}.ce-inline-tool-input{background:#F8F8F8;border:1px solid rgba(226,226,229,.2);border-radius:6px;padding:4px 8px;font-size:14px;line-height:22px;outline:none;margin:0;width:100%;-webkit-box-sizing:border-box;box-sizing:border-box;display:none;font-weight:500;-webkit-appearance:none;font-family:inherit}@media (max-width: 650px){.ce-inline-tool-input{font-size:15px;font-weight:500}}.ce-inline-tool-input::-webkit-input-placeholder{color:#707684}.ce-inline-tool-input::-moz-placeholder{color:#707684}.ce-inline-tool-input:-ms-input-placeholder{color:#707684}.ce-inline-tool-input::-ms-input-placeholder{color:#707684}.ce-inline-tool-input::placeholder{color:#707684}.ce-inline-tool-input--showed{display:block}.ce-inline-tool--active{background:var(--color-background-icon-active);color:var(--color-text-icon-active)}@-webkit-keyframes fade-in{0%{opacity:0}to{opacity:1}}@keyframes fade-in{0%{opacity:0}to{opacity:1}}.ce-block{-webkit-animation:fade-in .3s ease;animation:fade-in .3s ease;-webkit-animation-fill-mode:none;animation-fill-mode:none;-webkit-animation-fill-mode:initial;animation-fill-mode:initial}.ce-block:first-of-type{margin-top:0}.ce-block--selected .ce-block__content{background:#e1f2ff}.ce-block--selected .ce-block__content [contenteditable]{-webkit-user-select:none;-moz-user-select:none;-ms-user-select:none;user-select:none}.ce-block--selected .ce-block__content img,.ce-block--selected .ce-block__content .ce-stub{opacity:.55}.ce-block--stretched .ce-block__content{max-width:none}.ce-block__content{position:relative;max-width:650px;margin:0 auto;-webkit-transition:background-color .15s ease;transition:background-color .15s ease}.ce-block--drop-target .ce-block__content:before{content:"";position:absolute;top:100%;left:-20px;margin-top:-1px;height:8px;width:8px;border:solid #388AE5;border-width:1px 1px 0 0;-webkit-transform-origin:right;transform-origin:right;-webkit-transform:rotate(45deg);transform:rotate(45deg)}.ce-block--drop-target .ce-block__content:after{content:"";position:absolute;top:100%;height:1px;width:100%;color:#388ae5;background:repeating-linear-gradient(90deg,#388AE5,#388AE5 1px,#fff 1px,#fff 6px)}.ce-block a{cursor:pointer;-webkit-text-decoration:underline;text-decoration:underline}.ce-block b{font-weight:700}.ce-block i{font-style:italic}@-webkit-keyframes bounceIn{0%,20%,40%,60%,80%,to{-webkit-animation-timing-function:cubic-bezier(.215,.61,.355,1);animation-timing-function:cubic-bezier(.215,.61,.355,1)}0%{-webkit-transform:scale3d(.9,.9,.9);transform:scale3d(.9,.9,.9)}20%{-webkit-transform:scale3d(1.03,1.03,1.03);transform:scale3d(1.03,1.03,1.03)}60%{-webkit-transform:scale3d(1,1,1);transform:scaleZ(1)}}@keyframes bounceIn{0%,20%,40%,60%,80%,to{-webkit-animation-timing-function:cubic-bezier(.215,.61,.355,1);animation-timing-function:cubic-bezier(.215,.61,.355,1)}0%{-webkit-transform:scale3d(.9,.9,.9);transform:scale3d(.9,.9,.9)}20%{-webkit-transform:scale3d(1.03,1.03,1.03);transform:scale3d(1.03,1.03,1.03)}60%{-webkit-transform:scale3d(1,1,1);transform:scaleZ(1)}}@-webkit-keyframes selectionBounce{0%,20%,40%,60%,80%,to{-webkit-animation-timing-function:cubic-bezier(.215,.61,.355,1);animation-timing-function:cubic-bezier(.215,.61,.355,1)}50%{-webkit-transform:scale3d(1.01,1.01,1.01);transform:scale3d(1.01,1.01,1.01)}70%{-webkit-transform:scale3d(1,1,1);transform:scaleZ(1)}}@keyframes selectionBounce{0%,20%,40%,60%,80%,to{-webkit-animation-timing-function:cubic-bezier(.215,.61,.355,1);animation-timing-function:cubic-bezier(.215,.61,.355,1)}50%{-webkit-transform:scale3d(1.01,1.01,1.01);transform:scale3d(1.01,1.01,1.01)}70%{-webkit-transform:scale3d(1,1,1);transform:scaleZ(1)}}@-webkit-keyframes buttonClicked{0%,20%,40%,60%,80%,to{-webkit-animation-timing-function:cubic-bezier(.215,.61,.355,1);animation-timing-function:cubic-bezier(.215,.61,.355,1)}0%{-webkit-transform:scale3d(.95,.95,.95);transform:scale3d(.95,.95,.95)}60%{-webkit-transform:scale3d(1.02,1.02,1.02);transform:scale3d(1.02,1.02,1.02)}80%{-webkit-transform:scale3d(1,1,1);transform:scaleZ(1)}}@keyframes buttonClicked{0%,20%,40%,60%,80%,to{-webkit-animation-timing-function:cubic-bezier(.215,.61,.355,1);animation-timing-function:cubic-bezier(.215,.61,.355,1)}0%{-webkit-transform:scale3d(.95,.95,.95);transform:scale3d(.95,.95,.95)}60%{-webkit-transform:scale3d(1.02,1.02,1.02);transform:scale3d(1.02,1.02,1.02)}80%{-webkit-transform:scale3d(1,1,1);transform:scaleZ(1)}}.cdx-block{padding:.4em 0}.cdx-block::-webkit-input-placeholder{line-height:normal!important}.cdx-input{border:1px solid rgba(201,201,204,.48);-webkit-box-shadow:inset 0 1px 2px 0 rgba(35,44,72,.06);box-shadow:inset 0 1px 2px #232c480f;border-radius:3px;padding:10px 12px;outline:none;width:100%;-webkit-box-sizing:border-box;box-sizing:border-box}.cdx-input[data-placeholder]:before{position:static!important}.cdx-input[data-placeholder]:before{display:inline-block;width:0;white-space:nowrap;pointer-events:none}.cdx-settings-button{display:-webkit-inline-box;display:-ms-inline-flexbox;display:inline-flex;-webkit-box-align:center;-ms-flex-align:center;align-items:center;-webkit-box-pack:center;-ms-flex-pack:center;justify-content:center;border-radius:3px;cursor:pointer;border:0;outline:none;background-color:transparent;vertical-align:bottom;color:inherit;margin:0;min-width:26px;min-height:26px}.cdx-settings-button--focused{background:rgba(34,186,255,.08)!important}.cdx-settings-button--focused{-webkit-box-shadow:inset 0 0 0px 1px rgba(7,161,227,.08);box-shadow:inset 0 0 0 1px #07a1e314}.cdx-settings-button--focused-animated{-webkit-animation-name:buttonClicked;animation-name:buttonClicked;-webkit-animation-duration:.25s;animation-duration:.25s}.cdx-settings-button--active{color:#388ae5}.cdx-settings-button svg{width:auto;height:auto}@media (max-width: 650px){.cdx-settings-button svg{width:28px;height:28px}}@media (max-width: 650px){.cdx-settings-button{width:36px;height:36px;border-radius:8px}}@media (hover: hover){.cdx-settings-button:hover{background-color:#eff2f5}}.cdx-loader{position:relative;border:1px solid rgba(201,201,204,.48)}.cdx-loader:before{content:"";position:absolute;left:50%;top:50%;width:18px;height:18px;margin:-11px 0 0 -11px;border:2px solid rgba(201,201,204,.48);border-left-color:#388ae5;border-radius:50%;-webkit-animation:cdxRotation 1.2s infinite linear;animation:cdxRotation 1.2s infinite linear}@-webkit-keyframes cdxRotation{0%{-webkit-transform:rotate(0deg);transform:rotate(0)}to{-webkit-transform:rotate(360deg);transform:rotate(360deg)}}@keyframes cdxRotation{0%{-webkit-transform:rotate(0deg);transform:rotate(0)}to{-webkit-transform:rotate(360deg);transform:rotate(360deg)}}.cdx-button{padding:13px;border-radius:3px;border:1px solid rgba(201,201,204,.48);font-size:14.9px;background:#fff;-webkit-box-shadow:0 2px 2px 0 rgba(18,30,57,.04);box-shadow:0 2px 2px #121e390a;color:#707684;text-align:center;cursor:pointer}@media (hover: hover){.cdx-button:hover{background:#FBFCFE;-webkit-box-shadow:0 1px 3px 0 rgba(18,30,57,.08);box-shadow:0 1px 3px #121e3914}}.cdx-button svg{height:20px;margin-right:.2em;margin-top:-2px}.ce-stub{display:-webkit-box;display:-ms-flexbox;display:flex;-webkit-box-align:center;-ms-flex-align:center;align-items:center;padding:12px 18px;margin:10px 0;border-radius:10px;background:#eff2f5;border:1px solid #EFF0F1;color:#707684;font-size:14px}.ce-stub svg{width:20px;height:20px}.ce-stub__info{margin-left:14px}.ce-stub__title{font-weight:500;text-transform:capitalize}.codex-editor.codex-editor--rtl{direction:rtl}.codex-editor.codex-editor--rtl .cdx-list{padding-left:0;padding-right:40px}.codex-editor.codex-editor--rtl .ce-toolbar__plus{right:-26px;left:auto}.codex-editor.codex-editor--rtl .ce-toolbar__actions{right:auto;left:-26px}@media (max-width: 650px){.codex-editor.codex-editor--rtl .ce-toolbar__actions{margin-left:0;margin-right:auto;padding-right:0;padding-left:10px}}.codex-editor.codex-editor--rtl .ce-settings{left:5px;right:auto}.codex-editor.codex-editor--rtl .ce-settings:before{right:auto;left:25px}.codex-editor.codex-editor--rtl .ce-settings__button:not(:nth-child(3n+3)){margin-left:3px;margin-right:0}.codex-editor.codex-editor--rtl .ce-conversion-tool__icon{margin-right:0;margin-left:10px}.codex-editor.codex-editor--rtl .ce-inline-toolbar__dropdown{border-right:0px solid transparent;border-left:1px solid rgba(201,201,204,.48);margin:0 -6px 0 6px}.codex-editor.codex-editor--rtl .ce-inline-toolbar__dropdown .icon--toggler-down{margin-left:0;margin-right:4px}@media (min-width: 651px){.codex-editor--narrow.codex-editor--rtl .ce-toolbar__plus{left:0;right:5px}}@media (min-width: 651px){.codex-editor--narrow.codex-editor--rtl .ce-toolbar__actions{left:-5px}}.cdx-search-field{--icon-margin-right: 10px;background:#F8F8F8;border:1px solid rgba(226,226,229,.2);border-radius:6px;padding:2px;display:grid;grid-template-columns:auto auto 1fr;grid-template-rows:auto}.cdx-search-field__icon{width:26px;height:26px;display:-webkit-box;display:-ms-flexbox;display:flex;-webkit-box-align:center;-ms-flex-align:center;align-items:center;-webkit-box-pack:center;-ms-flex-pack:center;justify-content:center;margin-right:var(--icon-margin-right)}.cdx-search-field__icon svg{width:20px;height:20px;color:#707684}.cdx-search-field__input{font-size:14px;outline:none;font-weight:500;font-family:inherit;border:0;background:transparent;margin:0;padding:0;line-height:22px;min-width:calc(100% - 26px - var(--icon-margin-right))}.cdx-search-field__input::-webkit-input-placeholder{color:#707684;font-weight:500}.cdx-search-field__input::-moz-placeholder{color:#707684;font-weight:500}.cdx-search-field__input:-ms-input-placeholder{color:#707684;font-weight:500}.cdx-search-field__input::-ms-input-placeholder{color:#707684;font-weight:500}.cdx-search-field__input::placeholder{color:#707684;font-weight:500}.ce-popover{--border-radius: 6px;--width: 200px;--max-height: 270px;--padding: 6px;--offset-from-target: 8px;--color-border: #EFF0F1;--color-shadow: rgba(13, 20, 33, .1);--color-background: white;--color-text-primary: black;--color-text-secondary: #707684;--color-border-icon: rgba(201, 201, 204, .48);--color-border-icon-disabled: #EFF0F1;--color-text-icon-active: #388AE5;--color-background-icon-active: rgba(56, 138, 229, .1);--color-background-item-focus: rgba(34, 186, 255, .08);--color-shadow-item-focus: rgba(7, 161, 227, .08);--color-background-item-hover: #F8F8F8;--color-background-item-confirm: #E24A4A;--color-background-item-confirm-hover: #CE4343;--popover-top: calc(100% + var(--offset-from-target));--popover-left: 0;--nested-popover-overlap: 4px;--icon-size: 20px;--item-padding: 3px;--item-height: calc(var(--icon-size) + 2 * var(--item-padding))}.ce-popover__container{min-width:var(--width);width:var(--width);max-height:var(--max-height);border-radius:var(--border-radius);overflow:hidden;-webkit-box-sizing:border-box;box-sizing:border-box;-webkit-box-shadow:0px 3px 15px -3px var(--color-shadow);box-shadow:0 3px 15px -3px var(--color-shadow);position:absolute;left:var(--popover-left);top:var(--popover-top);background:var(--color-background);display:-webkit-box;display:-ms-flexbox;display:flex;-webkit-box-orient:vertical;-webkit-box-direction:normal;-ms-flex-direction:column;flex-direction:column;z-index:4;opacity:0;max-height:0;pointer-events:none;padding:0;border:none}.ce-popover--opened>.ce-popover__container{opacity:1;padding:var(--padding);max-height:var(--max-height);pointer-events:auto;-webkit-animation:panelShowing .1s ease;animation:panelShowing .1s ease;border:1px solid var(--color-border)}@media (max-width: 650px){.ce-popover--opened>.ce-popover__container{-webkit-animation:panelShowingMobile .25s ease;animation:panelShowingMobile .25s ease}}.ce-popover--open-top .ce-popover__container{--popover-top: calc(-1 * (var(--offset-from-target) + var(--popover-height)))}.ce-popover--open-left .ce-popover__container{--popover-left: calc(-1 * var(--width) + 100%)}.ce-popover__items{overflow-y:auto;-ms-scroll-chaining:none;overscroll-behavior:contain}@media (max-width: 650px){.ce-popover__overlay{position:fixed;top:0;bottom:0;left:0;right:0;background:#1D202B;z-index:3;opacity:.5;-webkit-transition:opacity .12s ease-in;transition:opacity .12s ease-in;will-change:opacity;visibility:visible}}.ce-popover__overlay--hidden{display:none}@media (max-width: 650px){.ce-popover .ce-popover__container{--offset: 5px;position:fixed;max-width:none;min-width:calc(100% - var(--offset) * 2);left:var(--offset);right:var(--offset);bottom:calc(var(--offset) + env(safe-area-inset-bottom));top:auto;border-radius:10px}}.ce-popover__search{margin-bottom:5px}.ce-popover__nothing-found-message{color:#707684;display:none;cursor:default;padding:3px;font-size:14px;line-height:20px;font-weight:500;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.ce-popover__nothing-found-message--displayed{display:block}.ce-popover--nested .ce-popover__container{--popover-left: calc(var(--nesting-level) * (var(--width) - var(--nested-popover-overlap)));top:calc(var(--trigger-item-top) - var(--nested-popover-overlap));position:absolute}.ce-popover--open-top.ce-popover--nested .ce-popover__container{top:calc(var(--trigger-item-top) - var(--popover-height) + var(--item-height) + var(--offset-from-target) + var(--nested-popover-overlap))}.ce-popover--open-left .ce-popover--nested .ce-popover__container{--popover-left: calc(-1 * (var(--nesting-level) + 1) * var(--width) + 100%)}.ce-popover-item-separator{padding:4px 3px}.ce-popover-item-separator--hidden{display:none}.ce-popover-item-separator__line{height:1px;background:var(--color-border);width:100%}.ce-popover-item-html--hidden{display:none}.ce-popover-item{--border-radius: 6px;border-radius:var(--border-radius);display:-webkit-box;display:-ms-flexbox;display:flex;-webkit-box-align:center;-ms-flex-align:center;align-items:center;padding:var(--item-padding);color:var(--color-text-primary);-webkit-user-select:none;-moz-user-select:none;-ms-user-select:none;user-select:none;border:none;background:transparent}@media (max-width: 650px){.ce-popover-item{padding:4px}}.ce-popover-item:not(:last-of-type){margin-bottom:1px}.ce-popover-item__icon{width:26px;height:26px;display:-webkit-box;display:-ms-flexbox;display:flex;-webkit-box-align:center;-ms-flex-align:center;align-items:center;-webkit-box-pack:center;-ms-flex-pack:center;justify-content:center}.ce-popover-item__icon svg{width:20px;height:20px}@media (max-width: 650px){.ce-popover-item__icon{width:36px;height:36px;border-radius:8px}.ce-popover-item__icon svg{width:28px;height:28px}}.ce-popover-item__icon--tool{margin-right:4px}.ce-popover-item__title{font-size:14px;line-height:20px;font-weight:500;overflow:hidden;white-space:nowrap;text-overflow:ellipsis;margin-right:auto}@media (max-width: 650px){.ce-popover-item__title{font-size:16px}}.ce-popover-item__secondary-title{color:var(--color-text-secondary);font-size:12px;white-space:nowrap;letter-spacing:-.1em;padding-right:5px;opacity:.6}@media (max-width: 650px){.ce-popover-item__secondary-title{display:none}}.ce-popover-item--active{background:var(--color-background-icon-active);color:var(--color-text-icon-active)}.ce-popover-item--disabled{color:var(--color-text-secondary);cursor:default;pointer-events:none}.ce-popover-item--focused:not(.ce-popover-item--no-focus){background:var(--color-background-item-focus)!important}.ce-popover-item--hidden{display:none}@media (hover: hover){.ce-popover-item:hover{cursor:pointer}.ce-popover-item:hover:not(.ce-popover-item--no-hover){background-color:var(--color-background-item-hover)}}.ce-popover-item--confirmation{background:var(--color-background-item-confirm)}.ce-popover-item--confirmation .ce-popover-item__title,.ce-popover-item--confirmation .ce-popover-item__icon{color:#fff}@media (hover: hover){.ce-popover-item--confirmation:not(.ce-popover-item--no-hover):hover{background:var(--color-background-item-confirm-hover)}}.ce-popover-item--confirmation:not(.ce-popover-item--no-focus).ce-popover-item--focused{background:var(--color-background-item-confirm-hover)!important}@-webkit-keyframes panelShowing{0%{opacity:0;-webkit-transform:translateY(-8px) scale(.9);transform:translateY(-8px) scale(.9)}70%{opacity:1;-webkit-transform:translateY(2px);transform:translateY(2px)}to{-webkit-transform:translateY(0);transform:translateY(0)}}@keyframes panelShowing{0%{opacity:0;-webkit-transform:translateY(-8px) scale(.9);transform:translateY(-8px) scale(.9)}70%{opacity:1;-webkit-transform:translateY(2px);transform:translateY(2px)}to{-webkit-transform:translateY(0);transform:translateY(0)}}@-webkit-keyframes panelShowingMobile{0%{opacity:0;-webkit-transform:translateY(14px) scale(.98);transform:translateY(14px) scale(.98)}70%{opacity:1;-webkit-transform:translateY(-4px);transform:translateY(-4px)}to{-webkit-transform:translateY(0);transform:translateY(0)}}@keyframes panelShowingMobile{0%{opacity:0;-webkit-transform:translateY(14px) scale(.98);transform:translateY(14px) scale(.98)}70%{opacity:1;-webkit-transform:translateY(-4px);transform:translateY(-4px)}to{-webkit-transform:translateY(0);transform:translateY(0)}}.wobble{-webkit-animation-name:wobble;animation-name:wobble;-webkit-animation-duration:.4s;animation-duration:.4s}@-webkit-keyframes wobble{0%{-webkit-transform:translate3d(0,0,0);transform:translateZ(0)}15%{-webkit-transform:translate3d(-9%,0,0);transform:translate3d(-9%,0,0)}30%{-webkit-transform:translate3d(9%,0,0);transform:translate3d(9%,0,0)}45%{-webkit-transform:translate3d(-4%,0,0);transform:translate3d(-4%,0,0)}60%{-webkit-transform:translate3d(4%,0,0);transform:translate3d(4%,0,0)}75%{-webkit-transform:translate3d(-1%,0,0);transform:translate3d(-1%,0,0)}to{-webkit-transform:translate3d(0,0,0);transform:translateZ(0)}}@keyframes wobble{0%{-webkit-transform:translate3d(0,0,0);transform:translateZ(0)}15%{-webkit-transform:translate3d(-9%,0,0);transform:translate3d(-9%,0,0)}30%{-webkit-transform:translate3d(9%,0,0);transform:translate3d(9%,0,0)}45%{-webkit-transform:translate3d(-4%,0,0);transform:translate3d(-4%,0,0)}60%{-webkit-transform:translate3d(4%,0,0);transform:translate3d(4%,0,0)}75%{-webkit-transform:translate3d(-1%,0,0);transform:translate3d(-1%,0,0)}to{-webkit-transform:translate3d(0,0,0);transform:translateZ(0)}}.ce-popover-header{margin-bottom:8px;margin-top:4px;display:-webkit-box;display:-ms-flexbox;display:flex;-webkit-box-align:center;-ms-flex-align:center;align-items:center}.ce-popover-header__text{font-size:18px;font-weight:600}.ce-popover-header__back-button{border:0;background:transparent;width:36px;height:36px;color:var(--color-text-primary)}.ce-popover-header__back-button svg{display:block;width:28px;height:28px}.ce-popover--inline{--height: 38px;--height-mobile: 46px;--container-padding: 4px;position:relative}.ce-popover--inline .ce-popover__custom-content{margin-bottom:0}.ce-popover--inline .ce-popover__items{display:-webkit-box;display:-ms-flexbox;display:flex}.ce-popover--inline .ce-popover__container{-webkit-box-orient:horizontal;-webkit-box-direction:normal;-ms-flex-direction:row;flex-direction:row;padding:var(--container-padding);height:var(--height);top:0;min-width:-webkit-max-content;min-width:-moz-max-content;min-width:max-content;width:-webkit-max-content;width:-moz-max-content;width:max-content;-webkit-animation:none;animation:none}@media (max-width: 650px){.ce-popover--inline .ce-popover__container{height:var(--height-mobile);position:absolute}}.ce-popover--inline .ce-popover-item-separator{padding:0 4px}.ce-popover--inline .ce-popover-item-separator__line{height:100%;width:1px}.ce-popover--inline .ce-popover-item{border-radius:4px;padding:4px}.ce-popover--inline .ce-popover-item__icon--tool{-webkit-box-shadow:none;box-shadow:none;background:transparent;margin-right:0}.ce-popover--inline .ce-popover-item__icon{width:auto;width:initial;height:auto;height:initial}.ce-popover--inline .ce-popover-item__icon svg{width:20px;height:20px}@media (max-width: 650px){.ce-popover--inline .ce-popover-item__icon svg{width:28px;height:28px}}.ce-popover--inline .ce-popover-item:not(:last-of-type){margin-bottom:0;margin-bottom:initial}.ce-popover--inline .ce-popover-item-html{display:-webkit-box;display:-ms-flexbox;display:flex;-webkit-box-align:center;-ms-flex-align:center;align-items:center}.ce-popover--inline .ce-popover-item__icon--chevron-right{-webkit-transform:rotate(90deg);transform:rotate(90deg)}.ce-popover--inline .ce-popover--nested-level-1 .ce-popover__container{--offset: 3px;left:0;top:calc(var(--height) + var(--offset))}@media (max-width: 650px){.ce-popover--inline .ce-popover--nested-level-1 .ce-popover__container{top:calc(var(--height-mobile) + var(--offset))}}.ce-popover--inline .ce-popover--nested .ce-popover__container{min-width:var(--width);width:var(--width);height:-webkit-fit-content;height:-moz-fit-content;height:fit-content;padding:6px;-webkit-box-orient:vertical;-webkit-box-direction:normal;-ms-flex-direction:column;flex-direction:column}.ce-popover--inline .ce-popover--nested .ce-popover__items{display:block;width:100%}.ce-popover--inline .ce-popover--nested .ce-popover-item{border-radius:6px;padding:3px}@media (max-width: 650px){.ce-popover--inline .ce-popover--nested .ce-popover-item{padding:4px}}.ce-popover--inline .ce-popover--nested .ce-popover-item__icon--tool{margin-right:4px}.ce-popover--inline .ce-popover--nested .ce-popover-item__icon{width:26px;height:26px}.ce-popover--inline .ce-popover--nested .ce-popover-item-separator{padding:4px 3px}.ce-popover--inline .ce-popover--nested .ce-popover-item-separator__line{width:100%;height:1px}.codex-editor [data-placeholder]:empty:before,.codex-editor [data-placeholder][data-empty=true]:before{pointer-events:none;color:#707684;cursor:text;content:attr(data-placeholder)}.codex-editor [data-placeholder-active]:empty:before,.codex-editor [data-placeholder-active][data-empty=true]:before{pointer-events:none;color:#707684;cursor:text}.codex-editor [data-placeholder-active]:empty:focus:before,.codex-editor [data-placeholder-active][data-empty=true]:focus:before{content:attr(data-placeholder-active)}\n';class Ia extends E{constructor(){super(...arguments),this.isMobile=!1,this.contentRectCache=null,this.resizeDebouncer=_((()=>{this.windowResize()}),200),this.selectionChangeDebounced=_((()=>{this.selectionChanged()}),vr),this.documentTouchedListener=e=>{this.documentTouched(e)}
/**
   * Editor.js UI CSS class names
   *
   * @returns {{editorWrapper: string, editorZone: string}}
   */}get CSS(){return{editorWrapper:"codex-editor",editorWrapperNarrow:"codex-editor--narrow",editorZone:"codex-editor__redactor",editorZoneHidden:"codex-editor__redactor--hidden",editorEmpty:"codex-editor--empty",editorRtlFix:"codex-editor--rtl"}}
/**
   * Return Width of center column of Editor
   *
   * @returns {DOMRect}
   */get contentRect(){if(this.contentRectCache!==null)return this.contentRectCache;const e=this.nodes.wrapper.querySelector(`.${R.CSS.content}`);return e?(this.contentRectCache=e.getBoundingClientRect(),this.contentRectCache):{width:650,left:0,right:0}}async prepare(){this.setIsMobile(),this.make(),this.loadStyles()
/**
   * Toggle read-only state
   *
   * If readOnly is true:
   *  - removes all listeners from main UI module elements
   *
   * if readOnly is false:
   *  - enables all listeners to UI module elements
   *
   * @param {boolean} readOnlyEnabled - "read only" state
   */}toggleReadOnly(e){e?this.unbindReadOnlySensitiveListeners():window.requestIdleCallback((()=>{this.bindReadOnlySensitiveListeners()}),{timeout:2e3})}checkEmptiness(){const{BlockManager:e}=this.Editor;this.nodes.wrapper.classList.toggle(this.CSS.editorEmpty,e.isEditorEmpty)}
/**
   * Check if one of Toolbar is opened
   * Used to prevent global keydowns (for example, Enter) conflicts with Enter-on-toolbar
   *
   * @returns {boolean}
   */get someToolbarOpened(){const{Toolbar:e,BlockSettings:t,InlineToolbar:o}=this.Editor;return!!(t.opened||o.opened||e.toolbox.opened)}get someFlipperButtonFocused(){return!!this.Editor.Toolbar.toolbox.hasFocus()||Object.entries(this.Editor).filter((([e,t])=>t.flipper instanceof ce)).some((([e,t])=>t.flipper.hasFocus()))}destroy(){this.nodes.holder.innerHTML="",this.unbindReadOnlyInsensitiveListeners()}closeAllToolbars(){const{Toolbar:e,BlockSettings:t,InlineToolbar:o}=this.Editor;t.close(),o.close(),e.toolbox.close()}setIsMobile(){const e=window.innerWidth<W;e!==this.isMobile&&this.eventsDispatcher.emit(pe,{isEnabled:this.isMobile}),this.isMobile=e}make(){this.nodes.holder=u.getHolder(this.config.holder),this.nodes.wrapper=u.make("div",[this.CSS.editorWrapper,...this.isRtl?[this.CSS.editorRtlFix]:[]]),this.nodes.redactor=u.make("div",this.CSS.editorZone),this.nodes.holder.offsetWidth<this.contentRect.width&&this.nodes.wrapper.classList.add(this.CSS.editorWrapperNarrow),this.nodes.redactor.style.paddingBottom=this.config.minHeight+"px",this.nodes.wrapper.appendChild(this.nodes.redactor),this.nodes.holder.appendChild(this.nodes.wrapper),this.bindReadOnlyInsensitiveListeners()}loadStyles(){const e="editor-js-styles";if(u.get(e))return;const t=u.make("style",null,{id:e,textContent:_r.toString()});this.config.style&&!x(this.config.style)&&this.config.style.nonce&&t.setAttribute("nonce",this.config.style.nonce),u.prepend(document.head,t)}bindReadOnlyInsensitiveListeners(){this.listeners.on(document,"selectionchange",this.selectionChangeDebounced),this.listeners.on(window,"resize",this.resizeDebouncer,{passive:!0}),this.listeners.on(this.nodes.redactor,"mousedown",this.documentTouchedListener,{capture:!0,passive:!0}),this.listeners.on(this.nodes.redactor,"touchstart",this.documentTouchedListener,{capture:!0,passive:!0})}unbindReadOnlyInsensitiveListeners(){this.listeners.off(document,"selectionchange",this.selectionChangeDebounced),this.listeners.off(window,"resize",this.resizeDebouncer),this.listeners.off(this.nodes.redactor,"mousedown",this.documentTouchedListener),this.listeners.off(this.nodes.redactor,"touchstart",this.documentTouchedListener)}bindReadOnlySensitiveListeners(){this.readOnlyMutableListeners.on(this.nodes.redactor,"click",(e=>{this.redactorClicked(e)}),!1),this.readOnlyMutableListeners.on(document,"keydown",(e=>{this.documentKeydown(e)}),!0),this.readOnlyMutableListeners.on(document,"mousedown",(e=>{this.documentClicked(e)}),!0),this.watchBlockHoveredEvents(),this.enableInputsEmptyMark()}watchBlockHoveredEvents(){let e;this.readOnlyMutableListeners.on(this.nodes.redactor,"mousemove",M((t=>{const o=t.target.closest(".ce-block");this.Editor.BlockSelection.anyBlockSelected||o&&e!==o&&(e=o,this.eventsDispatcher.emit(ro,{block:this.Editor.BlockManager.getBlockByChildNode(o)}))}),20),{passive:!0})}unbindReadOnlySensitiveListeners(){this.readOnlyMutableListeners.clearAll()}windowResize(){this.contentRectCache=null,this.setIsMobile()
/**
   * All keydowns on document
   *
   * @param {KeyboardEvent} event - keyboard event
   */}documentKeydown(e){switch(e.keyCode){case a.ENTER:this.enterPressed(e);break;case a.BACKSPACE:case a.DELETE:this.backspacePressed(e);break;case a.ESC:this.escapePressed(e);break;default:this.defaultBehaviour(e);break}}
/**
   * Ignore all other document's keydown events
   *
   * @param {KeyboardEvent} event - keyboard event
   */defaultBehaviour(e){const{currentBlock:t}=this.Editor.BlockManager,o=e.target.closest(`.${this.CSS.editorWrapper}`),n=e.altKey||e.ctrlKey||e.metaKey||e.shiftKey;t===void 0||o!==null?o||t&&n||(this.Editor.BlockManager.unsetCurrentBlock(),this.Editor.Toolbar.close()
/**
   * @param {KeyboardEvent} event - keyboard event
   */):this.Editor.BlockEvents.keydown(e)}backspacePressed(e){const{BlockManager:t,BlockSelection:o,Caret:n}=this.Editor;if(o.anyBlockSelected&&!b.isSelectionExists){const i=t.removeSelectedBlocks(),r=t.insertDefaultBlockAtIndex(i,!0);n.setToBlock(r,n.positions.START),o.clearSelection(e),e.preventDefault(),e.stopPropagation(),e.stopImmediatePropagation()}}
/**
   * Escape pressed
   * If some of Toolbar components are opened, then close it otherwise close Toolbar
   *
   * @param {Event} event - escape keydown event
   */escapePressed(e){this.Editor.BlockSelection.clearSelection(e),this.Editor.Toolbar.toolbox.opened?(this.Editor.Toolbar.toolbox.close(),this.Editor.Caret.setToBlock(this.Editor.BlockManager.currentBlock,this.Editor.Caret.positions.END)):this.Editor.BlockSettings.opened?this.Editor.BlockSettings.close():this.Editor.InlineToolbar.opened?this.Editor.InlineToolbar.close():this.Editor.Toolbar.close()
/**
   * Enter pressed on document
   *
   * @param {KeyboardEvent} event - keyboard event
   */}enterPressed(e){const{BlockManager:t,BlockSelection:o}=this.Editor;if(this.someToolbarOpened)return;const n=t.currentBlockIndex>=0;if(!o.anyBlockSelected||b.isSelectionExists){if(!this.someToolbarOpened&&n&&e.target.tagName==="BODY"){const t=this.Editor.BlockManager.insert();e.preventDefault(),this.Editor.Caret.setToBlock(t),this.Editor.Toolbar.moveAndOpen(t)}this.Editor.BlockSelection.clearSelection(e)}else o.clearSelection(e),e.preventDefault(),e.stopImmediatePropagation(),e.stopPropagation()}
/**
   * All clicks on document
   *
   * @param {MouseEvent} event - Click event
   */documentClicked(e){var t,o;if(!e.isTrusted)return;const n=e.target;this.nodes.holder.contains(n)||b.isAtEditor||(this.Editor.BlockManager.unsetCurrentBlock(),this.Editor.Toolbar.close());const i=(t=this.Editor.BlockSettings.nodes.wrapper)==null?void 0:t.contains(n),r=(o=this.Editor.Toolbar.nodes.settingsToggler)==null?void 0:o.contains(n),a=i||r;if(this.Editor.BlockSettings.opened&&!a){this.Editor.BlockSettings.close();const e=this.Editor.BlockManager.getBlockByChildNode(n);this.Editor.Toolbar.moveAndOpen(e)}this.Editor.BlockSelection.clearSelection(e)}
/**
   * First touch on editor
   * Fired before click
   *
   * Used to change current block — we need to do it before 'selectionChange' event.
   * Also:
   * - Move and show the Toolbar
   * - Set a Caret
   *
   * @param event - touch or mouse event
   */documentTouched(e){let t=e.target;if(t===this.nodes.redactor){const o=e instanceof MouseEvent?e.clientX:e.touches[0].clientX,n=e instanceof MouseEvent?e.clientY:e.touches[0].clientY;t=document.elementFromPoint(o,n)}try{this.Editor.BlockManager.setCurrentBlockByChildNode(t)}catch{this.Editor.RectangleSelection.isRectActivated()||this.Editor.Caret.setToTheLastBlock()}this.Editor.ReadOnly.isEnabled||this.Editor.Toolbar.moveAndOpen()}
/**
   * All clicks on the redactor zone
   *
   * @param {MouseEvent} event - click event
   * @description
   * - By clicks on the Editor's bottom zone:
   *      - if last Block is empty, set a Caret to this
   *      - otherwise, add a new empty Block and set a Caret to that
   */redactorClicked(e){if(!b.isCollapsed)return;const t=e.target,o=e.metaKey||e.ctrlKey;if(u.isAnchor(t)&&o){e.stopImmediatePropagation(),e.stopPropagation();const o=t.getAttribute("href"),n=D(o);H(n)}else this.processBottomZoneClick(e)}
/**
   * Check if user clicks on the Editor's bottom zone:
   *  - set caret to the last block
   *  - or add new empty block
   *
   * @param event - click event
   */processBottomZoneClick(e){const t=this.Editor.BlockManager.getBlockByIndex(-1),o=u.offset(t.holder).bottom,n=e.pageY,{BlockSelection:i}=this.Editor;if(e.target instanceof Element&&e.target.isEqualNode(this.nodes.redactor)&&!i.anyBlockSelected&&o<n){e.stopImmediatePropagation(),e.stopPropagation();const{BlockManager:t,Caret:o,Toolbar:n}=this.Editor;(!t.lastBlock.tool.isDefault||!t.lastBlock.isEmpty)&&t.insertAtEnd(),o.setToTheLastBlock(),n.moveAndOpen(t.lastBlock)}}selectionChanged(){const{CrossBlockSelection:e,BlockSelection:t}=this.Editor,o=b.anchorElement;if(e.isCrossBlockSelectionStarted&&t.anyBlockSelected&&b.get().removeAllRanges(),!o){b.range||this.Editor.InlineToolbar.close();return}const n=o.closest(`.${R.CSS.content}`);(n===null||n.closest(`.${b.CSS.editorWrapper}`)!==this.nodes.wrapper)&&(this.Editor.InlineToolbar.containsNode(o)||this.Editor.InlineToolbar.close(),!(o.dataset.inlineToolbar==="true"))||(this.Editor.BlockManager.currentBlock||this.Editor.BlockManager.setCurrentBlockByChildNode(o),this.Editor.InlineToolbar.tryToShow(!0))}enableInputsEmptyMark(){function e(e){const t=e.target;Z(t)}this.readOnlyMutableListeners.on(this.nodes.wrapper,"input",e),this.readOnlyMutableListeners.on(this.nodes.wrapper,"focusin",e),this.readOnlyMutableListeners.on(this.nodes.wrapper,"focusout",e)}}const Mr={BlocksAPI:gi,CaretAPI:bi,EventsAPI:vi,I18nAPI:kt,API:ki,InlineToolbarAPI:yi,ListenersAPI:wi,NotifierAPI:Ci,ReadOnlyAPI:Ti,SanitizerAPI:Li,SaverAPI:Pi,SelectionAPI:Ni,ToolsAPI:Ri,StylesAPI:Di,ToolbarAPI:Fi,TooltipAPI:Ui,UiAPI:Wi,BlockSettings:ms,Toolbar:Bs,InlineToolbar:Cs,BlockEvents:na,BlockManager:ra,BlockSelection:aa,Caret:Ye,CrossBlockSelection:la,DragNDrop:ca,ModificationsObserver:ha,Paste:wr,ReadOnly:fa,RectangleSelection:Be,Renderer:ga,Saver:ma,Tools:Wn,UI:Ia};class _a{
/**
   * @param {EditorConfig} config - user configuration
   */
constructor(e){this.moduleInstances={},this.eventsDispatcher=new Oe;let t,o;this.isReady=new Promise(((e,n)=>{t=e,o=n})),Promise.resolve().then((async()=>{this.configuration=e,this.validate(),this.init(),await this.start(),await this.render();const{BlockManager:o,Caret:n,UI:i,ModificationsObserver:r}=this.moduleInstances;i.checkEmptiness(),r.enable(),this.configuration.autofocus===!0&&this.configuration.readOnly!==!0&&n.setToBlock(o.blocks[0],n.positions.START),t()})).catch((e=>{h(`Editor.js is not ready because of ${e}`,"error"),o(e)}))
/**
   * Setting for configuration
   *
   * @param {EditorConfig|string} config - Editor's config to set
   */}set configuration(e){var t,o;m(e)?this.config={...e}:this.config={holder:e},U(!!this.config.holderId,"config.holderId","config.holder"),this.config.holderId&&!this.config.holder&&(this.config.holder=this.config.holderId,this.config.holderId=null),this.config.holder==null&&(this.config.holder="editorjs"),this.config.logLevel||(this.config.logLevel=r.VERBOSE),d(this.config.logLevel),U(!!this.config.initialBlock,"config.initialBlock","config.defaultBlock"),this.config.defaultBlock=this.config.defaultBlock||this.config.initialBlock||"paragraph",this.config.minHeight=this.config.minHeight!==void 0?this.config.minHeight:300;const n={type:this.config.defaultBlock,data:{}};this.config.placeholder=this.config.placeholder||!1,this.config.sanitizer=this.config.sanitizer||{p:!0,b:!0,a:!0},this.config.hideToolbar=!!this.config.hideToolbar&&this.config.hideToolbar,this.config.tools=this.config.tools||{},this.config.i18n=this.config.i18n||{},this.config.data=this.config.data||{blocks:[]},this.config.onReady=this.config.onReady||(()=>{}),this.config.onChange=this.config.onChange||(()=>{}),this.config.inlineToolbar=this.config.inlineToolbar===void 0||this.config.inlineToolbar,(x(this.config.data)||!this.config.data.blocks||this.config.data.blocks.length===0)&&(this.config.data={blocks:[n]}),this.config.readOnly=this.config.readOnly||!1,(t=this.config.i18n)!=null&&t.messages&&ne.setDictionary(this.config.i18n.messages),this.config.i18n.direction=((o=this.config.i18n)==null?void 0:o.direction)||"ltr"
/**
   * Returns private property
   *
   * @returns {EditorConfig}
   */}get configuration(){return this.config}validate(){const{holderId:e,holder:t}=this.config;if(e&&t)throw Error("«holderId» and «holder» param can't assign at the same time.");if(v(t)&&!u.get(t))throw Error(`element with ID «${t}» is missing. Pass correct holder's ID.`);if(t&&m(t)&&!u.isElement(t))throw Error("«holder» value must be an Element node")}init(){this.constructModules(),this.configureModules()
/**
   * Start Editor!
   *
   * Get list of modules that needs to be prepared and return a sequence (Promise)
   *
   * @returns {Promise<void>}
   */}async start(){await["Tools","UI","BlockManager","Paste","BlockSelection","RectangleSelection","CrossBlockSelection","ReadOnly"].reduce(((e,t)=>e.then((async()=>{try{await this.moduleInstances[t].prepare()}catch(e){if(e instanceof Ho)throw new Error(e.message);h(`Module ${t} was skipped because of %o`,"warn",e)}}))),Promise.resolve())}render(){return this.moduleInstances.Renderer.render(this.config.data.blocks)}constructModules(){Object.entries(Mr).forEach((([e,t])=>{try{this.moduleInstances[e]=new t({config:this.configuration,eventsDispatcher:this.eventsDispatcher})}catch(t){h("[constructModules]",`Module ${e} skipped because`,"error",t)}}))}configureModules(){for(const e in this.moduleInstances)Object.prototype.hasOwnProperty.call(this.moduleInstances,e)&&(this.moduleInstances[e].state=this.getModulesDiff(e))}
/**
   * Return modules without passed name
   *
   * @param {string} name - module for witch modules difference should be calculated
   */getModulesDiff(e){const t={};for(const o in this.moduleInstances)o!==e&&(t[o]=this.moduleInstances[o]);return t}}
/**
 * Editor.js
 *
 * @license Apache-2.0
 * @see Editor.js <https://editorjs.io>
 * @author CodeX Team <https://codex.so>
 */class Aa{static get version(){return"2.31.0"}
/**
   * @param {EditorConfig|string|undefined} [configuration] - user configuration
   */constructor(e){let t=()=>{};m(e)&&g(e.onReady)&&(t=e.onReady);const o=new _a(e);this.isReady=o.isReady.then((()=>{this.exportAPI(o),t()}))}
/**
   * Export external API methods
   *
   * @param {Core} editor — Editor's instance
   */exportAPI(e){const t=["configuration"],o=()=>{Object.values(e.moduleInstances).forEach((e=>{g(e.destroy)&&e.destroy(),e.listeners.removeAll()})),Qe(),e=null;for(const e in this)Object.prototype.hasOwnProperty.call(this,e)&&delete this[e];Object.setPrototypeOf(this,null)};t.forEach((t=>{this[t]=e[t]})),this.destroy=o,Object.setPrototypeOf(this,e.moduleInstances.API.methods),delete this.exportAPI,Object.entries({blocks:{clear:"clear",render:"render"},caret:{focus:"focus"},events:{on:"on",off:"off",emit:"emit"},saver:{save:"save"}}).forEach((([t,o])=>{Object.entries(o).forEach((([o,n])=>{this[n]=e.moduleInstances.API.methods[t][o]}))}))}}export{Aa as default};

