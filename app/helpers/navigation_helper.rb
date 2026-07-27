module NavigationHelper
  def can_view_compliment_logs?
    return false unless current_user

    Pundit.policy!(current_user, Compliment).index?
  rescue Pundit::NotDefinedError
    false
  end

  def can_manage_compliment_presets?
    return false unless current_user&.teacher? || current_user&.admin?

    Pundit.policy!(current_user, ComplimentPreset).index?
  rescue Pundit::NotDefinedError
    false
  end

  def can_view_coupon_events?
    return false unless current_user
    Pundit.policy!(current_user, CouponEvent).index?
  rescue Pundit::NotDefinedError
    false
  end

  def can_manage_coupon_templates?
    return false unless current_user
    Pundit.policy!(current_user, CouponTemplate).index?
  rescue Pundit::NotDefinedError
    false
  end

  # 관리자만 교사 관리 화면 접근 가능
  def can_manage_teachers?
    return false unless current_user
    Pundit.policy!(current_user, User).index?
  rescue Pundit::NotDefinedError
    false
  end

  def school_manager_membership_for_nav
    return nil unless active_teacher_school
    return @school_manager_membership_for_nav if defined?(@school_manager_membership_for_nav)

    membership = current_user.school_membership
    @school_manager_membership_for_nav = membership&.manager? ? membership : nil
  end

  def active_teacher_school
    return nil unless current_user&.active_teacher?
    return @active_teacher_school if defined?(@active_teacher_school)

    membership = current_user.school_membership
    @active_teacher_school = School.active.find_by(id: membership&.school_id)
  end
end
