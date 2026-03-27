require "rails_helper"

RSpec.describe "Hugo build integration", type: :job do
  let(:theme) { create(:theme, hugo_theme: "simple_emoji") }
  let(:site) { create(:site, theme: theme) }
  let(:deployment_target) { create(:deployment_target, site: site) }

  before do
    FileUtils.mkdir_p(Rails.root.join("vendor/themes"))
    allow(Open3).to receive(:capture3).and_return(["", "", instance_double(Process::Status, success?: true, exitstatus: 0)])
    allow(Rclone::Deployer).to receive(:deploy)
    allow(StaticSite::PrecompressJob).to receive(:perform_now)
  end

  after { FileUtils.rm_rf(deployment_target.build_path) }

  it "writes a complete Hugo source directory" do
    post = create(:post, site: site, title: "Hello World", slug: "/hello", draft: false, tags: "ruby", publish_at: 1.day.ago)
    page = create(:page, site: site, title: "About", slug: "about")
    project = create(:project, site: site, title: "CMS", slug: "cms")
    create(:book, site: site, title: "Test Book")

    site.main_navigation.add(page)

    Hugo::BuildJob.perform_now(deployment_target)

    source = deployment_target.source_path

    # Config
    config = JSON.parse(File.read(source.join("config.json")))
    expect(config["theme"]).to eq("simple_emoji")

    # Post
    post_content = File.read(source.join("content/posts/hello.html"))
    post_meta = JSON.parse(post_content.split("\n\n", 2).first)
    expect(post_meta["title"]).to eq("Hello World")
    expect(post_meta["tags"]).to eq(["ruby"])

    # Page with menu
    page_content = File.read(source.join("content/pages/about.html"))
    page_meta = JSON.parse(page_content.split("\n\n", 2).first)
    expect(page_meta["menu"]).to include("main")

    # Project
    project_content = File.read(source.join("content/projects/cms.html"))
    project_meta = JSON.parse(project_content.split("\n\n", 2).first)
    expect(project_meta["layout"]).to eq("project")

    # Data files
    books_data = JSON.parse(File.read(source.join("data/books.json")))
    expect(books_data.values.first["title"]).to eq("Test Book")

    projects_data = JSON.parse(File.read(source.join("data/projects.json")))
    expect(projects_data["cms"]["title"]).to eq("CMS")

    site_data = JSON.parse(File.read(source.join("data/site.json")))
    expect(site_data["title"]).to eq(site.title)

    # Themes symlink
    expect(source.join("themes")).to be_symlink
  end
end
