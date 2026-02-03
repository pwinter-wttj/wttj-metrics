# frozen_string_literal: true

require 'logger'

RSpec.describe WttjMetrics::Services::MetricsCollector do
  let(:logger) { instance_double(Logger, info: nil) }
  let(:options) do
    double(
      'Options',
      cache_enabled: true,
      clear_cache: false,
      output: 'tmp/metrics.csv',
      sources: ['linear'],
      days: 90,
      start_date: nil,
      end_date: Date.today
    )
  end

  let(:cache) { instance_double(WttjMetrics::Data::FileCache, clear!: nil) }
  let(:data_fetcher) { instance_double(WttjMetrics::Services::Linear::DataFetcher, call: fetched_data) }
  let(:calculator) { instance_double(WttjMetrics::Metrics::Linear::Calculator, calculate_all: calculated_rows) }
  let(:csv_writer) { instance_double(WttjMetrics::Data::CsvWriter, write_rows: nil) }
  let(:summary_logger) { instance_double(WttjMetrics::Services::MetricsSummaryLogger, call: nil) }

  let(:fetched_data) do
    {
      issues: [{ id: '1' }],
      cycles: [{ id: 'c1' }],
      team_members: [{ id: 'm1' }],
      workflow_states: [{ id: 's1' }]
    }
  end

  let(:calculated_rows) do
    [
      ['2024-01-01', 'flow', 'median_cycle_time_days', '10.5'],
      ['2024-01-01', 'issues', 'total_issues', '150']
    ]
  end

  before do
    allow(WttjMetrics::Config).to receive(:validate!)
    allow(WttjMetrics::Services::CacheFactory).to receive_messages(enabled: cache, disabled: nil)
    allow(WttjMetrics::Services::Linear::DataFetcher).to receive(:new).with(anything, anything, anything,
                                                                            anything).and_return(data_fetcher)
    allow(WttjMetrics::Metrics::Linear::Calculator).to receive(:new).and_return(calculator)
    allow(WttjMetrics::Data::CsvWriter).to receive(:new).and_return(csv_writer)
    allow(WttjMetrics::Services::MetricsSummaryLogger).to receive(:new).and_return(summary_logger)
  end

  describe '#call' do
    subject(:collector) { described_class.new(options, logger) }

    it 'validates configuration' do
      collector.call

      expect(WttjMetrics::Config).to have_received(:validate!)
    end

    it 'logs the start message with current date' do
      collector.call

      expect(logger).to have_received(:info).with(match(/🚀 Starting Metrics Collection \(linear\) - #{Date.today}/))
    end

    it 'creates a DataFetcher with cache, logger, and date range' do
      collector.call

      expect(WttjMetrics::Services::Linear::DataFetcher).to have_received(:new).with(cache, logger, anything, anything)
    end

    it 'calls DataFetcher to fetch data' do
      collector.call

      expect(data_fetcher).to have_received(:call)
    end

    it 'logs metrics calculation' do
      collector.call

      expect(logger).to have_received(:info).with('🔢 Calculating metrics...')
    end

    it 'creates a Calculator with fetched data' do
      collector.call

      expect(WttjMetrics::Metrics::Linear::Calculator).to have_received(:new).with(
        [{ id: '1' }],
        [{ id: 'c1' }],
        [{ id: 'm1' }],
        [{ id: 's1' }]
      )
    end

    it 'calls calculate_all on the calculator' do
      collector.call

      expect(calculator).to have_received(:calculate_all)
    end

    it 'creates a CsvWriter with output path' do
      collector.call

      expect(WttjMetrics::Data::CsvWriter).to have_received(:new).with('tmp/metrics.csv')
    end

    it 'writes calculated rows to CSV' do
      collector.call

      expect(csv_writer).to have_received(:write_rows).with(calculated_rows)
    end

    it 'logs writing metrics with row count' do
      collector.call

      expect(logger).to have_received(:info).with(match(/📝 Writing 2 metrics to CSV/))
    end

    it 'logs success message' do
      collector.call

      expect(logger).to have_received(:info).with('✅ Metrics collected and saved successfully!')
    end

    it 'creates and calls MetricsSummaryLogger' do
      collector.call

      expect(WttjMetrics::Services::MetricsSummaryLogger).to have_received(:new).with(calculated_rows, logger)
      expect(summary_logger).to have_received(:call)
    end

    context 'when cache is enabled' do
      let(:options) do
        double('Options', cache_enabled: true, clear_cache: false, output: 'tmp/metrics.csv', sources: ['linear'],
                          days: 90, start_date: nil, end_date: Date.today)
      end

      it 'uses enabled cache' do
        collector.call

        expect(WttjMetrics::Services::CacheFactory).to have_received(:enabled)
      end

      it 'does not clear cache when clear_cache is false' do
        collector.call

        expect(cache).not_to have_received(:clear!)
      end
    end

    context 'when cache is disabled' do
      let(:options) do
        double('Options', cache_enabled: false, clear_cache: false, output: 'tmp/metrics.csv', sources: ['linear'],
                          days: 90, start_date: nil, end_date: Date.today)
      end

      it 'uses disabled cache (nil)' do
        collector.call

        expect(WttjMetrics::Services::CacheFactory).to have_received(:disabled)
      end

      it 'passes nil as cache to DataFetcher' do
        collector.call

        expect(WttjMetrics::Services::Linear::DataFetcher).to have_received(:new).with(nil, logger, anything, anything)
      end
    end

    context 'when clear_cache is true' do
      let(:options) do
        double('Options', cache_enabled: true, clear_cache: true, output: 'tmp/metrics.csv', sources: ['linear'],
                          days: 90, start_date: nil, end_date: Date.today)
      end

      it 'clears the cache before fetching data' do
        collector.call

        expect(cache).to have_received(:clear!)
      end
    end

    context 'with integration flow' do
      let(:call_order) { [] }

      before do
        allow(WttjMetrics::Config).to receive(:validate!) { call_order << :validate }
        allow(logger).to receive(:info) do |msg|
          call_order << :log_start if msg.include?('🚀 Starting')
          call_order << :log_calculating if msg.include?('🔢 Calculating')
          call_order << :log_writing if msg.include?('📝 Writing')
          call_order << :log_success if msg.include?('✅ Metrics collected')
        end
        allow(data_fetcher).to receive(:call) {
          call_order << :fetch_data
          fetched_data
        }
        allow(calculator).to receive(:calculate_all) {
          call_order << :calculate
          calculated_rows
        }
        allow(csv_writer).to receive(:write_rows) { call_order << :write }
        allow(summary_logger).to receive(:call) { call_order << :log_summary }
      end

      it 'executes steps in correct order' do
        collector.call

        expect(call_order).to eq(%i[
                                   validate
                                   log_start
                                   fetch_data
                                   log_calculating
                                   calculate
                                   log_writing
                                   write
                                   log_success
                                   log_summary
                                 ])
      end
    end

    context 'with GitHub source' do
      let(:options) do
        double(
          'Options',
          cache_enabled: true,
          clear_cache: false,
          output: 'tmp/metrics.csv',
          sources: ['github'],
          days: 90,
          start_date: nil,
          end_date: Date.today
        )
      end
      let(:github_fetcher) { instance_double(WttjMetrics::Services::Github::DataFetcher, call: github_data) }
      let(:github_calculator) { instance_double(WttjMetrics::Metrics::Github::Calculator, calculate_all: github_rows) }
      let(:github_data) { { pull_requests: [{ title: 'PR 1' }] } }
      let(:github_rows) { [%w[2024-01-01 github pr_velocity 5]] }

      before do
        allow(WttjMetrics::Services::Github::DataFetcher).to receive(:new).with(anything, anything, anything,
                                                                                anything).and_return(github_fetcher)
        allow(WttjMetrics::Metrics::Github::Calculator).to receive(:new).and_return(github_calculator)
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('GITHUB_TOKEN').and_return('token')
        allow(ENV).to receive(:fetch).with('GITHUB_ORG', nil).and_return('org')
      end

      it 'fetches and calculates GitHub metrics' do
        collector.call

        expect(github_fetcher).to have_received(:call)
        expect(github_calculator).to have_received(:calculate_all)
        expect(csv_writer).to have_received(:write_rows).with(github_rows)
      end

      it 'does not fetch Linear data' do
        collector.call

        expect(data_fetcher).not_to have_received(:call)
      end
    end

    context 'with GitHub source but missing configuration' do
      let(:options) do
        double(
          'Options',
          cache_enabled: true,
          clear_cache: false,
          output: 'tmp/metrics.csv',
          sources: ['github'],
          days: 90,
          start_date: nil,
          end_date: Date.today
        )
      end

      before do
        allow(WttjMetrics::Services::Github::DataFetcher).to receive(:new)
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('GITHUB_TOKEN').and_return('token')
        allow(ENV).to receive(:fetch).with('GITHUB_ORG', nil).and_return(nil)
        allow(logger).to receive(:warn)
      end

      it 'logs warning and skips GitHub fetching' do
        collector.call
        expect(logger).to have_received(:warn).with('⚠️  Skipping GitHub: GITHUB_ORG not set')
        expect(WttjMetrics::Services::Github::DataFetcher).not_to have_received(:new)
      end
    end

    context 'with GitHub source but missing token' do
      let(:github_fetcher) { instance_double(WttjMetrics::Services::Github::DataFetcher, call: github_data) }
      let(:github_calculator) { instance_double(WttjMetrics::Metrics::Github::Calculator, calculate_all: github_rows) }
      let(:github_data) { { pull_requests: [{ title: 'PR 1' }], releases: [], teams: {} } }
      let(:github_rows) { [%w[2024-01-01 github pr_velocity 5]] }

      let(:options) do
        double(
          'Options',
          cache_enabled: true,
          clear_cache: false,
          output: 'tmp/metrics.csv',
          sources: ['github'],
          days: 90,
          start_date: nil,
          end_date: Date.today
        )
      end

      before do
        allow(WttjMetrics::Services::Github::DataFetcher).to receive(:new).with(anything, anything, anything,
                                                                                anything).and_return(github_fetcher)
        allow(WttjMetrics::Metrics::Github::Calculator).to receive(:new).and_return(github_calculator)
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('GITHUB_TOKEN').and_return(nil)
        allow(ENV).to receive(:fetch).with('GITHUB_ORG', nil).and_return('org')
        allow(logger).to receive(:warn)
      end

      it 'logs warning and fetches GitHub data using cache-only mode' do
        collector.call

        expect(logger).to have_received(:warn).with('⚠️  GITHUB_TOKEN not set; using cache-only GitHub data')
        expect(WttjMetrics::Services::Github::DataFetcher).to have_received(:new)
        expect(github_fetcher).to have_received(:call)
      end
    end

    context 'with empty data' do
      let(:fetched_data) { {} }

      it 'returns early without writing results' do
        collector.call
        expect(csv_writer).not_to have_received(:write_rows)
      end
    end

    context 'with data but missing specific keys' do
      let(:fetched_data) { { other: 'data' } }

      it 'does not calculate linear metrics if issues missing' do
        collector.call
        expect(calculator).not_to have_received(:calculate_all)
      end
    end
  end
end
