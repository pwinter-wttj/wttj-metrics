# frozen_string_literal: true

RSpec.describe WttjMetrics::Helpers::FormattingHelper do
  subject(:helper) { test_class.new }

  let(:test_class) do
    Class.new do
      include WttjMetrics::Helpers::FormattingHelper
    end
  end

  describe '#format_percentage' do
    it 'calculates percentage rounded to integer' do
      expect(helper.format_percentage(25, 100)).to eq(25)
    end

    it 'handles partial values' do
      expect(helper.format_percentage(1, 3)).to eq(33)
    end

    it 'returns 0 when total is zero' do
      expect(helper.format_percentage(10, 0)).to eq(0)
    end
  end

  describe '#format_with_unit' do
    it 'appends unit to value' do
      expect(helper.format_with_unit(42, '%')).to eq('42%')
    end

    it 'handles empty unit' do
      expect(helper.format_with_unit(42, '')).to eq('42')
    end
  end

  describe '#humanize_metric_name' do
    it 'replaces underscores with spaces' do
      expect(helper.humanize_metric_name('median_cycle_time')).to eq('Median cycle time')
    end

    it 'capitalizes the first letter' do
      expect(helper.humanize_metric_name('throughput')).to eq('Throughput')
    end

    it 'handles symbols' do
      expect(helper.humanize_metric_name(:metric_name)).to eq('Metric name')
    end
  end

  describe '#format_count_display' do
    it 'formats as completed/total' do
      expect(helper.format_count_display(5, 10)).to eq('5/10')
    end
  end

  describe '#format_points_display' do
    it 'appends pts suffix' do
      expect(helper.format_points_display(42)).to eq('42 pts')
    end
  end
end
