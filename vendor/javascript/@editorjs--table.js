// @editorjs/table@2.4.4 downloaded from https://ga.jspm.io/npm:@editorjs/table@2.4.4/dist/table.mjs

(function(){var t;"use strict";try{if(typeof document<"u"){var e=document.createElement("style");e.nonce=(t=document.head.querySelector("meta[property=csp-nonce]"))==null?void 0:t.content,e.appendChild(document.createTextNode('.tc-wrap{--color-background:#f9f9fb;--color-text-secondary:#7b7e89;--color-border:#e8e8eb;--cell-size:34px;--toolbox-icon-size:18px;--toolbox-padding:6px;--toolbox-aiming-field-size:calc(var(--toolbox-icon-size) + var(--toolbox-padding)*2);border-left:0;position:relative;height:100%;width:100%;margin-top:var(--toolbox-icon-size);box-sizing:border-box;display:grid;grid-template-columns:calc(100% - var(--cell-size)) var(--cell-size);z-index:0}.tc-wrap--readonly{grid-template-columns:100% var(--cell-size)}.tc-wrap svg{vertical-align:top}@media print{.tc-wrap{border-left-color:var(--color-border);border-left-style:solid;border-left-width:1px;grid-template-columns:100% var(--cell-size)}}@media print{.tc-wrap .tc-row:after{display:none}}.tc-table{position:relative;width:100%;height:100%;display:grid;font-size:14px;border-top:1px solid var(--color-border);line-height:1.4}.tc-table:after{width:calc(var(--cell-size));height:100%;left:calc(var(--cell-size)*-1);top:0}.tc-table:after,.tc-table:before{position:absolute;content:""}.tc-table:before{width:100%;height:var(--toolbox-aiming-field-size);top:calc(var(--toolbox-aiming-field-size)*-1);left:0}.tc-table--heading .tc-row:first-child{font-weight:600;border-bottom:2px solid var(--color-border)}.tc-table--heading .tc-row:first-child [contenteditable]:empty:before{content:attr(heading);color:var(--color-text-secondary)}.tc-table--heading .tc-row:first-child:after{bottom:-2px;border-bottom:2px solid var(--color-border)}.tc-add-column,.tc-add-row{display:flex;color:var(--color-text-secondary)}@media print{.tc-add{display:none}}.tc-add-column{padding:4px 0;justify-content:center;border-top:1px solid var(--color-border)}.tc-add-column--disabled{visibility:hidden}@media print{.tc-add-column{display:none}}.tc-add-row{height:var(--cell-size);align-items:center;padding-left:4px;position:relative}.tc-add-row--disabled{display:none}.tc-add-row:before{content:"";position:absolute;right:calc(var(--cell-size)*-1);width:var(--cell-size);height:100%}@media print{.tc-add-row{display:none}}.tc-add-column,.tc-add-row{transition:0s;cursor:pointer;will-change:background-color}.tc-add-column:hover,.tc-add-row:hover{transition:background-color .1s ease;background-color:var(--color-background)}.tc-add-row{margin-top:1px}.tc-add-row:hover:before{transition:.1s;background-color:var(--color-background)}.tc-row{display:grid;grid-template-columns:repeat(auto-fit,minmax(10px,1fr));position:relative;border-bottom:1px solid var(--color-border)}.tc-row:after{content:"";pointer-events:none;position:absolute;width:var(--cell-size);height:100%;bottom:-1px;right:calc(var(--cell-size)*-1);border-bottom:1px solid var(--color-border)}.tc-row--selected{background:var(--color-background)}.tc-row--selected:after{background:var(--color-background)}.tc-cell{border-right:1px solid var(--color-border);padding:6px 12px;overflow:hidden;outline:none;line-break:normal}.tc-cell--selected{background:var(--color-background)}.tc-wrap--readonly .tc-row:after{display:none}.tc-toolbox{--toolbox-padding:6px;--popover-margin:30px;--toggler-click-zone-size:30px;--toggler-dots-color:#7b7e89;--toggler-dots-color-hovered:#1d202b;position:absolute;cursor:pointer;z-index:1;opacity:0;transition:opacity .1s;will-change:left,opacity}.tc-toolbox--column{top:calc(var(--toggler-click-zone-size)*-1);transform:translate(calc(var(--toggler-click-zone-size)*-1/2));will-change:left,opacity}.tc-toolbox--row{left:calc(var(--popover-margin)*-1);transform:translateY(calc(var(--toggler-click-zone-size)*-1/2));margin-top:-1px;will-change:top,opacity}.tc-toolbox--showed{opacity:1}.tc-toolbox .tc-popover{position:absolute;top:0;left:var(--popover-margin)}.tc-toolbox__toggler{display:flex;align-items:center;justify-content:center;width:var(--toggler-click-zone-size);height:var(--toggler-click-zone-size);color:var(--toggler-dots-color);opacity:0;transition:opacity .15s ease;will-change:opacity}.tc-toolbox__toggler:hover{color:var(--toggler-dots-color-hovered)}.tc-toolbox__toggler svg{fill:currentColor}.tc-wrap:hover .tc-toolbox__toggler{opacity:1}.tc-settings .cdx-settings-button{width:50%;margin:0}.tc-popover{--color-border:#eaeaea;--color-background:#fff;--color-background-hover:rgba(232,232,235,.49);--color-background-confirm:#e24a4a;--color-background-confirm-hover:#d54040;--color-text-confirm:#fff;background:var(--color-background);border:1px solid var(--color-border);box-shadow:0 3px 15px -3px #0d142121;border-radius:6px;padding:6px;display:none;will-change:opacity,transform}.tc-popover--opened{display:block;animation:menuShowing .1s cubic-bezier(.215,.61,.355,1) forwards}.tc-popover__item{display:flex;align-items:center;padding:2px 14px 2px 2px;border-radius:5px;cursor:pointer;white-space:nowrap;-webkit-user-select:none;-moz-user-select:none;user-select:none}.tc-popover__item:hover{background:var(--color-background-hover)}.tc-popover__item:not(:last-of-type){margin-bottom:2px}.tc-popover__item-icon{display:inline-flex;width:26px;height:26px;align-items:center;justify-content:center;background:var(--color-background);border-radius:5px;border:1px solid var(--color-border);margin-right:8px}.tc-popover__item-label{line-height:22px;font-size:14px;font-weight:500}.tc-popover__item--confirm{background:var(--color-background-confirm);color:var(--color-text-confirm)}.tc-popover__item--confirm:hover{background-color:var(--color-background-confirm-hover)}.tc-popover__item--confirm .tc-popover__item-icon{background:var(--color-background-confirm);border-color:#0000001a}.tc-popover__item--confirm .tc-popover__item-icon svg{transition:transform .2s ease-in;transform:rotate(90deg) scale(1.2)}.tc-popover__item--hidden{display:none}@keyframes menuShowing{0%{opacity:0;transform:translateY(-8px) scale(.9)}70%{opacity:1;transform:translateY(2px)}to{transform:translateY(0)}}')),document.head.appendChild(e)}}catch(t){console.error("vite-plugin-css-injected-by-js",t)}})();function c(t,e,o={}){const i=document.createElement(t);Array.isArray(e)?i.classList.add(...e):e&&i.classList.add(e);for(const t in o)Object.prototype.hasOwnProperty.call(o,t)&&(i[t]=o[t]);return i}function f(t){const e=t.getBoundingClientRect();return{y1:Math.floor(e.top+window.pageYOffset),x1:Math.floor(e.left+window.pageXOffset),x2:Math.floor(e.right+window.pageXOffset),y2:Math.floor(e.bottom+window.pageYOffset)}}function g(t,e){const o=f(t),i=f(e);return{fromTopBorder:i.y1-o.y1,fromLeftBorder:i.x1-o.x1,fromRightBorder:o.x2-i.x2,fromBottomBorder:o.y2-i.y2}}function k(t,e){const o=t.getBoundingClientRect(),{width:i,height:r,x:s,y:n}=o,{clientX:l,clientY:d}=e;return{width:i,height:r,x:l-s,y:d-n}}function m(t,e){return e.parentNode.insertBefore(t,e)}function C(t,e=!0){const o=document.createRange(),i=window.getSelection();o.selectNodeContents(t),o.collapse(e),i.removeAllRanges(),i.addRange(o)}class a{
/**
   * @param {object} options - constructor options
   * @param {PopoverItem[]} options.items - constructor options
   */
constructor({items:t}){this.items=t,this.wrapper=void 0,this.itemEls=[]
/**
   * Set of CSS classnames used in popover
   *
   * @returns {object}
   */}static get CSS(){return{popover:"tc-popover",popoverOpened:"tc-popover--opened",item:"tc-popover__item",itemHidden:"tc-popover__item--hidden",itemConfirmState:"tc-popover__item--confirm",itemIcon:"tc-popover__item-icon",itemLabel:"tc-popover__item-label"}}
/**
   * Returns the popover element
   *
   * @returns {Element}
   */render(){return this.wrapper=c("div",a.CSS.popover),this.items.forEach(((t,e)=>{const o=c("div",a.CSS.item),i=c("div",a.CSS.itemIcon,{innerHTML:t.icon}),r=c("div",a.CSS.itemLabel,{textContent:t.label});o.dataset.index=e,o.appendChild(i),o.appendChild(r),this.wrapper.appendChild(o),this.itemEls.push(o)})),this.wrapper.addEventListener("click",(t=>{this.popoverClicked(t)})),this.wrapper
/**
   * Popover wrapper click listener
   * Used to delegate clicks in items
   *
   * @returns {void}
   */}popoverClicked(t){const e=t.target.closest(`.${a.CSS.item}`);if(!e)return;const o=e.dataset.index,i=this.items[o];!i.confirmationRequired||this.hasConfirmationState(e)?i.onClick():this.setConfirmationState(e)}
/**
   * Enable the confirmation state on passed item
   *
   * @returns {void}
   */setConfirmationState(t){t.classList.add(a.CSS.itemConfirmState)}
/**
   * Disable the confirmation state on passed item
   *
   * @returns {void}
   */clearConfirmationState(t){t.classList.remove(a.CSS.itemConfirmState)}
/**
   * Check if passed item has the confirmation state
   *
   * @returns {boolean}
   */hasConfirmationState(t){return t.classList.contains(a.CSS.itemConfirmState)}
/**
   * Return an opening state
   *
   * @returns {boolean}
   */get opened(){return this.wrapper.classList.contains(a.CSS.popoverOpened)}
/**
   * Opens the popover
   *
   * @returns {void}
   */open(){this.items.forEach(((t,e)=>{typeof t.hideIf=="function"&&this.itemEls[e].classList.toggle(a.CSS.itemHidden,t.hideIf())})),this.wrapper.classList.add(a.CSS.popoverOpened)
/**
   * Closes the popover
   *
   * @returns {void}
   */}close(){this.wrapper.classList.remove(a.CSS.popoverOpened),this.itemEls.forEach((t=>{this.clearConfirmationState(t)}))}}const t='<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" fill="none" viewBox="0 0 24 24"><path stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 9L10 12M10 12L7 15M10 12H4"/><path stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 9L14 12M14 12L17 15M14 12H20"/></svg>',e='<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" fill="none" viewBox="0 0 24 24"><path stroke="currentColor" stroke-linecap="round" stroke-width="2" d="M8 8L12 12M12 12L16 16M12 12L16 8M12 12L8 16"/></svg>',o='<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" fill="none" viewBox="0 0 24 24"><path stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14.8833 9.16666L18.2167 12.5M18.2167 12.5L14.8833 15.8333M18.2167 12.5H10.05C9.16594 12.5 8.31809 12.1488 7.69297 11.5237C7.06785 10.8986 6.71666 10.0507 6.71666 9.16666"/></svg>',i='<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" fill="none" viewBox="0 0 24 24"><path stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14.9167 14.9167L11.5833 18.25M11.5833 18.25L8.25 14.9167M11.5833 18.25L11.5833 10.0833C11.5833 9.19928 11.9345 8.35143 12.5596 7.72631C13.1848 7.10119 14.0326 6.75 14.9167 6.75"/></svg>',r='<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" fill="none" viewBox="0 0 24 24"><path stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.13333 14.9167L12.4667 18.25M12.4667 18.25L15.8 14.9167M12.4667 18.25L12.4667 10.0833C12.4667 9.19928 12.1155 8.35143 11.4904 7.72631C10.8652 7.10119 10.0174 6.75 9.13333 6.75"/></svg>',s='<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" fill="none" viewBox="0 0 24 24"><path stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14.8833 15.8333L18.2167 12.5M18.2167 12.5L14.8833 9.16667M18.2167 12.5L10.05 12.5C9.16595 12.5 8.31811 12.8512 7.69299 13.4763C7.06787 14.1014 6.71667 14.9493 6.71667 15.8333"/></svg>',n='<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" fill="none" viewBox="0 0 24 24"><path stroke="currentColor" stroke-linecap="round" stroke-width="2.6" d="M9.41 9.66H9.4"/><path stroke="currentColor" stroke-linecap="round" stroke-width="2.6" d="M14.6 9.66H14.59"/><path stroke="currentColor" stroke-linecap="round" stroke-width="2.6" d="M9.31 14.36H9.3"/><path stroke="currentColor" stroke-linecap="round" stroke-width="2.6" d="M14.6 14.36H14.59"/></svg>',l='<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" fill="none" viewBox="0 0 24 24"><path stroke="currentColor" stroke-linecap="round" stroke-width="2" d="M12 7V12M12 17V12M17 12H12M12 12H7"/></svg>',d='<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" fill="none" viewBox="0 0 24 24"><path stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 9L20 12L17 15"/><path stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14 12H20"/><path stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 9L4 12L7 15"/><path stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 12H10"/></svg>',h='<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" fill="none" viewBox="0 0 24 24"><path stroke="currentColor" stroke-width="2" d="M5 10H19"/><rect width="14" height="14" x="5" y="5" stroke="currentColor" stroke-width="2" rx="4"/></svg>',p='<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" fill="none" viewBox="0 0 24 24"><path stroke="currentColor" stroke-width="2" d="M10 5V18.5"/><path stroke="currentColor" stroke-width="2" d="M14 5V18.5"/><path stroke="currentColor" stroke-width="2" d="M5 10H19"/><path stroke="currentColor" stroke-width="2" d="M5 14H19"/><rect width="14" height="14" x="5" y="5" stroke="currentColor" stroke-width="2" rx="4"/></svg>',u='<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" fill="none" viewBox="0 0 24 24"><path stroke="currentColor" stroke-width="2" d="M10 5V18.5"/><path stroke="currentColor" stroke-width="2" d="M5 10H19"/><rect width="14" height="14" x="5" y="5" stroke="currentColor" stroke-width="2" rx="4"/></svg>';class w{
/**
   * Creates toolbox buttons and toolbox menus
   *
   * @param {Object} config
   * @param {any} config.api - Editor.js api
   * @param {PopoverItem[]} config.items - Editor.js api
   * @param {function} config.onOpen - callback fired when the Popover is opening
   * @param {function} config.onClose - callback fired when the Popover is closing
   * @param {string} config.cssModifier - the modifier for the Toolbox. Allows to add some specific styles.
   */
constructor({api:t,items:e,onOpen:o,onClose:i,cssModifier:r=""}){this.api=t,this.items=e,this.onOpen=o,this.onClose=i,this.cssModifier=r,this.popover=null,this.wrapper=this.createToolbox()}static get CSS(){return{toolbox:"tc-toolbox",toolboxShowed:"tc-toolbox--showed",toggler:"tc-toolbox__toggler"}}get element(){return this.wrapper}
/**
   * Creating a toolbox to open menu for a manipulating columns
   *
   * @returns {Element}
   */createToolbox(){const t=c("div",[w.CSS.toolbox,this.cssModifier?`${w.CSS.toolbox}--${this.cssModifier}`:""]);t.dataset.mutationFree="true";const e=this.createPopover(),o=this.createToggler();return t.appendChild(o),t.appendChild(e),t
/**
   * Creates the Toggler
   *
   * @returns {Element}
   */}createToggler(){const t=c("div",w.CSS.toggler,{innerHTML:n});return t.addEventListener("click",(()=>{this.togglerClicked()})),t
/**
   * Creates the Popover instance and render it
   *
   * @returns {Element}
   */}createPopover(){return this.popover=new a({items:this.items}),this.popover.render()
/**
   * Toggler click handler. Opens/Closes the popover
   *
   * @returns {void}
   */}togglerClicked(){this.popover.opened?(this.popover.close(),this.onClose()):(this.popover.open(),this.onOpen()
/**
   * Shows the Toolbox
   *
   * @param {function} computePositionMethod - method that returns the position coordinate
   * @returns {void}
   */)}show(t){const e=t();Object.entries(e).forEach((([t,e])=>{this.wrapper.style[t]=e})),this.wrapper.classList.add(w.CSS.toolboxShowed)
/**
   * Hides the Toolbox
   *
   * @returns {void}
   */}hide(){this.popover.close(),this.wrapper.classList.remove(w.CSS.toolboxShowed)}}function B(t,e){let o=0;return function(...i){const r=(new Date).getTime();if(!(r-o<t))return o=r,e(...i)}}const b={wrapper:"tc-wrap",wrapperReadOnly:"tc-wrap--readonly",table:"tc-table",row:"tc-row",withHeadings:"tc-table--heading",rowSelected:"tc-row--selected",cell:"tc-cell",cellSelected:"tc-cell--selected",addRow:"tc-add-row",addRowDisabled:"tc-add-row--disabled",addColumn:"tc-add-column",addColumnDisabled:"tc-add-column--disabled"};class E{
/**
   * Creates
   *
   * @constructor
   * @param {boolean} readOnly - read-only mode flag
   * @param {object} api - Editor.js API
   * @param {TableData} data - Editor.js API
   * @param {TableConfig} config - Editor.js API
   */
constructor(t,e,o,i){this.readOnly=t,this.api=e,this.data=o,this.config=i,this.wrapper=null,this.table=null,this.toolboxColumn=this.createColumnToolbox(),this.toolboxRow=this.createRowToolbox(),this.createTableWrapper(),this.hoveredRow=0,this.hoveredColumn=0,this.selectedRow=0,this.selectedColumn=0,this.tunes={withHeadings:!1},this.resize(),this.fill(),this.focusedCell={row:0,column:0},this.documentClicked=t=>{const e=t.target.closest(`.${b.table}`)!==null,o=t.target.closest(`.${b.wrapper}`)===null;(e||o)&&this.hideToolboxes();const i=t.target.closest(`.${b.addRow}`),r=t.target.closest(`.${b.addColumn}`);i&&i.parentNode===this.wrapper?(this.addRow(void 0,!0),this.hideToolboxes()):r&&r.parentNode===this.wrapper&&(this.addColumn(void 0,!0),this.hideToolboxes())},this.readOnly||this.bindEvents()
/**
   * Returns the rendered table wrapper
   *
   * @returns {Element}
   */}getWrapper(){return this.wrapper}bindEvents(){document.addEventListener("click",this.documentClicked),this.table.addEventListener("mousemove",B(150,(t=>this.onMouseMoveInTable(t))),{passive:!0}),this.table.onkeypress=t=>this.onKeyPressListener(t),this.table.addEventListener("keydown",(t=>this.onKeyDownListener(t))),this.table.addEventListener("focusin",(t=>this.focusInTableListener(t)))
/**
   * Configures and creates the toolbox for manipulating with columns
   *
   * @returns {Toolbox}
   */}createColumnToolbox(){return new w({api:this.api,cssModifier:"column",items:[{label:this.api.i18n.t("Add column to left"),icon:i,hideIf:()=>this.numberOfColumns===this.config.maxcols,onClick:()=>{this.addColumn(this.selectedColumn,!0),this.hideToolboxes()}},{label:this.api.i18n.t("Add column to right"),icon:r,hideIf:()=>this.numberOfColumns===this.config.maxcols,onClick:()=>{this.addColumn(this.selectedColumn+1,!0),this.hideToolboxes()}},{label:this.api.i18n.t("Delete column"),icon:e,hideIf:()=>this.numberOfColumns===1,confirmationRequired:!0,onClick:()=>{this.deleteColumn(this.selectedColumn),this.hideToolboxes()}}],onOpen:()=>{this.selectColumn(this.hoveredColumn),this.hideRowToolbox()},onClose:()=>{this.unselectColumn()}})}
/**
   * Configures and creates the toolbox for manipulating with rows
   *
   * @returns {Toolbox}
   */createRowToolbox(){return new w({api:this.api,cssModifier:"row",items:[{label:this.api.i18n.t("Add row above"),icon:s,hideIf:()=>this.numberOfRows===this.config.maxrows,onClick:()=>{this.addRow(this.selectedRow,!0),this.hideToolboxes()}},{label:this.api.i18n.t("Add row below"),icon:o,hideIf:()=>this.numberOfRows===this.config.maxrows,onClick:()=>{this.addRow(this.selectedRow+1,!0),this.hideToolboxes()}},{label:this.api.i18n.t("Delete row"),icon:e,hideIf:()=>this.numberOfRows===1,confirmationRequired:!0,onClick:()=>{this.deleteRow(this.selectedRow),this.hideToolboxes()}}],onOpen:()=>{this.selectRow(this.hoveredRow),this.hideColumnToolbox()},onClose:()=>{this.unselectRow()}})}moveCursorToNextRow(){this.focusedCell.row!==this.numberOfRows?(this.focusedCell.row+=1,this.focusCell(this.focusedCell)):(this.addRow(),this.focusedCell.row+=1,this.focusCell(this.focusedCell),this.updateToolboxesPosition(0,0)
/**
   * Get table cell by row and col index
   *
   * @param {number} row - cell row coordinate
   * @param {number} column - cell column coordinate
   * @returns {HTMLElement}
   */)}getCell(t,e){return this.table.querySelectorAll(`.${b.row}:nth-child(${t}) .${b.cell}`)[e-1]}
/**
   * Get table row by index
   *
   * @param {number} row - row coordinate
   * @returns {HTMLElement}
   */getRow(t){return this.table.querySelector(`.${b.row}:nth-child(${t})`)}
/**
   * The parent of the cell which is the row
   *
   * @param {HTMLElement} cell - cell element
   * @returns {HTMLElement}
   */getRowByCell(t){return t.parentElement}
/**
   * Ger row's first cell
   *
   * @param {Element} row - row to find its first cell
   * @returns {Element}
   */getRowFirstCell(t){return t.querySelector(`.${b.cell}:first-child`)}
/**
   * Set the sell's content by row and column numbers
   *
   * @param {number} row - cell row coordinate
   * @param {number} column - cell column coordinate
   * @param {string} content - cell HTML content
   */setCellContent(t,e,o){const i=this.getCell(t,e);i.innerHTML=o}
/**
   * Add column in table on index place
   * Add cells in each row
   *
   * @param {number} columnIndex - number in the array of columns, where new column to insert, -1 if insert at the end
   * @param {boolean} [setFocus] - pass true to focus the first cell
   */addColumn(t=-1,e=!1){var o;let i=this.numberOfColumns;if(this.config&&this.config.maxcols&&this.numberOfColumns>=this.config.maxcols)return;for(let o=1;o<=this.numberOfRows;o++){let r;const s=this.createCell();if(t>0&&t<=i?(r=this.getCell(o,t),m(s,r)):r=this.getRow(o).appendChild(s),o===1){const r=this.getCell(o,t>0?t:i+1);r&&e&&C(r)}}const r=this.wrapper.querySelector(`.${b.addColumn}`);(o=this.config)!=null&&o.maxcols&&this.numberOfColumns>this.config.maxcols-1&&r&&r.classList.add(b.addColumnDisabled),this.addHeadingAttrToFirstRow()
/**
   * Add row in table on index place
   *
   * @param {number} index - number in the array of rows, where new column to insert, -1 if insert at the end
   * @param {boolean} [setFocus] - pass true to focus the inserted row
   * @returns {HTMLElement} row
   */}addRow(t=-1,e=!1){let o,i=c("div",b.row);this.tunes.withHeadings&&this.removeHeadingAttrFromFirstRow();let r=this.numberOfColumns;if(this.config&&this.config.maxrows&&this.numberOfRows>=this.config.maxrows&&n)return;if(t>0&&t<=this.numberOfRows){let e=this.getRow(t);o=m(i,e)}else o=this.table.appendChild(i);this.fillRow(o,r),this.tunes.withHeadings&&this.addHeadingAttrToFirstRow();const s=this.getRowFirstCell(o);s&&e&&C(s);const n=this.wrapper.querySelector(`.${b.addRow}`);return this.config&&this.config.maxrows&&this.numberOfRows>=this.config.maxrows&&n&&n.classList.add(b.addRowDisabled),o
/**
   * Delete a column by index
   *
   * @param {number} index
   */}deleteColumn(t){for(let e=1;e<=this.numberOfRows;e++){const o=this.getCell(e,t);if(!o)return;o.remove()}const e=this.wrapper.querySelector(`.${b.addColumn}`);e&&e.classList.remove(b.addColumnDisabled)}
/**
   * Delete a row by index
   *
   * @param {number} index
   */deleteRow(t){this.getRow(t).remove();const e=this.wrapper.querySelector(`.${b.addRow}`);e&&e.classList.remove(b.addRowDisabled),this.addHeadingAttrToFirstRow()
/**
   * Create a wrapper containing a table, toolboxes
   * and buttons for adding rows and columns
   *
   * @returns {HTMLElement} wrapper - where all buttons for a table and the table itself will be
   */}createTableWrapper(){if(this.wrapper=c("div",b.wrapper),this.table=c("div",b.table),this.readOnly&&this.wrapper.classList.add(b.wrapperReadOnly),this.wrapper.appendChild(this.toolboxRow.element),this.wrapper.appendChild(this.toolboxColumn.element),this.wrapper.appendChild(this.table),!this.readOnly){const t=c("div",b.addColumn,{innerHTML:l}),e=c("div",b.addRow,{innerHTML:l});this.wrapper.appendChild(t),this.wrapper.appendChild(e)}}computeInitialSize(){const t=this.data&&this.data.content,e=Array.isArray(t),o=!!e&&t.length,i=e?t.length:void 0,r=o?t[0].length:void 0,s=Number.parseInt(this.config&&this.config.rows),n=Number.parseInt(this.config&&this.config.cols),l=!isNaN(s)&&s>0?s:void 0,d=!isNaN(n)&&n>0?n:void 0;return{rows:i||l||2,cols:r||d||2}}resize(){const{rows:t,cols:e}=this.computeInitialSize();for(let e=0;e<t;e++)this.addRow();for(let t=0;t<e;t++)this.addColumn()}
/**
   * Fills the table with data passed to the constructor
   *
   * @returns {void}
   */fill(){const t=this.data;if(t&&t.content)for(let e=0;e<t.content.length;e++)for(let o=0;o<t.content[e].length;o++)this.setCellContent(e+1,o+1,t.content[e][o])}
/**
   * Fills a row with cells
   *
   * @param {HTMLElement} row - row to fill
   * @param {number} numberOfColumns - how many cells should be in a row
   */fillRow(t,e){for(let o=1;o<=e;o++){const e=this.createCell();t.appendChild(e)}}createCell(){return c("div",b.cell,{contentEditable:!this.readOnly})}get numberOfRows(){return this.table.childElementCount}get numberOfColumns(){return this.numberOfRows?this.table.querySelectorAll(`.${b.row}:first-child .${b.cell}`).length:0}
/**
   * Is the column toolbox menu displayed or not
   *
   * @returns {boolean}
   */get isColumnMenuShowing(){return this.selectedColumn!==0}
/**
   * Is the row toolbox menu displayed or not
   *
   * @returns {boolean}
   */get isRowMenuShowing(){return this.selectedRow!==0}
/**
   * Recalculate position of toolbox icons
   *
   * @param {Event} event - mouse move event
   */onMouseMoveInTable(t){const{row:e,column:o}=this.getHoveredCell(t);this.hoveredColumn=o,this.hoveredRow=e,this.updateToolboxesPosition()
/**
   * Prevents default Enter behaviors
   * Adds Shift+Enter processing
   *
   * @param {KeyboardEvent} event - keypress event
   */}onKeyPressListener(t){if(t.key==="Enter"){if(t.shiftKey)return!0;this.moveCursorToNextRow()}return t.key!=="Enter"}
/**
   * Prevents tab keydown event from bubbling
   * so that it only works inside the table
   *
   * @param {KeyboardEvent} event - keydown event
   */onKeyDownListener(t){t.key==="Tab"&&t.stopPropagation()}
/**
   * Set the coordinates of the cell that the focus has moved to
   *
   * @param {FocusEvent} event - focusin event
   */focusInTableListener(t){const e=t.target,o=this.getRowByCell(e);this.focusedCell={row:Array.from(this.table.querySelectorAll(`.${b.row}`)).indexOf(o)+1,column:Array.from(o.querySelectorAll(`.${b.cell}`)).indexOf(e)+1}}
/**
   * Unselect row/column
   * Close toolbox menu
   * Hide toolboxes
   *
   * @returns {void}
   */hideToolboxes(){this.hideRowToolbox(),this.hideColumnToolbox(),this.updateToolboxesPosition()
/**
   * Unselect row, close toolbox
   *
   * @returns {void}
   */}hideRowToolbox(){this.unselectRow(),this.toolboxRow.hide()
/**
   * Unselect column, close toolbox
   *
   * @returns {void}
   */}hideColumnToolbox(){this.unselectColumn(),this.toolboxColumn.hide()
/**
   * Set the cursor focus to the focused cell
   *
   * @returns {void}
   */}focusCell(){this.focusedCellElem.focus()}
/**
   * Get current focused element
   *
   * @returns {HTMLElement} - focused cell
   */get focusedCellElem(){const{row:t,column:e}=this.focusedCell;return this.getCell(t,e)}
/**
   * Update toolboxes position
   *
   * @param {number} row - hovered row
   * @param {number} column - hovered column
   */updateToolboxesPosition(t=this.hoveredRow,e=this.hoveredColumn){this.isColumnMenuShowing||e>0&&e<=this.numberOfColumns&&this.toolboxColumn.show((()=>({left:`calc((100% - var(--cell-size)) / (${this.numberOfColumns} * 2) * (1 + (${e} - 1) * 2))`}))),this.isRowMenuShowing||t>0&&t<=this.numberOfRows&&this.toolboxRow.show((()=>{const e=this.getRow(t),{fromTopBorder:o}=g(this.table,e),{height:i}=e.getBoundingClientRect();return{top:`${Math.ceil(o+i/2)}px`}}))
/**
   * Makes the first row headings
   *
   * @param {boolean} withHeadings - use headings row or not
   */}setHeadingsSetting(t){this.tunes.withHeadings=t,t?(this.table.classList.add(b.withHeadings),this.addHeadingAttrToFirstRow()):(this.table.classList.remove(b.withHeadings),this.removeHeadingAttrFromFirstRow())}addHeadingAttrToFirstRow(){for(let t=1;t<=this.numberOfColumns;t++){let e=this.getCell(1,t);e&&e.setAttribute("heading",this.api.i18n.t("Heading"))}}removeHeadingAttrFromFirstRow(){for(let t=1;t<=this.numberOfColumns;t++){let e=this.getCell(1,t);e&&e.removeAttribute("heading")}}
/**
   * Add effect of a selected row
   *
   * @param {number} index
   */selectRow(t){const e=this.getRow(t);e&&(this.selectedRow=t,e.classList.add(b.rowSelected))}unselectRow(){if(this.selectedRow<=0)return;const t=this.table.querySelector(`.${b.rowSelected}`);t&&t.classList.remove(b.rowSelected),this.selectedRow=0
/**
   * Add effect of a selected column
   *
   * @param {number} index
   */}selectColumn(t){for(let e=1;e<=this.numberOfRows;e++){const o=this.getCell(e,t);o&&o.classList.add(b.cellSelected)}this.selectedColumn=t}unselectColumn(){if(this.selectedColumn<=0)return;let t=this.table.querySelectorAll(`.${b.cellSelected}`);Array.from(t).forEach((t=>{t.classList.remove(b.cellSelected)})),this.selectedColumn=0
/**
   * Calculates the row and column that the cursor is currently hovering over
   * The search was optimized from O(n) to O (log n) via bin search to reduce the number of calculations
   *
   * @param {Event} event - mousemove event
   * @returns hovered cell coordinates as an integer row and column
   */}getHoveredCell(t){let e=this.hoveredRow,o=this.hoveredColumn;const{width:i,height:r,x:s,y:n}=k(this.table,t);return s>=0&&(o=this.binSearch(this.numberOfColumns,(t=>this.getCell(1,t)),(({fromLeftBorder:t})=>s<t),(({fromRightBorder:t})=>s>i-t))),n>=0&&(e=this.binSearch(this.numberOfRows,(t=>this.getCell(t,1)),(({fromTopBorder:t})=>n<t),(({fromBottomBorder:t})=>n>r-t))),{row:e||this.hoveredRow,column:o||this.hoveredColumn}
/**
   * Looks for the index of the cell the mouse is hovering over.
   * Cells can be represented as ordered intervals with left and
   * right (upper and lower for rows) borders inside the table, if the mouse enters it, then this is our index
   *
   * @param {number} numberOfCells - upper bound of binary search
   * @param {function} getCell - function to take the currently viewed cell
   * @param {function} beforeTheLeftBorder - determines the cursor position, to the left of the cell or not
   * @param {function} afterTheRightBorder - determines the cursor position, to the right of the cell or not
   * @returns {number}
   */}binSearch(t,e,o,i){let r,s=0,n=t+1,l=0;for(;s<n-1&&l<10;){r=Math.ceil((s+n)/2);const t=e(r),d=g(this.table,t);if(o(d))n=r;else{if(!i(d))break;s=r}l++}return r}
/**
   * Collects data from cells into a two-dimensional array
   *
   * @returns {string[][]}
   */getData(){const t=[];for(let e=1;e<=this.numberOfRows;e++){const o=this.table.querySelector(`.${b.row}:nth-child(${e})`),i=Array.from(o.querySelectorAll(`.${b.cell}`));i.every((t=>!t.textContent.trim()))||t.push(i.map((t=>t.innerHTML)))}return t}destroy(){document.removeEventListener("click",this.documentClicked)}}class F{
/**
   * Notify core that read-only mode is supported
   *
   * @returns {boolean}
   */
static get isReadOnlySupported(){return!0}
/**
   * Allow to press Enter inside the CodeTool textarea
   *
   * @returns {boolean}
   * @public
   */static get enableLineBreaks(){return!0}
/**
   * Render plugin`s main Element and fill it with saved data
   *
   * @param {TableConstructor} init
   */constructor({data:t,config:e,api:o,readOnly:i,block:r}){this.api=o,this.readOnly=i,this.config=e,this.data={withHeadings:this.getConfig("withHeadings",!1,t),stretched:this.getConfig("stretched",!1,t),content:t&&t.content?t.content:[]},this.table=null,this.block=r
/**
   * Get Tool toolbox settings
   * icon - Tool icon's SVG
   * title - title to show in toolbox
   *
   * @returns {{icon: string, title: string}}
   */}static get toolbox(){return{icon:u,title:"Table"}}
/**
   * Return Tool's view
   *
   * @returns {HTMLDivElement}
   */render(){return this.table=new E(this.readOnly,this.api,this.data,this.config),this.container=c("div",this.api.styles.block),this.container.appendChild(this.table.getWrapper()),this.table.setHeadingsSetting(this.data.withHeadings),this.container
/**
   * Returns plugin settings
   *
   * @returns {Array}
   */}renderSettings(){return[{label:this.api.i18n.t("With headings"),icon:h,isActive:this.data.withHeadings,closeOnActivate:!0,toggle:!0,onActivate:()=>{this.data.withHeadings=!0,this.table.setHeadingsSetting(this.data.withHeadings)}},{label:this.api.i18n.t("Without headings"),icon:p,isActive:!this.data.withHeadings,closeOnActivate:!0,toggle:!0,onActivate:()=>{this.data.withHeadings=!1,this.table.setHeadingsSetting(this.data.withHeadings)}},{label:this.data.stretched?this.api.i18n.t("Collapse"):this.api.i18n.t("Stretch"),icon:this.data.stretched?t:d,closeOnActivate:!0,toggle:!0,onActivate:()=>{this.data.stretched=!this.data.stretched,this.block.stretched=this.data.stretched}}]}
/**
   * Extract table data from the view
   *
   * @returns {TableData} - saved data
   */save(){const t=this.table.getData();return{withHeadings:this.data.withHeadings,stretched:this.data.stretched,content:t}}
/**
   * Plugin destroyer
   *
   * @returns {void}
   */destroy(){this.table.destroy()}
/**
   * A helper to get config value.
   *
   * @param {string} configName - the key to get from the config.
   * @param {any} defaultValue - default value if config doesn't have passed key
   * @param {object} savedData - previously saved data. If passed, the key will be got from there, otherwise from the config
   * @returns {any} - config value.
   */getConfig(t,e=void 0,o=void 0){const i=this.data||o;return i?i[t]?i[t]:e:this.config&&this.config[t]?this.config[t]:e}static get pasteConfig(){return{tags:["TABLE","TR","TH","TD"]}}
/**
   * On paste callback that is fired from Editor
   *
   * @param {PasteEvent} event - event with pasted data
   */onPaste(t){const e=t.detail.data,o=e.querySelector(":scope > thead, tr:first-of-type th"),i=Array.from(e.querySelectorAll("tr")).map((t=>Array.from(t.querySelectorAll("th, td")).map((t=>t.innerHTML))));this.data={withHeadings:o!==null,content:i},this.table.wrapper&&this.table.wrapper.replaceWith(this.render())}}export{F as default};

