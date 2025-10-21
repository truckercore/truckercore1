# Secrets Handling

- Never commit secrets to the repo. Use environment managers (e.g., GitHub Actions secrets, cloud secret stores).
- Rotate credentials regularly; track rotation in CHANGELOG or internal tracker.
- Separate environments (dev/stage/prod) with distinct secrets; least privilege access.
- Do not log secrets. Our logger (api/lib/logging.ts) redacts common tokens/passwords/emails. Add fields to the redaction set before logging.
- Webhook secrets must be stored securely and rotated; signatures verified with timestamp skew and replay resistance (api/lib/webhook.ts).
- For highly sensitive fields, prefer application-layer encryption with key rotation (see forthcoming util scaffold).
