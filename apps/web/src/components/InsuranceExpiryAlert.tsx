import React from 'react';
import { AlertTriangle } from 'lucide-react';

interface InsuranceExpiryAlertProps {
  expiryDate: string;
  entityName: string;
  entityType: 'carrier' | 'vehicle';
  onRenew?: () => void;
}

export const InsuranceExpiryAlert: React.FC<InsuranceExpiryAlertProps> = ({
  expiryDate,
  entityName,
  entityType,
  onRenew,
}) => {
  const daysUntilExpiry = Math.ceil(
    (new Date(expiryDate).getTime() - Date.now()) / (1000 * 60 * 60 * 24)
  );

  if (daysUntilExpiry > 30) return null;

  const severity =
    daysUntilExpiry <= 7 ? 'critical' : daysUntilExpiry <= 15 ? 'warning' : 'info';

  const colors: Record<string, string> = {
    critical: 'bg-red-50 border-red-500 text-red-900',
    warning: 'bg-yellow-50 border-yellow-500 text-yellow-900',
    info: 'bg-blue-50 border-blue-500 text-blue-900',
  };

  const iconColors: Record<string, string> = {
    critical: 'text-red-500',
    warning: 'text-yellow-500',
    info: 'text-blue-500',
  };

  return (
    <div className={`border-l-4 p-4 rounded ${colors[severity]} mb-4`}>
      <div className="flex items-start">
        <AlertTriangle className={`mr-3 mt-0.5 ${iconColors[severity]}`} size={20} />
        <div className="flex-1">
          <h3 className="text-sm font-semibold">
            {severity === 'critical'
              ? '🚨 Critical: Insurance Expiring Soon!'
              : severity === 'warning'
              ? '⚠️ Warning: Insurance Renewal Required'
              : 'ℹ️ Insurance Renewal Reminder'}
          </h3>
          <p className="text-sm mt-1">
            Insurance for <strong>{entityName}</strong> ({entityType}) expires in{' '}
            <strong>{daysUntilExpiry} days</strong> on{' '}
            <strong>{new Date(expiryDate).toLocaleDateString()}</strong>
          </p>
          {onRenew && (
            <button
              onClick={onRenew}
              className="mt-2 px-4 py-2 bg-white border border-gray-300 rounded hover:bg-gray-50 text-sm font-semibold"
            >
              Renew Insurance
            </button>
          )}
        </div>
      </div>
    </div>
  );
};

export default InsuranceExpiryAlert;
