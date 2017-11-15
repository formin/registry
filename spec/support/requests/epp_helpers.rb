module Requests
  module EPPHelpers
    def have_code_of(*args)
      Matchers::EPP::Code.new(*args)
    end

    def valid_legal_document
      Base64.encode64('a' * 5000)
    end

    def epp_response
      EPP::Response.from_xml(response.body)
    end
  end
end
