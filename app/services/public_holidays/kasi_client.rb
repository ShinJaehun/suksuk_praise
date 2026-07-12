require "date"
require "net/http"
require "rexml/document"
require "uri"

module PublicHolidays
  class KasiClient
    BASE_URL = "https://apis.data.go.kr/B090041/openapi/service/SpcdeInfoService"
    OPERATION = "getRestDeInfo"
    SOURCE = "kasi_special_days"
    PAGE_SIZE = 100
    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 10

    class Error < StandardError; end
    class ConfigurationError < Error; end
    class ResponseError < Error; end

    def initialize(api_key: ENV["KASI_HOLIDAY_API_KEY"], http_get: nil)
      @api_key = api_key
      @http_get = http_get || method(:perform_get)
    end

    def fetch_year(year)
      raise ConfigurationError, "KASI_HOLIDAY_API_KEY is required" if api_key.blank?

      first_page = fetch_page(year, 1)
      page_count = (first_page.fetch(:total_count).to_f / PAGE_SIZE).ceil
      items = first_page.fetch(:items)

      2.upto(page_count) do |page_number|
        items.concat(fetch_page(year, page_number).fetch(:items))
      end

      items.uniq
    end

    private

    attr_reader :api_key, :http_get

    def fetch_page(year, page_number)
      response = http_get.call(build_uri(year, page_number))
      unless response.code.to_i.between?(200, 299)
        raise ResponseError, "KASI holiday API returned HTTP #{response.code}"
      end

      parse_response(response.body)
    rescue REXML::ParseException => error
      raise ResponseError, "KASI holiday API returned invalid XML: #{error.message}"
    end

    def build_uri(year, page_number)
      uri = URI("#{BASE_URL}/#{OPERATION}")
      uri.query = URI.encode_www_form(
        ServiceKey: api_key,
        solYear: year,
        pageNo: page_number,
        numOfRows: PAGE_SIZE
      )
      uri
    end

    def perform_get(uri)
      Net::HTTP.start(
        uri.host,
        uri.port,
        use_ssl: true,
        open_timeout: OPEN_TIMEOUT,
        read_timeout: READ_TIMEOUT
      ) { |http| http.get(uri.request_uri) }
    rescue Timeout::Error, SocketError, SystemCallError => error
      raise ResponseError, "KASI holiday API request failed: #{error.message}"
    end

    def parse_response(xml)
      document = REXML::Document.new(xml)
      result_code = REXML::XPath.first(document, "/response/header/resultCode")&.text.to_s.strip
      result_message = REXML::XPath.first(document, "/response/header/resultMsg")&.text.to_s.strip
      raise ResponseError, "KASI holiday API error #{result_code}: #{result_message}" unless result_code == "00"

      total_count = integer_value(document, "/response/body/totalCount")
      items = REXML::XPath.match(document, "/response/body/items/item").filter_map do |item|
        next unless element_text(item, "isHoliday") == "Y"

        build_item(item)
      end

      { total_count: total_count, items: items }
    end

    def integer_value(document, path)
      Integer(REXML::XPath.first(document, path)&.text.to_s, exception: false) ||
        raise(ResponseError, "KASI holiday API response has an invalid totalCount")
    end

    def build_item(item)
      raw_date = element_text(item, "locdate")
      name = element_text(item, "dateName")
      raise ResponseError, "KASI holiday API response has an invalid locdate" unless raw_date.match?(/\A\d{8}\z/)
      raise ResponseError, "KASI holiday API response has a blank dateName" if name.blank?

      {
        date: Date.strptime(raw_date, "%Y%m%d"),
        name: name,
        source: SOURCE
      }
    rescue Date::Error
      raise ResponseError, "KASI holiday API response has an invalid locdate"
    end

    def element_text(element, name)
      element.elements[name]&.text.to_s.strip
    end
  end
end
