// Shared JS for WTTJ Metrics Reports

// Color Palette
const colors = {
    purple: 'rgba(88, 88, 88, 0.8)',
    blue: 'rgba(59, 130, 246, 0.8)',
    pink: 'rgba(236, 72, 153, 0.8)',
    green: 'rgba(34, 197, 94, 0.8)',
    orange: 'rgba(249, 115, 22, 0.8)',
    yellow: 'rgba(255, 205, 0, 0.9)',
    red: 'rgba(220, 38, 38, 0.8)',
    cyan: 'rgba(6, 182, 212, 0.8)',
    black: 'rgba(21, 21, 21, 0.8)',
    lime: 'rgba(132, 204, 22, 0.8)',
    indigo: 'rgba(99, 102, 241, 0.8)',
    rose: 'rgba(244, 63, 94, 0.8)',
    teal: 'rgba(20, 184, 166, 0.8)',
    amber: 'rgba(245, 158, 11, 0.8)',
    violet: 'rgba(139, 92, 246, 0.8)',
    emerald: 'rgba(16, 185, 129, 0.8)',
    deepOrange: 'rgba(255, 87, 34, 0.8)',
    lightBlue: 'rgba(3, 169, 244, 0.8)',
    lightGreen: 'rgba(139, 195, 74, 0.8)',
    deepPurple: 'rgba(103, 58, 183, 0.8)',
    fuchsia: 'rgba(217, 70, 239, 0.8)',
    brown: 'rgba(121, 85, 72, 0.8)',
    slate: 'rgba(100, 116, 139, 0.8)',
    grey: 'rgba(158, 158, 158, 0.8)'
};

// Extended color palette for dynamic team colors
const teamColorPalette = [
    colors.blue, colors.green, colors.yellow, colors.orange,
    colors.purple, colors.pink, colors.cyan, colors.red,
    colors.lime, colors.indigo, colors.rose, colors.teal,
    colors.amber, colors.violet, colors.emerald, colors.deepOrange,
    colors.lightBlue, colors.lightGreen, colors.deepPurple, colors.fuchsia,
    colors.brown, colors.slate, colors.grey, colors.black
];

// Chart Defaults
if (typeof Chart !== 'undefined') {
    Chart.defaults.color = '#585858';
    Chart.defaults.borderColor = '#DEDEDE';
    Chart.defaults.responsive = true;
    Chart.defaults.maintainAspectRatio = false;
    Chart.defaults.plugins.legend.position = 'top';
}

// Helper to create baseline dataset
function createBaselineDataset(value, label, color, length) {
    return {
        type: 'line',
        label: `${label} (Median: ${Number(value).toFixed(2)})`,
        data: new Array(length).fill(value),
        borderColor: color,
        borderDash: [5, 5],
        pointRadius: 0,
        borderWidth: 2,
        fill: false
    };
}

// Helper to create standard metric line chart
function createMetricLineChart(elementId, labels, metricData, metricLabel, metricColor, avgValue, avgLabel = 'Period Median', options = {}) {
    const defaultOptions = {
        scales: { y: { beginAtZero: true } }
    };

    // Merge scales if provided
    if (options.scales) {
        defaultOptions.scales = { ...defaultOptions.scales, ...options.scales };
    }

    return new Chart(document.getElementById(elementId).getContext('2d'), {
        type: 'line',
        data: {
            labels: labels,
            datasets: [
                {
                    label: metricLabel,
                    data: metricData,
                    borderColor: metricColor,
                    backgroundColor: metricColor,
                    tension: 0.4
                },
                createBaselineDataset(avgValue, avgLabel, metricColor, labels.length)
            ]
        },
        options: defaultOptions
    });
}

// Helper to create stacked bar chart (100%)
function createStackedBarChart(elementId, labels, datasets, options = {}) {
    return new Chart(document.getElementById(elementId).getContext('2d'), {
        type: 'bar',
        data: {
            labels: labels,
            datasets: datasets
        },
        options: {
            scales: {
                x: { stacked: true, grid: { display: false } },
                y: { stacked: true, min: 0, max: 100, ticks: { callback: v => v + '%' }, grid: { color: 'rgba(0,0,0,0.1)' } }
            },
            plugins: {
                legend: { position: 'top' },
                tooltip: {
                    callbacks: {
                        label: ctx => {
                            const raw = ctx.dataset.raw ? ctx.dataset.raw[ctx.dataIndex] : ctx.parsed.y;
                            const val = ctx.parsed.y.toFixed(1);
                            if (ctx.dataset.raw !== undefined) {
                                return `${ctx.dataset.label}: ${raw} (${val}%)`;
                            }
                            return `${ctx.dataset.label}: ${val}%`;
                        }
                    }
                }
            },
            ...options
        }
    });
}

// Helper to create standard bar chart
function createBarChart(elementId, labels, datasets, options = {}) {
    const defaultOptions = {
        indexAxis: 'x',
        plugins: {
            legend: { display: datasets.length > 1 },
            title: { display: false }
        },
        scales: {
            x: { beginAtZero: true },
            y: { beginAtZero: true }
        }
    };

    // Merge options
    const finalOptions = { ...defaultOptions, ...options };
    if (options.scales) finalOptions.scales = { ...defaultOptions.scales, ...options.scales };
    if (options.plugins) finalOptions.plugins = { ...defaultOptions.plugins, ...options.plugins };

    return new Chart(document.getElementById(elementId).getContext('2d'), {
        type: 'bar',
        data: {
            labels: labels,
            datasets: datasets
        },
        options: finalOptions
    });
}

// Toggle Section Visibility
function toggleSection(header) {
    const content = header.nextElementSibling;
    const chevron = header.querySelector('.chevron');
    const checkbox = header.querySelector('input[type="checkbox"]');

    content.classList.toggle('collapsed');
    chevron.classList.toggle('collapsed');

    // Sync checkbox if it exists
    if (checkbox) {
        checkbox.checked = !content.classList.contains('collapsed');
    }
}

function toggleSectionByCheckbox(checkbox) {
    const header = checkbox.closest('.section-header');
    const content = header.nextElementSibling;
    const chevron = header.querySelector('.chevron');

    if (checkbox.checked) {
        content.classList.remove('collapsed');
        chevron.classList.remove('collapsed');
    } else {
        content.classList.add('collapsed');
        chevron.classList.add('collapsed');
    }
}

function toggleAllSections() {
    const btn = document.querySelector('.collapse-all-btn');
    const isCollapsing = btn.innerText.includes('Collapse');
    const sections = document.querySelectorAll('section');

    sections.forEach(section => {
        const header = section.querySelector('.section-header');
        const content = section.querySelector('.section-content');
        const chevron = section.querySelector('.chevron');
        const checkbox = section.querySelector('input[type="checkbox"]');

        if (isCollapsing) {
            content.classList.add('collapsed');
            chevron.classList.add('collapsed');
            if (checkbox) checkbox.checked = false;
        } else {
            content.classList.remove('collapsed');
            chevron.classList.remove('collapsed');
            if (checkbox) checkbox.checked = true;
        }
    });

    const icon = document.getElementById('toggleAllIcon');
    const text = document.getElementById('toggleAllText');

    if (isCollapsing) {
        icon.innerText = '▶';
        text.innerText = 'Expand All';
    } else {
        icon.innerText = '▼';
        text.innerText = 'Collapse All';
    }
}

// Filter Table
function filterTable(inputId, tableId) {
    const input = document.getElementById(inputId);
    const filter = input.value.toUpperCase();
    const table = document.getElementById(tableId);
    const tr = table.getElementsByTagName('tr');

    for (let i = 1; i < tr.length; i++) {
        const td = tr[i].getElementsByTagName('td')[0];
        if (td) {
            const txtValue = td.textContent || td.innerText;
            tr[i].style.display = txtValue.toUpperCase().indexOf(filter) > -1 ? '' : 'none';
        }
    }
}

// Sort Table
function sortTable(tableId, n) {
    const table = document.getElementById(tableId);
    let rows, switching, i, x, y, shouldSwitch, dir, switchcount = 0;
    switching = true;
    dir = 'asc';

    // Reset headers
    const headers = table.getElementsByTagName("TH");
    for (i = 0; i < headers.length; i++) {
        headers[i].classList.remove("asc", "desc");
    }

    while (switching) {
        switching = false;
        rows = table.rows;

        for (i = 1; i < (rows.length - 1); i++) {
            shouldSwitch = false;
            x = rows[i].getElementsByTagName('TD')[n];
            y = rows[i + 1].getElementsByTagName('TD')[n];

            let xVal = x.innerText.replace(/%| days/g, '');
            let yVal = y.innerText.replace(/%| days/g, '');

            if (!isNaN(parseFloat(xVal)) && !isNaN(parseFloat(yVal))) {
                xVal = parseFloat(xVal);
                yVal = parseFloat(yVal);
            } else {
                xVal = xVal.toLowerCase();
                yVal = yVal.toLowerCase();
            }

            if (dir === 'asc') {
                if (xVal > yVal) { shouldSwitch = true; break; }
            } else if (dir === 'desc') {
                if (xVal < yVal) { shouldSwitch = true; break; }
            }
        }

        if (shouldSwitch) {
            rows[i].parentNode.insertBefore(rows[i + 1], rows[i]);
            switching = true;
            switchcount++;
        } else {
            if (switchcount === 0 && dir === 'asc') {
                dir = 'desc';
                switching = true;
            }
        }
    }

    // Set header class
    headers[n].classList.add(dir);
}

// Helper to create doughnut chart
function createDoughnutChart(elementId, labels, datasets, options = {}) {
    const defaultOptions = {
        plugins: {
            legend: { position: 'right' }
        }
    };

    // Merge options
    const finalOptions = { ...defaultOptions, ...options };
    if (options.plugins) finalOptions.plugins = { ...defaultOptions.plugins, ...options.plugins };

    return new Chart(document.getElementById(elementId).getContext('2d'), {
        type: 'doughnut',
        data: {
            labels: labels,
            datasets: datasets
        },
        options: finalOptions
    });
}

// Helper to render Heatmap
function renderHeatmap(containerId, activityData, excludeBots = false) {
    const container = document.getElementById(containerId);
    if (!container) return;

    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const hours = Array.from({ length: 24 }, (_, i) => i);
    const isMobile = window.innerWidth <= 768;

    // Helper to get filtered count and authors
    const getCellData = (cell) => {
        let count = (typeof cell === 'object' && cell !== null) ? (cell.count || 0) : cell;
        let authors = (typeof cell === 'object' && cell !== null) ? (cell.authors || {}) : {};

        if (excludeBots) {
            const filteredAuthors = {};
            let filteredCount = 0;
            Object.entries(authors).forEach(([author, authorCount]) => {
                if (!author.toLowerCase().includes('[bot]')) {
                    filteredAuthors[author] = authorCount;
                    filteredCount += authorCount;
                }
            });
            return { count: filteredCount, authors: filteredAuthors };
        }

        return { count, authors };
    };

    // Calculate max value for coloring
    let maxVal = 0;
    activityData.forEach(row => {
        row.forEach(cell => {
            const { count } = getCellData(cell);
            if (count > maxVal) maxVal = count;
        });
    });
    if (maxVal === 0) maxVal = 1;

    let html = '<table class="heatmap-table">';

    if (isMobile) {
        // Mobile: Rows = Hours (0-23), Cols = Days (Mon-Sun)

        // Header: Days
        html += '<thead><tr><th></th>';
        days.forEach(day => {
            html += `<th>${day}</th>`;
        });
        html += '</tr></thead><tbody>';

        // Body: Hours
        hours.forEach(hour => {
            html += `<tr><td class="day-label">${hour}</td>`;
            days.forEach((_, dayIdx) => {
                const { count, authors } = getCellData(activityData[dayIdx][hour]);

                let tooltipContent = `${count} items`;
                if (count > 0 && authors) {
                    const sortedAuthors = Object.entries(authors).sort((a, b) => b[1] - a[1]);
                    sortedAuthors.forEach(([author, authorCount]) => {
                        tooltipContent += `\n${titleize(author)}: ${authorCount}`;
                    });
                }

                const style = getHeatmapCellStyle(count, maxVal);
                html += `<td style="${style}" data-tooltip="${tooltipContent.replace(/"/g, '&quot;')}" onmouseenter="showTooltip(this)" onmouseleave="hideTooltip()">
                    ${count > 0 ? count : ''}
                </td>`;
            });
            html += '</tr>';
        });

    } else {
        // Desktop: Rows = Days (Mon-Sun), Cols = Hours (0-23)

        // Header: Hours
        html += '<thead><tr><th></th>';
        hours.forEach(hour => {
            html += `<th>${hour}</th>`;
        });
        html += '</tr></thead><tbody>';

        // Body: Days
        days.forEach((day, dayIdx) => {
            html += `<tr><td class="day-label">${day}</td>`;
            hours.forEach(hour => {
                const { count, authors } = getCellData(activityData[dayIdx][hour]);

                let tooltipContent = `${count} items`;
                if (count > 0 && authors) {
                    const sortedAuthors = Object.entries(authors).sort((a, b) => b[1] - a[1]);
                    sortedAuthors.forEach(([author, authorCount]) => {
                        tooltipContent += `\n${titleize(author)}: ${authorCount}`;
                    });
                }

                const style = getHeatmapCellStyle(count, maxVal);
                html += `<td style="${style}" data-tooltip="${tooltipContent.replace(/"/g, '&quot;')}" onmouseenter="showTooltip(this)" onmouseleave="hideTooltip()">
                    ${count > 0 ? count : ''}
                </td>`;
            });
            html += '</tr>';
        });
    }

    html += '</tbody></table>';
    container.innerHTML = html;
}

function toggleBotExclusion(checkbox) {
    const excludeBots = checkbox.checked;
    if (typeof commitActivity !== 'undefined') {
        renderHeatmap('heatmap-container', commitActivity, excludeBots);
    }
}

function getHeatmapCellStyle(count, maxVal) {
    const intensity = count / maxVal;
    const alpha = 0.1 + (intensity * 0.9);
    const bgColor = count > 0 ? `rgba(40, 167, 69, ${alpha})` : "#f8f9fa";
    const textColor = intensity > 0.5 ? "#fff" : "#333";
    return `background-color: ${bgColor}; color: ${textColor}`;
}

// Global Tooltip Management
let globalTooltip = null;

function getGlobalTooltip() {
    if (!globalTooltip) {
        globalTooltip = document.createElement('div');
        globalTooltip.className = 'heatmap-tooltip';
        document.body.appendChild(globalTooltip);
    }
    return globalTooltip;
}

function showTooltip(td) {
    const tooltip = getGlobalTooltip();
    const content = td.getAttribute('data-tooltip');
    if (!content) return;

    const lines = content.split('\n');

    // Reset content and classes (keep base class)
    tooltip.className = 'heatmap-tooltip';
    tooltip.innerHTML = '';

    if (lines.length > 20) {
        tooltip.classList.add('multi-column');
        const columns = Math.ceil(lines.length / 20);

        for (let i = 0; i < columns; i++) {
            const colDiv = document.createElement('div');
            colDiv.className = 'tooltip-column';
            colDiv.innerText = lines.slice(i * 20, (i + 1) * 20).join('\n');
            tooltip.appendChild(colDiv);
        }
    } else {
        tooltip.innerText = content;
    }

    const rect = td.getBoundingClientRect();
    tooltip.style.left = (rect.left + rect.width / 2) + 'px';
    tooltip.style.top = rect.bottom + 'px';

    tooltip.classList.add('visible');
}

function hideTooltip() {
    const tooltip = getGlobalTooltip();
    tooltip.classList.remove('visible');
}

// Helper to titleize strings
function titleize(str) {
    if (!str) return '';
    return str
        .replace(/[-_]/g, ' ')
        .toLowerCase()
        .replace(/(?:^|\s)\S/g, function (a) { return a.toUpperCase(); });
}
