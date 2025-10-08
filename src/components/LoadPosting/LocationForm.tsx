import React from 'react';
import { Location } from '../../types';

interface LocationFormProps {
  location: Location;
  onChange: (location: Location) => void;
  type: 'origin' | 'destination';
}

const LocationForm: React.FC<LocationFormProps> = ({ location, onChange, type }) => {
  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) => {
    const { name, value } = e.target;
    onChange({ ...location, [name]: value });
  };

  const usStates = [
    'AL', 'AK', 'AZ', 'AR', 'CA', 'CO', 'CT', 'DE', 'FL', 'GA',
    'HI', 'ID', 'IL', 'IN', 'IA', 'KS', 'KY', 'LA', 'ME', 'MD',
    'MA', 'MI', 'MN', 'MS', 'MO', 'MT', 'NE', 'NV', 'NH', 'NJ',
    'NM', 'NY', 'NC', 'ND', 'OH', 'OK', 'OR', 'PA', 'RI', 'SC',
    'SD', 'TN', 'TX', 'UT', 'VT', 'VA', 'WA', 'WV', 'WI', 'WY'
  ];

  return (
    <div className="location-form">
      <div className="form-group">
        <label htmlFor={`${type}-address`}>Street Address *</label>
        <input
          type="text"
          id={`${type}-address`}
          name="address"
          value={location.address}
          onChange={handleChange}
          required
          placeholder="123 Main St"
        />
      </div>

      <div className="form-row">
        <div className="form-group">
          <label htmlFor={`${type}-city`}>City *</label>
          <input
            type="text"
            id={`${type}-city`}
            name="city"
            value={location.city}
            onChange={handleChange}
            required
            placeholder="City name"
          />
        </div>

        <div className="form-group">
          <label htmlFor={`${type}-state`}>State *</label>
          <select
            id={`${type}-state`}
            name="state"
            value={location.state}
            onChange={(e) => onChange({ ...location, state: e.target.value })}
            required
          >
            <option value="">Select</option>
            {usStates.map(state => (
              <option key={state} value={state}>{state}</option>
            ))}
          </select>
        </div>

        <div className="form-group">
          <label htmlFor={`${type}-zipCode`}>ZIP Code *</label>
          <input
            type="text"
            id={`${type}-zipCode`}
            name="zipCode"
            value={location.zipCode}
            onChange={handleChange}
            required
            pattern="[0-9]{5}"
            placeholder="12345"
          />
        </div>
      </div>

      <div className="form-row">
        <div className="form-group">
          <label htmlFor={`${type}-contactName`}>Contact Name</label>
          <input
            type="text"
            id={`${type}-contactName`}
            name="contactName"
            value={location.contactName || ''}
            onChange={handleChange}
            placeholder="Contact person"
          />
        </div>

        <div className="form-group">
          <label htmlFor={`${type}-contactPhone`}>Contact Phone</label>
          <input
            type="tel"
            id={`${type}-contactPhone`}
            name="contactPhone"
            value={location.contactPhone || ''}
            onChange={handleChange}
            placeholder="555-0100"
          />
        </div>
      </div>

      <div className="form-group">
        <label htmlFor={`${type}-specialInstructions`}>Special Instructions</label>
        <textarea
          id={`${type}-specialInstructions`}
          name="specialInstructions"
          value={location.specialInstructions || ''}
          onChange={handleChange}
          rows={2}
          placeholder="Loading dock hours, access codes, etc."
        />
      </div>
    </div>
  );
};

export default LocationForm;
