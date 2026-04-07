export type UpsellTier = 'premium' | 'ai';

export type FeatureCatalogItem = {
  key: string;
  tier: UpsellTier;
  headline: string;
  blurb?: string;
  runbook_url?: string;
  price_id: string;
  variant?: string;
  locale?: string;
};

export type UpsellCardProps = {
  orgId?: string;
  item: FeatureCatalogItem;
  entLoaded: boolean;             // entitlements resolved
  disabled?: boolean;             // additional parent gate
  token: string;                  // auth for create_checkout
  onCheckoutUrl?: (url: string) => void; // override navigation for tests
  onAfterSuccess?: () => void;    // called after redirect returns
  logEvt: (e: any) => void;       // central logger
};
