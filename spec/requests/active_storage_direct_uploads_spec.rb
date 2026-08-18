require "rails_helper"
require "digest/md5"

RSpec.describe "Active Storage direct uploads", type: :request do
  it "does not expose the direct upload endpoint" do
    payload = "test upload"
    checksum = Digest::MD5.base64digest(payload)

    expect {
      post "/rails/active_storage/direct_uploads",
        params: {
          blob: {
            filename: "test.txt",
            byte_size: payload.bytesize,
            checksum: checksum,
            content_type: "text/plain"
          }
        }
    }.not_to change(ActiveStorage::Blob, :count)

    expect(response).to have_http_status(:not_found)
  end
end
