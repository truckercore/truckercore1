import React, { useState } from 'react';
import { z } from 'zod';
import { RateCalculator } from '../utils/rateCalculator';
import { CarrierMatcher } from '../utils/carrierMatcher';
import { Load, Carrier } from '../types/freight';

const loadSchema = z.object({
  customerName: z.string().min(2, 'Customer name is required'),
  pickupAddress: z.string().min(5, 'Pickup address is required'),
  pickupCity: z.string().min(2, 'Pickup city is required'),
  pickupState: z.string().length(2, 'State must be 2 characters'),
  pickupZip: z.string().regex(/^\d{5}$/, 'ZIP must be 5 digits'),
  deliveryAddress: z.string().min(5, 'Delivery address is required'),
  deliveryCity: z.string().min(2, 'Delivery city is required'),
  deliveryState: z.string().length(2, 'State must be 2 characters'),
  deliveryZip: z.string().regex(/^\d{5}$/, 'ZIP must be 5 digits'),
  pickupDate: z.string().min(1, 'Pickup date is required'),
  deliveryDate: z.string().min(1, 'Delivery date is required'),
  equipmentType: z.enum(['dry_van', 'reefer', 'flatbed', 'step_deck', 'tanker']),
  weight: z.number().min(1, 'Weight must be greater than 0'),
  distance: z.number().min(1, 'Distance must be greater than 0'),
  commodity: z.string().min(2, 'Commodity description is required'),
  customerRate: z.number().min(1, 'Customer rate must be greater than 0'),
  specialInstructions: z.string().optional(),
});

type LoadFormData = z.infer<typeof loadSchema>;

interface LoadCreationDialogProps {
  isOpen: boolean;
  onClose: () => void;
  onCreateLoad: (load: Partial<Load>) => Promise<void>;
  carriers: Carrier[];
}

export const LoadCreationDialog: React.FC<LoadCreationDialogProps> = ({
  isOpen,
  onClose,
  onCreateLoad,
  carriers,
}) => {
  const [formData, setFormData] = useState<Partial<LoadFormData>>({
    equipmentType: 'dry_van',
  });
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [rateCalculation, setRateCalculation] = useState<any>(null);
  const [matchedCarriers, setMatchedCarriers] = useState<any[]>([]);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [showCarrierMatch, setShowCarrierMatch] = useState(false);

  if (!isOpen) return null;

  const handleInputChange = (field: keyof LoadFormData, value: any) => {
    setFormData((prev) => ({ ...prev, [field]: value }));
    // Clear error for this field
    if (errors[field]) {
      setErrors((prev) => {
        const newErrors = { ...prev };
        delete newErrors[field as string];
        return newErrors;
      });
    }
  };

  const handleCalculateRate = () => {
    if (!formData.distance || !formData.weight || !formData.equipmentType) {
      alert('Please fill in distance, weight, and equipment type to calculate rate');
      return;
    }

    const calculation = RateCalculator.calculateRate(
      formData.distance,
      formData.weight,
      formData.equipmentType
    );
    setRateCalculation(calculation);
    setFormData((prev) => ({
      ...prev,
      customerRate: calculation.suggestedCustomerRate,
    }));
  };

  const handleFindCarriers = () => {
    try {
      const result = loadSchema.parse(formData);
      const load: Partial<Load> = {
        customerName: result.customerName,
        pickupLocation: {
          address: result.pickupAddress,
          city: result.pickupCity,
          state: result.pickupState,
          zipCode: result.pickupZip,
        },
        deliveryLocation: {
          address: result.deliveryAddress,
          city: result.deliveryCity,
          state: result.deliveryState,
          zipCode: result.deliveryZip,
        },
        pickupDate: result.pickupDate,
        deliveryDate: result.deliveryDate,
        equipmentType: result.equipmentType,
        weight: result.weight,
        distance: result.distance,
        commodity: result.commodity,
        customerRate: result.customerRate,
      };

      const matches = CarrierMatcher.findMatchingCarriers(load as Load, carriers);
      setMatchedCarriers(matches);
      setShowCarrierMatch(true);
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
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setErrors({});

    try {
      const result = loadSchema.parse(formData);
      setIsSubmitting(true);

      const load: Partial<Load> = {
        id: `LOAD-${Date.now()}`,
        customerId: `CUST-${Date.now()}`,
        customerName: result.customerName,
        status: 'posted',
        pickupLocation: {
          address: result.pickupAddress,
          city: result.pickupCity,
          state: result.pickupState,
          zipCode: result.pickupZip,
        },
        deliveryLocation: {
          address: result.deliveryAddress,
          city: result.deliveryCity,
          state: result.deliveryState,
          zipCode: result.deliveryZip,
        },
        pickupDate: result.pickupDate,
        deliveryDate: result.deliveryDate,
        equipmentType: result.equipmentType,
        weight: result.weight,
        distance: result.distance,
        commodity: result.commodity,
        customerRate: result.customerRate,
        specialInstructions: result.specialInstructions,
        documents: [],
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      };

      await onCreateLoad(load);
      onClose();
      setFormData({ equipmentType: 'dry_van' });
      setRateCalculation(null);
      setMatchedCarriers([]);
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
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 overflow-y-auto">
      <div className="bg-white rounded-lg shadow-xl max-w-4xl w-full m-4 max-h-[90vh] overflow-y-auto">
        <div className="sticky top-0 bg-white border-b px-6 py-4 flex justify-between items-center">
          <h2 className="text-2xl font-bold text-gray-900">Create New Load</h2>
          <button
            onClick={onClose}
            className="text-gray-400 hover:text-gray-600 text-2xl"
          >
            ×
          </button>
        </div>

        <form onSubmit={handleSubmit} className="p-6 space-y-6">
          {/* Customer Information */}
          <div>
            <h3 className="text-lg font-semibold mb-3 text-gray-900">Customer Information</h3>
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Customer Name *
                </label>
                <input
                  type="text"
                  value={formData.customerName || ''}
                  onChange={(e) => handleInputChange('customerName', e.target.value)}
                  className={`w-full px-3 py-2 border rounded-lg ${
                    (errors as any).customerName ? 'border-red-500' : 'border-gray-300'
                  }`}
                />
                {(errors as any).customerName && (
                  <p className="text-red-500 text-sm mt-1">{(errors as any).customerName}</p>
                )}
              </div>
            </div>
          </div>

          {/* Pickup Location */}
          <div>
            <h3 className="text-lg font-semibold mb-3 text-gray-900">Pickup Location</h3>
            <div className="grid grid-cols-2 gap-4">
              <div className="col-span-2">
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Address *
                </label>
                <input
                  type="text"
                  value={formData.pickupAddress || ''}
                  onChange={(e) => handleInputChange('pickupAddress', e.target.value)}
                  className={`w-full px-3 py-2 border rounded-lg ${
                    (errors as any).pickupAddress ? 'border-red-500' : 'border-gray-300'
                  }`}
                />
                {(errors as any).pickupAddress && (
                  <p className="text-red-500 text-sm mt-1">{(errors as any).pickupAddress}</p>
                )}
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">City *</label>
                <input
                  type="text"
                  value={formData.pickupCity || ''}
                  onChange={(e) => handleInputChange('pickupCity', e.target.value)}
                  className={`w-full px-3 py-2 border rounded-lg ${
                    (errors as any).pickupCity ? 'border-red-500' : 'border-gray-300'
                  }`}
                />
                {(errors as any).pickupCity && (
                  <p className="text-red-500 text-sm mt-1">{(errors as any).pickupCity}</p>
                )}
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">State *</label>
                <input
                  type="text"
                  value={formData.pickupState || ''}
                  onChange={(e) => handleInputChange('pickupState', e.target.value.toUpperCase())}
                  maxLength={2}
                  className={`w-full px-3 py-2 border rounded-lg ${
                    (errors as any).pickupState ? 'border-red-500' : 'border-gray-300'
                  }`}
                />
                {(errors as any).pickupState && (
                  <p className="text-red-500 text-sm mt-1">{(errors as any).pickupState}</p>
                )}
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  ZIP Code *
                </label>
                <input
                  type="text"
                  value={formData.pickupZip || ''}
                  onChange={(e) => handleInputChange('pickupZip', e.target.value)}
                  maxLength={5}
                  className={`w-full px-3 py-2 border rounded-lg ${
                    (errors as any).pickupZip ? 'border-red-500' : 'border-gray-300'
                  }`}
                />
                {(errors as any).pickupZip && (
                  <p className="text-red-500 text-sm mt-1">{(errors as any).pickupZip}</p>
                )}
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Pickup Date *
                </label>
                <input
                  type="date"
                  value={formData.pickupDate || ''}
                  onChange={(e) => handleInputChange('pickupDate', e.target.value)}
                  className={`w-full px-3 py-2 border rounded-lg ${
                    (errors as any).pickupDate ? 'border-red-500' : 'border-gray-300'
                  }`}
                />
                {(errors as any).pickupDate && (
                  <p className="text-red-500 text-sm mt-1">{(errors as any).pickupDate}</p>
                )}
              </div>
            </div>
          </div>

          {/* Delivery Location */}
          <div>
            <h3 className="text-lg font-semibold mb-3 text-gray-900">Delivery Location</h3>
            <div className="grid grid-cols-2 gap-4">
              <div className="col-span-2">
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Address *
                </label>
                <input
                  type="text"
                  value={formData.deliveryAddress || ''}
                  onChange={(e) => handleInputChange('deliveryAddress', e.target.value)}
                  className={`w-full px-3 py-2 border rounded-lg ${
                    (errors as any).deliveryAddress ? 'border-red-500' : 'border-gray-300'
                  }`}
                />
                {(errors as any).deliveryAddress && (
                  <p className="text-red-500 text-sm mt-1">{(errors as any).deliveryAddress}</p>
                )}
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">City *</label>
                <input
                  type="text"
                  value={formData.deliveryCity || ''}
                  onChange={(e) => handleInputChange('deliveryCity', e.target.value)}
                  className={`w-full px-3 py-2 border rounded-lg ${
                    (errors as any).deliveryCity ? 'border-red-500' : 'border-gray-300'
                  }`}
                />
                {(errors as any).deliveryCity && (
                  <p className="text-red-500 text-sm mt-1">{(errors as any).deliveryCity}</p>
                )}
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">State *</label>
                <input
                  type="text"
                  value={formData.deliveryState || ''}
                  onChange={(e) =>
                    handleInputChange('deliveryState', e.target.value.toUpperCase())
                  }
                  maxLength={2}
                  className={`w-full px-3 py-2 border rounded-lg ${
                    (errors as any).deliveryState ? 'border-red-500' : 'border-gray-300'
                  }`}
                />
                {(errors as any).deliveryState && (
                  <p className="text-red-500 text-sm mt-1">{(errors as any).deliveryState}</p>
                )}
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  ZIP Code *
                </label>
                <input
                  type="text"
                  value={formData.deliveryZip || ''}
                  onChange={(e) => handleInputChange('deliveryZip', e.target.value)}
                  maxLength={5}
                  className={`w-full px-3 py-2 border rounded-lg ${
                    (errors as any).deliveryZip ? 'border-red-500' : 'border-gray-300'
                  }`}
                />
                {(errors as any).deliveryZip && (
                  <p className="text-red-500 text-sm mt-1">{(errors as any).deliveryZip}</p>
                )}
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Delivery Date *
                </label>
                <input
                  type="date"
                  value={formData.deliveryDate || ''}
                  onChange={(e) => handleInputChange('deliveryDate', e.target.value)}
                  className={`w-full px-3 py-2 border rounded-lg ${
                    (errors as any).deliveryDate ? 'border-red-500' : 'border-gray-300'
                  }`}
                />
                {(errors as any).deliveryDate && (
                  <p className="text-red-500 text-sm mt-1">{(errors as any).deliveryDate}</p>
                )}
              </div>
            </div>
          </div>

          {/* Load Details */}
          <div>
            <h3 className="text-lg font-semibold mb-3 text-gray-900">Load Details</h3>
            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Equipment Type *
                </label>
                <select
                  value={formData.equipmentType}
                  onChange={(e) => handleInputChange('equipmentType', e.target.value as any)}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg"
                >
                  <option value="dry_van">Dry Van</option>
                  <option value="reefer">Reefer</option>
                  <option value="flatbed">Flatbed</option>
                  <option value="step_deck">Step Deck</option>
                  <option value="tanker">Tanker</option>
                </select>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Weight (lbs) *
                </label>
                <input
                  type="number"
                  value={formData.weight || ''}
                  onChange={(e) => handleInputChange('weight', parseFloat(e.target.value))}
                  className={`w-full px-3 py-2 border rounded-lg ${
                    (errors as any).weight ? 'border-red-500' : 'border-gray-300'
                  }`}
                />
                {(errors as any).weight && (
                  <p className="text-red-500 text-sm mt-1">{(errors as any).weight}</p>
                )}
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Distance (miles) *
                </label>
                <input
                  type="number"
                  value={formData.distance || ''}
                  onChange={(e) => handleInputChange('distance', parseFloat(e.target.value))}
                  className={`w-full px-3 py-2 border rounded-lg ${
                    (errors as any).distance ? 'border-red-500' : 'border-gray-300'
                  }`}
                />
                {(errors as any).distance && (
                  <p className="text-red-500 text-sm mt-1">{(errors as any).distance}</p>
                )}
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Commodity *
                </label>
                <input
                  type="text"
                  value={formData.commodity || ''}
                  onChange={(e) => handleInputChange('commodity', e.target.value)}
                  className={`w-full px-3 py-2 border rounded-lg ${
                    (errors as any).commodity ? 'border-red-500' : 'border-gray-300'
                  }`}
                />
                {(errors as any).commodity && (
                  <p className="text-red-500 text-sm mt-1">{(errors as any).commodity}</p>
                )}
              </div>
              <div className="col-span-2">
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Special Instructions
                </label>
                <textarea
                  value={formData.specialInstructions || ''}
                  onChange={(e) => handleInputChange('specialInstructions', e.target.value)}
                  rows={3}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg"
                />
              </div>
            </div>
          </div>

          {/* Rate Calculator */}
          <div className="bg-blue-50 p-4 rounded-lg">
            <div className="flex justify-between items-center mb-3">
              <h3 className="text-lg font-semibold text-gray-900">Rate Calculator</h3>
              <button
                type="button"
                onClick={handleCalculateRate}
                className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700"
              >
                Calculate Rate
              </button>
            </div>
            {rateCalculation && (
              <div className="grid grid-cols-2 gap-4 text-sm">
                <div>
                  <p className="text-gray-600">Base Rate:</p>
                  <p className="font-semibold">${rateCalculation.baseRate.toLocaleString()}</p>
                </div>
                <div>
                  <p className="text-gray-600">Fuel Surcharge:</p>
                  <p className="font-semibold">
                    ${rateCalculation.fuelSurcharge.toLocaleString()}
                  </p>
                </div>
                <div>
                  <p className="text-gray-600">Total Carrier Rate:</p>
                  <p className="font-semibold">
                    ${rateCalculation.totalCarrierRate.toLocaleString()}
                  </p>
                </div>
                <div>
                  <p className="text-gray-600">Suggested Customer Rate:</p>
                  <p className="font-semibold text-green-600">
                    ${rateCalculation.suggestedCustomerRate.toLocaleString()}
                  </p>
                </div>
                <div>
                  <p className="text-gray-600">Expected Margin:</p>
                  <p className="font-semibold text-green-600">
                    ${rateCalculation.margin.toLocaleString()} (
                    {rateCalculation.marginPercentage}%)
                  </p>
                </div>
              </div>
            )}
          </div>

          {/* Customer Rate */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Customer Rate ($) *
            </label>
            <input
              type="number"
              value={formData.customerRate || ''}
              onChange={(e) => handleInputChange('customerRate', parseFloat(e.target.value))}
              className={`w-full px-3 py-2 border rounded-lg ${
                (errors as any).customerRate ? 'border-red-500' : 'border-gray-300'
              }`}
            />
            {(errors as any).customerRate && (
              <p className="text-red-500 text-sm mt-1">{(errors as any).customerRate}</p>
            )}
          </div>

          {/* Carrier Matching */}
          {showCarrierMatch && matchedCarriers.length > 0 && (
            <div className="bg-green-50 p-4 rounded-lg">
              <h3 className="text-lg font-semibold mb-3 text-gray-900">
                Matched Carriers ({matchedCarriers.length})
              </h3>
              <div className="space-y-2 max-h-60 overflow-y-auto">
                {matchedCarriers.map((match: any) => (
                  <div
                    key={match.carrier.id}
                    className="bg-white p-3 rounded border border-gray-200"
                  >
                    <div className="flex justify-between items-start">
                      <div>
                        <p className="font-semibold">{match.carrier.companyName}</p>
                        <p className="text-sm text-gray-600">MC# {match.carrier.mcNumber}</p>
                        <p className="text-xs text-gray-500 mt-1">
                          {match.reasons.join(' • ')}
                        </p>
                      </div>
                      <div className="text-right">
                        <div className="bg-blue-600 text-white px-2 py-1 rounded text-sm font-semibold">
                          Score: {match.score}
                        </div>
                        <div className="text-sm text-gray-600 mt-1">
                          ⭐ {match.carrier.rating.toFixed(1)}
                        </div>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Action Buttons */}
          <div className="flex justify-between gap-4 pt-4 border-t">
            <button
              type="button"
              onClick={handleFindCarriers}
              className="px-6 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 font-semibold"
            >
              Find Matching Carriers
            </button>
            <div className="flex gap-4">
              <button
                type="button"
                onClick={onClose}
                className="px-6 py-2 border border-gray-300 rounded-lg hover:bg-gray-50 font-semibold"
              >
                Cancel
              </button>
              <button
                type="submit"
                disabled={isSubmitting}
                className="px-6 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 font-semibold disabled:bg-gray-400"
              >
                {isSubmitting ? 'Creating...' : 'Create Load'}
              </button>
            </div>
          </div>
        </form>
      </div>
    </div>
  );
};
