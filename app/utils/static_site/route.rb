module StaticSite
  Route = Data.define(:kind, :record, :params) do
    def self.build(kind, record: nil, **params)
      new(kind:, record:, params:)
    end
  end
end
