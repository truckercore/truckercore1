// JavaScript
// Simple script to create placeholder text files that remind you to add real icons
const fs = require('fs');
const path = require('path');

const icons = [
  'icon-192.png',
  'icon-512.png',
  'apple-touch-icon.png',
  'og-image.png',
  'favicon.ico',
];

const publicDir = path.join(process.cwd(), 'public');
if (!fs.existsSync(publicDir)) fs.mkdirSync(publicDir, { recursive: true });

icons.forEach((icon) => {
  const filepath = path.join(publicDir, icon);
  if (!fs.existsSync(filepath)) {
    const message = `# Placeholder for ${icon}\n# Replace with actual image before production launch\n# Recommended tool: https://favicon.io/ or Figma export`;
    fs.writeFileSync(filepath, message);
    console.log(`✓ Created placeholder: ${icon}`);
  } else {
    console.log(`- Already exists: ${icon}`);
  }
});

console.log('\n✅ Icon placeholders created. Replace with real images before launch!');
