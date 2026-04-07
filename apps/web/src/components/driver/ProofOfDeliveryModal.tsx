"use client";
import React, { useState, useRef } from 'react';
import { LoadStop, ProofOfDelivery } from '@/types/load.types';
import { LoadService } from '@/services/load.service';

interface ProofOfDeliveryModalProps {
  stop: LoadStop;
  onSubmit: (pod: Omit<ProofOfDelivery, 'id' | 'stopId'>) => void;
  onCancel: () => void;
}

export default function ProofOfDeliveryModal({
  stop,
  onSubmit,
  onCancel,
}: ProofOfDeliveryModalProps) {
  const [photos, setPhotos] = useState<ProofOfDelivery['photos']>([]);
  const [signature, setSignature] = useState<ProofOfDelivery['signature']>();
  const [deliveredTo, setDeliveredTo] = useState('');
  const [notes, setNotes] = useState('');
  const [odometer, setOdometer] = useState<number>();
  const [isSubmitting, setIsSubmitting] = useState(false);

  const signatureCanvasRef = useRef<HTMLCanvasElement>(null);
  const [isDrawing, setIsDrawing] = useState(false);

  const handleCapturePhoto = async () => {
    try {
      const photo = await LoadService.capturePhoto();
      setPhotos([...photos, photo]);
    } catch (error) {
      console.error('Failed to capture photo:', error);
    }
  };

  const handleRemovePhoto = (photoId: string) => {
    setPhotos(photos.filter(p => p.id !== photoId));
  };

  const getPoint = (e: React.MouseEvent | React.TouchEvent, canvas: HTMLCanvasElement) => {
    const rect = canvas.getBoundingClientRect();
    const x = 'touches' in e ? e.touches[0].clientX - rect.left : (e as React.MouseEvent).clientX - rect.left;
    const y = 'touches' in e ? e.touches[0].clientY - rect.top : (e as React.MouseEvent).clientY - rect.top;
    return { x, y };
  };

  const handleStartDrawing = (e: React.MouseEvent | React.TouchEvent) => {
    setIsDrawing(true);
    const canvas = signatureCanvasRef.current;
    if (!canvas) return;

    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    const { x, y } = getPoint(e, canvas);
    ctx.beginPath();
    ctx.moveTo(x, y);
  };

  const handleDraw = (e: React.MouseEvent | React.TouchEvent) => {
    if (!isDrawing) return;

    const canvas = signatureCanvasRef.current;
    if (!canvas) return;

    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    const { x, y } = getPoint(e, canvas);
    ctx.lineTo(x, y);
    ctx.stroke();
  };

  const handleStopDrawing = () => {
    setIsDrawing(false);
  };

  const handleClearSignature = () => {
    const canvas = signatureCanvasRef.current;
    if (!canvas) return;

    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    ctx.clearRect(0, 0, canvas.width, canvas.height);
    setSignature(undefined);
  };

  const handleSaveSignature = () => {
    const canvas = signatureCanvasRef.current;
    if (!canvas) return;

    const dataUrl = canvas.toDataURL();
    setSignature({
      dataUrl,
      signedBy: deliveredTo,
      timestamp: new Date(),
    });
  };

  const handleSubmit = async () => {
    if (photos.length === 0) {
      alert('Please capture at least one photo');
      return;
    }

    if (!signature) {
      alert('Please capture signature');
      return;
    }

    if (!deliveredTo.trim()) {
      alert('Please enter recipient name');
      return;
    }

    setIsSubmitting(true);

    try {
      const pod: Omit<ProofOfDelivery, 'id' | 'stopId'> = {
        signature,
        photos,
        notes: notes.trim() || undefined,
        deliveredTo: deliveredTo.trim(),
        deliveryTime: new Date(),
        odometer,
      };

      await onSubmit(pod);
    } catch (error) {
      alert('Failed to submit. Please try again.');
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="modal-overlay">
      <div className="modal pod-modal">
        <div className="modal-header">
          <h2>Proof of Delivery</h2>
          <button className="close-button" onClick={onCancel}>✕</button>
        </div>

        <div className="modal-body">
          {/* Stop Info */}
          <div className="stop-info">
            <div className="stop-type">
              {stop.type === 'pickup' ? '📦 Pickup' : '📍 Delivery'}
            </div>
            <div className="stop-location">{stop.location.name}</div>
          </div>

          {/* Photos */}
          <div className="pod-section">
            <h3>Photos *</h3>
            <div className="photos-grid">
              {photos.map(photo => (
                <div key={photo.id} className="photo-item">
                  <img src={photo.dataUrl} alt="POD" />
                  <button 
                    className="remove-photo"
                    onClick={() => handleRemovePhoto(photo.id)}
                  >
                    ✕
                  </button>
                </div>
              ))}
              <button 
                className="add-photo-button"
                onClick={handleCapturePhoto}
              >
                📸 Add Photo
              </button>
            </div>
          </div>

          {/* Signature */}
          <div className="pod-section">
            <h3>Signature *</h3>
            <div className="signature-container">
              <canvas
                ref={signatureCanvasRef}
                width={400}
                height={200}
                className="signature-canvas"
                onMouseDown={handleStartDrawing}
                onMouseMove={handleDraw}
                onMouseUp={handleStopDrawing}
                onMouseLeave={handleStopDrawing}
                onTouchStart={handleStartDrawing}
                onTouchMove={handleDraw}
                onTouchEnd={handleStopDrawing}
              />
              <div className="signature-actions">
                <button onClick={handleClearSignature}>Clear</button>
                <button onClick={handleSaveSignature}>Save</button>
              </div>
            </div>
          </div>

          {/* Delivered To */}
          <div className="pod-section">
            <h3>Delivered To *</h3>
            <input
              type="text"
              className="input"
              placeholder="Recipient name"
              value={deliveredTo}
              onChange={(e) => setDeliveredTo(e.target.value)}
            />
          </div>

          {/* Odometer */}
          <div className="pod-section">
            <h3>Odometer Reading</h3>
            <input
              type="number"
              className="input"
              placeholder="Current odometer"
              value={odometer || ''}
              onChange={(e) => setOdometer(Number(e.target.value))}
            />
          </div>

          {/* Notes */}
          <div className="pod-section">
            <h3>Notes</h3>
            <textarea
              className="textarea"
              placeholder="Additional notes or comments"
              rows={3}
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
            />
          </div>
        </div>

        <div className="modal-footer">
          <button 
            className="btn-secondary"
            onClick={onCancel}
            disabled={isSubmitting}
          >
            Cancel
          </button>
          <button 
            className="btn-primary"
            onClick={handleSubmit}
            disabled={isSubmitting}
          >
            {isSubmitting ? 'Submitting...' : 'Submit POD'}
          </button>
        </div>
      </div>
    </div>
  );
}
