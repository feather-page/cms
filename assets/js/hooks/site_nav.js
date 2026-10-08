// The section navigation of a site scrolls sideways on narrow screens: keep
// the active link in view and mark the edges that have more links behind
// them (data-more="start|end|both"), which app.css fades out.
export default {
  mounted() {
    this.list = this.el.querySelector(".nav")
    this.update = () => this.markEdges()
    this.list.addEventListener("scroll", this.update, {passive: true})
    window.addEventListener("resize", this.update)
    this.revealActive()
    this.markEdges()
  },
  updated() {
    this.markEdges()
  },
  destroyed() {
    window.removeEventListener("resize", this.update)
  },
  revealActive() {
    const active = this.list.querySelector(".active")
    if (!active) return
    const {clientWidth} = this.list
    if (active.offsetLeft + active.offsetWidth > clientWidth)
      this.list.scrollLeft = active.offsetLeft - (clientWidth - active.offsetWidth) / 2
  },
  markEdges() {
    const {scrollLeft, scrollWidth, clientWidth} = this.list
    const start = scrollLeft > 1
    const end = scrollLeft + clientWidth < scrollWidth - 1
    const more = start && end ? "both" : start ? "start" : end ? "end" : null
    if (more) this.el.dataset.more = more
    else delete this.el.dataset.more
  },
}
