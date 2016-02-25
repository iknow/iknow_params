require 'active_support'
require 'active_support/inflector'
require 'active_support/core_ext/module/delegation'
require 'tzinfo'

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
      str
    end

    set_singleton!
    json_value!
  end

  class Integer < Serializer
    def initialize
      super(::Integer)
    end

    def load(str)
      Integer(str)
    end

    set_singleton!
    json_value!
  end


  class Float < Serializer
    def initialize
      super(::Float)
    end

    def load(str)
      Float(str)
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
      Float(str)
    end

    set_singleton!
    json_value!
  end

  # Abstract serializer for ISO8601 dates and times
  class ISO8601 < Serializer
    def load(str)
      clazz.parse(str)
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
      TZInfo::Timezone.get(str)
    end

    def dump(val, json: nil)
      matches_type!(val)
      val.identifier
    end

    set_singleton!
  end


  # Abstract serializer for JSON structures conforming to a specified
  # schema.
  class JsonWithSchema < Serializer
    attr_reader :schema
    def initialize(schema)
      @schema = schema
      super(nil)
    end

    def load(str)
      str = JSON.parse(str) if str.is_a?(::String)
      matches_type!(str)
    end

    def dump(val, json: false)
      matches_type!(val)
      if json
        val
      else
        JSON.dump(val)
      end
    end

    def matches_type!(val)
      JSON::Validator.validate!(schema, val, validate_schema: !Rails.env.production?)
    end

    json_value!
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
