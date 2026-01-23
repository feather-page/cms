# Pin npm packages by running ./bin/importmap
pin 'application', preload: true

pin_all_from 'app/javascript/controllers', under: 'controllers'
pin_all_from 'app/javascript/utils', under: 'utils'

pin '@hotwired/turbo-rails', to: 'turbo.min.js', preload: true
pin '@hotwired/stimulus', to: 'stimulus.min.js', preload: true
pin '@hotwired/stimulus-loading', to: 'stimulus-loading.js', preload: true

pin "@editorjs/editorjs", to: "@editorjs--editorjs.js" # @2.31.0
pin "@editorjs/list", to: "@editorjs--list.js" # @2.0.8
pin "@editorjs/quote", to: "@editorjs--quote.js" # @2.7.6
pin '@editorjs/nested-list', to: '@editorjs--nested-list.js' # @1.4.3
pin "@editorjs/underline", to: "@editorjs--underline.js" # @1.2.1
pin "@editorjs/table", to: "@editorjs--table.js" # @2.4.5
pin "@editorjs/inline-code", to: "@editorjs--inline-code.js" # @1.5.2
pin "@editorjs/header", to: "@editorjs--header.js" # @2.8.8
pin "@editorjs/image", to: "@editorjs--image.js" # @2.10.3
pin "@editorjs/code", to: "code-tool.js"
pin "@editorjs/book", to: "book-tool.js"
pin "@editorjs/embed", to: "@editorjs--embed.js" # @2.7.6
pin "bootstrap", to: "bootstrap.min.js", preload: true
pin "@popperjs/core", to: "popper.js", preload: true
