# frozen_string_literal: true

require 'logger'

RSpec.describe WttjMetrics::Services::MetricsSummaryLogger do
  let(:logger) { instance_double(Logger, info: nil) }

  describe '#call' do
    context 'with summary category rows' do
      subject(:summary_logger) { described_class.new(rows, logger) }

      let(:rows) do
        [
          ['2024-01-01', 'flow', 'median_cycle_time_days', '10.5'],
          ['2024-01-01', 'flow', 'median_lead_time_days', '24.3'],
          ['2024-01-01', 'cycle_metrics', 'total_cycles', '15'],
          ['2024-01-01', 'team', 'total_team_members', '25'],
          ['2024-01-01', 'issues', 'total_issues', '1500'],
          ['2024-01-01', 'issues', 'open_issues', '150']
        ]
      end

      it 'logs the summary header' do
        summary_logger.call

        expect(logger).to have_received(:info).with("\nMetrics Summary:")
      end

      it 'logs each summary row with metric name and value' do
        summary_logger.call

        expect(logger).to have_received(:info).with('  - median_cycle_time_days: 10.5')
        expect(logger).to have_received(:info).with('  - median_lead_time_days: 24.3')
        expect(logger).to have_received(:info).with('  - total_cycles: 15')
        expect(logger).to have_received(:info).with('  - total_team_members: 25')
        expect(logger).to have_received(:info).with('  - total_issues: 1500')
        expect(logger).to have_received(:info).with('  - open_issues: 150')
      end

      it 'logs exactly 7 times (header + 6 rows)' do
        summary_logger.call

        expect(logger).to have_received(:info).exactly(7).times
      end
    end

    context 'with mixed category rows' do
      subject(:summary_logger) { described_class.new(rows, logger) }

      let(:rows) do
        [
          ['2024-01-01', 'flow', 'median_cycle_time_days', '10.5'],
          ['2024-01-01', 'distribution', 'feature_count', '100'],
          ['2024-01-01', 'team', 'total_team_members', '25'],
          ['2024-01-01', 'bugs', 'total_bugs', '50'],
          ['2024-01-01', 'issues', 'total_issues', '1500']
        ]
      end

      it 'only logs rows with summary categories' do
        summary_logger.call

        expect(logger).to have_received(:info).with('  - median_cycle_time_days: 10.5')
        expect(logger).to have_received(:info).with('  - total_team_members: 25')
        expect(logger).to have_received(:info).with('  - total_issues: 1500')
      end

      it 'does not log rows with non-summary categories' do
        summary_logger.call

        expect(logger).not_to have_received(:info).with(match(/feature_count/))
        expect(logger).not_to have_received(:info).with(match(/total_bugs/))
      end
    end

    context 'with more than 6 summary items' do
      subject(:summary_logger) { described_class.new(rows, logger) }

      let(:rows) do
        [
          %w[2024-01-01 flow metric1 1],
          %w[2024-01-01 flow metric2 2],
          %w[2024-01-01 cycle_metrics metric3 3],
          %w[2024-01-01 team metric4 4],
          %w[2024-01-01 issues metric5 5],
          %w[2024-01-01 issues metric6 6],
          %w[2024-01-01 flow metric7 7],
          %w[2024-01-01 flow metric8 8]
        ]
      end

      it 'only logs the first 6 summary items' do
        summary_logger.call

        expect(logger).to have_received(:info).exactly(7).times # header + 6 items
      end

      it 'logs metrics in order and stops at 6' do
        summary_logger.call

        expect(logger).to have_received(:info).with('  - metric1: 1')
        expect(logger).to have_received(:info).with('  - metric2: 2')
        expect(logger).to have_received(:info).with('  - metric3: 3')
        expect(logger).to have_received(:info).with('  - metric4: 4')
        expect(logger).to have_received(:info).with('  - metric5: 5')
        expect(logger).to have_received(:info).with('  - metric6: 6')
        expect(logger).not_to have_received(:info).with(match(/metric7/))
        expect(logger).not_to have_received(:info).with(match(/metric8/))
      end
    end

    context 'with no summary category rows' do
      subject(:summary_logger) { described_class.new(rows, logger) }

      let(:rows) do
        [
          %w[2024-01-01 distribution feature_count 100],
          %w[2024-01-01 bugs total_bugs 50]
        ]
      end

      it 'only logs the header' do
        summary_logger.call

        expect(logger).to have_received(:info).once.with("\nMetrics Summary:")
      end
    end

    context 'with empty rows' do
      subject(:summary_logger) { described_class.new(rows, logger) }

      let(:rows) { [] }

      it 'only logs the header' do
        summary_logger.call

        expect(logger).to have_received(:info).once.with("\nMetrics Summary:")
      end
    end
  end

  describe 'constants' do
    it 'defines SUMMARY_CATEGORIES' do
      expect(described_class::SUMMARY_CATEGORIES).to eq(%w[flow cycle_metrics team issues])
    end

    it 'defines MAX_SUMMARY_ITEMS as 6' do
      expect(described_class::MAX_SUMMARY_ITEMS).to eq(6)
    end
  end
end
