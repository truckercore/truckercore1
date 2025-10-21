// probes/lib/with_retries.js
export async function runFlakeTolerant(fn, attempts = 3, delays = [200, 800]) {
  const results = [];
  for (let i = 0; i < attempts; i++) {
    try {
      results.push(await fn());
      if (results[results.length - 1]?.status === 'pass') return { status: 'pass', runs: results };
    } catch (e) {
      results.push({ status: 'fail', error: String(e?.message || e) });
    }
    if (i < delays.length) await new Promise(r => setTimeout(r, delays[i]));
  }
  const passCount = results.filter(r => r.status === 'pass').length;
  return passCount >= 2 ? { status: 'degraded', runs: results } : { status: 'fail', runs: results, details: { hint: 'flaky' } };
}
