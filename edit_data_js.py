import io
path = "admin_web/js/data.js"
with io.open(path, encoding="utf-8") as f:
    s = f.read()

def replace_once(old, new, s):
    n = s.count(old)
    if n != 1:
        raise SystemExit(f"expected 1, found {n}: {old[:100]!r}")
    return s.replace(old, new, 1)

old = """export async function deletePlan(id) {
  await deleteDoc(doc(db, "insurance_plans", id));
}
"""
new = """export async function deletePlan(id) {
  await deleteDoc(doc(db, "insurance_plans", id));
}
/**
 * Moves one plan through the draft -> pending_review -> published /
 * rejected -> suspended review workflow -- the per-PLAN counterpart of
 * setPartnerStatus() above (per-ORGANIZATION), same reasoning: every
 * review action goes through one function so every page that can trigger
 * one (partner/plan-form.html submitting/resubmitting, admin/insurance.html
 * approving/rejecting/suspending/republishing) stamps the same audit
 * fields the same way, instead of each page writing its own slightly
 * different update.
 * - pending_review -> stamps submittedAt, clears rejectionReason/
 *   reviewedAt/reviewedBy (a resubmission starts review fresh).
 * - published -> stamps publishedAt + reviewedAt/reviewedBy, clears
 *   rejectionReason (an approval after a past rejection shouldn't still
 *   show the old reason).
 * - rejected -> stamps reviewedAt/reviewedBy + rejectionReason (passed in
 *   `extra`).
 * - suspended -> stamps suspendedAt. Works the same whether an admin
 *   suspended it or the partner paused their own published plan.
 * `reviewedBy` is the signed-in admin's uid -- only ever set when an
 * admin calls this (firestore.rules already keeps a partner from setting
 * status to "published"/"rejected" themselves, see insurance_plans rules).
 */
export async function setPlanStatus(id, status, extra = {}) {
  const payload = { status, ...extra };
  if (status === "pending_review") {
    payload.submittedAt = serverTimestamp();
    payload.rejectionReason = deleteField();
    payload.reviewedAt = deleteField();
    payload.reviewedBy = deleteField();
  } else if (status === "published") {
    payload.publishedAt = serverTimestamp();
    payload.reviewedAt = serverTimestamp();
    payload.rejectionReason = deleteField();
  } else if (status === "rejected") {
    payload.reviewedAt = serverTimestamp();
  } else if (status === "suspended") {
    payload.suspendedAt = serverTimestamp();
  }
  await updateDoc(doc(db, "insurance_plans", id), payload);
}
/** Every plan currently waiting on an admin -- used for the sidebar
 * notification dot / stat card the same way countPendingPartners() is. */
export async function countPendingPlans() {
  const items = await listPlans();
  return items.filter((p) => p.status === "pending_review").length;
}
"""
s = replace_once(old, new, s)
with io.open(path, "w", encoding="utf-8") as f:
    f.write(s)
print("braces", s.count("{"), s.count("}"))
print("parens", s.count("("), s.count(")"))
