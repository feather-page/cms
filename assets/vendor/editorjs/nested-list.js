(function(){try{if(typeof document<"u"){var t=document.createElement("style");t.appendChild(document.createTextNode('.cdx-nested-list{margin:0;padding:0;outline:none;counter-reset:item;list-style:none}.cdx-nested-list__item{line-height:1.6em;display:flex;margin:2px 0}.cdx-nested-list__item [contenteditable]{outline:none}.cdx-nested-list__item-body{flex-grow:2}.cdx-nested-list__item-content,.cdx-nested-list__item-children{flex-basis:100%}.cdx-nested-list__item-content{word-break:break-word;white-space:pre-wrap}.cdx-nested-list__item:before{counter-increment:item;margin-right:5px;white-space:nowrap}.cdx-nested-list--ordered>.cdx-nested-list__item:before{content:counters(item,".") ". "}.cdx-nested-list--unordered>.cdx-nested-list__item:before{content:"•"}.cdx-nested-list__settings{display:flex}.cdx-nested-list__settings .cdx-settings-button{width:50%}')),document.head.appendChild(t)}}catch(t){console.error("vite-plugin-css-injected-by-js",t)}})();function c(t){return t.nodeType===Node.ELEMENT_NODE}function p(t,r=null,n){const s=document.createElement(t);Array.isArray(r)?s.classList.add(...r):r&&s.classList.add(r);for(const t in n)s[t]=n[t];return s}function g(t){const r=p("div");return r.appendChild(t),r.innerHTML}function C(t){let r;return t.nodeType!==Node.ELEMENT_NODE?r=t.textContent:(r=t.innerHTML,r=r.replaceAll("<br>","")),(r==null?void 0:r.trim().length)===0}class u{constructor(){this.savedFakeCaret=void 0}
/**
   * Saves caret position using hidden <span>
   *
   * @returns {void}
   */save(){const t=u.range,r=p("span");r.hidden=!0,t&&(t.insertNode(r),this.savedFakeCaret=r
/**
   * Restores the caret position saved by the save() method
   *
   * @returns {void}
   */)}restore(){if(!this.savedFakeCaret)return;const t=window.getSelection();if(!t)return;const r=new Range;r.setStartAfter(this.savedFakeCaret),r.setEndAfter(this.savedFakeCaret),t.removeAllRanges(),t.addRange(r),setTimeout((()=>{var t;(t=this.savedFakeCaret)==null||t.remove()}),150)
/**
   * Returns the first range
   *
   * @returns {Range|null}
   */}static get range(){const t=window.getSelection();return t&&t.rangeCount?t.getRangeAt(0):null}
/**
   * Extract content fragment from Caret position to the end of contenteditable element
   *
   * @returns {DocumentFragment|void}
   */static extractFragmentFromCaretPositionTillTheEnd(){const t=window.getSelection();if(!t||!t.rangeCount)return;const r=t.getRangeAt(0);let n=r.startContainer;if(n.nodeType!==Node.ELEMENT_NODE){if(!n.parentNode)return;n=n.parentNode}if(!c(n))return;const s=n.closest("[contenteditable]");if(!s)return;r.deleteContents();const o=r.cloneRange();return o.selectNodeContents(s),o.setStart(r.endContainer,r.endOffset),o.extractContents()
/**
   * Set focus to contenteditable or native input element
   *
   * @param {HTMLElement} element - element where to set focus
   * @param {boolean} atStart - where to set focus: at the start or at the end
   * @returns {void}
   */}static focus(t,r=!0){const n=document.createRange(),s=window.getSelection();s&&(n.selectNodeContents(t),n.collapse(r),s.removeAllRanges(),s.addRange(n)
/**
   * Check if the caret placed at the start of the contenteditable element
   *
   * @returns {boolean}
   */)}static isAtStart(){const t=window.getSelection();if(!t||t.focusOffset>0)return!1;const r=t.focusNode;return!(!r||!c(r))&&u.getHigherLevelSiblings(r,"left").every((t=>C(t)))}
/**
   * Get all first-level (first child of [contenteditabel]) siblings from passed node
   * Then you can check it for emptiness
   *
   * @example
   * <div contenteditable>
   * <p></p>                            |
   * <p></p>                            | left first-level siblings
   * <p></p>                            |
   * <blockquote><a><b>adaddad</b><a><blockquote>       <-- passed node for example <b>
   * <p></p>                            |
   * <p></p>                            | right first-level siblings
   * <p></p>                            |
   * </div>
   * @param {HTMLElement} from - element from which siblings should be searched
   * @param {'left' | 'right'} direction - direction of search
   * @returns {HTMLElement[]}
   */static getHigherLevelSiblings(t,r="left"){let n=t;const s=[];for(;n.parentNode&&n.parentNode.contentEditable!=="true";)n=n.parentNode;const o=r==="left"?"previousSibling":"nextSibling";for(;n[o];)n=n[o],s.push(n);return s}}const t='<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" fill="none" viewBox="0 0 24 24"><line x1="9" x2="19" y1="7" y2="7" stroke="currentColor" stroke-linecap="round" stroke-width="2"/><line x1="9" x2="19" y1="12" y2="12" stroke="currentColor" stroke-linecap="round" stroke-width="2"/><line x1="9" x2="19" y1="17" y2="17" stroke="currentColor" stroke-linecap="round" stroke-width="2"/><path stroke="currentColor" stroke-linecap="round" stroke-width="2" d="M5.00001 17H4.99002"/><path stroke="currentColor" stroke-linecap="round" stroke-width="2" d="M5.00001 12H4.99002"/><path stroke="currentColor" stroke-linecap="round" stroke-width="2" d="M5.00001 7H4.99002"/></svg>',r='<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" fill="none" viewBox="0 0 24 24"><line x1="12" x2="19" y1="7" y2="7" stroke="currentColor" stroke-linecap="round" stroke-width="2"/><line x1="12" x2="19" y1="12" y2="12" stroke="currentColor" stroke-linecap="round" stroke-width="2"/><line x1="12" x2="19" y1="17" y2="17" stroke="currentColor" stroke-linecap="round" stroke-width="2"/><path stroke="currentColor" stroke-linecap="round" stroke-width="2" d="M7.79999 14L7.79999 7.2135C7.79999 7.12872 7.7011 7.0824 7.63597 7.13668L4.79999 9.5"/></svg>';class f{
/**
   * Notify core that read-only mode is supported
   *
   * @returns {boolean}
   */
static get isReadOnlySupported(){return!0}
/**
   * Allow to use native Enter behaviour
   *
   * @returns {boolean}
   * @public
   */static get enableLineBreaks(){return!0}
/**
   * Get Tool toolbox settings
   * icon - Tool icon's SVG
   * title - title to show in toolbox
   *
   * @returns {ToolboxConfig}
   */static get toolbox(){return{icon:r,title:"List"}}
/**
   * Render plugin`s main Element and fill it with saved data
   *
   * @param {object} params - tool constructor options
   * @param {ListData} params.data - previously saved data
   * @param {object} params.config - user config for Tool
   * @param {object} params.api - Editor.js API
   * @param {boolean} params.readOnly - read-only mode flag
   */constructor({data:t,config:r,api:n,readOnly:s}){var o;this.nodes={wrapper:null},this.api=n,this.readOnly=s,this.config=r,this.defaultListStyle=((o=this.config)==null?void 0:o.defaultStyle)==="ordered"?"ordered":"unordered";const a={style:this.defaultListStyle,items:[]};this.data=t&&Object.keys(t).length?t:a,this.caret=new u
/**
   * Returns list tag with items
   *
   * @returns {Element}
   * @public
   */}render(){return this.nodes.wrapper=this.makeListWrapper(this.data.style,[this.CSS.baseBlock]),this.data.items.length?this.appendItems(this.data.items,this.nodes.wrapper):this.appendItems([{content:"",items:[]}],this.nodes.wrapper),this.readOnly||this.nodes.wrapper.addEventListener("keydown",(t=>{switch(t.key){case"Enter":this.enterPressed(t);break;case"Backspace":this.backspace(t);break;case"Tab":t.shiftKey?this.shiftTab(t):this.addTab(t);break}}),!1),this.nodes.wrapper
/**
   * Creates Block Tune allowing to change the list style
   *
   * @public
   * @returns {Array}
   */}renderSettings(){return[{name:"unordered",label:this.api.i18n.t("Unordered"),icon:t},{name:"ordered",label:this.api.i18n.t("Ordered"),icon:r}].map((t=>({name:t.name,icon:t.icon,label:t.label,isActive:this.data.style===t.name,closeOnActivate:!0,onActivate:()=>{this.listStyle=t.name}})))}
/**
   * On paste sanitzation config. Allow only tags that are allowed in the Tool.
   *
   * @returns {PasteConfig} - paste config.
   */static get pasteConfig(){return{tags:["OL","UL","LI"]}}
/**
   * On paste callback that is fired from Editor.
   *
   * @param {PasteEvent} event - event with pasted data
   */onPaste(t){const r=t.detail.data;this.data=this.pasteHandler(r);const n=this.nodes.wrapper;n&&n.parentNode&&n.parentNode.replaceChild(this.render(),n)}
/**
   * Handle UL, OL and LI tags paste and returns List data
   *
   * @param {HTMLUListElement|HTMLOListElement|HTMLLIElement} element
   * @returns {ListData}
   */pasteHandler(t){const{tagName:r}=t;let n,s="unordered";switch(r){case"OL":s="ordered",n="ol";break;case"UL":case"LI":s="unordered",n="ul"}const o={style:s,items:[]},i=t=>Array.from(t.querySelectorAll(":scope > li")).map((t=>{var r;const s=t.querySelector(`:scope > ${n}`),o=s?i(s):[];return{content:((r=t==null?void 0:t.firstChild)==null?void 0:r.textContent)||"",items:o}}));return o.items=i(t),o
/**
   * Renders children list
   *
   * @param {ListItem[]} items - items data to append
   * @param {Element} parentItem - where to append
   * @returns {void}
   */}appendItems(t,r){t.forEach((t=>{const n=this.createItem(t.content,t.items);r.appendChild(n)}))}
/**
   * Renders the single item
   *
   * @param {string} content - item content to render
   * @param {ListItem[]} [items] - children
   * @returns {Element}
   */createItem(t,r=[]){const n=p("li",this.CSS.item),s=p("div",this.CSS.itemBody),o=p("div",this.CSS.itemContent,{innerHTML:t,contentEditable:(!this.readOnly).toString()});return s.appendChild(o),n.appendChild(s),r&&r.length>0&&this.addChildrenList(n,r),n
/**
   * Extracts tool's data from the DOM
   *
   * @returns {ListData}
   */}save(){const e=t=>Array.from(t.querySelectorAll(`:scope > .${this.CSS.item}`)).map((t=>{const r=t.querySelector(`.${this.CSS.itemChildren}`),n=this.getItemContent(t),s=r?e(r):[];return{content:n,items:s}}));return{style:this.data.style,items:this.nodes.wrapper?e(this.nodes.wrapper):[]}}
/**
   * Append children list to passed item
   *
   * @param {Element} parentItem - item that should contain passed sub-items
   * @param {ListItem[]} items - sub items to append
   */addChildrenList(t,r){const n=t.querySelector(`.${this.CSS.itemBody}`),s=this.makeListWrapper(void 0,[this.CSS.itemChildren]);this.appendItems(r,s),n&&n.appendChild(s)
/**
   * Creates main <ul> or <ol> tag depended on style
   *
   * @param {string} [style] - 'ordered' or 'unordered'
   * @param {string[]} [classes] - additional classes to append
   * @returns {HTMLOListElement|HTMLUListElement}
   */}makeListWrapper(t=this.listStyle,r=[]){const n=t==="ordered"?"ol":"ul",s=t==="ordered"?this.CSS.wrapperOrdered:this.CSS.wrapperUnordered;return r.push(s),p(n,[this.CSS.wrapper,...r])
/**
   * Styles
   *
   * @returns {NestedListCssClasses} - CSS classes names by keys
   * @private
   */}get CSS(){return{baseBlock:this.api.styles.block,wrapper:"cdx-nested-list",wrapperOrdered:"cdx-nested-list--ordered",wrapperUnordered:"cdx-nested-list--unordered",item:"cdx-nested-list__item",itemBody:"cdx-nested-list__item-body",itemContent:"cdx-nested-list__item-content",itemChildren:"cdx-nested-list__item-children",settingsWrapper:"cdx-nested-list__settings",settingsButton:this.api.styles.settingsButton,settingsButtonActive:this.api.styles.settingsButtonActive}}
/**
   * Get list style name
   *
   * @returns {string}
   */get listStyle(){return this.data.style||this.defaultListStyle}
/**
   * Set list style
   *
   * @param {ListDataStyle} style - new style to set
   */set listStyle(t){if(!this.nodes||!this.nodes.wrapper)return;const r=Array.from(this.nodes.wrapper.querySelectorAll(`.${this.CSS.wrapper}`));r.push(this.nodes.wrapper),r.forEach((r=>{r.classList.toggle(this.CSS.wrapperUnordered,t==="unordered"),r.classList.toggle(this.CSS.wrapperOrdered,t==="ordered")})),this.data.style=t
/**
   * Returns current List item by the caret position
   *
   * @returns {Element}
   */}get currentItem(){const t=window.getSelection();if(!t)return null;let r=t.anchorNode;return r&&(c(r)||(r=r.parentNode),r)&&c(r)?r.closest(`.${this.CSS.item}`):null}
/**
   * Handles Enter keypress
   *
   * @param {KeyboardEvent} event - keydown
   * @returns {void}
   */enterPressed(t){const r=this.currentItem;if(t.stopPropagation(),t.preventDefault(),t.isComposing)return;const n=!r||this.getItemContent(r).trim().length===0,s=(r==null?void 0:r.parentNode)===this.nodes.wrapper,o=(r==null?void 0:r.nextElementSibling)===null;if(s&&o&&n){this.getOutOfList();return}if(o&&n){this.unshiftItem();return}const a=u.extractFragmentFromCaretPositionTillTheEnd();if(!a)return;const d=g(a),l=r==null?void 0:r.querySelector(`.${this.CSS.itemChildren}`),h=this.createItem(d,void 0);l&&Array.from(l.querySelectorAll(`.${this.CSS.item}`)).length>0?l.prepend(h):r==null||r.after(h),this.focusItem(h)
/**
   * Decrease indentation of the current item
   *
   * @returns {void}
   */}unshiftItem(){const t=this.currentItem;if(!t||!t.parentNode||!c(t.parentNode))return;const r=t.parentNode.closest(`.${this.CSS.item}`);if(!r)return;this.caret.save(),r.after(t),this.caret.restore();const n=r.querySelector(`.${this.CSS.itemChildren}`);n&&n.children.length===0&&n.remove()}
/**
   * Return the item content
   *
   * @param {Element} item - item wrapper (<li>)
   * @returns {string}
   */getItemContent(t){const r=t.querySelector(`.${this.CSS.itemContent}`);return!r||C(r)?"":r.innerHTML}
/**
   * Sets focus to the item's content
   *
   * @param {Element} item - item (<li>) to select
   * @param {boolean} atStart - where to set focus: at the start or at the end
   * @returns {void}
   */focusItem(t,r=!0){const n=t.querySelector(`.${this.CSS.itemContent}`);n&&u.focus(n,r)}
/**
   * Get out from List Tool by Enter on the empty last item
   *
   * @returns {void}
   */getOutOfList(){var t;(t=this.currentItem)==null||t.remove(),this.api.blocks.insert(),this.api.caret.setToBlock(this.api.blocks.getCurrentBlockIndex())
/**
   * Handle backspace
   *
   * @param {KeyboardEvent} event - keydown
   */}backspace(t){if(!u.isAtStart())return;t.preventDefault();const r=this.currentItem;if(!r)return;const n=r.previousSibling;if(!r.parentNode||!c(r.parentNode))return;const s=r.parentNode.closest(`.${this.CSS.item}`);if(!n&&!s||n&&!c(n))return;t.stopPropagation();let o;if(n){const t=n.querySelectorAll(`.${this.CSS.item}`);o=Array.from(t).pop()||n}else o=s;const a=u.extractFragmentFromCaretPositionTillTheEnd();if(!a)return;const d=g(a);if(!o)return;const l=o.querySelector(`.${this.CSS.itemContent}`);if(!l)return;u.focus(l,!1),this.caret.save(),l.insertAdjacentHTML("beforeend",d);let h=r.querySelectorAll(`.${this.CSS.itemChildren} > .${this.CSS.item}`);h=Array.from(h),h=h.filter((t=>!(!t.parentNode||!c(t.parentNode))&&t.parentNode.closest(`.${this.CSS.item}`)===r)),h.reverse().forEach((t=>{n?o.after(t):r.after(t)})),r.remove(),this.caret.restore()
/**
   * Add indentation to current item
   *
   * @param {KeyboardEvent} event - keydown
   */}addTab(t){t.stopPropagation(),t.preventDefault();const r=this.currentItem;if(!r)return;const n=r.previousSibling;if(!n||!c(n)||!n)return;const s=n.querySelector(`.${this.CSS.itemChildren}`);if(this.caret.save(),s)s.appendChild(r);else{const t=this.makeListWrapper(void 0,[this.CSS.itemChildren]),s=n.querySelector(`.${this.CSS.itemBody}`);t.appendChild(r),s==null||s.appendChild(t)}this.caret.restore()}
/**
   * Reduce indentation for current item
   *
   * @param {KeyboardEvent} event - keydown
   * @returns {void}
   */shiftTab(t){t.stopPropagation(),t.preventDefault(),this.unshiftItem()
/**
   * Convert from list to text for conversionConfig
   *
   * @param {ListData} data
   * @returns {string}
   */}static joinRecursive(t){return t.items.map((t=>`${t.content} ${f.joinRecursive(t)}`)).join("")}static get conversionConfig(){return{export:t=>f.joinRecursive(t),import:t=>({items:[{content:t,items:[]}],style:"unordered"})}}}export{f as default};

