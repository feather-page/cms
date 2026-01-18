import { Controller } from '@hotwired/stimulus'

const THEME_KEY = 'feather-theme'
const DARK = 'dark'
const LIGHT = 'light'

export default class extends Controller {
  static targets = ['icon']

  connect () {
    this.applyTheme(this.currentTheme)
  }

  toggle () {
    const newTheme = this.currentTheme === DARK ? LIGHT : DARK
    this.applyTheme(newTheme)
    this.saveTheme(newTheme)
  }

  applyTheme (theme) {
    if (theme === DARK) {
      document.documentElement.setAttribute('data-theme', DARK)
    } else {
      document.documentElement.removeAttribute('data-theme')
    }
    this.updateIcon(theme)
  }

  updateIcon (theme) {
    if (!this.hasIconTarget) return

    if (theme === DARK) {
      this.iconTarget.classList.remove('bi-moon')
      this.iconTarget.classList.add('bi-sun')
    } else {
      this.iconTarget.classList.remove('bi-sun')
      this.iconTarget.classList.add('bi-moon')
    }
  }

  saveTheme (theme) {
    window.localStorage.setItem(THEME_KEY, theme)
  }

  get currentTheme () {
    // Check localStorage first
    const saved = window.localStorage.getItem(THEME_KEY)
    if (saved) return saved

    // Fall back to system preference
    if (window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches) {
      return DARK
    }

    return LIGHT
  }
}
