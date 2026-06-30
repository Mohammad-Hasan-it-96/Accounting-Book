import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../data/models/customer.dart';
import '../../data/models/currency.dart';
import '../../data/models/transaction.dart' as tx_model;
import '../../core/helpers/format_helper.dart';
import '../../core/helpers/form_validators.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/app_form_field.dart';
import '../../core/widgets/app_snackbar.dart';
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
      AppSnackBar.warning(context, 'التاريخ مطلوب');
      return;
    }
    if (!hasValidType) {
      AppSnackBar.warning(context, 'نوع الحركة مطلوب');
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

    final confirm = await AppDialog.confirm(
      context,
      title: 'حذف الحركة',
      message: 'هل تريد حذف هذه الحركة؟ لا يمكن التراجع عن هذا الإجراء.',
      confirmLabel: 'حذف',
      destructive: true,
    );

    if (!confirm) return;
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
              Icon(Icons.people_outline,
                  size: AppIconSize.empty, color: Colors.grey.shade300),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'لا يوجد عملاء',
                style: TextStyle(
                    fontSize: AppFontSize.subtitle, color: Colors.grey.shade600),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'أضف عميلاً أولاً ثم أضف الحركة',
                style: TextStyle(
                    fontSize: AppFontSize.body, color: Colors.grey.shade400),
              ),
              const SizedBox(height: AppSpacing.xxl),
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
        final leave = await AppDialog.confirm(
          context,
          title: 'تجاهل التغييرات؟',
          message: 'لديك تغييرات غير محفوظة. هل تريد المغادرة؟',
          confirmLabel: 'تجاهل',
          cancelLabel: 'تابع التعديل',
          destructive: true,
        );
        if (leave && mounted) nav.pop();
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
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                AppDropdownField<int>(
                  value: _customers.any((c) => c.id == _selectedCustomerId)
                      ? _selectedCustomerId
                      : null,
                  label: 'العميل',
                  icon: Icons.person,
                  required: true,
                  requiredMessage: 'العميل مطلوب',
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
                ),
                Gap.h12,

                AppDropdownField<int>(
                  value: _currencies.any((c) => c.id == _selectedCurrencyId)
                      ? _selectedCurrencyId
                      : null,
                  label: 'العملة',
                  icon: Icons.currency_exchange,
                  required: true,
                  requiredMessage: 'العملة مطلوبة',
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
                ),
                Gap.h12,

                // المبلغ
                AppTextField(
                  controller: _amountCtrl,
                  label: 'المبلغ',
                  icon: Icons.monetization_on,
                  required: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: FormValidators.amount(requiredMessage: 'المبلغ مطلوب'),
                  onChanged: (_) => _markDirty(),
                ),
                Gap.h12,

                // التاريخ
                AppDateField(
                  label: 'التاريخ',
                  required: true,
                  value: _selectedDate,
                  format: FormatHelper.formatDateFromDateTime,
                  onTap: () async {
                    await _pickDate();
                    _markDirty();
                  },
                ),
                Gap.h12,

                AppDropdownField<int>(
                  value: _normalizeInFlag(_inFlag),
                  label: 'نوع الحركة',
                  icon: Icons.compare_arrows,
                  required: true,
                  requiredMessage: 'نوع الحركة مطلوب',
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
                ),
                Gap.h12,

                // ملاحظة
                AppTextField(
                  controller: _remarksCtrl,
                  label: 'ملاحظة (اختياري)',
                  icon: Icons.note,
                  maxLines: 2,
                  onChanged: (_) => _markDirty(),
                ),
                const SizedBox(height: AppSpacing.xxl),

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

