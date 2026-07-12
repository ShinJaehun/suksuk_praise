module PublicHolidays
  class SyncYear
    SOURCE = KasiClient::SOURCE

    class Error < StandardError; end
    class InvalidYearError < Error; end
    class EmptyResultError < Error; end

    def self.call(year:, client: KasiClient.new)
      new(year: year, client: client).call
    end

    def initialize(year:, client:)
      @year = Integer(year, exception: false)
      @client = client
    end

    def call
      validate_year!
      attributes = client.fetch_year(year)
      raise EmptyResultError, "KASI holiday API returned no holidays for #{year}" if attributes.empty?

      records = attributes.map { |item| normalized_attributes(item) }.uniq

      PublicHoliday.transaction do
        holidays_for_year.delete_all
        PublicHoliday.create!(records)
      end

      records.size
    end

    private

    attr_reader :year, :client

    def validate_year!
      raise InvalidYearError, "year must be a four-digit integer" unless year&.between?(1000, 9999)
    end

    def normalized_attributes(item)
      date = item.fetch(:date)
      raise Error, "holiday date must belong to #{year}" unless date.is_a?(Date) && date.year == year

      {
        date: date,
        name: item.fetch(:name),
        source: SOURCE
      }
    end

    def holidays_for_year
      PublicHoliday.where(
        source: SOURCE,
        date: Date.new(year, 1, 1)..Date.new(year, 12, 31)
      )
    end
  end
end
