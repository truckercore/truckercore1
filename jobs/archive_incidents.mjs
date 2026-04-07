// jobs/archive_incidents.mjs
// Archive resolved incidents older than 180d to S3 Glacier and mark archived_at.
// Env: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, AWS_REGION, ARCHIVE_BUCKET

import { createClient } from '@supabase/supabase-js';
import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
const AWS_REGION = process.env.AWS_REGION;
const BUCKET = process.env.ARCHIVE_BUCKET;

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  console.error('[archive] Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY');
  process.exit(1);
}
if (!AWS_REGION || !BUCKET) {
  console.error('[archive] Missing AWS_REGION or ARCHIVE_BUCKET');
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
const s3 = new S3Client({ region: AWS_REGION });

function s3KeyForIncident(row) {
  const d = new Date(row.created_at);
  const year = d.getUTCFullYear();
  return `incidents/year=${year}/id=${row.id}.json`;
}

async function* fetchCandidates(pageSize = 1000) {
  let from = 0;
  while (true) {
    const to = from + pageSize - 1;
    const { data, error } = await supabase
      .from('v_incidents_archive_candidates')
      .select('*')
      .range(from, to);
    if (error) throw error;
    if (!data || data.length === 0) return;
    for (const row of data) yield row;
    if (data.length < pageSize) return;
    from += pageSize;
  }
}

async function main() {
  let archived = 0;
  for await (const row of fetchCandidates(1000)) {
    const key = s3KeyForIncident(row);
    const body = JSON.stringify(row);
    await s3.send(new PutObjectCommand({
      Bucket: BUCKET,
      Key: key,
      Body: body,
      StorageClass: 'GLACIER'
    }));
    // optional: mark archived_at
    const { error } = await supabase
      .from('safety_incidents')
      .update({ archived_at: new Date().toISOString() })
      .eq('id', row.id);
    if (error) throw error;
    archived++;
    if (archived % 50 === 0) console.log(`[archive] archived ${archived}...`);
  }
  console.log(`[archive] done; archived=${archived}`);
}

main().catch((e) => {
  console.error('[archive] error', e);
  process.exit(1);
});
