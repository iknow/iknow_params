# frozen_string_literal: true

require "active_support/concern"
require "active_support/inflector"
require "active_support/core_ext/object/blank"

# IknowParams::Parser provides a mix-in for ActiveRecord controllers to parse input parameters.
module IknowParams::Parser
  require "iknow_params/parser/hash_parser"

  extend ActiveSupport::Concern

  class ParseError < RuntimeError
    attr_accessor :param, :value

    def initialize(message, param, value)
      super(message)
      self.param = param
      self.value = value
    end
  end

  PARAM_REQUIRED = Object.new
  BLANK = Object.new

  class << self
    def parse_hash(hash, &block)
      HashParser.new(hash).parse(&block)
    end

    def parse_value(value, **args)
      HashParser.new({ sentinel: value }).parse_param(:sentinel, **args)
    end

    def parse_values(values, **args)
      HashParser.new({ sentinel: values }).parse_array_param(:sentinel, **args)
    end
  end

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
    serializer =
      case with
      when String, Symbol
        IknowParams::Serializer.for!(with)
      else
        with
      end

    parse =
      if !params.has_key?(param)
        raise ParseError.new("Required parameter '#{param}' missing", param, nil) if default == PARAM_REQUIRED
        default
      else
        val = params[param]
        if serializer.present?
          begin
            serializer.load(val)
          rescue IknowParams::Serializer::LoadError => ex
            raise ParseError.new("Invalid parameter '#{param}': '#{val.inspect}' - #{ex.message}", param, val)
          end
        else
          val
        end
      end

    if dump && parse != BLANK
      begin
        parse = serializer.dump(parse)
      rescue NoMethodError => ex
        raise ParseError.new("Serializer '#{serializer}' can't dump param '#{param}' #{val.inspect} - #{ex.message}", param, val)
      end
    end

    parse
  end

  # Parse an array-typed param using the provided serializer for each member element.
  def parse_array_param(param, with: nil, default: PARAM_REQUIRED, dump: false)
    serializer =
      case with
      when String, Symbol
        IknowParams::Serializer.for!(with)
      else
        with
      end

    vals = params[param]

    parses =
      if vals.nil?
        raise ParseError.new("Required parameter '#{param}' missing", param, nil) if default == PARAM_REQUIRED
        default
      elsif !vals.is_a?(Array)
        raise ParseError.new("Invalid type for parameter '#{param}': '#{vals.class.name}'", param, vals)
      elsif serializer.present?
        vals.map do |val|
          begin
            serializer.load(val)
          rescue IknowParams::Serializer::LoadError => ex
            raise ParseError.new("Invalid member in array parameter '#{param}': '#{val.inspect}' - #{ex.message}", param, val)
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

  # Allow serializers to register themselves
  def self.register_serializer(name, serializer)
    define_method(:"parse_#{name.underscore}_param") do |param, default: PARAM_REQUIRED|
      parse_param(param, with: serializer, default: default)
    end
    define_method(:"parse_#{name.underscore}_array_param") do |param, default: PARAM_REQUIRED|
      parse_array_param(param, with: serializer, default: default)
    end
  end
end
