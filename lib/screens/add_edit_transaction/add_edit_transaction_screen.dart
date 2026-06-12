import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../data/models/customer.dart';
import '../../data/models/currency.dart';
import '../../data/models/transaction.dart' as tx_model;
import '../../core/helpers/format_helper.dart';
import '../../data/repositories/customer_repository.dart';
import '../../data/repositories/currency_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../providers/app_provider.dart';

class AddEditTransactionScreen extends StatefulWidget {
  final Customer? customer;
  final Currency? currency;
  final tx_model.Transaction? transaction; // null = إضافة جديدة

  const AddEditTransactionScreen({
    super.key,
    this.customer,
    this.currency,
    this.transaction,
  });

  @override
  State<AddEditTransactionScreen> createState() =>
      _AddEditTransactionScreenState();
}

class _TransactionTypeOption {
  final int inValue;
  final String label;

  const _TransactionTypeOption({required this.inValue, required this.label});
}

class _AddEditTransactionScreenState extends State<AddEditTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  static const List<_TransactionTypeOption> _transactionTypeOptions = [
    _TransactionTypeOption(inValue: 1, label: 'مطلوب'),
    _TransactionTypeOption(inValue: -1, label: 'مدفوع'),
  ];

  late final TextEditingController _amountCtrl;
  late final TextEditingController _remarksCtrl;
  late DateTime? _selectedDate;

  List<Customer> _customers = const [];
  List<Currency> _currencies = const [];
  int? _selectedCustomerId;
  int? _selectedCurrencyId;
  int _inFlag = _transactionTypeOptions.first.inValue;
  bool _saving       = false;
  bool _dirty        = false;
  bool _loadingLookups = true;

  void _markDirty() { if (!_dirty) setState(() => _dirty = true); }

  int _normalizeInFlag(int? rawValue) {
    final exists = _transactionTypeOptions.any((o) => o.inValue == rawValue);
    return exists ? rawValue! : _transactionTypeOptions.first.inValue;
  }

  @override
  void initState() {
    super.initState();
    final tx = widget.transaction;
    _amountCtrl =
        TextEditingController(text: tx != null ? tx.out.toString() : '');
    _remarksCtrl =
        TextEditingController(text: tx?.remarks ?? '');
    _inFlag = _normalizeInFlag(tx?.inFlag);
    _selectedDate =
        FormatHelper.parseDate(tx?.date) ?? (tx == null ? DateTime.now() : null);
    _selectedCustomerId = tx?.cusId ?? widget.customer?.id;
    _selectedCurrencyId = tx?.currId ?? widget.currency?.id;
    _loadLookups();
  }

  Future<void> _loadLookups() async {
    final dbHelper = context.read<AppProvider>().dbHelper;
    final customers = await CustomerRepository(dbHelper).getAll();
    final currencies = await CurrencyRepository(dbHelper).getAll();

    if (!mounted) return;

    setState(() {
      _customers = customers;
      _currencies = currencies;

      if (_selectedCustomerId == null && _customers.isNotEmpty) {
        _selectedCustomerId = _customers.first.id;
      }
      if (_selectedCurrencyId == null && _currencies.isNotEmpty) {
        _selectedCurrencyId = _currencies.first.id;
      }

      _loadingLookups = false;
    });
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _selectedDate = d);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.lightImpact();
      return;
    }

    final customerId = _selectedCustomerId;
    final currencyId = _selectedCurrencyId;
    final selectedDate = _selectedDate;
    final hasValidType =
        _transactionTypeOptions.any((o) => o.inValue == _inFlag);

    if (customerId == null || currencyId == null) return;
    if (selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('التاريخ مطلوب')),
      );
      return;
    }
    if (!hasValidType) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('نوع الحركة مطلوب')),
      );
      return;
    }

    setState(() => _saving = true);

    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    final now = DateTime.now().toIso8601String();
    final dateStr = FormatHelper.formatDateForDb(selectedDate);

    final tx = tx_model.Transaction(
      id: widget.transaction?.id,
      cusId: customerId,
      inFlag: _inFlag,
      out: amount,
      date: dateStr,
      remarks: _remarksCtrl.text.trim().isEmpty ? null : _remarksCtrl.text.trim(),
      currId: currencyId,
      now: now,
    );

    final dbHelper = context.read<AppProvider>().dbHelper;
    final repo = TransactionRepository(dbHelper);
    if (widget.transaction == null) {
      await repo.insert(tx);
    } else {
      await repo.update(tx);
    }

    if (!mounted) return;
    HapticFeedback.mediumImpact();
    Navigator.pop(context, true);
  }

  Future<void> _deleteTransaction() async {
    final txId = widget.transaction?.id;
    if (txId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل تريد حذف هذه الحركة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!mounted) return;

    HapticFeedback.heavyImpact();
    setState(() => _saving = true);
    final dbHelper = context.read<AppProvider>().dbHelper;
    await TransactionRepository(dbHelper).delete(txId);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.transaction != null;

    if (_loadingLookups) {
      return Scaffold(
        appBar: AppBar(title: Text(isEdit ? 'تعديل حركة' : 'إضافة حركة')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_customers.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(isEdit ? 'تعديل حركة' : 'إضافة حركة')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.people_outline, size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(
                'لا يوجد عملاء',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              Text(
                'أضف عميلاً أولاً ثم أضف الحركة',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text('العودة'),
              ),
            ],
          ),
        ),
      );
    }

    return PopScope(
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        final leave = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('تجاهل التغييرات؟'),
            content: const Text('لديك تغييرات غير محفوظة. هل تريد المغادرة؟'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('تابع التعديل'),
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('تجاهل'),
              ),
            ],
          ),
        );
        if (leave == true && mounted) nav.pop();
      },
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          appBar: AppBar(
            title: Text(isEdit ? 'تعديل حركة' : 'إضافة حركة'),
            actions: [
              if (isEdit)
                IconButton(
                  tooltip: 'حذف الحركة',
                  onPressed: _saving ? null : _deleteTransaction,
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                ),
            ],
          ),
          body: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                DropdownButtonFormField<int>(
                  initialValue: _customers.any((c) => c.id == _selectedCustomerId)
                      ? _selectedCustomerId
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'العميل *',
                    prefixIcon: Icon(Icons.person),
                  ),
                  items: _customers
                      .where((c) => c.id != null)
                      .map(
                        (c) => DropdownMenuItem<int>(
                          value: c.id!,
                          child: Text(c.name),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    setState(() => _selectedCustomerId = v);
                    _markDirty();
                  },
                  validator: (v) => v == null ? 'العميل مطلوب' : null,
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<int>(
                  initialValue: _currencies.any((c) => c.id == _selectedCurrencyId)
                      ? _selectedCurrencyId
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'العملة *',
                    prefixIcon: Icon(Icons.currency_exchange),
                  ),
                  items: _currencies
                      .where((c) => c.id != null)
                      .map(
                        (c) => DropdownMenuItem<int>(
                          value: c.id!,
                          child: Text(c.displayName),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    setState(() => _selectedCurrencyId = v);
                    _markDirty();
                  },
                  validator: (v) => v == null ? 'العملة مطلوبة' : null,
                ),
                const SizedBox(height: 12),

                // المبلغ
                TextFormField(
                  controller: _amountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'المبلغ *',
                    prefixIcon: Icon(Icons.monetization_on),
                  ),
                  onChanged: (_) => _markDirty(),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'المبلغ مطلوب';
                    final amount = double.tryParse(v.trim());
                    if (amount == null) return 'أدخل رقماً صحيحاً';
                    if (amount <= 0) return 'أدخل مبلغاً أكبر من صفر';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // التاريخ
                InkWell(
                  onTap: () async {
                    await _pickDate();
                    _markDirty();
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'التاريخ *',
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(
                      _selectedDate == null
                          ? 'اختر التاريخ'
                          : FormatHelper.formatDateFromDateTime(_selectedDate!),
                      style: TextStyle(
                        color: _selectedDate == null
                            ? Colors.grey.shade600
                            : null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                DropdownButtonFormField<int>(
                  initialValue: _normalizeInFlag(_inFlag),
                  decoration: const InputDecoration(
                    labelText: 'نوع الحركة *',
                    prefixIcon: Icon(Icons.compare_arrows),
                  ),
                  items: _transactionTypeOptions
                      .map(
                        (option) => DropdownMenuItem<int>(
                          value: option.inValue,
                          child: Text(option.label),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    setState(() => _inFlag = _normalizeInFlag(v));
                    _markDirty();
                  },
                  validator: (v) => v == null ? 'نوع الحركة مطلوب' : null,
                ),
                const SizedBox(height: 12),

                // ملاحظة
                TextFormField(
                  controller: _remarksCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظة (اختياري)',
                    prefixIcon: Icon(Icons.note),
                  ),
                  onChanged: (_) => _markDirty(),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(isEdit ? 'حفظ التعديلات' : 'إضافة الحركة'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

