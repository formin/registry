module ObjectVersionsHelper
  def attach_existing_fields(version, new_object)
    version.diff.to_h.each do |key, value|
      method_name = "#{key}=".to_sym
      if new_object.respond_to?(method_name)
        new_object.public_send(method_name, value)
      end
    end
  end

  def only_present_fields(version, model)
    field_names = model.column_names
    version.new_value.select { |key, _value| field_names.include?(key) }
  end
end
