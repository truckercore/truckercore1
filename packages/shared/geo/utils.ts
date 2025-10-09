export function toRad(d: number){ return (d * Math.PI) / 180 }
export function haversineMeters(a:[number,number], b:[number,number]){
  const R=6371000
  const dLat=toRad(b[0]-a[0]), dLng=toRad(b[1]-a[1])
  const s1=Math.sin(dLat/2)**2
  const s2=Math.cos(toRad(a[0]))*Math.cos(toRad(b[0]))*Math.sin(dLng/2)**2
  return 2*R*Math.asin(Math.sqrt(s1+s2))
}

/** Approx off-route distance as min of end-point distances (fast, conservative). */
export function offRouteDistanceM(pos:[number,number], route:[number,number][]): number{
  if (!route || route.length<2) return Infinity
  let min=Number.POSITIVE_INFINITY
  for(let i=0;i<route.length;i++){
    const d = haversineMeters(pos, route[i])
    if(d<min) min=d
  }
  return min
}

/** Is speeding above limit with configurable buffer (kph). */
export function isSpeeding(speedKph:number, limitKph:number, bufferKph=8): boolean{
  if(!limitKph || limitKph<=0) return false
  return speedKph > (limitKph + bufferKph)
}
