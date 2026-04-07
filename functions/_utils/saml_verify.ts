// functions/_utils/saml_verify.ts
// Minimal, non-production SAML signature verification helper (skeleton).
// NOTE: For production, use a well-tested XML-DSig implementation.

export interface VerifyExpected {
  audience: string;
  acsUrl: string;
  clockSkewSec: number;
}

export async function verifySamlResponse(xml: string, idpCertPem: string, expected: VerifyExpected): Promise<{ ok: boolean; reason?: string }>{
  try {
    const dom = new DOMParser().parseFromString(xml, "text/xml");
    if (!dom) return { ok: false, reason: "parse_error" };
    const assertion = dom.querySelector("Assertion");
    const response = dom.querySelector("Response");
    const signedNode = assertion || response;
    if (!signedNode) return { ok: false, reason: "no_assertion" };

    const sigValB64 = signedNode.querySelector("SignatureValue")?.textContent?.trim() ?? "";
    const signedInfo = signedNode.querySelector("SignedInfo");
    if (!signedInfo || !sigValB64) return { ok: false, reason: "invalid_signature_node" };

    // Very naive canonicalization placeholder: production must apply proper C14N
    const signedInfoXml = signedInfo.outerHTML;
    const sigBytes = b64ToBytes(sigValB64);

    // Import IdP public key from PEM cert (assumes SPKI extraction ok for most x509 PEMs in modern runtimes)
    const spki = pemCertToArrayBuffer(idpCertPem);
    const key = await crypto.subtle.importKey(
      "spki",
      spki,
      { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
      false,
      ["verify"]
    );

    const ok = await crypto.subtle.verify(
      { name: "RSASSA-PKCS1-v1_5" },
      key,
      sigBytes,
      new TextEncoder().encode(signedInfoXml)
    );
    if (!ok) return { ok: false, reason: "bad_signature" };

    // Conditions
    const audience = dom.querySelector("Audience")?.textContent?.trim();
    const recipient = dom.querySelector("SubjectConfirmationData")?.getAttribute("Recipient");
    const notBefore = dom.querySelector("Conditions")?.getAttribute("NotBefore");
    const notOnOrAfter = dom.querySelector("Conditions")?.getAttribute("NotOnOrAfter");

    if (audience && audience !== expected.audience) return { ok: false, reason: "aud_mismatch" };
    if (recipient && recipient !== expected.acsUrl) return { ok: false, reason: "recipient_mismatch" };
    if (!withinSkew(notBefore, notOnOrAfter, expected.clockSkewSec)) return { ok: false, reason: "time_window" };

    return { ok: true };
  } catch (e) {
    return { ok: false, reason: String((e as any)?.message ?? e) };
  }
}

function withinSkew(nb?: string|null, noa?: string|null, skew = 120) {
  const now = Date.now();
  const okNb = !nb || (now + skew*1000) >= Date.parse(nb);
  const okNoa = !noa || (now - skew*1000) < Date.parse(noa);
  return okNb && okNoa;
}

function b64ToBytes(b64: string): Uint8Array {
  const bin = atob(b64.replace(/\s+/g, ""));
  const arr = new Uint8Array(bin.length);
  for (let i=0;i<bin.length;i++) arr[i] = bin.charCodeAt(i);
  return arr;
}

function pemCertToArrayBuffer(pem: string): ArrayBuffer {
  const b64 = pem.replace(/-----BEGIN CERTIFICATE-----|-----END CERTIFICATE-----|\r|\n|\s+/g, "");
  return b64ToBytes(b64).buffer;
}
