import React, { useState } from 'react';
import { z } from 'zod';
import { CarrierVerificationService } from '../services/carrierVerificationService';
import { Carrier } from '../types/freight';

const carrierSchema = z.object({
  companyName: z.string().min(2, 'Company name is required'),
  mcNumber: z.string().min(6, 'MC number must be at least 6 digits'),
  dotNumber: z.string().min(7, 'DOT number must be at least 7 digits'),
  contactName: z.string().min(2, 'Contact name is required'),
  email: z.string().email('Invalid email address'),
  phone: z.string().regex(/^\d{10}$/, 'Phone must be 10 digits'),
});

type CarrierFormData = z.infer<typeof carrierSchema>;

interface CarrierOnboardingDialogProps {
  isOpen: boolean;
  onClose: () => void;
  onAddCarrier: (carrier: Partial<Carrier>) => Promise<void>;
}

export const CarrierOnboardingDialog: React.FC<CarrierOnboardingDialogProps> = ({
  isOpen,
  onClose,
  onAddCarrier,
}) => {
  const [formData, setFormData] = useState<Partial<CarrierFormData>>({});
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [isVerifying, setIsVerifying] = useState(false);
  const [verificationResult, setVerificationResult] = useState<any>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);

  if (!isOpen) return null;

  const handleInputChange = (field: keyof CarrierFormData, value: string) => {
    setFormData((prev) => ({ ...prev, [field]: value }));
    if ((errors as any)[field]) {
      setErrors((prev) => {
        const newErrors = { ...prev } as any;
        delete newErrors[field as string];
        return newErrors;
      });
    }
  };

  const handleVerifyMC = async () => {
    if (!formData.mcNumber || (formData.mcNumber as string).length < 6) {
      setErrors((prev) => ({ ...prev, mcNumber: 'Please enter a valid MC number' }));
      return;
    }

    setIsVerifying(true);
    setVerificationResult(null);

    try {
      const fmcsaResult = await CarrierVerificationService.verifyMCNumber(formData.mcNumber as string);
      const insuranceResult = await CarrierVerificationService.verifyInsurance(
        formData.mcNumber as string
      );

      setVerificationResult({
        ...fmcsaResult,
        insurance: insuranceResult,
      });

      // Auto-fill some fields if verified
      if (fmcsaResult.status === 'active') {
        setFormData((prev) => ({
          ...prev,
          companyName: fmcsaResult.legalName,
          dotNumber: fmcsaResult.dotNumber,
        }));
      }
    } catch (error) {
      setErrors((prev) => ({
        ...prev,
        mcNumber: 'Verification failed. Please check the MC number.',
      }));
    } finally {
      setIsVerifying(false);
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setErrors({});

    try {
      const result = carrierSchema.parse(formData);

      if (!verificationResult || verificationResult.status !== 'active') {
        alert('Please verify the MC number before submitting');
        return;
      }

      setIsSubmitting(true);

      const carrier: Partial<Carrier> = {
        id: `CARR-${Date.now()}`,
        companyName: result.companyName,
        mcNumber: result.mcNumber,
        dotNumber: result.dotNumber,
        contactName: result.contactName,
        email: result.email,
        phone: result.phone,
        status: 'approved',
        rating: 0,
        totalLoads: 0,
        onTimeDeliveryRate: 0,
        insuranceVerified: verificationResult.insurance?.verified || false,
        insuranceExpiry: verificationResult.insurance?.expiryDate || '',
        authorityStatus: verificationResult.status,
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      };

      await onAddCarrier(carrier);
      onClose();
      setFormData({});
      setVerificationResult(null);
    } catch (error) {
      if (error instanceof z.ZodError) {
        const newErrors: Record<string, string> = {};
        error.errors.forEach((err) => {
          if (err.path[0]) {
            newErrors[err.path[0] as string] = err.message;
          }
        });
        setErrors(newErrors);
      }
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div className="bg-white rounded-lg shadow-xl max-w-2xl w-full m-4 max-h-[90vh] overflow-y-auto">
        <div className="sticky top-0 bg-white border-b px-6 py-4 flex justify-between items-center">
          <h2 className="text-2xl font-bold text-gray-900">Onboard New Carrier</h2>
          <button
            onClick={onClose}
            className="text-gray-400 hover:text-gray-600 text-2xl"
          >
            ×
          </button>
        </div>

        <form onSubmit={handleSubmit} className="p-6 space-y-6">
          {/* MC Number Verification */}
          <div className="bg-blue-50 p-4 rounded-lg">
            <h3 className="text-lg font-semibold mb-3 text-gray-900">MC Number Verification</h3>
            <div className="flex gap-3">
              <div className="flex-1">
                <input
                  type="text"
                  placeholder="Enter MC Number"
                  value={formData.mcNumber || ''}
                  onChange={(e) => handleInputChange('mcNumber', e.target.value)}
                  className={`w-full px-3 py-2 border rounded-lg ${
                    (errors as any).mcNumber ? 'border-red-500' : 'border-gray-300'
                  }`}
                />
                {(errors as any).mcNumber && (
                  <p className="text-red-500 text-sm mt-1">{(errors as any).mcNumber}</p>
                )}
              </div>
              <button
                type="button"
                onClick={handleVerifyMC}
                disabled={isVerifying}
                className="px-6 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 font-semibold disabled:bg-gray-400"
              >
                {isVerifying ? 'Verifying...' : 'Verify'}
              </button>
            </div>

            {verificationResult && (
              <div className="mt-4 p-3 bg-white rounded border">
                <div className="grid grid-cols-2 gap-3 text-sm">
                  <div>
                    <p className="text-gray-600">Status:</p>
                    <p
                      className={`font-semibold ${
                        verificationResult.status === 'active'
                          ? 'text-green-600'
                          : 'text-red-600'
                      }`}
                    >
                      {verificationResult.status.toUpperCase()}
                    </p>
                  </div>
                  <div>
                    <p className="text-gray-600">DOT Number:</p>
                    <p className="font-semibold">{verificationResult.dotNumber}</p>
                  </div>
                  <div>
                    <p className="text-gray-600">Insurance:</p>
                    <p
                      className={`font-semibold ${
                        verificationResult.insurance?.verified
                          ? 'text-green-600'
                          : 'text-red-600'
                      }`}
                    >
                      {verificationResult.insurance?.verified ? 'VERIFIED ✓' : 'NOT VERIFIED'}
                    </p>
                  </div>
                  {verificationResult.insurance?.expiryDate && (
                    <div>
                      <p className="text-gray-600">Insurance Expiry:</p>
                      <p className="font-semibold">
                        {new Date(
                          verificationResult.insurance.expiryDate
                        ).toLocaleDateString()}
                      </p>
                    </div>
                  )}
                </div>
              </div>
            )}
          </div>

          {/* Company Information */}
          <div>
            <h3 className="text-lg font-semibold mb-3 text-gray-900">Company Information</h3>
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Company Name *
                </label>
                <input
                  type="text"
                  value={formData.companyName || ''}
                  onChange={(e) => handleInputChange('companyName', e.target.value)}
                  className={`w-full px-3 py-2 border rounded-lg ${
                    (errors as any).companyName ? 'border-red-500' : 'border-gray-300'
                  }`}
                />
                {(errors as any).companyName && (
                  <p className="text-red-500 text-sm mt-1">{(errors as any).companyName}</p>
                )}
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  DOT Number *
                </label>
                <input
                  type="text"
                  value={formData.dotNumber || ''}
                  onChange={(e) => handleInputChange('dotNumber', e.target.value)}
                  className={`w-full px-3 py-2 border rounded-lg ${
                    (errors as any).dotNumber ? 'border-red-500' : 'border-gray-300'
                  }`}
                />
                {(errors as any).dotNumber && (
                  <p className="text-red-500 text-sm mt-1">{(errors as any).dotNumber}</p>
                )}
              </div>
            </div>
          </div>

          {/* Contact Information */}
          <div>
            <h3 className="text-lg font-semibold mb-3 text-gray-900">Contact Information</h3>
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Contact Name *
                </label>
                <input
                  type="text"
                  value={formData.contactName || ''}
                  onChange={(e) => handleInputChange('contactName', e.target.value)}
                  className={`w-full px-3 py-2 border rounded-lg ${
                    (errors as any).contactName ? 'border-red-500' : 'border-gray-300'
                  }`}
                />
                {(errors as any).contactName && (
                  <p className="text-red-500 text-sm mt-1">{(errors as any).contactName}</p>
                )}
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Email *
                </label>
                <input
                  type="email"
                  value={formData.email || ''}
                  onChange={(e) => handleInputChange('email', e.target.value)}
                  className={`w-full px-3 py-2 border rounded-lg ${
                    (errors as any).email ? 'border-red-500' : 'border-gray-300'
                  }`}
                />
                {(errors as any).email && <p className="text-red-500 text-sm mt-1">{(errors as any).email}</p>}
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Phone (10 digits) *
                </label>
                <input
                  type="tel"
                  value={formData.phone || ''}
                  onChange={(e) => handleInputChange('phone', e.target.value.replace(/\D/g, ''))}
                  maxLength={10}
                  className={`w-full px-3 py-2 border rounded-lg ${
                    (errors as any).phone ? 'border-red-500' : 'border-gray-300'
                  }`}
                />
                {(errors as any).phone && <p className="text-red-500 text-sm mt-1">{(errors as any).phone}</p>}
              </div>
            </div>
          </div>

          {/* Action Buttons */}
          <div className="flex justify-end gap-4 pt-4 border-t">
            <button
              type="button"
              onClick={onClose}
              className="px-6 py-2 border border-gray-300 rounded-lg hover:bg-gray-50 font-semibold"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={isSubmitting || !verificationResult}
              className="px-6 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 font-semibold disabled:bg-gray-400"
            >
              {isSubmitting ? 'Adding...' : 'Add Carrier'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};
