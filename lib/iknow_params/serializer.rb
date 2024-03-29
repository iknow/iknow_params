# frozen_string_literal: true

require 'active_support'
require 'active_support/duration'
require 'active_support/inflector'
require 'active_support/core_ext/module/delegation'
require 'tzinfo'
require 'json-schema'

class IknowParams::Serializer
  class LoadError < ArgumentError; end
  class DumpError < ArgumentError; end

  attr_reader :clazz

  def initialize(clazz)
    @clazz = clazz
  end

  def dump(val, json: false)
    matches_type!(val)
    if json && self.class.json_value?
      val
    else
      val.to_s
    end
  end

  def load(_val)
    raise StandardError.new('unimplemented')
  end

  def matches_type?(val)
    val.is_a?(clazz)
  end

  def matches_type!(val, err: DumpError)
    unless matches_type?(val)
      raise err.new("Incorrect type for #{self.class.name}: #{val.inspect}:#{val.class.name}")
    end
    true
  end

  @registry = {}
  class << self
    delegate :load, :dump, :matches_type?, :matches_type!, to: :singleton

    def singleton
      raise ArgumentError.new("Singleton instance not defined for abstract serializer '#{self.name}'")
    end

    def json_value?
      false
    end

    def for(name)
      @registry[name.to_s]
    end

    def for!(name)
      s = self.for(name)
      raise ArgumentError.new("No serializer registered with name: '#{name}'") if s.nil?
      s
    end

    protected

    def register_serializer(name, serializer)
      @registry[name] = serializer
      IknowParams::Parser.register_serializer(name, serializer)
    end

    private

    def set_singleton!
      instance = self.new
      define_singleton_method(:singleton) { instance }
      IknowParams::Serializer.register_serializer(self.name.demodulize, instance)
    end

    def json_value!
      define_singleton_method(:json_value?) { true }
    end
  end

  require 'iknow_params/serializer/nullable'
  require 'iknow_params/serializer/array_of'
  require 'iknow_params/serializer/hash_of'

  class String < IknowParams::Serializer
    def initialize
      super(::String)
    end

    def load(str)
      matches_type!(str, err: LoadError)
      str
    end

    set_singleton!
    json_value!
  end

  class Integer < IknowParams::Serializer
    def initialize
      super(::Integer)
    end

    # JSON only supports floats, so we have to accept a value
    # which may have already been parsed into a Ruby Float or Integer.
    def load(str_or_num)
      raise LoadError.new("Invalid integer: #{str_or_num}") unless [::String, ::Integer].any? { |t| str_or_num.is_a?(t) }
      Integer(str_or_num)
    rescue ArgumentError => e
      raise LoadError.new(e.message)
    end

    set_singleton!
    json_value!
  end

  class Float < IknowParams::Serializer
    def initialize
      super(::Float)
    end

    def load(str)
      Float(str)
    rescue TypeError, ArgumentError => _e
      raise LoadError.new("Invalid type for conversion to Float")
    end

    set_singleton!
    json_value!
  end

  class Boolean < IknowParams::Serializer
    def initialize
      super(nil)
    end

    def load(str)
      str = str.downcase if str.is_a?(::String)

      if ['false', 'no', 'off', false, '0', 0].include?(str)
        false
      elsif ['true', 'yes', 'on', true, '1', 1].include?(str)
        true
      else
        raise LoadError.new("Invalid boolean: #{str.inspect}")
      end
    end

    def matches_type?(val)
      [true, false].include?(val)
    end

    set_singleton!
    json_value!
  end

  class Numeric < IknowParams::Serializer
    def initialize
      super(::Numeric)
    end

    def load(str)
      Float(str)
    rescue TypeError, ArgumentError => _e
      raise LoadError.new("Invalid type for conversion to Numeric")
    end

    set_singleton!
    json_value!
  end

  # Abstract serializer for ISO8601 dates and times
  class ISO8601 < IknowParams::Serializer
    def load(str)
      raise TypeError.new unless str.is_a?(::String)

      clazz.parse(str)
    rescue TypeError, ArgumentError => _e
      raise LoadError.new("Invalid type for conversion to #{clazz}")
    end

    def dump(val, json: nil)
      matches_type!(val)
      val.iso8601
    end
  end

  class Date < ISO8601
    def initialize
      super(::Date)
    end

    set_singleton!
  end

  class Time < ISO8601
    def initialize
      super(::Time)
    end

    set_singleton!
  end

  class Duration < ISO8601
    def initialize
      super(::ActiveSupport::Duration)
    end

    set_singleton!
  end


  class Timezone < IknowParams::Serializer
    def initialize
      super(::TZInfo::Timezone)
    end

    def load(str)
      TZInfo::Timezone.get(str)
    rescue TZInfo::InvalidTimezoneIdentifier => _e
      raise LoadError.new("Invalid identifier for TZInfo zone: #{str}")
    end

    def dump(val, json: nil)
      matches_type!(val)
      val.identifier
    end

    set_singleton!
  end

  class UUID < String
    def load(str)
      matches_type!(str, err: LoadError)

      # UUIDs in Ruby are typically represented as lower case strings,
      # for example, as returned by SecureRandom.uuid. To avoid surprises,
      # and ensure that two equivalent UUIDs are equal to each other, we
      # canonicalize any provided strings to lower case.
      super.downcase
    end

    def matches_type?(str)
      super && /[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}/i.match?(str)
    end

    set_singleton!
    json_value!
  end

  # Abstract serializer for JSON structures conforming to a specified
  # schema.
  class JsonWithSchema < IknowParams::Serializer
    attr_reader :schema
    def initialize(schema, validate_schema: true)
      @schema          = schema
      @validate_schema = validate_schema
      super(nil)
    end

    def load(structure)
      structure = JSON.parse(structure) if structure.is_a?(::String)
      matches_type!(structure, err: LoadError)
      structure
    rescue JSON::ParserError => ex
      raise LoadError.new("Invalid JSON: #{ex.message}")
    end

    def dump(val, json: false)
      matches_type!(val)
      if json
        val
      else
        JSON.dump(val)
      end
    end

    def matches_type?(val)
      JSON::Validator.validate(schema, val, validate_schema: @validate_schema)
    end

    json_value!
  end

  # Adds Rails conveniences
  class JsonWithSchema
    class Rails < JsonWithSchema
      def initialize(schema)
        super(schema, validate_schema: !::Rails.env.production?)
      end

      def load(structure)
        super(convert_strong_parameters(structure))
      end

      private

      def convert_strong_parameters(structure)
        case structure
        when ActionController::Parameters
          structure.to_unsafe_h
        when Array
          structure.dup.map { |x| convert_strong_parameters(x) }
        else
          structure
        end
      end
    end
  end

  ## Abstract serializer for `ActsAsEnum` constants.
  class ActsAsEnum < IknowParams::Serializer
    def load(str)
      constant = clazz.value_of(str)
      if constant.nil?
        raise LoadError.new("Invalid #{clazz.name} member: '#{str}'")
      end
      constant
    end

    def dump(val, json: nil)
      matches_type!(val)
      val.enum_constant
    end

    def matches_type?(val)
      return true if super(val)
      dc = clazz.dummy_class
      dc.present? && val.is_a?(dc)
    end
  end

  ## Abstract serializer for `renum` constants.
  class Renum < IknowParams::Serializer
    def load(str)
      val = clazz.with_name(str)
      if val.nil?
        raise LoadError.new("Invalid enumeration constant: '#{str}'")
      end
      val
    end

    def dump(val, json: nil)
      matches_type!(val)
      val.name
    end
  end

  # Abstract serializer for members of a fixed set of lowercase strings,
  # case-normalized on parse.
  class StringEnum < IknowParams::Serializer
    def initialize(*members)
      @member_set = members.map { |s| normalize(s) }.to_set.freeze
      super(nil)
    end

    def load(str)
      val = normalize(str.to_s)
      matches_type!(val, err: LoadError)
      val
    end

    def matches_type?(str)
      str.is_a?(::String) && @member_set.include?(str)
    end

    def normalize(str)
      str.downcase
    end
  end

  class CaseSensitiveStringEnum < StringEnum
    def normalize(str)
      str
    end
  end
end
