# frozen_string_literal: true

module WttjMetrics
  module Metrics
    module Linear
      # Calculates team performance metrics
      class TeamCalculator < Base
        include Helpers::StatisticsHelper

        DAYS_IN_MONTH = 30
        HOURS_PER_DAY = 24

        def calculate
          {
            completion_rate: completion_rate,
            median_blocked_time_hours: median_blocked_time
          }
        end

        def to_rows
          calculate.map do |metric, value|
            [today.to_s, 'team', metric.to_s, value]
          end
        end

        private

        def completion_rate
          recent = recent_issues
          return 0 if recent.empty?

          completed_count = count_completed_issues(recent)
          calculate_percentage(completed_count, recent.size, precision: 2)
        end

        def count_completed_issues(issue_collection)
          issue_collection.count { |issue| issue['completedAt'] }
        end

        def recent_issues
          @recent_issues ||= issues.select { |issue| recent_issue?(issue) }
        end

        def recent_issue?(issue)
          created = parse_datetime(issue['createdAt'])
          created >= thirty_days_ago
        end

        def thirty_days_ago
          @thirty_days_ago ||= (today - DAYS_IN_MONTH).to_datetime
        end

        def median_blocked_time
          blocked_times = collect_blocked_times
          return 0 if blocked_times.empty?

          safe_median(blocked_times, precision: 2)
        end

        def collect_blocked_times
          issues.flat_map { |issue| calculate_blocked_times(issue) }
        end

        def calculate_blocked_times(issue)
          history = sorted_history(issue)
          durations = []
          blocked_entry_time = nil

          history.each do |event|
            if entering_blocked?(event)
              blocked_entry_time = parse_datetime(event['createdAt'])
            elsif blocked_entry_time && leaving_blocked?(event)
              duration = calculate_blocked_duration(blocked_entry_time, event['createdAt'])
              durations << duration
              blocked_entry_time = nil
            end
          end

          durations
        end

        def sorted_history(issue)
          history = issue.dig('history', 'nodes') || []
          history.sort_by { |event| event['createdAt'] }
        end

        def calculate_blocked_duration(start_time, end_field)
          end_time = parse_datetime(end_field)
          (end_time - start_time) * HOURS_PER_DAY
        end

        def entering_blocked?(event)
          state_is_blocked?(event.dig('toState', 'name'))
        end

        def leaving_blocked?(event)
          state_is_blocked?(event.dig('fromState', 'name'))
        end

        def state_is_blocked?(state_name)
          state_name&.downcase&.include?('blocked')
        end
      end
    end
  end
end
