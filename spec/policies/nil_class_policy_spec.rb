require "rails_helper"

describe NilClassPolicy do
  subject(:policy) { described_class }

  permissions :index?, :show?, :create?, :update?, :destroy? do
    it "denies all actions" do
      expect(policy).not_to permit(create(:user), nil)
    end
  end
end
