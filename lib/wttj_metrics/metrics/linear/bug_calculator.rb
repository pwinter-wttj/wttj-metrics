# frozen_string_literal: true

module WttjMetrics
  module Metrics
    module Linear
      # Calculates bug-related metrics
      class BugCalculator < Base
        include Helpers::Linear::IssueHelper
        include Helpers::StatisticsHelper

        COMPLETED_STATES = %w[completed canceled].freeze
        DAYS_IN_MONTH = 30
        METRIC_MAPPINGS = {
          total_bugs: :total,
          open_bugs: :open,
          closed_bugs: :closed,
          bugs_created_last_30d: :created_last_30d,
          bugs_closed_last_30d: :closed_last_30d,
          median_bug_resolution_days: :median_resolution_days,
          bug_ratio: :bug_ratio
        }.freeze

        def calculate
          build_metrics_hash
        end

        def to_rows
          stats = calculate
          [
            *bug_metric_rows(stats),
            *priority_rows(stats[:by_priority])
          ]
        end

        private

        def build_metrics_hash
          {
            total: total_bugs,
            open: open_bugs_count,
            closed: closed_bugs_count,
            created_last_30d: bugs_created_last_30_days,
            closed_last_30d: bugs_closed_last_30_days,
            median_resolution_days: median_resolution_days,
            bug_ratio: bug_ratio,
            by_priority: bugs_by_priority
          }
        end

        def bug_metric_rows(stats)
          METRIC_MAPPINGS.map do |metric_name, stat_key|
            build_row('bugs', metric_name.to_s, stats[stat_key])
          end
        end

        def priority_rows(priorities)
          priorities.map do |priority, count|
            build_row('bugs_by_priority', priority.to_s, count)
          end
        end

        def build_row(category, metric, value)
          [today_str, category, metric, value]
        end

        def bugs
          @bugs ||= issues.select { |issue| issue_is_bug?(issue) }
        end

        def open_bugs
          @open_bugs ||= bugs.reject { |bug| issue_completed?(bug) }
        end

        def closed_bugs
          @closed_bugs ||= bugs.select { |bug| issue_completed?(bug) }
        end

        def total_bugs
          bugs.size
        end

        def open_bugs_count
          open_bugs.size
        end

        def closed_bugs_count
          closed_bugs.size
        end

        def today_str
          @today_str ||= today.to_s
        end

        def last_30_days_range
          @last_30_days_range ||= (today - DAYS_IN_MONTH)..today
        end

        def bugs_created_last_30_days
          bugs.count { |bug| date_in_range?(bug['createdAt'], last_30_days_range) }
        end

        def bugs_closed_last_30_days
          closed_bugs.count do |bug|
            date_in_range?(bug['completedAt'], last_30_days_range)
          end
        end

        def date_in_range?(date_string, range)
          return false unless date_string

          parsed_date = parse_date(date_string)
          range.cover?(parsed_date)
        end

        def median_resolution_days
          resolution_times = calculate_resolution_times
          return 0 if resolution_times.empty?

          safe_median(resolution_times, precision: 1)
        end

        def calculate_resolution_times
          closed_bugs.filter_map { |bug| resolution_time_for(bug) }
        end

        def resolution_time_for(bug)
          return unless bug['completedAt']

          created = parse_date(bug['createdAt'])
          completed = parse_date(bug['completedAt'])
          (completed - created).to_f
        end

        def bug_ratio
          return 0 if issues.empty?

          calculate_percentage(bugs.size, issues.size)
        end

        def bugs_by_priority
          open_bugs.each_with_object(Hash.new(0)) do |bug, distribution|
            priority = extract_priority_label(bug)
            distribution[priority] += 1
          end
        end
      end
    end
  end
end
