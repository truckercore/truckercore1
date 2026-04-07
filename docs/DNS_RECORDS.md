# TruckerCore DNS Records Configuration

## Canonical DNS Table

**Copy these records into your DNS provider (e.g., Namecheap Advanced DNS)**

| Type  | Host      | Value                                    | TTL       |
|-------|-----------|------------------------------------------|-----------|
| A     | @         | `76.76.21.21`                           | Automatic |
| CNAME | www       | `cname.vercel-dns.com`                  | Automatic |
| CNAME | app       | `cname.vercel-dns.com`                  | Automatic |
| CNAME | api       | `<your-ref>.functions.supabase.co`      | Automatic |
| CNAME | downloads | `<your-ref>.supabase.co`                | Automatic |

---

## How to Find Your Supabase Reference

Your Supabase reference is in your project URL:

```
https://app.supabase.com/project/<your-ref>
^^^^^^^^^ This part!
```

Or check your `.env.local`:

```
NEXT_PUBLIC_SUPABASE_URL=https://<your-ref>.supabase.co
^^^^^^^^^
```

**Example:**
If your URL is `https://abcdefgh12345678.supabase.co`, then:
- API CNAME: `abcdefgh12345678.functions.supabase.co`
- Downloads CNAME: `abcdefgh12345678.supabase.co`

---

## Verification Commands

```bash
# Check all DNS records
npm run dns:check

# Open configuration guide
npm run dns:guide

# CI assertion (for automated checks)
npm run dns:ci
```

---

## What "Good" Looks Like

When you run `npm run dns:check`, you should see:

```
truckercore.com
  Root domain → Vercel
  ✅ 76.76.21.21

www.truckercore.com
  WWW subdomain → Vercel
  ✅ cname.vercel-dns.com.

app.truckercore.com
  App subdomain → Vercel
  ✅ cname.vercel-dns.com.

api.truckercore.com
  API subdomain → Supabase Edge Functions
  ✅ abcdefgh12345678.functions.supabase.co.

downloads.truckercore.com
  Downloads subdomain → Supabase Storage
  ✅ abcdefgh12345678.supabase.co.

══════════════════════════════════════════════════
✅ All DNS records configured correctly!
```

---

## Provider-Specific Instructions

### Namecheap
- Login to Namecheap
- Go to Domain List → Manage (next to truckercore.com)
- Click "Advanced DNS" tab
- Delete any existing conflicting records
- Add records from table above:
  - For "Host": Use @ for root, or subdomain name
  - For "Value": Copy exact value from table
  - For "TTL": Select "Automatic"

### Vercel Dashboard (Alternative)
- Go to https://vercel.com/your-org/truckercore1/settings/domains
- Click "Add Domain"
- Enter: truckercore.com
- Follow verification steps
- Repeat for www.truckercore.com and app.truckercore.com

---

## Troubleshooting

"No A record found" for root domain
- Fix: Add A record pointing to 76.76.21.21

"Wrong IP" for root domain
- Fix: Update A record to 76.76.21.21

"No CNAME record found" for subdomains
- Fix: Add CNAME records as shown in table

Changes not taking effect
- Wait: DNS propagation takes 5-10 minutes (sometimes up to 24 hours)
- Check multiple DNS servers:

```bash
# Cloudflare DNS
dig @1.1.1.1 truckercore.com +short

# Google DNS
dig @8.8.8.8 truckercore.com +short

# Your ISP DNS (default)
dig truckercore.com +short
```

Clear local DNS cache:

```bash
# macOS
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder

# Windows
ipconfig /flushdns

# Linux
sudo systemd-resolve --flush-caches
```

---

## Success Checklist

Before deploying to production:

```bash
# 1. DNS check passes
npm run dns:check
# All ✅

# 2. Domains resolve
curl -I https://truckercore.com
curl -I https://app.truckercore.com
# Both return 200 OK

# 3. SSL valid
curl https://truckercore.com
# No certificate warnings

# 4. Vercel dashboard shows valid
# Visit: https://vercel.com/your-org/truckercore1/settings/domains
# Should show "Valid Configuration" ✅
```

Last Updated: 2025-09-30
