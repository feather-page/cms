describe ApplicationPolicy do
  describe ApplicationPolicy::Scope do
    it 'returns an NotImplemented error per default' do
      expect { described_class.new(nil, nil).resolve }.to raise_error(NotImplementedError)
    end
  end

  permissions :index?, :create?, :destroy?, :edit?, :new?, :show?, :update? do
    it 'returns false per default' do
      user = build(:user, :superadmin)
      expect(described_class).not_to permit(user, instance_double(Object))
    end
  end
end
