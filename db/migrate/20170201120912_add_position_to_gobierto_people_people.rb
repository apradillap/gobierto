class AddPositionToGobiertoPeoplePeople < ActiveRecord::Migration[5.0]
  def change
    add_column :gp_people, :position, :integer, default: 999999, null: false
  end
end
