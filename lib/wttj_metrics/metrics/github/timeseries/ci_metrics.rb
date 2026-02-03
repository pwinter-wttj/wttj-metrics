# frozen_string_literal: true

module WttjMetrics
  module Metrics
    module Github
      module Timeseries
        class CiMetrics
          include Helpers::StatisticsHelper

          def initialize
            @count_ci_success = 0
            @pr_count = 0
            @time_to_green = []
          end

          def record(pull_request)
            @pr_count += 1
            update_ci_success(pull_request)
            update_time_to_green(pull_request)
          end

          def metrics
            {
              ci_success_rate: rate(@count_ci_success, @pr_count),
              median_time_to_green_hours: median_duration(@time_to_green, 3600.0)
            }
          end

          private

          def update_ci_success(pull_request)
            last_commit = fetch_last_commit(pull_request)
            return unless last_commit

            status = last_commit.dig(:statusCheckRollup, :state) || last_commit.dig('statusCheckRollup', 'state')
            @count_ci_success += 1 if status == 'SUCCESS'
          end

          def update_time_to_green(pull_request)
            return unless (pull_request[:state] || pull_request['state']) == 'MERGED'

            last_commit = fetch_last_commit(pull_request)
            return unless last_commit

            suites = last_commit.dig(:checkSuites, :nodes) || last_commit.dig('checkSuites', 'nodes')
            return unless suites

            success_suite = suites.select { |cs| (cs[:conclusion] || cs['conclusion']) == 'SUCCESS' }
                                  .max_by { |cs| cs[:updatedAt] || cs['updatedAt'] }
            return unless success_suite

            committed_at = Time.parse(last_commit[:committedDate] || last_commit['committedDate'])
            suite_at = Time.parse(success_suite[:updatedAt] || success_suite['updatedAt'])
            @time_to_green << (suite_at - committed_at)
          end

          def fetch_last_commit(pull_request)
            pull_request.dig(:lastCommit, :nodes)&.first&.dig(:commit) ||
              pull_request.dig('lastCommit', 'nodes')&.first&.dig('commit')
          end

          def median_duration(values, divisor)
            return 0.0 if values.empty?

            (safe_median(values, precision: 2) / divisor).round(2)
          end

          def rate(numerator, denominator)
            return 0.0 unless denominator&.positive?

            ((numerator.to_f / denominator) * 100).round(2)
          end
        end
      end
    end
  end
end
