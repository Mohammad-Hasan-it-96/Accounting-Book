import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/currency.dart';
import '../../data/models/customer.dart';
import '../../data/repositories/customer_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../providers/app_provider.dart';
import '../../core/helpers/customer_helper.dart';
import '../../core/helpers/format_helper.dart';
import '../customer_details/customer_details_screen.dart';
import '../add_edit_customer/add_edit_customer_screen.dart';

class CurrencyAccountsScreen extends StatefulWidget {
  final Currency currency;
  const CurrencyAccountsScreen({super.key, required this.currency});

  @override
  State<CurrencyAccountsScreen> createState() =>
      _CurrencyAccountsScreenState();
}

class _CurrencyAccountsScreenState extends State<CurrencyAccountsScreen> {
  final _searchCtrl = TextEditingController();
  String _sortBy = 'name'; // name | balance | last_tx

  List<_CustomerWithBalance> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final dbHelper = context.read<AppProvider>().dbHelper;
      final cusRepo = CustomerRepository(dbHelper);
      final txRepo = TransactionRepository(dbHelper);

      final summaries = await txRepo.getCustomerSummaries(widget.currency.id!);
      final customers = await cusRepo.getAll();

      _items = customers.map((c) {
        final s = summaries[c.id];
        return _CustomerWithBalance(
          customer: c,
          balance: s?.balance ?? 0.0,
          txCount: s?.txCount ?? 0,
          lastTxDate: s?.lastTxDate,
        );
      }).toList();
    } catch (_) {
      _items = [];
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _editCustomer(Customer customer) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddEditCustomerScreen(customer: customer),
      ),
    );
    if (changed == true && mounted) await _load();
  }

  Future<void> _deleteCustomer(Customer customer) async {
    final id = customer.id;
    if (id == null) return;
    final dbHelper = context.read<AppProvider>().dbHelper;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل تريد حذف العميل "${customer.name}" نهائيًا؟'),
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

    try {
      final repo = CustomerRepository(dbHelper);
      await repo.delete(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حذف العميل')),
      );
      await _load();
    } on StateError catch (e) {
      if (!mounted) return;
      final hasTx = e.message == 'customer_has_transactions';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            hasTx
                ? 'لا يمكن حذف العميل لأنه يملك حركات. احذف الحركات أولاً.'
                : 'تعذر حذف العميل',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر حذف العميل')),
      );
    }
  }

  /// بحث فوري + ترتيب فقط — بدون فلاتر إضافية
  List<_CustomerWithBalance> get _displayed {
    var list = _searchCtrl.text.isEmpty
        ? List<_CustomerWithBalance>.from(_items)
        : _items
            .where((i) => i.customer.name
                .toLowerCase()
                .contains(_searchCtrl.text.toLowerCase()))
            .toList();

    if (_sortBy == 'name') {
      list.sort((a, b) => a.customer.name.compareTo(b.customer.name));
    } else if (_sortBy == 'balance') {
      // ترتيب حسب الرصيد تنازلياً (الأكبر أولاً)
      list.sort((a, b) => b.balance.abs().compareTo(a.balance.abs()));
    } else {
      // الأحدث أولاً، والعملاء بلا حركات في النهاية
      list.sort((a, b) {
        final ad = a.lastTxDate;
        final bd = b.lastTxDate;
        if (ad == null && bd == null) return 0;
        if (ad == null) return 1;
        if (bd == null) return -1;
        return bd.compareTo(ad);
      });
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final displayed = _displayed;

    return Scaffold(
      appBar: AppBar(
        title: Text('دفتر ${widget.currency.displayName}'),
        actions: [
          // ─── زر الترتيب ────────────────────────────────────────
          PopupMenuButton<String>(
            icon: Icon(
              _sortBy == 'name'
                  ? Icons.sort_by_alpha
                  : _sortBy == 'balance'
                      ? Icons.attach_money
                      : Icons.schedule,
            ),
            tooltip: 'ترتيب',
            onSelected: (v) => setState(() => _sortBy = v),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'name',
                child: Row(children: [
                  Icon(Icons.sort_by_alpha,
                      size: 18,
                      color: _sortBy == 'name'
                          ? Theme.of(context).colorScheme.primary
                          : null),
                  const SizedBox(width: 8),
                  const Text('ترتيب بالاسم'),
                ]),
              ),
              PopupMenuItem(
                value: 'balance',
                child: Row(children: [
                  Icon(Icons.attach_money,
                      size: 18,
                      color: _sortBy == 'balance'
                          ? Theme.of(context).colorScheme.primary
                          : null),
                  const SizedBox(width: 8),
                  const Text('ترتيب بالرصيد'),
                ]),
              ),
              PopupMenuItem(
                value: 'last_tx',
                child: Row(children: [
                  Icon(Icons.schedule,
                      size: 18,
                      color: _sortBy == 'last_tx'
                          ? Theme.of(context).colorScheme.primary
                          : null),
                  const SizedBox(width: 8),
                  const Text('ترتيب بآخر حركة'),
                ]),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // ─── ملخص سريع ──────────────────────────────────────────
          if (!_loading)
            _SummaryBar(
              items: _items,
              currencyName: widget.currency.displayName,
            ),

          // ─── بحث فوري ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'بحث بالاسم...',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {});
                        })
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),

          // ─── عداد النتائج ────────────────────────────────────────
          if (!_loading && _searchCtrl.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16, bottom: 4),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${displayed.length} نتيجة',
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade500),
                ),
              ),
            ),

          // ─── القائمة ─────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : displayed.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.people_outline,
                                size: 48, color: Colors.grey.shade300),
                            const SizedBox(height: 8),
                            Text(
                              _searchCtrl.text.isNotEmpty
                                  ? 'لا نتائج لـ "${_searchCtrl.text}"'
                                  : 'لا يوجد عملاء',
                              style:
                                  TextStyle(color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          itemCount: displayed.length,
                          itemBuilder: (_, i) {
                            final item = displayed[i];
                            return _CustomerTile(
                              item: item,
                              currencyName: widget.currency.displayName,
                              onTap: () async {
                                final changed = await Navigator.push<bool>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CustomerDetailsScreen(
                                      customer: item.customer,
                                      currency: widget.currency,
                                    ),
                                  ),
                                );
                                if (changed == true && mounted) {
                                  await _load();
                                }
                              },
                              onEdit: () => _editCustomer(item.customer),
                              onDelete: () => _deleteCustomer(item.customer),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'إضافة عميل',
        onPressed: () async {
          final result = await Navigator.push<Object?>(
            context,
            MaterialPageRoute(
                builder: (_) => const AddEditCustomerScreen()),
          );
          if (!mounted) return;
          if (result is Customer) {
            if (!context.mounted) return;
            await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) => CustomerDetailsScreen(
                  customer: result,
                  currency: widget.currency,
                ),
              ),
            );
            if (!context.mounted) return;
            await _load();
            return;
          }
          if (result == true) {
            await _load();
          }
        },
        child: const Icon(Icons.person_add),
      ),
    );
  }
}

// ─── شريط الملخص ─────────────────────────────────────────────────────────────
class _SummaryBar extends StatelessWidget {
  final List<_CustomerWithBalance> items;
  final String currencyName;

  const _SummaryBar({required this.items, required this.currencyName});

  @override
  Widget build(BuildContext context) {
    final withBalance = items.where((i) => i.balance != 0).length;
    final totalCredit =
        items.fold(0.0, (s, i) => i.balance > 0 ? s + i.balance : s);
    final totalDebit =
        items.fold(0.0, (s, i) => i.balance < 0 ? s + i.balance.abs() : s);

    return Container(
      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(label: 'العملاء', value: '${items.length}', icon: Icons.people),
          _StatItem(
              label: 'لديهم رصيد',
              value: '$withBalance',
              icon: Icons.account_balance_wallet),
          _StatItem(
              label: 'دائن',
              value: FormatHelper.formatAmount(totalCredit),
              icon: Icons.arrow_downward,
              color: const Color(0xFF2E7D32)),
          _StatItem(
              label: 'مدين',
              value: FormatHelper.formatAmount(totalDebit),
              icon: Icons.arrow_upward,
              color: const Color(0xFFC62828)),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  const _StatItem(
      {required this.label,
      required this.value,
      required this.icon,
      this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: c),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 13, color: c)),
        Text(label,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
      ],
    );
  }
}

// ─── بلاط العميل ─────────────────────────────────────────────────────────────
class _CustomerTile extends StatelessWidget {
  final _CustomerWithBalance item;
  final String currencyName;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CustomerTile({
    required this.item,
    required this.currencyName,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final groupName = safeGroupName(item.customer);
    final balance = item.balance;
    final isZero = balance == 0;
    final color = isZero
        ? Colors.grey
        : balance > 0
            ? const Color(0xFF2E7D32)
            : const Color(0xFFC62828);

    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Text(
            item.customer.name.isNotEmpty ? item.customer.name[0] : '؟',
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(item.customer.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.customer.gsm != null && item.customer.gsm!.isNotEmpty)
              Text(
                item.customer.gsm!,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            if (groupName != null)
              Text(
                'المجموعة: $groupName',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            if (item.txCount > 0)
              Text(
                '${item.txCount} حركة',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  FormatHelper.formatAmount(balance),
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.bold, fontSize: 15),
                ),
                Text(currencyName,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
              ],
            ),
            PopupMenuButton<String>(
              tooltip: 'خيارات العميل',
              onSelected: (value) {
                if (value == 'edit') {
                  onEdit();
                } else if (value == 'delete') {
                  onDelete();
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem<String>(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('تعديل العميل'),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 18, color: Colors.red),
                      SizedBox(width: 8),
                      Text('حذف العميل'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomerWithBalance {
  final Customer customer;
  final double balance;
  final int txCount;
  final DateTime? lastTxDate;

  _CustomerWithBalance({
    required this.customer,
    required this.balance,
    required this.txCount,
    this.lastTxDate,
  });
}
