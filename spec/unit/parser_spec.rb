# frozen_string_literal: true

require 'spec_helper'
require 'iknow_params/parser'

RSpec.describe IknowParams::Parser do
  class Controller
    attr_reader :params
    def initialize(params)
      @params = params
    end
  end

  before { Controller.include IknowParams::Parser }

  describe "#parse_param" do

    let(:parsed) { Controller.new(@params).parse_param(@param, with: serializer) }

    context "no serializer specified" do
      let(:serializer) { nil }

      it "returns the value" do
        @params = {name: "foo"}
        @param  = :name

        expect(parsed).to eq @params[@param]
      end

      it "requires the value" do
        @params = {id: 5}
        @param  = :name

        expect { parsed }.to raise_error(IknowParams::Parser::ParseError)
      end

      it "admits an explicit nil" do
        @params = { name: nil }
        @param = :name

        expect(parsed).to eq(nil)
      end

      context "with a default specified" do
        let(:default) { Object.new }
        let(:parsed) { Controller.new(@params).parse_param(@param, with: serializer, default: default) }

        it "returns the value when param is present" do
          @params = {name: "foo"}
          @param  = :name

          expect(parsed).to eq @params[@param]
        end

        it "returns the default when param is missing" do
          @params = {id: 5}
          @param  = :name

          expect(parsed).to eq default
        end
      end

      context "when dumping the value" do
        let(:parsed) { Controller.new(@params).parse_param(@param, with: serializer, dump: true) }

        it "raises an error" do
          @params = {name: "foo"}
          @param  = :name

          expect { parsed }.to raise_error(IknowParams::Parser::ParseError)
        end
      end
    end

    context "with a serializer specified" do
      let(:serializer) { :Integer }

      it "returns the parsed value" do
        @params = {id: "5"}
        @param  = :id

        expect(parsed).to eq 5
      end

      it "registers a typed parse method" do
        params = { id: "5" }
        param  = :id
        expect(Controller.new(params).parse_integer_param(param)).to eq 5
      end

      it "requires the value" do
        @params = {name: "5"}
        @param  = :id

        expect { parsed }.to raise_error(IknowParams::Parser::ParseError)
      end

      it "raises an error when the param can't be parsed into the serializer's type" do
        @params = {id: "fish"}
        @param  = :id

        expect { parsed }.to raise_error(IknowParams::Parser::ParseError)
      end

      context "with a default specified" do
        let(:default) { 9000 }
        let(:parsed) { Controller.new(@params).parse_param(@param, with: serializer, default: default) }

        it "returns the value when param is present" do
          @params = {id: "10"}
          @param  = :id

          expect(parsed).to eq 10
        end

        it "returns the default when param is missing" do
          @params = {name: "22"}
          @param  = :id

          expect(parsed).to eq default
        end
      end

      context "when dumping the value" do
        let(:parsed) { Controller.new(@params).parse_param(@param, with: serializer, dump: true) }

        it "returns the string representation" do
          @params = {id: "10"}
          @param  = :id

          expect(parsed).to eq "10"
        end
      end
    end

    context "with a complex named serializer" do
      class ThisInterestingType < IknowParams::Serializer::Integer
        set_singleton!
      end

      it "registers a typed parse method" do
        params = { id: "5" }
        param  = :id
        expect(Controller.new(params).parse_this_interesting_type_param(param)).to eq 5
      end
    end
  end

  describe "#parse_array_param" do
    let(:parsed) { Controller.new(@params).parse_array_param(@param, with: serializer) }

    context "no serializer specified" do
      let(:serializer) { nil }

      it "returns the values" do
        @params = {names: ["foo", "bar"]}
        @param  = :names

        expect(parsed).to eq @params[@param]
      end

      it "requires the value" do
        @params = {id: 5}
        @param  = :names

        expect { parsed }.to raise_error(IknowParams::Parser::ParseError)
      end

      context "with a default specified" do
        let(:default) { [Object.new] }
        let(:parsed) { Controller.new(@params).parse_param(@param, with: serializer, default: default) }

        it "returns the value when param is present" do
          @params = {names: ["foo", "bar"]}
          @param  = :names

          expect(parsed).to eq @params[@param]
        end

        it "returns the default when param is missing" do
          @params = {id: 5}
          @param  = :names

          expect(parsed).to eq default
        end
      end

      context "when dumping the value" do
        let(:parsed) { Controller.new(@params).parse_param(@param, with: serializer, dump: true) }

        it "raises an error" do
          @params = {names: ["foo"]}
          @param  = :names

          expect { parsed }.to raise_error(IknowParams::Parser::ParseError)
        end
      end
    end

    context "with a serializer specified" do
      let(:serializer) { :Integer }

      it "returns the parsed value" do
        @params = {ids: ["4", "5"]}
        @param  = :ids

        expect(parsed).to eq [4, 5]
      end

      it "registers a typed parse array method" do
        params = { ids: ['4', '5'] }
        param  = :ids
        expect(Controller.new(params).parse_integer_array_param(param)).to eq [4, 5]
      end

      it "requires the value" do
        @params = {name: "5"}
        @param  = :ids

        expect { parsed }.to raise_error(IknowParams::Parser::ParseError)
      end

      it "raises an error when the one of the params can't be parsed into the serializer's type" do
        @params = {ids: ["4", "fish"]}
        @param  = :ids

        expect { parsed }.to raise_error(IknowParams::Parser::ParseError)
      end

      context "with a default specified" do
        let(:default) { [4] }
        let(:parsed) { Controller.new(@params).parse_array_param(@param, with: serializer, default: default) }

        it "returns the value when param is present" do
          @params = {ids: ["10"]}
          @param  = :ids

          expect(parsed).to eq [10]
        end

        it "returns the default when param is missing" do
          @params = {name: "22"}
          @param  = :ids

          expect(parsed).to eq default
        end
      end

      context "when dumping the value" do
        let(:parsed) { Controller.new(@params).parse_array_param(@param, with: serializer, dump: true) }

        it "returns the string representation" do
          @params = {ids: ["10"]}
          @param  = :ids

          expect(parsed).to eq ["10"]
        end
      end

    end
  end

  describe '.parse_hash' do
    let(:hash) { { name: "1" } }

    it "invokes parsers on an arbitrary hash" do
      parsed = IknowParams::Parser.parse_hash(hash) do
        parse_param(:name, with: :Integer)
      end
      expect(parsed).to eq(1)
    end
  end

  describe '.parse_value' do
    it "invokes parsers on an arbitrary value" do
      parsed = IknowParams::Parser.parse_value("1", with: :Integer)
      expect(parsed).to eq(1)
    end
  end

  describe '.parse_values' do
    it "invokes parsers on an array of arbitrary values" do
      parsed = IknowParams::Parser.parse_values(["1", "2"], with: :Integer)
      expect(parsed).to eq([1, 2])
    end
  end

  describe '#remove_blanks' do
    let(:parsed) do
      {"id" => 5,
       "user" => {
        "name" => "Tomoyo",
        "favorite_color" => IknowParams::Parser::BLANK,
        "comment_ids" => [IknowParams::Parser::BLANK, IknowParams::Parser::BLANK, 5]
      }
      }
    end

    let(:expected) do
      {"id" => 5,
       "user" => {
        "name" => "Tomoyo",
        "comment_ids" => [5]
      }
      }
    end

    it "removes blanks" do
      expect(Controller.new({}).remove_blanks(parsed)).to eq expected
    end
  end
end

