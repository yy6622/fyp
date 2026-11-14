import io
path = "admin_web/admin/insurance.html"
with io.open(path, encoding="utf-8") as f:
    s = f.read()

def r1(old, new, s):
    n = s.count(old)
    if n != 1:
        raise SystemExit(f"expected 1, found {n}: {old[:160]!r}")
    return s.replace(old, new, 1)

# 2. New "Plans" tab section HTML, inserted right after partnerSection's
# closing </div> and before </main> -- same table/filter-bar/pagination
# skeleton as the Transactions/Partners sections above it.
old = '''      <div class="table-foot">
        <p class="small muted" id="partnerResultsLabel"></p>
        <div class="pagination" id="partnerPagination"></div>
      </div>
    </div>
  </main>
</div>'''
new = '''      <div class="table-foot">
        <p class="small muted" id="partnerResultsLabel"></p>
        <div class="pagination" id="partnerPagination"></div>
      </div>
    </div>

    <!-- ==================== Plans tab ==================== -->
    <div id="planSection" style="display:none;">
      <div class="filter-bar">
        <div class="search-input-wrap"><span data-icon="search"></span><input class="input" id="planSearchInput" placeholder="Search plan name or partner…" /></div>
        <select class="select" id="planStatusFilter">
          <option value="">All status</option>
          <option value="pending_review">Pending review</option>
          <option value="published">Published</option>
          <option value="rejected">Rejected</option>
          <option value="suspended">Suspended</option>
          <option value="draft">Draft</option>
        </select>
        <select class="select" id="planPartnerFilter">
          <option value="">All partners</option>
        </select>
      </div>

      <div class="table-wrap scroll-x">
        <table class="data-table">
          <thead><tr><th>Plan name</th><th>Partner</th><th>Trip type</th><th>Premium</th><th>Status</th><th></th></tr></thead>
          <tbody id="planTableBody"><tr><td colspan="6"><div class="skeleton" style="height:40px;"></div></td></tr></tbody>
        </table>
        <div class="empty-state" id="planEmptyState" style="display:none;">
          <span data-icon="briefcase" class="icon-lg"></span>
          <div class="h3">No plans found</div>
          <p class="small">Try a different search or status filter.</p>
        </div>
      </div>
      <div class="table-foot">
        <p class="small muted" id="planResultsLabel"></p>
        <div class="pagination" id="planPagination"></div>
      </div>
    </div>
  </main>
</div>'''
s = r1(old, new, s)

with io.open(path, "w", encoding="utf-8") as f:
    f.write(s)
print("step2 ok")
