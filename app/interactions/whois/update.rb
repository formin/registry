module Whois
  class Update < ActiveInteraction::Base
    array :names
    string :type

    validates :type, inclusion: { in: %w[reserved blocked domain disputed zone] }

    def execute
      ::PaperTrail.request.whodunnit = "job - #{self.class.name} - #{type}"

      klass = determine_class

      Array(names).each do |name|
        record = find_record(klass, name)
        if record
          Whois::UpdateRecord.run(record: { klass: klass.to_s, id: record.id, type: type })
        else
          Whois::DeleteRecord.run(name: name, type: type)
        end
      end
    end

    private

    def determine_class
      case type
      when 'reserved' then ReservedDomain
      when 'blocked'  then BlockedDomain
      when 'domain'   then Domain
      when 'disputed' then Dispute.active
      else                 DNS::Zone
      end
    end

    def find_record(klass, name)
      case klass
      when DNS::Zone
        klass.find_by(origin: name)
      when Dispute.active
        klass.find_by(domain_name: name)
      else
        klass.find_by(name: name)
      end
    end
  end
end
