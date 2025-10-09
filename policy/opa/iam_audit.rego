package truckercore.iam.audit

# Deny if audit event details appear to contain raw email addresses (PII leak)
deny[msg] {
  input.module == "iam"
  some e
  e := input.diff.audit_events_created[_]
  contains(lower(e.details), "@")
  msg := "PII leak in iam_audit_events.details"
}
