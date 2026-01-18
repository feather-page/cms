export default class ApiClient {
  constructor () {
    this.csrfToken = document.querySelector('meta[name="csrf-token"]').getAttribute('content')
  }

  get (url) {
    return fetch(url, {
      method: 'GET',
      headers: {
        Accept: 'application/json',
        'X-CSRF-Token': this.csrfToken
      }
    })
  }

  post (url, data) {
    return fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': this.csrfToken
      },
      body: JSON.stringify(data)
    })
  }
}
