class CouponTemplatesController < ApplicationController
  include ActionView::RecordIdentifier

  before_action :authenticate_user!
  before_action :set_coupon_template,
                only: %i[edit update toggle_active adopt destroy bump_weight remove_image]
  before_action :set_form_mode, only: %i[new edit]

  def index
    authorize CouponTemplate

    load_personal!

    # 역할별 가시성(관리자=전체, 교사=active만) + 정렬은 정책 스코프에서 처리
    load_library!
    @library_admin = current_user.admin?
  end

  def new
    authorize CouponTemplate
    @bucket = current_user.admin? && params[:bucket] == 'library' ? 'library' : 'personal'

    # bucket에 따라 기본값을 다르게 설정한다.
    # - library: 관리자가 바로 사용할 수 있도록 active=true, weight=50 (기존 동작 유지)
    # - personal: 기본은 비활성/가중치 0에서 시작 → 저장 후 목록에서 버튼으로 조정
    default_attrs =
      if @bucket == 'library'
        { active: true,  weight: 50 }
      else
        { active: false, weight: 0 }
      end

    @coupon_template = CouponTemplate.new(
      default_attrs.merge(
        bucket: @bucket,
        created_by_id: current_user.id
      )
    )

    render layout: false if turbo_frame_request?
  end

  def create
    authorize CouponTemplate

    bucket = if current_user.admin? &&
                (params[:bucket] == 'library' ||
                  params.dig(:coupon_template, :bucket) == 'library')
               'library'
             else
               'personal'
             end
    @is_library = bucket == 'library'

    @coupon_template = CouponTemplate.new(
      coupon_template_params.merge(
        created_by_id: current_user.id,
        bucket: bucket
      )
    )

    if bucket == 'personal'
      @coupon_template.active = false
      @coupon_template.weight = 0
    end

    if @coupon_template.save
      message = t('coupon_templates.flash.created')

      if bucket == 'library'
        load_library!

        respond_to do |f|
          f.html { redirect_to coupon_templates_path, notice: message }
          f.turbo_stream do
            flash.now[:notice] = message
            render :create_library, layout: 'application'
          end
        end
      else

        load_personal!

        respond_to do |f|
          f.html { redirect_to coupon_templates_path, notice: message }
          f.turbo_stream do
            flash.now[:notice] = message
            render :create, layout: 'application'
          end
        end
      end

    else
      respond_to do |f|
        f.html { render :new, status: :unprocessable_entity }
        f.turbo_stream do
          render turbo_stream: turbo_stream.update(
            'modal',
            partial: 'coupon_templates/new_modal'
          ), status: :unprocessable_entity
        end
      end
    end
  end

  def edit
    authorize @coupon_template
    render layout: false if turbo_frame_request?
  end

  def update
    authorize @coupon_template

    # 편집 정책:
    # - library(관리자용): title/weight/active 모두 수정 가능
    # - personal(교사용): title/image만 수정, weight/active는 버튼/토글로만 조정
    attrs = coupon_template_params

    if @coupon_template.bucket == 'personal'
      # personal 세트에서는 title/image만 허용
      # (permit 반환값은 ActionController::Parameters 이므로 slice 사용 가능)
      attrs = attrs.slice(:title, :image)
    end

    if @coupon_template.update(attrs)
      message = t('coupon_templates.flash.updated')

      load_personal!

      load_library! if current_user.admin? && @coupon_template.bucket == 'library'

      respond_to do |f|
        f.html { redirect_to coupon_templates_path, notice: message }
        f.turbo_stream do
          flash.now[:notice] = message
          render :update, layout: 'application'
        end
      end
    else
      respond_to do |f|
        f.html { render :edit, status: :unprocessable_entity }
        f.turbo_stream do
          render turbo_stream: turbo_stream.update(
            'modal',
            partial: 'coupon_templates/edit_modal'
          ), status: :unprocessable_entity
        end
      end
    end
  end

  # 리스트에서 빠른 on/off
  def toggle_active
    authorize @coupon_template

    @coupon_template.update!(active: !@coupon_template.active)

    load_personal!

    message = t('coupon_templates.flash.toggled')

    load_library! if current_user.admin? && @coupon_template.bucket == 'library'

    respond_to do |f|
      f.html { redirect_to coupon_templates_path, notice: message }
      f.turbo_stream do
        flash.now[:notice] = message
        render :update, layout: 'application'
      end
    end
  end

  # 라이브러리 → 내 세트로 복제
  def adopt
    # 라이브러리 대상만 허용(=admin 소유)
    library_scope = CouponTemplatePolicy::Scope.library_scope(current_user, CouponTemplate)
    source = library_scope.find(@coupon_template.id)
    authorize source, :adopt?

    # 이미 source_template_id로 가져온 적 있으면 멱등 처리
    existing_by_source = CouponTemplate.find_by(created_by_id: current_user.id, bucket: 'personal',
                                                source_template_id: source.id)
    if existing_by_source
      load_personal!
      load_library!
      message = t('coupon_templates.flash.already_in_personal')
      respond_to do |f|
        f.html { redirect_to coupon_templates_path, notice: message }
        f.turbo_stream do
          flash.now[:notice] = message
          render :adopt, layout: 'application'
        end
      end
      return
    end

    @adopted = build_adopted_coupon_template(source)
    unless @adopted.valid?
      raise ActiveRecord::RecordInvalid, @adopted unless title_uniqueness_conflict?(@adopted)

      load_personal!
      load_library!
      message = t('coupon_templates.flash.title_conflict')
      respond_to do |f|
        f.html { redirect_to coupon_templates_path, alert: message }
        f.turbo_stream do
          flash.now[:alert] = message
          render :adopt, layout: 'application'
        end
      end
      return
    end

    begin
      CouponTemplate.transaction do
        @adopted.save!
        CouponTemplates::ImageCopier.copy!(source:, target: @adopted)
      end
    rescue CouponTemplates::ImageCopier::CopyError => e
      log_image_copy_failure(source, e)
      load_personal!
      load_library!
      message = t('coupon_templates.flash.image_copy_failed')
      respond_to do |f|
        f.html { redirect_to coupon_templates_path, alert: message }
        f.turbo_stream do
          flash.now[:alert] = message
          render :adopt, layout: 'application'
        end
      end
      return
    end

    load_personal!
    load_library!

    message = t('coupon_templates.flash.adopted')
    respond_to do |f|
      f.html { redirect_to coupon_templates_path, notice: message }
      f.turbo_stream do
        flash.now[:notice] = message
        render :adopt, layout: 'application'
      end
    end
  end

  def destroy
    authorize @coupon_template
    begin
      # 발급 이력이 없으면 정상 삭제
      @coupon_template.destroy!
      message = t('coupon_templates.flash.deleted', default: '삭제했습니다.')
    rescue ActiveRecord::DeleteRestrictionError
      # 발급 이력이 있으면 삭제 대신 숨김 처리
      @coupon_template.update!(active: false)
      message = t('coupon_templates.flash.deactivated_instead',
                  default: '이미 발급한 쿠폰이 있어 삭제할 수 없어 비활성화했습니다.')
    end

    # 프레임 갱신에 쓸 데이터 준비
    load_personal!

    load_library!

    respond_to do |f|
      f.html { redirect_to coupon_templates_path, notice: message }
      f.turbo_stream do
        flash.now[:notice] = message
        render :destroy, layout: 'application'
      end
    end
  end

  def remove_image
    authorize @coupon_template, :update?

    remove_coupon_image!

    if @coupon_template.bucket == 'library'
      load_library!
    else
      load_personal!
    end

    message = t('coupon_templates.flash.image_removed')

    respond_to do |f|
      f.html { redirect_to coupon_templates_path, notice: message }
      f.turbo_stream do
        flash.now[:notice] = message
        render :remove_image, layout: 'application'
      end
    end
  end

  def bump_weight
    authorize @coupon_template

    amount  = params[:amount].to_i
    snapped = ((@coupon_template.weight.to_i + amount).clamp(0, 100) / 10.0).round * 10

    # --- 라이브러리: admin이 개별 템플릿 weight만 조정 (합 100 강제 안 함) ---
    if @coupon_template.bucket == 'library' && current_user.admin?
      @coupon_template.update!(weight: snapped)

      load_personal!
      load_library! # => @library + @library_active_weight_sum 갱신

      flash.now[:notice] = "라이브러리 가중치를 #{snapped}으로 변경했습니다."
      return render :update, layout: 'application'
    end

    # --- personal: 합계/정규화 신경 쓰지 않고 단순히 weight만 조정 ---
    if snapped == 0
      # weight=0이면 자동으로 비활성화(이것만 유지)
      @coupon_template.update!(weight: 0, active: false)
      flash.now[:notice] = '가중치를 0으로 내려 비활성화했습니다.'
    else
      @coupon_template.update!(weight: snapped)
      flash.now[:notice] = "가중치를 #{snapped}으로 변경했어요."
    end

    # personal 전체 다시 그림(합계/버튼 disabled 반영)
    load_personal!

    render :update, layout: 'application' # (= personal 프레임 replace)
  end

  def rebalance_personal
    authorize CouponTemplate, :rebalance_equal?
    CouponTemplates::WeightBalancer.normalize!(current_user)
    reload_personal_and_flash!('활성 쿠폰을 균등 분배했습니다.')
  end

  def rebalance_library
    authorize CouponTemplate, :rebalance_equal?
    raise Pundit::NotAuthorizedError unless current_user.admin?

    CouponTemplates::WeightBalancer.normalize_library!

    load_library!
    reload_personal_and_flash!(
      t('coupon_templates.flash.library_rebalanced',
        default: '라이브러리 활성 쿠폰의 가중치를 균등 분배했습니다.')
    )
  end

  def adopt_all_from_library
    authorize CouponTemplate, :adopt?

    source_scope = CouponTemplatePolicy::Scope.library_scope(current_user, CouponTemplate)
    templates = source_scope
                .where(active: true)
                .includes(image_attachment: :blob)

    existing_source_ids = policy_scope(CouponTemplate)
                          .where(source_template_id: templates.map(&:id))
                          .pluck(:source_template_id)
                          .to_set
    created = 0
    skipped = 0
    image_copy_failed = 0

    templates.each do |src|
      if existing_source_ids.include?(src.id)
        skipped += 1
        next
      end

      created_template = build_adopted_coupon_template(src)
      unless created_template.valid?
        raise ActiveRecord::RecordInvalid, created_template unless title_uniqueness_conflict?(created_template)

        skipped += 1
        next
      end

      begin
        CouponTemplate.transaction do
          created_template.save!
          CouponTemplates::ImageCopier.copy!(source: src, target: created_template)
        end
        created += 1
      rescue CouponTemplates::ImageCopier::CopyError => e
        log_image_copy_failure(src, e)
        image_copy_failed += 1
      end
    end

    load_personal!
    load_library!

    message =
      if created.positive?
        t('coupon_templates.flash.adopt_all',
          created_count: created,
          skipped_count: skipped,
          image_copy_failed_count: image_copy_failed)
      else
        t('coupon_templates.flash.adopt_all_nothing',
          skipped_count: skipped,
          image_copy_failed_count: image_copy_failed)
      end

    respond_to do |f|
      f.html { redirect_to coupon_templates_path, notice: message }
      f.turbo_stream do
        flash.now[:notice] = message
        render :adopt_all_from_library, layout: 'application'
      end
    end
  end

  private

  def set_coupon_template
    @coupon_template = CouponTemplate.find(params[:id])
  end

  def coupon_template_params
    params.require(:coupon_template).permit(:title, :weight, :active, :image)
  end

  def set_form_mode
    @is_library =
      if action_name == 'new'
        current_user.admin? && params[:bucket] == 'library'
      else
        @coupon_template&.bucket == 'library'
      end
  end

  # 프레젠테이션 행 데이터(권한 포함)를 구성
  Row = Struct.new(
    :tpl,
    :can_destroy,
    :can_decrease_weight, :decrease_title,
    :can_increase_weight, :increase_title,
    :can_toggle_active,   :toggle_title,
    keyword_init: true
  )

  def build_rows(relation)
    # N회 policy 호출은 여기서만 수행; 뷰는 데이터만 사용
    rows = relation.map do |tpl|
      pol = Pundit.policy!(current_user, tpl)
      Row.new(
        tpl: tpl,
        can_destroy: pol.destroy?
      )
    end

    rows.each do |row|
      tpl     = row.tpl
      weight  = tpl.weight.to_i
      active  = tpl.active?

      # ← 버튼: weight가 0이면 더 줄일 수 없음
      row.can_decrease_weight =
        weight > 0
      row.decrease_title =
        row.can_decrease_weight ? nil : I18n.t('coupon_templates.titles.minimum_weight')

      # 증가 버튼: 개별 쿠폰의 현재 허용 범위만 확인
      row.can_increase_weight = weight < 100
      row.increase_title =
        if row.can_increase_weight
          nil
        else
          I18n.t('coupon_templates.titles.maximum_weight')
        end

      # ON/OFF 토글: weight=0 인 비활성 상태에서는 활성화할 수 없음
      row.can_toggle_active =
        !(!active && weight == 0)
      row.toggle_title =
        if !active && weight == 0
          I18n.t('coupon_templates.titles.zero_weight_cannot_activate')
        else
          nil
        end
    end

    rows
  end

  # 라이브러리 스코프 로딩 + 물리화(뷰에서 SELECT 라벨 안 찍히도록)
  def load_library!
    @library = CouponTemplatePolicy::Scope
               .library_scope(current_user, CouponTemplate)
               .includes(image_attachment: :blob)
               .to_a
    load_adopted_library_source_ids!
    load_library_title_conflict_ids!
  end

  def load_adopted_library_source_ids!
    @adopted_library_source_ids =
      policy_scope(CouponTemplate)
      .where.not(source_template_id: nil)
      .pluck(:source_template_id)
  end

  def load_library_title_conflict_ids!
    @library_title_conflict_ids =
      Array(@library).filter_map do |source|
        next if Array(@adopted_library_source_ids).include?(source.id)

        source.id if title_uniqueness_conflict?(build_adopted_coupon_template(source))
      end
  end

  def reload_personal_and_flash!(message)
    load_personal!
    respond_to do |f|
      f.html { redirect_to coupon_templates_path, notice: message }
      f.turbo_stream do
        flash.now[:notice] = message
        render :update, layout: 'application'
      end
    end
  end

  def load_personal!
    @personal = policy_scope(CouponTemplate)
                .includes(image_attachment: :blob)
                .order(:title)
    @personal_rows = build_rows(@personal)
  end

  def build_adopted_coupon_template(source)
    CouponTemplate.new(
      title: source.title,
      active: source.active,
      weight: source.weight,
      default_image_key: source.default_image_key,
      bucket: 'personal',
      created_by_id: current_user.id,
      source_template_id: source.id
    )
  end

  def title_uniqueness_conflict?(coupon_template)
    coupon_template.valid?
    coupon_template.errors.where(:title).any? do |error|
      error.type == :taken || error.options[:message] == :already_in_bucket
    end
  end

  def log_image_copy_failure(source, error)
    Rails.logger.error(
      "[CouponTemplates::ImageCopier] source_template_id=#{source.id} #{error.class}: #{error.message}"
    )
  end

  def remove_coupon_image!
    attachment = @coupon_template.image_attachment
    blob = attachment&.blob
    return unless attachment

    @coupon_template.image.detach
    blob.purge if blob && !blob.attachments.exists?
  end
end
