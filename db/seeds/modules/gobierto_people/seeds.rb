module GobiertoSeeds
  class Recipe
    def self.run(site)
      # Config keys
      settings = GobiertoModuleSettings.find_by site: site, module_name: "GobiertoPeople"
      if settings.nil?
        settings = GobiertoModuleSettings.new site: site, module_name: "GobiertoPeople"
        settings.submodules_enabled = GobiertoPeople.module_submodules
        settings.save!
      end

      #
      # Content blocks
      #

      ## Contact block
      contact_block = GobiertoCommon::ContentBlock.find_by(site_id: site.id, internal_id: GobiertoCommon::DynamicContent::CONTACT_BLOCK_ID)
      if contact_block.nil?
        contact_block = GobiertoCommon::ContentBlock.create!({
          internal_id: GobiertoCommon::DynamicContent::CONTACT_BLOCK_ID,
          site: site,
          content_model_name: "GobiertoPeople::Person",
          title: { "ca" => "Formes de contacte", "es" => "Formas de contacto" }
        })
      end

      ## Contact block fields
      contact_block_field = GobiertoCommon::ContentBlockField.find_by content_block: contact_block, name: "service_name"
      if contact_block_field.nil?
        GobiertoCommon::ContentBlockField.create!({content_block: contact_block,
          name: "service_name",
          field_type: ::GobiertoCommon::ContentBlockField.field_types["text"],
          label: { "ca" => "Servei", "es" => "Servicio" }
        })
      end

      contact_block_field = GobiertoCommon::ContentBlockField.find_by content_block: contact_block, name: "service_url"
      if contact_block_field.nil?
        GobiertoCommon::ContentBlockField.create!({content_block: contact_block,
          name: "service_url",
          field_type: ::GobiertoCommon::ContentBlockField.field_types["text"],
          label: { "ca" => "URL", "es" => "URL" }
        })
      end

      contact_block_field = GobiertoCommon::ContentBlockField.find_by content_block: contact_block, name: "service_handle"
      if contact_block_field.nil?
        GobiertoCommon::ContentBlockField.create!({content_block: contact_block,
          name: "service_handle",
          field_type: ::GobiertoCommon::ContentBlockField.field_types["text"],
          label: { "ca" => "Nom d'usuari", "es" => "Nombre de usuario" }
        })
      end

      contact_block_field = GobiertoCommon::ContentBlockField.find_by content_block: contact_block, name: "service_notes"
      if contact_block_field.nil?
        GobiertoCommon::ContentBlockField.create!({content_block: contact_block,
          name: "service_notes",
          field_type: ::GobiertoCommon::ContentBlockField.field_types["text"],
          label: { "ca" => "Notes", "es" => "Notas" }
        })
      end

      ## Seed loader
      seeds_filenames = Dir.glob(File.join(File.dirname(__FILE__), "*_seeds.yml"))

      seeds_filenames.each do |seeds_filename|
        block_data = YAML.load File.read(seeds_filename)

        block_data['blocks'].each do |content_block|
          block = GobiertoCommon::ContentBlock.find_by(site_id: site.id, internal_id: content_block['internal_id'])
          if block.nil?
            block = GobiertoCommon::ContentBlock.create!({
              internal_id: content_block['internal_id'],
              site: site,
              content_model_name: content_block['content_model_name'],
              title: content_block['title']
            })
          end

          content_block['fields'].each do |field|
            block_field = GobiertoCommon::ContentBlockField.find_by content_block: block, name: field['name']
            if block_field.nil?
              GobiertoCommon::ContentBlockField.create!({content_block: block, name: field['name'],
                field_type: ::GobiertoCommon::ContentBlockField.field_types[field['field_type']],
                label: field['label']
              })
            end
          end
        end
      end

    end
  end
end
