# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WttjMetrics::Presenters::CycleMetricPresenter do
  subject(:presenter) { described_class.new(metric) }

  let(:metric) { { metric: metric_name, value: metric_value } }
  let(:metric_name) { 'median_cycle_velocity' }
  let(:metric_value) { 42 }

  it_behaves_like 'a presenter'

  describe '#label' do
    subject(:label) { presenter.label }

    context 'with median_cycle_velocity' do
      let(:metric_name) { 'median_cycle_velocity' }

      it 'uses Median prefix' do
        expect(label).to eq('Median velocity')
      end
    end

    context 'with cycle_commitment_accuracy' do
      let(:metric_name) { 'cycle_commitment_accuracy' }

      it 'removes cycle prefix' do
        expect(label).to eq('Commitment accuracy')
      end
    end

    context 'with cycle_carryover_count' do
      let(:metric_name) { 'cycle_carryover_count' }

      it 'removes cycle prefix' do
        expect(label).to eq('Carryover count')
      end
    end
  end

  describe '#tooltip' do
    subject(:tooltip) { presenter.tooltip }

    context 'with median_cycle_velocity' do
      let(:metric_name) { 'median_cycle_velocity' }

      it 'returns the tooltip' do
        expect(tooltip).to eq('Median story points completed per cycle across completed cycles (excluding zero-velocity cycles).')
      end
    end

    context 'with cycle_commitment_accuracy' do
      let(:metric_name) { 'cycle_commitment_accuracy' }

      it 'returns the tooltip' do
        expect(tooltip).to eq('Median percentage of planned work completed across all completed cycles.')
      end
    end

    context 'with cycle_carryover_count' do
      let(:metric_name) { 'cycle_carryover_count' }

      it 'returns the tooltip' do
        expect(tooltip).to eq('Median number of issues carried over per completed cycle.')
      end
    end

    context 'with unknown metric' do
      let(:metric_name) { 'unknown_metric' }

      it 'returns empty string' do
        expect(tooltip).to eq('')
      end
    end
  end

  describe '#unit' do
    subject(:unit) { presenter.unit }

    context 'with accuracy metric' do
      let(:metric_name) { 'cycle_commitment_accuracy' }

      it 'returns percentage unit' do
        expect(unit).to eq('%')
      end
    end

    context 'with velocity metric' do
      let(:metric_name) { 'median_cycle_velocity' }

      it 'returns empty string' do
        expect(unit).to eq('')
      end
    end

    context 'with carryover metric' do
      let(:metric_name) { 'cycle_carryover_count' }

      it 'returns empty string' do
        expect(unit).to eq('')
      end
    end
  end
end
