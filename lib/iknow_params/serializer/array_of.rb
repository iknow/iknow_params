# frozen_string_literal: true

# Serialize an array of application types to JSON types. Does not support fully
# rendering to/from a JSON string.
class IknowParams::Serializer::ArrayOf < IknowParams::Serializer
  attr_reader :serializer, :allow_singleton
  json_value!

  def initialize(serializer, allow_singleton: false)
    super(::Array)
    @serializer = serializer
    @allow_singleton = allow_singleton
  end

  def load(jvals)
    if allow_singleton
      jvals = Array.wrap(jvals)
    else
      unless jvals.is_a?(Array)
        raise IknowParams::Serializer::LoadError.new(
                "Incorrect type for ArrayOf: #{jvals.inspect}:#{jvals.class.name} is not an array")
      end
    end

    # Special case thanks to Rails' array query param format not differentating
    # empty arrays (i.e. `route?param[]=`). Since we can only express one of
    # empty array and singleton array containing empty string, we pick the more
    # useful former.
    return [] if jvals == ['']

    jvals.map { |jval| serializer.load(jval) }
  end

  def dump(vals, json: true)
    matches_type!(vals)
    vals.map { |val| serializer.dump(val, json: json) }
  end

  def matches_type?(vals)
    super(vals) && vals.all? { |val| serializer.matches_type?(val) }
  end
end
