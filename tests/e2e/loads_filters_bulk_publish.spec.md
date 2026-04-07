# E2E Spec: Loads Filters + Bulk Publish (near-cap)

Goal: Validate filters persist and narrow results; bulk publish honors Free cap (20 active) with partial success summary; counters/KPIs update.

Environment: Desktop web browsers (Chromium, Firefox, WebKit) using existing Playwright setup under apps/web.

Preconditions:
- Seed an org with planTier = Free.
- Ensure activeLoadsCount = 18 before test start; have at least 7 draft loads in the list so we can select 5.

Steps:
1) Navigate to Loads page
- Open /loads
- Expect list renders with rows (> 0).

2) Apply filters and verify persistence
- Set Status = Draft
- Set pickup date range to [today-7d, today]
- Type Origin = "Columbus" (debounced 300ms)
- Type Destination = "Nashville"
- Select Equipment = Dry Van
- Assert active filter chips present; list shrinks or shows empty with contextual clear-all.
- Reload page; assert filters persist (chips restored).

3) Clear filters
- Click "Clear all"; assert chips gone; list returns to default 7-day window.

4) Bulk publish near cap (Free)
- With activeLoadsCount=18, select 5 draft rows via header checkbox then manually unselect non-drafts until 5 drafts selected.
- Click Bulk Publish.
- Expect toast summary: ok: 2, skipped: 3 (cap reached), failed: 0.
- Assert at least 2 of the selected rows show status "published".

5) Counters/KPIs reflect changes
- Navigate to dashboard with KPI ribbon or read counters endpoint.
- Assert Open Loads increased by 2.

6) Bulk unpublish
- Filter Status = Published; select 2 recent published loads.
- Click Bulk Unpublish; expect ok: 2.
- Assert statuses flip to draft; KPIs adjust accordingly (-2).

Telemetry assertions (optional):
- Intercept dispatch_events inserts or observability endpoint for events:
  - quick_post_submitted (if Quick Post used)
  - loads_list_filtered
  - bulk_publish_attempted
  - bulk_publish_result
  - cap_reached (skipped_due_to_cap = 3)

Notes:
- Timezone: date range inputs displayed in local; repository sends UTC ISO.
- Accessibility: verify keyboard navigation on filters and bulk buttons; check ARIA labels on row checkboxes.
