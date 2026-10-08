import io

# ============== 1. Fix the Chart.js CDN version (4.4.4 404s — use 4.5.1) ==============
for path in ["admin_web/admin/reports.html", "admin_web/partner/reports.html"]:
    with io.open(path, "r", encoding="utf-8") as f:
        content = f.read()
    old = '<script src="https://cdnjs.cloudflare.com/ajax/libs/Chart.js/4.4.4/chart.umd.min.js"></script>'
    assert content.count(old) == 1, f"{path}: chart cdn anchor count={content.count(old)}"
    new = '<script src="https://cdnjs.cloudflare.com/ajax/libs/Chart.js/4.5.1/chart.umd.min.js"></script>'
    content = content.replace(old, new, 1)
    with io.open(path, "w", encoding="utf-8") as f:
        f.write(content)
    print(path, "chart.js version fixed")

# ============== 2. Replace the Traveller/Insurance Partner pill-tabs with a dropdown ==============
path = "admin_web/admin/reports.html"
with io.open(path, "r", encoding="utf-8") as f:
    content = f.read()

old_render = '''async function renderUserAccountReports() {
  document.getElementById("reportBody").innerHTML = `
    <div class="tabs" id="uarSubTabs" style="margin-bottom:20px;">
      <button class="tab-btn${uarSubTab === "traveller" ? " active" : ""}" data-sub="traveller">Traveller</button>
      <button class="tab-btn${uarSubTab === "partner" ? " active" : ""}" data-sub="partner">Insurance Partner</button>
    </div>
    <div id="uarSubBody"><div class="skeleton" style="height:200px;"></div></div>`;
  document.querySelectorAll("#uarSubTabs .tab-btn").forEach((b) => b.addEventListener("click", async () => {
    if (b.dataset.sub === uarSubTab) return;
    uarSubTab = b.dataset.sub;
    document.querySelectorAll("#uarSubTabs .tab-btn").forEach((t) => t.classList.toggle("active", t === b));
    data = null;
    await renderUserAccountSubPage();
  }));
  await renderUserAccountSubPage();
}'''
assert content.count(old_render) == 1, f"old_render count={content.count(old_render)}"

new_render = '''async function renderUserAccountReports() {
  document.getElementById("reportBody").innerHTML = `
    <div class="filter-bar" style="margin-bottom:20px;">
      <select class="select" id="uarSubSelect">
        <option value="traveller">Traveller</option>
        <option value="partner">Insurance Partner</option>
      </select>
    </div>
    <div id="uarSubBody"><div class="skeleton" style="height:200px;"></div></div>`;
  document.getElementById("uarSubSelect").value = uarSubTab;
  document.getElementById("uarSubSelect").addEventListener("change", async (e) => {
    uarSubTab = e.target.value;
    data = null;
    await renderUserAccountSubPage();
  });
  await renderUserAccountSubPage();
}'''

content = content.replace(old_render, new_render, 1)
with io.open(path, "w", encoding="utf-8") as f:
    f.write(content)
print("admin/reports.html sub-tab -> dropdown done, length", len(content))
