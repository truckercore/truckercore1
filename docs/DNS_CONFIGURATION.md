# DNS Configuration Guide for TruckerCore

## Quick Status Check

```bash
# Run this to check current DNS configuration
./scripts/check-dns.sh
```

---

## Configuration Methods

### Method 1: Vercel Nameservers (Easiest) ✅

Advantages:
- Automatic SSL certificates
- Automatic www → non-www redirects
- Fastest DNS propagation
- Managed by Vercel

Setup Steps:
1. In Vercel Dashboard:
   - https://vercel.com/your-org/truckercore1/settings/domains
   - Click "Add Domain"
   - Enter: `truckercore.com`
   - Vercel will show you the nameservers to use

2. In Your Domain Registrar:
   - Find DNS/Nameserver settings
   - Replace existing nameservers with:
     - ns1.vercel-dns.com
     - ns2.vercel-dns.com

3. Wait for Propagation:
   - Usually 1–2 hours (up to 24 hours)
   - Check status: `./scripts/check-dns.sh`

4. Verify:
```bash
# Should list Vercel nameservers
dig truckercore.com NS +short
```

---

### Method 2: A & CNAME Records (Advanced)

Use this method if you want to keep your current DNS provider (for example, if you also manage MX/email records there).

Root Domain (truckercore.com)
- A Record:
  - Type: A
  - Name: @ (or leave blank)
  - Value: 76.76.21.21
  - TTL: 300
- Alternative (if provider supports CNAME at root):
  - Type: CNAME
  - Name: @ (or leave blank)
  - Value: cname.vercel-dns.com
  - TTL: 300

WWW Subdomain
- Type: CNAME
- Name: www
- Value: cname.vercel-dns.com
- TTL: 300

App Subdomain
- Type: CNAME
- Name: app
- Value: cname.vercel-dns.com
- TTL: 300

API Subdomain (Supabase)
- Type: CNAME
- Name: api
- Value: YOUR_PROJECT_ID.supabase.co
- TTL: 300

Downloads Subdomain (Supabase Storage)
- Type: CNAME
- Name: downloads
- Value: YOUR_PROJECT_ID.supabase.co
- TTL: 300

Note: Replace `YOUR_PROJECT_ID` with your actual Supabase project ID.

---

## Provider-Specific Instructions

### Namecheap
1. Login → Domain List → Manage → Advanced DNS
2. Nameservers:
   - For Vercel Nameservers: set `ns1.vercel-dns.com`, `ns2.vercel-dns.com`
3. Or add A/CNAME records as listed above.

### GoDaddy
1. Login → My Products → Domains → DNS
2. Nameservers:
   - For Vercel Nameservers: set `ns1.vercel-dns.com`, `ns2.vercel-dns.com`
3. Or add A/CNAME records as listed above.

### Cloudflare
- Using Vercel nameservers is not compatible with Cloudflare.
- Use A/CNAME records instead and set Proxy status to "DNS only" (grey cloud).

### Google Domains
1. Login → Select domain → DNS
2. Nameservers:
   - For Vercel Nameservers: set `ns1.vercel-dns.com`, `ns2.vercel-dns.com`
3. Or add A/CNAME records as listed above.

---

## Verification Steps

1) Check DNS Propagation
```bash
./scripts/check-dns.sh
# From multiple resolvers
dig @8.8.8.8 truckercore.com +short   # Google DNS
dig @1.1.1.1 truckercore.com +short   # Cloudflare DNS
```

2) Check in Browser
```bash
open https://truckercore.com
open https://www.truckercore.com
open https://app.truckercore.com
```

3) Verify SSL Certificate
```bash
curl -vI https://truckercore.com 2>&1 | grep -i "SSL certificate"
```

---

## Troubleshooting

Domain Not Resolving
- `dig truckercore.com +short` is empty → Wait for propagation, clear local DNS cache, verify records in provider.
- Clear DNS cache:
```bash
# macOS
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder
# Linux
sudo systemd-resolve --flush-caches
# Windows
ipconfig /flushdns
```

SSL Certificate Error
- Wait 5–10 minutes after DNS changes for Vercel to provision SSL.
- Ensure domain is added in the Vercel dashboard.

404 Error
- Domain resolves but shows 404:
  - Run: `./scripts/debug-vercel-404.sh`
  - Check deployment status in Vercel dashboard

---

## Propagation Timeline
- Add A/CNAME record: 5–10 minutes
- Change nameservers: 1–24 hours
- SSL certificate: 5–10 minutes after DNS
- Full global propagation: up to 48 hours

Most changes are live within 10–30 minutes, but some ISPs cache DNS longer.

---

## Support
- Check Propagation: https://www.whatsmydns.net/#A/truckercore.com
- Vercel Docs: https://vercel.com/docs/concepts/projects/domains
- Contact Support: support@vercel.com
- Community: https://github.com/vercel/vercel/discussions

Last Updated: 2025-09-30
