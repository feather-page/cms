module StaticSite
  class RssFeedRenderer
    def initialize(site:, base_url:)
      @site = site
      @base_url = base_url
    end

    def render
      builder = Builder::XmlMarkup.new(indent: 2)
      builder.instruct! :xml, version: "1.0", encoding: "UTF-8"
      builder.rss(version: "2.0", "xmlns:atom" => "http://www.w3.org/2005/Atom") do |rss|
        rss.channel { |channel| render_channel(channel) }
      end
    end

    private

    attr_reader :site, :base_url

    def render_channel(channel)
      render_channel_metadata(channel)
      render_posts(channel)
    end

    def render_channel_metadata(channel)
      channel.title site.title
      channel.link base_url
      channel.description "#{site.title} - RSS Feed"
      channel.language site.language_code
      channel.tag!("atom:link", href: "#{base_url}feed.xml", rel: "self", type: "application/rss+xml")
    end

    def render_posts(channel)
      posts.each { |post| render_post_item(channel, post) }
    end

    def render_post_item(channel, post)
      channel.item do |item|
        item.title post.title.presence || "Post"
        item.link post_url(post)
        item.pubDate post.publish_at.rfc2822
        item.guid post_url(post), isPermaLink: "true"
        item.description post.static_site_html
      end
    end

    def posts
      @posts ||= site.posts.published.order(publish_at: :desc).limit(20)
    end

    def post_url(post)
      if post.slug.present?
        "#{base_url}#{post.slug.sub(%r{^/}, '')}/"
      else
        "#{base_url}posts/#{post.public_id.downcase}/"
      end
    end
  end
end
