# frozen_string_literal: true

describe Hugo::BaseFile do
  let(:site) { create(:site) }
  let(:deployment_target) { create(:deployment_target, :staging, site: site) }

  describe "#write" do
    it "raises NotImplementedError for relative_path" do
      file = described_class.new(nil, deployment_target)

      expect { file.write }.to raise_error(NotImplementedError)
    end
  end

  describe "#binary?" do
    it "returns false by default" do
      file = described_class.new(nil, deployment_target)

      expect(file.binary?).to be false
    end
  end

  describe "path normalization" do
    it "rejects paths that escape the build directory" do
      file = described_class.new(nil, deployment_target)
      # Access protected method for testing
      expect {
        file.send(:normalized_path!, File.join(deployment_target.build_path, "../../etc/passwd"))
      }.to raise_error(RuntimeError, /Invalid file path/)
    end
  end
end
