import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../data/models/customer.dart';
import '../../data/models/currency.dart';
import '../../data/models/transaction.dart' as tx_model;
import '../../data/repositories/transaction_repository.dart';
import '../../providers/app_provider.dart';
import '../../core/helpers/customer_helper.dart';
import '../../core/helpers/format_helper.dart';
import '../../core/helpers/statement_helper.dart';
import '../../core/services/pdf_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_dimens.dart';
import '../add_edit_transaction/add_edit_transaction_screen.dart';

class CustomerDetailsScreen extends StatefulWidget {
  final Customer customer;
  final Currency currency;

  const CustomerDetailsScreen({
    super.key,
    required this.customer,
    required this.currency,
  });

  @override
  State<CustomerDetailsScreen> createState() => _CustomerDetailsScreenState();
}

class _CustomerDetailsScreenState extends State<CustomerDetailsScreen> {
  List<tx_model.Transaction> _transactions = [];
  double _balance = 0;
  bool _loading = true;
  DateTime? _fromDate;
  DateTime? _toDate;
  bool _hasChanges  = false;
  int _txTypeFilter = 0; // 0=الكل، 1=مطلوب فقط، -1=مدفوع فقط

  DateTime? _parseTxDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return FormatHelper.parseDate(raw);
  }

  List<tx_model.Transaction> get _filteredTransactions {
    final from = _fromDate;
    final to = _toDate == null
        ? null
        : DateTime(
            _toDate!.year,
            _toDate!.month,
            _toDate!.day,
            23,
            59,
            59,
            999,
          );

    // Create a list of transactions with their parsed date (or null)
    final List<Map<String, dynamic>> processed = [];
    for (final tx in _transactions) {
      final parsed = _parseTxDate(tx.date);
      processed.add({'tx': tx, 'date': parsed});
    }

    // Determine if we have an active date filter
    final bool hasActiveFilter = from != null || to != null;
    final List<Map<String, dynamic>> filtered = processed.where((item) {
      if (!hasActiveFilter) {
        // No date filter: include regardless of parse success
        return true;
      } else {
        // Has date filter: we require a valid date and within range
        if (item['date'] == null) return false;
        if (from != null && item['date'].isBefore(from)) return false;
        if (to != null && item['date'].isAfter(to)) return false;
        return true;
      }
    }).toList();

    // Sort: first by date descending (null dates last), then maintain original order for equal dates
    filtered.sort((a, b) {
      final dateA = a['date'];
      final dateB = b['date'];
      // If both have dates, compare by date descending
      if (dateA != null && dateB != null) {
        return dateB.compareTo(dateA); // descending
      }
      // If only a has date, a comes first
      if (dateA != null) return -1;
      // If only b has date, b comes first
      if (dateB != null) return 1;
      // Both null: maintain original order (do nothing)
      return 0;
    });

    // فلتر النوع
    final typeFiltered = _txTypeFilter == 0
        ? filtered
        : filtered
            .where((item) =>
                (item['tx'] as tx_model.Transaction).inFlag == _txTypeFilter)
            .toList();

    return typeFiltered.map((e) => e['tx'] as tx_model.Transaction).toList();
  }

  Future<void> _pickFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      _fromDate = picked;
      if (_toDate != null && _toDate!.isBefore(picked)) {
        _toDate = picked;
      }
    });
  }

  Future<void> _pickToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate ?? _fromDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      _toDate = picked;
      if (_fromDate != null && _fromDate!.isAfter(picked)) {
        _fromDate = picked;
      }
    });
  }

  void _clearDateFilter() {
    setState(() {
      _fromDate = null;
      _toDate = null;
    });
  }

  // ─── تسوية الرصيد ────────────────────────────────────────────────────────
  Future<void> _settleBalance() async {
    if (_balance == 0) return;
    final isDebt = _balance > 0; // رصيد موجب = مطلوب = نضيف مدفوع
    final amount = _balance.abs();

    final remarksCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تسوية الرصيد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isDebt
                  ? 'سيتم تسجيل دفعة بقيمة ${_balance.abs()} ${widget.currency.displayName} لتصفير الرصيد.'
                  : 'سيتم تسجيل مبلغ مطلوب بقيمة ${_balance.abs()} ${widget.currency.displayName} لتصفير الرصيد.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: remarksCtrl,
              decoration: const InputDecoration(
                labelText: 'ملاحظة (اختياري)',
                prefixIcon: Icon(Icons.notes_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    remarksCtrl.dispose();
    if (confirmed != true || !mounted) return;

    final dbHelper = context.read<AppProvider>().dbHelper;
    final repo = TransactionRepository(dbHelper);
    await repo.insert(tx_model.Transaction(
      cusId:   widget.customer.id!,
      inFlag:  isDebt ? -1 : 1,
      out:     amount,
      date:    DateTime.now().toIso8601String().substring(0, 10),
      currId:  widget.currency.id!,
      remarks: remarksCtrl.text.trim().isEmpty ? 'تسوية رصيد' : remarksCtrl.text.trim(),
    ));
    _hasChanges = true;
    await _load();
  }

  _TransactionsSummary _calculateSummary(List<tx_model.Transaction> source) {
    double totalIn = 0;
    double totalOut = 0;
    for (final tx in source) {
      if (tx.inFlag == 1) {
        totalIn += tx.out;
      } else {
        totalOut += tx.out;
      }
    }
    final finalBalance = source.fold<double>(
      0,
      (sum, tx) => tx.inFlag == 1 ? sum + tx.out : sum - tx.out,
    );
    return _TransactionsSummary(
      totalIn: totalIn,
      totalOut: totalOut,
      finalBalance: finalBalance,
    );
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final dbHelper = context.read<AppProvider>().dbHelper;
      final repo = TransactionRepository(dbHelper);
      final txList = await repo.getByCustomerAndCurrency(
        widget.customer.id!,
        widget.currency.id!,
      );
      final balance = await repo.getBalance(
        widget.customer.id!,
        widget.currency.id!,
      );
      if (!mounted) return;
      _transactions = txList;
      _balance = balance;
    } catch (_) {
      if (!mounted) return;
      _transactions = [];
      _balance = 0;
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  // ─── حذف حركة ─────────────────────────────────────────────────────────────
  Future<void> _deleteTransaction(tx_model.Transaction tx) async {
    final dbHelper = context.read<AppProvider>().dbHelper;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل تريد حذف هذه الحركة؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء')),
          TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('حذف')),
        ],
      ),
    );
    if (confirm != true) return;
    if (!mounted) return;
    await TransactionRepository(dbHelper).delete(tx.id!);
    _hasChanges = true;
    await _load();
  }

  // ─── مشاركة كشف الحساب ────────────────────────────────────────────────────
  String _buildStatement() {
    final summary = _calculateSummary(_transactions);
    return StatementHelper.buildArabicStatement(
      customerName: widget.customer.name,
      currencyName: widget.currency.displayName,
      currentBalance: _balance,
      finalBalance: summary.finalBalance,
      transactions: _transactions,
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleTransactions = _filteredTransactions;
    final summary = _calculateSummary(visibleTransactions);
    final balanceColor = _balance == 0
        ? Colors.grey
        : _balance > 0
            ? AppTheme.income
            : AppTheme.expense;

    return PopScope<bool>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, _hasChanges);
      },
      child: Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, _hasChanges),
        ),
        title: Text(widget.customer.name),
        actions: [
           if (_balance != 0)
             IconButton(
               icon: const Icon(Icons.done_all),
               tooltip: 'تسوية الرصيد',
               onPressed: _settleBalance,
             ),
           IconButton(
             icon: const Icon(Icons.copy),
             tooltip: 'نسخ',
             color: Theme.of(context).primaryColor,
             onPressed: () {
               Clipboard.setData(ClipboardData(text: _buildStatement()));
               ScaffoldMessenger.of(context).showSnackBar(
                   const SnackBar(
                     content: Text('تم نسخ كشف الحساب'),
                     behavior: SnackBarBehavior.floating,
                   ));
             },
           ),
           IconButton(
             icon: const Icon(Icons.share),
             tooltip: 'مشاركة',
             color: Theme.of(context).primaryColor,
             onPressed: () => Share.share(_buildStatement()),
           ),
           IconButton(
             icon: const Icon(Icons.picture_as_pdf_outlined),
             tooltip: 'تصدير PDF',
             color: Theme.of(context).primaryColor,
             onPressed: () async {
               final messenger = ScaffoldMessenger.of(context);
               try {
                 await PdfService.shareStatement(
                   customer: widget.customer,
                   currency: widget.currency,
                   transactions: _transactions,
                   balance: _balance,
                 );
               } catch (_) {
                 messenger.showSnackBar(
                   const SnackBar(
                     content: Text('تعذر إنشاء ملف PDF'),
                     behavior: SnackBarBehavior.floating,
                   ),
                 );
               }
             },
           ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ─── بطاقة معلومات العميل ────────────────────────────
                _CustomerHeader(
                  customer: widget.customer,
                  currency: widget.currency,
                  balance: _balance,
                  txCount: _transactions.length,
                  balanceColor: balanceColor,
                ),
                _SummarySection(
                  summary: summary,
                  currencyName: widget.currency.displayName,
                  balanceColor: balanceColor,
                ),
                if (_fromDate != null || _toDate != null)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'ملخص مفلتر'
                        '${_fromDate != null ? ': من ${FormatHelper.formatDateFromDateTime(_fromDate!)}' : ''}'
                        '${_toDate != null ? ' — ${FormatHelper.formatDateFromDateTime(_toDate!)}' : ''}',
                        style: TextStyle(
                            fontSize: AppFontSize.caption,
                            color: Colors.grey.shade600),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.xxs),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _pickFromDate,
                          child: Text(
                            _fromDate == null
                                ? 'من تاريخ'
                                : 'من ${FormatHelper.formatDateFromDateTime(_fromDate!)}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _pickToDate,
                          child: Text(
                            _toDate == null
                                ? 'إلى تاريخ'
                                : 'إلى ${FormatHelper.formatDateFromDateTime(_toDate!)}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      if (_fromDate != null || _toDate != null)
                        IconButton(
                          tooltip: 'مسح الفلتر',
                          onPressed: _clearDateFilter,
                          icon: const Icon(Icons.clear),
                        ),
                    ],
                  ),
                ),
                // ─── فلتر نوع الحركة ─────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md, 0, AppSpacing.md, AppSpacing.xs),
                  child: Row(
                    children: [
                      _TypeChip(
                        label: 'الكل',
                        selected: _txTypeFilter == 0,
                        onTap: () => setState(() => _txTypeFilter = 0),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _TypeChip(
                        label: 'مطلوب',
                        selected: _txTypeFilter == 1,
                        color: AppTheme.income,
                        onTap: () => setState(() => _txTypeFilter = 1),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _TypeChip(
                        label: 'مدفوع',
                        selected: _txTypeFilter == -1,
                        color: AppTheme.expense,
                        onTap: () => setState(() => _txTypeFilter = -1),
                      ),
                    ],
                  ),
                ),
                // ─── عنوان قسم الحركات ──────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                  child: Row(
                    children: [
                      const Icon(Icons.receipt_long, size: AppIconSize.sm,
                          color: Colors.grey),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'الحركات (${visibleTransactions.length})',
                        style: TextStyle(
                            fontSize: AppFontSize.body,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // ─── قائمة الحركات (الأحدث أولاً) ──────────────────
                Expanded(
                  child: visibleTransactions.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.receipt_long,
                                  size: AppIconSize.empty,
                                  color: Colors.grey.shade300),
                              const SizedBox(height: AppSpacing.sm),
                              Text('لا توجد حركات',
                                  style: TextStyle(
                                      color: Colors.grey.shade500)),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: Builder(builder: (context) {
                            // حساب الرصيد الجاري (من الأقدم إلى الأحدث)
                            final reversed = visibleTransactions.reversed.toList();
                            double running = 0;
                            final runningBalances = reversed.map((tx) {
                              running += tx.inFlag == 1 ? tx.out : -tx.out;
                              return running;
                            }).toList();
                            final balancesForDisplay = runningBalances.reversed.toList();

                            return ListView.builder(
                              itemCount: visibleTransactions.length,
                              itemBuilder: (_, i) => _TransactionTile(
                                tx: visibleTransactions[i],
                                currencyName: widget.currency.displayName,
                                runningBalance: balancesForDisplay[i],
                                onEdit: () async {
                                  final changed = await Navigator.push<bool>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => AddEditTransactionScreen(
                                        customer: widget.customer,
                                        currency: widget.currency,
                                        transaction: visibleTransactions[i],
                                      ),
                                    ),
                                  );
                                  if (changed == true) {
                                    _hasChanges = true;
                                    await _load();
                                  }
                                },
                                onDelete: () =>
                                    _deleteTransaction(visibleTransactions[i]),
                              ),
                            );
                          }),
                        ),
                ),
              ],
            ),
       floatingActionButton: FloatingActionButton(
         backgroundColor: Theme.of(context).primaryColor,
         tooltip: 'إضافة حركة',
         onPressed: () async {
           final changed = await Navigator.push<bool>(
             context,
             MaterialPageRoute(
               builder: (_) => AddEditTransactionScreen(
                 customer: widget.customer,
                 currency: widget.currency,
               ),
             ),
           );
           if (changed == true) {
             _hasChanges = true;
             await _load();
           }
         },
         child: const Icon(Icons.add, size: AppIconSize.xl),
       ),
      ),
    );
  }
}

// ─── بطاقة معلومات العميل ────────────────────────────────────────────────────
class _CustomerHeader extends StatelessWidget {
  final Customer customer;
  final Currency currency;
  final double balance;
  final int txCount;
  final Color balanceColor;

  const _CustomerHeader({
    required this.customer,
    required this.currency,
    required this.balance,
    required this.txCount,
    required this.balanceColor,
  });

  @override
  Widget build(BuildContext context) {
    final groupName = safeGroupName(customer);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.lg),
       decoration: BoxDecoration(
         color: balanceColor.withValues(alpha: 0.07),
         borderRadius: AppRadius.mdAll,
         border: Border.all(color: balanceColor.withValues(alpha: 0.25)),
         boxShadow: [
           BoxShadow(
             color: Colors.black.withValues(alpha: 0.05),
             blurRadius: 4,
             offset: Offset(0, 2),
           ),
         ],
       ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── الاسم ────────────────────────────────────────────────
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: balanceColor.withValues(alpha: 0.15),
                child: Text(
                  customer.name.isNotEmpty ? customer.name[0] : '؟',
                  style: TextStyle(
                      color: balanceColor, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: AppFontSize.subtitle),
                    ),
                    if (customer.gsm != null && customer.gsm!.isNotEmpty)
                      Text(
                        customer.gsm!,
                        style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: AppFontSize.body),
                      ),
                    if (groupName != null)
                      Text(
                        'المجموعة: $groupName',
                        style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: AppFontSize.small),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.md),
          // ─── الرصيد + عدد الحركات ────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // الرصيد
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('الرصيد الحالي',
                      style: TextStyle(
                          fontSize: AppFontSize.caption,
                          color: Colors.grey.shade500)),
                  const SizedBox(height: AppSpacing.xxs),
                   Text(
                     '${FormatHelper.formatAmount(balance)} ${currency.displayName}',
                     style: TextStyle(
                         color: balanceColor,
                         fontSize: AppFontSize.display,
                         fontWeight: FontWeight.bold),
                   ),
                ],
              ),
              // عدد الحركات
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                decoration: ShapeDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  shape: const StadiumBorder(),
                ),
                child: Row(
                  children: [
                    Icon(Icons.receipt_long,
                        size: AppIconSize.sm, color: Colors.grey.shade600),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      '$txCount حركة',
                      style: TextStyle(
                          fontSize: AppFontSize.body,
                          color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── بلاط الحركة ─────────────────────────────────────────────────────────────
class _TransactionTile extends StatelessWidget {
  final tx_model.Transaction tx;
  final String currencyName;
  final double runningBalance;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TransactionTile({
    required this.tx,
    required this.currencyName,
    required this.runningBalance,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isIn = tx.inFlag == 1;
    final color = isIn ? AppTheme.income : AppTheme.expense;
    final label = BalanceHelper.transactionLabel(tx.inFlag);
    final hasRemarks = tx.remarks != null && tx.remarks!.isNotEmpty;

    return Card(
      margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.md, AppSpacing.xs, AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ─── أيقونة النوع ─────────────────────────────────────
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isIn ? Icons.arrow_downward : Icons.arrow_upward,
                color: color,
                size: AppIconSize.md,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            // ─── التفاصيل (نوع + تاريخ + ملاحظة) ────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // نوع الحركة كـ badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
                    decoration: ShapeDecoration(
                      color: color.withValues(alpha: 0.1),
                      shape: const StadiumBorder(),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        color: color,
                        fontSize: AppFontSize.caption,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                   // التاريخ
                   if (tx.date != null)
                     Text(
                       FormatHelper.formatDate(tx.date),
                       style: TextStyle(
                           fontSize: AppFontSize.body,
                           color: Colors.grey.shade500),
                     ),
                  // الملاحظة
                  if (hasRemarks) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                       tx.remarks!,
                       style: TextStyle(
                           fontSize: AppFontSize.small,
                           color: Colors.grey.shade600),
                       maxLines: 1,
                       overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            // ─── المبلغ + أزرار ───────────────────────────────────
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                 // المبلغ — واضح وكبير
                 Text(
                   FormatHelper.formatAmount(tx.out),
                   style: TextStyle(
                     color: color,
                     fontSize: AppFontSize.title,
                     fontWeight: FontWeight.bold,
                     letterSpacing: 0.3,
                   ),
                 ),
                Text(
                  currencyName,
                  style: TextStyle(
                      fontSize: AppFontSize.micro, color: Colors.grey.shade400),
                ),
                const SizedBox(height: AppSpacing.xxs),
                // الرصيد الجاري
                Text(
                  'رصيد: ${FormatHelper.formatAmount(runningBalance)}',
                  style: TextStyle(
                      fontSize: AppFontSize.micro,
                      color: runningBalance == 0
                          ? Colors.grey
                          : runningBalance > 0
                              ? AppTheme.income
                              : AppTheme.expense),
                ),
                const SizedBox(height: AppSpacing.xxs),
                // أزرار تعديل وحذف
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: Icon(Icons.edit_outlined,
                            size: AppIconSize.sm, color: Colors.grey.shade500),
                        onPressed: onEdit,
                        tooltip: 'تعديل',
                      ),
                    ),
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.delete_outline,
                            size: AppIconSize.sm, color: Colors.red),
                        onPressed: onDelete,
                        tooltip: 'حذف',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── شريحة فلتر النوع ────────────────────────────────────────────────────────
class _TypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;

  const _TypeChip({
    required this.label,
    required this.selected,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.xs),
        decoration: ShapeDecoration(
          color: selected ? c.withValues(alpha: 0.15) : Colors.transparent,
          shape: StadiumBorder(
              side: BorderSide(color: selected ? c : Colors.grey.shade300)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: AppFontSize.small,
            color: selected ? c : Colors.grey.shade600,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _TransactionsSummary {
  final double totalIn;
  final double totalOut;
  final double finalBalance;

  const _TransactionsSummary({
    required this.totalIn,
    required this.totalOut,
    required this.finalBalance,
  });
}

class _SummarySection extends StatelessWidget {
  final _TransactionsSummary summary;
  final String currencyName;
  final Color balanceColor;

  const _SummarySection({
    required this.summary,
    required this.currencyName,
    required this.balanceColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: AppRadius.mdAll,
        color: Colors.grey.withValues(alpha: 0.06),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SummaryValue(
              title: 'إجمالي مطلوب',
              value: FormatHelper.formatAmount(summary.totalIn),
              color: AppTheme.income,
            ),
          ),
          Expanded(
            child: _SummaryValue(
              title: 'إجمالي مدفوع',
              value: FormatHelper.formatAmount(summary.totalOut),
              color: AppTheme.expense,
            ),
          ),
          Expanded(
            child: _SummaryValue(
              title: 'الرصيد النهائي',
              value:
                  '${FormatHelper.formatAmount(summary.finalBalance)} $currencyName',
              color: balanceColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _SummaryValue({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
              fontSize: AppFontSize.caption, color: Colors.grey.shade600),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: AppFontSize.body,
          ),
        ),
      ],
    );
  }
}
