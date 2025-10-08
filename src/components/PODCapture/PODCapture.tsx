import React, { useEffect, useState } from 'react';
import './PODCapture.css';
import { POD, Photo } from '../../types';
import SignaturePad from './SignaturePad';
import PhotoCapture from './PhotoCapture';

const PODCapture: React.FC = () => {
  const [loadNumber, setLoadNumber] = useState('');
  const [recipientName, setRecipientName] = useState('');
  const [recipientTitle, setRecipientTitle] = useState('');
  const [deliveryNotes, setDeliveryNotes] = useState('');
  const [signature, setSignature] = useState('');
  const [photos, setPhotos] = useState<Photo[]>([]);
  const [submittedPODs, setSubmittedPODs] = useState<POD[]>([]);
  const [showSuccess, setShowSuccess] = useState(false);
  const [currentLocation, setCurrentLocation] = useState<GeolocationPosition | null>(null);

  const driverInfo = {
    id: 'DRV-001',
    name: 'John Smith',
  };

  useEffect(() => {
    if (navigator.geolocation) {
      navigator.geolocation.getCurrentPosition(
        (position) => setCurrentLocation(position),
        (error) => console.error('Error getting location:', error),
      );
    }
  }, []);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();

    if (!signature) {
      alert('Please capture recipient signature');
      return;
    }
    if (photos.length === 0) {
      alert('Please capture at least one delivery photo');
      return;
    }

    const now = new Date();
    const pod: POD = {
      id: `POD-${Date.now()}`,
      loadId: `LOAD-${loadNumber}`,
      loadNumber,
      deliveryDate: now.toISOString().split('T')[0],
      deliveryTime: now.toTimeString().split(' ')[0],
      recipientName,
      recipientTitle: recipientTitle || undefined,
      signature,
      photos,
      notes: deliveryNotes || undefined,
      location: {
        lat: currentLocation?.coords.latitude || 0,
        lng: currentLocation?.coords.longitude || 0,
        address: 'Current Location',
      },
      createdAt: now.toISOString(),
      driverId: driverInfo.id,
      driverName: driverInfo.name,
    };

    setSubmittedPODs([pod, ...submittedPODs]);
    setShowSuccess(true);

    setLoadNumber('');
    setRecipientName('');
    setRecipientTitle('');
    setDeliveryNotes('');
    setSignature('');
    setPhotos([]);

    setTimeout(() => setShowSuccess(false), 3000);
  };

  return (
    <div className="pod-capture">
      <header className="pod-header">
        <h1>📸 Proof of Delivery Capture</h1>
        <div className="driver-info-card">
          <div className="driver-avatar">{driverInfo.name.split(' ').map((n) => n[0]).join('')}</div>
          <div>
            <strong>{driverInfo.name}</strong>
            <small>Driver ID: {driverInfo.id}</small>
          </div>
        </div>
      </header>

      <div className="pod-content">
        <div className="pod-form-section">
          <div className="form-card">
            <h2>Delivery Confirmation</h2>

            {showSuccess && <div className="success-message">✓ Proof of Delivery submitted successfully!</div>}

            <form onSubmit={handleSubmit}>
              <div className="form-group">
                <label htmlFor="loadNumber">Load Number *</label>
                <input
                  type="text"
                  id="loadNumber"
                  value={loadNumber}
                  onChange={(e) => setLoadNumber(e.target.value)}
                  required
                  placeholder="LD-2025-XXX"
                />
              </div>

              <div className="delivery-time-info">
                <div className="info-item">
                  <span className="info-label">Delivery Date:</span>
                  <span className="info-value">{new Date().toLocaleDateString()}</span>
                </div>
                <div className="info-item">
                  <span className="info-label">Delivery Time:</span>
                  <span className="info-value">{new Date().toLocaleTimeString()}</span>
                </div>
              </div>

              {currentLocation && (
                <div className="location-info">
                  <span>📍</span>
                  <div>
                    <strong>Current Location Captured</strong>
                    <small>
                      Lat: {currentLocation.coords.latitude.toFixed(4)}, Lng: {currentLocation.coords.longitude.toFixed(4)}
                    </small>
                  </div>
                </div>
              )}

              <div className="form-group">
                <label htmlFor="recipientName">Recipient Name *</label>
                <input
                  type="text"
                  id="recipientName"
                  value={recipientName}
                  onChange={(e) => setRecipientName(e.target.value)}
                  required
                  placeholder="Full name of person receiving delivery"
                />
              </div>

              <div className="form-group">
                <label htmlFor="recipientTitle">Recipient Title/Position</label>
                <input
                  type="text"
                  id="recipientTitle"
                  value={recipientTitle}
                  onChange={(e) => setRecipientTitle(e.target.value)}
                  placeholder="e.g., Warehouse Manager, Receiving Clerk"
                />
              </div>

              <SignaturePad signature={signature} onSignatureChange={setSignature} />

              <PhotoCapture photos={photos} onPhotosChange={setPhotos} />

              <div className="form-group">
                <label htmlFor="deliveryNotes">Delivery Notes</label>
                <textarea
                  id="deliveryNotes"
                  value={deliveryNotes}
                  onChange={(e) => setDeliveryNotes(e.target.value)}
                  rows={4}
                  placeholder="Any issues, damages, or special conditions at delivery..."
                />
              </div>

              <div className="form-actions">
                <button type="submit" className="btn-submit-pod">
                  Submit Proof of Delivery
                </button>
              </div>
            </form>
          </div>
        </div>

        <div className="pod-history-section">
          <div className="history-card">
            <h2>Recent PODs</h2>

            {submittedPODs.length === 0 ? (
              <div className="empty-state">
                <p>No PODs submitted yet</p>
                <small>Completed deliveries will appear here</small>
              </div>
            ) : (
              <div className="pod-list">
                {submittedPODs.map((pod) => (
                  <div key={pod.id} className="pod-item">
                    <div className="pod-item-header">
                      <div>
                        <strong>{pod.loadNumber}</strong>
                        <small>
                          {pod.deliveryDate} at {pod.deliveryTime}
                        </small>
                      </div>
                      <span className="pod-status">✓ Complete</span>
                    </div>
                    <div className="pod-item-details">
                      <div className="detail-row">
                        <span className="detail-label">Recipient:</span>
                        <span>{pod.recipientName}</span>
                      </div>
                      {pod.recipientTitle && (
                        <div className="detail-row">
                          <span className="detail-label">Title:</span>
                          <span>{pod.recipientTitle}</span>
                        </div>
                      )}
                      <div className="detail-row">
                        <span className="detail-label">Photos:</span>
                        <span>{pod.photos.length} attached</span>
                      </div>
                      <div className="pod-thumbnails">
                        {pod.photos.slice(0, 3).map((photo) => (
                          <div key={photo.id} className="thumbnail">
                            <img src={photo.url} alt="Delivery" />
                          </div>
                        ))}
                        {pod.photos.length > 3 && <div className="thumbnail more">+{pod.photos.length - 3}</div>}
                      </div>
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

export default PODCapture;
