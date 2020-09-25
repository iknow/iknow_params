# frozen_string_literal: true

require 'spec_helper'
require 'iknow_params'
require 'rails'

RSpec.describe IknowParams::Serializer::ArrayOf do
  let(:subject) { IknowParams::Serializer::ArrayOf.new(IknowParams::Serializer::Date) }

  let(:serialized_dates) { ['2000-01-01', '2000-01-02'] }
  let(:dates) { serialized_dates.map { |d| Date.parse(d) } }

  describe '#load' do
    it 'can load correct values' do
      expect(subject.load(serialized_dates)).to eq(dates)
    end

    it 'raises load error on incorrect type' do
      expect { subject.load(12) }.to raise_error(IknowParams::Serializer::LoadError)
    end
  end

  describe '#dump' do
    it 'can dump correct values' do
      expect(subject.dump(dates)).to eq(serialized_dates)
    end

    it 'raises dump error on incorrect type' do
      expect { subject.dump(12) }.to raise_error(IknowParams::Serializer::DumpError)
    end
  end
end
