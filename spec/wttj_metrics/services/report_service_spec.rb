# frozen_string_literal: true

require 'logger'

RSpec.describe WttjMetrics::Services::ReportService do
  let(:logger) { instance_double(Logger, info: nil) }
  let(:csv_file) { 'tmp/metrics.csv' }
  let(:options) do
    double(
      'Options',
      output: 'tmp/report.html',
      excel_enabled: false,
      excel_path: 'tmp/report.xlsx',
      days: 90,
      teams: %w[ATS Platform],
      teams_config: nil,
      start_date: nil,
      end_date: nil,
      source: nil
    )
  end

  let(:report_generator) do
    instance_double(
      WttjMetrics::Reports::Linear::ReportGenerator,
      generate_html: nil,
      generate_excel: nil
    )
  end

  let(:github_report_generator) do
    instance_double(
      WttjMetrics::Reports::Github::ReportGenerator,
      generate_html: nil,
      generate_excel: nil
    )
  end

  before do
    allow(File).to receive(:exist?).with(csv_file).and_return(true)
    allow(WttjMetrics::Services::DirectoryPreparer).to receive(:ensure_exists)
    allow(WttjMetrics::Reports::Linear::ReportGenerator).to receive(:new).and_return(report_generator)
    allow(WttjMetrics::Reports::Github::ReportGenerator).to receive(:new).and_return(github_report_generator)
  end

  describe '#call' do
    subject(:report_service) { described_class.new(csv_file, options, logger) }

    it 'validates that CSV file exists' do
      report_service.call

      expect(File).to have_received(:exist?).with(csv_file)
    end

    it 'prepares directories for output file' do
      report_service.call

      expect(WttjMetrics::Services::DirectoryPreparer)
        .to have_received(:ensure_exists)
        .with('tmp/report.html')
    end

    it 'creates a ReportGenerator with CSV file and options' do
      report_service.call

      expect(WttjMetrics::Reports::Linear::ReportGenerator).to have_received(:new).with(
        csv_file,
        days: 90,
        teams: %w[ATS Platform],
        teams_config: nil,
        start_date: nil,
        end_date: nil
      )
    end

    context 'when options specify github source' do
      let(:options) do
        double(
          'Options',
          output: 'tmp/report.html',
          excel_enabled: false,
          excel_path: 'tmp/report.xlsx',
          days: 90,
          teams: %w[ATS Platform],
          teams_config: nil,
          start_date: nil,
          end_date: nil,
          source: 'github'
        )
      end

      it 'creates a Github::ReportGenerator with CSV file and options' do
        report_service.call

        expect(WttjMetrics::Reports::Github::ReportGenerator).to have_received(:new).with(
          csv_file,
          days: 90,
          teams: %w[ATS Platform],
          teams_config: nil,
          start_date: nil,
          end_date: nil
        )
      end
    end

    it 'generates HTML report' do
      report_service.call

      expect(report_generator).to have_received(:generate_html).with('tmp/report.html')
    end

    it 'does not generate Excel report when excel_enabled is false' do
      report_service.call

      expect(report_generator).not_to have_received(:generate_excel)
    end

    context 'when CSV file does not exist' do
      before do
        allow(File).to receive(:exist?).with(csv_file).and_return(false)
      end

      it 'raises an error with descriptive message' do
        expect { report_service.call }.to raise_error(
          WttjMetrics::Error,
          "CSV file not found: #{csv_file}"
        )
      end

      it 'does not prepare directories' do
        expect { report_service.call }.to raise_error(WttjMetrics::Error)

        expect(WttjMetrics::Services::DirectoryPreparer).not_to have_received(:ensure_exists)
      end

      it 'does not create ReportGenerator' do
        expect { report_service.call }.to raise_error(WttjMetrics::Error)

        expect(WttjMetrics::Reports::Linear::ReportGenerator).not_to have_received(:new)
      end
    end

    context 'when excel is enabled' do
      let(:options) do
        double(
          'Options',
          output: 'tmp/report.html',
          excel_enabled: true,
          excel_path: 'tmp/report.xlsx',
          days: 90,
          teams: %w[ATS Platform],
          teams_config: nil,
          start_date: nil,
          end_date: nil
        )
      end

      it 'prepares directories for Excel file' do
        report_service.call

        expect(WttjMetrics::Services::DirectoryPreparer)
          .to have_received(:ensure_exists)
          .with('tmp/report.xlsx')
      end

      it 'generates Excel report' do
        report_service.call

        expect(report_generator).to have_received(:generate_excel).with('tmp/report.xlsx')
      end

      it 'generates both HTML and Excel reports' do
        report_service.call

        expect(report_generator).to have_received(:generate_html)
        expect(report_generator).to have_received(:generate_excel)
      end
    end

    context 'with nested output paths' do
      let(:options) do
        double(
          'Options',
          output: 'reports/2024/december/report.html',
          excel_enabled: true,
          excel_path: 'exports/excel/report.xlsx',
          days: 90,
          teams: [],
          teams_config: nil,
          start_date: nil,
          end_date: nil
        )
      end

      it 'prepares nested directories for both outputs' do
        report_service.call

        expect(WttjMetrics::Services::DirectoryPreparer)
          .to have_received(:ensure_exists)
          .with('reports/2024/december/report.html')

        expect(WttjMetrics::Services::DirectoryPreparer)
          .to have_received(:ensure_exists)
          .with('exports/excel/report.xlsx')
      end
    end

    context 'when generator is reused' do
      it 'creates generator only once' do
        report_service.call

        expect(WttjMetrics::Reports::Linear::ReportGenerator).to have_received(:new).once
      end

      it 'uses the same generator instance for both reports' do
        options_with_excel = double(
          'Options',
          output: 'tmp/report.html',
          excel_enabled: true,
          excel_path: 'tmp/report.xlsx',
          days: 90,
          teams: [],
          teams_config: nil,
          start_date: nil,
          end_date: nil
        )

        service = described_class.new(csv_file, options_with_excel, logger)
        service.call

        expect(report_generator).to have_received(:generate_html)
        expect(report_generator).to have_received(:generate_excel)
        expect(WttjMetrics::Reports::Linear::ReportGenerator).to have_received(:new).once
      end
    end

    context 'with different days option' do
      let(:options) do
        double(
          'Options',
          output: 'tmp/report.html',
          excel_enabled: false,
          excel_path: 'tmp/report.xlsx',
          days: 30,
          teams: [],
          teams_config: nil,
          start_date: nil,
          end_date: nil
        )
      end

      it 'passes days parameter to ReportGenerator' do
        report_service.call

        expect(WttjMetrics::Reports::Linear::ReportGenerator).to have_received(:new).with(
          csv_file,
          days: 30,
          teams: [],
          teams_config: nil,
          start_date: nil,
          end_date: nil
        )
      end
    end

    context 'with specific teams filter' do
      let(:options) do
        double(
          'Options',
          output: 'tmp/report.html',
          excel_enabled: false,
          excel_path: 'tmp/report.xlsx',
          days: 90,
          teams: %w[ATS Platform Sourcing],
          teams_config: nil,
          start_date: nil,
          end_date: nil
        )
      end

      it 'passes teams parameter to ReportGenerator' do
        report_service.call

        expect(WttjMetrics::Reports::Linear::ReportGenerator).to have_received(:new).with(
          csv_file,
          days: 90,
          teams: %w[ATS Platform Sourcing],
          teams_config: nil,
          start_date: nil,
          end_date: nil
        )
      end
    end
  end
end
