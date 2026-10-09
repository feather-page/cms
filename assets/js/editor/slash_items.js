// The entries of the slash menu (slash_menu.js). A block type offers itself
// by registering an item, in the order the menu shows it:
//
//   registerSlashItem({
//     name: "image",                    // unique; typing a prefix of it finds the item
//     label: "Image",                   // shown, typing any part of it finds the item
//     icon: "▣",                        // a short text in front of the label
//     keywords: ["picture", "photo"],   // more prefixes that find the item
//     create: (schema) => schema.nodes.image.create()
//   })
//
// `create` returns a new top-level node. Choosing the item puts it in place
// of the block the slash was typed in when that block is empty (the node
// takes over the block's id), otherwise right after that block. The cursor
// goes to the node's first text, or the node is selected when it has none.
import {schema} from "./schema"

const items = []

export function registerSlashItem(item) {
  if (items.some(({name}) => name === item.name)) throw new Error(`Slash menu item "${item.name}" already exists`)
  items.push({keywords: [], ...item})
}

const normalize = (text) => text.normalize("NFKC").trim().toLowerCase()

// The items matching what was typed after the slash, all for an empty query.
export function slashItems(query = "") {
  const typed = normalize(query)

  return items.filter(
    ({name, label, keywords}) =>
      normalize(label).includes(typed) || [name, ...keywords].some((word) => normalize(word).startsWith(typed))
  )
}

const {nodes} = schema

registerSlashItem({
  name: "paragraph",
  label: "Text",
  icon: "Aa",
  keywords: ["text", "plain"],
  create: () => nodes.paragraph.create()
})

for (const level of [2, 3, 4]) {
  registerSlashItem({
    name: `heading${level}`,
    label: `Heading ${level}`,
    icon: `H${level}`,
    keywords: [`h${level}`, "title"],
    create: () => nodes.heading.create({level})
  })
}

registerSlashItem({
  name: "bullet_list",
  label: "Bulleted list",
  icon: "•",
  keywords: ["ul", "unordered", "-"],
  create: () => nodes.bullet_list.createAndFill()
})

registerSlashItem({
  name: "ordered_list",
  label: "Numbered list",
  icon: "1.",
  keywords: ["ol", "ordered", "1."],
  create: () => nodes.ordered_list.createAndFill()
})

registerSlashItem({
  name: "quote",
  label: "Quote",
  icon: "❝",
  keywords: ["blockquote", "citation", ">"],
  create: () => nodes.quote.createAndFill()
})

registerSlashItem({
  name: "code_block",
  label: "Code",
  icon: "</>",
  keywords: ["pre", "snippet", "```"],
  create: () => nodes.code_block.create()
})
