require 'test_helper'
require 'base64'

module GobiertoAdmin
  module GobiertoAttachments
    class AttachmentTest < ActionDispatch::IntegrationTest

      def site
        @site ||= sites(:madrid)
      end

      def admin
        @admin ||= gobierto_admin_admins(:nick)
      end

      def attachment_attributes
        @attachment_attributes ||= %w[ id site_id name description file_name file_digest url file_size current_version ]
      end

      def pdf_file
        @pdf_file ||= file_fixture('gobierto_attachments/attachment/pdf-attachment.pdf')
      end

      def xlsx_file
        @xlsx_file ||= file_fixture('gobierto_attachments/attachment/xlsx-attachment.xlsx')
      end

      def pdf_attachment
        gobierto_attachments_attachments(:pdf_attachment)
      end

      def attachable
        @attachable ||= gobierto_cms_pages(:consultation_faq)
      end

      def test_requests_need_authentication
        get admin_attachments_api_attachments_path(site_id: site.id)

        assert_response :redirect
      end

      def test_attachments_index
        login_admin_for_api(admin)

        get admin_attachments_api_attachments_path(site_id: site.id)

        json_response = JSON.parse(response.body)
        attachment = json_response.first

        assert_response :success

        assert_equal 4, json_response.size
        assert array_match(attachment_attributes, attachment.keys)

        assert_equal 'PDF Attachment Name',                            attachment['name']
        assert_equal 10022,                                            attachment['file_size']
        assert_equal 'pdf-attachment.pdf',                             attachment['file_name']
        assert_equal 'pdf-attachment-file-digest',                     attachment['file_digest']
        assert_equal 'http://host.com/attachments/pdf-attachment.pdf', attachment['url']
        assert_equal 'Description of a PDF attachment',                attachment['description']
        assert_equal 1,                                                attachment['current_version']
        assert_equal site.id,                                          attachment['site_id']
      end

      def test_attachments_index_for_attachable
        login_admin_for_api(admin)

        payload = {
          site_id: site.id,
          attachable: { id: attachable.id, type: attachable.class.to_s }
        }

        get admin_attachments_api_attachments_path(payload)

        json_response = JSON.parse(response.body)
        attachment = json_response.first

        assert_response :success

        assert_equal 1, json_response.size
        assert_equal 'XLSX Attachment Name', attachment['name']
      end

      def test_attachment_index_search
        login_admin_for_api(admin)

        payload = {
          site_id: site.id,
          search_string: 'PDF'
        }

        ::GobiertoAttachments::Attachment.stubs(:search).returns([pdf_attachment])

        get admin_attachments_api_attachments_path(payload)

        json_response = JSON.parse(response.body)

        assert_response :success

        assert_equal 1, json_response.size
        assert_equal 'PDF Attachment Name', json_response.first['name']
      end

      def test_attachments_create_success
        login_admin_for_api(admin)

        payload = {
          site_id: site.id,
          attachment: {
            site_id: site.id,
            name: 'New attachment name',
            description: 'New attachment description',
            file_name: 'pdf-attachment.pdf',
            file: ::Base64.encode64(pdf_file.read)
          }
        }

        ::GobiertoAdmin::FileUploadService.any_instance.stubs(:call).returns('http://host.com/attachments/pdf-attachment.pdf')

        post admin_attachments_api_attachments_path(payload)

        response_body = JSON.parse(response.body)
        attachment = response_body['attachment']

        assert_response :success

        assert array_match(attachment_attributes, attachment.keys)

        assert_equal 'New attachment name',                            attachment['name']
        assert_equal 'pdf-attachment.pdf',                             attachment['file_name']
        assert_equal 'http://host.com/attachments/pdf-attachment.pdf', attachment['url']
        assert_equal 1,                                                attachment['current_version']
      end

      def test_attachments_create_error
        login_admin_for_api(admin)

        payload = {
          site_id: site.id,
          attachment: { site_id: site.id, name: 'Incomplete attachment info' }
        }

        post admin_attachments_api_attachments_path, params: payload

        response_body = JSON.parse(response.body)

        assert_response :bad_request
        assert_equal 'Invalid payload', response_body['error']
      end

      def test_attachments_update_success
        login_admin_for_api(admin)

        payload = {
          site_id: site.id,
          attachment: {
            id: pdf_attachment.id,
            site_id: site.id,
            name: 'Replace PDF with XLSX',
            description: nil,
            file_name: 'xlsx-attachment.xlsx',
            file: ::Base64.encode64(xlsx_file.read)
          }
        }

        ::GobiertoAdmin::FileUploadService.any_instance.stubs(:call).returns('http://host.com/attachments/xlsx-attachment.xlsx')

        patch admin_attachments_api_attachment_path(pdf_attachment.id), params: payload

        # Check DB record was updated

        db_pdf_attachment = ::GobiertoAttachments::Attachment.find(pdf_attachment.id)

        assert_equal 'Replace PDF with XLSX',                            db_pdf_attachment.name
        assert_nil                                                       db_pdf_attachment.description
        assert_equal 'xlsx-attachment.xlsx',                             db_pdf_attachment.file_name
        assert_equal 'http://host.com/attachments/xlsx-attachment.xlsx', db_pdf_attachment.url
        assert_equal 2,                                                  db_pdf_attachment.current_version

        # Check HTTP response returns updated info

        response_body = JSON.parse(response.body)
        attachment = response_body['attachment']

        assert_response :success

        assert array_match(attachment_attributes, attachment.keys)

        assert_equal pdf_attachment.id,                                  attachment['id']
        assert_equal 'Replace PDF with XLSX',                            attachment['name']
        assert_nil                                                       attachment['description']
        assert_equal 'xlsx-attachment.xlsx',                             attachment['file_name']
        assert_equal 'http://host.com/attachments/xlsx-attachment.xlsx', attachment['url']
        assert_equal 2,                                                  attachment['current_version']
      end

      def test_attachments_update_error
        login_admin_for_api(admin)

        payload = {
          site_id: site.id,
          attachment: {
            id: pdf_attachment.id,
            site_id: site.id,
            name: nil
          }
        }

        patch admin_attachments_api_attachment_path(pdf_attachment.id), params: payload

        assert_response :bad_request

        db_pdf_attachment = ::GobiertoAttachments::Attachment.find(pdf_attachment.id)

        assert_equal 'PDF Attachment Name', db_pdf_attachment.name
      end

      def test_attachments_destroy_success
        login_admin_for_api(admin)

        payload = {
          site_id: site.id,
          attachment: { id: pdf_attachment.id }
        }

        delete admin_attachments_api_attachment_path(pdf_attachment.id), params: payload

        response_body = JSON.parse(response.body)

        assert_response :success

        assert_raises ActiveRecord::RecordNotFound do
          ::GobiertoAttachments::Attachment.find(pdf_attachment.id)
        end
      end

      def test_attachments_destroy_error
        login_admin_for_api(admin)

        unexistent_id = 666

        payload = {
          site_id: site.id,
          attachment: { id: unexistent_id }
        }

        delete admin_attachments_api_attachment_path(unexistent_id), params: payload

        assert_response :not_found
      end

    end
  end
end