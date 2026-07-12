require "rails_helper"

RSpec.describe PublicHolidays::KasiClient do
  Response = Struct.new(:code, :body)

  def xml_response(items:, total_count: items.size, result_code: "00")
    item_xml = items.map do |item|
      <<~XML
        <item>
          <dateName>#{item.fetch(:name)}</dateName>
          <isHoliday>#{item.fetch(:holiday, "Y")}</isHoliday>
          <locdate>#{item.fetch(:date)}</locdate>
        </item>
      XML
    end.join

    <<~XML
      <response>
        <header><resultCode>#{result_code}</resultCode><resultMsg>message</resultMsg></header>
        <body><items>#{item_xml}</items><totalCount>#{total_count}</totalCount></body>
      </response>
    XML
  end

  it "converts multiple holiday items and excludes non-holidays" do
    xml = xml_response(items: [
      { date: "20260101", name: " 1월1일 " },
      { date: "20260102", name: "평일", holiday: "N" },
      { date: "20260301", name: "삼일절" }
    ])
    client = described_class.new(api_key: "secret", http_get: ->(_uri) { Response.new("200", xml) })

    expect(client.fetch_year(2026)).to eq([
      { date: Date.new(2026, 1, 1), name: "1월1일", source: "kasi_special_days" },
      { date: Date.new(2026, 3, 1), name: "삼일절", source: "kasi_special_days" }
    ])
  end

  it "handles a response containing one item" do
    xml = xml_response(items: [{ date: "20260101", name: "1월1일" }])
    client = described_class.new(api_key: "secret", http_get: ->(_uri) { Response.new("200", xml) })

    expect(client.fetch_year(2026).size).to eq(1)
  end

  it "loads all pages and removes duplicate results" do
    requested_pages = []
    first_xml = xml_response(
      items: [{ date: "20260101", name: "1월1일" }],
      total_count: 101
    )
    second_xml = xml_response(items: [
      { date: "20260101", name: "1월1일" },
      { date: "20260301", name: "삼일절" }
    ], total_count: 101)
    http_get = lambda do |uri|
      page = URI.decode_www_form(uri.query).to_h.fetch("pageNo")
      requested_pages << page
      Response.new("200", page == "1" ? first_xml : second_xml)
    end
    client = described_class.new(api_key: "secret", http_get: http_get)

    expect(client.fetch_year(2026).size).to eq(2)
    expect(requested_pages).to eq(%w[1 2])
  end

  it "raises before requesting when the API key is missing" do
    http_get = spy("http_get")
    client = described_class.new(api_key: nil, http_get: http_get)

    expect { client.fetch_year(2026) }
      .to raise_error(described_class::ConfigurationError)
    expect(http_get).not_to have_received(:call)
  end

  it "raises for an HTTP failure" do
    client = described_class.new(
      api_key: "secret",
      http_get: ->(_uri) { Response.new("500", "failure") }
    )

    expect { client.fetch_year(2026) }.to raise_error(described_class::ResponseError)
  end

  it "raises for an API result error" do
    xml = xml_response(items: [], result_code: "30")
    client = described_class.new(api_key: "secret", http_get: ->(_uri) { Response.new("200", xml) })

    expect { client.fetch_year(2026) }.to raise_error(described_class::ResponseError)
  end

  it "raises for malformed XML and invalid dates" do
    malformed = described_class.new(
      api_key: "secret",
      http_get: ->(_uri) { Response.new("200", "<response>") }
    )
    invalid_date_xml = xml_response(items: [{ date: "20260230", name: "휴일" }])
    invalid_date = described_class.new(
      api_key: "secret",
      http_get: ->(_uri) { Response.new("200", invalid_date_xml) }
    )

    expect { malformed.fetch_year(2026) }.to raise_error(described_class::ResponseError)
    expect { invalid_date.fetch_year(2026) }.to raise_error(described_class::ResponseError)
  end
end
