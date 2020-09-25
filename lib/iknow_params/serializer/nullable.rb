# frozen_string_literal: true

# Serialize a potentially nil application type to JSON types. Does not support
# fully rendering to/from a string.
class IknowParams::Serializer::Nullable < IknowParams::Serializer
  attr_reader :serializer

  def load(val)
    if val.nil?
      nil
    else
      serializer.load(val)
    end
  end

  def dump(val, json: false)
    if val.nil?
      nil
    else
      serializer.dump(val, json: json)
    end
  end

  def matches_type?(val)
    val.nil? || super
  end

  def json_value?
    true
  end

  def initialize(serializer)
    @serializer = serializer
  end
end
