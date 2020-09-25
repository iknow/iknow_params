# frozen_string_literal: true

# Serialize a hash structure of application types to JSON types. Does not
# support fully rendering to/from a JSON string.
class IknowParams::Serializer::HashOf < IknowParams::Serializer
  attr_reader :key_serializer, :value_serializer
  json_value!

  def initialize(key_serializer, value_serializer)
    super(::Hash)
    @key_serializer   = key_serializer
    @value_serializer = value_serializer
  end

  def load(jstructure)
    jstructure = jstructure.to_unsafe_h if jstructure.is_a?(ActionController::Parameters)

    unless jstructure.is_a?(Hash)
      raise IknowParams::Serializer::LoadError.new(
              "Incorrect type for HashOf: #{jstructure.inspect}:#{jstructure.class.name} is not a hash")
    end

    jstructure.each_with_object({}) do |(jkey, jvalue), result|
      key   = key_serializer.load(jkey)
      value = value_serializer.load(jvalue)
      result[key] = value
    end
  end

  def dump(structure, json: true)
    matches_type!(structure)
    structure.each_with_object({}) do |(key, value), result|
      jkey   = key_serializer.dump(key, json: false)
      jvalue = value_serializer.dump(value, json: json)
      result[jkey] = jvalue
    end
  end

  def matches_type?(vals)
    super(vals) && vals.all? do |k_val, v_val|
      key_serializer.matches_type?(k_val) && value_serializer.matches_type?(v_val)
    end
  end
end
