Deno.serve(async (req)=>{
  if(req.method!=='POST') return new Response('method',{status:405});
  const { current_lat, current_lon } = await req.json();
  return new Response(JSON.stringify({ stop: { name:'FuelMax 112', save_per_gal: 0.18, detour_min: 4 } }), {headers:{'content-type':'application/json'}});
});