/**
 * BookTool for Editor.js
 * Allows searching and embedding books from the site
 */

const BOOK_ICON = '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" fill="none" viewBox="0 0 24 24"><path stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 6.5C6 5.67 6.67 5 7.5 5H9c.83 0 1.5.67 1.5 1.5v11c0 .83-.67 1.5-1.5 1.5H7.5c-.83 0-1.5-.67-1.5-1.5v-11z"/><path stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.5 6.5c0-.83.67-1.5 1.5-1.5h1.5c.83 0 1.5.67 1.5 1.5v11c0 .83-.67 1.5-1.5 1.5H12c-.83 0-1.5-.67-1.5-1.5v-11z"/><path stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 6.27c0-.8.6-1.47 1.4-1.56l1.48-.17c.82-.1 1.55.54 1.55 1.37v11.18c0 .83-.73 1.47-1.55 1.37l-1.49-.17c-.79-.1-1.39-.76-1.39-1.56V6.27z"/></svg>'

export default class BookTool {
  static get toolbox () {
    return {
      icon: BOOK_ICON,
      title: 'Book'
    }
  }

  static get isReadOnlySupported () {
    return true
  }

  constructor ({ data, config, api, readOnly }) {
    this.data = {
      book_public_id: data.book_public_id || '',
      title: data.title || '',
      author: data.author || '',
      cover_url: data.cover_url || null,
      emoji: data.emoji || null
    }
    this.lookupEndpoint = config.lookupEndpoint
    this.api = api
    this.readOnly = readOnly
    this.wrapper = null
    this.searchTimeout = null
  }

  render () {
    this.wrapper = document.createElement('div')
    this.wrapper.classList.add('book-tool')

    if (this.data.book_public_id) {
      this._renderPreview()
    } else {
      this._renderSearchUI()
    }

    return this.wrapper
  }

  _renderSearchUI () {
    this.wrapper.innerHTML = ''

    const container = document.createElement('div')
    container.classList.add('book-tool__search-container')

    const searchInput = document.createElement('input')
    searchInput.type = 'text'
    searchInput.placeholder = 'Search for a book...'
    searchInput.classList.add('book-tool__search-input', 'form-control')
    searchInput.addEventListener('input', (e) => this._handleSearch(e.target.value))

    const resultsContainer = document.createElement('div')
    resultsContainer.classList.add('book-tool__results', 'list-group', 'mt-2')
    resultsContainer.style.display = 'none'

    container.appendChild(searchInput)
    container.appendChild(resultsContainer)
    this.wrapper.appendChild(container)

    this.searchInput = searchInput
    this.resultsContainer = resultsContainer
  }

  _renderPreview () {
    this.wrapper.innerHTML = ''

    const preview = document.createElement('div')
    preview.classList.add(
      'book-tool__preview',
      'd-flex',
      'align-items-center',
      'gap-2',
      'p-2',
      'bg-light',
      'rounded'
    )

    // Cover or emoji
    if (this.data.cover_url) {
      const img = document.createElement('img')
      img.src = this.data.cover_url
      img.style.maxHeight = '40px'
      img.classList.add('rounded')
      preview.appendChild(img)
    } else if (this.data.emoji) {
      const emojiSpan = document.createElement('span')
      emojiSpan.style.fontSize = '1.5rem'
      emojiSpan.textContent = this.data.emoji
      preview.appendChild(emojiSpan)
    }

    // Book info
    const info = document.createElement('div')
    info.classList.add('flex-grow-1')

    const title = document.createElement('div')
    title.classList.add('fw-semibold', 'small')
    title.textContent = this.data.title

    const author = document.createElement('div')
    author.classList.add('text-muted', 'small')
    author.textContent = this.data.author

    info.appendChild(title)
    info.appendChild(author)
    preview.appendChild(info)

    // Change button (if not read-only)
    if (!this.readOnly) {
      const changeBtn = document.createElement('button')
      changeBtn.type = 'button'
      changeBtn.classList.add('btn', 'btn-sm', 'btn-outline-secondary')
      changeBtn.textContent = 'Change'
      changeBtn.addEventListener('click', () => {
        this.data = {
          book_public_id: '',
          title: '',
          author: '',
          cover_url: null,
          emoji: null
        }
        this._renderSearchUI()
        this.searchInput?.focus()
      })
      preview.appendChild(changeBtn)
    }

    this.wrapper.appendChild(preview)
  }

  _handleSearch (query) {
    clearTimeout(this.searchTimeout)

    if (query.length < 2) {
      this.resultsContainer.style.display = 'none'
      this.resultsContainer.innerHTML = ''
      return
    }

    this.searchTimeout = setTimeout(async () => {
      try {
        const response = await fetch(`${this.lookupEndpoint}?q=${encodeURIComponent(query)}`)
        const books = await response.json()
        this._renderResults(books)
      } catch (error) {
        console.error('Book search failed:', error)
        this.resultsContainer.innerHTML = '<div class="list-group-item text-danger">Search failed</div>'
        this.resultsContainer.style.display = 'block'
      }
    }, 300)
  }

  _renderResults (books) {
    this.resultsContainer.innerHTML = ''

    if (books.length === 0) {
      this.resultsContainer.innerHTML = '<div class="list-group-item text-muted">No books found</div>'
      this.resultsContainer.style.display = 'block'
      return
    }

    books.forEach((book) => {
      const item = document.createElement('button')
      item.type = 'button'
      item.classList.add(
        'list-group-item',
        'list-group-item-action',
        'd-flex',
        'align-items-center',
        'gap-2'
      )

      // Cover or emoji
      if (book.cover_url) {
        const img = document.createElement('img')
        img.src = book.cover_url
        img.style.maxHeight = '30px'
        img.classList.add('rounded')
        item.appendChild(img)
      } else if (book.emoji) {
        const emojiSpan = document.createElement('span')
        emojiSpan.textContent = book.emoji
        item.appendChild(emojiSpan)
      }

      // Book info
      const info = document.createElement('div')
      info.classList.add('flex-grow-1')

      const title = document.createElement('div')
      title.classList.add('fw-semibold', 'small')
      title.textContent = book.title

      const author = document.createElement('div')
      author.classList.add('text-muted', 'small')
      author.textContent = book.author

      info.appendChild(title)
      info.appendChild(author)
      item.appendChild(info)

      item.addEventListener('click', () => this._selectBook(book))

      this.resultsContainer.appendChild(item)
    })

    this.resultsContainer.style.display = 'block'
  }

  _selectBook (book) {
    this.data = {
      book_public_id: book.public_id,
      title: book.title,
      author: book.author,
      cover_url: book.cover_url,
      emoji: book.emoji
    }

    this._renderPreview()
    this._dispatchChange()
  }

  _dispatchChange () {
    const blockIndex = this.api.blocks.getCurrentBlockIndex()
    const block = this.api.blocks.getBlockByIndex(blockIndex)
    block?.dispatchChange()
  }

  save () {
    return this.data
  }

  validate (savedData) {
    return !!savedData.book_public_id
  }
}
