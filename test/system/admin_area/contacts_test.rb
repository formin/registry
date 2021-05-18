require 'application_system_test_case'

class AdminContactsTest < ApplicationSystemTestCase
  def setup
    super

    @contact = contacts(:william)
    sign_in users(:admin)
  end

  def test_update_contact
    visit admin_contact_path(@contact.id)
    assert_text "#{@contact.name}"

    click_on 'Edit statuses'
    assert_text "Edit: #{@contact.name}"

    click_on 'Save'
    assert_text 'Contact updated'
  end

  def test_display_list
    visit admin_contacts_path

    assert_text('william-001')
    assert_text('william-002')
    assert_text('acme-ltd-001')
    assert_text(@contact.name)
    assert_text(@contact.code.to_s)
    assert_text(@contact.email)
    assert_text(@contact.registrar.name)
  end

  def test_display_details
    assert_nothing_raised do
      visit admin_contact_path(@contact)
    end

    assert_text('Street Main Street City New York Postcode 12345 ' \
                'State New York State Country United States of America')
  end
end
