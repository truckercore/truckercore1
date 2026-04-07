import React, { useState } from 'react';
import './ExpenseEntry.css';
import { Expense, Receipt } from '../../types';
import ReceiptUpload from './ReceiptUpload';

const ExpenseEntry: React.FC = () => {
  const [formData, setFormData] = useState({
    operatorName: '',
    date: new Date().toISOString().split('T')[0],
    category: 'fuel' as Expense['category'],
    amount: '',
    description: '',
    paymentMethod: 'credit' as Expense['paymentMethod'],
    location: '',
    odometer: '',
    loadNumber: '',
  });

  const [receipts, setReceipts] = useState<Receipt[]>([]);
  const [submittedExpenses, setSubmittedExpenses] = useState<Expense[]>([]);
  const [showSuccess, setShowSuccess] = useState(false);

  const handleInputChange = (
    e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement>,
  ) => {
    const { name, value } = e.target;
    setFormData((prev) => ({ ...prev, [name]: value }));
  };

  const handleReceiptsChange = (newReceipts: Receipt[]) => {
    setReceipts(newReceipts);
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();

    if (receipts.length === 0) {
      alert('Please upload at least one receipt');
      return;
    }

    const expense: Expense = {
      id: `EXP-${Date.now()}`,
      operatorId: 'OP-' + formData.operatorName.replace(/\s/g, '-'),
      operatorName: formData.operatorName,
      date: formData.date,
      category: formData.category,
      amount: parseFloat(formData.amount),
      description: formData.description,
      paymentMethod: formData.paymentMethod,
      location: formData.location,
      odometer: formData.odometer ? parseInt(formData.odometer) : undefined,
      receipts: receipts,
      loadNumber: formData.loadNumber || undefined,
      status: 'pending',
      submittedAt: new Date().toISOString(),
    };

    setSubmittedExpenses([expense, ...submittedExpenses]);
    setShowSuccess(true);

    setFormData({
      operatorName: formData.operatorName,
      date: new Date().toISOString().split('T')[0],
      category: 'fuel',
      amount: '',
      description: '',
      paymentMethod: 'credit',
      location: '',
      odometer: '',
      loadNumber: '',
    });
    setReceipts([]);

    setTimeout(() => setShowSuccess(false), 3000);
  };

  const getTotalExpenses = () => submittedExpenses.reduce((sum, exp) => sum + exp.amount, 0);

  const getCategoryIcon = (category: string) => {
    const icons: { [key: string]: string } = {
      fuel: '⛽',
      maintenance: '🔧',
      tolls: '🛣️',
      permits: '📄',
      insurance: '🛡️',
      supplies: '📦',
      other: '📋',
    };
    return icons[category] || '📋';
  };

  return (
    <div className="expense-entry">
      <header className="expense-header">
        <h1>💰 Owner Operator Expense Entry</h1>
        <div className="expense-summary">
          <div className="summary-card">
            <span className="summary-value">${getTotalExpenses().toFixed(2)}</span>
            <span className="summary-label">Total Expenses</span>
          </div>
          <div className="summary-card">
            <span className="summary-value">{submittedExpenses.length}</span>
            <span className="summary-label">Entries This Session</span>
          </div>
          <div className="summary-card">
            <span className="summary-value">{submittedExpenses.filter((e) => e.status === 'pending').length}</span>
            <span className="summary-label">Pending Review</span>
          </div>
        </div>
      </header>

      <div className="expense-content">
        <div className="expense-form-section">
          <div className="form-card">
            <h2>Submit New Expense</h2>

            {showSuccess && <div className="success-message">✓ Expense submitted successfully!</div>}

            <form onSubmit={handleSubmit}>
              <div className="form-row">
                <div className="form-group">
                  <label htmlFor="operatorName">Operator Name *</label>
                  <input
                    type="text"
                    id="operatorName"
                    name="operatorName"
                    value={formData.operatorName}
                    onChange={handleInputChange}
                    required
                    placeholder="Enter your full name"
                  />
                </div>

                <div className="form-group">
                  <label htmlFor="date">Expense Date *</label>
                  <input
                    type="date"
                    id="date"
                    name="date"
                    value={formData.date}
                    onChange={handleInputChange}
                    required
                    max={new Date().toISOString().split('T')[0]}
                  />
                </div>
              </div>

              <div className="form-row">
                <div className="form-group">
                  <label htmlFor="category">Expense Category *</label>
                  <select id="category" name="category" value={formData.category} onChange={handleInputChange} required>
                    <option value="fuel">⛽ Fuel</option>
                    <option value="maintenance">🔧 Maintenance & Repairs</option>
                    <option value="tolls">🛣️ Tolls</option>
                    <option value="permits">📄 Permits & Licenses</option>
                    <option value="insurance">🛡️ Insurance</option>
                    <option value="supplies">📦 Supplies</option>
                    <option value="other">📋 Other</option>
                  </select>
                </div>

                <div className="form-group">
                  <label htmlFor="amount">Amount ($) *</label>
                  <input
                    type="number"
                    id="amount"
                    name="amount"
                    value={formData.amount}
                    onChange={handleInputChange}
                    required
                    min="0"
                    step="0.01"
                    placeholder="0.00"
                  />
                </div>
              </div>

              <div className="form-group">
                <label htmlFor="description">Description *</label>
                <textarea
                  id="description"
                  name="description"
                  value={formData.description}
                  onChange={handleInputChange}
                  required
                  rows={3}
                  placeholder="Provide details about this expense..."
                />
              </div>

              <div className="form-row">
                <div className="form-group">
                  <label htmlFor="paymentMethod">Payment Method *</label>
                  <select id="paymentMethod" name="paymentMethod" value={formData.paymentMethod} onChange={handleInputChange} required>
                    <option value="cash">💵 Cash</option>
                    <option value="credit">💳 Credit Card</option>
                    <option value="debit">💳 Debit Card</option>
                    <option value="company-card">🏢 Company Card</option>
                  </select>
                </div>

                <div className="form-group">
                  <label htmlFor="location">Location *</label>
                  <input
                    type="text"
                    id="location"
                    name="location"
                    value={formData.location}
                    onChange={handleInputChange}
                    required
                    placeholder="City, State"
                  />
                </div>
              </div>

              <div className="form-row">
                <div className="form-group">
                  <label htmlFor="odometer">Odometer Reading</label>
                  <input
                    type="number"
                    id="odometer"
                    name="odometer"
                    value={formData.odometer}
                    onChange={handleInputChange}
                    placeholder="Current mileage"
                  />
                </div>

                <div className="form-group">
                  <label htmlFor="loadNumber">Load Number (if applicable)</label>
                  <input
                    type="text"
                    id="loadNumber"
                    name="loadNumber"
                    value={formData.loadNumber}
                    onChange={handleInputChange}
                    placeholder="LD-2025-XXX"
                  />
                </div>
              </div>

              <ReceiptUpload receipts={receipts} onChange={handleReceiptsChange} />

              <div className="form-actions">
                <button type="submit" className="btn-submit">
                  Submit Expense
                </button>
              </div>
            </form>
          </div>
        </div>

        <div className="expense-history-section">
          <div className="history-card">
            <h2>Recent Expenses</h2>

            {submittedExpenses.length === 0 ? (
              <div className="empty-state">
                <p>No expenses submitted yet</p>
                <small>Your submitted expenses will appear here</small>
              </div>
            ) : (
              <div className="expense-list">
                {submittedExpenses.map((expense) => (
                  <div key={expense.id} className="expense-item">
                    <div className="expense-item-header">
                      <div className="expense-category-icon">{getCategoryIcon(expense.category)}</div>
                      <div className="expense-item-info">
                        <strong>{expense.category.replace('-', ' ').toUpperCase()}</strong>
                        <small>{new Date(expense.date).toLocaleDateString()}</small>
                      </div>
                      <div className="expense-amount">${expense.amount.toFixed(2)}</div>
                    </div>
                    <div className="expense-item-details">
                      <p>{expense.description}</p>
                      <div className="expense-meta">
                        <span>📍 {expense.location}</span>
                        <span>💳 {expense.paymentMethod}</span>
                        <span className={`status-badge status-${expense.status}`}>{expense.status}</span>
                      </div>
                      <div className="expense-receipts-count">📎 {expense.receipts.length} receipt(s) attached</div>
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

export default ExpenseEntry;
