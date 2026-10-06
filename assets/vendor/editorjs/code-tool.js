(function(){"use strict";try{if(typeof document<"u"){var e=document.createElement("style");e.appendChild(document.createTextNode(".ce-code__textarea{min-height:200px;font-family:Menlo,Monaco,Consolas,Courier New,monospace;color:#41314e;line-height:1.6em;font-size:12px;background:#f8f7fa;box-shadow:none;white-space:pre;word-wrap:normal;overflow-x:auto;resize:vertical}.ce-code select,.ce-code .select{width:100%}.ce-code .select{margin-top:.1em}")),document.head.appendChild(e)}}catch(o){console.error("vite-plugin-css-injected-by-js",o)}})();
function d(c, e) {
  let a = "";
  for (; a !== `
` && e > 0; )
    e = e - 1, a = c.substr(e, 1);
  return a === `
` && (e += 1), e;
}
const h = '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" fill="none" viewBox="0 0 24 24"><path stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 8L5 12L9 16"/><path stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 8L19 12L15 16"/></svg>';
/**
 * CodeTool for Editor.js
 * @version 2.0.0
 * @license MIT
 */
class o {
  /**
   * Notify core that read-only mode is supported
   * @returns true if read-only mode is supported
   */
  static get isReadOnlySupported() {
    return !0;
  }
  /**
   * Allows pressing Enter key to create line breaks inside the CodeTool textarea
   * This enables multi-line input within the code editor.
   * @returns true if line breaks are allowed in the textarea
   */
  static get enableLineBreaks() {
    return !0;
  }
  /**
   * Render plugin`s main Element and fill it with saved data
   * @param options - tool constricting options
   * @param options.data — previously saved plugin code
   * @param options.config - user config for Tool
   * @param options.api - Editor.js API
   * @param options.readOnly - read only mode flag
   */
  constructor({ data: e, config: t, api: a, readOnly: s }) {
    this.api = a, this.readOnly = s, this.placeholder = this.api.i18n.t(t.placeholder || o.DEFAULT_PLACEHOLDER), this.languages = t.languages, this.CSS = {
      baseClass: this.api.styles.block,
      input: this.api.styles.input,
      wrapper: "ce-code",
      textarea: "ce-code__textarea"
    }, this.nodes = {
      holder: null,
      textarea: null,
      languageSelector: null
    }, this.data = {
      code: e.code ?? "",
      language: e.language ?? ""
    }, this.nodes.holder = this.drawView();
  }
  /**
   * Return Tool's view
   * @returns this.nodes.holder - Code's wrapper
   */
  render() {
    return this.nodes.holder;
  }
  /**
   * Extract Tool's data from the view
   * @param codeWrapper - CodeTool's wrapper, containing textarea with code
   * @returns - saved plugin code
   */
  save(e) {
    return {
      code: e.querySelector("textarea").value,
      language: e.querySelector("select").value
    };
  }
  /**
   * onPaste callback fired from Editor`s core
   * @param event - event with pasted content
   */
  onPaste(e) {
    const t = e.detail;
    if ("data" in t) {
      const a = t.data;
      this.data = {
        code: a || "",
        language: ""
      };
    }
  }
  /**
   * Returns Tool`s data from private property
   * @returns
   */
  get data() {
    return this._data;
  }
  /**
   * Set Tool`s data to private property and update view
   * @param data - saved tool data
   */
  set data(e) {
    this._data = e, this.nodes.textarea && (this.nodes.textarea.textContent = e.code), this.nodes.languageSelector && (this.nodes.languageSelector.value = e.language);
  }
  /**
   * Get Tool toolbox settings.
   * Provides the icon and title to display in the toolbox for the CodeTool.
   * @returns An object containing:
   * - icon: SVG representation of the Tool's icon
   * - title: Title to show in the toolbox
   */
  static get toolbox() {
    return {
      icon: h,
      title: "Code"
    };
  }
  /**
   * Default placeholder for CodeTool's textarea
   * @returns
   */
  static get DEFAULT_PLACEHOLDER() {
    return "Enter a code";
  }
  /**
   *  Used by Editor.js paste handling API.
   *  Provides configuration to handle CODE tag.
   * @returns
   */
  static get pasteConfig() {
    return {
      tags: ["pre"]
    };
  }
  /**
   * Automatic sanitize config
   * @returns
   */
  static get sanitize() {
    return {
      // Allow HTML tags
      code: !0,
      language: !0
    };
  }
  /**
   * Handles Tab key pressing (adds/removes indentations)
   * @param event - keydown
   */
  tabHandler(e) {
    e.stopPropagation(), e.preventDefault();
    const t = e.target, a = e.shiftKey, s = t.selectionStart, n = t.value, r = "  ";
    let i;
    if (!a)
      i = s + r.length, t.value = n.substring(0, s) + r + n.substring(s);
    else {
      const l = d(n, s);
      if (n.substr(l, r.length) !== r)
        return;
      t.value = n.substring(0, l) + n.substring(l + r.length), i = s - r.length;
    }
    t.setSelectionRange(i, i);
  }
  /**
   * Create Tool's view
   * @returns
   */
  drawView() {
    const e = document.createElement("div"), t = document.createElement("textarea"), a = this.languageSelector();
    return e.classList.add(this.CSS.baseClass, this.CSS.wrapper), t.classList.add(this.CSS.textarea, this.CSS.input), t.textContent = this.data.code, t.placeholder = this.placeholder, this.readOnly && (t.disabled = !0), e.appendChild(t), e.appendChild(a), t.addEventListener("keydown", (s) => {
      switch (s.code) {
        case "Tab":
          this.tabHandler(s);
          break;
      }
    }), this.nodes.textarea = t, this.nodes.languageSelector = a, e;
  }
  /**
   * Create the programming language selector dropdown
   */
  languageSelector() {
    const e = document.createElement("select");
    e.addEventListener("change", this.dispatchChangeEvent.bind(this)), e.classList.add("ce-code__language-selector");
    for (const a in this.languages) {
      const s = document.createElement("option");
      s.value = a, s.text = this.languages[a], s.selected = a === this.data.language, e.appendChild(s);
    }
    const t = document.createElement("div");
    return t.classList.add("select"), t.classList.add("is-small"), t.appendChild(e), t;
  }
  dispatchChangeEvent() {
    var e;
    (e = this.api.blocks.getBlockByIndex(this.api.blocks.getCurrentBlockIndex())) == null || e.dispatchChange();
  }
}
export {
  o as default
};
