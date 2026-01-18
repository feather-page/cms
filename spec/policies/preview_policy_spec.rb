describe PreviewPolicy do
  subject(:policy) { described_class }

  let!(:deployment_target) { create(:deployment_target) }

  permissions :show? do
    context "for a super admin" do
      let(:user) { build(:user, :superadmin) }

      it "permits" do
        expect(policy).to permit(user, deployment_target)
      end
    end

    context "for a user that is part of the site" do
      let(:user) { create(:user, sites: [deployment_target.site]) }

      it "permits" do
        expect(policy).to permit(user, deployment_target)
      end
    end

    context "for a user that is not part of the site" do
      let(:user) { create(:user) }

      it "denies" do
        expect(policy).not_to permit(user, deployment_target)
      end
    end
  end
end
