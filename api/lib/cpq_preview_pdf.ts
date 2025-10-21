// api/lib/cpq_preview_pdf.ts
import { writeFile } from "node:fs/promises";

type LineItem = { description: string; qty: number; unit_cents: number };
export type Quote = {
  org_name: string;
  locations: number;
  plan_band: "199" | "349" | "499";
  prepay: "monthly" | "quarterly" | "annual";
  discounts: string[]; // textual
  line_items: LineItem[];
  terms: string;
  valid_until_iso: string;
};

export async function renderQuotePreview(quote: Quote) {
  const sum = quote.line_items.reduce((a, li) => a + li.qty * li.unit_cents, 0);
  const fmt = (c: number) => `$${(c / 100).toFixed(2)}`;
  const body = [
    `Quote Preview — ${quote.org_name}`,
    `Plan: ${quote.plan_band} • Locations: ${quote.locations} • Prepay: ${quote.prepay}`,
    `Valid Until: ${quote.valid_until_iso}`,
    ``,
    `Line Items:`,
    ...quote.line_items.map(
      (li) => `  - ${li.description} x${li.qty} @ ${fmt(li.unit_cents)} = ${fmt(li.qty * li.unit_cents)}`
    ),
    ``,
    `Discounts:`,
    ...(quote.discounts.length ? quote.discounts.map((d) => `  - ${d}`) : ["  - None"]),
    ``,
    `Subtotal: ${fmt(sum)}`,
    ``,
    `Terms:`,
    quote.terms,
    ``,
    `Preview only — not a tax invoice.`,
  ].join("\n");

  const filename = `quote_preview_${Date.now()}.txt`; // replace with real PDF engine
  await writeFile(filename, body, "utf8");
  return { filename, contentType: "text/plain" };
}
