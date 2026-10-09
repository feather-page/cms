// The services an embed block takes a URL of: the ones the Editor.js embed
// tool offered (its patterns, embed URLs and sizes), without the defunct
// Vine and Gfycat, and without GitHub gists, whose data: URL the server
// never stored. Imgur's embed URL is https (the tool's http one is blocked
// on https sites). Stored embeds of other services are kept as they are.
//
// `id(groups)` turns the pattern's groups into the part that goes into the
// embed URL in place of {id}; by default the first group.
const youtubeParams = {start: "start", end: "end", t: "start", time_continue: "start", list: "list"}

function youtubeId([id, query]) {
  if (!query && id) return id

  const params = query
    .slice(1)
    .split("&")
    .map((pair) => {
      const [name, value] = pair.split("=")
      if (!id && name === "v") {
        id = value
        return null
      }
      if (!youtubeParams[name] || value === "LL" || value.startsWith("RDMM") || value.startsWith("FL")) return null
      return `${youtubeParams[name]}=${value}`
    })
    .filter(Boolean)

  return `${id}?${params.join("&")}`
}

export const EMBED_SERVICES = {
  vimeo: {
    label: "Vimeo",
    regex: /(?:http[s]?:\/\/)?(?:www.)?(?:player.)?vimeo\.co(?:.+\/([^/]\d+)(?:#t=[\d]+)?s?$)/,
    embedUrl: "https://player.vimeo.com/video/{id}?title=0&byline=0",
    width: 580,
    height: 320
  },
  youtube: {
    label: "YouTube",
    regex:
      /(?:https?:\/\/)?(?:www\.)?(?:(?:youtu\.be\/)|(?:youtube\.com)\/(?:v\/|u\/\w\/|embed\/|watch))(?:(?:\?v=)?([^#&?=]*))?((?:[?&]\w*=\w*)*)/,
    embedUrl: "https://www.youtube.com/embed/{id}",
    width: 580,
    height: 320,
    id: youtubeId
  },
  coub: {
    label: "Coub",
    regex: /https?:\/\/coub\.com\/view\/([^/?&]+)/,
    embedUrl: "https://coub.com/embed/{id}",
    width: 580,
    height: 320
  },
  imgur: {
    label: "Imgur",
    regex: /https?:\/\/(?:i\.)?imgur\.com.*\/([a-zA-Z0-9]+)(?:\.gifv)?/,
    embedUrl: "https://imgur.com/{id}/embed",
    width: 540,
    height: 500
  },
  "twitch-channel": {
    label: "Twitch",
    regex: /https?:\/\/www\.twitch\.tv\/([^/?&]*)\/?$/,
    embedUrl: "https://player.twitch.tv/?channel={id}",
    width: 600,
    height: 366
  },
  "twitch-video": {
    label: "Twitch",
    regex: /https?:\/\/www\.twitch\.tv\/(?:[^/?&]*\/v|videos)\/([0-9]*)/,
    embedUrl: "https://player.twitch.tv/?video=v{id}",
    width: 600,
    height: 366
  },
  "yandex-music-album": {
    label: "Yandex Music",
    regex: /https?:\/\/music\.yandex\.ru\/album\/([0-9]*)\/?$/,
    embedUrl: "https://music.yandex.ru/iframe/#album/{id}/",
    width: 540,
    height: 400
  },
  "yandex-music-track": {
    label: "Yandex Music",
    regex: /https?:\/\/music\.yandex\.ru\/album\/([0-9]*)\/track\/([0-9]*)/,
    embedUrl: "https://music.yandex.ru/iframe/#track/{id}/",
    width: 540,
    height: 100,
    id: (groups) => groups.join("/")
  },
  "yandex-music-playlist": {
    label: "Yandex Music",
    regex: /https?:\/\/music\.yandex\.ru\/users\/([^/?&]*)\/playlists\/([0-9]*)/,
    embedUrl: "https://music.yandex.ru/iframe/#playlist/{id}/show/cover/description/",
    width: 540,
    height: 400,
    id: (groups) => groups.join("/")
  },
  codepen: {
    label: "CodePen",
    regex: /https?:\/\/codepen\.io\/([^/?&]*)\/pen\/([^/?&]*)/,
    embedUrl: "https://codepen.io/{id}?height=300&theme-id=0&default-tab=css,result&embed-version=2",
    width: 600,
    height: 300,
    id: (groups) => groups.join("/embed/")
  },
  instagram: {
    label: "Instagram",
    regex: /^https:\/\/(?:www\.)?instagram\.com\/(?:reel|p)\/(.*)/,
    embedUrl: "https://www.instagram.com/p/{id}/embed",
    width: 400,
    height: 505,
    id: (groups) => groups[0]?.split("/")[0]
  },
  twitter: {
    label: "X (Twitter)",
    regex: /^https?:\/\/(www\.)?(?:twitter\.com|x\.com)\/.+\/status\/(\d+)/,
    embedUrl: "https://platform.twitter.com/embed/Tweet.html?id={id}",
    width: 600,
    height: 300,
    id: (groups) => groups[1]
  },
  pinterest: {
    label: "Pinterest",
    regex: /https?:\/\/([^/?&]*).pinterest.com\/pin\/([^/?&]*)\/?$/,
    embedUrl: "https://assets.pinterest.com/ext/embed.html?id={id}",
    id: (groups) => groups[1]
  },
  facebook: {
    label: "Facebook",
    regex: /https?:\/\/www.facebook.com\/([^/?&]*)\/(.*)/,
    embedUrl: "https://www.facebook.com/plugins/post.php?href=https://www.facebook.com/{id}&width=500",
    id: (groups) => groups.join("/")
  },
  aparat: {
    label: "Aparat",
    regex: /(?:http[s]?:\/\/)?(?:www.)?aparat\.com\/v\/([^/?&]+)\/?/,
    embedUrl: "https://www.aparat.com/video/video/embed/videohash/{id}/vt/frame",
    width: 600,
    height: 300
  },
  miro: {
    label: "Miro",
    regex: /https:\/\/miro.com\/\S+(\S{12})\/(\S+)?/,
    embedUrl: "https://miro.com/app/live-embed/{id}"
  }
}

// "YouTube, Vimeo, ... or Miro", for messages.
export const serviceNames = (() => {
  const names = [...new Set(Object.values(EMBED_SERVICES).map(({label}) => label))]
  return `${names.slice(0, -1).join(", ")} or ${names.at(-1)}`
})()

// The URL as an absolute http(s) URL ("youtu.be/x" gets https://), or null.
function absoluteUrl(text) {
  const trimmed = (text || "").trim()
  if (!trimmed || /\s/.test(trimmed)) return null

  const url = /^[a-z][a-z0-9+.-]*:/i.test(trimmed) ? trimmed : `https://${trimmed}`
  try {
    const {protocol} = new URL(url)
    return ["http:", "https:"].includes(protocol) ? url : null
  } catch (_error) {
    return null
  }
}

const firstGroup = (groups) => groups[0] || ""

// The embed attrs (service, source, embed, width, height) for the URL of a
// supported service, as the Editor.js tool computed them, or null.
export function recognizeEmbed(text) {
  const source = absoluteUrl(text)
  if (!source) return null

  for (const [service, spec] of Object.entries(EMBED_SERVICES)) {
    const {regex, embedUrl, width = null, height = null, id = firstGroup} = spec
    const groups = regex.exec(source)?.slice(1)
    if (groups) return {service, source, embed: embedUrl.replaceAll("{id}", id(groups)), width, height}
  }

  return null
}

const host = (url) => {
  try {
    return new URL(url).host
  } catch (_error) {
    return null
  }
}

const previewHosts = new Set(Object.values(EMBED_SERVICES).map(({embedUrl}) => host(embedUrl.replaceAll("{id}", "x"))))

// The URL the editor shows an embed's preview from: only https URLs of the
// services' own embed hosts, so a stored embed of anything else (another
// service, content from the API) loads nothing in the admin. YouTube
// without cookies, like the exported site.
export function previewUrl(embed) {
  if (typeof embed !== "string" || !embed.startsWith("https://") || !previewHosts.has(host(embed))) return null
  return embed.replace("youtube.com/embed/", "youtube-nocookie.com/embed/")
}
