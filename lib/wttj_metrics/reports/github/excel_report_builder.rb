# frozen_string_literal: true

require 'axlsx'

module WttjMetrics
  module Reports
    module Github
      # Builds Excel reports from GitHub metrics data
      class ExcelReportBuilder
        KEY_METRICS_CONFIG = [
          { label: 'Median Time to Merge', key: :median_time_to_merge, unit: 'days' },
          { label: 'Total Merged PRs', key: :total_merged, unit: '' },
          { label: 'Median Reviews/PR', key: :median_reviews, unit: '' },
          { label: 'Median Comments/PR', key: :median_comments, unit: '' },
          { label: 'Median Time to First Review', key: :median_time_to_first_review, unit: 'days' },
          { label: 'Merge Rate', key: :merge_rate, unit: '%' },
          { label: 'Median Time to Approval', key: :median_time_to_approval, unit: 'days' },
          { label: 'Rework Cycles', key: :median_rework_cycles, unit: '' },
          { label: 'CI Success Rate', key: :ci_success_rate, unit: '%' },
          { label: 'Daily Deploys', key: :deploy_frequency_daily, unit: '' },
          { label: 'Median Additions/PR', key: :median_additions, unit: 'lines' },
          { label: 'Median Deletions/PR', key: :median_deletions, unit: 'lines' },
          { label: 'Median Changed Files/PR', key: :median_changed_files, unit: '' },
          { label: 'Median Commits/PR', key: :median_commits, unit: '' }
        ].freeze

        DAILY_BREAKDOWN_HEADERS = %w[Date Merged Closed Open Median_Merge_Time(h) Median_Reviews Median_Comments Median_Additions
                                     Median_Deletions Median_Time_To_First_Review(h)].freeze

        DAILY_DATASET_KEYS = %i[merged closed open median_time_to_merge median_reviews median_comments median_additions
              median_deletions median_time_to_first_review].freeze

        def initialize(data)
          @data = data
          @package = Axlsx::Package.new
          @workbook = @package.workbook
          @header_style = create_header_style
        end

        def build(output_path)
          add_key_metrics_sheet
          add_daily_breakdown_sheet
          add_top_repositories_sheet
          add_raw_data_sheet

          @package.serialize(output_path)
        end

        private

        def create_header_style
          @workbook.styles.add_style(
            bg_color: '2D3748',
            fg_color: 'FFFFFF',
            b: true,
            alignment: { horizontal: :center },
            border: { style: :thin, color: '4A5568' }
          )
        end

        def add_key_metrics_sheet
          @workbook.add_worksheet(name: 'Key Metrics') do |sheet|
            setup_key_metrics_header(sheet)
            add_key_metrics_rows(sheet)
            sheet.column_widths 30, 20
          end
        end

        def setup_key_metrics_header(sheet)
          sheet.add_row ["GitHub Metrics Report - #{@data[:today]}"], style: @header_style
          sheet.merge_cells('A1:B1')
          sheet.add_row []
          sheet.add_row %w[Metric Value], style: @header_style
        end

        def add_key_metrics_rows(sheet)
          metrics = @data[:metrics]
          KEY_METRICS_CONFIG.each do |config|
            add_metric_row(sheet, config[:label], metrics[config[:key]], config[:unit])
          end
        end

        def add_metric_row(sheet, label, value, unit)
          sheet.add_row [label, format_metric_value(value, unit)]
        end

        def format_metric_value(value, unit)
          formatted_num = value.is_a?(Float) ? value.round(1) : value.to_i
          unit_suffix = unit.to_s.empty? ? '' : " #{unit}"
          "#{formatted_num}#{unit_suffix}"
        end

        def add_daily_breakdown_sheet
          @workbook.add_worksheet(name: 'Daily Breakdown') do |sheet|
            sheet.add_row DAILY_BREAKDOWN_HEADERS, style: @header_style
            add_daily_rows(sheet)
          end
        end

        def add_daily_rows(sheet)
          daily = @data[:daily_breakdown]
          daily[:labels].each_with_index do |date, index|
            row_values = [date] + DAILY_DATASET_KEYS.map { |key| daily[:datasets][key][index] }
            sheet.add_row row_values
          end
        end

        def add_top_repositories_sheet
          return unless @data[:top_repositories]&.any?

          @workbook.add_worksheet(name: 'Top 10 Repositories') do |sheet|
            sheet.add_row %w[Repository PRs], style: @header_style
            @data[:top_repositories].each do |repo|
              sheet.add_row [repo[:metric], repo[:value]]
            end
          end
        end

        def add_raw_data_sheet
          @workbook.add_worksheet(name: 'Raw Data') do |sheet|
            sheet.add_row %w[Date Category Metric Value], style: @header_style
            @data[:raw_data].each do |row|
              sheet.add_row [row['date'], row['category'], row['metric'], row['value']]
            end
          end
        end
      end
    end
  end
end
