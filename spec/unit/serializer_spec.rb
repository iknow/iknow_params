require "spec_helper"

RSpec.describe IknowParams::Serializer do
  shared_examples "a serializer" do
    it "can load its type from a string" do
      valid_values.each do |valid, parsed|
        expect(described_class.load(valid)).to eq parsed
      end
    end

    it "raises an error when asked to load a bad value" do
      invalid_values.each do |invalid|
        expect { described_class.load(invalid) }.to(raise_error(ArgumentError), "value was accepted: #{invalid}")
      end
    end

    it "dumps to a string" do
      valid_values.values.each do |parsed|
        expect(described_class.singleton.dump(parsed)).to eq parsed.public_send(string_serializer)
      end
    end

    it "dumps to a string or JSON value when asked for JSON" do
      valid_values.values.each do |parsed|
        if described_class.json_value?
          expect(described_class.singleton.dump(parsed, json: true)).to eq parsed
        else
          expect(described_class.singleton.dump(parsed, json: true)).to eq parsed.public_send(string_serializer)
        end
      end
    end

    it "matches the type of arguments" do
      expect(described_class.singleton.matches_type?(valid_values.values.first)).to eq true

      invalid_values.each do |invalid|
        expect(described_class.singleton.matches_type?(invalid)).to(eq(false), "value was accepted: #{invalid}")
      end
    end
  end

  shared_examples "a JSON-value serializer" do
    it "represents a JSON value" do
      expect(described_class.json_value?).to eq true
    end
  end

  shared_examples "a non-JSON value serializer" do
    it "represents a non-JSON value" do
      expect(described_class.json_value?).to eq false
    end
  end

  # What we expect dump to use to serialize the entity to a string
  let(:string_serializer) { :to_s }

  describe IknowParams::Serializer::Integer do
    let(:valid_values)   { {"33" => 33, 33 => 33, "-1" => -1, -2 => -2} }
    let(:invalid_values) { ["fish", "4.5", 4.5, Object.new] }

    it_behaves_like "a serializer"
    it_behaves_like "a JSON-value serializer"
  end

  describe IknowParams::Serializer::Float do
    let(:valid_values)  {  {"33.3" => 33.3, 33.3 => 33.3, "0.0" => 0.0, 0.0 => 0.0, 0 => 0.0} }
    let(:invalid_values) { ["fish", {}, Object.new] }

    it_behaves_like "a serializer"
    it_behaves_like "a JSON-value serializer"
  end

  describe IknowParams::Serializer::Boolean do
    let(:valid_values)  {  {true => true, 'yes' => true, 'on' => true, 'ON' => true, 'true' => true, '1' => true, 1 => true, 1.0 => true,
                            false => false, 'no' => false, 'off' => false, 'OFF' => false, 'false' => false, '0' => false, 0 => false, 0.0 =>false} }

    let(:invalid_values) { ["fish", {}, Object.new, 2] }

    it_behaves_like "a serializer"
    it_behaves_like "a JSON-value serializer"
  end

  describe IknowParams::Serializer::Numeric do
    let(:valid_values)  {  {"33.3" => 33.3, 33.3 => 33.3, "0.0" => 0.0, 0.0 => 0.0, 0 => 0.0, "2" => 2, 2 => 2} }
    let(:invalid_values) { ["fish", {}, Object.new] }

    it_behaves_like "a serializer"
    it_behaves_like "a JSON-value serializer"
  end

  describe IknowParams::Serializer::Date do
    let(:valid_values)  {  {"2017/07/13" => Date.new(2017, 07, 13), "1998/01" => Date.new(1998, 01, 01), "2017/07/13 13:00" => Date.new(2017, 07, 13)} }
    let(:invalid_values) { ["fish", {}, Object.new] }

    let(:string_serializer) { :iso8601 }

    it_behaves_like "a serializer"
    it_behaves_like "a non-JSON value serializer"
  end

  describe IknowParams::Serializer::Time do
    let(:valid_values)  { {"2017/07/13 10:00 UTC" => Time.parse("2017/07/13 10:00 UTC"), "2017/07/13 13:00 JST" => Time.parse("2017/07/13 13:00 JST"), "20170525T204236+0700" => Time.parse("2017/05/25 20:42:36 +0700")} }
    let(:invalid_values) { ["fish", {}, Object.new] }

    let(:string_serializer) { :iso8601 }

    it_behaves_like "a serializer"
    it_behaves_like "a non-JSON value serializer"
  end

  describe IknowParams::Serializer::Timezone do
    let(:valid_values)  {  {"Asia/Tokyo" => TZInfo::Timezone.get("Asia/Tokyo"), "Asia/Shanghai" => TZInfo::Timezone.get("Asia/Shanghai"), "Europe/Berlin" => TZInfo::Timezone.get("Europe/Berlin")} }
    let(:invalid_values) { ["Tokyo", {}, Object.new, "Eastern"] }

    let(:string_serializer) { :identifier }

    it_behaves_like "a serializer"
    it_behaves_like "a non-JSON value serializer"
  end

  describe IknowParams::Serializer::UUID do
    let(:valid_values)  {  {"e56986f4-4418-4f7a-99d8-3faccde33f6b" => "e56986f4-4418-4f7a-99d8-3faccde33f6b",
                            "1e851f60-4eb9-4660-ad4e-ac0b315f3647" => "1e851f60-4eb9-4660-ad4e-ac0b315f3647",
                            "8a540cb9-8107-45e8-8611-82b9171b4a4b" => "8a540cb9-8107-45e8-8611-82b9171b4a4b" } }

    let(:invalid_values) { ["e56986f4-4418-4f7a-99d8-3faccde33f$b", {}, Object.new, "e56986f4-4418-4f7a-99d8-3faccde33fb"] }

    it_behaves_like "a serializer"
    it_behaves_like "a JSON-value serializer"
  end

  # Test abstract JsonWithSchema serializer by making a real schema
  # and serializer for it.

  class MyJsonSerializer < IknowParams::Serializer::JsonWithSchema
    def initialize
      schema = {"type" => "object", "required" => ["a"], "properties" => {"a" => {"type" => "integer"}}}
      super(schema)
    end

    set_singleton!
  end

  describe MyJsonSerializer do
    let(:valid_values)  { {'{"a": 5}' => {"a" => 5}, '{"a": 6}' => {"a" => 6}} }
    let(:invalid_values) { ['{"a": "5"}', '{"b": 6}', '[]', '{}'] }

    let(:string_serializer) { :to_json }

    it_behaves_like "a serializer"
    it_behaves_like "a JSON-value serializer"
  end

  # Test abstract JsonWithSchema serializer by making a real schema
  # and serializer for it.

  class MyJsonSerializer < IknowParams::Serializer::JsonWithSchema
    def initialize
      schema = {"type" => "object", "required" => ["a"], "properties" => {"a" => {"type" => "integer"}}}
      super(schema)
    end

    set_singleton!
  end

  describe MyJsonSerializer do
    let(:valid_values)  { {'{"a": 5}' => {"a" => 5}, '{"a": 6}' => {"a" => 6}} }
    let(:invalid_values) { ['{"a": "5"}', '{"b": 6}', '[]', '{}'] }

    let(:string_serializer) { :to_json }

    it_behaves_like "a serializer"
    it_behaves_like "a JSON-value serializer"
  end

  # Test abstract StringEnum serializer by making a real enum
  # and serializer for it.

  class MyStringEnumSerializer < IknowParams::Serializer::StringEnum
    def initialize
      super("a", "b")
    end

    set_singleton!
  end

  describe MyStringEnumSerializer do
    let(:valid_values)   { {'a' => 'a', 'b' => 'b', 'B' => 'b'} }
    let(:invalid_values) { ['c', 'd'] }

    let(:string_serializer) { :downcase }

    it_behaves_like "a serializer"
    it_behaves_like "a non-JSON value serializer"
  end
end

