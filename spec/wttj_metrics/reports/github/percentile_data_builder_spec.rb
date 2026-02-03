# frozen_string_literal: true

require 'wttj_metrics/reports/github/percentile_data_builder'

RSpec.describe WttjMetrics::Reports::Github::PercentileDataBuilder do
  subject(:builder) { described_class.new(parser, cutoff_date: cutoff_date) }

  let(:parser) { instance_double(WttjMetrics::Data::CsvParser) }
  let(:cutoff_date) { '2025-01-01' }

  let(:daily_metrics) do
    [
      { date: '2025-01-15', metric: 'median_time_to_first_review_days', value: '1.5' },
      { date: '2025-01-16', metric: 'median_time_to_first_review_days', value: '2.0' },
      { date: '2025-01-17', metric: 'median_time_to_first_review_days', value: '0.8' },
      { date: '2025-01-18', metric: 'median_time_to_first_review_days', value: '3.2' },
      { date: '2025-01-15', metric: 'median_time_to_merge_hours', value: '48' },
      { date: '2025-01-16', metric: 'median_time_to_merge_hours', value: '72' },
      { date: '2025-01-17', metric: 'median_time_to_merge_hours', value: '24' },
      { date: '2025-01-18', metric: 'median_time_to_merge_hours', value: '96' },
      { date: '2025-01-15', metric: 'median_additions_per_pr', value: '100' },
      { date: '2025-01-16', metric: 'median_additions_per_pr', value: '150' },
      { date: '2025-01-17', metric: 'median_additions_per_pr', value: '50' },
      { date: '2025-01-18', metric: 'median_additions_per_pr', value: '200' },
      { date: '2025-01-15', metric: 'median_deletions_per_pr', value: '30' },
      { date: '2025-01-16', metric: 'median_deletions_per_pr', value: '40' },
      { date: '2025-01-17', metric: 'median_deletions_per_pr', value: '20' },
      { date: '2025-01-18', metric: 'median_deletions_per_pr', value: '60' },
      { date: '2025-01-15', metric: 'median_reviews_per_pr', value: '1.5' },
      { date: '2025-01-16', metric: 'median_reviews_per_pr', value: '2.0' },
      { date: '2025-01-17', metric: 'median_reviews_per_pr', value: '1.0' },
      { date: '2025-01-18', metric: 'median_reviews_per_pr', value: '2.5' },
      { date: '2025-01-15', metric: 'merged', value: '10' },
      { date: '2025-01-16', metric: 'merged', value: '15' },
      { date: '2025-01-17', metric: 'merged', value: '8' },
      { date: '2025-01-18', metric: 'merged', value: '12' },
      { date: '2025-01-15', metric: 'created', value: '12' },
      { date: '2025-01-16', metric: 'created', value: '18' },
      { date: '2025-01-17', metric: 'created', value: '10' },
      { date: '2025-01-18', metric: 'created', value: '14' },
      { date: '2025-01-15', metric: 'ci_success_rate', value: '85' },
      { date: '2025-01-16', metric: 'ci_success_rate', value: '92' },
      { date: '2025-01-17', metric: 'ci_success_rate', value: '78' },
      { date: '2025-01-18', metric: 'ci_success_rate', value: '95' },
      { date: '2025-01-15', metric: 'median_time_to_green_hours', value: '0.5' },
      { date: '2025-01-16', metric: 'median_time_to_green_hours', value: '0.8' },
      { date: '2025-01-17', metric: 'median_time_to_green_hours', value: '0.3' },
      { date: '2025-01-18', metric: 'median_time_to_green_hours', value: '1.2' }
    ]
  end

  before do
    allow(parser).to receive(:metrics_by_category).and_return({ 'github_daily' => daily_metrics })
  end

  describe '#time_to_first_review_percentiles' do
    it 'returns percentile data structure' do
      result = builder.time_to_first_review_percentiles

      aggregate_failures do
        expect(result).to have_key(:percentiles)
        expect(result).to have_key(:labels)
        expect(result).to have_key(:stats)
        expect(result[:labels]).to eq(%w[P50 P75 P90 P95])
      end
    end

    it 'calculates percentiles correctly' do
      result = builder.time_to_first_review_percentiles

      expect(result[:percentiles]).to be_an(Array)
      expect(result[:percentiles].size).to eq(4)
      expect(result[:percentiles].first).to be_between(0.8, 3.2)
    end

    it 'includes basic statistics' do
      result = builder.time_to_first_review_percentiles

      aggregate_failures do
        expect(result[:stats][:min]).to eq(0.8)
        expect(result[:stats][:max]).to eq(3.2)
        expect(result[:stats][:count]).to eq(4)
      end
    end
  end

  describe '#time_to_merge_percentiles' do
    it 'converts hours to days' do
      result = builder.time_to_merge_percentiles

      # 24h = 1d, 48h = 2d, 72h = 3d, 96h = 4d
      # P50 should be around 2.5 days
      expect(result[:percentiles].first).to be_between(1, 4)
      expect(result[:unit]).to eq('days')
    end
  end

  describe '#pr_size_percentiles' do
    it 'returns combined size data' do
      result = builder.pr_size_percentiles

      aggregate_failures do
        expect(result).to have_key(:percentiles)
        expect(result).to have_key(:additions)
        expect(result).to have_key(:deletions)
        expect(result[:unit]).to eq('lines')
      end
    end

    it 'separates additions and deletions' do
      result = builder.pr_size_percentiles

      expect(result[:additions][:percentiles]).to be_an(Array)
      expect(result[:deletions][:percentiles]).to be_an(Array)
    end
  end

  describe '#reviews_per_pr_percentiles' do
    it 'returns review count percentiles' do
      result = builder.reviews_per_pr_percentiles

      aggregate_failures do
        expect(result[:percentiles].size).to eq(4)
        expect(result[:unit]).to eq('reviews')
      end
    end
  end

  describe '#weekly_pr_throughput' do
    it 'aggregates data by week' do
      result = builder.weekly_pr_throughput

      aggregate_failures do
        expect(result).to have_key(:labels)
        expect(result).to have_key(:merged)
        expect(result).to have_key(:created)
        expect(result).to have_key(:percentiles)
      end
    end

    it 'formats week labels correctly' do
      result = builder.weekly_pr_throughput

      expect(result[:labels].first).to match(/^W\d+$/)
    end
  end

  describe '#ci_success_rate_distribution' do
    it 'returns distribution histogram' do
      result = builder.ci_success_rate_distribution

      aggregate_failures do
        expect(result).to have_key(:percentiles)
        expect(result).to have_key(:distribution)
        expect(result[:distribution]).to be_an(Array)
        expect(result[:distribution].first).to have_key(:range)
        expect(result[:distribution].first).to have_key(:count)
      end
    end
  end

  describe '#time_to_green_percentiles' do
    it 'returns CI duration percentiles' do
      result = builder.time_to_green_percentiles

      aggregate_failures do
        expect(result[:unit]).to eq('hours')
        expect(result[:percentiles].size).to eq(4)
      end
    end
  end

  describe '#all_percentile_data' do
    it 'returns combined percentile data' do
      result = builder.all_percentile_data

      aggregate_failures do
        expect(result).to have_key(:time_to_first_review)
        expect(result).to have_key(:time_to_merge)
        expect(result).to have_key(:time_to_approval)
        expect(result).to have_key(:pr_size)
        expect(result).to have_key(:rework_cycles)
        expect(result).to have_key(:reviews_per_pr)
        expect(result).to have_key(:time_to_green)
        expect(result).to have_key(:ci_success_rate)
        expect(result).to have_key(:weekly_throughput)
        expect(result).to have_key(:deploy_frequency)
      end
    end
  end

  describe 'edge cases' do
    context 'with empty data' do
      before do
        allow(parser).to receive(:metrics_by_category).and_return({ 'github_daily' => [] })
      end

      it 'handles empty data gracefully' do
        result = builder.time_to_first_review_percentiles

        aggregate_failures do
          expect(result[:percentiles]).to eq([0, 0, 0, 0])
          expect(result[:stats][:count]).to eq(0)
        end
      end
    end

    context 'with cutoff date filtering' do
      let(:cutoff_date) { '2025-01-17' }

      it 'filters out data before cutoff' do
        result = builder.time_to_first_review_percentiles

        # Should only include 2025-01-17 (0.8) and 2025-01-18 (3.2)
        expect(result[:stats][:count]).to eq(2)
      end
    end
  end
end
