require "test_helper"
require "support/concerns/gobierto_people/sluggable_test"

module GobiertoPeople
  class PoliticalGroupTest < ActiveSupport::TestCase
    include ::GobiertoPeople::SluggableTestModule

    def political_group
      @political_group ||= gobierto_people_political_groups(:marvel)
    end
    alias sluggable political_group

    def new_political_group
      ::GobiertoPeople::PoliticalGroup.create!(
        name: 'Political Group Name',
        site: sites(:madrid)
      )
    end
    alias create_sluggable new_political_group

    def test_valid
      assert political_group.valid?
    end
  end
end
