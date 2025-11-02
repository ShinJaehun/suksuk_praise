class CouponTemplatesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_coupon_template, only: [:edit, :update, :toggle_active, :adopt, :destroy]

  # 더블클릭/중복요청 소프트 가드(2초)
  DUP_WINDOW = 2.seconds

  def index
    authorize CouponTemplate

    @mine = policy_scope(CouponTemplate).order(:title)
    @mine_rows = build_rows(@mine)

    # 역할별 가시성(관리자=전체, 교사=active만) + 정렬은 정책 스코프에서 처리
    load_library!
    @library_admin = current_user.admin?

  end

  def new
    authorize CouponTemplate
    @bucket = (current_user.admin? && params[:bucket] == "library") ? "library" : "personal"
    @coupon_template = CouponTemplate.new(active: true, weight: 50)
    render layout: false if turbo_frame_request?  
  end

  def create
    authorize CouponTemplate

    bucket = (current_user.admin? && 
      (params[:bucket] == "library" ||
        params.dig(:coupon_template, :bucket) == "library")) ? "library" : "personal"

    @coupon_template = CouponTemplate.new(
      coupon_template_params.merge(created_by_id: current_user.id, bucket: bucket))
    
    if @coupon_template.save
      message = t("coupon_templates.flash.created")
      
      if bucket == "library"
        load_library!
        
        respond_to do |f|
          f.html { redirect_to coupon_templates_path, notice: message }
          f.turbo_stream do
            flash.now[:notice] = message
            render :create_library, layout: "application"
          end
        end
      else

        @mine = policy_scope(CouponTemplate).order(:title)
        @mine_rows = build_rows(@mine)

        respond_to do |f|
          f.html { redirect_to coupon_templates_path, notice: message }
          f.turbo_stream do
            flash.now[:notice] = message
            render :create, layout: "application"
          end
        end
      end
     
    else
      respond_to do |f|
        f.html { render :new, status: :unprocessable_entity }
        f.turbo_stream { render :new, status: :unprocessable_entity, layout: false }
      end
    end
  end

  def edit
    authorize @coupon_template
    render layout: false if turbo_frame_request?  
  end

  def update
    authorize @coupon_template
    
    if @coupon_template.update(coupon_template_params)
      message = t("coupon_templates.flash.updated")

      @mine = policy_scope(CouponTemplate).order(:title)
      @mine_rows = build_rows(@mine)

      load_library! if current_user.admin? && @coupon_template.bucket == "library"

      respond_to do |f|
        f.html { redirect_to coupon_templates_path, notice: message }
        f.turbo_stream do
          flash.now[:notice] = message
          render :update, layout: "application"
        end
      end
    else
      respond_to do |f|
        f.html { render :edit, status: :unprocessable_entity }
        f.turbo_stream { render :edit, status: :unprocessable_entity, layout: false }
      end
    end
  end

  # 리스트에서 빠른 on/off
  def toggle_active
    authorize @coupon_template
    @coupon_template.update!(active: !@coupon_template.active)

    @mine = policy_scope(CouponTemplate).order(:title)
    @mine_rows = build_rows(@mine)

    message = t("coupon_templates.flash.toggled")

    load_library! if current_user.admin? && @coupon_template.bucket == "library"

    respond_to do |f|
      f.html { redirect_to coupon_templates_path, notice: message }
      f.turbo_stream do
        flash.now[:notice] = message
        render :update, layout: "application"
      end
    end
  end

  # 라이브러리 → 내 세트로 복제
  def adopt
    # 라이브러리 대상만 허용(=admin 소유)
    library_scope = CouponTemplatePolicy::Scope.library_scope(current_user, CouponTemplate)
    source = library_scope.find(@coupon_template.id)
    authorize source, :adopt?

    # 소프트 가드(2초 내 중복 가져오기 방지)
    if CouponTemplate.where(created_by_id: current_user.id, title: source.title, bucket: "personal")
                     .where("created_at >= ?", Time.current - DUP_WINDOW).exists?
                     
      @mine = policy_scope(CouponTemplate).order(:title)
      @mine_rows = build_rows(@mine)

      message = t("coupon_templates.flash.adopt_duplicate")

      respond_to do |f|
        f.html  { redirect_to coupon_templates_path, alert: message }
        f.turbo_stream do

          @mine = policy_scope(CouponTemplate).order(:title)
          @mine_rows = build_rows(@mine)

          flash.now[:alert] = message
          render :adopt, status: :conflict, layout: "application"
        end
      end
      return
    end

    # 멱등 처리: 이미 내(personal) 버킷에 같은 제목이 있으면 생성하지 않음
    existing = CouponTemplate.find_by(
      created_by_id: current_user.id,
      bucket:        "personal",
      title:         source.title
    )
    
    if existing
      @mine   = policy_scope(CouponTemplate).order(:title)
      @mine_rows = build_rows(@mine)

      message = t("coupon_templates.flash.already_in_mine", default: "이미 내 쿠폰에 있습니다.")
      respond_to do |f|
        f.html        { redirect_to coupon_templates_path, notice: message }
        f.turbo_stream do
          flash.now[:notice] = message
          render :adopt, layout: "application"
        end
      end
      return
    end

    @adopted = CouponTemplate.create!(
      title: source.title,
      weight: source.weight,
      active: source.active,
      bucket: "personal",
      created_by_id: current_user.id
    )

    @mine = policy_scope(CouponTemplate).order(:title)
    @mine_rows = build_rows(@mine)

    message = t("coupon_templates.flash.adopted")
    respond_to do |f|
      f.html { redirect_to coupon_templates_path, notice: message }
      f.turbo_stream do
        flash.now[:notice] = message
        render :adopt, layout: "application"
      end
    end
  end

  def destroy
    authorize @coupon_template
    was_library = (@coupon_template.bucket == "library")

    begin
      # 발급 이력이 없으면 정상 삭제
      @coupon_template.destroy!  
      message = t("coupon_templates.flash.deleted", default: "삭제했습니다.")
    rescue ActiveRecord::DeleteRestrictionError
      # 발급 이력이 있으면 삭제 대신 숨김 처리
      @coupon_template.update!(active: false)
      message = t("coupon_templates.flash.deactivated_instead",
                  default: "이미 발급한 쿠폰이 있어 삭제할 수 없어 비활성화했습니다.")
    end

    # 프레임 갱신에 쓸 데이터 준비
    @mine = policy_scope(CouponTemplate).order(:title)
    @mine_rows = build_rows(@mine)

    load_library! if current_user.admin? && was_library

    respond_to do |f|
      f.html { redirect_to coupon_templates_path, notice: message }
      f.turbo_stream do
        flash.now[:notice] = message
        render :destroy, layout: "application" 
      end
    end
  end

  private
  def set_coupon_template
    @coupon_template = CouponTemplate.find(params[:id])
  end

  def coupon_template_params
    params.require(:coupon_template).permit(:title, :weight, :active)
  end

  # 프레젠테이션 행 데이터(권한 포함)를 구성
  Row = Struct.new(:tpl, :can_destroy, keyword_init: true)
  def build_rows(relation)
    # N회 policy 호출은 여기서만 수행; 뷰는 데이터만 사용
    relation.map do |tpl|
      pol = Pundit.policy!(current_user, tpl)
      Row.new(
        tpl: tpl,
        can_destroy: pol.destroy?
      )
    end
  end


  # 라이브러리 스코프 로딩 + 물리화(뷰에서 SELECT 라벨 안 찍히도록)
  def load_library!
    @library = CouponTemplatePolicy::Scope.library_scope(current_user, CouponTemplate)
    @library = @library.to_a
  end
end
