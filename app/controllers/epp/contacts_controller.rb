require 'deserializers/xml/contact_update'
require 'deserializers/xml/contact_create'
module Epp
  class ContactsController < BaseController
    before_action :find_contact, only: [:info, :update, :delete]
    before_action :find_password, only: [:info, :update, :delete]

    THROTTLED_ACTIONS = %i[info renew update transfer delete].freeze
    include Shunter::Integration::Throttle

    def info
      authorize! :info, @contact, @password
      render_epp_response 'epp/contacts/info'
    end

    def check
      authorize! :check, Epp::Contact

      ids = params[:parsed_frame].css('id').map(&:text)
      @results = Epp::Contact.check_availability(ids, reg: current_user.registrar.code)
      render_epp_response '/epp/contacts/check'
    end

    def create
      authorize! :create, Epp::Contact

      @contact = Epp::Contact.new(params[:parsed_frame], current_user.registrar)
      collected_data = ::Deserializers::Xml::ContactCreate.new(params[:parsed_frame])
      action = Actions::ContactCreate.new(@contact, collected_data.legal_document,
                                          collected_data.ident)

      action_call_response(action: action)
    end

    def update
      authorize! :update, @contact, @password

      collected_data = ::Deserializers::Xml::ContactUpdate.new(params[:parsed_frame])
      action = Actions::ContactUpdate.new(@contact,
                                          collected_data.contact,
                                          collected_data.legal_document,
                                          collected_data.ident,
                                          current_user)

      action_call_response(action: action)
    end

    def delete
      authorize! :delete, @contact, @password
      action = Actions::ContactDelete.new(@contact, params[:legal_document])
      unless action.call
        handle_errors(@contact)
        return
      end

      render_epp_response '/epp/contacts/delete'
    end

    def renew
      authorize! :renew, Epp::Contact
      epp_errors.add(:epp_errors, code: '2101', msg: t(:'errors.messages.unimplemented_command'))
      handle_errors
    end

    def transfer
      authorize! :transfer, Epp::Contact
      epp_errors.add(:epp_errors, code: '2101', msg: t(:'errors.messages.unimplemented_command'))
      handle_errors
    end

    private

    def opt_addr?
      !Contact.address_processing? && address_given?
    end

    def action_call_response(action:)
      unless action.call
        handle_errors(@contact)
        return
      end

      if opt_addr?
        @response_code = 1100
        @response_description = t('epp.contacts.completed_without_address')
      else
        @response_code = 1000
        @response_description = t('epp.contacts.completed')
      end

      render_epp_response('epp/contacts/save')
    end

    def find_password
      @password = params[:parsed_frame].css('authInfo pw').text
    end

    def find_contact
      code = params[:parsed_frame].css('id').text.strip.upcase
      reg_code = current_user.registrar.code.upcase
      arr = [code, "#{reg_code}:#{code}", "CID:#{code}", "CID:#{reg_code}:#{code}"]

      contact = arr.find { |c| Epp::Contact.find_by(code: c).present? }
      @contact = Epp::Contact.find_by!(code: contact || code)
    end

    #
    # Validations
    #
    def validate_info
      @prefix = 'info > info >'
      requires 'id'
    end

    def validate_check
      @prefix = 'check > check >'
      requires 'id'
    end

    def validate_create
      @prefix = 'create > create >'

      required_attributes = [
        'postalInfo > name',
        'voice',
        'email'
      ]

      address_attributes = [
        'postalInfo > addr > street',
        'postalInfo > addr > city',
        'postalInfo > addr > pc',
        'postalInfo > addr > cc',
      ]

      required_attributes.concat(address_attributes) if Contact.address_processing?
      requires(*required_attributes)
      ident = params[:parsed_frame].css('ident')

      if ident.present? && ident.attr('type').blank?
        epp_errors.add(:epp_errors,
                       code: '2003',
                       msg: I18n.t('errors.messages.required_ident_attribute_missing', key: 'type'))
      end

      if ident.present? && ident.text != 'birthday' && ident.attr('cc').blank?
        epp_errors.add(:epp_errors,
                       code: '2003',
                       msg: I18n.t('errors.messages.required_ident_attribute_missing', key: 'cc'))
      end
      contact_org_disabled
      fax_disabled
      status_editing_disabled
      @prefix = nil
      requires 'extension > extdata > ident'
    end

    def validate_update
      @prefix = 'update > update >'
      contact_org_disabled
      fax_disabled
      status_editing_disabled
      requires 'id'
      @prefix = nil
    end

    def validate_delete
      @prefix = 'delete > delete >'
      requires 'id'
      @prefix = nil
    end

    def contact_org_disabled
      return true if ENV['contact_org_enabled'] == 'true'
      return true if params[:parsed_frame].css('postalInfo org').text.blank?

      epp_errors.add(:epp_errors,
                     code: '2306',
                     msg: "#{I18n.t(:contact_org_error)}: postalInfo > org [org]")
    end

    def fax_disabled
      return true if ENV['fax_enabled'] == 'true'
      return true if params[:parsed_frame].css('fax').text.blank?
      epp_errors.add(:epp_errors,
                     code: '2306',
                     msg: "#{I18n.t(:contact_fax_error)}: fax [fax]")
    end

    def status_editing_disabled
      return true if Setting.client_status_editing_enabled
      return true if params[:parsed_frame].css('status').empty?
      epp_errors.add(:epp_errors,
                     code: '2306',
                     msg: "#{I18n.t(:client_side_status_editing_error)}: status [status]")
    end

    def address_given?
      params[:parsed_frame].css('postalInfo addr').size != 0
    end
  end
end
