# How To Page On-Call for Security

When to Page
- SEV1/SEV2 incidents (see runbooks/severity_matrix.md).
- Suspected key compromise, data exfiltration, or active exploitation.
- Repeated webhook signature failures/replays across multiple orgs.

How to Page
1) Open PagerDuty/On-call tool and select schedule: Security On-Call.
2) Provide: short title, severity, and link to war room doc/channel.
3) Include correlation_id(s) and affected org_id(s) if known.
4) If paging fails, escalate via backup contact tree.

Escalation Tree
- Primary Security On-Call -> Secondary Security -> Head of Security -> CTO.

After Paging
- Create war room (#inc-<yyyymmdd>-<slug>), assign IC and Comms Lead.
- Start incident doc from runbooks/war_room_template.md.
- Send initial internal comms using runbooks/comms_templates.md.
