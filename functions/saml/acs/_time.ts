// functions/saml/acs/_time.ts
export function validTime(notBefore?: string, notOnOrAfter?: string, skewSec = 300) {
  const now = Date.now();
  const nb = notBefore ? Date.parse(notBefore) - skewSec * 1000 : -Infinity;
  const na = notOnOrAfter ? Date.parse(notOnOrAfter) + skewSec * 1000 : Infinity;
  return now >= nb && now <= na;
}
