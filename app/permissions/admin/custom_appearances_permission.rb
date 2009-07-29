module Admin::CustomAppearancesPermission

  def may_new_custom_appearances?
    may_admin_site?
  end

  def may_update_custom_appearances?(appearance=@appearance)
    !appearance || appearance == current_site.custom_appearance and
    may_admin_site?
  end

  alias_method :may_edit_custom_appearances?, :may_update_custom_appearances?
  alias_method :may_available_custom_appearances?, :may_update_custom_appearances?
end
