// Voya — small hand-built line-icon set (no external icon font/CDN needed).
// Each entry is the *inner* SVG markup for a 24x24 viewBox, stroke=currentColor.
const RAW = {
  home: '<path d="M4 11.5l8-7.5 8 7.5"/><path d="M6 10v10h5v-6h2v6h5V10"/>',
  user: '<circle cx="12" cy="8" r="3.6"/><path d="M4.5 20c1-4 4-6 7.5-6s6.5 2 7.5 6"/>',
  "user-check": '<circle cx="10.5" cy="8" r="3.4"/><path d="M3.5 20c1-3.8 3.7-5.7 7-5.7"/><path d="M15.8 12.8l1.6 1.6 3-3"/>',
  "user-x": '<circle cx="10.5" cy="8" r="3.4"/><path d="M3.5 20c1-3.8 3.7-5.7 7-5.7"/><path d="M15.5 12l4 4M19.5 12l-4 4"/>',
  "user-plus": '<circle cx="10" cy="8" r="3.4"/><path d="M3 20c1-3.8 3.6-5.7 7-5.7"/><path d="M18 11v6M15 14h6"/>',
  sparkle: '<path d="M12 3l1.6 5.4L19 10l-5.4 1.6L12 17l-1.6-5.4L5 10l5.4-1.6z"/>',
  clock: '<circle cx="12" cy="12" r="8.4"/><path d="M12 7.2v5l3.4 2"/>',
  "check-circle": '<circle cx="12" cy="12" r="8.4"/><path d="M8 12.4l2.6 2.6L16.2 9"/>',
  "x-circle": '<circle cx="12" cy="12" r="8.4"/><path d="M9 9l6 6M15 9l-6 6"/>',
  "file-check": '<path d="M7 3h7l4 4v14H7z"/><path d="M14 3v4h4"/><path d="M9.4 14l2 2 4.2-4.2"/>',
  "file-x": '<path d="M7 3h7l4 4v14H7z"/><path d="M14 3v4h4"/><path d="M9.6 13.2l4 4M13.6 13.2l-4 4"/>',
  swap: '<path d="M4 8h13M13.8 4.6L17.2 8l-3.4 3.4"/><path d="M20 16H7M10.2 12.6L6.8 16l3.4 3.4"/>',
  coin: '<circle cx="12" cy="12" r="8.4"/><path d="M12 7.2v9.6"/><path d="M14.6 9.6c0-1.2-1.1-2-2.6-2s-2.6.9-2.6 2.1c0 2.6 5.2 1.4 5.2 4 0 1.3-1.1 2.1-2.6 2.1s-2.6-.9-2.6-2.1"/>',
  shield: '<path d="M12 3.2l7 3v5.6c0 5-3 8-7 9-4-1-7-4-7-9V6.2z"/>',
  "shield-check": '<path d="M12 3.2l7 3v5.6c0 5-3 8-7 9-4-1-7-4-7-9V6.2z"/><path d="M8.8 12.2l2.3 2.3 4.2-4.4"/>',
  percent: '<circle cx="7.2" cy="7.2" r="2.3"/><circle cx="16.8" cy="16.8" r="2.3"/><path d="M18 6L6 18"/>',
  undo: '<path d="M8 8L4 12l4 4"/><path d="M4 12h9.5a5 5 0 1 1 0 10H11"/>',
  "bar-chart": '<path d="M5 20V10M12 20V4M19 20v-7"/>',
  building: '<rect x="5" y="3" width="10" height="18" rx="1"/><path d="M9 7h2M9 11h2M9 15h2M15 11h4v10h-4z"/>',
  download: '<path d="M12 4v11M8 11l4 4 4-4"/><path d="M5 19h14"/>',
  upload: '<path d="M12 15V4M8 8l4-4 4 4"/><path d="M5 19h14"/>',
  search: '<circle cx="10.5" cy="10.5" r="6.5"/><path d="M20 20l-5-5"/>',
  plus: '<path d="M12 5v14M5 12h14"/>',
  "log-out": '<path d="M9 4H5v16h4"/><path d="M13 8l4 4-4 4"/><path d="M17 12H9"/>',
  "arrow-left": '<path d="M19 12H5M11 6l-6 6 6 6"/>',
  "chevron-left": '<path d="M15 5l-7 7 7 7"/>',
  "chevron-right": '<path d="M9 5l7 7-7 7"/>',
  mail: '<rect x="3" y="5" width="18" height="14" rx="2"/><path d="M3 7l9 6 9-6"/>',
  phone: '<path d="M6.2 3h3l1.4 4.7-2.2 1.4a12.7 12.7 0 0 0 6.3 6.3l1.4-2.2L20.8 15v3a2 2 0 0 1-2 2C11 20 4 13 4 5.2a2 2 0 0 1 2-2z"/>',
  "map-pin": '<path d="M12 21s7-6.4 7-12a7 7 0 0 0-14 0c0 5.6 7 12 7 12z"/><circle cx="12" cy="9" r="2.3"/>',
  flag: '<path d="M5 3v18"/><path d="M5 4h11l-2 3 2 3H5"/>',
  star: '<path d="M12 3.5l2.5 5.3 5.8.7-4.2 4 1 5.8-5.1-2.8-5.1 2.8 1-5.8-4.2-4 5.8-.7z"/>',
  trash: '<path d="M4 7h16M9 7V4h6v3M6 7l1 13h10l1-13"/><path d="M10 11v6M14 11v6"/>',
  edit: '<path d="M4 20h4L19 9l-4-4L4 16z"/><path d="M14.5 5.5l4 4"/>',
  eye: '<path d="M2 12s3.6-7 10-7 10 7 10 7-3.6 7-10 7-10-7-10-7z"/><circle cx="12" cy="12" r="3"/>',
  "alert-triangle": '<path d="M12 4.2l9.3 15.8H2.7z"/><path d="M12 10v4"/><circle cx="12" cy="16.8" r=".2" fill="currentColor" stroke="currentColor"/>',
  "doc-text": '<path d="M7 3h7l4 4v14H7z"/><path d="M14 3v4h4"/><path d="M9.4 12h5.2M9.4 15.5h5.2"/>',
  briefcase: '<rect x="3" y="8" width="18" height="12" rx="2"/><path d="M8 8V6a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/><path d="M3 13h18"/>',
  x: '<path d="M6 6l12 12M18 6L6 18"/>',
  info: '<circle cx="12" cy="12" r="8.4"/><path d="M12 11v5"/><circle cx="12" cy="8" r=".2" fill="currentColor" stroke="currentColor"/>',
  menu: '<path d="M4 6h16M4 12h16M4 18h16"/>',
  refresh: '<path d="M4.5 12a7.5 7.5 0 0 1 13.2-5"/><path d="M19.5 12a7.5 7.5 0 0 1-13.2 5"/><path d="M17.2 4.6v4.1h-4.1M6.8 19.4v-4.1h4.1"/>',
  play: '<path d="M8 5.5v13l11-6.5z"/>',
};

// Gear (settings icon) built with trig so the teeth are always even.
function gearPath() {
  const cx = 12, cy = 12, rOuter = 9.4, rInner = 7.1, teeth = 8;
  let d = "";
  for (let i = 0; i < teeth; i++) {
    const a0 = (i / teeth) * Math.PI * 2;
    const a1 = a0 + (Math.PI * 2) / teeth / 2.2;
    const x0 = cx + rInner * Math.cos(a0), y0 = cy + rInner * Math.sin(a0);
    const x1 = cx + rOuter * Math.cos(a0), y1 = cy + rOuter * Math.sin(a0);
    const x2 = cx + rOuter * Math.cos(a1), y2 = cy + rOuter * Math.sin(a1);
    d += `M${x0.toFixed(2)} ${y0.toFixed(2)} L${x1.toFixed(2)} ${y1.toFixed(2)} L${x2.toFixed(2)} ${y2.toFixed(2)} `;
  }
  return `<circle cx="12" cy="12" r="6.2"/><circle cx="12" cy="12" r="2.4"/><path d="${d}"/>`;
}
RAW.settings = gearPath();

export function iconMarkup(name, { size = 18, className = "icon" } = {}) {
  const inner = RAW[name] || RAW.info;
  return `<svg class="${className}" width="${size}" height="${size}" viewBox="0 0 24 24">${inner}</svg>`;
}

/** Finds every [data-icon] element under `root` and injects its SVG. */
export function mountIcons(root = document) {
  root.querySelectorAll("[data-icon]").forEach((el) => {
    const name = el.getAttribute("data-icon");
    const size = el.getAttribute("data-icon-size") || 18;
    if (el.dataset.iconMounted === name) return;
    el.innerHTML = iconMarkup(name, { size: Number(size) });
    el.dataset.iconMounted = name;
  });
}
