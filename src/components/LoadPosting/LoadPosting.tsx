import React, { useState } from 'react';
import './LoadPosting.css';
import { Load, Location } from '../../types';
import LocationForm from './LocationForm';

const LoadPosting: React.FC = () => {
  const [step, setStep] = useState(1);
  const [postedLoads, setPostedLoads] = useState<Load[]>([]);
  
  const [loadData, setLoadData] = useState({
    loadNumber: `LD-${new Date().getFullYear()}-${String(Date.now()).slice(-6)}`,
    pickupDate: '',
    deliveryDate: '',
    cargoDescription: '',
    cargoWeight: '',
    cargoPieces: '',
    cargoType: 'Palletized',
    rate: '',
    distance: '',
    requirements: [] as string[],
    specialInstructions: ''
  });

  const [origin, setOrigin] = useState<Location>({
    address: '',
    city: '',
    state: '',
    zipCode: '',
    contactName: '',
    contactPhone: '',
    specialInstructions: ''
  });

  const [destination, setDestination] = useState<Location>({
    address: '',
    city: '',
    state: '',
    zipCode: '',
    contactName: '',
    contactPhone: '',
    specialInstructions: ''
  });

  const requirementOptions = [
    'Temperature Controlled',
    'Team Required',
    'Hazmat Certified',
    'Liftgate Required',
    'Inside Delivery',
    'Appointment Required',
    'No Touch Freight',
    'Expedited'
  ];

  const handleLoadDataChange = (
    e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement>
  ) => {
    const { name, value } = e.target;
    setLoadData(prev => ({ ...prev, [name]: value }));
  };

  const toggleRequirement = (requirement: string) => {
    setLoadData(prev => ({
      ...prev,
      requirements: prev.requirements.includes(requirement)
        ? prev.requirements.filter(r => r !== requirement)
        : [...prev.requirements, requirement]
    }));
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();

    const newLoad: Load = {
      id: `LOAD-${Date.now()}`,
      loadNumber: loadData.loadNumber,
      status: 'posted',
      origin: origin,
      destination: destination,
      pickupDate: loadData.pickupDate,
      deliveryDate: loadData.deliveryDate,
      cargo: {
        description: loadData.cargoDescription,
        weight: parseFloat(loadData.cargoWeight),
        pieces: parseInt(loadData.cargoPieces),
        type: loadData.cargoType
      },
      rate: parseFloat(loadData.rate),
      distance: parseFloat(loadData.distance),
      requirements: loadData.requirements.length > 0 ? loadData.requirements : undefined,
      createdBy: 'broker@freight.com',
      createdAt: new Date().toISOString()
    };

    setPostedLoads([newLoad, ...postedLoads]);
    
    // Reset form
    resetForm();
    setStep(1);
    
    alert('Load posted successfully!');
  };

  const resetForm = () => {
    setLoadData({
      loadNumber: `LD-${new Date().getFullYear()}-${String(Date.now()).slice(-6)}`,
      pickupDate: '',
      deliveryDate: '',
      cargoDescription: '',
      cargoWeight: '',
      cargoPieces: '',
      cargoType: 'Palletized',
      rate: '',
      distance: '',
      requirements: [],
      specialInstructions: ''
    });
    setOrigin({
      address: '',
      city: '',
      state: '',
      zipCode: '',
      contactName: '',
      contactPhone: '',
      specialInstructions: ''
    });
    setDestination({
      address: '',
      city: '',
      state: '',
      zipCode: '',
      contactName: '',
      contactPhone: '',
      specialInstructions: ''
    });
  };

  const canProceed = () => {
    switch (step) {
      case 1:
        return !!(origin.address && origin.city && origin.state && origin.zipCode);
      case 2:
        return !!(destination.address && destination.city && destination.state && destination.zipCode);
      case 3:
        return !!(loadData.cargoDescription && loadData.cargoWeight && loadData.cargoPieces);
      case 4:
        return !!(loadData.pickupDate && loadData.deliveryDate && loadData.rate);
      default:
        return false;
    }
  };

  const renderStep = () => {
    switch (step) {
      case 1:
        return (
          <div className="step-content">
            <h3>🚚 Pickup Location</h3>
            <LocationForm location={origin} onChange={setOrigin} type="origin" />
          </div>
        );
      case 2:
        return (
          <div className="step-content">
            <h3>🎯 Delivery Location</h3>
            <LocationForm location={destination} onChange={setDestination} type="destination" />
          </div>
        );
      case 3:
        return (
          <div className="step-content">
            <h3>📦 Cargo Details</h3>
            <div className="form-group">
              <label htmlFor="cargoDescription">Cargo Description *</label>
              <textarea
                id="cargoDescription"
                name="cargoDescription"
                value={loadData.cargoDescription}
                onChange={handleLoadDataChange}
                required
                rows={3}
                placeholder="Describe the cargo..."
              />
            </div>

            <div className="form-row">
              <div className="form-group">
                <label htmlFor="cargoWeight">Weight (lbs) *</label>
                <input
                  type="number"
                  id="cargoWeight"
                  name="cargoWeight"
                  value={loadData.cargoWeight}
                  onChange={handleLoadDataChange}
                  required
                  min="0"
                  placeholder="0"
                />
              </div>

              <div className="form-group">
                <label htmlFor="cargoPieces">Number of Pieces *</label>
                <input
                  type="number"
                  id="cargoPieces"
                  name="cargoPieces"
                  value={loadData.cargoPieces}
                  onChange={handleLoadDataChange}
                  required
                  min="1"
                  placeholder="0"
                />
              </div>
            </div>

            <div className="form-group">
              <label htmlFor="cargoType">Cargo Type *</label>
              <select
                id="cargoType"
                name="cargoType"
                value={loadData.cargoType}
                onChange={handleLoadDataChange}
                required
              >
                <option value="Palletized">Palletized</option>
                <option value="Crated">Crated</option>
                <option value="Loose">Loose</option>
                <option value="Boxed">Boxed</option>
                <option value="Drums">Drums</option>
                <option value="Other">Other</option>
              </select>
            </div>
          </div>
        );
      case 4:
        return (
          <div className="step-content">
            <h3>📅 Schedule & Rate</h3>
            <div className="form-row">
              <div className="form-group">
                <label htmlFor="pickupDate">Pickup Date & Time *</label>
                <input
                  type="datetime-local"
                  id="pickupDate"
                  name="pickupDate"
                  value={loadData.pickupDate}
                  onChange={handleLoadDataChange}
                  required
                />
              </div>

              <div className="form-group">
                <label htmlFor="deliveryDate">Delivery Date & Time *</label>
                <input
                  type="datetime-local"
                  id="deliveryDate"
                  name="deliveryDate"
                  value={loadData.deliveryDate}
                  onChange={handleLoadDataChange}
                  required
                />
              </div>
            </div>

            <div className="form-row">
              <div className="form-group">
                <label htmlFor="rate">Rate ($) *</label>
                <input
                  type="number"
                  id="rate"
                  name="rate"
                  value={loadData.rate}
                  onChange={handleLoadDataChange}
                  required
                  min="0"
                  step="0.01"
                  placeholder="0.00"
                />
              </div>

              <div className="form-group">
                <label htmlFor="distance">Distance (miles) *</label>
                <input
                  type="number"
                  id="distance"
                  name="distance"
                  value={loadData.distance}
                  onChange={handleLoadDataChange}
                  required
                  min="0"
                  placeholder="0"
                />
              </div>
            </div>

            <div className="form-group">
              <label>Special Requirements</label>
              <div className="requirements-grid">
                {requirementOptions.map(req => (
                  <label key={req} className="checkbox-label">
                    <input
                      type="checkbox"
                      checked={loadData.requirements.includes(req)}
                      onChange={() => toggleRequirement(req)}
                    />
                    <span>{req}</span>
                  </label>
                ))}
              </div>
            </div>

            <div className="form-group">
              <label htmlFor="specialInstructions">Special Instructions</label>
              <textarea
                id="specialInstructions"
                name="specialInstructions"
                value={loadData.specialInstructions}
                onChange={handleLoadDataChange}
                rows={3}
                placeholder="Any additional information..."
              />
            </div>
          </div>
        );
      case 5:
        return (
          <div className="step-content review-step">
            <h3>✅ Review & Confirm</h3>
            
            <div className="review-section">
              <h4>Load Information</h4>
              <div className="review-grid">
                <div className="review-item">
                  <span className="review-label">Load Number:</span>
                  <span className="review-value">{loadData.loadNumber}</span>
                </div>
                <div className="review-item">
                  <span className="review-label">Rate:</span>
                  <span className="review-value">${parseFloat(loadData.rate || '0').toLocaleString()}</span>
                </div>
                <div className="review-item">
                  <span className="review-label">Distance:</span>
                  <span className="review-value">{loadData.distance} miles</span>
                </div>
              </div>
            </div>

            <div className="review-section">
              <h4>Route</h4>
              <div className="review-route">
                <div className="review-location">
                  <strong>📍 Pickup</strong>
                  <p>{origin.address}</p>
                  <p>{origin.city}, {origin.state} {origin.zipCode}</p>
                  <p>📅 {new Date(loadData.pickupDate).toLocaleString()}</p>
                </div>
                <div className="review-arrow">→</div>
                <div className="review-location">
                  <strong>🎯 Delivery</strong>
                  <p>{destination.address}</p>
                  <p>{destination.city}, {destination.state} {destination.zipCode}</p>
                  <p>📅 {new Date(loadData.deliveryDate).toLocaleString()}</p>
                </div>
              </div>
            </div>

            <div className="review-section">
              <h4>Cargo Details</h4>
              <div className="review-grid">
                <div className="review-item">
                  <span className="review-label">Description:</span>
                  <span className="review-value">{loadData.cargoDescription}</span>
                </div>
                <div className="review-item">
                  <span className="review-label">Weight:</span>
                  <span className="review-value">{parseFloat(loadData.cargoWeight || '0').toLocaleString()} lbs</span>
                </div>
                <div className="review-item">
                  <span className="review-label">Pieces:</span>
                  <span className="review-value">{loadData.cargoPieces}</span>
                </div>
                <div className="review-item">
                  <span className="review-label">Type:</span>
                  <span className="review-value">{loadData.cargoType}</span>
                </div>
              </div>
            </div>

            {loadData.requirements.length > 0 && (
              <div className="review-section">
                <h4>Requirements</h4>
                <div className="review-requirements">
                  {loadData.requirements.map(req => (
                    <span key={req} className="review-requirement">{req}</span>
                  ))}
                </div>
              </div>
            )}
          </div>
        );
      default:
        return null;
    }
  };

  return (
    <div className="load-posting">
      <header className="posting-header">
        <h1>📋 Freight Broker Load Posting</h1>
        <div className="posting-stats">
          <div className="stat-card">
            <span className="stat-value">{postedLoads.length}</span>
            <span className="stat-label">Loads Posted Today</span>
          </div>
          <div className="stat-card">
            <span className="stat-value">
              ${postedLoads.reduce((sum, load) => sum + load.rate, 0).toLocaleString()}
            </span>
            <span className="stat-label">Total Value</span>
          </div>
        </div>
      </header>

      <div className="posting-content">
        <div className="posting-form-section">
          <div className="form-card">
            <div className="step-indicator">
              {[1, 2, 3, 4, 5].map(num => (
                <div
                  key={num}
                  className={`step-dot ${step >= num ? 'active' : ''} ${step === num ? 'current' : ''}`}
                  onClick={() => step > num && setStep(num)}
                >
                  {num}
                </div>
              ))}
            </div>

            <div className="step-labels">
              <span className={step === 1 ? 'active' : ''}>Pickup</span>
              <span className={step === 2 ? 'active' : ''}>Delivery</span>
              <span className={step === 3 ? 'active' : ''}>Cargo</span>
              <span className={step === 4 ? 'active' : ''}>Schedule</span>
              <span className={step === 5 ? 'active' : ''}>Review</span>
            </div>

            <form onSubmit={handleSubmit}>
              {renderStep()}

              <div className="form-navigation">
                {step > 1 && (
                  <button
                    type="button"
                    className="btn-secondary"
                    onClick={() => setStep(step - 1)}
                  >
                    ← Previous
                  </button>
                )}
                {step < 5 ? (
                  <button
                    type="button"
                    className="btn-primary"
                    onClick={() => setStep(step + 1)}
                    disabled={!canProceed()}
                  >
                    Next →
                  </button>
                ) : (
                  <button type="submit" className="btn-success">
                    Post Load
                  </button>
                )}
              </div>
            </form>
          </div>
        </div>

        <div className="posted-loads-section">
          <div className="loads-card">
            <h2>Recently Posted Loads</h2>
            {postedLoads.length === 0 ? (
              <div className="empty-state">
                <p>No loads posted yet</p>
                <small>Complete the form to post your first load</small>
              </div>
            ) : (
              <div className="posted-loads-list">
                {postedLoads.map(load => (
                  <div key={load.id} className="posted-load-card">
                    <div className="load-header">
                      <strong>{load.loadNumber}</strong>
                      <span className="load-rate">${load.rate.toLocaleString()}</span>
                    </div>
                    <div className="load-route-mini">
                      <span>{load.origin.city}, {load.origin.state}</span>
                      <span>→</span>
                      <span>{load.destination.city}, {load.destination.state}</span>
                    </div>
                    <div className="load-meta">
                      <span>📦 {load.cargo.weight.toLocaleString()} lbs</span>
                      <span>📏 {load.distance} mi</span>
                    </div>
                    <div className="load-status">
                      <span className="status-badge status-posted">POSTED</span>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
};

export default LoadPosting;
