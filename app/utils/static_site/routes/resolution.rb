module StaticSite
  class Routes
    module Resolution
      # Precedence order for ambiguous paths.
      RESOLVERS = %i[
        resolve_home
        resolve_artifact
        resolve_image
        resolve_project
        resolve_post_by_public_id
        resolve_page
        resolve_post_by_slug
      ].freeze

      def resolve(path)
        request_path = normalize_request_path(path)

        RESOLVERS.each do |resolver|
          route = send(resolver, request_path)
          return route if route
        end

        nil
      end

      private

      def normalize_request_path(path)
        path.to_s.delete_prefix("/").sub(%r{(\A|/)index\.html\z}, "").delete_suffix("/")
      end

      def resolve_home(path)
        return Route.build(:home, page: 1) if ["", "index.html", "index"].include?(path)

        match = path.match(%r{\Apage/(\d+)\z})
        Route.build(:home, page: match[1].to_i) if match
      end

      def resolve_artifact(path)
        Route.build(:artifact, name: path) if ARTIFACTS.include?(path)
      end

      def resolve_image(path)
        match = path.match(%r{\Aimages/([^/]+)/([^/]+)\.(\w+)\z})
        return unless match

        variant = Image::Variants.key_from(match[2], match[3])
        return unless variant

        image = site.images.find_by(public_id: match[1])
        Route.build(:image, record: image, variant:) if image
      end

      def resolve_project(path)
        return unless path.start_with?("projects/")

        project = find_by_slug(site.projects, path.delete_prefix("projects/"))
        Route.build(:project, record: project) if project
      end

      def resolve_post_by_public_id(path)
        return unless path.start_with?("posts/")

        public_id = path.delete_prefix("posts/").delete_suffix(".html")
        post = site.posts.find_by("LOWER(public_id) = ?", public_id.downcase)
        Route.build(:post, record: post) if post
      end

      def resolve_page(path)
        page = find_by_slug(site.pages, path.delete_suffix(".html"))
        Route.build(:page, record: page) if page
      end

      def resolve_post_by_slug(path)
        post = find_by_slug(site.posts, path.delete_suffix(".html"))
        Route.build(:post, record: post) if post
      end

      def find_by_slug(scope, slug)
        slug = strip_slug(slug)
        return if slug.blank?

        scope.find_by(slug: "/#{slug}") || scope.find_by(slug:)
      end
    end
  end
end
