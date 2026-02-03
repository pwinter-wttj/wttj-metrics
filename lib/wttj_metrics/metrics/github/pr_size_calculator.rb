# frozen_string_literal: true

require 'date'

module WttjMetrics
  module Metrics
    module Github
      class PrSizeCalculator
        CATEGORY = 'github'
        METRICS = {
          median_additions: 'median_additions_per_pr',
          median_deletions: 'median_deletions_per_pr',
          median_changed_files: 'median_changed_files_per_pr',
          median_commits: 'median_commits_per_pr'
        }.freeze

        def initialize(pull_requests)
          @pull_requests = pull_requests
        end

        def calculate
          return {} if @pull_requests.empty?

          {
            median_additions: median_metric { |pr| pr[:additions] },
            median_deletions: median_metric { |pr| pr[:deletions] },
            median_changed_files: median_metric { |pr| pr[:changedFiles] },
            median_commits: median_metric { |pr| pr.dig(:commits, :totalCount) }
          }
        end

        def to_rows(category = CATEGORY)
          return [] if @pull_requests.empty?

          date = Date.today.to_s
          calculate.map do |metric_key, value|
            [date, category, METRICS[metric_key], value]
          end
        end

        private

        def median_metric
          values = @pull_requests.map { |pr| yield(pr) || 0 }.map(&:to_f)
          median(values).round(2)
        end

        def median(values)
          return 0.0 if values.empty?

          sorted = values.sort
          mid = sorted.length / 2
          return sorted[mid] if sorted.length.odd?

          (sorted[mid - 1] + sorted[mid]) / 2.0
        end
      end
    end
  end
end
