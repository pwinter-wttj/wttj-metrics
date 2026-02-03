# frozen_string_literal: true

RSpec.describe WttjMetrics::Presenters::BasePresenter do
  subject(:presenter) { described_class.new(metric) }

  # Setup
  let(:metric) { { metric: 'test_metric', value: 42.7 } }

  it_behaves_like 'a presenter'

  describe '#name' do
    subject(:name) { presenter.name }

    it 'returns the metric name' do
      # Exercise & Verify
      expect(name).to eq('test_metric')
    end
  end

  describe '#raw_value' do
    subject(:raw_value) { presenter.raw_value }

    it 'returns the original value' do
      # Exercise & Verify
      expect(raw_value).to eq(42.7)
    end
  end

  describe '#value' do
    subject(:value) { presenter.value }

    it 'returns a formatted numeric value' do
      # Exercise & Verify
      expect(value).to eq(42.7)
    end
  end

  describe '#label' do
    subject(:label) { presenter.label }

    context 'with single underscore' do
      # Setup
      let(:metric) { { metric: 'test_metric', value: 10 } }

      it 'formats the metric name as a human-readable label' do
        # Exercise & Verify
        expect(label).to eq('Test metric')
      end
    end

    context 'with multiple underscores' do
      # Setup
      let(:metric) { { metric: 'median_cycle_time', value: 10 } }

      it 'replaces all underscores with spaces' do
        # Exercise & Verify
        expect(label).to eq('Median cycle time')
      end
    end
  end

  describe '#display_value' do
    subject(:display_value) { presenter.display_value }

    it 'returns the value with unit' do
      # Exercise & Verify
      expect(display_value).to eq('42.7')
    end
  end

  describe '#to_h' do
    subject(:hash) { presenter.to_h }

    it 'returns a hash with all presentation data' do
      # Exercise & Verify
      expect(hash).to include(
        label: 'Test metric',
        value: 42.7,
        display_value: '42.7',
        tooltip: '',
        unit: ''
      )
    end
  end
end
