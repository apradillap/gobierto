module GobiertoPeople
  module Sluggable
    extend ActiveSupport::Concern

    included do
      before_create :set_slug
    end

    private

    def set_slug
      unless slug.present?
        base_slug = attributes_for_slug.join('-').gsub('_', ' ').parameterize
        new_slug  = base_slug

        count = 2
        while self.class.exists?(site: site, slug: new_slug)
          new_slug = "#{base_slug}-#{count}"
          count += 1
        end

        self.slug = new_slug
      end
    end

  end
end
