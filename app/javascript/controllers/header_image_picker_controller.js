import { Controller } from '@hotwired/stimulus'
import ApiClient from 'utils/ApiClient'

export default class extends Controller {
  static targets = [
    'preview', 'searchInput', 'results', 'loading',
    'unsplashModal', 'uploadModal', 'fileInput', 'removeButton',
    'emojiInput', 'emojiDisplay', 'imageContainer', 'emojiPicker',
    'removeEmojiButton', 'addIconButton'
  ]

  static values = {
    searchUrl: String,
    createUrl: String,
    uploadUrl: String
  }

  connect () {
    this.searchTimeout = null
    this.apiClient = new ApiClient()
    this.handleClickOutside = this.handleClickOutside.bind(this)
  }

  disconnect () {
    document.removeEventListener('click', this.handleClickOutside)
  }

  openUnsplashModal (event) {
    event.preventDefault()
    this.unsplashModalTarget.showModal()
  }

  closeUnsplashModal (event) {
    event.preventDefault()
    this.unsplashModalTarget.close()
  }

  openUploadModal (event) {
    event.preventDefault()
    this.uploadModalTarget.showModal()
  }

  closeUploadModal (event) {
    event.preventDefault()
    this.uploadModalTarget.close()
  }

  openEmojiPicker (event) {
    event.preventDefault()
    event.stopPropagation()
    const isOpen = this.emojiPickerTarget.style.display !== 'none'
    if (isOpen) {
      this.closeEmojiPicker()
    } else {
      this.emojiPickerTarget.style.display = ''
      setTimeout(() => {
        document.addEventListener('click', this.handleClickOutside)
      }, 0)
    }
  }

  handleClickOutside (event) {
    const clickedInPicker = this.emojiPickerTarget.contains(event.target)
    const clickedOnDisplay = this.hasEmojiDisplayTarget && this.emojiDisplayTarget.contains(event.target)
    const clickedOnAddButton = this.hasAddIconButtonTarget && this.addIconButtonTarget.contains(event.target)

    if (!clickedInPicker && !clickedOnDisplay && !clickedOnAddButton) {
      this.closeEmojiPicker()
    }
  }

  closeEmojiPicker () {
    this.emojiPickerTarget.style.display = 'none'
    document.removeEventListener('click', this.handleClickOutside)
  }

  selectEmoji (event) {
    event.preventDefault()
    const emoji = event.currentTarget.dataset.emoji
    this.setEmoji(emoji)
    this.closeEmojiPicker()
  }

  clearEmoji (event) {
    event.preventDefault()
    this.setEmoji('')
    this.closeEmojiPicker()
  }

  setEmoji (emoji) {
    if (this.hasEmojiInputTarget) {
      this.emojiInputTarget.value = emoji
    }
    if (this.hasEmojiDisplayTarget) {
      this.emojiDisplayTarget.textContent = emoji
      this.emojiDisplayTarget.style.display = emoji ? '' : 'none'
    }
    if (this.hasRemoveEmojiButtonTarget) {
      this.removeEmojiButtonTarget.style.display = emoji ? '' : 'none'
    }
    this.updatePreviewVisibility()
  }

  removeEmoji (event) {
    event.preventDefault()
    this.setEmoji('')
  }

  updatePreviewVisibility () {
    if (!this.hasPreviewTarget) return

    const hasImage = this.hasImageContainerTarget &&
      this.imageContainerTarget.style.display !== 'none' &&
      this.imageContainerTarget.innerHTML.trim() !== ''
    const hasEmoji = this.hasEmojiInputTarget && this.emojiInputTarget.value

    this.previewTarget.style.display = (hasImage || hasEmoji) ? '' : 'none'
  }

  search () {
    clearTimeout(this.searchTimeout)
    this.searchTimeout = setTimeout(() => this.performSearch(), 300)
  }

  async performSearch () {
    const query = this.searchInputTarget.value

    if (query.length < 2) {
      this.resultsTarget.innerHTML = ''
      return
    }

    this.showLoading()

    try {
      const response = await this.apiClient.get(
        `${this.searchUrlValue}?q=${encodeURIComponent(query)}`
      )
      const results = await response.json()

      this.displayResults(results)
    } catch (error) {
      console.error('Search failed:', error)
      this.resultsTarget.innerHTML = '<div class="alert alert-danger">Search failed. Please try again.</div>'
    } finally {
      this.hideLoading()
    }
  }

  displayResults (results) {
    if (results.length === 0) {
      this.resultsTarget.innerHTML = '<div class="text-muted text-center">No results found</div>'
      return
    }

    this.resultsTarget.innerHTML = results.map(img =>
      this.resultTemplate(img)
    ).join('')
  }

  resultTemplate (img) {
    return `
      <div class="col-md-4">
        <div class="card h-100" style="cursor: pointer;"
             data-action="click->header-image-picker#selectUnsplash"
             data-unsplash-id="${img.id}"
             data-url="${img.thumbnail_url}">
          <img src="${img.thumbnail_url}"
               class="card-img-top"
               alt="${this.escapeHtml(img.description || '')}"
               style="height: 150px; object-fit: cover;">
          <div class="card-body p-2">
            <small class="text-muted">
              Photo by <a href="${img.photographer_url}" target="_blank" rel="noopener">${this.escapeHtml(img.photographer_name)}</a>
            </small>
          </div>
        </div>
      </div>
    `
  }

  async selectUnsplash (event) {
    const card = event.currentTarget.closest('[data-unsplash-id]')
    const unsplashId = card.dataset.unsplashId
    const url = card.dataset.url

    try {
      const response = await this.apiClient.post(
        this.createUrlValue,
        { unsplash_id: unsplashId }
      )
      const data = await response.json()

      if (data.success) {
        this.updatePreview(url)
        this.updateHiddenField(data.image_id)
        this.showRemoveButton()
        this.unsplashModalTarget.close()
      } else {
        alert('Failed to select image. Please try again.')
      }
    } catch (error) {
      console.error('Failed to create image:', error)
      alert('Failed to select image. Please try again.')
    }
  }

  async upload () {
    const file = this.fileInputTarget.files[0]
    if (!file) return

    const formData = new FormData()
    formData.append('image', file)

    try {
      const response = await fetch(this.uploadUrlValue, {
        method: 'POST',
        body: formData,
        headers: {
          'X-CSRF-Token': this.apiClient.csrfToken
        }
      })

      const data = await response.json()

      if (data.success === 1) {
        this.updatePreview(URL.createObjectURL(file))
        this.updateHiddenField(data.id)
        this.showRemoveButton()
        this.uploadModalTarget.close()
      } else {
        alert('Failed to upload image. Please try again.')
      }
    } catch (error) {
      console.error('Upload failed:', error)
      alert('Failed to upload image. Please try again.')
    }
  }

  remove (event) {
    event.preventDefault()

    if (confirm('Are you sure you want to remove the cover image?')) {
      this.updateHiddenField('')
      if (this.hasImageContainerTarget) {
        this.imageContainerTarget.innerHTML = ''
        this.imageContainerTarget.style.display = 'none'
      }
      this.hideRemoveButton()
      this.updatePreviewVisibility()
    }
  }

  updatePreview (url) {
    if (this.hasImageContainerTarget) {
      this.imageContainerTarget.innerHTML = `<img src="${url}">`
      this.imageContainerTarget.style.display = ''
    }
    this.updatePreviewVisibility()
  }

  updateHiddenField (value) {
    const input = this.element.querySelector('input[type="hidden"]')
    if (input) {
      input.value = value
    }
  }

  showRemoveButton () {
    if (this.hasRemoveButtonTarget) {
      this.removeButtonTarget.style.display = ''
    }
  }

  hideRemoveButton () {
    if (this.hasRemoveButtonTarget) {
      this.removeButtonTarget.style.display = 'none'
    }
  }

  showLoading () {
    if (this.hasLoadingTarget) {
      this.loadingTarget.style.display = ''
    }
  }

  hideLoading () {
    if (this.hasLoadingTarget) {
      this.loadingTarget.style.display = 'none'
    }
  }

  escapeHtml (text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }
}
