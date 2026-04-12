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
  bool _hasChanges = false;

  DateTime? _parseTxDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  List<tx_model.Transaction> get _filteredTransactions {
    if (_fromDate == null && _toDate == null) return _transactions;

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

    return _transactions.where((tx) {
      final date = _parseTxDate(tx.date);
      if (date == null) return false;
      if (from != null && date.isBefore(from)) return false;
      if (to != null && date.isAfter(to)) return false;
      return true;
    }).toList();
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
            ? const Color(0xFF2E7D32)
            : const Color(0xFFC62828);

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
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'نسخ كشف الحساب',
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
            tooltip: 'مشاركة الكشف',
            onPressed: () => Share.share(_buildStatement()),
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
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'الملخص محسوب حسب الفلتر الزمني الحالي.',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 2),
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
                      const SizedBox(width: 8),
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
                // ─── عنوان قسم الحركات ──────────────────────────────
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.receipt_long, size: 16,
                          color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(
                        'الحركات (${visibleTransactions.length})',
                        style: TextStyle(
                            fontSize: 13,
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
                                  size: 48, color: Colors.grey.shade300),
                              const SizedBox(height: 8),
                              Text('لا توجد حركات',
                                  style: TextStyle(
                                      color: Colors.grey.shade500)),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            itemCount: visibleTransactions.length,
                            itemBuilder: (_, i) => _TransactionTile(
                              tx: visibleTransactions[i],
                              currencyName: widget.currency.displayName,
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
                          ),
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
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
        child: const Icon(Icons.add),
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
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: balanceColor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: balanceColor.withValues(alpha: 0.25)),
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
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    if (customer.gsm != null && customer.gsm!.isNotEmpty)
                      Text(
                        customer.gsm!,
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 13),
                      ),
                    if (groupName != null)
                      Text(
                        'المجموعة: $groupName',
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 12),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
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
                          fontSize: 11, color: Colors.grey.shade500)),
                  const SizedBox(height: 2),
                  Text(
                    '${FormatHelper.formatAmount(balance)} ${currency.displayName}',
                    style: TextStyle(
                        color: balanceColor,
                        fontSize: 22,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              // عدد الحركات
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(Icons.receipt_long,
                        size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      '$txCount حركة',
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey.shade700),
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
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TransactionTile({
    required this.tx,
    required this.currencyName,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isIn = tx.inFlag == 1;
    final color = isIn ? const Color(0xFF2E7D32) : const Color(0xFFC62828);
    final label = BalanceHelper.transactionLabel(tx.inFlag);
    final hasRemarks = tx.remarks != null && tx.remarks!.isNotEmpty;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ─── أيقونة النوع ─────────────────────────────────────
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isIn ? Icons.arrow_downward : Icons.arrow_upward,
                color: color,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            // ─── التفاصيل (نوع + تاريخ + ملاحظة) ────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // نوع الحركة كـ badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  // التاريخ
                  if (tx.date != null)
                    Text(
                      FormatHelper.formatDate(tx.date),
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade500),
                    ),
                  // الملاحظة
                  if (hasRemarks) ...[
                    const SizedBox(height: 2),
                    Text(
                      tx.remarks!,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            // ─── المبلغ + أزرار ───────────────────────────────────
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // المبلغ — واضح وكبير
                Text(
                  FormatHelper.formatAmount(tx.out),
                  style: TextStyle(
                    color: color,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
                Text(
                  currencyName,
                  style: TextStyle(
                      fontSize: 10, color: Colors.grey.shade400),
                ),
                const SizedBox(height: 4),
                // أزرار تعديل وحذف
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 30,
                      height: 30,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: Icon(Icons.edit_outlined,
                            size: 16, color: Colors.grey.shade500),
                        onPressed: onEdit,
                        tooltip: 'تعديل',
                      ),
                    ),
                    SizedBox(
                      width: 30,
                      height: 30,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.delete_outline,
                            size: 16, color: Colors.red),
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
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.grey.withValues(alpha: 0.06),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SummaryValue(
              title: 'إجمالي له',
              value: FormatHelper.formatAmount(summary.totalIn),
              color: const Color(0xFF2E7D32),
            ),
          ),
          Expanded(
            child: _SummaryValue(
              title: 'إجمالي عليه',
              value: FormatHelper.formatAmount(summary.totalOut),
              color: const Color(0xFFC62828),
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
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
