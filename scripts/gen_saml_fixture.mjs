// scripts/gen_saml_fixture.mjs
// Usage:
//   node scripts/gen_saml_fixture.mjs 'https://sp.example.com/saml-acs?org_id=00000000-0000-0000-0000-0000000000F1' 'urn:sp:entity' > fixtures/saml/Response_valid_base64.txt
// Notes:
// - Non-prod probe fixture only. Do NOT use in production.
// - Signs the Assertion with an ephemeral RSA key (unless TEST_SAML_KEY_PEM/TEST_SAML_CERT_PEM provided).

import crypto from 'node:crypto';

const [acsUrl, audience] = process.argv.slice(2);
if (!acsUrl || !audience) {
  console.error('Usage: node scripts/gen_saml_fixture.mjs <acsUrl> <audience>');
  process.exit(2);
}

// Ephemeral non-prod keypair (or load from env)
let privateKey; let publicKey;
if (process.env.TEST_SAML_KEY_PEM) {
  privateKey = crypto.createPrivateKey(process.env.TEST_SAML_KEY_PEM);
  publicKey = crypto.createPublicKey(privateKey);
} else {
  ({ privateKey, publicKey } = crypto.generateKeyPairSync('rsa', { modulusLength: 2048 }));
}

// Time window (±2 min skew)
const now = new Date();
const nb = new Date(now.getTime() - 60_000).toISOString();
const nooa = new Date(now.getTime() + 5 * 60_000).toISOString();

// Simple IDs
const respId = `_R${crypto.randomBytes(10).toString('hex')}`;
const asrtId = `_A${crypto.randomBytes(10).toString('hex')}`;

// Minimal Assertion (non-namespaced simplification for probe only)
const assertion = `
<Assertion ID="${asrtId}" Version="2.0" IssueInstant="${now.toISOString()}">
  <Issuer>urn:nonprod:idp</Issuer>
  <Subject>
    <NameID Format="urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress">probe@nonprod.local</NameID>
    <SubjectConfirmation Method="urn:oasis:names:tc:SAML:2.0:cm:bearer">
      <SubjectConfirmationData Recipient="${acsUrl}" NotOnOrAfter="${nooa}" InResponseTo="${respId}"/>
    </SubjectConfirmation>
  </Subject>
  <Conditions NotBefore="${nb}" NotOnOrAfter="${nooa}">
    <AudienceRestriction><Audience>${audience}</Audience></AudienceRestriction>
  </Conditions>
  <AttributeStatement>
    <Attribute Name="Email"><AttributeValue>probe@nonprod.local</AttributeValue></Attribute>
    <Attribute Name="Groups"><AttributeValue>TC-Probe</AttributeValue></Attribute>
    <Attribute Name="Name"><AttributeValue>Probe User</AttributeValue></Attribute>
  </AttributeStatement>
  <AuthnStatement AuthnInstant="${now.toISOString()}"/>
</Assertion>`.trim();

// Naive SignedInfo (NOT for prod)
const signedInfo = `
<SignedInfo>
  <CanonicalizationMethod Algorithm="http://www.w3.org/2001/10/xml-exc-c14n#"/>
  <SignatureMethod Algorithm="http://www.w3.org/2000/09/xmldsig#rsa-sha256"/>
  <Reference URI="#${asrtId}">
    <DigestMethod Algorithm="http://www.w3.org/2001/04/xmlenc#sha256"/>
    <DigestValue>${crypto.createHash('sha256').update(assertion).digest('base64')}</DigestValue>
  </Reference>
</SignedInfo>`.trim();

const sig = crypto.sign('RSA-SHA256', Buffer.from(signedInfo), privateKey).toString('base64');
const signature = `
<Signature>
  ${signedInfo}
  <SignatureValue>${sig}</SignatureValue>
  <KeyInfo><KeyValue><RSAKeyValue>TEST</RSAKeyValue></KeyValue></KeyInfo>
</Signature>`.trim();

const signedAssertion = assertion.replace('</Assertion>', `${signature}</Assertion>`);

const response = `
<Response ID="${respId}" Version="2.0" IssueInstant="${now.toISOString()}">
  <Issuer>urn:nonprod:idp</Issuer>
  <Status><StatusCode Value="urn:oasis:names:tc:SAML:2.0:status:Success"/></Status>
  ${signedAssertion}
</Response>`.trim();

process.stdout.write(Buffer.from(response).toString('base64'));
