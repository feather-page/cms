class NormalizePageAndProjectSlugs < ActiveRecord::Migration[8.1]
  def up
    %w[pages projects].each { |table| prefix_slugs(table) }
  end

  def down
    # Behaviour-neutral: "about" and "/about" produce the same output path,
    # so there is nothing to restore.
  end

  private

  # A site may already hold both "about" and "/about"; prefixing blindly would
  # violate the unique index on (slug, site_id). Those rows keep their slug --
  # StaticSite::Routes addresses them identically either way.
  def prefix_slugs(table)
    execute(<<~SQL.squish)
      UPDATE #{table} AS t
      SET slug = '/' || t.slug
      WHERE t.slug IS NOT NULL
        AND t.slug NOT LIKE '/%'
        AND NOT EXISTS (
          SELECT 1 FROM #{table} AS other
          WHERE other.site_id = t.site_id
            AND other.slug = '/' || t.slug
        )
    SQL
  end
end
