module Api
  class LinksController < ApplicationController
    def index
      items = search_linkables(search_query).map do |item|
        {
          href: item.slug,
          name: [item.emoji, item.title].compact_blank.join(' '),
          description: item.model_name.human,
          sgid: item.to_sgid(expires_in: nil, for: 'internal_link').to_s
        }
      end

      render json: { success: true, items: }
    end

    private

    def search_query
      params[:search].to_s.strip
    end

    def search_linkables(query)
      pages = current_site.pages
      posts = current_site.posts.where.not(slug: nil)

      if query.present?
        query_pattern = "%#{query.downcase}%"
        pages = pages.where('LOWER(title) LIKE ?', query_pattern)
        posts = posts.where('LOWER(title) LIKE ?', query_pattern)
      end

      (pages.limit(10).to_a + posts.limit(10).to_a)
        .sort_by { |item| item.title.to_s.downcase }
        .first(15)
    end
  end
end
