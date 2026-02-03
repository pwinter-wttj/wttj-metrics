# frozen_string_literal: true

require 'tempfile'

RSpec.describe WttjMetrics::Data::CsvParser do
  subject(:parser) { described_class.new(csv_path) }

  let(:csv_path) { temp_csv.path }
  let(:temp_csv) { Tempfile.new(['metrics', '.csv']) }

  before do
    # Create a test CSV file
    CSV.open(temp_csv.path, 'w') do |csv|
      csv << %w[date category metric value]
      csv << %w[2024-12-01 flow throughput 10]
      csv << %w[2024-12-02 flow throughput 15]
      csv << %w[2024-12-01 flow wip 25]
      csv << %w[2024-12-01 bugs open_bugs 5]
      csv << %w[2024-12-02 bugs open_bugs 3]
    end
  end

  after do
    temp_csv.close
    temp_csv.unlink
  end

  describe '#initialize' do
    it 'loads CSV data' do
      parser = described_class.new(temp_csv.path)
      expect(parser.data).not_to be_empty
      expect(parser.data.first['date']).to eq('2024-12-01')
      expect(parser.data.first['category']).to eq('flow')
      expect(parser.data.first['metric']).to eq('throughput')
      expect(parser.data.first['value']).to eq('10')
    end
  end

  describe '#metrics_by_category' do
    it 'groups metrics by category' do
      parser = described_class.new(temp_csv.path)
      expect(parser.metrics_by_category).to have_key('flow')
      expect(parser.metrics_by_category).to have_key('bugs')
    end

    it 'contains correct data structure' do
      parser = described_class.new(temp_csv.path)
      flow_metrics = parser.metrics_by_category['flow']
      expect(flow_metrics).to be_an(Array)
      expect(flow_metrics.first).to have_key(:date)
      expect(flow_metrics.first).to have_key(:metric)
      expect(flow_metrics.first).to have_key(:value)
    end
  end

  describe '#metrics_for' do
    it 'returns metrics for a specific category' do
      parser = described_class.new(temp_csv.path)
      flow_metrics = parser.metrics_for('flow', date: '2024-12-01')
      expect(flow_metrics).to be_an(Array)
      expect(flow_metrics.size).to eq(2)
    end

    it 'filters by date when provided' do
      parser = described_class.new(temp_csv.path)
      metrics = parser.metrics_for('flow', date: '2024-12-01')
      expect(metrics.size).to eq(2)
      expect(metrics.all? { |m| m[:date] == '2024-12-01' }).to be true
    end

    it 'returns empty array for unknown category' do
      parser = described_class.new(temp_csv.path)
      expect(parser.metrics_for('unknown')).to eq([])
    end
  end

  describe '#timeseries_for' do
    it 'looks for metrics in timeseries category' do
      parser = described_class.new(temp_csv.path)
      # timeseries_for expects data in 'timeseries' category
      series = parser.timeseries_for('throughput', since: '2024-12-01')
      expect(series).to be_an(Array)
    end

    it 'returns empty array when no timeseries category exists' do
      parser = described_class.new(temp_csv.path)
      expect(parser.timeseries_for('unknown_metric', since: '2024-12-01')).to eq([])
    end

    context 'when timeseries category exists' do
      let(:csv_with_timeseries) { Tempfile.new(['timeseries', '.csv']) }

      before do
        CSV.open(csv_with_timeseries.path, 'w') do |csv|
          csv << %w[date category metric value]
          csv << %w[2024-12-01 timeseries throughput 10]
          csv << %w[2024-12-02 timeseries throughput 15]
          csv << %w[2024-11-30 timeseries throughput 99]
          csv << %w[2024-12-02 timeseries other_metric 123]
        end
      end

      after do
        csv_with_timeseries.close
        csv_with_timeseries.unlink
      end

      it 'filters by metric name and since date' do
        parser = described_class.new(csv_with_timeseries.path)

        series = parser.timeseries_for('throughput', since: '2024-12-01')

        aggregate_failures do
          expect(series.map { |m| m[:date] }).to eq(%w[2024-12-01 2024-12-02])
          expect(series.map { |m| m[:value] }).to eq([10.0, 15.0])
        end
      end
    end
  end

  describe 'value parsing' do
    let(:csv_with_cycles) { Tempfile.new(['cycles', '.csv']) }

    before do
      CSV.open(csv_with_cycles.path, 'w') do |csv|
        csv << %w[date category metric value]
        csv << ['2024-12-01', 'cycle', 'cycle_time', '{"state":"Done","days":5}']
        csv << %w[2024-12-01 flow throughput 42.5]
      end
    end

    after do
      csv_with_cycles.close
      csv_with_cycles.unlink
    end

    it 'parses cycle category values as strings' do
      parser = described_class.new(csv_with_cycles.path)
      cycle_metrics = parser.metrics_by_category['cycle']
      expect(cycle_metrics.first[:value]).to be_a(String)
      expect(cycle_metrics.first[:value]).to eq('{"state":"Done","days":5}')
    end

    it 'parses non-cycle values as floats' do
      parser = described_class.new(csv_with_cycles.path)
      flow_metrics = parser.metrics_by_category['flow']
      expect(flow_metrics.first[:value]).to be_a(Float)
      expect(flow_metrics.first[:value]).to eq(42.5)
    end
  end
end
