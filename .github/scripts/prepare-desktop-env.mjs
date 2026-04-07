import { writeFileSync } from "fs";
const sha = process.env.GIT_COMMIT || process.env.VERCEL_GIT_COMMIT_SHA || "";
writeFileSync("apps/web/.env.local", `NEXT_PUBLIC_BUILD_SHA=${sha}\nNEXT_PUBLIC_SHELL_VERSION=${process.env.npm_package_version || ""}\n`);
console.log("Prepared desktop env");
