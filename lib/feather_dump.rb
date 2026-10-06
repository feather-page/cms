require "fileutils"
require "json"

# One-time export of all application data for the Phoenix port (issue #378).
#
# Writes one JSON array per table plus the original image files into a directory. The layout is the
# contract the Phoenix importer reads:
#
#   DIR/manifest.json                 {"format", "dumped_at", "rails_env", "counts"}
#   DIR/<table>.json                  every column of every row, ordered by created_at
#   DIR/images/<public_id>/<filename> the original Active Storage blob of each image
#
# Values are written as stored: enums as their string labels, JSON columns as real JSON, timestamps
# as ISO 8601 UTC with microseconds, dates as YYYY-MM-DD. Active Storage, Solid Queue and Solid
# Cable tables are not dumped; the blob metadata the importer needs is inlined into images.json.
#
# The dump contains secrets (deployment target credentials), so DIR is created with mode 0700 and
# the JSON files are written with mode 0600.
class FeatherDump
  FORMAT = 1

  # Foreign-key parents before children, so an importer can insert the files in this order
  # (images.imageable is polymorphic and has no foreign key).
  MODEL_NAMES = %w[
    User Site SiteUser UserInvitation SocialMediaLink ApiToken Image Post Page Project Book
    Navigation NavigationItem DeploymentTarget
  ].freeze

  class DirectoryNotEmptyError < StandardError; end

  attr_reader :dir, :counts, :image_files

  def initialize(dir:, out: $stdout)
    @dir = Pathname.new(dir).expand_path
    @out = out
    @counts = {}
    @image_files = ImageFiles.new(dir: @dir, warn: method(:warn_line))
  end

  def run
    prepare_directory
    MODEL_NAMES.each { |name| dump_model(name.constantize) }
    write_json("manifest.json", manifest)
    print_summary
    self
  end

  private

  def prepare_directory
    raise DirectoryNotEmptyError, "#{dir} exists and is not empty" if dir.exist? && !dir.empty?

    FileUtils.mkdir_p(dir)
    File.chmod(0o700, dir)
  end

  def dump_model(model)
    rows = each_record(model).map { |record| row_for(record) }
    counts[model.table_name] = rows.size
    write_json("#{model.table_name}.json", rows)
  end

  # site_users has no timestamps; its bigint primary key is the insertion order there.
  def each_record(model)
    cursor = [model.column_names.include?("created_at") ? :created_at : nil, model.primary_key]
    model.find_each(cursor: cursor.compact)
  end

  def row_for(record)
    # Only real columns: `attributes` also carries virtual attributes such as
    # Page#add_to_navigation, which are not stored.
    row = record.attributes.slice(*record.class.column_names).transform_values { |v| serialize(v) }

    case record
    when Image then row.merge("file" => image_files.dump(record))
    when DeploymentTarget then row.merge("config_plain" => deployment_config(record))
    else row
    end
  end

  def serialize(value)
    case value
    when ActiveSupport::TimeWithZone, Time, DateTime then value.utc.iso8601(6)
    when Date then value.iso8601
    else value
    end
  end

  # `encrypts :config` in DeploymentTarget targets an attribute that has no column: the model's
  # own config/config= read and write the `encrypted_config` column as plain JSON, so nothing is
  # actually encrypted. The warning per target confirms this against the real data.
  def deployment_config(target)
    config = target.config
    state = target.encrypted_config.nil? ? "is NULL (config_plain is {})" : "parsed as plain JSON"
    warn_line("deployment target #{target.public_id}: encrypted_config #{state}")
    config
  rescue JSON::ParserError => e
    warn_line("deployment target #{target.public_id}: encrypted_config is NOT plain JSON " \
              "(#{e.class}), config_plain is null")
    nil
  end

  def manifest
    {
      "format" => FORMAT,
      "dumped_at" => serialize(Time.current),
      "rails_env" => Rails.env.to_s,
      "counts" => counts
    }
  end

  def write_json(name, data)
    File.write(dir.join(name), JSON.pretty_generate(data), perm: 0o600)
  end

  def warn_line(message)
    @out.puts "WARNING: #{message}"
  end

  def print_summary
    @out.puts "Dumped to #{dir}"
    counts.each { |table, count| @out.puts format("  %-20<table>s %<count>d", table:, count:) }
    @out.puts "  image files copied: #{image_files.copied}"
    @out.puts "  missing files:      #{image_files.missing.size}"
    image_files.missing.each { |message| @out.puts "    - #{message}" }
    @out.puts "WARNING: the dump contains deployment credentials in plain text. " \
              "Handle #{dir} carefully and delete it after the import."
  end
end
