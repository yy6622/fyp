import { VOYA_LOGO_PNG_BASE64 } from "./voya-logo-base64.js";

const NAVY = [14, 58, 82]; // --navy-800
const NAVY_LIGHT = [92, 112, 128];
const TEAL = [28, 125, 140]; // --teal-600
const INDIGO = [75, 99, 217]; // --accent-indigo
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

function renderChartImage({ type, labels, datasets, indexAxis, showLegend = false }) {
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
      plugins: {
        legend: showLegend
          ? { display: true, position: "top", align: "start", labels: { font: { size: 20 }, color: "#4a5a64", boxWidth: 18, padding: 20 } }
          : { display: false },
      },
      scales: {
        x: { ticks: { font: { size: 20 }, color: "#4a5a64", precision: 0 }, grid: { color: "#e5e9ec" }, beginAtZero: true },
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
const SERIES_PALETTE = [TEAL, INDIGO];
function barChartImage({ labels, values, series, color = TEAL, horizontal = false }) {
  const datasets = series && series.length
    ? series.map((s, i) => ({
        label: s.label,
        data: s.values,
        backgroundColor: `rgb(${(s.color || SERIES_PALETTE[i % SERIES_PALETTE.length]).join(",")})`,
        borderRadius: 2,
        barThickness: horizontal ? 16 : undefined,
      }))
    : [{ data: values, backgroundColor: `rgb(${color.join(",")})`, borderRadius: 2, barThickness: horizontal ? 22 : undefined }];
  return renderChartImage({
    type: "bar",
    labels,
    datasets,
    indexAxis: horizontal ? "y" : "x",
    showLegend: !!(series && series.length > 1),
  });
}

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
        : barChartImage({ labels: c.labels, values: c.values, series: c.series, color: TEAL, horizontal: c.horizontal });
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

export function exportReportExcel({ filename, sheets = [] }) {
  ensureLibs();
  const wb = window.XLSX.utils.book_new();
  sheets.forEach((s) => {
    const ws = window.XLSX.utils.aoa_to_sheet(s.rows);
    window.XLSX.utils.book_append_sheet(wb, ws, s.name.slice(0, 31));
  });
  window.XLSX.writeFile(wb, filename.endsWith(".xlsx") ? filename : `${filename}.xlsx`);
}
