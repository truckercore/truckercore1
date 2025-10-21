class FeatureCatalogItem {
  final String key;
  final String tier; // 'premium' | 'ai'
  final String headline;
  final String? blurb;
  final String? runbookUrl;
  final String priceId;
  final String? variant;
  final String? locale;

  FeatureCatalogItem({
    required this.key,
    required this.tier,
    required this.headline,
    this.blurb,
    this.runbookUrl,
    required this.priceId,
    this.variant,
    this.locale,
  });
}

typedef LogEvt = void Function(Map<String, dynamic> e);

class UpsellCardProps {
  final String? orgId;
  final FeatureCatalogItem item;
  final bool entLoaded; // entitlements resolved
  final bool disabled; // extra parent gate
  final String token; // auth for checkout
  final Future<void> Function(String url)? onCheckoutUrl;
  final Future<void> Function()? onAfterSuccess;
  final LogEvt logEvt;

  UpsellCardProps({
    required this.item,
    required this.entLoaded,
    required this.token,
    required this.logEvt,
    this.orgId,
    this.disabled = false,
    this.onCheckoutUrl,
    this.onAfterSuccess,
  });
}
