// scripts/notify_slack.mjs
// ESM utility that works in Node 18+ (global fetch) and Deno
export async function notifySlack(webhookUrl, title, fields = {}) {
  if (!webhookUrl) throw new Error('notifySlack: webhookUrl is required');
  const blocks = [
    { type: 'header', text: { type: 'plain_text', text: String(title).slice(0, 150) } },
    { type: 'section', text: { type: 'mrkdwn', text: Object.entries(fields).map(([k, v]) => `*${k}:* ${v}`).join('\n') || '(no fields)' } }
  ];
  const res = await fetch(webhookUrl, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ blocks })
  });
  if (!res.ok) {
    const txt = await res.text().catch(() => '');
    throw new Error(`notifySlack: ${res.status} ${res.statusText} ${txt}`);
  }
}

// Allow CLI usage: node scripts/notify_slack.mjs "https://hooks.slack.com/..." "Title" '{"k":"v"}'
if (import.meta.url === `file://${process.argv[1]}`) {
  const [,, url, title = 'Notification', fieldsJson = '{}'] = process.argv;
  const fields = JSON.parse(fieldsJson);
  notifySlack(url, title, fields).then(() => {
    console.log('Sent');
  }).catch((e) => {
    console.error(e);
    process.exit(1);
  });
}
