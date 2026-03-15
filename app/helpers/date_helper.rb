# frozen_string_literal: true

module DateHelper
  def format_date(date)
    date&.strftime("%d.%m.%Y")
  end

  def format_month_year(date)
    date&.strftime("%m.%Y")
  end

  def format_datetime(datetime)
    datetime&.strftime("%d.%m.%Y, %H:%M")
  end
end
