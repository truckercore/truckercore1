import React, { useRef, useState } from 'react';
import { Upload, X, Camera } from 'lucide-react';
import type { Expense, ExpenseCategory } from '../../types/ownerOperator';
import { ocrService } from '../../services/ocrService';
import { expenseService } from '../../services/expenseService';

interface ExpenseEntryProps {
  onClose: () => void;
  onExpenseAdded: (expense: Expense) => void;
}

export const ExpenseEntry: React.FC<ExpenseEntryProps> = ({ onClose, onExpenseAdded }) => {
  const [formData, setFormData] = useState({
    date: new Date().toISOString().split('T')[0],
    category: 'fuel' as ExpenseCategory,
    amount: '',
    description: '',
    mileage: '',
    fuelGallons: '',
    state: '',
    deductible: true,
  });
  const [receiptFile, setReceiptFile] = useState<File | null>(null);
  const [isProcessing, setIsProcessing] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const handleFileUpload = async (file: File) => {
    setReceiptFile(file);
    setIsProcessing(true);
    try {
      const receiptData = await ocrService.parseReceipt(file);
      setFormData((prev) => ({
        ...prev,
        date: receiptData.date?.toISOString().split('T')[0] || prev.date,
        amount: receiptData.amount?.toString() || prev.amount,
        category: (receiptData.category as ExpenseCategory) || prev.category,
        fuelGallons: receiptData.fuelGallons?.toString() || prev.fuelGallons,
        description: receiptData.merchantName || prev.description,
      }));
    } catch (e) {
      console.error('Error parsing receipt:', e);
      alert('Could not parse receipt. Please enter details manually.');
    } finally {
      setIsProcessing(false);
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      const expense = await expenseService.createExpense({
        date: new Date(formData.date),
        category: formData.category,
        amount: parseFloat(formData.amount),
        description: formData.description,
        mileage: formData.mileage ? parseFloat(formData.mileage) : undefined,
        fuelGallons: formData.fuelGallons ? parseFloat(formData.fuelGallons) : undefined,
        state: formData.state || undefined,
        deductible: formData.deductible,
        receiptUrl: receiptFile ? URL.createObjectURL(receiptFile) : undefined,
      } as Partial<Expense>);
      onExpenseAdded(expense);
    } catch (error) {
      console.error('Error creating expense:', error);
      alert('Failed to create expense');
    }
  };

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div className="bg-white rounded-lg shadow-xl max-w-2xl w-full max-h-[90vh] overflow-y-auto">
        <div className="flex items-center justify-between p-6 border-b">
          <h2 className="text-2xl font-semibold text-gray-900">Add Expense</h2>
          <button onClick={onClose} className="text-gray-400 hover:text-gray-500 transition-colors">
            <X className="h-6 w-6" />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="p-6 space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">Receipt (Optional - Auto-fill with OCR)</label>
            <div onClick={() => fileInputRef.current?.click()} className="border-2 border-dashed border-gray-300 rounded-lg p-6 text-center hover:border-blue-500 cursor-pointer transition-colors">
              {isProcessing ? (
                <div className="flex items-center justify-center">
                  <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
                  <span className="ml-3 text-gray-600">Processing receipt...</span>
                </div>
              ) : receiptFile ? (
                <div className="flex items-center justify-center">
                  <Camera className="h-8 w-8 text-green-600" />
                  <span className="ml-3 text-gray-900">{receiptFile.name}</span>
                </div>
              ) : (
                <div>
                  <Upload className="h-12 w-12 text-gray-400 mx-auto mb-2" />
                  <p className="text-gray-600">Click to upload receipt</p>
                  <p className="text-xs text-gray-500 mt-1">PNG, JPG up to 10MB</p>
                </div>
              )}
            </div>
            <input ref={fileInputRef} type="file" accept="image/*" className="hidden" onChange={(e) => e.target.files?.[0] && handleFileUpload(e.target.files[0])} />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Date *</label>
            <input type="date" required value={formData.date} onChange={(e) => setFormData({ ...formData, date: e.target.value })} className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent" />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Category *</label>
            <select required value={formData.category} onChange={(e) => setFormData({ ...formData, category: e.target.value as ExpenseCategory })} className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent">
              <option value="fuel">Fuel</option>
              <option value="maintenance">Maintenance</option>
              <option value="insurance">Insurance</option>
              <option value="tolls">Tolls</option>
              <option value="permits">Permits</option>
              <option value="depreciation">Depreciation</option>
              <option value="meals">Meals (80% deductible)</option>
              <option value="lodging">Lodging</option>
              <option value="other">Other</option>
            </select>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Amount *</label>
            <div className="relative">
              <span className="absolute left-3 top-2 text-gray-500">$</span>
              <input type="number" step="0.01" required value={formData.amount} onChange={(e) => setFormData({ ...formData, amount: e.target.value })} className="w-full pl-8 pr-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent" placeholder="0.00" />
            </div>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Description *</label>
            <input type="text" required value={formData.description} onChange={(e) => setFormData({ ...formData, description: e.target.value })} className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent" placeholder="Vendor/merchant name" />
          </div>

          {formData.category === 'fuel' && (
            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Gallons</label>
                <input type="number" step="0.01" value={formData.fuelGallons} onChange={(e) => setFormData({ ...formData, fuelGallons: e.target.value })} className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent" placeholder="0.00" />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">State</label>
                <input type="text" maxLength={2} value={formData.state} onChange={(e) => setFormData({ ...formData, state: e.target.value.toUpperCase() })} className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent uppercase" placeholder="CA" />
              </div>
            </div>
          )}

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Mileage (for allocation)</label>
            <input type="number" step="0.1" value={formData.mileage} onChange={(e) => setFormData({ ...formData, mileage: e.target.value })} className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent" placeholder="0.0" />
          </div>

          <div className="flex items-center">
            <input type="checkbox" id="deductible" checked={formData.deductible} onChange={(e) => setFormData({ ...formData, deductible: e.target.checked })} className="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded" />
            <label htmlFor="deductible" className="ml-2 block text-sm text-gray-900">Tax deductible</label>
          </div>

          <div className="flex gap-3 pt-4">
            <button type="button" onClick={onClose} className="flex-1 px-4 py-2 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-colors">Cancel</button>
            <button type="submit" className="flex-1 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors">Add Expense</button>
          </div>
        </form>
      </div>
    </div>
  );
};

export default ExpenseEntry;
