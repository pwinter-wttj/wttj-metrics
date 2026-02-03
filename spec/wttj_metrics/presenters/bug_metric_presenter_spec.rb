# frozen_string_literal: true

RSpec.describe WttjMetrics::Presenters::BugMetricPresenter do
  subject(:presenter) { described_class.new(metric) }

  let(:metric) { { metric: name, value: value } }
  let(:value) { 42.5 }

  describe '#label' do
    context 'with total_bugs metric' do
      let(:name) { 'total_bugs' }

      it 'formats the label removing redundant bug words' do
        expect(presenter.label).to eq('Total bugs')
      end
    end

    context 'with open_bugs metric' do
      let(:name) { 'open_bugs' }

      it 'removes bugs prefix' do
        expect(presenter.label).to eq('Open bugs')
      end
    end

    context 'with median_bug_resolution_days metric' do
      let(:name) { 'median_bug_resolution_days' }

      it 'uses Median prefix' do
        expect(presenter.label).to eq('Median resolution days')
      end
    end

    context 'with bug_ratio metric' do
      let(:name) { 'bug_ratio' }

      it 'returns custom label' do
        expect(presenter.label).to eq('Issues are bugs')
      end
    end
  end

  describe '#tooltip' do
    context 'with known metric' do
      let(:name) { 'total_bugs' }

      it 'returns the tooltip text' do
        expect(presenter.tooltip).to eq('Total number of issues labeled as bugs.')
      end
    end

    context 'with median_bug_resolution_days' do
      let(:name) { 'median_bug_resolution_days' }

      it 'returns the tooltip' do
        expect(presenter.tooltip).to eq('Median time to resolve a bug.')
      end
    end

    context 'with unknown metric' do
      let(:name) { 'unknown_metric' }

      it 'returns empty string' do
        expect(presenter.tooltip).to eq('')
      end
    end
  end

  describe '#unit' do
    context 'with median_bug_resolution_days' do
      let(:name) { 'median_bug_resolution_days' }

      it 'returns days unit' do
        expect(presenter.unit).to eq(' days')
      end
    end

    context 'with bug_ratio' do
      let(:name) { 'bug_ratio' }

      it 'returns percentage unit' do
        expect(presenter.unit).to eq('%')
      end
    end

    context 'with other metrics' do
      let(:name) { 'total_bugs' }

      it 'returns empty string' do
        expect(presenter.unit).to eq('')
      end
    end
  end

  describe '#value' do
    context 'with bug_ratio metric' do
      let(:name) { 'bug_ratio' }
      let(:value) { 42.678 }

      it 'rounds to 1 decimal place' do
        expect(presenter.value).to eq(42.7)
      end
    end

    context 'with other metrics' do
      let(:name) { 'total_bugs' }
      let(:value) { 42.9 }

      it 'converts to integer' do
        expect(presenter.value).to eq(42)
      end
    end
  end
end
