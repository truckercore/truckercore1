import { logJSON } from "../functions/_lib/redacting_logger.ts";

Deno.test("logger redacts PII", () => {
  const spy = console.log;
  let out = "";
  // @ts-ignore
  console.log = (s: string) => (out = s);
  logJSON("info", { event: "x", driver_name: "Moise", lat: 1, status: "ok" });
  console.log = spy;
  const obj = JSON.parse(out);
  if (obj.driver_name !== "[REDACTED]") throw new Error("PII not redacted");
  if (obj.event !== "x" || obj.status !== "ok") throw new Error("Allowed keys broken");
});
