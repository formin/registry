module Whois
  class Record < Whois::Server
    self.table_name = 'whois_records'

    def self.without_auctions
      ids = Whois::Record.all.select { |record| Auction.where(domain: record.name).blank? }
                         .pluck(:id)
      Whois::Record.where(id: ids)
    end

    def self.disclaimer
      Setting.registry_whois_disclaimer
    end

    # rubocop:disable Metrics/AbcSize
    def update_from_auction(auction)
      if auction.started?
        update!(json: { name: auction.domain,
                        status: ['AtAuction'],
                        disclaimer: self.class.disclaimer })
        ToStdout.msg "Updated from auction WHOIS record #{inspect}"
      elsif auction.no_bids?
        ToStdout.msg "Destroying WHOIS record #{inspect}"
        destroy!
      elsif auction.awaiting_payment? || auction.payment_received?
        update!(json: { name: auction.domain,
                        status: ['PendingRegistration'],
                        disclaimer: self.class.disclaimer,
                        registration_deadline: auction.whois_deadline })
        ToStdout.msg "Updated from auction WHOIS record #{inspect}"
      end
    end
    # rubocop:enable Metrics/AbcSize
  end
end
