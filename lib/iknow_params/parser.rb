require "active_support/concern"
require "active_support/inflector"
require "iknow_params/serializer"

# IknowParams::Parser provides a mix-in for ActiveRecord controllers to parse input parameters.
module IknowParams::Parser
  extend ActiveSupport::Concern

  class ParseError < Exception; end

  PARAM_REQUIRED = Object.new
  BLANK = Object.new

  # Parse the specified parameter, optionally deserializing with the provided
  # IKnowParams::Serializer. If the parameter is missing and no default is
  # provided, raises a ParseError.
  #
  # If `BLANK` is provided as a default, return a placeholder object that can be
  # later stripped out with `remove_blanks`
  #
  # If `dump` is true, use the serializer to re-serialize any successfully
  # parsed argument back to a canonical string. This can be useful to validate
  # and normalize the input to another service without parsing it. A serializer
  # must be passed to use this option.
  def parse_param(param, with: nil, default: PARAM_REQUIRED, dump: false)
    serializer = with
    val = params[param]

    parse =
        if val.nil?
          raise ParseError.new("Required parameter '#{param}' missing") if default == PARAM_REQUIRED
          default
        elsif serializer.present?
          begin
            serializer.load(val)
          rescue Exception => ex
            raise ParseError.new("Invalid parameter '#{param}': '#{val.inspect}' - #{ex.message}")
          end
        else
          val
        end

    if dump && parse != BLANK
      parse = serializer.dump(parse)
    end

    parse
  end

  # Parse an array-typed param using the provided serializer for each member element.
  def parse_array_param(param, with: nil, default: PARAM_REQUIRED, dump: false)
    serializer = with
    vals = params[param]

    parses =
      if vals.nil?
        raise ParseError.new("Required parameter '#{param}' missing") if default == PARAM_REQUIRED
        default
      elsif !vals.is_a?(Array)
        raise ParseError.new("Invalid type for parameter '#{param}': '#{vals.class.name}'")
      elsif serializer.present?
        vals.map do |val|
          begin
            serializer.load(val)
          rescue Exception => ex
            raise ParseError.new("Invalid member in parameter '#{param}': '#{val.inspect}' - #{ex.message}")
          end
        end
      else
        vals
      end

    if dump && parses != BLANK
      parses.map! { |v| serializer.dump(v) }
    end

    parses
  end

  # Convenience method to make it simpler to build a hash structure with
  # optional members from parsed data. This method recursively traverses the
  # provided structure and removes any instances of the sentinel value
  # Parser::BLANK.
  def remove_blanks(arg)
    case arg
    when Hash
      arg.each do |k, v|
        if v == BLANK
          arg.delete(k)
        else
          remove_blanks(v)
        end
      end
    when Array
      arg.delete(BLANK)
      arg.each { |e| remove_blanks(e) }
    end
  end

  # Add default parse methods for each basic serializer class
  ObjectSpace.each_object(IknowParams::Serializer.singleton_class).each do |serializer_class|
    name = serializer_class.name.demodulize.underscore
    define_method(:"parse_#{name}_param") do |param, default: PARAM_REQUIRED|
      parse_param(param, with: serializer_class, default: default)
    end
  end

end
