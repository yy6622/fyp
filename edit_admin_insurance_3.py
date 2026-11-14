import io
path = "admin_web/admin/insurance.html"
with io.open(path, encoding="utf-8") as f:
    s = f.read()

def r1(old, new, s):
    n = s.count(old)
    if n != 1:
        raise SystemExit(f"expected 1, found {n}: {old[:160]!r}")
    return s.replace(old, new, 1)

# 3. Imports: listPlans (already imported? no) + setPlanStatus.
old = 'import { listTransactions, listClaims, listPartners, setPartnerStatus } from "../js/data.js?v=20261110c";'
new = 'import { listTransactions, listClaims, listPartners, setPartnerStatus, listPlans, setPlanStatus } from "../js/data.js?v=20261113a";'
s = r1(old, new, s)

# Also bump the ui.js import version on this file since ui.js changed too.
old = 'from "../js/ui.js?v=20261110c";'
new = 'from "../js/ui.js?v=20261113a";'
s = r1(old, new, s)

# 4. State vars
old = '''let txns = [], claims = [], insurancePartners = [];
let txnFiltered = [], txnPage = 1;
let partnerFiltered = [], partnerPage = 1;
const PAGE_SIZE = 8;'''
new = '''let txns = [], claims = [], insurancePartners = [], plans = [];
let txnFiltered = [], txnPage = 1;
let partnerFiltered = [], partnerPage = 1;
let planFiltered = [], planPage = 1;
const PAGE_SIZE = 8;'''
s = r1(old, new, s)

# 5. load(): fetch plans too, compute pending-plans dot.
old = '''async function load() {
  const [transactions, claimsList, partnersList] = await Promise.all([listTransactions(), listClaims(), listPartners()]);
  txns = transactions;
  claims = claimsList;
  insurancePartners = partnersList;
  populateTxnPartnerFilter();
  const pendingCount = insurancePartners.filter((p) => p.status === "pending" || !p.status).length;
  document.getElementById("partnersTabDot").style.display = pendingCount ? "" : "none";
  showTab(activeTab);
}'''
new = '''async function load() {
  const [transactions, claimsList, partnersList, plansList] = await Promise.all([listTransactions(), listClaims(), listPartners(), listPlans()]);
  txns = transactions;
  claims = claimsList;
  insurancePartners = partnersList;
  plans = plansList;
  populateTxnPartnerFilter();
  populatePlanPartnerFilter();
  const pendingCount = insurancePartners.filter((p) => p.status === "pending" || !p.status).length;
  document.getElementById("partnersTabDot").style.display = pendingCount ? "" : "none";
  const pendingPlanCount = plans.filter((p) => p.status === "pending_review").length;
  document.getElementById("plansTabDot").style.display = pendingPlanCount ? "" : "none";
  showTab(activeTab);
}'''
s = r1(old, new, s)

# 6. showTab(): toggle planSection visibility too.
old = '''  document.getElementById("txnSection").style.display = tab === "transactions" ? "" : "none";
  document.getElementById("partnerSection").style.display = tab === "partners" ? "" : "none";
  document.getElementById("exportBtn").style.display = tab === "transactions" ? "" : "none";
  renderStats();
  if (tab === "transactions") applyTxnFilters(); else applyPartnerFilters();
}'''
new = '''  document.getElementById("txnSection").style.display = tab === "transactions" ? "" : "none";
  document.getElementById("partnerSection").style.display = tab === "partners" ? "" : "none";
  document.getElementById("planSection").style.display = tab === "plans" ? "" : "none";
  document.getElementById("exportBtn").style.display = tab === "transactions" ? "" : "none";
  renderStats();
  if (tab === "transactions") applyTxnFilters();
  else if (tab === "partners") applyPartnerFilters();
  else applyPlanFilters();
}'''
s = r1(old, new, s)

# 7. requestedTab default: allow ?tab=plans deep link too.
old = 'let activeTab = requestedTab === "partners" ? "partners" : "transactions";'
new = 'let activeTab = requestedTab === "partners" ? "partners" : requestedTab === "plans" ? "plans" : "transactions";'
s = r1(old, new, s)

with io.open(path, "w", encoding="utf-8") as f:
    f.write(s)
print("step3 ok")
