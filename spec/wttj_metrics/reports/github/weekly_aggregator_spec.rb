# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WttjMetrics::Reports::Github::WeeklyAggregator do
  subject(:aggregator) { described_class.new(daily_data) }

  let(:daily_data) do
    [
      { date: '2024-01-01', metric: 'merged', value: 5 }, # Week 1
      { date: '2024-01-02', metric: 'merged', value: 3 }, # Week 1
      { date: '2024-01-08', metric: 'merged', value: 10 }, # Week 2
      { date: '2024-01-01', metric: 'open', value: 2 },
      { date: '2024-01-02', metric: 'open', value: 4 },
      { date: '2024-01-01', metric: 'median_time_to_merge_hours', value: 10 },
      { date: '2024-01-02', metric: 'median_time_to_merge_hours', value: 20 }
    ]
  end

  describe '#aggregate' do
    let(:result) { aggregator.aggregate }

    it 'returns labels and datasets' do
      expect(result).to have_key(:labels)
      expect(result).to have_key(:datasets)
    end

    it 'generates correct labels (start of week)' do
      # 2024-01-01 is Monday, Week 1
      # 2024-01-08 is Monday, Week 2
      expect(result[:labels]).to eq(%w[2024-01-01 2024-01-08])
    end

    it 'aggregates merged count (sum)' do
      # Week 1: 5 + 3 = 8
      # Week 2: 10
      expect(result[:datasets][:merged]).to eq([8, 10])
    end

    it 'aggregates open count (last value)' do
      # Week 1: last value is 4 (from 2024-01-02)
      # Week 2: 0 (no open metric)
      expect(result[:datasets][:open]).to eq([4, 0])
    end

    it 'calculates weighted median for time to merge' do
      # Week 1 values (weighted by merged count):
      # 10h (weight 5), 20h (weight 3) => weighted median is 10
      expect(result[:datasets][:median_time_to_merge]).to eq([10.0, 0.0])
    end

    context 'with empty data' do
      let(:daily_data) { [] }

      it 'returns empty structure' do
        expect(result[:labels]).to be_empty
        expect(result[:datasets][:merged]).to be_empty
      end
    end

    context 'with missing or zero data' do
      let(:daily_data) do
        [
          { date: '2024-01-01', metric: 'other', value: 1 }
        ]
      end

      it 'returns 0 for calculations with zero denominator' do
        expect(result[:datasets][:median_time_to_merge]).to eq([0]) # weight 0
        expect(result[:datasets][:median_time_to_first_review]).to eq([0]) # empty values
        expect(result[:datasets][:hotfix_rate]).to eq([0]) # denominator 0
        expect(result[:datasets][:merge_rate]).to eq([0]) # total_processed 0
        expect(result[:datasets][:ci_success_rate]).to eq([0]) # total_base 0
      end
    end
  end
end
