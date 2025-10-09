#!/usr/bin/env bash
set -euo pipefail

: "${DB_URL:?set DB_URL}"
: "${AWS_S3_BUCKET:=s3://private-evidence}"
: "${EVIDENCE_RETENTION_DAYS:=90}"

TS=$(date -u +"%Y-%m-%dT%H-%M-%SZ")
tmp=$(mktemp -d)

psql "$DB_URL" -c "\\copy (select * from audit_log where created_at >= now() - interval '24 hours') to '$tmp/audit_log_$TS.csv' csv header"
psql "$DB_URL" -c "\\copy (select * from function_slo_last_24h) to '$tmp/function_slo_last_24h_$TS.csv' csv header"
psql "$DB_URL" -c "\\copy (select * from rls_validation_results order by ran_at desc limit 1) to '$tmp/rls_validation_results_$TS.csv' csv header"
psql "$DB_URL" -c "\\copy (select * from secrets_registry) to '$tmp/secrets_registry_$TS.csv' csv header"

# Create tarball and SHA256 manifest
ART="evidence_${TS}.tar.gz"
pushd "$tmp" >/dev/null
  tar -czf "$ART" .
  shasum -a 256 "$ART" > "${ART}.sha256" || sha256sum "$ART" > "${ART}.sha256"
  # Optional: GPG detached signature if GPG available and key is configured in env
  if command -v gpg >/dev/null 2>&1 && [ -n "${GPG_SIGN:=}" ]; then
    gpg --batch --yes --armor --detach-sign "$ART" || true
  fi
popd >/dev/null

# Compute Governance retention until date (ISO8601)
RET_DATE=$(date -u -d "+${EVIDENCE_RETENTION_DAYS} days" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -v+${EVIDENCE_RETENTION_DAYS}d -u +"%Y-%m-%dT%H:%M:%SZ")

# Upload raw CSVs folder for convenience
aws s3 cp "$tmp/" "$AWS_S3_BUCKET/$TS/" --recursive --sse AES256
# Upload tarball + checksum with Object Lock (if bucket configured)
aws s3 cp "$tmp/$ART" "$AWS_S3_BUCKET/$TS/" \
  --sse AES256 \
  --object-lock-mode GOVERNANCE \
  --object-lock-retain-until-date "$RET_DATE" || \
  aws s3 cp "$tmp/$ART" "$AWS_S3_BUCKET/$TS/" --sse AES256
aws s3 cp "$tmp/${ART}.sha256" "$AWS_S3_BUCKET/$TS/" --sse AES256 || true
if [ -f "$tmp/${ART}.asc" ]; then
  aws s3 cp "$tmp/${ART}.asc" "$AWS_S3_BUCKET/$TS/" --sse AES256 || true
fi

echo "[ok] evidence snapshot uploaded to $AWS_S3_BUCKET/$TS/ (retention ${EVIDENCE_RETENTION_DAYS}d)"
