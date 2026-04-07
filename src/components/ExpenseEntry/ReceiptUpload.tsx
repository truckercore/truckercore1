import React, { useRef, useState } from 'react';
import { Receipt } from '../../types';

interface ReceiptUploadProps {
  receipts: Receipt[];
  onChange: (receipts: Receipt[]) => void;
}

const ReceiptUpload: React.FC<ReceiptUploadProps> = ({ receipts, onChange }) => {
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [dragActive, setDragActive] = useState(false);

  const handleFiles = (files: FileList | null) => {
    if (!files) return;

    const newReceipts: Receipt[] = [];
    const allowedTypes = ['image/jpeg', 'image/png', 'image/jpg', 'application/pdf'];

    Array.from(files).forEach((file) => {
      if (!allowedTypes.includes(file.type)) {
        alert(`File type not allowed: ${file.name}`);
        return;
      }

      if (file.size > 10 * 1024 * 1024) {
        alert(`File too large (max 10MB): ${file.name}`);
        return;
      }

      const receipt: Receipt = {
        id: `receipt-${Date.now()}-${Math.random()}`,
        fileName: file.name,
        fileSize: file.size,
        fileType: file.type,
        url: URL.createObjectURL(file),
        uploadedAt: new Date().toISOString(),
      };

      newReceipts.push(receipt);
    });

    onChange([...receipts, ...newReceipts]);
  };

  const handleDrag = (e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
    if (e.type === 'dragenter' || e.type === 'dragover') {
      setDragActive(true);
    } else if (e.type === 'dragleave') {
      setDragActive(false);
    }
  };

  const handleDrop = (e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
    setDragActive(false);

    if (e.dataTransfer.files && e.dataTransfer.files[0]) {
      handleFiles(e.dataTransfer.files);
    }
  };

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    e.preventDefault();
    if (e.target.files && e.target.files[0]) {
      handleFiles(e.target.files);
    }
  };

  const handleButtonClick = () => {
    fileInputRef.current?.click();
  };

  const removeReceipt = (receiptId: string) => {
    onChange(receipts.filter((r) => r.id !== receiptId));
  };

  const formatFileSize = (bytes: number) => {
    if (bytes < 1024) return bytes + ' B';
    if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB';
    return (bytes / (1024 * 1024)).toFixed(1) + ' MB';
  };

  return (
    <div className="receipt-upload-section">
      <label className="section-label">Receipt Upload *</label>

      <div
        className={`upload-zone ${dragActive ? 'drag-active' : ''}`}
        onDragEnter={handleDrag}
        onDragLeave={handleDrag}
        onDragOver={handleDrag}
        onDrop={handleDrop}
      >
        <input
          ref={fileInputRef}
          type="file"
          multiple
          accept="image/*,application/pdf"
          onChange={handleChange}
          style={{ display: 'none' }}
        />

        <div className="upload-content">
          <div className="upload-icon">📎</div>
          <h3>Drag & Drop receipts here</h3>
          <p>or</p>
          <button type="button" className="upload-button" onClick={handleButtonClick}>
            Browse Files
          </button>
          <small>Accepted: JPG, PNG, PDF (Max 10MB each)</small>
        </div>
      </div>

      {receipts.length > 0 && (
        <div className="receipts-list">
          <h4>Uploaded Receipts ({receipts.length})</h4>
          {receipts.map((receipt) => (
            <div key={receipt.id} className="receipt-item">
              <div className="receipt-preview">
                {receipt.fileType.startsWith('image/') ? (
                  <img src={receipt.url} alt={receipt.fileName} />
                ) : (
                  <div className="pdf-icon">📄</div>
                )}
              </div>
              <div className="receipt-info">
                <strong>{receipt.fileName}</strong>
                <small>{formatFileSize(receipt.fileSize)}</small>
              </div>
              <button
                type="button"
                className="remove-receipt"
                onClick={() => removeReceipt(receipt.id)}
                title="Remove receipt"
              >
                ×
              </button>
            </div>
          ))}
        </div>
      )}
    </div>
  );
};

export default ReceiptUpload;
