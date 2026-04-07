// apps/web/src/hooks/useFeatureCatalog.ts
import type { FeatureCatalogItem } from "@/components/UpsellCard.types";

export async function fetchFeatureCatalog(locale?: string): Promise<FeatureCatalogItem[]> {
  const res = await fetch(`/api/feature_catalog${locale ? `?locale=${encodeURIComponent(locale)}` : ""}`);
  const data = await res.json();
  return (data.items ?? []) as FeatureCatalogItem[];
}
