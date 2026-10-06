namespace :feather do
  desc "Dump all application data for the Phoenix port. Usage: bin/rails 'feather:dump[DIR]'"
  task :dump, %i[dir] => :environment do |_t, args|
    dir = args[:dir].presence || Rails.root.join("tmp", "dump-#{Time.current.utc.strftime('%Y%m%d%H%M%S')}")
    FeatherDump.new(dir:).run
  rescue FeatherDump::DirectoryNotEmptyError => e
    abort e.message
  end
end
