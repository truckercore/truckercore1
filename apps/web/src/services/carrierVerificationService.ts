interface FMCSAResponse {
  mcNumber: string;
  legalName: string;
  dbaName?: string;
  status: 'active' | 'inactive';
  insuranceOnFile: boolean;
  insuranceExpiry?: string;
  dotNumber: string;
}

export class CarrierVerificationService {
  // In production, this would call FMCSA's API
  // https://mobile.fmcsa.dot.gov/developer/
  static async verifyMCNumber(mcNumber: string): Promise<FMCSAResponse> {
    try {
      // Simulated API call - Replace with actual FMCSA API
      // const response = await fetch(`https://mobile.fmcsa.dot.gov/qc/services/carriers/${mcNumber}`);
      
      // Mock response for development
      await new Promise((resolve) => setTimeout(resolve, 1000));
      
      // Simulate verification
      const isValid = mcNumber.length >= 6;
      
      return {
        mcNumber,
        legalName: `Carrier Company ${mcNumber}`,
        status: isValid ? 'active' : 'inactive',
        insuranceOnFile: isValid,
        insuranceExpiry: isValid
          ? new Date(Date.now() + 365 * 24 * 60 * 60 * 1000).toISOString()
          : undefined,
        dotNumber: `${parseInt(mcNumber) + 1000000}`,
      };
    } catch (error) {
      throw new Error(`Failed to verify MC#: ${mcNumber}`);
    }
  }

  static async verifyInsurance(mcNumber: string): Promise<{
    verified: boolean;
    expiryDate?: string;
    coverageAmount?: number;
  }> {
    try {
      // In production, integrate with insurance verification service
      await new Promise((resolve) => setTimeout(resolve, 800));
      
      return {
        verified: true,
        expiryDate: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000).toISOString(),
        coverageAmount: 1000000, // $1M coverage
      };
    } catch (error) {
      throw new Error('Insurance verification failed');
    }
  }

  static isInsuranceExpiringSoon(expiryDate: string, daysThreshold: number = 30): boolean {
    const expiry = new Date(expiryDate);
    const now = new Date();
    const daysUntilExpiry = (expiry.getTime() - now.getTime()) / (1000 * 60 * 60 * 24);
    return daysUntilExpiry <= daysThreshold;
  }
}
