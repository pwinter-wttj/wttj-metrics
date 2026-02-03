# frozen_string_literal: true

require 'axlsx'

module WttjMetrics
  module Reports
    module Linear
      # Builds Excel reports from metrics data
      # Single Responsibility: Excel file generation
      class ExcelReportBuilder
        def initialize(report_data)
          @data = report_data
          @package = Axlsx::Package.new
          @workbook = @package.workbook
          @header_style = create_header_style
          @formatter = ExcelFormatter.new
        end

        def build(output_path)
          add_key_metrics_sheet
          add_bug_tracking_sheet
          add_distribution_sheet
          add_team_comparison_sheet
          add_cycles_sheet
          add_ticket_flow_sheet
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
            add_title_row(sheet, "Linear Metrics Report - #{@data[:today]}", columns: 3)
            sheet.add_row %w[Metric Value Description], style: @header_style

            add_metrics_rows(sheet, @data[:flow_metrics], :flow)
            add_metrics_rows(sheet, @data[:cycle_metrics], :cycle)
            add_metrics_rows(sheet, @data[:team_metrics], :team)

            sheet.column_widths 35, 15, 45
          end
        end

        def add_bug_tracking_sheet
          @workbook.add_worksheet(name: 'Bug Tracking') do |sheet|
            add_title_row(sheet, 'Bug Tracking Overview', columns: 3)
            sheet.add_row %w[Metric Value Description], style: @header_style

            @data[:bug_metrics].each do |m|
              sheet.add_row @formatter.format_bug_row(m)
            end

            sheet.add_row []
            sheet.add_row ['Bugs by Priority'], style: @header_style
            sheet.add_row %w[Priority Count], style: @header_style

            priority_order = %w[Urgent High Medium Low]
            sorted_bugs = @data[:bugs_by_priority].sort_by do |m|
              priority_order.index(m[:metric]) || 99
            end
            sorted_bugs.each { |m| sheet.add_row [m[:metric], m[:value].to_i] }

            sheet.column_widths 35, 15, 45
          end
        end

        def add_distribution_sheet
          @workbook.add_worksheet(name: 'Distribution') do |sheet|
            add_title_row(sheet, 'Current Distribution', columns: 2)

            add_section(sheet, 'Status Distribution', %w[Status Count]) do
              @data[:status_chart_data].map { |d| [d[:label], d[:value]] }
            end

            add_section(sheet, 'Priority Distribution', %w[Priority Count]) do
              priority_order = %w[Urgent High Medium Low]
              @data[:priority_dist]
                .sort_by { |m| priority_order.index(m[:metric]) || 99 }
                .map { |m| [m[:metric], m[:value].to_i] }
            end

            add_section(sheet, 'Issue Type Distribution', %w[Type Count]) do
              @data[:type_dist].map { |m| [m[:metric], m[:value].to_i] }
            end

            add_section(sheet, 'Top Assignees (WIP)', ['Assignee', 'Active Issues']) do
              @data[:assignee_dist].map { |m| [m[:metric], m[:value].to_i] }
            end

            sheet.column_widths 30, 15
          end
        end

        def add_team_comparison_sheet
          @workbook.add_worksheet(name: 'Team Comparison') do |sheet|
            add_title_row(sheet, 'Team Comparison', columns: 6)
            headers = ['Team', 'Cycles (with data)', 'Median Velocity (pts)',
                       'Median Tickets/Cycle', 'Median Completion Rate (%)', 'Median Scope Change (%)']
            sheet.add_row headers, style: @header_style

            @data[:team_stats].each do |team, stats|
              sheet.add_row [
                team,
                "#{stats[:cycles_with_data]}/#{stats[:total_cycles]}",
                stats[:median_velocity],
                stats[:median_tickets_per_cycle],
                stats[:median_completion_rate].round(1),
                stats[:median_scope_change].round(1)
              ]
            end

            sheet.column_widths 20, 18, 18, 18, 22, 20
          end
        end

        def add_cycles_sheet
          @workbook.add_worksheet(name: 'Cycles by Team') do |sheet|
            add_title_row(sheet, 'Cycles by Team', columns: 9)

            @data[:cycles_by_team].each do |team, cycles|
              sheet.add_row [team], style: @header_style
              headers = ['Cycle', 'Status', 'Progress (%)', 'Issues (Done/Total)',
                         'Velocity (pts)', 'Assignees', 'Tickets/Day', 'Carryover', 'Scope Change (%)']
              sheet.add_row headers, style: @header_style

              cycles.each { |c| sheet.add_row @formatter.format_cycle_row(c) }
              sheet.add_row []
            end

            sheet.column_widths 40, 12, 12, 18, 14, 12, 14, 12, 16
          end
        end

        def add_ticket_flow_sheet
          @workbook.add_worksheet(name: 'Ticket Flow') do |sheet|
            add_title_row(sheet, "Ticket Flow (Last #{@data[:days_to_show]} Days)", columns: 3)
            sheet.add_row %w[Week Created Completed], style: @header_style

            flow = @data[:weekly_flow_data]
            flow[:labels].each_with_index do |week, i|
              sheet.add_row [week, flow[:created_raw][i], flow[:completed_raw][i]]
            end

            sheet.column_widths 15, 12, 12
          end
        end

        def add_raw_data_sheet
          @workbook.add_worksheet(name: 'Raw Data') do |sheet|
            add_title_row(sheet, 'Raw Metrics Data', columns: 4)
            sheet.add_row %w[Date Category Metric Value], style: @header_style

            @data[:raw_data].each do |row|
              sheet.add_row [row['date'], row['category'], row['metric'], row['value']]
            end

            sheet.column_widths 12, 20, 40, 30
          end
        end

        # Helper methods

        def add_title_row(sheet, title, columns:)
          sheet.add_row [title], style: @header_style
          sheet.merge_cells("A1:#{('A'.ord + columns - 1).chr}1")
          sheet.add_row []
        end

        def add_section(sheet, title, headers)
          sheet.add_row []
          sheet.add_row [title], style: @header_style
          sheet.add_row headers, style: @header_style
          yield.each { |row| sheet.add_row row }
        end

        def add_metrics_rows(sheet, metrics, _type)
          metrics.each do |m|
            label = m[:metric].tr('_', ' ').capitalize
            value = @formatter.format_metric_value(m[:metric], m[:value])
            sheet.add_row [label, value, @formatter.description_for(m[:metric])]
          end
        end
      end
    end
  end
end
