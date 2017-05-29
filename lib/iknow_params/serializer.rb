require 'active_support'
require 'active_support/inflector'
require 'active_support/core_ext/module/delegation'
require 'tzinfo'
require 'json-schema'

module IknowParams
class Serializer
  attr_reader :clazz

  def initialize(clazz)
    @clazz = clazz
  end

  def dump(val, json: false)
    matches_type!(val)
    if(json && self.class.json_value?)
      val
    else
      val.to_s
    end
  end

  def load(val)
    raise StandardError.new('unimplemented')
  end

  def matches_type?(val)
    val.is_a?(clazz)
  end

  def matches_type!(val)
    unless matches_type?(val)
      raise ArgumentError.new("Incorrect type for #{self.class.name}: #{val.inspect}:#{val.class.name}")
    end
    true
  end

  @registry = {}
  class << self
    delegate :load, :dump, to: :singleton

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
    end

    private

    def set_singleton!
      instance = self.new
      define_singleton_method(:singleton){ instance }
      IknowParams::Serializer.register_serializer(self.name.demodulize, instance)
    end

    def json_value!
      define_singleton_method(:json_value?){ true }
    end
  end

  class String < Serializer
    def initialize
      super(::String)
    end

    def load(str)
      raise ArgumentError.new("Invalid type, expected String") unless str.kind_of?(::String)
      str
    end

    set_singleton!
    json_value!
  end

  class Integer < Serializer
    def initialize
      super(::Integer)
    end

    # JSON only supports floats, so we have to accept a value
    # which may have already been parsed into a Ruby Float or Integer.
    def load(str_or_num)
      raise ArgumentError.new("Invalid integer: #{str_or_num}") unless [::String, ::Integer].any? { |t| str_or_num.is_a?(t) }
      Integer(str_or_num)
    end

    set_singleton!
    json_value!
  end


  class Float < Serializer
    def initialize
      super(::Float)
    end

    def load(str)
      begin
        Float(str)
      rescue TypeError => e
        raise ArgumentError.new("Invalid type for conversion to Float")
      end
    end

    set_singleton!
    json_value!
  end


  class Boolean < Serializer
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
        raise ArgumentError.new("Invalid boolean: #{str.inspect}")
      end
    end

    def matches_type?(val)
      [true, false].include?(val)
    end

    set_singleton!
    json_value!
  end


  class Numeric < Serializer
    def initialize
      super(::Numeric)
    end

    def load(str)
      begin
        Float(str)
      rescue TypeError => e
        raise ArgumentError.new("Invalid type for conversion to Numeric")
      end
    end

    set_singleton!
    json_value!
  end

  # Abstract serializer for ISO8601 dates and times
  class ISO8601 < Serializer
    def load(str)
      begin
        clazz.parse(str)
      rescue TypeError => e
        raise ArgumentError.new("Invalid type for conversion to #{clazz}")
      end
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


  class Timezone < Serializer
    def initialize
      super(::TZInfo::Timezone)
    end

    def load(str)
      begin
        TZInfo::Timezone.get(str)
      rescue TZInfo::InvalidTimezoneIdentifier => e
        raise ArgumentError.new("Invalid identifier for TZINfo zone: #{str}")
      end
    end

    def dump(val, json: nil)
      matches_type!(val)
      val.identifier
    end

    set_singleton!
  end

  class UUID < String
    def load(str)
      matches_type!(str)
      super
    end

    def matches_type?(str)
      super && !!(str.match(/[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}/i))
    end

    set_singleton!
    json_value!
  end

  # Abstract serializer for JSON structures conforming to a specified
  # schema.
  class JsonWithSchema < Serializer
    attr_reader :schema
    def initialize(schema, validate_schema: true)
      @schema          = schema
      @validate_schema = validate_schema
      super(nil)
    end

    def load(structure)
      structure = JSON.parse(structure) if structure.is_a?(::String)
      matches_type!(structure)
      structure
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
        super(schema, !Rails.env.production?)
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
  class ActsAsEnum < Serializer
    def load(str)
      clazz.value_of!(str)
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
  class Renum < Serializer
    def load(str)
      val = clazz.with_name(str)
      if val.nil?
        raise ArgumentError.new("Invalid enumeration constant: '#{str}'")
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
  class StringEnum < Serializer
    def initialize(*members)
      @member_set = members.map(&:downcase).to_set.freeze
      super(nil)
    end

    def load(str)
      val = str.to_s.downcase
      matches_type!(val)
      val
    end

    def matches_type?(str)
      str.is_a?(::String) && @member_set.include?(str)
    end
  end
end
end
