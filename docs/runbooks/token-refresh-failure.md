# Runbook: Token Refresh Failure

## Symptoms
- 401/403 errors from vendor APIs after token expiry
- Increased authentication failures in logs
- Reduced successful call rate

## Diagnosis
1. Confirm auth error rates and messages:
```
docker logs integration-service 2>&1 | grep -E "Unauthorized|401|403" | tail -100
```
2. Validate current token/secret expiry (check secrets manager / env vars).
3. Ensure clock skew is not excessive (> 2 minutes) on host/container.

## Mitigation
- Rotate or refresh tokens using the Advanced Secrets Manager / vendor console.
- Restart the service if it needs to reload credentials after rotation.
- Temporarily reduce write operations until auth is stable.

## Recovery
- Verify successful authenticated calls resume.
- Monitor error rates for 15 minutes.

## Prevention
- Enable automatic rotation schedules and alerting before expiry.
- Store multiple versions with overlap during rotation cutover.
- Use least‑privilege scopes and separate keys per environment/tenant.

## Post‑Incident
- Record expiry timeline and rotation events
- Update rotation intervals and alert thresholds if needed
