import { writeFileSync, readdirSync, readFileSync } from "fs";
import crypto from "crypto";

const CDN = process.env.CDN_BASE || "https://downloads.truckercore.com";
const version = (process.env.VERSION || "v0.0.0").replace(/^v/, "");
const files = readdirSync("artifacts");

const sha256 = (name) => crypto.createHash("sha256").update(readFileSync(`artifacts/${name}`)).digest("hex");
const find = (re) => files.find((f) => re.test(f));

const dmga = find(new RegExp(`TruckerCore_${version}_aarch64\\.dmg$`));
const dmgx = find(new RegExp(`TruckerCore_${version}_x64\\.dmg$`));
const msix = find(new RegExp(`TruckerCore_${version}_x64\\.msixbundle$`));
const debAmd = find(new RegExp(`truckercore_${version}_amd64\\.deb$`));
const debArm = find(new RegExp(`truckercore_${version}_arm64\\.deb$`));

const entry = (name) => name ? ({
  url: `${CDN}/stable/${version}/${name}`,
  signature: process.env.TAURI_SIGNATURE || "REPLACE_WITH_REAL",
  sha256: sha256(name)
}) : undefined;

const payload = {
  version,
  notes: process.env.RELEASE_NOTES || "Auto update.",
  pub_date: new Date().toISOString(),
  platforms: {
    "darwin-aarch64": entry(dmga),
    "darwin-x86_64": entry(dmgx),
    "windows-x86_64": entry(msix),
    "linux-x86_64": entry(debAmd),
    "linux-aarch64": entry(debArm)
  }
};

Object.keys(payload.platforms).forEach((k) => !payload.platforms[k] && delete payload.platforms[k]);

writeFileSync("artifacts/latest.json", JSON.stringify(payload, null, 2));
console.log("Wrote artifacts/latest.json");
