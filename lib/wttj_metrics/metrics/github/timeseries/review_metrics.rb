# frozen_string_literal: true

module WttjMetrics
  module Metrics
    module Github
      module Timeseries
        class ReviewMetrics
          include Helpers::StatisticsHelper

          def initialize
            @reviews_per_pr = []
            @comments_per_pr = []
            @rework_cycles_per_pr = []
            @time_to_first_review = []
            @count_zero_reviews = 0
            @time_to_approval = []
            @pr_count = 0
          end

          def record(pull_request)
            @pr_count += 1
            update_basic_stats(pull_request)
            update_review_stats(pull_request)
          end

          def metrics
            {
              median_reviews_per_pr: safe_median(@reviews_per_pr, precision: 2),
              median_comments_per_pr: safe_median(@comments_per_pr, precision: 2),
              median_rework_cycles: safe_median(@rework_cycles_per_pr, precision: 2),
              median_time_to_first_review_days: median_duration(@time_to_first_review, 86_400.0),
              median_time_to_approval_days: median_duration(@time_to_approval, 86_400.0),
              unreviewed_pr_rate: rate(@count_zero_reviews, @pr_count)
            }
          end

          private

          def update_basic_stats(pull_request)
            @reviews_per_pr << (fetch(pull_request, :reviews, :totalCount) || 0).to_f
            @comments_per_pr << (fetch(pull_request, :comments, :totalCount) || 0).to_f
          end

          def update_review_stats(pull_request)
            reviews = fetch(pull_request, :reviews, :nodes) || []

            calculate_rework_cycles(reviews)
            calculate_time_to_approval(pull_request, reviews)
            calculate_time_to_first_review(pull_request, reviews)
            @count_zero_reviews += 1 if reviews.empty?
          end

          def calculate_rework_cycles(reviews)
            count = reviews.count { |r| (r[:state] || r['state']) == 'CHANGES_REQUESTED' }
            @rework_cycles_per_pr << count.to_f
          end

          def calculate_time_to_approval(pull_request, reviews)
            approved = reviews.select { |r| (r[:state] || r['state']) == 'APPROVED' }
            return if approved.empty?

            first = approved.min_by { |r| r[:createdAt] || r['createdAt'] }
            pr_created_at = Time.parse(pull_request[:createdAt] || pull_request['createdAt'])
            first_approved_at = Time.parse(first[:createdAt] || first['createdAt'])
            duration = first_approved_at - pr_created_at
            @time_to_approval << duration
          end

          def calculate_time_to_first_review(pull_request, reviews)
            return if reviews.empty?

            first = reviews.min_by { |r| r[:createdAt] || r['createdAt'] }
            pr_created_at = Time.parse(pull_request[:createdAt] || pull_request['createdAt'])
            first_review_at = Time.parse(first[:createdAt] || first['createdAt'])
            duration = first_review_at - pr_created_at
            @time_to_first_review << duration
          end

          def fetch(obj, *keys)
            keys.reduce(obj) do |memo, key|
              memo.is_a?(Hash) ? (memo[key] || memo[key.to_s]) : nil
            end
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
