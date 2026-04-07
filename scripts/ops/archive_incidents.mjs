import { S3Client, PutObjectCommand, ListObjectsV2Command, DeleteObjectsCommand } from '@aws-sdk/client-s3';
import { createRequire } from 'module';
const require = createRequire(import.meta.url);

const s3 = new S3Client({ region: process.env.AWS_REGION || 'us-east-1' });
const BUCKET = process.env.INCIDENT_BUCKET;
const KEEP_DAYS = Number(process.env.INCIDENT_RETENTION_DAYS || 180);

export async function archiveIncident(row) {
  if (!BUCKET) throw new Error('INCIDENT_BUCKET not set');
  const d = new Date(row.created_at || Date.now());
  const year = d.getUTCFullYear();
  const key = `incidents/year=${year}/id=${row.id}.json`;
  const body = JSON.stringify(row);
  await s3.send(new PutObjectCommand({ Bucket: BUCKET, Key: key, Body: body, ContentType: 'application/json' }));
  return key;
}

export async function pruneIncidentArchives() {
  if (!BUCKET) throw new Error('INCIDENT_BUCKET not set');
  const cutoff = Date.now() - KEEP_DAYS * 24 * 3600 * 1000;
  let ContinuationToken;
  const toDelete = [];
  do {
    const res = await s3.send(new ListObjectsV2Command({ Bucket: BUCKET, Prefix: 'incidents/', ContinuationToken }));
    ContinuationToken = res.IsTruncated ? res.NextContinuationToken : undefined;
    for (const obj of res.Contents || []) {
      const lastMod = new Date(obj.LastModified).getTime();
      if (lastMod < cutoff) {
        toDelete.push({ Key: obj.Key });
      }
    }
  } while (ContinuationToken);

  if (toDelete.length) {
    for (let i = 0; i < toDelete.length; i += 1000) {
      const chunk = toDelete.slice(i, i + 1000);
      await s3.send(new DeleteObjectsCommand({ Bucket: BUCKET, Delete: { Objects: chunk } }));
    }
  }
  return toDelete.length;
}

if (process.argv[1] && process.argv[1].endsWith('archive_incidents.mjs')) {
  pruneIncidentArchives().then((cnt) => {
    console.log(`[incidents] pruned ${cnt} archived objects`);
  }).catch((e) => {
    console.error(e);
    process.exit(1);
  });
}
