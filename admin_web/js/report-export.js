// Voya — shared PDF/Excel export helpers for the Report Design feature
// (admin/reports.html, partner/reports.html). This project has no build
// step, so jsPDF + its AutoTable plugin, SheetJS (xlsx), and Chart.js are
// loaded as plain <script> tags on whichever page calls these — see the
// <head> of each reports.html for the exact CDN URLs. These functions
// just assume window.jspdf.jsPDF, window.XLSX and window.Chart already
// exist by the time a user clicks an export button.
//
// exportReportPdf() renders the branded, print-ready layout from the FYP
// report's reference figures: a logo + uppercase title header, a Report
// Period / Generated / Report ID metadata line (plus an optional extra
// line, e.g. "Provider: Allianz Malaysia"), a divided stat row (2-4
// values separated by thin rules rather than boxed cards), up to two
// charts side by side (a navy line chart and a teal bar chart), one data
// table (navy header, zebra-striped rows, an optional highlighted TOTAL
// row), and a footer repeated on every page. Every caller in
// admin/reports.html and partner/reports.html builds its own
// stats/chart/table data from what it already has on screen — this file
// only knows how to lay it out.
import { VOYA_LOGO_PNG_BASE64 } from "./voya-logo-base64.js";

const NAVY = [14, 58, 82]; // --navy-800
const NAVY_LIGHT = [92, 112, 128];
const TEAL = [28, 125, 140]; // --teal-600
const GRAY = [110, 110, 110];
const TOTAL_ROW_BG = [227, 242, 243]; // --teal-100
const ZEBRA_BG = [245, 248, 249];
const GRID_LINE = [210, 216, 220];

function ensureLibs() {
  if (!window.jspdf?.jsPDF) {
    throw new Error("PDF export library didn't load — check your internet connection and reload the page.");
  }
  if (!window.XLSX) {
    throw new Error("Excel export library didn't load — check your internet connection and reload the page.");
  }
}

function ensureChartLib() {
  if (!window.Chart) {
    throw new Error("Chart library didn't load — check your internet connection and reload the page.");
  }
}

function fmtDate(d) {
  return d.toLocaleDateString("en-MY", { day: "2-digit", month: "short", year: "numeric" });
}

/** A local, per-browser, per-report-type counter — just enough to make
 * "Report ID: VYA-CPAR-2026-0001" look like a real sequence on the
 * printed page. There's no backend to issue a globally unique id from
 * (this console has no server component), so this is honestly cosmetic,
 * not a uniqueness guarantee. Falls back to 1 every time if storage is
 * blocked (private browsing, etc.) rather than let that block an export. */
function nextReportSeq(code) {
  const key = `voya_report_seq_${code}`;
  try {
    const n = Number(localStorage.getItem(key) || "0") + 1;
    localStorage.setItem(key, String(n));
    return n;
  } catch {
    return 1;
  }
}
function buildReportId(code, year) {
  return `VYA-${code}-${year}-${String(nextReportSeq(code)).padStart(4, "0")}`;
}

/** Renders one Chart.js chart offscreen and returns a PNG data URL —
 * jsPDF can only embed a raster image, not a live canvas, so every chart
 * in the PDF is drawn once to a detached <canvas> (at a fixed pixel size
 * well above its final point size in the PDF, so it stays crisp once
 * scaled down) and captured as an image. Animation is forced off so the
 * canvas is fully painted the instant `new Chart()` returns — this
 * function stays synchronous, no need to await a frame before reading it
 * back, which keeps every exportReportPdf() caller non-async too. */
function renderChartImage({ type, labels, datasets, indexAxis }) {
  const canvas = document.createElement("canvas");
  canvas.width = 920;
  canvas.height = 460;
  const chart = new window.Chart(canvas.getContext("2d"), {
    type,
    data: { labels, datasets },
    options: {
      indexAxis: indexAxis || "x",
      animation: false,
      responsive: false,
      plugins: { legend: { display: false } },
      scales: {
        x: { ticks: { font: { size: 20 }, color: "#4a5a64" }, grid: { color: "#e5e9ec" } },
        y: { ticks: { font: { size: 20 }, color: "#4a5a64", precision: 0 }, grid: { color: "#e5e9ec" }, beginAtZero: true },
      },
      elements: { point: { radius: 0 }, line: { borderWidth: 4 } },
    },
  });
  const url = canvas.toDataURL("image/png");
  chart.destroy();
  return url;
}
function lineChartImage({ labels, values, color = NAVY }) {
  const rgb = `rgb(${color.join(",")})`;
  return renderChartImage({
    type: "line",
    labels,
    datasets: [{ data: values, borderColor: rgb, backgroundColor: rgb, tension: 0.35, fill: false }],
  });
}
function barChartImage({ labels, values, color = TEAL, horizontal = false }) {
  const rgb = `rgb(${color.join(",")})`;
  return renderChartImage({
    type: "bar",
    labels,
    datasets: [{ data: values, backgroundColor: rgb, borderRadius: 2, barThickness: horizontal ? 22 : undefined }],
    indexAxis: horizontal ? "y" : "x",
  });
}

/**
 * Exports a report to a branded, print-ready PDF.
 *
 * - `title` — plain text, upper-cased and bold-set automatically.
 * - `reportCode` — short prefix for the Report ID, e.g. "CPAR", "IOR",
 *   "UAR-T" (traveller), "UAR-P" (partner).
 * - `period` — `{ start: Date, end: Date }`, shown as "Report Period: 01
 *   Jan 2026 - 31 Dec 2026". Optional — omit if the report has none.
 * - `extraLine` — optional second metadata line under Report Period,
 *   e.g. "Provider: Allianz Malaysia" for a partner-scoped export.
 * - `stats` — `[{ label, value }]`, 2-4 items, laid out as one row
 *   divided by thin rules (not boxed cards) to match the reference
 *   design.
 * - `lineChart` / `barChart` — optional `{ title, labels, values,
 *   horizontal? }`. Passing both puts them side by side; passing just
 *   one gives it the full content width; passing neither skips the
 *   charts section entirely.
 * - `table` — optional `{ title, head, body, totalRow? }`. `totalRow`
 *   (an array matching `head`'s length) renders as a distinct,
 *   highlighted footer row via AutoTable's `foot`, matching the
 *   reference design's bold TOTAL row.
 */
export function exportReportPdf({ filename, title, reportCode, period, extraLine, stats = [], lineChart, barChart, table }) {
  ensureLibs();
  const needsChart = lineChart || barChart;
  if (needsChart) ensureChartLib();

  const { jsPDF } = window.jspdf;
  const doc = new jsPDF({ unit: "pt", format: "a4" });
  const marginX = 40;
  const pageWidth = doc.internal.pageSize.getWidth();
  const contentWidth = pageWidth - marginX * 2;
  const now = new Date();
  let y = 46;

  // ---- Header: logo + title ----
  const logoW = 56, logoH = 38;
  doc.addImage(`data:image/png;base64,${VOYA_LOGO_PNG_BASE64}`, "PNG", marginX, y - 27, logoW, logoH);
  doc.setFont(undefined, "bold");
  doc.setFontSize(19);
  doc.setTextColor(...NAVY);
  doc.text(String(title || "").toUpperCase(), pageWidth - marginX, y, { align: "right" });
  y += 22;

  // ---- Metadata row: Report Period (+ optional extra line) / Generated / Report ID ----
  doc.setFont(undefined, "normal");
  doc.setFontSize(9);
  doc.setTextColor(...GRAY);
  if (period) doc.text(`Report Period: ${fmtDate(period.start)} - ${fmtDate(period.end)}`, marginX, y);
  doc.text(`Generated: ${fmtDate(now)}`, pageWidth / 2 - 30, y);
  doc.text(`Report ID:\n${buildReportId(reportCode || "RPT", now.getFullYear())}`, pageWidth - marginX, y - 4, { align: "right" });
  y += 10;
  if (extraLine) {
    doc.text(extraLine, marginX, y);
    y += 10;
  }
  y += 14;

  // ---- Divider ----
  doc.setDrawColor(...NAVY);
  doc.setLineWidth(1.3);
  doc.line(marginX, y, pageWidth - marginX, y);
  y += 28;

  // ---- Stat row (divided by thin rules, not boxed cards) ----
  if (stats.length) {
    const colW = contentWidth / stats.length;
    stats.forEach((s, i) => {
      const cx = marginX + colW * i + colW / 2;
      if (i > 0) {
        doc.setDrawColor(...GRID_LINE);
        doc.setLineWidth(0.8);
        doc.line(marginX + colW * i, y - 20, marginX + colW * i, y + 10);
      }
      doc.setFont(undefined, "bold");
      doc.setFontSize(8.5);
      doc.setTextColor(...NAVY_LIGHT);
      doc.text(String(s.label).toUpperCase(), cx, y - 8, { align: "center" });
      doc.setFontSize(19);
      doc.setTextColor(...NAVY);
      doc.text(String(s.value), cx, y + 11, { align: "center" });
    });
    y += 32;
    doc.setDrawColor(...NAVY);
    doc.setLineWidth(1.3);
    doc.line(marginX, y, pageWidth - marginX, y);
    y += 26;
  }

  // ---- Charts (side by side if both given, full-width if only one) ----
  if (needsChart) {
    const charts = [
      lineChart && { ...lineChart, kind: "line" },
      barChart && { ...barChart, kind: "bar" },
    ].filter(Boolean);
    const gap = 18;
    const chartW = charts.length === 2 ? (contentWidth - gap) / 2 : contentWidth;
    const chartH = chartW * 0.5;
    charts.forEach((c, i) => {
      const cx = marginX + i * (chartW + gap);
      doc.setFont(undefined, "bold");
      doc.setFontSize(11);
      doc.setTextColor(...NAVY);
      doc.text(String(c.title || "").toUpperCase(), cx, y);
      const img = c.kind === "line"
        ? lineChartImage({ labels: c.labels, values: c.values, color: NAVY })
        : barChartImage({ labels: c.labels, values: c.values, color: TEAL, horizontal: c.horizontal });
      doc.addImage(img, "PNG", cx, y + 8, chartW, chartH);
    });
    y += chartH + 36;
  }

  // ---- Table (optional highlighted TOTAL row via AutoTable's foot) ----
  if (table) {
    doc.setFont(undefined, "bold");
    doc.setFontSize(12);
    doc.setTextColor(...NAVY);
    doc.text(String(table.title || "").toUpperCase(), marginX, y);
    y += 10;
    doc.autoTable({
      startY: y,
      head: [table.head],
      body: table.body,
      foot: table.totalRow ? [table.totalRow] : undefined,
      margin: { left: marginX, right: marginX },
      styles: { fontSize: 9, cellPadding: 6, textColor: [40, 48, 54] },
      headStyles: { fillColor: NAVY, textColor: 255, fontStyle: "bold" },
      alternateRowStyles: { fillColor: ZEBRA_BG },
      footStyles: { fillColor: TOTAL_ROW_BG, textColor: NAVY, fontStyle: "bold" },
      theme: "grid",
    });
    y = doc.lastAutoTable.finalY + 20;
  }

  // ---- Footer on every page: thin rule, data source (left), page X of Y (right) ----
  const pageCount = doc.internal.getNumberOfPages();
  for (let p = 1; p <= pageCount; p++) {
    doc.setPage(p);
    const pageHeight = doc.internal.pageSize.getHeight();
    const fy = pageHeight - 34;
    doc.setDrawColor(...NAVY);
    doc.setLineWidth(0.8);
    doc.line(marginX, fy, pageWidth - marginX, fy);
    doc.setFont(undefined, "normal");
    doc.setFontSize(8);
    doc.setTextColor(...GRAY);
    doc.text("Data source: Voya - AI-Driven Contextual Travel Management", marginX, fy + 14);
    doc.text(`Page ${p} of ${pageCount}`, pageWidth - marginX, fy + 14, { align: "right" });
  }

  doc.save(filename.endsWith(".pdf") ? filename : `${filename}.pdf`);
}

/**
 * Exports a report to an .xlsx workbook — one sheet per entry in `sheets`
 * (`{ name, rows: [[header...], [row...], ...] }`, first row is the
 * header). Sheet names longer than 31 chars are truncated (Excel's limit).
 * Unchanged by the PDF branding work above — a spreadsheet has no visual
 * template to match, so this just stays a plain data export.
 */
export function exportReportExcel({ filename, sheets = [] }) {
  ensureLibs();
  const wb = window.XLSX.utils.book_new();
  sheets.forEach((s) => {
    const ws = window.XLSX.utils.aoa_to_sheet(s.rows);
    window.XLSX.utils.book_append_sheet(wb, ws, s.name.slice(0, 31));
  });
  window.XLSX.writeFile(wb, filename.endsWith(".xlsx") ? filename : `${filename}.xlsx`);
}
