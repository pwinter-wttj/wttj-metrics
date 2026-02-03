# frozen_string_literal: true

module WttjMetrics
  module Services
    # Orchestrates metrics collection from Linear API
    class MetricsCollector
      def initialize(options, logger)
        @options = options
        @logger = logger
      end

      def call
        validate_config
        log_start
        data = fetch_data
        return if data.empty?

        rows = calculate_metrics(data)
        write_results(rows)
        log_summary(rows)
      end

      private

      attr_reader :options, :logger

      def validate_config
        Config.validate!
      end

      def log_start
        logger.info "🚀 Starting Metrics Collection (#{options.sources.join(', ')}) - #{Date.today}"
      end

      def fetch_data
        data = {}

        if options.sources.include?('linear')
          data.merge!(Linear::DataFetcher.new(cache_strategy, logger, start_date, end_date).call)
        end

        if options.sources.include?('github')
          if ENV.fetch('GITHUB_ORG', nil)
            logger.warn '⚠️  GITHUB_TOKEN not set; using cache-only GitHub data' unless ENV['GITHUB_TOKEN']
            data.merge!(Github::DataFetcher.new(cache_strategy, logger, start_date, end_date).call)
          else
            logger.warn '⚠️  Skipping GitHub: GITHUB_ORG not set'
          end
        end

        data
      end

      def start_date
        options.start_date || (Date.today - options.days)
      end

      def end_date
        options.end_date
      end

      def cache_strategy
        cache = options.cache_enabled ? CacheFactory.enabled : CacheFactory.disabled
        cache&.clear! if options.clear_cache
        cache
      end

      def calculate_metrics(data)
        logger.info '🔢 Calculating metrics...'
        rows = []

        if options.sources.include?('linear') && data[:issues]
          calculator = Metrics::Linear::Calculator.new(
            data[:issues],
            data[:cycles],
            data[:team_members],
            data[:workflow_states]
          )
          rows.concat(calculator.calculate_all)
        end

        if options.sources.include?('github') && data[:pull_requests]
          github_rows = Metrics::Github::Calculator.new(
            data[:pull_requests],
            data[:releases],
            data[:teams]
          ).calculate_all
          rows.concat(github_rows)
        end

        rows
      end

      def write_results(rows)
        logger.info "📝 Writing #{rows.size} metrics to CSV: #{options.output}"
        DirectoryPreparer.ensure_exists(options.output)
        Data::CsvWriter.new(options.output).write_rows(rows)
        logger.info '✅ Metrics collected and saved successfully!'
      end

      def log_summary(rows)
        MetricsSummaryLogger.new(rows, logger).call
      end
    end
  end
end
