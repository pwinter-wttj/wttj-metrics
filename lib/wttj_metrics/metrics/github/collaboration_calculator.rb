# frozen_string_literal: true

require 'date'

module WttjMetrics
  module Metrics
    module Github
      class CollaborationCalculator
        CATEGORY = 'github'

        attr_reader :pull_requests

        def initialize(pull_requests)
          @pull_requests = pull_requests
        end

        def calculate
          return {} if pull_requests.empty?

          {
            median_reviews_per_pr: median_reviews_per_pr,
            median_comments_per_pr: median_comments_per_pr,
            median_rework_cycles: median_rework_cycles,
            unreviewed_pr_rate: unreviewed_pr_rate
          }
        end

        def to_rows(category = CATEGORY)
          calculate.map do |metric, value|
            [Date.today.to_s, category, metric.to_s, value]
          end
        end

        private

        def count
          @count ||= pull_requests.size
        end

        def median_reviews_per_pr
          calculate_median { |pr| pr.dig(:reviews, :totalCount) || 0 }
        end

        def median_comments_per_pr
          calculate_median { |pr| pr.dig(:comments, :totalCount) || 0 }
        end

        def median_rework_cycles
          calculate_median { |pr| count_changes_requested(pr) }
        end

        def unreviewed_pr_rate
          unreviewed = pull_requests.count { |pr| (pr.dig(:reviews, :totalCount) || 0).zero? }
          (unreviewed.to_f / count * 100).round(2)
        end

        def calculate_median(&)
          values = pull_requests.map(&).map(&:to_f)
          median(values).round(2)
        end

        def median(values)
          return 0.0 if values.empty?

          sorted = values.sort
          mid = sorted.length / 2
          return sorted[mid] if sorted.length.odd?

          (sorted[mid - 1] + sorted[mid]) / 2.0
        end

        def count_changes_requested(pull_request)
          reviews = pull_request.dig(:reviews, :nodes) || []
          reviews.count { |review| review[:state] == 'CHANGES_REQUESTED' }
        end
      end
    end
  end
end
