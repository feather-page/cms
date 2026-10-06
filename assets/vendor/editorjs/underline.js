// @editorjs/underline@1.2.1 downloaded from https://ga.jspm.io/npm:@editorjs/underline@1.2.1/dist/underline.mjs

(function(){try{if(typeof document<"u"){var t=document.createElement("style");t.appendChild(document.createTextNode(".cdx-underline{text-decoration:underline}")),document.head.appendChild(t)}}catch(t){console.error("vite-plugin-css-injected-by-js",t)}})();const t='<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" fill="none" viewBox="0 0 24 24"><path stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 7.5V11.5C9 12.2956 9.31607 13.0587 9.87868 13.6213C10.4413 14.1839 11.2044 14.5 12 14.5C12.7956 14.5 13.5587 14.1839 14.1213 13.6213C14.6839 13.0587 15 12.2956 15 11.5V7.5"/><path stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7.71429 18H16.2857"/></svg>',e=class s{
/**
   * @param options InlineToolConstructorOptions
   */
constructor(t){this.tag="U",this.api=t.api,this.iconClasses={base:this.api.styles.inlineToolButton,active:this.api.styles.inlineToolButtonActive}
/**
   * Class name for term-tag
   *
   * @type {string}
   */}static get CSS(){return"cdx-underline"}
/**
   * Create button element for Toolbar
   *
   * @returns {HTMLElement}
   */render(){return this.button=document.createElement("button"),this.button.type="button",this.button.classList.add(this.iconClasses.base),this.button.innerHTML=this.toolboxIcon,this.button
/**
   * Wrap/Unwrap selected fragment
   *
   * @param {Range} range - selected fragment
   */}surround(t){if(!t)return;const e=this.api.selection.findParentTag(this.tag,s.CSS);e?this.unwrap(e):this.wrap(t)}
/**
   * Wrap selection with term-tag
   *
   * @param {Range} range - selected fragment
   */wrap(t){const e=document.createElement(this.tag);e.classList.add(s.CSS),e.appendChild(t.extractContents()),t.insertNode(e),this.api.selection.expandToTag(e)
/**
   * Unwrap term-tag
   *
   * @param {HTMLElement} termWrapper - term wrapper tag
   */}unwrap(t){var e;this.api.selection.expandToTag(t);const n=window.getSelection();if(!n)return;const i=n.getRangeAt(0);if(!i)return;const o=i.extractContents();o&&((e=t.parentNode)==null||e.removeChild(t),i.insertNode(o),n.removeAllRanges(),n.addRange(i))}checkState(){var t;const e=this.api.selection.findParentTag(this.tag,s.CSS);return(t=this.button)==null||t.classList.toggle(this.iconClasses.active,!!e),!!e
/**
   * Get Tool icon's SVG
   *
   * @returns {string}
   */}get toolboxIcon(){return t}
/**
   * Sanitizer rule
   *
   * @returns {{u: {class: string}}}
   */static get sanitize(){return{u:{class:s.CSS}}}};e.isInline=!0;let n=e;export{n as default};

