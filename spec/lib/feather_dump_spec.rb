require "rails_helper"
require "rake"

RSpec.describe FeatherDump do
  subject(:dump) { described_class.new(dir:, out:) }

  let(:dir) { Rails.root.join("tmp/feather_dump_spec/#{SecureRandom.hex(4)}") }
  let(:out) { StringIO.new }

  let(:user) { create(:user, :superadmin) }
  let(:site) { create(:site) }
  let!(:image) { create(:image, site:, unsplash_data: { "photographer_name" => "Jane" }) }
  let!(:post) { create(:post, site:, title: "Hello", tags: "ruby", content: [paragraph]) }
  let!(:project) { create(:project, site:) }
  let!(:page) { create(:page, :books, site:, add_to_navigation: true) }
  let!(:target) do
    create(:deployment_target, :fastmail, site:, config: { "email" => "a@b.c", "password" => "pw" })
  end
  let(:paragraph) { { "id" => "p1", "type" => "paragraph", "text" => "Hi <b>there</b>" } }

  before do
    create(:site_user, site:, user:)
    create(:user_invitation, site:, inviting_user: user)
    create(:social_media_link, site:)
    create(:api_token, user:)
    create(:book, :with_cover, site:, post:)
    image.file.analyze
  end

  after { FileUtils.rm_rf(Rails.root.join("tmp/feather_dump_spec")) }

  def read_json(name)
    JSON.parse(File.read(dir.join(name)))
  end

  def row_for(table, record)
    read_json("#{table}.json").find { |row| row["id"] == record.id }
  end

  it "writes one JSON file per table and a manifest with the counts" do
    dump.run

    manifest = read_json("manifest.json")
    expect(manifest).to include("format" => 1, "rails_env" => "test")
    expect(manifest["dumped_at"]).to match(/\A\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{6}Z\z/)
    expect(manifest["counts"]).to eq(
      "users" => User.count, "sites" => 1, "site_users" => 1, "user_invitations" => 1,
      "social_media_links" => 1, "api_tokens" => 1, "images" => 2, "posts" => 1, "pages" => 1,
      "projects" => 1, "books" => 1, "navigations" => 1, "navigation_items" => 1,
      "deployment_targets" => 1
    )
    manifest["counts"].each do |table, count|
      expect(read_json("#{table}.json").size).to eq(count)
    end
  end

  it "creates the directory readable only by the owner" do
    dump.run

    expect(File.stat(dir).mode & 0o777).to eq(0o700)
    expect(File.stat(dir.join("deployment_targets.json")).mode & 0o777).to eq(0o600)
  end

  it "dumps all columns with timestamps in microseconds, enum labels and real JSON" do
    dump.run

    post_row = row_for("posts", post)
    expect(post_row.keys).to match_array(Post.column_names)
    expect(post_row["created_at"]).to eq(post.reload.created_at.utc.iso8601(6))
    expect(post_row["created_at"]).to match(/\.\d{6}Z\z/)
    expect(post_row["content"]).to eq([paragraph])

    page_row = row_for("pages", page)
    expect(page_row.keys).to match_array(Page.column_names)
    expect(page_row["page_type"]).to eq("books")

    project_row = row_for("projects", project)
    expect(project_row["started_at"]).to eq(project.started_at.iso8601)
    expect(project_row["links"]).to eq(project.links)
    expect(project_row["status"]).to eq("completed")
  end

  it "orders rows by created_at" do
    newer = create(:post, site:, created_at: 1.day.ago)

    dump.run

    expect(read_json("posts.json").pluck("id")).to eq([newer.id, post.id])
  end

  it "copies the original image file and inlines the blob metadata" do
    dump.run

    file = row_for("images", image)["file"]
    expect(file).to eq(
      "path" => "images/#{image.public_id}/15x15.jpg", "filename" => "15x15.jpg",
      "content_type" => "image/jpeg", "byte_size" => image.file.byte_size,
      "checksum" => image.file.checksum, "width" => 15, "height" => 15
    )
    expect(dir.join(file["path"]).binread)
      .to eq(Rails.root.join("spec/fixtures/files/15x15.jpg").binread)
    expect(row_for("images", image)["unsplash_data"]).to eq("photographer_name" => "Jane")
    expect(dump.image_files.copied).to eq(2)
  end

  it "keeps the polymorphic owner of an image" do
    dump.run

    cover = Book.last.cover_image
    expect(row_for("images", cover)).to include("imageable_type" => "Book", "imageable_id" => Book.last.id)
  end

  it "writes a null file and logs images without an attachment" do
    image.file.detach

    dump.run

    expect(row_for("images", image)["file"]).to be_nil
    expect(dump.image_files.missing).to eq(["image #{image.public_id}: no file attached"])
    expect(out.string).to include("missing files:      1")
  end

  it "keeps the metadata but no path when the blob is gone from storage" do
    FileUtils.rm(ActiveStorage::Blob.service.path_for(image.file.key))

    dump.run

    file = row_for("images", image)["file"]
    expect(file).to include("path" => nil, "filename" => "15x15.jpg")
    expect(dump.image_files.missing.first).to include("ActiveStorage::FileNotFoundError")
  end

  it "dumps deployment targets with the raw and the decoded config" do
    dump.run

    row = row_for("deployment_targets", target)
    expect(row["encrypted_config"]).to eq(target.reload.encrypted_config)
    expect(row["config_plain"]).to eq("email" => "a@b.c", "password" => "pw")
    expect(row["type"]).to eq("production")
    expect(out.string)
      .to include("deployment target #{target.public_id}: encrypted_config parsed as plain JSON")
  end

  it "says so when a deployment target has no config" do
    staging = create(:deployment_target, :staging, site:)

    dump.run

    expect(row_for("deployment_targets", staging)).to include("encrypted_config" => nil, "config_plain" => {})
    expect(out.string).to include("deployment target #{staging.public_id}: encrypted_config is NULL")
  end

  it "warns when encrypted_config is not plain JSON" do
    target.update!(encrypted_config: "not json")

    dump.run

    expect(row_for("deployment_targets", target)["config_plain"]).to be_nil
    expect(out.string).to include("encrypted_config is NOT plain JSON")
  end

  it "dumps API tokens with their digest only" do
    dump.run

    row = read_json("api_tokens.json").first
    expect(row.keys).to match_array(ApiToken.column_names)
    expect(row["token_digest"]).to eq(ApiToken.first.token_digest)
  end

  it "dumps site users, which have no timestamps" do
    dump.run

    expect(read_json("site_users.json").first).to include("role" => "editor", "user_id" => user.id)
  end

  it "prints a summary with a warning about secrets" do
    dump.run

    expect(out.string).to include("deployment_targets   1", "image files copied: 2",
                                  "contains deployment credentials")
  end

  it "refuses to write into a directory that is not empty" do
    FileUtils.mkdir_p(dir)
    FileUtils.touch(dir.join("leftover"))

    expect { dump.run }.to raise_error(described_class::DirectoryNotEmptyError)
  end

  describe "rake feather:dump" do
    before do
      Rake.application = Rake::Application.new
      Rake::Task.define_task(:environment)
      load Rails.root.join("lib/tasks/dump.rake")
    end

    it "dumps into the given directory" do
      expect { Rake::Task["feather:dump"].invoke(dir.to_s) }.to output(/Dumped to/).to_stdout

      expect(dir.join("manifest.json")).to exist
    end

    it "aborts when the directory is not empty" do
      FileUtils.mkdir_p(dir)
      FileUtils.touch(dir.join("leftover"))

      expect { Rake::Task["feather:dump"].invoke(dir.to_s) }
        .to raise_error(SystemExit).and output(/is not empty/).to_stderr
    end
  end
end
