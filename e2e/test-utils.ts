import { Page } from '@playwright/test';
import fs from 'fs';
import path from 'path';

export const LINEAR_REPORT_URL = `file://${path.resolve(__dirname, '..', 'report', 'linear_report.html')}`;
export const GITHUB_REPORT_URL = `file://${path.resolve(__dirname, '..', 'report', 'github_report.html')}`;

// Note: the repository ships sample reports used as stable fixtures for e2e.
// Generated reports may not exist in CI/local runs.
export const LINEAR_SAMPLE_REPORT_URL = `file://${path.resolve(__dirname, '..', 'report', 'linear_report.sample.html')}`;
export const GITHUB_SAMPLE_REPORT_URL = `file://${path.resolve(__dirname, '..', 'report', 'github_report.sample.html')}`;

function reportPathFor(type: 'linear' | 'github'): string {
    const filename = type === 'github' ? 'github_report.html' : 'linear_report.html';
    return path.resolve(__dirname, '..', 'report', filename);
}

function reportUrlFor(type: 'linear' | 'github'): string {
    return type === 'github' ? GITHUB_REPORT_URL : LINEAR_REPORT_URL;
}

function sampleReportUrlFor(type: 'linear' | 'github'): string {
    return type === 'github' ? GITHUB_SAMPLE_REPORT_URL : LINEAR_SAMPLE_REPORT_URL;
}

export async function loadReport(page: Page, type: 'linear' | 'github' = 'linear'): Promise<void> {
    const url = fs.existsSync(reportPathFor(type)) ? reportUrlFor(type) : sampleReportUrlFor(type);
    await page.goto(url, { waitUntil: 'networkidle' });
}
