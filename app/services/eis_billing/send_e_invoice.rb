module EisBilling
  class SendEInvoice < EisBilling::Base
    def self.send_request(invoice:, payable:)
      send_info(invoice: invoice, payable: payable)
    end

    def self.send_info(invoice:, payable:)
      items = []
      prepared_data = prepare_data(invoice: invoice, payable: payable)

      invoice.items.each do |invoice_item|
        items << prepare_item(invoice_item)
      end

      prepared_data[:items] = items

      http = EisBilling::Base.base_request(url: e_invoice_url)
      http.post(e_invoice_url, prepared_data.to_json, EisBilling::Base.headers)
    end

    def self.prepare_item(invoice_item)
      {
        description: invoice_item.description,
        price: invoice_item.price,
        quantity: invoice_item.quantity,
        unit: invoice_item.unit,
        subtotal: invoice_item.subtotal,
        vat_rate: invoice_item.vat_rate,
        vat_amount: invoice_item.vat_amount,
        total: invoice_item.total,
      }
    end

    def self.prepare_data(invoice:, payable:)
      {
        invoice: invoice,
        vat_amount: invoice.vat_amount,
        invoice_subtotal: invoice.subtotal,
        buyer_billing_email: invoice.buyer.billing_email,
        buyer_e_invoice_iban: invoice.buyer.e_invoice_iban,
        seller_country_code: invoice.seller_country_code,
        buyer_country_code: invoice.buyer_country_code,
        payable: payable,
        initiator: EisBilling::Base::INITIATOR,
      }
    end

    def self.e_invoice_url
      "#{BASE_URL}/api/v1/e_invoice/e_invoice"
    end
  end
end
