import React, { useState } from 'react';
import { Download, FileText, Table, TrendingUp } from 'lucide-react';
import type { Revenue, Expense } from '../../types/ownerOperator';
import { exportService } from '../../services/exportService';

interface ExportToolsProps {
  revenues: Revenue[];
  expenses: Expense[];
}

export const ExportTools: React.FC<ExportToolsProps> = ({ revenues, expenses }) => {
  const [dateRange, setDateRange] = useState({
    start: new Date(new Date().getFullYear(), 0, 1).toISOString().split('T')[0],
    end: new Date().toISOString().split('T')[0],
  });
  const [isExporting, setIsExporting] = useState(false);

  const filterByDateRange = <T extends { date: Date }>(items: T[]): T[] => {
    const start = new Date(dateRange.start);
    const end = new Date(dateRange.end);
    return items.filter((item) => {
      const d = new Date(item.date);
      return d >= start && d <= end;
    });
  };

  const handleExportFinancialPDF = async () => {
    setIsExporting(true);
    try {
      const filteredRevenues = filterByDateRange(revenues);
      const filteredExpenses = filterByDateRange(expenses);
      const blob = await exportService.exportFinancialSummaryPDF({ revenues: filteredRevenues, expenses: filteredExpenses, startDate: new Date(dateRange.start), endDate: new Date(dateRange.end) });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `Financial-Summary-${dateRange.start}-to-${dateRange.end}.pdf`;
      a.click();
      URL.revokeObjectURL(url);
    } catch (e) {
      console.error('Error exporting PDF:', e);
      alert('Failed to export PDF');
    } finally {
      setIsExporting(false);
    }
  };

  const handleExportExpensesCSV = async () => {
    setIsExporting(true);
    try {
      const filteredExpenses = filterByDateRange(expenses);
      const csv = await exportService.exportExpensesCSV(filteredExpenses);
      const blob = new Blob([csv], { type: 'text/csv' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `Expenses-${dateRange.start}-to-${dateRange.end}.csv`;
      a.click();
      URL.revokeObjectURL(url);
    } catch (e) {
      console.error('Error exporting CSV:', e);
      alert('Failed to export CSV');
    } finally {
      setIsExporting(false);
    }
  };

  const handleExportRevenueCSV = async () => {
    setIsExporting(true);
    try {
      const filteredRevenues = filterByDateRange(revenues);
      const csv = await exportService.exportRevenueCSV(filteredRevenues);
      const blob = new Blob([csv], { type: 'text/csv' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `Revenue-${dateRange.start}-to-${dateRange.end}.csv`;
      a.click();
      URL.revokeObjectURL(url);
    } catch (e) {
      console.error('Error exporting CSV:', e);
      alert('Failed to export CSV');
    } finally {
      setIsExporting(false);
    }
  };

  const handleExportQuickBooksCSV = async () => {
    setIsExporting(true);
    try {
      const filteredRevenues = filterByDateRange(revenues);
      const filteredExpenses = filterByDateRange(expenses);
      const csv = await exportService.exportQuickBooksCSV({ revenues: filteredRevenues, expenses: filteredExpenses });
      const blob = new Blob([csv], { type: 'text/csv' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `QuickBooks-Import-${dateRange.start}-to-${dateRange.end}.csv`;
      a.click();
      URL.revokeObjectURL(url);
    } catch (e) {
      console.error('Error exporting QuickBooks CSV:', e);
      alert('Failed to export QuickBooks CSV');
    } finally {
      setIsExporting(false);
    }
  };

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-bold text-gray-900 mb-2">Export & Reports</h2>
        <p className="text-gray-600">Download your financial data in various formats for accounting and record-keeping</p>
      </div>

      <div className="bg-gray-50 rounded-lg p-6 border border-gray-200">
        <h3 className="text-lg font-semibold text-gray-900 mb-4">Select Date Range</h3>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Start Date</label>
            <input type="date" value={dateRange.start} onChange={(e) => setDateRange({ ...dateRange, start: e.target.value })} className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent" />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">End Date</label>
            <input type="date" value={dateRange.end} onChange={(e) => setDateRange({ ...dateRange, end: e.target.value })} className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent" />
          </div>
        </div>
        <div className="flex gap-2 mt-4">
          <button onClick={() => {
            const now = new Date();
            const start = new Date(now.getFullYear(), now.getMonth(), 1);
            setDateRange({ start: start.toISOString().split('T')[0], end: now.toISOString().split('T')[0] });
          }} className="px-3 py-1 text-sm bg-white border border-gray-300 rounded-md hover:bg-gray-50">This Month</button>
          <button onClick={() => {
            const now = new Date();
            const start = new Date(now.getFullYear(), 0, 1);
            setDateRange({ start: start.toISOString().split('T')[0], end: now.toISOString().split('T')[0] });
          }} className="px-3 py-1 text-sm bg-white border border-gray-300 rounded-md hover:bg-gray-50">Year to Date</button>
          <button onClick={() => {
            const now = new Date();
            const lastYear = new Date(now.getFullYear() - 1, 0, 1);
            const lastYearEnd = new Date(now.getFullYear() - 1, 11, 31);
            setDateRange({ start: lastYear.toISOString().split('T')[0], end: lastYearEnd.toISOString().split('T')[0] });
          }} className="px-3 py-1 text-sm bg-white border border-gray-300 rounded-md hover:bg-gray-50">Last Year</button>
        </div>
      </div>

      <div className="bg-white rounded-lg border border-gray-200 p-6">
        <div className="flex items-center gap-3 mb-4">
          <FileText className="h-6 w-6 text-red-600" />
          <h3 className="text-lg font-semibold text-gray-900">PDF Reports</h3>
        </div>
        <div className="space-y-3">
          <ExportButton onClick={handleExportFinancialPDF} disabled={isExporting} title="Financial Summary Report" description="Complete income and expense report with charts" icon={<TrendingUp className="h-5 w-5" />} />
        </div>
      </div>

      <div className="bg-white rounded-lg border border-gray-200 p-6">
        <div className="flex items-center gap-3 mb-4">
          <Table className="h-6 w-6 text-green-600" />
          <h3 className="text-lg font-semibold text-gray-900">CSV Exports</h3>
        </div>
        <div className="space-y-3">
          <ExportButton onClick={handleExportExpensesCSV} disabled={isExporting} title="Expenses CSV" description="All expenses with categories, amounts, and deduction status" icon={<Download className="h-5 w-5" />} />
          <ExportButton onClick={handleExportRevenueCSV} disabled={isExporting} title="Revenue CSV" description="All revenue transactions with invoice details" icon={<Download className="h-5 w-5" />} />
        </div>
      </div>

      <div className="bg-gradient-to-br from-blue-50 to-indigo-50 rounded-lg border border-blue-200 p-6">
        <div className="flex items-center gap-3 mb-4">
          <div className="w-10 h-10 bg-blue-600 rounded-lg flex items-center justify-center">
            <FileText className="h-6 w-6 text-white" />
          </div>
          <div>
            <h3 className="text-lg font-semibold text-gray-900">QuickBooks Integration</h3>
            <p className="text-sm text-gray-600">Export data in QuickBooks-compatible format</p>
          </div>
        </div>
        <div className="space-y-3">
          <ExportButton onClick={handleExportQuickBooksCSV} disabled={isExporting} title="QuickBooks CSV Export" description="Ready to import into QuickBooks Online or Desktop" icon={<Download className="h-5 w-5" />} variant="primary" />
          <div className="bg-blue-100 rounded-lg p-4 mt-4">
            <p className="text-sm text-blue-900"><strong>Import Instructions:</strong></p>
            <ol className="text-sm text-blue-800 mt-2 ml-4 list-decimal space-y-1">
              <li>Open QuickBooks and go to Banking → File Upload</li>
              <li>Select the downloaded CSV file</li>
              <li>Map columns to QuickBooks fields</li>
              <li>Review and confirm transactions</li>
            </ol>
          </div>
        </div>
      </div>

      <div className="bg-gray-50 rounded-lg p-6 border border-gray-200">
        <h3 className="text-lg font-semibold text-gray-900 mb-4">Export Summary</h3>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div className="bg-white rounded-lg p-4">
            <p className="text-sm text-gray-600">Total Transactions</p>
            <p className="text-2xl font-bold text-gray-900">{filterByDateRange([...revenues, ...expenses]).length}</p>
          </div>
          <div className="bg-white rounded-lg p-4">
            <p className="text-sm text-gray-600">Date Range</p>
            <p className="text-sm font-semibold text-gray-900">{new Date(dateRange.start).toLocaleDateString()} - {new Date(dateRange.end).toLocaleDateString()}</p>
          </div>
          <div className="bg-white rounded-lg p-4">
            <p className="text-sm text-gray-600">Total Revenue</p>
            <p className="text-2xl font-bold text-green-600">${filterByDateRange(revenues).reduce((sum, r) => sum + r.amount, 0).toLocaleString('en-US', { minimumFractionDigits: 2 })}</p>
          </div>
        </div>
      </div>

      <div className="bg-yellow-50 rounded-lg p-6 border border-yellow-200">
        <h3 className="text-lg font-semibold text-gray-900 mb-3">Export Tips</h3>
        <ul className="space-y-2 text-sm text-gray-700">
          <li className="flex items-start gap-2"><span className="text-yellow-600 font-bold">•</span><span>Export monthly for easier reconciliation with bank statements</span></li>
          <li className="flex items-start gap-2"><span className="text-yellow-600 font-bold">•</span><span>Keep PDF copies of quarterly reports for tax purposes</span></li>
          <li className="flex items-start gap-2"><span className="text-yellow-600 font-bold">•</span><span>Use QuickBooks export to sync with your accountant's system</span></li>
          <li className="flex items-start gap-2"><span className="text-yellow-600 font-bold">•</span><span>Download year-end summaries before January 31 for 1099 preparation</span></li>
        </ul>
      </div>
    </div>
  );
};

const ExportButton: React.FC<{ onClick: () => void; disabled: boolean; title: string; description: string; icon: React.ReactNode; variant?: 'default' | 'primary'; }> = ({ onClick, disabled, title, description, icon, variant = 'default' }) => (
  <button onClick={onClick} disabled={disabled} className={`w-full flex items-center gap-4 p-4 rounded-lg border transition-all ${variant === 'primary' ? 'bg-blue-600 border-blue-700 text-white hover:bg-blue-700' : 'bg-white border-gray-200 hover:border-gray-300 hover:shadow-sm'} disabled:opacity-50 disabled:cursor-not-allowed`}>
    <div className={`flex-shrink-0 w-10 h-10 rounded-lg flex items-center justify-center ${variant === 'primary' ? 'bg-blue-700' : 'bg-gray-100'}`}>{icon}</div>
    <div className="flex-1 text-left">
      <h4 className={`font-semibold ${variant === 'primary' ? 'text-white' : 'text-gray-900'}`}>{title}</h4>
      <p className={`text-sm ${variant === 'primary' ? 'text-blue-100' : 'text-gray-600'}`}>{description}</p>
    </div>
    <Download className={`h-5 w-5 flex-shrink-0 ${variant === 'primary' ? 'text-white' : 'text-gray-400'}`} />
  </button>
);

export default ExportTools;
