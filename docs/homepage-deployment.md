# Homepage Deployment Checklist

## Pre-Deployment

- [x] App Router homepage (`app/page.tsx`)
- [x] Layout with metadata (`app/layout.tsx`)
- [x] Global styles (`app/globals.css`)
- [x] Sitemap generation (`app/sitemap.ts`)
- [x] Robots.txt (`apps/web/public/robots.txt`)
- [x] 404 page (`app/not-found.tsx`)
- [x] Loading state (`app/loading.tsx`)
- [x] PWA manifest (`apps/web/public/manifest.json`)

## Assets Needed

- [ ] `/apps/web/public/favicon.ico`
- [ ] `/apps/web/public/apple-touch-icon.png`
- [ ] `/apps/web/public/og-image.png` (1200x630)
- [ ] `/apps/web/public/icon-192.png`
- [ ] `/apps/web/public/icon-512.png`

## SEO Configuration

- [x] Page metadata (title, description, keywords)
- [x] Open Graph tags
- [x] Twitter Card tags
- [x] Canonical URLs
- [ ] Google Search Console verification
- [ ] Google Analytics (if needed)

## Testing

- [ ] Test all anchor links (`#features`)
- [ ] Test external links (app.truckercore.com)
- [ ] Verify mobile responsiveness
- [ ] Check hover states
- [ ] Lighthouse score (aim for >90)
- [ ] Accessibility audit (WCAG AA)
- [ ] Browser compatibility (Chrome, Firefox, Safari, Edge)

## Deployment

```bash
# Local test
npm run dev
open http://localhost:3000

# Build
npm run build

# Production test
npm run start
```

## Post-Deployment

- [ ] Verify https://truckercore.com/ shows homepage (not 404)
- [ ] Test sitemap: https://truckercore.com/sitemap.xml
- [ ] Test robots.txt: https://truckercore.com/robots.txt
- [ ] Submit sitemap to Google Search Console
- [ ] Test social sharing (OG image appears)
- [ ] Monitor Core Web Vitals
- [ ] Check Analytics (if configured)

## Performance Targets

- LCP: < 2.5s
- FID: < 100ms
- CLS: < 0.1
- Lighthouse Performance: > 90
- Lighthouse Accessibility: > 95

## Success Criteria

✅ Homepage loads without 404
✅ All sections render correctly
✅ CTAs link to app.truckercore.com
✅ Mobile responsive
✅ SEO metadata complete
✅ Sitemap accessible
