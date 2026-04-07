// supabase/functions/user-profile-router/index.ts
// Simple header-based router to forward to versioned user-profile functions.
// If client sets x-tc-func-ver: v2, routes to user-profile-v2; otherwise v1.

export default Deno.serve(async (req) => {
  const ver = req.headers.get('x-tc-func-ver') === 'v2' ? 'user-profile-v2' : 'user-profile-v1';
  const url = new URL(req.url);
  url.pathname = `/functions/v1/${ver}`;
  return await fetch(url.toString(), { method: req.method, headers: req.headers, body: req.body });
});
