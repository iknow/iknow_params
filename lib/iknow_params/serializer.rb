module IknowParams
class Serializer
  def self.dump(val)
    matches_type!(val)
    val.to_s
  end

  def self.load(val)
    raise StandardError.new('unimplemented')
  end

  def self.matches_type?(val)
    val.is_a?(clazz)
  end

  def self.matches_type!(val)
    unless matches_type?(val)
      raise ArgumentError.new("Incorrect type for #{self.name}: #{val.inspect}:#{val.class.name}")
    end
    true
  end

  def self.clazz
    raise StandardError.new('unimplemented')
  end

  class String < Serializer
    def self.clazz
      ::String
    end

    def self.load(str)
      str
    end
  end

  class Integer < Serializer
    def self.clazz
      ::Integer
    end

    def self.load(str)
      Integer(str)
    end
  end

  class Float < Serializer
    def self.clazz
      ::Float
    end

    def self.load(str)
      Float(str)
    end
  end

  class Boolean < Serializer
    def self.load(str)
      val = ServiceHelper.boolean(str)

      unless matches_type?(val)
        raise ArgumentError.new("Invalid boolean: #{str.inspect}")
      end

      val
    end

    def self.matches_type?(val)
      [true, false].include?(val)
    end
  end

  class Numeric < Float
    def self.clazz
      ::Numeric
    end
  end

  class Hash < Serializer
    def self.clazz
      ::Hash
    end

    def self.load(str)
      JSON.parse(str)
    end

    def self.dump(val)
      matches_type!(val)
      JSON.dump(val)
    end
  end

  # Abstract serializer for ISO8601 dates and times
  class ISO8601 < Serializer
    def self.load(str)
      clazz.parse(str)
    end

    def self.dump(val)
      matches_type!(val)
      val.iso8601
    end
  end

  class Date < ISO8601
    def self.clazz
      ::Date
    end

  end

  class Time < ISO8601
    def self.clazz
      ::Time
    end
  end

  class Timezone < Serializer
    def self.clazz
      ::TZInfo::Timezone
    end

    def self.load(str)
      TZInfo::Timezone.get(str)
    end

    def self.dump(val)
      matches_type!(val)
      val.identifier
    end
  end

  # Abstract serializer for JSON structures conforming to a specified
  # schema. Implementors must override `self.schema`
  class JsonWithSchema < Serializer
    def self.schema
      raise StandardError.new("Unimplemented")
    end

    def self.load(str)
      matches_type!(str)
      JSON.parse(str)
    end

    def self.dump(val)
      matches_type!(val)
      JSON.dump(val)
    end

    def self.matches_type!(val)
      JSON::Validator.validate!(schema, val, validate_schema: !Rails.env.production?)
    end
  end


  ## Abstract serializer for `ActsAsEnum` constants. Implementors must override
  ## `self.clazz`.
  class ActsAsEnum < Serializer
    def self.load(str)
      clazz.value_of!(str)
    end

    def self.dump(val)
      matches_type!(val)
      val.enum_constant
    end
  end

  # Abstract serializer for members of a fixed set of lowercase strings,
  # case-normalized on parse. Implementors must override `self.members`.
  class StringEnum < Serializer
    def self.members
      raise StandardError.new('unimplemented')
    end

    def self.member?(m)
      @member_set ||= members.map(&:downcase).to_set
      @member_set.include?(m)
    end

    def self.load(str)
      val = str.to_s.downcase
      matches_type!(val)
      val
    end

    def self.dump(val)
      matches_type!(val)
      val
    end

    def self.matches_type?(str)
      str.is_a?(String) && self.member?(str)
    end
  end
end
end
