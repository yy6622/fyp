import io
path = "admin_web/admin/insurance.html"
with io.open(path, encoding="utf-8") as f:
    s = f.read()

def r1(old, new, s):
    n = s.count(old)
    if n != 1:
        raise SystemExit(f"expected 1, found {n}: {old[:160]!r}")
    return s.replace(old, new, 1)

# 8. renderStats(): add a third branch for the Plans tab.
old = '''  } else {
    const pending = insurancePartners.filter((p) => p.status === "pending" || !p.status).length;
    const approved = insurancePartners.filter((p) => p.status === "approved").length;
    const suspended = insurancePartners.filter((p) => p.status === "suspended").length;
    document.getElementById("statGrid").innerHTML = [
      statCard("Total partners", number(insurancePartners.length), "building", null),
      plainCard("Pending", number(pending), "clock"),
      statCard("Approved", number(approved), "shield-check", null),
      plainCard("Suspended", number(suspended), "x-circle"),
    ].join("");
  }
  mountIcons(document);
}'''
new = '''  } else if (activeTab === "partners") {
    const pending = insurancePartners.filter((p) => p.status === "pending" || !p.status).length;
    const approved = insurancePartners.filter((p) => p.status === "approved").length;
    const suspended = insurancePartners.filter((p) => p.status === "suspended").length;
    document.getElementById("statGrid").innerHTML = [
      statCard("Total partners", number(insurancePartners.length), "building", null),
      plainCard("Pending", number(pending), "clock"),
      statCard("Approved", number(approved), "shield-check", null),
      plainCard("Suspended", number(suspended), "x-circle"),
    ].join("");
  } else {
    const pendingReview = plans.filter((p) => p.status === "pending_review").length;
    const published = plans.filter((p) => p.status === "published" || p.status === "active").length;
    const rejected = plans.filter((p) => p.status === "rejected").length;
    document.getElementById("statGrid").innerHTML = [
      statCard("Total plans", number(plans.length), "briefcase", null),
      plainCard("Pending review", number(pendingReview), "clock"),
      statCard("Published", number(published), "shield-check", null),
      plainCard("Rejected", number(rejected), "x-circle"),
    ].join("");
  }
  mountIcons(document);
}'''
s = r1(old, new, s)

with io.open(path, "w", encoding="utf-8") as f:
    f.write(s)
print("step4 ok")
