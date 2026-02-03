# frozen_string_literal: true

module WttjMetrics
  module Metrics
    module Github
      module Timeseries
        class PrActivityMetrics
          include Helpers::StatisticsHelper

          attr_reader :created, :merged, :closed, :open

          def initialize
            @created = 0
            @merged = 0
            @closed = 0
            @open = 0
            @merge_times_hours = []
          end

          def record(pull_request)
            @created += 1
            update_state(pull_request)
          end

          def metrics
            {
              created: @created,
              merged: @merged,
              closed: @closed,
              open: @open,
              median_time_to_merge_hours: safe_median(@merge_times_hours, precision: 2)
            }
          end

          private

          def update_state(pull_request)
            state = pull_request[:state] || pull_request['state']
            case state
            when 'MERGED'
              handle_merged(pull_request)
            when 'CLOSED'
              @closed += 1
            when 'OPEN'
              @open += 1
            end
          end

          def handle_merged(pull_request)
            @merged += 1
            merged_at = pull_request[:mergedAt] || pull_request['mergedAt']
            created_at = pull_request[:createdAt] || pull_request['createdAt']
            return unless merged_at

            @merge_times_hours << ((Time.parse(merged_at) - Time.parse(created_at)) / 3600.0)
          end
        end
      end
    end
  end
end
