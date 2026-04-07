export interface RateCalculation {
  baseRate: number;
  fuelSurcharge: number;
  totalCarrierRate: number;
  suggestedCustomerRate: number;
  margin: number;
  marginPercentage: number;
}

export class RateCalculator {
  private static readonly BASE_RATE_PER_MILE = 2.0; // Base rate per mile
  private static readonly FUEL_SURCHARGE_PERCENTAGE = 0.15; // 15% fuel surcharge
  private static readonly TARGET_MARGIN_PERCENTAGE = 0.20; // 20% margin

  static calculateRate(
    distance: number,
    weight: number,
    equipmentType: string,
    customMarginPercentage?: number
  ): RateCalculation {
    // Calculate base rate considering weight and equipment
    let ratePerMile = this.BASE_RATE_PER_MILE;

    // Adjust for equipment type
    const equipmentMultipliers: Record<string, number> = {
      dry_van: 1.0,
      reefer: 1.3,
      flatbed: 1.2,
      step_deck: 1.4,
      tanker: 1.5,
    };
    ratePerMile *= equipmentMultipliers[equipmentType] || 1.0;

    // Adjust for weight (if over 40,000 lbs, increase rate)
    if (weight > 40000) {
      ratePerMile *= 1.1;
    }

    const baseRate = distance * ratePerMile;
    const fuelSurcharge = baseRate * this.FUEL_SURCHARGE_PERCENTAGE;
    const totalCarrierRate = baseRate + fuelSurcharge;

    // Calculate customer rate with margin
    const marginPercentage = customMarginPercentage ?? this.TARGET_MARGIN_PERCENTAGE;
    const suggestedCustomerRate = totalCarrierRate / (1 - marginPercentage);
    const margin = suggestedCustomerRate - totalCarrierRate;

    return {
      baseRate: Math.round(baseRate * 100) / 100,
      fuelSurcharge: Math.round(fuelSurcharge * 100) / 100,
      totalCarrierRate: Math.round(totalCarrierRate * 100) / 100,
      suggestedCustomerRate: Math.round(suggestedCustomerRate * 100) / 100,
      margin: Math.round(margin * 100) / 100,
      marginPercentage: Math.round(marginPercentage * 10000) / 100,
    };
  }

  static calculateMargin(customerRate: number, carrierRate: number) {
    const margin = customerRate - carrierRate;
    const marginPercentage = (margin / customerRate) * 100;
    return {
      margin: Math.round(margin * 100) / 100,
      marginPercentage: Math.round(marginPercentage * 100) / 100,
    };
  }

  static calculateDistance(lat1: number, lng1: number, lat2: number, lng2: number): number {
    const R = 3959; // Earth's radius in miles
    const dLat = this.toRad(lat2 - lat1);
    const dLng = this.toRad(lng2 - lng1);
    const a =
      Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos(this.toRad(lat1)) *
        Math.cos(this.toRad(lat2)) *
        Math.sin(dLng / 2) *
        Math.sin(dLng / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return Math.round(R * c);
  }

  private static toRad(degrees: number): number {
    return degrees * (Math.PI / 180);
  }
}
