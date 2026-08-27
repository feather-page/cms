class NormalizePageAndProjectSlugs < ActiveRecord::Migration[8.1]
  def up
    execute("UPDATE pages SET slug = '/' || slug WHERE slug IS NOT NULL AND slug NOT LIKE '/%'")
    execute("UPDATE projects SET slug = '/' || slug WHERE slug IS NOT NULL AND slug NOT LIKE '/%'")
  end

  def down
    # Behaviour-neutral: "about" and "/about" produce the same output path,
    # so there is nothing to restore.
  end
end
