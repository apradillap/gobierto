require "test_helper"
require "support/file_uploader_helpers"

module GobiertoAdmin
  module GobiertoPeople
    class PersonEventUpdateTest < ActionDispatch::IntegrationTest
      include FileUploaderHelpers

      def setup
        super
        @path = edit_admin_people_person_event_path(person, person_event)
      end

      def person_event
        @person_event ||= gobierto_people_person_events(:richard_published)
      end

      def person
        @person ||= person_event.person
      end

      def admin
        @admin ||= gobierto_admin_admins(:nick)
      end

      def site
        @site ||= sites(:madrid)
      end

      def test_person_event_update
        with_javascript do
          with_signed_in_admin(admin) do
            with_current_site(site) do
              visit @path

              within "form.edit_person_event" do
                fill_in "person_event_title_translations_en", with: "Event Title"
                fill_in "person_event_starts_at", with: "2017-01-01 00:00"
                fill_in "person_event_ends_at", with: "2017-01-01 00:01"
                find("#person_event_description_translations_en", visible: false).set("Event Description")

                click_link "ES"
                fill_in "person_event_title_translations_es", with: "Título Evento"
                find("#person_event_description_translations_es", visible: false).set("Descripción Evento")

                within ".attachment_file_field" do
                  assert has_selector?("a")
                  attach_file "person_event_attachment_file", "test/fixtures/files/gobierto_people/people/person_event/attachment.pdf"
                end

                within "#person-event-locations" do
                  person_event.locations.each do |location|
                    within ".dynamic-content-record-wrapper.content-block-record-#{location.id}" do
                      with_hidden_elements do
                        find("a[data-behavior=edit_record]").trigger("click")
                      end

                      fill_in "Place", with: "Location Place"
                      fill_in "Address", with: "Location Address"

                      find("a[data-behavior=add_record]").click
                    end
                  end
                end

                within "#person-event-attendees" do
                  person_event.attendees.each do |attendee|
                    within ".dynamic-content-record-wrapper.content-block-record-#{attendee.id}" do
                      next if attendee.person && attendee.person == person
                      with_hidden_elements do
                        find("a[data-behavior=edit_record]").trigger("click")
                      end

                      select "", from: "Person"
                      fill_in "Name", with: "Attendee Name"
                      fill_in "Charge", with: "Attendee Charge"

                      find("a[data-behavior=add_record]").click
                    end
                  end
                end

                within ".person-event-state-radio-buttons" do
                  find("label", text: "Pending").click
                end

                scroll_to_top

                with_stubbed_s3_file_upload do
                  click_button "Update"
                end
              end

              assert has_message?("Event was successfully updated. See the event.")

              within "form.edit_person_event" do
                assert has_field?("person_event_title_translations_en", with: "Event Title")

                assert has_field?("person_event_starts_at", with: "2017-01-01 00:00")
                assert has_field?("person_event_ends_at", with: "2017-01-01 00:01")
                assert_equal(
                  "<div>Event Description</div>",
                  find("#person_event_description_translations_en", visible: false).value
                )

                within ".attachment_file_field" do
                  assert has_selector?("a")
                end

                within "#person-event-locations .dynamic-content-record-view", match: :first do
                  assert has_selector?(".content-block-record-value", text: "Location Place")
                  assert has_selector?(".content-block-record-value", text: "Location Address")
                end

                assert all(".content-block-record-value").any?{ |v| v.text.include?("Attendee Name") }
                assert all(".content-block-record-value").any?{ |v| v.text.include?("Attendee Charge") }

                within ".person-event-state-radio-buttons" do
                  with_hidden_elements do
                    assert has_checked_field?("Pending")
                  end
                end

                click_link "ES"

                assert has_field?("person_event_title_translations_es", with: "Título Evento")
                assert_equal(
                  "<div>Descripción Evento</div>",
                  find("#person_event_description_translations_es", visible: false).value
                )
              end
            end
          end
        end
      end
    end
  end
end
