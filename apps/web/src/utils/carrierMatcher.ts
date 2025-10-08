import type { Carrier, Load } from '../types/freight';

interface CarrierMatch {
  carrier: Carrier;
  score: number;
  reasons: string[];
}

export class CarrierMatcher {
  static findMatchingCarriers(
    load: Load,
    carriers: Carrier[],
    limit: number = 10
  ): CarrierMatch[] {
    const matches: CarrierMatch[] = carriers
      .filter((carrier) => carrier.status === 'approved' && carrier.insuranceVerified)
      .map((carrier) => {
        const { score, reasons } = this.calculateMatchScore(load, carrier);
        return { carrier, score, reasons };
      })
      .sort((a, b) => b.score - a.score)
      .slice(0, limit);

    return matches;
  }

  private static calculateMatchScore(
    load: Load,
    carrier: Carrier
  ): { score: number; reasons: string[] } {
    let score = 0;
    const reasons: string[] = [];

    // High rating (up to 30 points)
    if (carrier.rating >= 4.5) {
      score += 30;
      reasons.push('Excellent rating');
    } else if (carrier.rating >= 4.0) {
      score += 20;
      reasons.push('Good rating');
    } else if (carrier.rating >= 3.5) {
      score += 10;
      reasons.push('Average rating');
    }

    // On-time delivery rate (up to 30 points)
    if (carrier.onTimeDeliveryRate >= 95) {
      score += 30;
      reasons.push('Excellent on-time delivery');
    } else if (carrier.onTimeDeliveryRate >= 90) {
      score += 20;
      reasons.push('Good on-time delivery');
    } else if (carrier.onTimeDeliveryRate >= 85) {
      score += 10;
      reasons.push('Average on-time delivery');
    }

    // Experience (up to 20 points)
    if (carrier.totalLoads >= 100) {
      score += 20;
      reasons.push('Highly experienced');
    } else if (carrier.totalLoads >= 50) {
      score += 15;
      reasons.push('Experienced');
    } else if (carrier.totalLoads >= 20) {
      score += 10;
      reasons.push('Moderately experienced');
    }

    // Insurance verified (20 points)
    if (carrier.insuranceVerified) {
      score += 20;
      reasons.push('Insurance verified');
    }

    return { score, reasons };
  }

  static getRecommendedRate(matches: CarrierMatch[], calculatedRate: number): number {
    if (matches.length === 0) return calculatedRate;

    // If we have high-quality carriers, we might be able to negotiate better
    const topCarrier = matches[0];
    if (topCarrier.score >= 80) {
      return calculatedRate * 0.95; // 5% discount for top carriers
    } else if (topCarrier.score >= 60) {
      return calculatedRate * 0.98; // 2% discount for good carriers
    }

    return calculatedRate;
  }
}
