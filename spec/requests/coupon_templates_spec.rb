require "rails_helper"

RSpec.describe "Coupon template management", type: :request do
  let(:turbo_headers) { { "ACCEPT" => "text/vnd.turbo-stream.html" } }
  let(:modal_headers) { { "Turbo-Frame" => "modal" } }
  let!(:teacher) { create(:user, :teacher) }
  let!(:admin) { create(:user, :admin) }

  def attach_image(record, content:, filename: "coupon.png")
    record.image.attach(
      io: StringIO.new(content),
      filename: filename,
      content_type: "image/png"
    )
  end

  describe "GET /coupon_templates" do
    it "renders the personal section before the library with one global modal frame" do
      personal = create(
        :coupon_template,
        created_by: teacher,
        title: "개인 쿠폰",
        weight: 30,
        active: true,
        default_image_key: "coupon_templates/mychew.png"
      )
      create(:coupon_template, created_by: admin, bucket: "library", title: "추천 쿠폰", weight: 30)
      sign_in teacher

      get coupon_templates_path

      document = Nokogiri::HTML(response.body)
      headings = document.css("h2").map { _1.text.strip }
      personal_frame = document.at_css("turbo-frame#personal")

      expect(response).to have_http_status(:ok)
      expect(document.at_css("h1").text.strip).to eq("쿠폰 관리")
      expect(headings.index("내 쿠폰")).to be < headings.index("쿠폰 라이브러리")
      expect(document.css("turbo-frame#personal").size).to eq(1)
      expect(document.css("turbo-frame#library").size).to eq(1)
      expect(document.css("turbo-frame#modal").size).to eq(1)
      expect(personal_frame.text).to include(personal.title, "사용 중", "가중치", "30", "수정")
      expect(personal_frame.at_css("img")).to be_present
      expect(personal_frame.at_css(%(a[data-turbo-frame="modal"][href="#{edit_coupon_template_path(personal)}"]))).to be_present
      expect(personal_frame.at_css(%(button[aria-label="가중치 10 낮추기"]))).to be_present
      expect(personal_frame.at_css(%(button[aria-label="가중치 10 높이기"]))).to be_present
      expect(personal_frame.to_html).not_to include("←", "→", "🟢", "⚪")
      expect(response.body).not_to include(
        "이 쿠폰 세트로 실제 쿠폰이 발급됩니다.",
        "라이브러리는 추천 쿠폰 모음입니다.",
        "활성 가중치 합계:",
        "/ 100"
      )
    end

    it "distinguishes adopted library coupons from title conflicts" do
      adopted_source = create(:coupon_template, created_by: admin, bucket: "library", title: "추가한 추천")
      same_title_source = create(:coupon_template, created_by: admin, bucket: "library", title: "같은 제목")
      create(
        :coupon_template,
        created_by: teacher,
        title: adopted_source.title,
        source_template_id: adopted_source.id
      )
      create(:coupon_template, created_by: teacher, title: same_title_source.title)
      sign_in teacher

      get coupon_templates_path

      document = Nokogiri::HTML(response.body)
      adopted_row = document.at_css("#library_coupon_template_#{adopted_source.id}")
      same_title_row = document.at_css("#library_coupon_template_#{same_title_source.id}")

      expect(document.at_css("turbo-frame#library").text).to include("추천 세트 적용")
      expect(adopted_row.text).to include("추가됨")
      expect(adopted_row.at_css(%(form[action="#{adopt_coupon_template_path(adopted_source)}"]))).to be_nil
      expect(same_title_row.text).to include("같은 이름의 쿠폰이 있습니다")
      expect(same_title_row.at_css(%(form[action="#{adopt_coupon_template_path(same_title_source)}"]))).to be_nil
      expect(response.body).not_to include("라이브러리 쿠폰 만들기")
    end

    it "shows the existing admin library management actions" do
      library_template = create(:coupon_template, created_by: admin, bucket: "library", weight: 30)
      sign_in admin

      get coupon_templates_path

      document = Nokogiri::HTML(response.body)
      library_frame = document.at_css("turbo-frame#library")
      row = document.at_css("#library_admin_coupon_template_#{library_template.id}")

      expect(library_frame.text).to include("가중치 균등 분배", "라이브러리 쿠폰 만들기")
      expect(library_frame.text).not_to include("추천 세트 적용")
      expect(row.at_css(%(form[action="#{toggle_active_coupon_template_path(library_template)}"]))).to be_present
      expect(row.at_css(%(form[action="#{adopt_coupon_template_path(library_template)}"]))).to be_nil
      expect(row.at_css(%(button[aria-label="가중치 10 낮추기"]))).to be_present
      expect(row.at_css(%(button[aria-label="가중치 10 높이기"]))).to be_present
      expect(row.at_css(%(a[data-turbo-frame="modal"][href="#{edit_coupon_template_path(library_template)}"]))).to be_present
    end

    it "renders personal and library empty states with their actions" do
      sign_in teacher

      get coupon_templates_path

      document = Nokogiri::HTML(response.body)

      expect(document.at_css("turbo-frame#personal").text).to include(
        "아직 만든 쿠폰이 없습니다.",
        "새 쿠폰 만들기"
      )
      expect(document.at_css("turbo-frame#library").text).to include(
        "사용 가능한 라이브러리 쿠폰이 없습니다.",
        "추천 세트 적용"
      )
    end
  end

  describe "coupon form image preview" do
    it "shows the generic default preview in the new personal coupon modal" do
      sign_in teacher

      get new_coupon_template_path, headers: modal_headers

      document = Nokogiri::HTML(response.body)
      preview_area = document.at_css(%([data-controller="coupon-image-preview"]))
      input = preview_area.at_css(%(input[type="file"][data-coupon-image-preview-target="input"]))
      preview_container = preview_area.at_css(%([data-coupon-image-preview-target="previewContainer"]))

      expect(response).to have_http_status(:ok)
      expect(input["accept"]).to eq("image/*")
      expect(input["data-action"]).to eq("change->coupon-image-preview#update")
      preview = preview_area.at_css(%(img[data-coupon-image-preview-target="preview"]))
      expect(preview["src"]).to include("coupon_templates/default")
      expect(preview["alt"]).to eq("쿠폰 이미지 미리보기")
      expect(preview_area["data-coupon-image-preview-initial-source-value"]).to include("coupon_templates/default")
      expect(preview_container.key?("hidden")).to eq(false)
      expect(response.body).not_to include("이미지 삭제")
    end

    it "shows the generic default preview in the new admin library coupon modal" do
      sign_in admin

      get new_coupon_template_path(bucket: "library"), headers: modal_headers

      document = Nokogiri::HTML(response.body)
      preview_area = document.at_css(%([data-controller="coupon-image-preview"]))
      preview_container = preview_area.at_css(%([data-coupon-image-preview-target="previewContainer"]))
      preview = preview_area.at_css(%(img[data-coupon-image-preview-target="preview"]))

      expect(preview_area["data-coupon-image-preview-initial-source-value"]).to include("coupon_templates/default")
      expect(preview["src"]).to include("coupon_templates/default")
      expect(preview["alt"]).to eq("쿠폰 이미지 미리보기")
      expect(preview_container.key?("hidden")).to eq(false)
      expect(response.body).not_to include("이미지 삭제")
    end

    it "shows the current default image in the edit coupon modal" do
      template = create(
        :coupon_template,
        created_by: teacher,
        default_image_key: "coupon_templates/mychew.png"
      )
      sign_in teacher

      get edit_coupon_template_path(template), headers: modal_headers

      document = Nokogiri::HTML(response.body)
      preview_area = document.at_css(%([data-controller="coupon-image-preview"]))
      preview_container = preview_area.at_css(%([data-coupon-image-preview-target="previewContainer"]))
      preview = preview_area.at_css(%(img[data-coupon-image-preview-target="preview"]))

      expect(response).to have_http_status(:ok)
      expect(preview_area["data-coupon-image-preview-initial-source-value"]).to include("coupon_templates/mychew")
      expect(preview["src"]).to include("coupon_templates/mychew")
      expect(preview["alt"]).to eq("쿠폰 이미지 미리보기")
      expect(preview_container.key?("hidden")).to eq(false)
    end

    it "does not show the source attachment for an adopted coupon without its own image" do
      source = create(:coupon_template, created_by: admin, bucket: "library", title: "원본 이미지 쿠폰")
      attach_image(source, content: "source preview", filename: "source-preview.png")
      adopted = create(
        :coupon_template,
        created_by: teacher,
        source_template: source,
        title: source.title,
        default_image_key: CouponTemplate::DEFAULT_IMAGE_KEY
      )
      sign_in teacher

      get edit_coupon_template_path(adopted), headers: modal_headers

      document = Nokogiri::HTML(response.body)
      preview_area = document.at_css(%([data-controller="coupon-image-preview"]))
      preview = preview_area.at_css(%(img[data-coupon-image-preview-target="preview"]))

      expect(preview_area["data-coupon-image-preview-initial-source-value"]).to eq(preview["src"])
      expect(preview["src"]).to include("coupon_templates/default")
      expect(preview["alt"]).to eq("쿠폰 이미지 미리보기")
    end

    it "renders the preview structure again after a validation failure" do
      sign_in teacher

      post coupon_templates_path,
        params: { coupon_template: { title: "", weight: 0, active: false } },
        headers: turbo_headers

      document = Nokogiri::HTML(response.body)
      preview_area = document.at_css(%([data-controller="coupon-image-preview"]))

      expect(response).to have_http_status(:unprocessable_entity)
      expect(preview_area).to be_present
      expect(preview_area.at_css(%(input[data-action="change->coupon-image-preview#update"]))).to be_present
    end
  end

  describe "Turbo frame refreshes" do
    it "allows a teacher to update a personal coupon image without changing weight or active state" do
      personal = create(
        :coupon_template,
        created_by: teacher,
        title: "이미지 수정 쿠폰",
        weight: 30,
        active: true
      )
      upload = Rack::Test::UploadedFile.new(
        StringIO.new("teacher image"),
        "image/png",
        original_filename: "teacher-upload.png"
      )
      sign_in teacher

      patch coupon_template_path(personal),
        params: {
          coupon_template: {
            title: "이미지 수정 완료",
            image: upload,
            weight: 90,
            active: false
          }
        },
        headers: turbo_headers

      targets = Nokogiri::HTML(response.body).css("turbo-stream").map { _1["target"] }
      personal.reload

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(personal.title).to eq("이미지 수정 완료")
      expect(personal.image).to be_attached
      expect(personal.image.blob.filename.to_s).to eq("teacher-upload.png")
      expect(personal.image.blob.content_type).to eq("image/png")
      expect(personal.weight).to eq(30)
      expect(personal).to be_active
      expect(targets).to include("personal", "modal", "flash")
    end

    it "refreshes personal, clears modal, and renders flash after creating a coupon" do
      sign_in teacher

      post coupon_templates_path,
        params: { coupon_template: { title: "새 개인 쿠폰", weight: 0, active: false } },
        headers: turbo_headers

      targets = Nokogiri::HTML(response.body).css("turbo-stream").map { _1["target"] }

      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(targets).to include("personal", "modal", "flash")
    end

    it "refreshes personal and library after adopting a library coupon" do
      library_template = create(:coupon_template, created_by: admin, bucket: "library", title: "개별 추천")
      attach_image(library_template, content: "source image", filename: "source.png")
      sign_in teacher

      post adopt_coupon_template_path(library_template), headers: turbo_headers

      document = Nokogiri::HTML(response.body)
      targets = document.css("turbo-stream").map { _1["target"] }
      adopted = CouponTemplate.find_by!(created_by: teacher, source_template: library_template)

      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(targets).to include("personal", "library", "flash")
      expect(adopted.image).to be_attached
      expect(adopted.image.blob_id).not_to eq(library_template.image.blob_id)
      expect(adopted.image.blob.filename.to_s).to eq("source.png")
      expect(adopted.image.blob.content_type).to eq("image/png")
      expect(adopted.image.download).to eq(library_template.image.download)
      expect(adopted.title).to eq(library_template.title)
      expect(adopted.weight).to eq(library_template.weight)
      expect(adopted.active).to eq(library_template.active)
      expect(adopted.default_image_key).to eq(library_template.default_image_key)
      expect(adopted.source_template_id).to eq(library_template.id)
    end

    it "does not change an existing personal coupon when the same source is adopted again" do
      source = create(:coupon_template, created_by: admin, bucket: "library", title: "개별 멱등 추천")
      attach_image(source, content: "source image")
      sign_in teacher
      post adopt_coupon_template_path(source), headers: turbo_headers
      adopted = CouponTemplate.find_by!(created_by: teacher, source_template: source)
      adopted.update!(
        title: "교사 제목",
        weight: 20,
        active: false,
        default_image_key: "coupon_templates/mychew.png"
      )
      attach_image(adopted, content: "teacher image", filename: "teacher.png")
      blob_id = adopted.image.blob_id
      count = CouponTemplate.where(created_by: teacher, source_template: source).count

      post adopt_coupon_template_path(source), headers: turbo_headers

      adopted.reload
      expect(CouponTemplate.where(created_by: teacher, source_template: source).count).to eq(count)
      expect(adopted.title).to eq("교사 제목")
      expect(adopted.weight).to eq(20)
      expect(adopted).not_to be_active
      expect(adopted.default_image_key).to eq("coupon_templates/mychew.png")
      expect(adopted.image.blob_id).to eq(blob_id)
      expect(adopted.image.download).to eq("teacher image")
    end

    it "does not create or link a coupon when adopting a library coupon with a conflicting title" do
      source = create(:coupon_template, created_by: admin, bucket: "library", title: "겹치는 추천")
      existing = create(
        :coupon_template,
        created_by: teacher,
        title: source.title,
        weight: 20,
        active: false,
        source_template_id: nil
      )
      sign_in teacher

      expect {
        post adopt_coupon_template_path(source), headers: turbo_headers
      }.not_to change { CouponTemplate.where(created_by: teacher, bucket: "personal").count }

      existing.reload
      document = Nokogiri::HTML(response.body)
      library_stream = document.at_css(%(turbo-stream[target="library"]))

      expect(existing.source_template_id).to be_nil
      expect(existing.weight).to eq(20)
      expect(existing).not_to be_active
      expect(response.body).to include("같은 이름의 쿠폰이 있어 가져오지 않았습니다.")
      expect(library_stream.to_html).to include("같은 이름의 쿠폰이 있습니다")
      expect(library_stream.at_css(%(form[action="#{adopt_coupon_template_path(source)}"]))).to be_nil
    end

    it "redirects without changing an existing personal coupon when adopting a conflicting title over HTML" do
      source = create(:coupon_template, created_by: admin, bucket: "library", title: "HTML 겹치는 추천")
      existing = create(
        :coupon_template,
        created_by: teacher,
        title: source.title,
        weight: 20,
        active: false,
        source_template_id: nil
      )
      sign_in teacher

      expect {
        post adopt_coupon_template_path(source)
      }.not_to change { CouponTemplate.where(created_by: teacher, bucket: "personal").count }

      existing.reload

      expect(existing.source_template_id).to be_nil
      expect(existing.weight).to eq(20)
      expect(existing).not_to be_active
      expect(response).to redirect_to(coupon_templates_path)
      expect(flash[:alert]).to eq("같은 이름의 쿠폰이 있어 가져오지 않았습니다.")
    end

    it "refreshes library after deleting a coupon adopted by source id" do
      library_template = create(:coupon_template, created_by: admin, bucket: "library", title: "삭제할 추천")
      adopted = create(
        :coupon_template,
        created_by: teacher,
        title: library_template.title,
        source_template_id: library_template.id
      )
      sign_in teacher

      delete coupon_template_path(adopted), headers: turbo_headers

      document = Nokogiri::HTML(response.body)
      library_stream = document.at_css(%(turbo-stream[target="library"]))

      expect(library_stream).to be_present
      expect(library_stream.to_html).to include("내 쿠폰에 추가")
      expect(library_stream.to_html).not_to include("추가됨")
    end

    it "refreshes personal and library after applying the recommended set" do
      source = create(:coupon_template, created_by: admin, bucket: "library", title: "추천 세트 쿠폰")
      attach_image(source, content: "recommended image")
      sign_in teacher

      post adopt_all_from_library_coupon_templates_path, headers: turbo_headers

      targets = Nokogiri::HTML(response.body).css("turbo-stream").map { _1["target"] }
      adopted = CouponTemplate.find_by!(created_by: teacher, source_template: source)

      expect(targets).to include("personal", "library", "flash")
      expect(adopted.image.blob_id).not_to eq(source.image.blob_id)
      expect(adopted.image.download).to eq(source.image.download)
      expect(adopted.source_template_id).to eq(source.id)
      expect(adopted.title).to eq(source.title)
      expect(adopted.weight).to eq(source.weight)
      expect(adopted.active).to eq(source.active)
      expect(adopted.default_image_key).to eq(source.default_image_key)
      expect(response.body).to include("추천 세트에서 새 쿠폰 1개를 추가했습니다. 0개는 건너뛰었습니다.")
    end

    it "skips only title conflicts when applying the recommended set" do
      conflicting_source = create(:coupon_template, created_by: admin, bucket: "library", title: "겹치는 세트 쿠폰")
      new_source = create(:coupon_template, created_by: admin, bucket: "library", title: "새 세트 쿠폰")
      existing = create(
        :coupon_template,
        created_by: teacher,
        title: conflicting_source.title,
        weight: 10,
        active: false,
        source_template_id: nil
      )
      sign_in teacher

      expect {
        post adopt_all_from_library_coupon_templates_path, headers: turbo_headers
      }.to change { CouponTemplate.where(created_by: teacher, bucket: "personal").count }.by(1)

      existing.reload
      adopted = CouponTemplate.find_by!(created_by: teacher, source_template: new_source)

      expect(adopted.title).to eq(new_source.title)
      expect(CouponTemplate.find_by(created_by: teacher, source_template: conflicting_source)).to be_nil
      expect(existing.source_template_id).to be_nil
      expect(existing.weight).to eq(10)
      expect(existing).not_to be_active
      expect(response.body).to include("추천 세트에서 새 쿠폰 1개를 추가했습니다. 1개는 건너뛰었습니다.")
    end

    it "preserves every customized field on an existing adopted coupon" do
      source = create(
        :coupon_template,
        created_by: admin,
        bucket: "library",
        title: "원본 추천",
        weight: 80,
        active: true,
        default_image_key: "coupon_templates/chocolate.png"
      )
      attach_image(source, content: "source before")
      adopted = create(
        :coupon_template,
        created_by: teacher,
        source_template: source,
        title: "교사 맞춤 제목",
        weight: 20,
        active: false,
        default_image_key: "coupon_templates/mychew.png"
      )
      attach_image(adopted, content: "teacher custom image", filename: "custom.png")
      target_blob_id = adopted.image.blob_id
      source.update!(title: "관리자 변경 제목", weight: 90, default_image_key: "coupon_templates/lunch_seat.png")
      attach_image(source, content: "source after", filename: "source-after.png")
      sign_in teacher

      post adopt_all_from_library_coupon_templates_path, headers: turbo_headers

      adopted.reload
      expect(adopted.title).to eq("교사 맞춤 제목")
      expect(adopted.weight).to eq(20)
      expect(adopted).not_to be_active
      expect(adopted.default_image_key).to eq("coupon_templates/mychew.png")
      expect(adopted.image.blob_id).to eq(target_blob_id)
      expect(adopted.image.download).to eq("teacher custom image")
      expect(response.body).to include("새로 추가한 쿠폰이 없습니다. 1개는 건너뛰었습니다.")
    end
  end

  describe "DELETE /coupon_templates/:id/remove_image" do
    it "removes a teacher's personal image and refreshes personal, modal, and flash" do
      personal = create(
        :coupon_template,
        created_by: teacher,
        default_image_key: "coupon_templates/chocolate.png"
      )
      attach_image(personal, content: "personal image")
      sign_in teacher

      get edit_coupon_template_path(personal), headers: modal_headers
      edit_document = Nokogiri::HTML(response.body)
      expect(edit_document.at_css(%(a[href="#{remove_image_coupon_template_path(personal)}"][data-turbo-method="delete"]))).to be_present
      expect(edit_document.text).to include("쿠폰 삭제", "삭제는 되돌릴 수 없어요.")

      delete remove_image_coupon_template_path(personal), headers: turbo_headers

      document = Nokogiri::HTML(response.body)
      targets = document.css("turbo-stream").map { _1["target"] }
      modal_stream = document.at_css(%(turbo-stream[target="modal"]))

      expect(response).to have_http_status(:ok)
      expect(personal.reload.image).not_to be_attached
      expect(personal.default_image_key).to eq("coupon_templates/chocolate.png")
      expect(targets).to include("personal", "modal", "flash")
      expect(modal_stream.to_html).to include("coupon_templates/chocolate")
      expect(modal_stream.to_html).not_to include("이미지 삭제")
    end

    it "removes an admin library image and refreshes library, modal, and flash" do
      library_template = create(
        :coupon_template,
        created_by: admin,
        bucket: "library",
        default_image_key: "coupon_templates/mychew.png"
      )
      attach_image(library_template, content: "library image")
      sign_in admin

      delete remove_image_coupon_template_path(library_template), headers: turbo_headers

      targets = Nokogiri::HTML(response.body).css("turbo-stream").map { _1["target"] }

      expect(response).to have_http_status(:ok)
      expect(library_template.reload.image).not_to be_attached
      expect(library_template.default_image_key).to eq("coupon_templates/mychew.png")
      expect(targets).to include("library", "modal", "flash")
    end

    it "rejects another teacher removing a personal coupon image" do
      personal = create(:coupon_template, created_by: teacher)
      attach_image(personal, content: "owner image")
      sign_in create(:user, :teacher)

      delete remove_image_coupon_template_path(personal), headers: turbo_headers

      expect(response).to have_http_status(:forbidden)
      expect(personal.reload.image).to be_attached
    end

    it "rejects a teacher removing a library coupon image" do
      library_template = create(:coupon_template, created_by: admin, bucket: "library")
      attach_image(library_template, content: "admin image")
      sign_in teacher

      delete remove_image_coupon_template_path(library_template), headers: turbo_headers

      expect(response).to have_http_status(:forbidden)
      expect(library_template.reload.image).to be_attached
    end

    it "keeps the source image when a legacy shared target attachment is removed" do
      source = create(:coupon_template, created_by: admin, bucket: "library", title: "공유 원본")
      attach_image(source, content: "shared content")
      target = create(:coupon_template, created_by: teacher, source_template: source, title: source.title)
      target.image.attach(source.image.blob)
      sign_in teacher

      delete remove_image_coupon_template_path(target), headers: turbo_headers

      expect(target.reload.image).not_to be_attached
      expect(source.reload.image).to be_attached
      expect(source.image.download).to eq("shared content")
    end

    it "keeps the personal image when a legacy shared source attachment is removed" do
      source = create(:coupon_template, created_by: admin, bucket: "library", title: "삭제할 공유 원본")
      attach_image(source, content: "shared content")
      target = create(:coupon_template, created_by: teacher, source_template: source, title: source.title)
      target.image.attach(source.image.blob)
      sign_in admin

      delete remove_image_coupon_template_path(source), headers: turbo_headers

      expect(source.reload.image).not_to be_attached
      expect(target.reload.image).to be_attached
      expect(target.image.download).to eq("shared content")
    end
  end
end
