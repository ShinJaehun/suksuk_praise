module NavigationHelper
  def primary_navigation_items(context)
    user = context[:user]
    return [] unless user

    if user.admin?
      [
        navigation_item("navigation.school_management", schools_path),
        navigation_item("navigation.dashboard", dashboard_path),
        navigation_item("navigation.classrooms", classrooms_path),
        (navigation_item("navigation.teacher_management", admin_teachers_path) if can_manage_teachers?)
      ].compact
    elsif context[:manager_membership]
      school = context[:manager_membership].school
      [
        navigation_item("navigation.school_operations", school_path(school)),
        navigation_item("navigation.dashboard", dashboard_path),
        navigation_item("navigation.classrooms", classrooms_path),
        navigation_item("navigation.teacher_management", school_teachers_path(school))
      ]
    elsif user.teacher?
      [navigation_item("navigation.dashboard", dashboard_path)]
    elsif user.student?
      [
        navigation_item("navigation.dashboard", dashboard_path),
        navigation_item("navigation.my_praise_book", user_path(user))
      ]
    else
      []
    end
  end

  def teacher_classroom_navigation(context)
    return unless context[:user]&.teacher? && !context[:manager_membership]

    classrooms = context.fetch(:classrooms, [])
    {
      mode: classrooms.none? ? :index : (classrooms.one? ? :single : :multiple),
      classrooms: classrooms
    }
  end

  def management_navigation_groups
    [
      {
        label: t("navigation.coupon_group"),
        items: [
          (navigation_item("navigation.coupon_management", coupon_templates_path) if can_manage_coupon_templates?),
          (navigation_item("navigation.coupon_log", coupon_events_path) if can_view_coupon_events?)
        ].compact
      },
      {
        label: t("navigation.compliment_group"),
        items: [
          (navigation_item("navigation.compliment_phrase_management", compliment_templates_path) if can_manage_compliment_presets?),
          (navigation_item("navigation.compliment_log", compliment_events_path) if can_view_compliment_logs?)
        ].compact
      }
    ].reject { |group| group[:items].empty? }
  end

  def navigation_account(context)
    user = context[:user]
    return unless user

    {
      user: user,
      display_name: user.name.presence || user.email,
      edit_path: (edit_user_registration_path unless user.student?),
      sign_out_label: t(user.student? ? "navigation.account.finish" : "navigation.account.sign_out"),
      sign_out_path: user.student? ? destroy_student_session_path : destroy_user_session_path
    }
  end

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

  private

  def navigation_item(label_key, path)
    { label: t(label_key), path: path }
  end
end
