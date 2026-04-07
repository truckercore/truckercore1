import React, { useRef } from 'react';
import { Photo } from '../../types';

interface PhotoCaptureProps {
  photos: Photo[];
  onPhotosChange: (photos: Photo[]) => void;
}

const PhotoCapture: React.FC<PhotoCaptureProps> = ({ photos, onPhotosChange }) => {
  const fileInputRef = useRef<HTMLInputElement>(null);
  const cameraInputRef = useRef<HTMLInputElement>(null);

  const handleFileSelect = (files: FileList | null, source: 'camera' | 'gallery') => {
    if (!files) return;

    const newPhotos: Photo[] = [];

    Array.from(files).forEach((file) => {
      if (!file.type.startsWith('image/')) {
        alert(`Not an image file: ${file.name}`);
        return;
      }

      if (file.size > 10 * 1024 * 1024) {
        alert(`Image too large (max 10MB): ${file.name}`);
        return;
      }

      const photo: Photo = {
        id: `photo-${Date.now()}-${Math.random()}`,
        url: URL.createObjectURL(file),
        caption: source === 'camera' ? 'Camera Photo' : 'Gallery Photo',
        timestamp: new Date().toISOString(),
      };

      newPhotos.push(photo);
    });

    onPhotosChange([...photos, ...newPhotos]);
  };

  const removePhoto = (photoId: string) => {
    onPhotosChange(photos.filter((p) => p.id !== photoId));
  };

  const updateCaption = (photoId: string, caption: string) => {
    onPhotosChange(photos.map((p) => (p.id === photoId ? { ...p, caption } : p)));
  };

  return (
    <div className="photo-capture-section">
      <label className="section-label">Delivery Photos *</label>

      <div className="photo-actions">
        <input
          ref={cameraInputRef}
          type="file"
          accept="image/*"
          capture="environment"
          onChange={(e) => handleFileSelect(e.target.files, 'camera')}
          style={{ display: 'none' }}
        />
        <button type="button" className="photo-button camera-button" onClick={() => cameraInputRef.current?.click()}>
          📷 Take Photo
        </button>

        <input
          ref={fileInputRef}
          type="file"
          accept="image/*"
          multiple
          onChange={(e) => handleFileSelect(e.target.files, 'gallery')}
          style={{ display: 'none' }}
        />
        <button type="button" className="photo-button gallery-button" onClick={() => fileInputRef.current?.click()}>
          🖼️ From Gallery
        </button>
      </div>

      {photos.length > 0 && (
        <div className="photos-grid">
          {photos.map((photo) => (
            <div key={photo.id} className="photo-card">
              <div className="photo-preview">
                <img src={photo.url} alt={photo.caption || 'Delivery photo'} />
                <button type="button" className="remove-photo" onClick={() => removePhoto(photo.id)}>
                  ×
                </button>
              </div>
              <input
                type="text"
                className="photo-caption-input"
                value={photo.caption || ''}
                onChange={(e) => updateCaption(photo.id, e.target.value)}
                placeholder="Add caption..."
              />
              <small className="photo-timestamp">{new Date(photo.timestamp).toLocaleTimeString()}</small>
            </div>
          ))}
        </div>
      )}

      <small className="photo-hint">Capture photos of delivered items, loading dock, and any damage</small>
    </div>
  );
};

export default PhotoCapture;
