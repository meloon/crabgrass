class GroupLostUserActivity < GroupGainedUserActivity
  def description(view=nil)
    "{user} has left {group_type} {group}"[
      :activity_user_left_group, {
        :user => user_span(:user),
        :group_type => group_class(:group),
        :group => group_span(:group)
      }
    ]
  end

  def icon
    'membership_delete'
  end

end

