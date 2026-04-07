class Address {
  final String line1;
  final String city;
  final String state;
  final String postal;
  final String country;
  const Address({required this.line1, required this.city, required this.state, required this.postal, required this.country});

  Map<String, dynamic> toJson() => {
    'line1': line1, 'city': city, 'state': state, 'postal': postal, 'country': country
  };
}

class Tender {
  final String id;
  final String shipperOrgId;
  final Address pickup;
  final Address dropoff;
  final String commodity;
  final double weightKg;
  final String equipment;
  final DateTime? earliestPickup;
  final DateTime? latestDelivery;
  final String status;
  final String? notes;

  Tender({
    required this.id,
    required this.shipperOrgId,
    required this.pickup,
    required this.dropoff,
    required this.commodity,
    required this.weightKg,
    required this.equipment,
    this.earliestPickup,
    this.latestDelivery,
    required this.status,
    this.notes,
  });

  Map<String, dynamic> toInsert() => {
    'shipper_org_id': shipperOrgId,
    'pickup_address': pickup.toJson(),
    'dropoff_address': dropoff.toJson(),
    'commodity': commodity,
    'weight_kg': weightKg,
    'equipment': equipment,
    'earliest_pickup': earliestPickup?.toIso8601String(),
    'latest_delivery': latestDelivery?.toIso8601String(),
    'notes': notes,
    'status': status,
  };
}

class TenderQuote {
  final String id;
  final String tenderId;
  final String bidderOrgId;
  final int priceCents;
  final String currency;
  final int? etaHours;
  final String status;
  final String? notes;

  TenderQuote({
    required this.id,
    required this.tenderId,
    required this.bidderOrgId,
    required this.priceCents,
    required this.currency,
    this.etaHours,
    required this.status,
    this.notes,
  });

  Map<String, dynamic> toInsert() => {
    'tender_id': tenderId,
    'bidder_org_id': bidderOrgId,
    'price_cents': priceCents,
    'currency': currency,
    'eta_hours': etaHours,
    'notes': notes,
  };
}
