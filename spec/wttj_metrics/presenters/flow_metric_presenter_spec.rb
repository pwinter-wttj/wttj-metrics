# frozen_string_literal: true

RSpec.describe WttjMetrics::Presenters::FlowMetricPresenter do
  subject(:presenter) { described_class.new(metric) }

  # Setup
  let(:metric) { { metric: metric_name, value: metric_value } }
  let(:metric_name) { 'median_cycle_time_days' }
  let(:metric_value) { 5.7 }

  it_behaves_like 'a presenter'

  describe '#label' do
    subject(:label) { presenter.label }

    context 'with cycle time metric' do
      # Setup
      let(:metric_name) { 'median_cycle_time_days' }

      it 'formats correctly' do
        # Exercise & Verify
        expect(label).to eq('Median cycle time')
      end
    end

    context 'with lead time metric' do
      # Setup
      let(:metric_name) { 'median_lead_time_days' }

      it 'formats correctly' do
        # Exercise & Verify
        expect(label).to eq('Median lead time')
      end
    end

    context 'with throughput metric' do
      # Setup
      let(:metric_name) { 'weekly_throughput' }

      it 'formats correctly' do
        # Exercise & Verify
        expect(label).to eq('Weekly throughput')
      end
    end

    context 'with WIP metric' do
      # Setup
      let(:metric_name) { 'current_wip' }

      it 'formats correctly' do
        # Exercise & Verify
        expect(label).to eq('Wip')
      end
    end
  end

  describe '#unit' do
    subject(:unit) { presenter.unit }

    context 'with time metrics' do
      # Setup
      let(:metric_name) { 'median_cycle_time_days' }

      it 'returns days' do
        # Exercise & Verify
        expect(unit).to eq(' days')
      end
    end

    context 'with throughput metric' do
      # Setup
      let(:metric_name) { 'weekly_throughput' }

      it 'returns issues' do
        # Exercise & Verify
        expect(unit).to eq(' issues')
      end
    end

    context 'with WIP metric' do
      # Setup
      let(:metric_name) { 'current_wip' }

      it 'returns issues' do
        # Exercise & Verify
        expect(unit).to eq(' issues')
      end
    end

    context 'with unknown metric' do
      let(:metric_name) { 'unknown_metric' }

      it 'returns empty string' do
        expect(unit).to eq('')
      end
    end
  end

  describe '#tooltip' do
    subject(:tooltip) { presenter.tooltip }

    context 'with cycle time metric' do
      # Setup
      let(:metric_name) { 'median_cycle_time_days' }

      it 'returns descriptive tooltip' do
        # Exercise & Verify
        expect(tooltip).to include('Median time from when work starts')
      end
    end

    context 'with lead time metric' do
      # Setup
      let(:metric_name) { 'median_lead_time_days' }

      it 'returns descriptive tooltip' do
        # Exercise & Verify
        expect(tooltip).to include('issue creation to completion')
      end
    end

    context 'with unknown metric' do
      # Setup
      let(:metric_name) { 'unknown_metric' }

      it 'returns empty string' do
        # Exercise & Verify
        expect(tooltip).to eq('')
      end
    end
  end

  describe '#display_value' do
    subject(:display_value) { presenter.display_value }

    # Setup
    let(:metric_name) { 'median_cycle_time_days' }
    let(:metric_value) { 5.7 }

    it 'includes value and unit' do
      # Exercise & Verify
      expect(display_value).to eq('5.7 days')
    end
  end
end
