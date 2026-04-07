// jobs/build_status_feed.mjs
// Builds a JSON status feed with checksum (sha-256) and size for a list of files.
// Usage: node jobs/build_status_feed.mjs path1,url1 path2,url2 ... > status_feed.json
import { readFile } from 'fs/promises'
import crypto from 'node:crypto'

function fileIntegrity(buf) {
  const sha256 = crypto.createHash('sha256').update(buf).digest('hex')
  return { size: buf.length, sha256 }
}

function parseArgs(argv) {
  // each arg: 
  const items = []
  for (const arg of argv.slice(2)) {
    const [path, url] = arg.split(',')
    if (!path || !url) continue
    items.push({ id: crypto.randomUUID(), path, url, updatedAt: new Date().toISOString() })
  }
  return items
}

async function buildStatusFeed(items) {
  const enriched = []
  for (const i of items) {
    const buf = await readFile(i.path)
    const { size, sha256 } = fileIntegrity(buf)
    enriched.push({ id: i.id, url: i.url, size, sha256, updated_at: i.updatedAt })
  }
  return { generated_at: new Date().toISOString(), items: enriched }
}

async function main() {
  const items = parseArgs(process.argv)
  const feed = await buildStatusFeed(items)
  process.stdout.write(JSON.stringify(feed, null, 2))
}

main().catch((e) => { console.error(e); process.exit(1) })
