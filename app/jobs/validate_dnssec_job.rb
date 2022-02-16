class ValidateDnssecJob < ApplicationJob
  discard_on StandardError

  def perform(domain_name: nil)
    unless domain_name.nil?
      domain = Domain.find_by(name: domain_name)

      return logger.info "This domain not contain any dnskeys" if domain.dnskeys.empty?

      return logger.info "No domain found" if domain.nil?

      return logger.info "No related nameservers for this domain" if domain.nameservers.empty?

      iterate_nameservers(domain)
    else
      domain_list = Domain.all.reject { |d| d.dnskeys.empty? }

      domain_list.each do |d|
        if d.nameservers.empty?
          logger.info "#{d.name} has no nameserver"

          next
        end

        iterate_nameservers(d)
      end
    end
  rescue StandardError => e
    logger.error e.message
    raise e
  end

  private

  def iterate_nameservers(domain)
    domain.nameservers.each do |n|
      next unless n.validated?

      validate(nameserver: n, domain: domain)

      notify_contacts(domain)
      logger.info "----------------------------"
    end
  end

  def notify_contacts(domain)
    flag = domain.dnskeys.any? { |k| k.validation_datetime.present? }

    return if flag

    text = "DNSKEY record of a domain #{domain.name} is invalid. Please fix or contact the registrant."
    logger.info text
    # ContactNotification.notify_registrar(domain: domain, text: text)
    # ContactNotification.notify_tech_contact(domain: domain, reason: 'dnssec')
  end

  def validate(nameserver:, domain:,  type: 'DNSKEY', klass: 'IN')
    resolver = prepare_validator(nameserver.hostname)
    answer = resolver.query(domain.name, type, klass)

    return logger.info "no any data for #{domain.name} | hostname - #{nameserver.hostname}" if answer.nil?

    logger.info "-----------"
    logger.info "data for domain name - #{domain.name} | hostname - #{nameserver.hostname}"
    logger.info "-----------"

    response_container = parse_response(answer)

    compare_dnssec_data(response_container: response_container, domain: domain, nameserver: nameserver)
  rescue Exception => e
    logger.error "#{e.message} - domain name: #{domain.name} - hostname: #{nameserver.hostname}"
    nameserver.update(failed_validation_reason: "#{e.message} - domain name: #{domain.name} - hostname: #{nameserver.hostname}")
    nil
  end

  def compare_dnssec_data(response_container:, domain:, nameserver:)
    domain.dnskeys.each do |key|
      next unless key.flags.to_s == '257'
      next if key.validation_datetime.present?

      flag = make_magic(response_container: response_container, dnskey: key)
      text = "#{key.flags} - #{key.protocol} - #{key.alg} - #{key.public_key}"

      if flag
        key.validation_datetime = Time.zone.now
        key.failed_validation_reason = nil
        key.save
        nameserver.failed_validation_reason = nil
        nameserver.save

        logger.info text + " ------->> succesfully!"
      else
        key.update!(failed_validation_reason: text + " not found in zone! Domain name - #{domain.name}. Hostname - #{nameserver.hostname}")
        logger.info text + " ------->> not found in zone! Domain name - #{domain.name}. Hostname - #{nameserver.hostname}"
      end
    end
  end

  def make_magic(response_container:, dnskey:)
    response_container.any? do |r|
      r[:flags].to_s == dnskey.flags.to_s &&
        r[:protocol].to_s == dnskey.protocol.to_s &&
        r[:alg].to_s == dnskey.alg.to_s &&
        r[:public_key] == dnskey.public_key
    end
  end

  def parse_response(answer)
    response_container = []

    answer.each_answer do |a|

      a_string = a.to_s
      a_string = a_string.gsub /\t/, ' '
      a_string = a_string.split(' ')

      next unless a_string[4] == '257'

      protocol = a.protocol
      alg = a.algorithm.code

      response_container << {
        flags: a_string[4],
        protocol: protocol,
        alg: alg,
        public_key: a_string[8]
      }
    end

    response_container
  end

  def prepare_validator(nameserver)
    inner_resolver = Dnsruby::Resolver.new
    timeouts = ENV['nameserver_validation_timeout'] || 4
    inner_resolver.do_validation = true
    inner_resolver.dnssec = true
    inner_resolver.nameserver = nameserver
    inner_resolver.packet_timeout = timeouts.to_i
    inner_resolver.query_timeout = timeouts.to_i
    # resolver = Dnsruby::Recursor.new(inner_resolver)
    # resolver.dnssec = true

    # resolver
    inner_resolver
  end

  def logger
    @logger ||= Rails.logger
  end
end
