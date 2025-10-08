# Homepage Asset Guide

## Required Assets

### 1) Favicon (favicon.ico)
- Size: 32x32px (multi-resolution ICO preferred)
- Format: ICO (PNG acceptable as temporary fallback)
- Location: `apps/web/public/favicon.ico`

Design:
- Simple "TC" monogram
- Blue (#58A6FF) on dark background (#0F1216)
- High contrast for browser tabs

Tools:
- https://favicon.io/ — Generate from text
- https://realfavicongenerator.net/ — Multi-platform pack

Quick generate (ImageMagick):
```bash
convert -size 32x32 -background "#0F1216" -fill "#58A6FF" \
  -font Arial-Bold -pointsize 20 -gravity center \
  label:"TC" apps/web/public/favicon.ico
```

### 2) Open Graph Image (og-image.png)
- Size: 1200x630px
- Format: PNG or JPEG (<300KB)
- Location: `apps/web/public/og-image.png`

Design:
- Dark background (#0F1216)
- "TruckerCore" wordmark
- Tagline: "Smart Logistics Platform"
- Optional truck emoji/icon 🚛
- 40px safe margin all sides

Validation:
- Twitter: https://cards-dev.twitter.com/validator
- Facebook: https://developers.facebook.com/tools/debug/
- LinkedIn: https://www.linkedin.com/post-inspector/

### 3) Apple Touch Icon (apple-touch-icon.png)
- Size: 180x180px
- Format: PNG (no transparency)
- Location: `apps/web/public/apple-touch-icon.png`

Quick generate (from favicon):
```bash
convert apps/web/public/favicon.ico -resize 180x180 apps/web/public/apple-touch-icon.png
```

### 4) PWA Icons
- `apps/web/public/icon-192.png` (192x192)
- `apps/web/public/icon-512.png` (512x512)
- Format: PNG (transparent background OK)

Design: App launcher style, minimal, high contrast.

Quick generate (from SVG/large PNG):
```bash
convert logo.svg -resize 192x192 apps/web/public/icon-192.png
convert logo.svg -resize 512x512 apps/web/public/icon-512.png
```

## Asset Checklist
- [ ] `apps/web/public/favicon.ico` (32x32)
- [ ] `apps/web/public/og-image.png` (1200x630)
- [ ] `apps/web/public/apple-touch-icon.png` (180x180)
- [ ] `apps/web/public/icon-192.png` (192x192)
- [ ] `apps/web/public/icon-512.png` (512x512)

## Testing Assets

### Favicon
- Load homepage and check the browser tab icon is not the default.

### OG Image
- Share https://truckercore.com on Twitter, Facebook, LinkedIn, and Slack — preview should show the image and correct title/description.

### PWA Icons
- On Android Chrome: Menu → Add to Home screen → verify icon quality on home screen.

## Fallback Strategy
If assets are not ready, the site will use browser defaults and no OG image will appear. For development, generate placeholders with:

```bash
npm run generate:assets
npm run check:homepage-assets
```

Note: Placeholder generator writes PNGs. Replace with final branded assets before production.

## Brand Guidelines

### Logo Usage
- Primary: "TruckerCore" wordmark
- Icon: Stylized truck or "TC" monogram
- Colors: Blue (#58A6FF) on dark, white on light

### Typography
- System sans-serif
- Weights: 400 (regular), 600 (semibold), 700 (bold)

### Imagery
- Modern, tech-forward, professional
- Prefer flat illustrations and subtle gradients; avoid dated stock photos