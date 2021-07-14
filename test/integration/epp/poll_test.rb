require 'test_helper'

class EppPollTest < EppTestCase
  setup do
    @notification = notifications(:complete)
  end

  # Deliberately does not conform to RFC5730, which requires the first notification to be returned
  def test_return_latest_notification_when_queue_is_not_empty
    request_xml = <<-XML
      <?xml version="1.0" encoding="UTF-8" standalone="no"?>
      <epp xmlns="#{Xsd::Schema.filename(for_prefix: 'epp-ee', for_version: '1.0')}">
        <command>
          <poll op="req"/>
        </command>
      </epp>
    XML
    post epp_poll_path, params: { frame: request_xml },
         headers: { 'HTTP_COOKIE' => 'session=api_bestnames' }

    xml_doc = Nokogiri::XML(response.body)
    assert_epp_response :completed_successfully_ack_to_dequeue
    assert_equal 2.to_s, xml_doc.at_css('msgQ')[:count]
    assert_equal @notification.id.to_s, xml_doc.at_css('msgQ')[:id]
    assert_equal Time.zone.parse('2010-07-05').utc.xmlschema, xml_doc.at_css('msgQ qDate').text
    assert_equal 'Your domain has been updated', xml_doc.at_css('msgQ msg').text
  end

  def test_clears_orphan_messages_if_any
    # To check if we are clearing orphan messages we need to create a message not linked to any
    # existing Epp::Domain

    orphan_notification = @notification.dup
    orphan_notification.attached_obj_type = Epp::Domain
    orphan_notification.attached_obj_id = rand(Epp::Domain.first.id-1)
    orphan_notification.save!
    assert orphan_notification.unread?

    request_xml = <<-XML
      <?xml version="1.0" encoding="UTF-8" standalone="no"?>
      <epp xmlns="#{Xsd::Schema.filename(for_prefix: 'epp-ee', for_version: '1.0')}">
        <command>
          <poll op="req"/>
        </command>
      </epp>
    XML
    post epp_poll_path, params: { frame: request_xml },
         headers: { 'HTTP_COOKIE' => 'session=api_bestnames' }

    orphan_notification.reload
    refute orphan_notification.unread?
  end

  def test_does_not_drop_error_if_old_version
    version = Version::DomainVersion.last
    @notification.update(attached_obj_type: 'DomainVersion', attached_obj_id: version.id)

    request_xml = <<-XML
      <?xml version="1.0" encoding="UTF-8" standalone="no"?>
      <epp xmlns="#{Xsd::Schema.filename(for_prefix: 'epp-ee', for_version: '1.0')}">
        <command>
          <poll op="req"/>
        </command>
      </epp>
    XML
    assert_nothing_raised do
      post epp_poll_path, params: { frame: request_xml },
           headers: { 'HTTP_COOKIE' => 'session=api_bestnames' }
    end

    xml_doc = Nokogiri::XML(response.body)
    assert_epp_response :completed_successfully_ack_to_dequeue
    assert_equal 2.to_s, xml_doc.at_css('msgQ')[:count]
    assert_equal @notification.id.to_s, xml_doc.at_css('msgQ')[:id]
    assert_equal Time.zone.parse('2010-07-05').utc.xmlschema, xml_doc.at_css('msgQ qDate').text
    assert_equal 'Your domain has been updated', xml_doc.at_css('msgQ msg').text
  end

  def test_return_action_data_when_present
    @notification.update!(action: actions(:contact_update))

    request_xml = <<-XML
      <?xml version="1.0" encoding="UTF-8" standalone="no"?>
      <epp xmlns="#{Xsd::Schema.filename(for_prefix: 'epp-ee', for_version: '1.0')}">
        <command>
          <poll op="req"/>
        </command>
      </epp>
    XML
    post epp_poll_path, params: { frame: request_xml },
         headers: { 'HTTP_COOKIE' => 'session=api_bestnames' }

    xml_doc = Nokogiri::XML(response.body)
    namespace = Xsd::Schema.filename(for_prefix: 'changePoll')
    assert_equal 'update', xml_doc.xpath('//changePoll:operation', 'changePoll' => namespace).text
    assert_equal Time.zone.parse('2010-07-05').utc.xmlschema,
                 xml_doc.xpath('//changePoll:date', 'changePoll' => namespace).text
    assert_equal @notification.action.id.to_s, xml_doc.xpath('//changePoll:svTRID',
                                                             'changePoll' => namespace).text
    assert_equal 'Registrant User', xml_doc.xpath('//changePoll:who',
                                                  'changePoll' => namespace).text
  end

  def test_no_notifications
    registrars(:bestnames).notifications.delete_all(:delete_all)

    request_xml = <<-XML
      <?xml version="1.0" encoding="UTF-8" standalone="no"?>
      <epp xmlns="#{Xsd::Schema.filename(for_prefix: 'epp-ee', for_version: '1.0')}">
        <command>
          <poll op="req"/>
        </command>
      </epp>
    XML
    post epp_poll_path, params: { frame: request_xml },
         headers: { 'HTTP_COOKIE' => 'session=api_bestnames' }

    assert_epp_response :completed_successfully_no_messages
  end

  def test_mark_as_read
    notification = notifications(:greeting)

    request_xml = <<-XML
      <?xml version="1.0" encoding="UTF-8" standalone="no"?>
      <epp xmlns="#{Xsd::Schema.filename(for_prefix: 'epp-ee', for_version: '1.0')}">
        <command>
          <poll op="ack" msgID="#{notification.id}"/>
        </command>
      </epp>
    XML

    post epp_poll_path, params: { frame: request_xml },
         headers: { 'HTTP_COOKIE' => 'session=api_bestnames' }
    notification.reload

    xml_doc = Nokogiri::XML(response.body)
    assert notification.read?
    assert_epp_response :completed_successfully
    assert_equal 1.to_s, xml_doc.at_css('msgQ')[:count]
    assert_equal notification.id.to_s, xml_doc.at_css('msgQ')[:id]
  end

  def test_notification_of_other_registrars_cannot_be_marked_as_read
    notification = notifications(:farewell)

    request_xml = <<-XML
      <?xml version="1.0" encoding="UTF-8" standalone="no"?>
      <epp xmlns="#{Xsd::Schema.filename(for_prefix: 'epp-ee', for_version: '1.0')}">
        <command>
          <poll op="ack" msgID="#{notification.id}"/>
        </command>
      </epp>
    XML
    post epp_poll_path, params: { frame: request_xml },
         headers: { 'HTTP_COOKIE' => 'session=api_bestnames' }
    notification.reload

    assert notification.unread?
    assert_epp_response :object_does_not_exist
  end

  def test_notification_not_found
    request_xml = <<-XML
      <?xml version="1.0" encoding="UTF-8" standalone="no"?>
      <epp xmlns="#{Xsd::Schema.filename(for_prefix: 'epp-ee', for_version: '1.0')}">
        <command>
          <poll op="ack" msgID="0"/>
        </command>
      </epp>
    XML
    post epp_poll_path, params: { frame: request_xml },
         headers: { 'HTTP_COOKIE' => 'session=api_bestnames' }

    assert_epp_response :object_does_not_exist
  end

  def test_anonymous_user_cannot_access
    request_xml = <<-XML
      <?xml version="1.0" encoding="UTF-8" standalone="no"?>
      <epp xmlns="#{Xsd::Schema.filename(for_prefix: 'epp-ee', for_version: '1.0')}">
        <command>
          <poll op="req"/>
        </command>
      </epp>
    XML

    post '/epp/command/poll', params: { frame: request_xml },
         headers: { 'HTTP_COOKIE' => 'session=non-existent' }

    assert_epp_response :authorization_error
  end
end
