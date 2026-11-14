import io
path = "firestore.rules"
with io.open(path, encoding="utf-8") as f:
    s = f.read()
old = '''    match /insurance_plans/{id} {
      // Any signed-in user (Flutter app riders, or the console) can read
      // plans; only the owning, *approved* partner or an admin may write
      // one — a pending or suspended partner's console hides the
      // Add/Edit/Delete actions for this same reason (plans.html), this
      // is the rule that actually enforces it.
      allow read: if isSignedIn();
      allow create: if isAdmin() ||
        (isApprovedInsurancePartner() && request.resource.data.partnerId == request.auth.uid);
      // update also pins request.resource.data.partnerId to the existing
      // owner, so an owning partner can't reassign a plan to someone else
      // by editing its partnerId field mid-update.
      allow update: if isAdmin() ||
        (isApprovedInsurancePartner() && resource.data.partnerId == request.auth.uid &&
          request.resource.data.partnerId == request.auth.uid);
      allow delete: if isAdmin() || (isApprovedInsurancePartner() && resource.data.partnerId == request.auth.uid);
    }'''
new = '''    match /insurance_plans/{id} {
      // Any signed-in user (Flutter app riders, or the console) can read
      // plans; only the owning, *approved* partner or an admin may write
      // one — a pending or suspended partner's console hides the
      // Add/Edit/Delete actions for this same reason (plans.html), this
      // is the rule that actually enforces it.
      //
      // A plan also carries its own review `status` now (draft ->
      // pending_review -> published/rejected, or suspended once
      // published) -- see lib/models/insurance_models.dart's
      // InsurancePlanStatus and admin_web/admin/insurance.html's Plans
      // tab. A partner may only ever set their own plan to draft,
      // pending_review or suspended; only an admin can move one to
      // published or rejected, so a partner can never self-publish or
      // self-clear a rejection by writing straight to Firestore. A
      // partner also can't touch the review-audit fields themselves
      // (admin_web/js/data.js's setPlanStatus() is what stamps these).
      allow read: if isSignedIn();
      allow create: if isAdmin() ||
        (isApprovedInsurancePartner() && request.resource.data.partnerId == request.auth.uid &&
          request.resource.data.status in ['draft', 'pending_review']);
      // update also pins request.resource.data.partnerId to the existing
      // owner, so an owning partner can't reassign a plan to someone else
      // by editing its partnerId field mid-update.
      allow update: if isAdmin() ||
        (isApprovedInsurancePartner() && resource.data.partnerId == request.auth.uid &&
          request.resource.data.partnerId == request.auth.uid &&
          request.resource.data.status in ['draft', 'pending_review', 'suspended'] &&
          !request.resource.data.diff(resource.data).affectedKeys()
            .hasAny(['reviewedAt', 'reviewedBy', 'rejectionReason', 'publishedAt']));
      allow delete: if isAdmin() || (isApprovedInsurancePartner() && resource.data.partnerId == request.auth.uid);
    }'''
assert s.count(old) == 1
s = s.replace(old, new, 1)
with io.open(path, "w", encoding="utf-8") as f:
    f.write(s)
print("braces", s.count("{"), s.count("}"))
print("parens", s.count("("), s.count(")"))
print("brackets", s.count("["), s.count("]"))
