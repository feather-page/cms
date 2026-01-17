import { Controller } from '@hotwired/stimulus'
import ApiClient from 'utils/ApiClient'

export default class extends Controller {
  static values = { searchUrl: String }
  static targets = ['query', 'results', 'title', 'author', 'isbn', 'coverUrl', 'coverPreview']

  connect () {
    this.timeout = null
  }

  search () {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => this.performSearch(), 300)
  }

  async performSearch () {
    const query = this.queryTarget.value
    if (query.length < 3) {
      this.resultsTarget.innerHTML = ''
      return
    }

    const response = await (new ApiClient()).get(
      `${this.searchUrlValue}?q=${encodeURIComponent(query)}`
    )
    const results = await response.json()
    this.displayResults(results)
  }

  displayResults (results) {
    this.resultsTarget.innerHTML = results.map(book =>
      this.resultTemplate(book)
    ).join('')
  }

  select (event) {
    const data = event.currentTarget.dataset
    this.titleTarget.value = data.title || ''
    this.authorTarget.value = data.author || ''
    if (this.hasIsbnTarget) this.isbnTarget.value = data.isbn || ''
    if (this.hasCoverUrlTarget) this.coverUrlTarget.value = data.coverUrl || ''
    if (this.hasCoverPreviewTarget && data.coverUrl) {
      this.coverPreviewTarget.innerHTML = `<img src="${data.coverUrl}" class="book-cover-preview" style="max-height: 150px;">`
    }
    this.resultsTarget.innerHTML = ''
    this.queryTarget.value = ''
  }

  resultTemplate (book) {
    const coverImg = book.cover_url
      ? `<img src="${book.cover_url}" width="40" style="margin-right: 10px;">`
      : ''
    const author = book.author || 'Unknown'

    return `<div class="search-result list-group-item list-group-item-action d-flex align-items-center"
                 style="cursor: pointer;"
                 data-action="click->book-search#select"
                 data-title="${this.escapeHtml(book.title || '')}"
                 data-author="${this.escapeHtml(author)}"
                 data-isbn="${this.escapeHtml(book.isbn || '')}"
                 data-cover-url="${this.escapeHtml(book.cover_url || '')}">
      ${coverImg}
      <div>
        <strong>${this.escapeHtml(book.title || '')}</strong>
        <br><small class="text-muted">by ${this.escapeHtml(author)}</small>
      </div>
    </div>`
  }

  escapeHtml (text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }
}
