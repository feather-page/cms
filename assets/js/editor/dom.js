// DOM helpers for the editor's node views and menus.

export const element = (tag, className, attrs = {}, children = []) => {
  const el = document.createElement(tag)
  if (className) el.className = className
  for (const [name, value] of Object.entries(attrs)) el.setAttribute(name, value)
  el.append(...children)
  return el
}

// The controls of a node view (URL fields, file pickers, selects) are not
// fields of the record form the editor sits in: their input and change
// events stop at `el`, so the form's phx-change never sees them.
export const keepOutOfForm = (el) => {
  for (const type of ["input", "change"]) el.addEventListener(type, (event) => event.stopPropagation())
  return el
}
