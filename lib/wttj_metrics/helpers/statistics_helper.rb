# frozen_string_literal: true

module WttjMetrics
  module Helpers
    # Shared statistics calculations for percentiles and summary statistics
    # Extracted to DRY up duplicate logic in percentile data builders
    module StatisticsHelper
      PERCENTILES = [50, 75, 90, 95].freeze
      PERCENTAGE_MULTIPLIER = 100

      def calculate_percentiles(values, percentiles: PERCENTILES)
        return percentiles.map { 0 } if values.empty?

        sorted = values.sort
        percentiles.map { |p| percentile_value(sorted, p) }
      end

      def percentile_value(sorted_array, percentile)
        return 0 if sorted_array.empty?

        rank = (percentile / 100.0) * (sorted_array.length - 1)
        lower = sorted_array[rank.floor]
        upper = sorted_array[rank.ceil] || lower
        weight = rank - rank.floor

        (lower + (weight * (upper - lower))).round(2)
      end

      def safe_average(values, precision: 2)
        return 0 if values.empty?

        (values.sum / values.size).round(precision)
      end

      def safe_median(values, precision: 2)
        return 0 if values.empty?

        sorted = values.sort
        mid = sorted.length / 2

        median = if sorted.length.odd?
                   sorted[mid]
                 else
                   (sorted[mid - 1] + sorted[mid]) / 2.0
                 end

        median.round(precision)
      end

      def calculate_percentage(numerator, denominator, precision: 1)
        return 0 if denominator.zero?

        ((numerator.to_f / denominator) * PERCENTAGE_MULTIPLIER).round(precision)
      end

      def build_stats(values, precision: 2)
        {
          min: values.min&.round(precision) || 0,
          max: values.max&.round(precision) || 0,
          avg: safe_median(values, precision: precision),
          count: values.size
        }
      end
    end
  end
end
