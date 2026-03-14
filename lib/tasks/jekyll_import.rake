require_relative "../jekyll_importer"

namespace :import do
  desc "Delete all posts and pages from a site. Usage: bin/rails import:reset[token,site_id]"
  task :reset, %i[token site_id] => :environment do |_t, args|
    unless args[:token] && args[:site_id]
      abort "Usage: bin/rails import:reset[api_token,site_public_id]"
    end

    base_url = ENV.fetch("IMPORT_BASE_URL", "http://localhost:3000")
    client = JekyllImporter::ApiClient.new(base_url: base_url, token: args[:token], site_id: args[:site_id])

    deleted_posts = 0
    errors = []
    loop do
      response = client.list_posts(page: 1)
      posts = response["data"]
      break if posts.empty?

      posts.each do |post|
        client.delete_post(post["id"])
        deleted_posts += 1
        print "\rDeleted #{deleted_posts} posts..."
      rescue JekyllImporter::ApiClient::ApiError => e
        errors << "Post #{post['id']}: #{e.message}"
        print "\rSkipped post #{post['id']} (#{e.message}), continuing..."
      end

      # If all posts on this page failed, move to next page to avoid infinite loop
      break if errors.size >= posts.size && deleted_posts == 0
    end
    puts "\rDeleted #{deleted_posts} posts.    "

    deleted_pages = 0
    loop do
      response = client.list_pages(page: 1)
      pages = response["data"]
      break if pages.empty?

      pages.each do |page|
        client.delete_page(page["id"])
        deleted_pages += 1
        print "\rDeleted #{deleted_pages} pages..."
      rescue JekyllImporter::ApiClient::ApiError => e
        errors << "Page #{page['id']}: #{e.message}"
        print "\rSkipped page #{page['id']} (#{e.message}), continuing..."
      end

      break if errors.size >= pages.size && deleted_pages == 0
    end
    puts "\rDeleted #{deleted_pages} pages.    "

    if errors.any?
      puts "\nErrors (#{errors.size}):"
      errors.each { |e| puts "  - #{e}" }
    end

    puts "\nReset complete! Deleted #{deleted_posts} posts and #{deleted_pages} pages."
  end

  desc "Import a Jekyll site via the CMS API. Usage: bin/rails import:jekyll[path,token,site_id]"
  task :jekyll, %i[path token site_id] => :environment do |_t, args|
    unless args[:path] && args[:token] && args[:site_id]
      abort "Usage: bin/rails import:jekyll[path_to_jekyll_site,api_token,site_public_id]"
    end

    abort "Error: #{args[:path]} is not a directory" unless File.directory?(args[:path])

    base_url = ENV.fetch("IMPORT_BASE_URL", "http://localhost:3000")

    importer = JekyllImporter::Importer.new(
      site_path: args[:path],
      api_token: args[:token],
      site_id: args[:site_id],
      base_url: base_url
    )

    importer.run
  end
end
