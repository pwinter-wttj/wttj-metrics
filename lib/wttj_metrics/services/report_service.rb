# frozen_string_literal: true

module WttjMetrics
  module Services
    # Orchestrates report generation from CSV metrics
    class ReportService
      def initialize(csv_file, options, logger)
        @csv_file = csv_file
        @options = options
        @logger = logger
      end

      def call
        validate_csv_exists!
        prepare_directories
        generate_html_report
        generate_excel_report if options.excel_enabled
      end

      private

      attr_reader :csv_file, :options, :logger

      def validate_csv_exists!
        return if File.exist?(csv_file)

        raise Error, "CSV file not found: #{csv_file}"
      end

      def prepare_directories
        DirectoryPreparer.ensure_exists(options.output)
        DirectoryPreparer.ensure_exists(options.excel_path) if options.excel_enabled
      end

      def generate_html_report
        generator.generate_html(options.output)
      end

      def generate_excel_report
        generator.generate_excel(options.excel_path)
      end

      def generator
        @generator ||= case report_source
                       when 'github'
                         Reports::Github::ReportGenerator.new(
                           csv_file,
                           days: options.days,
                           teams: options.teams,
                           teams_config: teams_config,
                           start_date: options.start_date,
                           end_date: options.end_date
                         )
                       else
                         Reports::Linear::ReportGenerator.new(
                           csv_file,
                           days: options.days,
                           teams: options.teams,
                           teams_config: teams_config,
                           start_date: options.start_date,
                           end_date: options.end_date
                         )
                       end
      end

      def report_source
        return options.source if options.respond_to?(:source) && options.source

        csv_file.include?('github') ? 'github' : 'linear'
      end

      def teams_config
        return nil if options.teams == :all
        return nil unless options.teams_config && File.exist?(options.teams_config)

        Values::TeamConfiguration.new(options.teams_config)
      end
    end
  end
end
