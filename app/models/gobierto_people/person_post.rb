require_dependency "gobierto_people"

module GobiertoPeople
  class PersonPost < ApplicationRecord
    include User::Subscribable
    include GobiertoCommon::Searchable
    include GobiertoPeople::Sluggable

    validates :person, presence: true
    validates :site, presence: true
    
    algoliasearch_gobierto do
      attribute :site_id, :title, :body, :updated_at
      searchableAttributes ['title', 'body']
      attributesForFaceting [:site_id]
      add_attribute :resource_path, :class_name
    end

    belongs_to :person, counter_cache: :posts_count
    belongs_to :site

    scope :sorted, -> { order(created_at: :desc) }
    scope :by_tag, ->(*tags) { where("tags @> ARRAY[?]::varchar[]", tags) }

    delegate :site_id, to: :person
    delegate :admin_id, to: :person

    enum visibility_level: { draft: 0, active: 1 }

    def parameterize
      { person_slug: person.slug, slug: slug }
    end

    def attributes_for_slug
      [created_at.strftime('%F'), title]
    end

  end
end
