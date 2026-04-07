# Dashboard: Data Access Anomalies

Charts
- rls_denied_total over time by org/user
- Unusual query volume per org/user (z-score baseline)
- Data exports/downloads count by type

Breakdowns
- By table, policy, endpoint

Signals
- Sudden spikes in denied access for a single org
- Large export operations without prior approval window

Links
- Alerts: RLS denials, privileged actions
- Runbooks: runbooks/tabletop_drills.md (Data Exfil decision tree)
