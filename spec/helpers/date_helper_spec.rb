# frozen_string_literal: true

require "rails_helper"

RSpec.describe DateHelper, type: :helper do
  describe "#format_date" do
    it "formats a date as dd.mm.yyyy" do
      expect(helper.format_date(Date.new(2026, 3, 15))).to eq("15.03.2026")
    end

    it "returns nil for nil" do
      expect(helper.format_date(nil)).to be_nil
    end
  end

  describe "#format_month_year" do
    it "formats a date as mm.yyyy" do
      expect(helper.format_month_year(Date.new(2019, 3, 1))).to eq("03.2019")
    end

    it "returns nil for nil" do
      expect(helper.format_month_year(nil)).to be_nil
    end
  end

  describe "#format_datetime" do
    it "formats a datetime as dd.mm.yyyy, HH:MM" do
      expect(helper.format_datetime(Time.zone.local(2026, 3, 15, 14, 30))).to eq("15.03.2026, 14:30")
    end

    it "returns nil for nil" do
      expect(helper.format_datetime(nil)).to be_nil
    end
  end
end
