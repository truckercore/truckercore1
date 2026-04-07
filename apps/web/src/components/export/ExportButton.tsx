import React, { useState } from 'react';
import { exportService, ExportOptions } from '../../services/ExportService';

interface ExportButtonProps {
  data: any[];
  filename?: string;
  columns?: string[];
  title?: string;
  className?: string;
}

export const ExportButton: React.FC<ExportButtonProps> = ({
  data,
  filename,
  columns,
  title,
  className = '',
}) => {
  const [isExporting, setIsExporting] = useState(false);
  const [showMenu, setShowMenu] = useState(false);

  const handleExport = async (format: 'csv' | 'pdf' | 'excel' | 'json') => {
    setIsExporting(true);
    setShowMenu(false);
    try {
      const options: ExportOptions = {
        format,
        data,
        filename: filename || `export-${Date.now()}.${format === 'excel' ? 'xlsx' : format}`,
        columns,
        title: title || 'Data Export',
        includeTimestamp: true,
      };
      await exportService.export(options);
    } catch (error) {
      console.error('Export failed:', error);
      alert('Export failed. Please try again.');
    } finally {
      setIsExporting(false);
    }
  };

  return (
    <div className={`relative ${className}`}>
      <button
        onClick={() => setShowMenu(!showMenu)}
        disabled={isExporting}
        className="inline-flex items-center px-4 py-2 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 disabled:opacity-50 disabled:cursor-not-allowed"
      >
        {isExporting ? (
          <>
            <svg className="animate-spin -ml-1 mr-2 h-4 w-4 text-gray-700" fill="none" viewBox="0 0 24 24">
              <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
              <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z" />
            </svg>
            Exporting...
          </>
        ) : (
          <>
            <svg className="-ml-1 mr-2 h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
            </svg>
            Export
            <svg className="ml-2 -mr-1 h-4 w-4" fill="currentColor" viewBox="0 0 20 20">
              <path fillRule="evenodd" d="M5.293 7.293a1 1 0 011.414 0L10 10.586l3.293-3.293a1 1 0 111.414 1.414l-4 4a1 1 0 01-1.414 0l-4-4a1 1 0 010-1.414z" clipRule="evenodd" />
            </svg>
          </>
        )}
      </button>

      {showMenu && (
        <>
          <div className="fixed inset-0 z-10" onClick={() => setShowMenu(false)} />
          <div className="absolute right-0 mt-2 w-48 rounded-md shadow-lg bg-white ring-1 ring-black ring-opacity-5 z-20">
            <div className="py-1">
              <button onClick={() => handleExport('csv')} className="block w-full text-left px-4 py-2 text-sm text-gray-700 hover:bg-gray-100">
                <span className="font-medium">CSV</span>
                <span className="block text-xs text-gray-500">Comma-separated values</span>
              </button>
              <button onClick={() => handleExport('excel')} className="block w-full text-left px-4 py-2 text-sm text-gray-700 hover:bg-gray-100">
                <span className="font-medium">Excel</span>
                <span className="block text-xs text-gray-500">Microsoft Excel format</span>
              </button>
              <button onClick={() => handleExport('pdf')} className="block w-full text-left px-4 py-2 text-sm text-gray-700 hover:bg-gray-100">
                <span className="font-medium">PDF</span>
                <span className="block text-xs text-gray-500">Portable Document Format</span>
              </button>
              <button onClick={() => handleExport('json')} className="block w-full text-left px-4 py-2 text-sm text-gray-700 hover:bg-gray-100">
                <span className="font-medium">JSON</span>
                <span className="block text-xs text-gray-500">JavaScript Object Notation</span>
              </button>
            </div>
          </div>
        </>
      )}
    </div>
  );
};
