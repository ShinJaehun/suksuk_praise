class AddStatusToClassroomMemberships < ActiveRecord::Migration[7.1]
  def change
    add_column :classroom_memberships, :status, :string, default: "active", null: false

    add_check_constraint :classroom_memberships,
      "status IN ('active', 'inactive')",
      name: "chk_classroom_memberships_status"
  end
end
