import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/expense.dart';
import '../providers/expense_provider.dart';

class ExpenseEntryScreen extends ConsumerStatefulWidget {
  const ExpenseEntryScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ExpenseEntryScreen> createState() => _ExpenseEntryScreenState();
}

class _ExpenseEntryScreenState extends ConsumerState<ExpenseEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _odometerController = TextEditingController();
  final _loadNumberController = TextEditingController();

  ExpenseCategory _selectedCategory = ExpenseCategory.fuel;
  PaymentMethod _selectedPaymentMethod = PaymentMethod.credit;
  DateTime _selectedDate = DateTime.now();
  List<PlatformFile> _selectedFiles = [];

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _odometerController.dispose();
    _loadNumberController.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
    );

    if (result != null) {
      setState(() {
        _selectedFiles.addAll(result.files);
      });
    }
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  Future<void> _submitExpense() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload at least one receipt'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final now = DateTime.now();
    final receipts = _selectedFiles
        .map(
          (file) => Receipt(
            id: 'receipt-${now.millisecondsSinceEpoch}-${file.name.hashCode}',
            fileName: file.name,
            fileSize: file.size,
            fileType: (file.extension ?? '').toLowerCase(),
            url: file.path ?? '',
            uploadedAt: now.toIso8601String(),
          ),
        )
        .toList();

    final expense = Expense(
      id: 'EXP-${now.millisecondsSinceEpoch}',
      operatorId: 'OP-001',
      operatorName: 'Current User',
      date: _selectedDate.toIso8601String(),
      category: _selectedCategory,
      amount: double.parse(_amountController.text),
      description: _descriptionController.text,
      paymentMethod: _selectedPaymentMethod,
      location: _locationController.text,
      odometer: _odometerController.text.isEmpty
          ? null
          : int.parse(_odometerController.text),
      receipts: receipts,
      loadNumber:
          _loadNumberController.text.isEmpty ? null : _loadNumberController.text,
      status: ExpenseStatus.pending,
      submittedAt: now.toIso8601String(),
    );

    try {
      await ref.read(expenseNotifierProvider.notifier).submitExpense(expense);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Expense submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        _formKey.currentState!.reset();
        _amountController.clear();
        _descriptionController.clear();
        _locationController.clear();
        _odometerController.clear();
        _loadNumberController.clear();
        setState(() {
          _selectedFiles.clear();
          _selectedDate = DateTime.now();
          _selectedCategory = ExpenseCategory.fuel;
          _selectedPaymentMethod = PaymentMethod.credit;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Entry'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ExpenseHistoryScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSummaryCard(),
            const SizedBox(height: 16),
            _buildExpenseForm(),
            const SizedBox(height: 16),
            _buildReceiptSection(),
            const SizedBox(height: 24),
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'New Expense',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Track and submit your expenses with digital receipts',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Expense Details', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: const Text('Date'),
              subtitle: Text(
                '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (date != null) setState(() => _selectedDate = date);
              },
            ),
            const Divider(),
            DropdownButtonFormField<ExpenseCategory>(
              value: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Category',
                prefixIcon: Icon(Icons.category),
              ),
              items: ExpenseCategory.values
                  .map(
                    (c) => DropdownMenuItem(
                      value: c,
                      child: Text(_getCategoryLabel(c)),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _selectedCategory = v ?? _selectedCategory),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixIcon: Icon(Icons.attach_money),
                prefixText: '\$',
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) return 'Please enter amount';
                if (double.tryParse(value) == null) return 'Please enter a valid number';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 3,
              validator: (value) =>
                  (value == null || value.isEmpty) ? 'Please enter description' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<PaymentMethod>(
              value: _selectedPaymentMethod,
              decoration: const InputDecoration(
                labelText: 'Payment Method',
                prefixIcon: Icon(Icons.payment),
              ),
              items: PaymentMethod.values
                  .map(
                    (m) => DropdownMenuItem(
                      value: m,
                      child: Text(_getPaymentMethodLabel(m)),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _selectedPaymentMethod = v ?? _selectedPaymentMethod),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Location',
                prefixIcon: Icon(Icons.location_on),
                hintText: 'City, State',
              ),
              validator: (value) =>
                  (value == null || value.isEmpty) ? 'Please enter location' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _odometerController,
              decoration: const InputDecoration(
                labelText: 'Odometer Reading (Optional)',
                prefixIcon: Icon(Icons.speed),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _loadNumberController,
              decoration: const InputDecoration(
                labelText: 'Load Number (Optional)',
                prefixIcon: Icon(Icons.local_shipping),
                hintText: 'LD-2025-XXX',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Receipt Upload', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _pickFiles,
              icon: const Icon(Icons.upload_file),
              label: const Text('Upload Receipts'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
            ),
            const SizedBox(height: 8),
            Text(
              'Accepted: JPG, PNG, PDF (Max 10MB each)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            ),
            if (_selectedFiles.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Uploaded Files (${_selectedFiles.length})',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              ..._selectedFiles.asMap().entries.map((entry) {
                final index = entry.key;
                final file = entry.value;
                final isPdf = (file.extension ?? '').toLowerCase() == 'pdf';
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(isPdf ? Icons.picture_as_pdf : Icons.image,
                      color: Theme.of(context).colorScheme.primary),
                  title: Text(file.name),
                  subtitle: Text(_formatFileSize(file.size)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _removeFile(index),
                  ),
                );
              }).toList(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _submitExpense,
      style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 56)),
      child: const Text('Submit Expense',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }

  String _getCategoryLabel(ExpenseCategory category) {
    switch (category) {
      case ExpenseCategory.fuel:
        return '⛽ Fuel';
      case ExpenseCategory.maintenance:
        return '🔧 Maintenance';
      case ExpenseCategory.tolls:
        return '🛣️ Tolls';
      case ExpenseCategory.permits:
        return '📄 Permits';
      case ExpenseCategory.insurance:
        return '🛡️ Insurance';
      case ExpenseCategory.supplies:
        return '📦 Supplies';
      case ExpenseCategory.other:
        return '📋 Other';
    }
  }

  String _getPaymentMethodLabel(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash:
        return '💵 Cash';
      case PaymentMethod.credit:
        return '💳 Credit Card';
      case PaymentMethod.debit:
        return '💳 Debit Card';
      case PaymentMethod.companyCard:
        return '🏢 Company Card';
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class ExpenseHistoryScreen extends ConsumerStatefulWidget {
  const ExpenseHistoryScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ExpenseHistoryScreen> createState() => _ExpenseHistoryScreenState();
}

class _ExpenseHistoryScreenState extends ConsumerState<ExpenseHistoryScreen> {
  ExpenseStatus? _filterStatus;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(expenseNotifierProvider.notifier).loadExpenses();
    });
  }

  @override
  Widget build(BuildContext context) {
    final expensesAsync = ref.watch(expenseNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Expense History')),
      body: Column(
        children: [
            _buildFilters(),
            Expanded(
              child: expensesAsync.when(
                data: (expenses) {
                  final filtered = _filterExpenses(expenses);
                  if (filtered.isEmpty) return _buildEmptyState();
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) => _buildExpenseCard(filtered[i]),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Error: $e'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => ref.read(expenseNotifierProvider.notifier).loadExpenses(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.surface,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip('All', null),
            const SizedBox(width: 8),
            _buildFilterChip('Pending', ExpenseStatus.pending),
            const SizedBox(width: 8),
            _buildFilterChip('Approved', ExpenseStatus.approved),
            const SizedBox(width: 8),
            _buildFilterChip('Rejected', ExpenseStatus.rejected),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, ExpenseStatus? status) {
    final isSelected = _filterStatus == status;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) => setState(() => _filterStatus = selected ? status : null),
    );
  }

  List<Expense> _filterExpenses(List<Expense> expenses) {
    if (_filterStatus == null) return expenses;
    return expenses.where((e) => e.status == _filterStatus).toList();
  }

  Widget _buildExpenseCard(Expense expense) {
    final amount = expense.amount.toStringAsFixed(2);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_getCategoryLabel(expense.category),
                    style: Theme.of(context).textTheme.titleMedium),
                Text('\$$amount',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(color: Colors.green, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Text(expense.description, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(DateTime.tryParse(expense.date)?.toLocal().toString().split(' ').first ?? expense.date,
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(width: 16),
                const Icon(Icons.location_on, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(expense.location, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${expense.receipts.length} receipt(s)',
                    style: Theme.of(context).textTheme.bodySmall),
                _buildStatusChip(expense.status),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(ExpenseStatus status) {
    late Color color;
    late String label;
    switch (status) {
      case ExpenseStatus.pending:
        color = Colors.orange;
        label = 'PENDING';
        break;
      case ExpenseStatus.approved:
        color = Colors.green;
        label = 'APPROVED';
        break;
      case ExpenseStatus.rejected:
        color = Colors.red;
        label = 'REJECTED';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  String _getCategoryLabel(ExpenseCategory category) {
    switch (category) {
      case ExpenseCategory.fuel:
        return '⛽ Fuel';
      case ExpenseCategory.maintenance:
        return '🔧 Maintenance';
      case ExpenseCategory.tolls:
        return '🛣️ Tolls';
      case ExpenseCategory.permits:
        return '📄 Permits';
      case ExpenseCategory.insurance:
        return '🛡️ Insurance';
      case ExpenseCategory.supplies:
        return '📦 Supplies';
      case ExpenseCategory.other:
        return '📋 Other';
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('No expenses found', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text('Submit your first expense to get started',
              style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
