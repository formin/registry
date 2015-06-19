xml.epp_head do
  xml.response do
    xml.result('code' => '1000') do
      xml.msg 'Command completed successfully'
    end

    xml.resData do
      xml.tag!('domain:renData', 'xmlns:domain' => 'https://raw.githubusercontent.com/internetee/registry/alpha/doc/schemas/domain-eis-1.0.xsd') do
        xml.tag!('domain:name', @domain[:name])
        xml.tag!('domain:exDate', @domain.valid_to.try(:iso8601))
      end
    end

    render('epp/shared/trID', builder: xml)
  end
end
