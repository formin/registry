require 'rails_helper'

describe 'EPP Helper', epp: true do
  context 'in context of Domain' do
    before(:all) { @uniq_no = proc { @i ||= 0; @i += 1 } }

    it 'generates valid transfer xml' do
      dn = next_domain_name
      expected = Nokogiri::XML('<?xml version="1.0" encoding="UTF-8" standalone="no"?>
        <epp xmlns="urn:ietf:params:xml:ns:epp-1.0">
          <command>
            <transfer op="query">
              <domain:transfer
               xmlns:domain="urn:ietf:params:xml:ns:domain-1.0">
                <domain:name>' + dn + '</domain:name>
                <domain:authInfo>
                  <domain:pw roid="citizen_1234-REP">98oiewslkfkd</domain:pw>
                </domain:authInfo>
              </domain:transfer>
            </transfer>
            <clTRID>ABC-12345</clTRID>
          </command>
        </epp>
      ').to_s.squish

      generated = Nokogiri::XML(domain_transfer_xml(name: { value: dn })).to_s.squish
      expect(generated).to eq(expected)

      expected = Nokogiri::XML('<?xml version="1.0" encoding="UTF-8" standalone="no"?>
        <epp xmlns="urn:ietf:params:xml:ns:epp-1.0">
          <command>
            <transfer op="approve">
              <domain:transfer
               xmlns:domain="urn:ietf:params:xml:ns:domain-1.0">
                <domain:name>one.ee</domain:name>
                <domain:authInfo>
                  <domain:pw roid="askdf">test</domain:pw>
                </domain:authInfo>
              </domain:transfer>
            </transfer>
            <clTRID>ABC-12345</clTRID>
          </command>
        </epp>
      ').to_s.squish

      xml = domain_transfer_xml({
        name: { value: 'one.ee' },
        authInfo: {
          pw: { value: 'test', attrs: { roid: 'askdf' } }
        }
      }, 'approve')

      generated = Nokogiri::XML(xml).to_s.squish
      expect(generated).to eq(expected)
    end
  end
end
