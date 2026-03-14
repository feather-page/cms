require_relative "../jekyll_importer"

namespace :import do
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
