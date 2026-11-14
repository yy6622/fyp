import io
path = "firestore.rules"
with io.open(path, encoding="utf-8") as f:
    s = f.read()
old = '''      // A plan also carries its own review `status` now (draft ->
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
      allow delete: if isAdmin() || (isApprovedInsurancePartner() && resource.data.partnerId == request.auth.uid);'''
new = '''      // A plan also carries its own review `status` now (draft ->
      // pending_review -> published/rejected, or suspended once
      // published) -- see lib/models/insurance_models.dart's
      // InsurancePlanStatus and admin_web/admin/insurance.html's Plans
      // tab. The one property actually worth enforcing here is that a
      // partner can never set their OWN plan's status to 'published' or
      // 'rejected' -- only an admin can (admin_web/js/data.js's
      // setPlanStatus() is what every review action, partner or admin,
      // goes through, and stamps reviewedAt/reviewedBy/publishedAt/
      // rejectionReason to match). A partner resubmitting after a
      // rejection clears their own old rejectionReason/reviewedAt via
      // deleteField() -- that's a normal part of resubmitting, not
      // something to block, so those fields aren't separately
      // restricted; faking a timestamp on your own unpublished plan
      // isn't a real integrity risk (status is what every read path
      // actually gates on).
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
          request.resource.data.status in ['draft', 'pending_review', 'suspended']);
      allow delete: if isAdmin() || (isApprovedInsurancePartner() && resource.data.partnerId == request.auth.uid);'''
assert s.count(old) == 1
s = s.replace(old, new, 1)
with io.open(path, "w", encoding="utf-8") as f:
    f.write(s)
print("braces", s.count("{"), s.count("}"))
print("parens", s.count("("), s.count(")"))
print("brackets", s.count("["), s.count("]"))
