# frozen_string_literal: true

require 'erb'
require 'date'
require 'json'
require_relative 'percentile_data_builder'

module WttjMetrics
  module Reports
    module Github
      class ReportGenerator
        include Helpers::FormattingHelper

        METRIC_MAPPING = {
          median_time_to_merge: 'median_time_to_merge_days',
          total_merged: 'total_merged_prs',
          median_reviews: 'median_reviews_per_pr',
          median_comments: 'median_comments_per_pr',
          median_time_to_first_review: 'median_time_to_first_review_days',
          median_additions: 'median_additions_per_pr',
          median_deletions: 'median_deletions_per_pr',
          median_changed_files: 'median_changed_files_per_pr',
          median_commits: 'median_commits_per_pr',
          merge_rate: 'merge_rate',
          median_time_to_approval: 'median_time_to_approval_days',
          median_rework_cycles: 'median_rework_cycles',
          unreviewed_pr_rate: 'unreviewed_pr_rate',
          ci_success_rate: 'ci_success_rate',
          deploy_frequency: 'deploy_frequency_weekly',
          hotfix_rate: 'hotfix_rate',
          time_to_green: 'time_to_green_hours'
        }.freeze

        DAILY_METRIC_MAPPING = {
          merged: 'merged', closed: 'closed', open: 'open',
          median_time_to_merge: 'median_time_to_merge_hours',
          median_reviews: 'median_reviews_per_pr',
          median_comments: 'median_comments_per_pr',
          median_additions: 'median_additions_per_pr',
          median_deletions: 'median_deletions_per_pr',
          median_time_to_first_review: 'median_time_to_first_review_days',
          merge_rate: 'merge_rate',
          median_time_to_approval: 'median_time_to_approval_days',
          median_rework_cycles: 'median_rework_cycles',
          unreviewed_pr_rate: 'unreviewed_pr_rate',
          ci_success_rate: 'ci_success_rate',
          deploy_frequency: 'releases_count',
          hotfix_rate: 'hotfix_rate',
          time_to_green: 'median_time_to_green_hours'
        }.freeze

        attr_reader :data, :days_to_show, :today, :start_date, :end_date

        # :reek:LongParameterList { max_params: 6 }
        def initialize(csv_path, days: 90, teams: nil, teams_config: nil, start_date: nil, end_date: nil)
          @csv_path = csv_path
          @days_to_show = days
          @start_date = start_date
          @end_date = end_date || Date.today
          @teams = teams
          @teams_config = teams_config
          @today = @end_date.to_s
          @parser = Data::CsvParser.new(csv_path)
          @data = @parser.data
        end

        def selected_teams
          return @teams_config.defined_teams if @teams_config

          @teams || []
        end

        def all_teams_mode
          @teams == :all || (@teams.nil? && @teams_config.nil?)
        end

        def team_mapping_display
          return selected_teams.map { |team| "• #{team}" }.join('<br>') unless @teams_config

          @teams_config.defined_teams.map do |unified_name|
            patterns = @teams_config.patterns_for(unified_name, :github)
            "• #{unified_name} (#{patterns.join(', ')})"
          end.join('<br>')
        end

        def generate_html(output_path)
          HtmlReportBuilder.new(self).build(output_path)
        end

        def template_binding
          binding
        end

        def generate_excel(output_path)
          builder = ExcelReportBuilder.new(excel_report_data)
          builder.build(output_path)
          puts "✅ Excel report generated: #{output_path}"
        end

        def metrics
          @metrics ||= begin
            calculator = MetricsCalculator.new(metrics_data('github'))
            METRIC_MAPPING.transform_values { |name| calculator.latest(name) }
                          .merge(deploy_frequency_daily: calculate_daily_deploy_frequency)
          end
        end

        def history
          @history ||= begin
            calculator = MetricsCalculator.new(metrics_data('github'))
            METRIC_MAPPING.transform_values { |name| calculator.history(name) }
          end
        end

        def daily_breakdown
          @daily_breakdown ||= begin
            grouped_data = group_daily_data
            sorted_dates = grouped_data.keys.sort
            datasets = build_datasets(grouped_data, sorted_dates)

            { labels: sorted_dates, datasets: datasets }
          end
        end

        def weekly_breakdown
          @weekly_breakdown ||= begin
            daily_data = @parser.metrics_by_category['github_daily'] || []
            WeeklyAggregator.new(daily_data).aggregate
          end
        end

        def percentile_data
          @percentile_data ||= PercentileDataBuilder.new(@parser, cutoff_date: cutoff_date).all_percentile_data
        end

        def team_metrics_warning
          team_metrics
          @team_metrics_warning
        end

        def team_metrics
          @team_metrics ||= begin
            teams = TeamService.new(@parser, @teams_config).resolve_teams

            if teams.empty?
              @team_metrics_warning = if @teams_config
                                       'No GitHub team metrics found in the CSV. Re-run `collect` with a `GITHUB_TOKEN` that can read org teams (or after teams have been cached) to populate per-team GitHub metrics.'
                                     end
              {}
            else
              teams.each_with_object({}) do |team_name, hash|
                category = "github:#{team_name}"
                calculator = MetricsCalculator.new(metrics_data(category))

                hash[team_name] = {
                  metrics: METRIC_MAPPING.transform_values { |name| calculator.latest_or_nil(name) },
                  history: METRIC_MAPPING.transform_values { |name| calculator.history(name) },
                  daily_breakdown: daily_breakdown_for(team_name)
                }
              end
            end
          end
        end

        def commit_activity
          @commit_activity ||= begin
            data = @parser.metrics_by_category['github_commit_activity'] || []
            grid = Array.new(7) { Array.new(24) { { count: 0, authors: {} } } }

            data.each do |row|
              # row[:metric] is "wday_hour" (e.g. "1_14")
              wday, hour = row[:metric].split('_').map(&:to_i)

              # wday: 0=Sunday, 1=Monday...
              # We want Monday=0 for display, so (wday - 1) % 7
              display_wday = (wday - 1) % 7
              hour = hour.to_i

              # Parse JSON value if it's a string, otherwise handle legacy integer
              begin
                parsed_value = if row[:value].is_a?(String)
                                 JSON.parse(row[:value])
                               else
                                 { 'count' => row[:value].to_i,
                                   'authors' => {} }
                               end
              rescue JSON::ParserError
                parsed_value = { 'count' => row[:value].to_i, 'authors' => {} }
              end

              # Ensure we have a hash structure
              parsed_value = { 'count' => parsed_value.to_i, 'authors' => {} } if parsed_value.is_a?(Numeric)

              grid[display_wday][hour][:count] += parsed_value['count'].to_i

              next unless parsed_value['authors']

              parsed_value['authors'].each do |author, count|
                grid[display_wday][hour][:authors][author] ||= 0
                grid[display_wday][hour][:authors][author] += count
              end
            end
            grid
          end
        end

        private

        def excel_report_data
          {
            today: @today,
            metrics: metrics,
            daily_breakdown: daily_breakdown,
            top_repositories: top_repositories,
            top_contributors: top_contributors,
            raw_data: @parser.data
          }
        end

        def top_repositories
          top_metrics_for('github_repo_activity')
        end

        def top_contributors
          top_metrics_for('github_contributor_activity')
        end

        def group_daily_data
          (@parser.metrics_by_category['github_daily'] || []).group_by { |m| m[:date] }
        end

        def daily_breakdown_for(team_name)
          category = "github:#{team_name}_daily"
          grouped_data = (@parser.metrics_by_category[category] || []).group_by { |m| m[:date] }
          sorted_dates = grouped_data.keys.sort
          datasets = build_datasets(grouped_data, sorted_dates)

          { labels: sorted_dates, datasets: datasets }
        end

        def build_datasets(grouped_data, dates)
          datasets = Hash.new { |h, k| h[k] = [] }
          dates.each do |date|
            metrics = grouped_data[date]
            DAILY_METRIC_MAPPING.each do |key, metric_name|
              datasets[key] << get_value(metrics, metric_name)
            end
          end
          datasets
        end

        def top_metrics_for(category)
          metrics = filter_and_group_metrics(category)
          aggregate_and_sort_metrics(metrics)
        end

        def filter_and_group_metrics(category)
          (@parser.metrics_by_category[category] || [])
            .select { |m| m[:date] >= cutoff_date }
            .group_by { |m| m[:metric] }
        end

        def aggregate_and_sort_metrics(grouped_metrics)
          aggregated = grouped_metrics.map do |name, metrics|
            { metric: name, value: metrics.sum { |m| m[:value] }, date: @today }
          end

          aggregated.sort_by { |m| -m[:value] }.first(10)
        end

        def get_value(metrics, name)
          metrics&.find { |m| m[:metric] == name }&.dig(:value) || 0
        end

        def metrics_data(category = 'github')
          @parser.metrics_by_category[category] || []
        end

        def cutoff_date
          @cutoff_date ||= if @start_date
                             @start_date.to_s
                           else
                             (@end_date - @days_to_show).to_s
                           end
        end

        def calculate_daily_deploy_frequency
          calculator = MetricsCalculator.new(metrics_data('github'))
          daily = calculator.latest('deploy_frequency_daily')
          return daily if daily.nonzero?

          (calculator.latest('deploy_frequency_weekly') / 7.0).round(2)
        end
      end
    end
  end
end
