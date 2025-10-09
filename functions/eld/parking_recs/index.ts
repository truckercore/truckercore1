const CORS = {"access-control-allow-origin":"*","access-control-allow-headers":"authorization,content-type","access-control-allow-methods":"GET,OPTIONS"};
Deno.serve(async (req)=>{
  if(req.method==='OPTIONS') return new Response('',{headers:CORS});
  const url = new URL(req.url);
  const lat = Number(url.searchParams.get('lat')); const lon = Number(url.searchParams.get('lon'));
  const results = [{id: 'poi-1', name:'SafeStop A', lat:lat+0.02, lon:lon-0.01, rating:4.7, spaces: 8}];
  return new Response(JSON.stringify({results}), {headers:{...CORS,"content-type":"application/json"}});
});