import React, { useEffect, useState } from 'react';
import { FileText, Download, AlertTriangle, CheckCircle } from 'lucide-react';
import type { Revenue, Expense, IFTAReport, TaxEstimate, Form2290Data } from '../../types/ownerOperator';
import { taxService } from '../../services/taxService';
import { exportService } from '../../services/exportService';

interface TaxComplianceProps {
  revenues: Revenue[];
  expenses: Expense[];
}

export const TaxCompliance: React.FC<TaxComplianceProps> = ({ revenues, expenses }) => {
  const [selectedQuarter, setSelectedQuarter] = useState('Q1');
  const [selectedYear, setSelectedYear] = useState(new Date().getFullYear());
  const [iftaReport, setIftaReport] = useState<IFTAReport | null>(null);
  const [taxEstimate, setTaxEstimate] = useState<TaxEstimate | null>(null);
  const [form2290Data, setForm2290Data] = useState<Form2290Data | null>(null);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    generateTaxReports();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [selectedQuarter, selectedYear, revenues, expenses]);

  const generateTaxReports = async () => {
    setLoading(true);
    try {
      const quarterRevenues = filterByQuarter(revenues, selectedQuarter, selectedYear);
      const quarterExpenses = filterByQuarter(expenses, selectedQuarter, selectedYear);

      const totalRevenue = quarterRevenues.reduce((sum, r) => sum + r.amount, 0);
      const totalExpenses = quarterExpenses.reduce((sum, e) => sum + e.amount, 0);

      const estimate = taxService.calculateQuarterlyTaxEstimate(totalRevenue, totalExpenses, selectedQuarter, selectedYear);
      setTaxEstimate(estimate);

      const trips = quarterRevenues.map((r) => ({ state: 'CA', miles: r.miles }));
      const fuelPurchases = quarterExpenses
        .filter((e) => e.category === 'fuel' && e.fuelGallons && e.state)
        .map((e) => ({ state: e.state as string, gallons: e.fuelGallons as number }));

      const ifta = await taxService.generateIFTAReport(selectedQuarter, selectedYear, trips, fuelPurchases);
      setIftaReport(ifta);

      if (selectedQuarter === 'Q3') {
        const form2290 = taxService.calculateForm2290('1HGBH41JXMN109186', 80000, 'July', selectedYear);
        setForm2290Data(form2290);
      } else {
        setForm2290Data(null);
      }
    } catch (e) {
      console.error('Error generating tax reports:', e);
    } finally {
      setLoading(false);
    }
  };

  const filterByQuarter = <T extends { date: Date }>(items: T[], quarter: string, year: number): T[] => {
    const quarterMonths: Record<string, number[]> = { Q1: [0,1,2], Q2: [3,4,5], Q3: [6,7,8], Q4: [9,10,11] };
    const months = quarterMonths[quarter] || [];
    return items.filter((item) => {
      const d = new Date(item.date);
      return d.getFullYear() === year && months.includes(d.getMonth());
    });
  };

  const handleDownloadIFTA = async () => {
    if (!iftaReport) return;
    try {
      const blob = await exportService.exportIFTAPDF(iftaReport);
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `IFTA-Report-${selectedQuarter}-${selectedYear}.pdf`;
      a.click();
      URL.revokeObjectURL(url);
    } catch (e) {
      console.error('Error downloading IFTA report:', e);
    }
  };

  const generate1099Forms = () => {
    const contractors = [{ name: 'John Doe', ssn: '123-45-6789', totalPaid: 5000 }];
    const companyInfo = { name: 'Your Company LLC', ein: '12-3456789' };
    const forms1099 = taxService.generate1099Data(selectedYear, contractors, companyInfo);
    console.log('1099 Forms generated:', forms1099);
    alert(`Generated ${forms1099.length} Form 1099s for year ${selectedYear}`);
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center py-12">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex gap-4 items-center">
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">Quarter</label>
          <select value={selectedQuarter} onChange={(e) => setSelectedQuarter(e.target.value)} className="px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent">
            <option value="Q1">Q1 (Jan-Mar)</option>
            <option value="Q2">Q2 (Apr-Jun)</option>
            <option value="Q3">Q3 (Jul-Sep)</option>
            <option value="Q4">Q4 (Oct-Dec)</option>
          </select>
        </div>
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">Year</label>
          <select value={selectedYear} onChange={(e) => setSelectedYear(Number(e.target.value))} className="px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent">
            {[2024, 2023, 2022].map((y) => (
              <option key={y} value={y}>{y}</option>
            ))}
          </select>
        </div>
      </div>

      <div className="bg-gradient-to-br from-blue-50 to-indigo-50 p-6 rounded-lg border border-blue-200">
        <div className="flex items-center justify-between mb-4">
          <h3 className="text-xl font-semibold text-gray-900">Quarterly Tax Estimate</h3>
          <FileText className="h-6 w-6 text-blue-600" />
        </div>

        {taxEstimate ? (
          <div className="space-y-4">
            <div className="grid grid-cols-2 gap-4">
              <div>
                <p className="text-sm text-gray-600">Estimated Income</p>
                <p className="text-2xl font-bold text-gray-900">${taxEstimate.estimatedIncome.toLocaleString('en-US', { minimumFractionDigits: 2 })}</p>
              </div>
              <div>
                <p className="text-sm text-gray-600">Estimated Expenses</p>
                <p className="text-2xl font-bold text-gray-900">${taxEstimate.estimatedExpenses.toLocaleString('en-US', { minimumFractionDigits: 2 })}</p>
              </div>
            </div>
            <div className="border-t border-blue-200 pt-4 space-y-2">
              <div className="flex justify-between"><span className="text-gray-700">Self-Employment Tax (15.3%):</span><span className="font-semibold">${taxEstimate.selfEmploymentTax.toLocaleString('en-US', { minimumFractionDigits: 2 })}</span></div>
              <div className="flex justify-between"><span className="text-gray-700">Estimated Income Tax:</span><span className="font-semibold">${taxEstimate.incomeTax.toLocaleString('en-US', { minimumFractionDigits: 2 })}</span></div>
              <div className="flex justify-between text-lg font-bold border-t border-blue-300 pt-2"><span>Total Quarterly Payment Due:</span><span className="text-blue-700">${taxEstimate.totalDue.toLocaleString('en-US', { minimumFractionDigits: 2 })}</span></div>
            </div>
            <div className="bg-blue-100 p-4 rounded-lg flex items-start gap-3">
              <AlertTriangle className="h-5 w-5 text-blue-700 mt-0.5 flex-shrink-0" />
              <div className="text-sm text-blue-900">
                <p className="font-semibold mb-1">Quarterly Payment Deadlines:</p>
                <ul className="space-y-1 ml-4 list-disc">
                  <li>Q1: April 15</li>
                  <li>Q2: June 15</li>
                  <li>Q3: September 15</li>
                  <li>Q4: January 15 (following year)</li>
                </ul>
              </div>
            </div>
          </div>
        ) : (
          <p className="text-gray-600">No data available for this quarter</p>
        )}
      </div>

      <div className="bg-white border border-gray-200 rounded-lg p-6">
        <div className="flex items-center justify-between mb-4">
          <h3 className="text-xl font-semibold text-gray-900">IFTA State-by-State Breakdown</h3>
          <button onClick={handleDownloadIFTA} disabled={!iftaReport} className="flex items-center gap-2 px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 disabled:bg-gray-400 disabled:cursor-not-allowed transition-colors">
            <Download className="h-4 w-4" />
            Download PDF
          </button>
        </div>
        {iftaReport && iftaReport.stateBreakdown.length > 0 ? (
          <div className="overflow-x-auto">
            <table className="min-w-full divide-y divide-gray-200">
              <thead className="bg-gray-50">
                <tr>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">State</th>
                  <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">Miles</th>
                  <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">Gallons Purchased</th>
                  <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">Tax Rate</th>
                  <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">Tax Owed</th>
                </tr>
              </thead>
              <tbody className="bg-white divide-y divide-gray-200">
                {iftaReport.stateBreakdown.map((s) => (
                  <tr key={s.state} className="hover:bg-gray-50">
                    <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">{s.state}</td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900 text-right">{s.miles.toLocaleString()}</td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900 text-right">{s.fuelGallons.toFixed(2)}</td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900 text-right">${s.taxRate.toFixed(4)}</td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm font-semibold text-gray-900 text-right">${s.taxOwed.toFixed(2)}</td>
                  </tr>
                ))}
              </tbody>
              <tfoot className="bg-gray-50">
                <tr>
                  <td colSpan={4} className="px-6 py-4 text-sm font-bold text-gray-900 text-right">Total IFTA Tax Due:</td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm font-bold text-blue-600 text-right">${iftaReport.totalTax.toFixed(2)}</td>
                </tr>
              </tfoot>
            </table>
          </div>
        ) : (
          <div className="text-center py-8 text-gray-600">
            <p>No IFTA data available for this quarter</p>
            <p className="text-sm mt-2">Make sure to log fuel purchases with state information</p>
          </div>
        )}
      </div>

      {selectedQuarter === 'Q3' && (
        <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-6">
          <div className="flex items-center gap-3 mb-4">
            <AlertTriangle className="h-6 w-6 text-yellow-600" />
            <h3 className="text-xl font-semibold text-gray-900">Form 2290 - Heavy Vehicle Use Tax</h3>
          </div>
          {form2290Data ? (
            <div className="space-y-4">
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <p className="text-sm text-gray-600">Tax Year</p>
                  <p className="text-lg font-semibold text-gray-900">{form2290Data.year}</p>
                </div>
                <div>
                  <p className="text-sm text-gray-600">VIN</p>
                  <p className="text-lg font-semibold text-gray-900">{form2290Data.vin}</p>
                </div>
                <div>
                  <p className="text-sm text-gray-600">Gross Weight</p>
                  <p className="text-lg font-semibold text-gray-900">{form2290Data.grossWeight.toLocaleString()} lbs</p>
                </div>
                <div>
                  <p className="text-sm text-gray-600">First Used Month</p>
                  <p className="text-lg font-semibold text-gray-900">{form2290Data.firstUsedMonth}</p>
                </div>
              </div>
              <div className="border-t border-yellow-300 pt-4">
                <div className="flex justify-between items-center">
                  <span className="text-lg font-semibold text-gray-900">Tax Amount Due:</span>
                  <span className="text-2xl font-bold text-yellow-700">${form2290Data.taxAmount.toFixed(2)}</span>
                </div>
              </div>
              <div className="bg-yellow-100 p-4 rounded-lg">
                <p className="text-sm text-yellow-900"><strong>Due Date:</strong> August 31, {form2290Data.year}</p>
                <p className="text-sm text-yellow-900 mt-2">File electronically at <a href="https://www.irs.gov/forms-pubs/about-form-2290" target="_blank" rel="noopener noreferrer" className="underline">IRS.gov</a></p>
              </div>
              <div className="flex items-center gap-2 text-sm">
                <div className={`px-3 py-1 rounded-full ${
                  form2290Data.status === 'paid' ? 'bg-green-100 text-green-800' :
                  form2290Data.status === 'filed' ? 'bg-blue-100 text-blue-800' :
                  'bg-yellow-100 text-yellow-800'
                }`}>
                  Status: {form2290Data.status.toUpperCase()}
                </div>
              </div>
            </div>
          ) : (
            <p className="text-gray-600">No Form 2290 data available</p>
          )}
        </div>
      )}

      <div className="bg-white border border-gray-200 rounded-lg p-6">
        <div className="flex items-center justify-between mb-4">
          <div>
            <h3 className="text-xl font-semibold text-gray-900">Form 1099 Generation</h3>
            <p className="text-sm text-gray-600 mt-1">Generate 1099-NEC forms for contractors paid $600 or more</p>
          </div>
          <FileText className="h-6 w-6 text-gray-400" />
        </div>
        <div className="space-y-4">
          <div className="bg-gray-50 p-4 rounded-lg">
            <p className="text-sm text-gray-700 mb-2"><strong>Year-End Requirement:</strong> Issue 1099-NEC forms to all contractors by January 31</p>
            <p className="text-sm text-gray-600">This includes owner-operators you've hired, independent contractors, and other non-employees</p>
          </div>
          <button onClick={generate1099Forms} className="w-full px-4 py-3 bg-purple-600 text-white rounded-lg hover:bg-purple-700 transition-colors flex items-center justify-center gap-2">
            <FileText className="h-5 w-5" />
            Generate 1099 Forms for {selectedYear}
          </button>
        </div>
      </div>

      <div className="bg-white border border-gray-200 rounded-lg p-6">
        <h3 className="text-xl font-semibold text-gray-900 mb-4">Tax Compliance Checklist</h3>
        <div className="space-y-3">
          <ComplianceItem checked={!!taxEstimate} text="Quarterly estimated taxes calculated" />
          <ComplianceItem checked={!!iftaReport && iftaReport.stateBreakdown.length > 0} text="IFTA fuel tax report prepared" />
          <ComplianceItem checked={!!form2290Data && selectedQuarter === 'Q3'} text="Form 2290 (HVUT) filed (if applicable)" />
          <ComplianceItem checked={false} text="Receipts organized and digitized" />
          <ComplianceItem checked={false} text="Mileage logs up to date" />
        </div>
      </div>
    </div>
  );
};

const ComplianceItem: React.FC<{ checked: boolean; text: string }> = ({ checked, text }) => (
  <div className="flex items-center gap-3">
    {checked ? <CheckCircle className="h-5 w-5 text-green-600" /> : <div className="h-5 w-5 rounded-full border-2 border-gray-300" />}
    <span className={`text-sm ${checked ? 'text-gray-900' : 'text-gray-600'}`}>{text}</span>
  </div>
);

export default TaxCompliance;
