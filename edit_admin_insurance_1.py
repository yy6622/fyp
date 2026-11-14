import io
path = "admin_web/admin/insurance.html"
with io.open(path, encoding="utf-8") as f:
    s = f.read()

def r1(old, new, s):
    n = s.count(old)
    if n != 1:
        raise SystemExit(f"expected 1, found {n}: {old[:120]!r}")
    return s.replace(old, new, 1)

# 1. Tabs: add Plans tab button
old = '''    <div class="tabs" id="insuranceTabs">
      <button class="tab-btn active" data-tab="transactions">Transactions</button>
      <button class="tab-btn" data-tab="partners">Partners<span class="tab-alert-dot" id="partnersTabDot" style="display:none;" title="New partner requests"></span></button>
    </div>'''
new = '''    <div class="tabs" id="insuranceTabs">
      <button class="tab-btn active" data-tab="transactions">Transactions</button>
      <button class="tab-btn" data-tab="partners">Partners<span class="tab-alert-dot" id="partnersTabDot" style="display:none;" title="New partner requests"></span></button>
      <button class="tab-btn" data-tab="plans">Plans<span class="tab-alert-dot" id="plansTabDot" style="display:none;" title="Plans awaiting review"></span></button>
    </div>'''
s = r1(old, new, s)

with io.open(path, "w", encoding="utf-8") as f:
    f.write(s)
print("step1 ok")
