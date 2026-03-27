require "rails_helper"

RSpec.describe Hugo::DataFile do
  let(:build_path) { Pathname.new(Dir.mktmpdir) }
  let(:site) { create(:site) }

  after { FileUtils.rm_rf(build_path) }

  describe "with type :books" do
    subject(:file) { described_class.new(build_path: build_path, site: site, type: :books) }

    describe "#relative_path" do
      it "returns data/books.json" do
        expect(file.relative_path).to eq("data/books.json")
      end
    end

    describe "#content" do
      context "with no books" do
        it "returns an empty JSON object" do
          expect(JSON.parse(file.content)).to eq({})
        end
      end

      context "with books" do
        let!(:book) do
          create(:book, site: site, title: "Test Book", author: "Test Author",
                 emoji: "📖", rating: 4, reading_status: :finished,
                 read_at: Date.new(2025, 1, 15))
        end

        it "includes book data keyed by public_id" do
          parsed = JSON.parse(file.content)
          book_data = parsed[book.public_id]
          expect(book_data["title"]).to eq("Test Book")
          expect(book_data["author"]).to eq("Test Author")
          expect(book_data["emoji"]).to eq("📖")
          expect(book_data["rating"]).to eq(4)
          expect(book_data["reading_status"]).to eq("finished")
          expect(book_data["read_at"]).to eq(book.read_at.iso8601)
        end

        it "sets cover_url to nil when no cover image" do
          parsed = JSON.parse(file.content)
          expect(parsed[book.public_id]["cover_url"]).to be_nil
        end
      end

      context "with a book that has no read_at" do
        let!(:book) { create(:book, :want_to_read, site: site) }

        it "sets read_at to nil" do
          parsed = JSON.parse(file.content)
          expect(parsed[book.public_id]["read_at"]).to be_nil
        end
      end
    end

    describe "#write" do
      it "writes data/books.json to the build path" do
        file.write
        expect(build_path.join("data/books.json")).to exist
      end
    end
  end

  describe "with type :projects" do
    subject(:file) { described_class.new(build_path: build_path, site: site, type: :projects) }

    describe "#relative_path" do
      it "returns data/projects.json" do
        expect(file.relative_path).to eq("data/projects.json")
      end
    end

    describe "#content" do
      context "with no projects" do
        it "returns an empty JSON object" do
          expect(JSON.parse(file.content)).to eq({})
        end
      end

      context "with projects" do
        let!(:project) do
          create(:project, site: site, title: "My Project", slug: "my-project",
                 emoji: "🚀", status: :completed, project_type: :professional,
                 short_description: "A project", company: "Acme", role: "Dev",
                 links: [{ "label" => "Site", "url" => "https://example.com" }])
        end

        it "includes project data keyed by slug" do
          parsed = JSON.parse(file.content)
          project_data = parsed["my-project"]
          expect(project_data["title"]).to eq("My Project")
          expect(project_data["emoji"]).to eq("🚀")
          expect(project_data["status"]).to eq("completed")
          expect(project_data["status_badge_class"]).to eq("success")
          expect(project_data["project_type"]).to eq("professional")
          expect(project_data["short_description"]).to eq("A project")
          expect(project_data["company"]).to eq("Acme")
          expect(project_data["role"]).to eq("Dev")
          expect(project_data["url"]).to eq("/projects/my-project/")
        end

        it "includes links" do
          parsed = JSON.parse(file.content)
          expect(parsed["my-project"]["links"]).to eq([{ "label" => "Site", "url" => "https://example.com" }])
        end

        it "includes period" do
          parsed = JSON.parse(file.content)
          expect(parsed["my-project"]["period"]).to eq(project.display_period)
        end
      end
    end

    describe "#write" do
      it "writes data/projects.json to the build path" do
        file.write
        expect(build_path.join("data/projects.json")).to exist
      end
    end
  end

  describe "with type :site" do
    subject(:file) { described_class.new(build_path: build_path, site: site, type: :site) }

    describe "#relative_path" do
      it "returns data/site.json" do
        expect(file.relative_path).to eq("data/site.json")
      end
    end

    describe "#content" do
      it "includes site metadata" do
        parsed = JSON.parse(file.content)
        expect(parsed["title"]).to eq(site.title)
        expect(parsed["language_code"]).to eq(site.language_code)
        expect(parsed["domain"]).to eq(site.domain)
        expect(parsed["copyright"]).to eq(site.copyright)
      end

      it "includes emoji" do
        parsed = JSON.parse(file.content)
        expect(parsed).to have_key("emoji")
      end
    end

    describe "#write" do
      it "writes data/site.json to the build path" do
        file.write
        expect(build_path.join("data/site.json")).to exist
      end
    end
  end
end
