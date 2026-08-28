require "builder"

module StaticSite
  class RssFeedRenderer
    MAX_ITEMS = 20

    def initialize(site:, routes:)
      @site = site
      @routes = routes.canonical
    end

    def render
      builder = Builder::XmlMarkup.new(indent: 2)
      builder.instruct! :xml, version: "1.0", encoding: "UTF-8"
      builder.rss(version: "2.0", "xmlns:atom" => "http://www.w3.org/2005/Atom") do |rss|
        rss.channel { |channel| render_channel(channel) }
      end
    end

    private

    attr_reader :site, :routes

    def render_channel(channel)
      render_channel_metadata(channel)
      render_posts(channel)
    end

    def render_channel_metadata(channel)
      channel.title site.title
      channel.link routes.home_url
      channel.description "#{site.title} - RSS Feed"
      channel.language site.language_code
      channel.tag!("atom:link", href: routes.artifact_url("feed.xml"), rel: "self",
                                type: "application/rss+xml")
    end

    def render_posts(channel)
      posts.each { |post| render_post_item(channel, post) }
    end

    def render_post_item(channel, post)
      channel.item do |item|
        item.title post.title.presence || "Post"
        item.link routes.post_url(post)
        item.pubDate post.publish_at.rfc2822
        item.guid routes.post_url(post), isPermaLink: "true"
        item.description Blocks::Renderer.render(post.blocks, routes:)
      end
    end

    def posts
      @posts ||= site.posts.published.order(publish_at: :desc).limit(MAX_ITEMS)
    end
  end
end
