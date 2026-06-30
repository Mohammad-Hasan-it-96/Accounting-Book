import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/activation_service.dart';
import '../../data/models/currency.dart';
import '../../data/models/customer.dart';
import '../../data/repositories/customer_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../providers/app_provider.dart';
import '../../core/helpers/format_helper.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/widgets/app_dialog.dart';
import '../activation/activation_screen.dart';
import '../customer_details/customer_details_screen.dart';
import '../add_edit_customer/add_edit_customer_screen.dart';

class CurrencyAccountsScreen extends StatefulWidget {
  final Currency currency;

  /// عند فتح الشاشة من اختصار "إضافة عميل" في الرئيسية: يبدأ تدفّق الإضافة فوراً.
  final bool openAddOnStart;

  const CurrencyAccountsScreen({
    super.key,
    required this.currency,
    this.openAddOnStart = false,
  });

  @override
  State<CurrencyAccountsScreen> createState() =>
      _CurrencyAccountsScreenState();
}

class _CurrencyAccountsScreenState extends State<CurrencyAccountsScreen> {
  final _searchCtrl = TextEditingController();
  String _sortBy = 'name'; // name | balance | last_tx

  List<_CustomerWithBalance> _items = [];
  bool _loading      = true;
  bool _isActivated  = true;
  bool _showArchived = false; // إظهار العملاء المؤرشفين

  @override
  void initState() {
    super.initState();
    _load().then((_) {
      if (widget.openAddOnStart && mounted) _addCustomer();
    });
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

      final results = await Future.wait([
        txRepo.getCustomerSummaries(widget.currency.id!),
        cusRepo.getAll(),
        ActivationService().isActivated(),
      ]);

      final summaries  = results[0] as Map<int?, dynamic>;
      final customers  = results[1] as List<Customer>;
      final activated  = results[2] as bool;

      _isActivated = activated;
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

  // ─── إضافة عميل ──────────────────────────────────────────────────────────
  // يعيد استخدام فحص الحد المجاني ثم يفتح شاشة الإضافة، ويعرض تفاصيل العميل
  // الجديد عند إنشائه. مُستدعى من زر الإضافة العائم ومن اختصار الرئيسية.
  Future<void> _addCustomer() async {
    final canAdd = await _checkCanAddCustomer();
    if (!mounted) return;
    if (!canAdd) return;

    final result = await Navigator.push<Object?>(
      context,
      MaterialPageRoute(builder: (_) => const AddEditCustomerScreen()),
    );
    if (!mounted) return;
    if (result is Customer) {
      await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => CustomerDetailsScreen(
            customer: result,
            currency: widget.currency,
          ),
        ),
      );
      if (!mounted) return;
      await _load();
      return;
    }
    if (result == true) {
      await _load();
    }
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

    final confirm = await AppDialog.confirm(
      context,
      title: 'حذف العميل',
      message:
          'هل تريد حذف العميل "${customer.name}" نهائياً؟ لا يمكن التراجع عن هذا الإجراء.',
      confirmLabel: 'حذف',
      destructive: true,
    );

    if (!confirm) return;

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

  // ─── فحص الحد المجاني ────────────────────────────────────────────────────
  /// يُرجع true إذا مُسموح بالإضافة، false إذا وصل الحد وعُرض الـ Dialog.
  Future<bool> _checkCanAddCustomer() async {
    if (_isActivated) return true;

    if (!mounted) return false;
    final total = _items.length;

    if (total < AppConstants.trialCustomerLimit) return true;

    final activate = await AppDialog.confirm(
      context,
      title: 'وصلت إلى الحد المجاني',
      message:
          'وصلت للحد المجاني (${AppConstants.trialCustomerLimit} حساب).\nيرجى تفعيل التطبيق للمتابعة.',
      confirmLabel: 'تفعيل الآن',
      cancelLabel: 'لاحقاً',
      icon: Icons.lock_outline,
    );
    if (activate && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ActivationScreen()),
      );
    }
    return false;
  }

  // ─── تصدير تقرير جميع العملاء ───────────────────────────────────────────
  Future<void> _exportAllReport() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يوجد عملاء للتصدير'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final sorted = List<_CustomerWithBalance>.from(_items)
      ..sort((a, b) => b.balance.compareTo(a.balance));

    final now = DateTime.now();
    final dateStr =
        '${now.day}/${now.month}/${now.year}  ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final buf = StringBuffer();
    buf.writeln('═══════════════════════════════════');
    buf.writeln('   كشف أرصدة العملاء');
    buf.writeln('   ${widget.currency.displayName}');
    buf.writeln('   $dateStr');
    buf.writeln('═══════════════════════════════════\n');

    double totalDebt = 0;
    double totalCredit = 0;
    for (final item in sorted) {
      final b = item.balance;
      if (b > 0) totalDebt += b;
      if (b < 0) totalCredit += b.abs();
    }

    buf.writeln('إجمالي المطلوب : ${FormatHelper.formatAmount(totalDebt)} ${widget.currency.displayName}');
    buf.writeln('إجمالي المدفوع : ${FormatHelper.formatAmount(totalCredit)} ${widget.currency.displayName}');
    buf.writeln('عدد العملاء   : ${_items.length}');
    buf.writeln('───────────────────────────────────\n');

    for (int i = 0; i < sorted.length; i++) {
      final item = sorted[i];
      final b = item.balance;
      final label = b > 0 ? 'مطلوب' : b < 0 ? 'مدفوع' : 'مسوّى';
      buf.writeln('${i + 1}. ${item.customer.name}');
      if (item.customer.gsm?.isNotEmpty == true) {
        buf.writeln('   📞 ${item.customer.gsm}');
      }
      buf.writeln('   ${FormatHelper.formatAmount(b.abs())} ${widget.currency.displayName} — $label');
      buf.writeln();
    }

    buf.writeln('═══════════════════════════════════');
    buf.writeln('دفتر الحسابات');

    await Share.share(buf.toString(), subject: 'كشف أرصدة العملاء — ${widget.currency.displayName}');
  }

  /// بحث فوري + ترتيب + فلتر الأرشيف
  List<_CustomerWithBalance> get _displayed {
    final q = _searchCtrl.text.toLowerCase();
    var list = _items.where((i) {
      // فلتر الأرشيف: إخفاء المؤرشفين إلا إذا طلب المستخدم إظهارهم
      if (!_showArchived && i.customer.isArchived) return false;
      if (q.isEmpty) return true;
      return i.customer.name.toLowerCase().contains(q) ||
          (i.customer.gsm?.toLowerCase().contains(q) ?? false);
    }).toList();

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
          // ─── تصدير تقرير العملاء ───────────────────────────────
          if (!_loading)
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: 'تصدير كشف العملاء',
              onPressed: _exportAllReport,
            ),
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
                      size: AppIconSize.md,
                      color: _sortBy == 'name'
                          ? Theme.of(context).colorScheme.primary
                          : null),
                  const SizedBox(width: AppSpacing.sm),
                  const Text('ترتيب بالاسم'),
                ]),
              ),
              PopupMenuItem(
                value: 'balance',
                child: Row(children: [
                  Icon(Icons.attach_money,
                      size: AppIconSize.md,
                      color: _sortBy == 'balance'
                          ? Theme.of(context).colorScheme.primary
                          : null),
                  const SizedBox(width: AppSpacing.sm),
                  const Text('ترتيب بالرصيد'),
                ]),
              ),
              PopupMenuItem(
                value: 'last_tx',
                child: Row(children: [
                  Icon(Icons.schedule,
                      size: AppIconSize.md,
                      color: _sortBy == 'last_tx'
                          ? Theme.of(context).colorScheme.primary
                          : null),
                  const SizedBox(width: AppSpacing.sm),
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

          // ─── تحذير الاقتراب من الحد المجاني ────────────────────
          if (!_loading && !_isActivated &&
              _items.length >= AppConstants.trialWarningThreshold &&
              _items.length < AppConstants.trialCustomerLimit)
            Container(
              color: Colors.orange.shade50,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.orange.shade800, size: AppIconSize.md),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'اقتربت من الحد المجاني: ${_items.length} / ${AppConstants.trialCustomerLimit} عميل',
                      style: TextStyle(
                          fontSize: AppFontSize.small, color: Colors.orange.shade900),
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                        foregroundColor: Colors.orange.shade900,
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm)),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ActivationScreen()),
                    ),
                    child: const Text('تفعيل', style: TextStyle(fontSize: AppFontSize.small)),
                  ),
                ],
              ),
            ),

          // ─── بحث فوري ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'بحث بالاسم أو الهاتف...',
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

          // ─── فلتر الأرشيف + عداد النتائج ───────────────────────
          if (!_loading)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, 0, AppSpacing.md, AppSpacing.xs),
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('المؤرشفون',
                        style: TextStyle(fontSize: AppFontSize.small)),
                    selected: _showArchived,
                    avatar: Icon(
                      Icons.archive_outlined,
                      size: AppIconSize.sm,
                      color: _showArchived
                          ? Theme.of(context).colorScheme.onPrimary
                          : Colors.grey.shade600,
                    ),
                    onSelected: (v) => setState(() => _showArchived = v),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                  ),
                  const Spacer(),
                  if (_searchCtrl.text.isNotEmpty || _showArchived)
                    Text(
                      '${displayed.length} نتيجة',
                      style: TextStyle(fontSize: AppFontSize.small, color: Colors.grey.shade500),
                    ),
                ],
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
                                size: AppIconSize.empty,
                                color: Colors.grey.shade300),
                            const SizedBox(height: AppSpacing.sm),
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
                              onShare: () {
                                final b = item.balance;
                                final label = b > 0
                                    ? 'مطلوب'
                                    : b < 0
                                        ? 'مدفوع'
                                        : 'مسوّى';
                                Share.share(
                                  'حساب: ${item.customer.name}\n'
                                  'الرصيد: ${FormatHelper.formatAmount(b.abs())} ${widget.currency.displayName}\n'
                                  'الحالة: $label',
                                  subject: 'رصيد ${item.customer.name}',
                                );
                              },
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'إضافة عميل',
        onPressed: _addCustomer,
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
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
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
              color: AppColors.income),
          _StatItem(
              label: 'مدين',
              value: FormatHelper.formatAmount(totalDebit),
              icon: Icons.arrow_upward,
              color: AppColors.expense),
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
        Icon(icon, size: AppIconSize.sm, color: c),
        const SizedBox(height: AppSpacing.xxs),
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: AppFontSize.body, color: c)),
        Text(label,
            style: TextStyle(fontSize: AppFontSize.micro, color: Colors.grey.shade600)),
      ],
    );
  }
}

// ─── بلاط العميل ─────────────────────────────────────────────────────────────
class _CustomerTile extends StatelessWidget {
  final _CustomerWithBalance item;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onShare;

  const _CustomerTile({
    required this.item,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final balance = item.balance;
    final isZero  = balance == 0;

    final avatarBg = isZero
        ? Colors.grey.shade400
        : balance > 0
            ? AppColors.income
            : AppColors.expense;

    final balanceColor = isZero
        ? Colors.grey.shade500
        : balance > 0
            ? AppColors.incomeDark
            : AppColors.expenseDark;

    final statusLabel = isZero
        ? 'مسوّى'
        : balance > 0
            ? 'مطلوب'
            : 'مدفوع';

    // ─── معلومات ثانوية: الهاتف + عدد الحركات (+ ملاحظة عند وجودها) ─────────
    final phone = item.customer.gsm?.trim() ?? '';
    final hasPhone = phone.isNotEmpty;
    final txCountLabel =
        item.txCount > 0 ? '${item.txCount} حركة' : 'لا حركات';
    final notes = item.customer.notes?.trim() ?? '';
    final hasNotes = notes.isNotEmpty;

    return Card(
      margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.mdAll,
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        // ─── الأفاتار (مع مؤشّر الأرشفة) ──────────────────────────
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: avatarBg.withValues(alpha: 0.14),
              child: Text(
                item.customer.name.isNotEmpty ? item.customer.name[0] : '؟',
                style: TextStyle(
                  color: avatarBg,
                  fontWeight: FontWeight.bold,
                  fontSize: AppFontSize.title,
                ),
              ),
            ),
            if (item.customer.isArchived)
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.xxs),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade600,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: const Icon(Icons.archive, size: 10, color: Colors.white),
                ),
              ),
          ],
        ),
        // ─── الاسم: تأكيد أقوى ─────────────────────────────────────
        title: Text(
          item.customer.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: AppFontSize.subtitle,
          ),
        ),
        // ─── ثانوي: الهاتف + عدد الحركات ──────────────────────────
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.xxs),
            Row(
              children: [
                if (hasPhone) ...[
                  Icon(Icons.phone_outlined,
                      size: AppIconSize.sm, color: Colors.grey.shade400),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: Text(
                      phone,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: AppFontSize.small,
                          color: Colors.grey.shade600),
                    ),
                  ),
                  Text(
                    '  ·  ',
                    style: TextStyle(
                        fontSize: AppFontSize.small,
                        color: Colors.grey.shade400),
                  ),
                ],
                Text(
                  txCountLabel,
                  style: TextStyle(
                      fontSize: AppFontSize.small, color: Colors.grey.shade500),
                ),
              ],
            ),
            if (hasNotes) ...[
              const SizedBox(height: AppSpacing.xxs),
              Text(
                notes,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: AppFontSize.caption,
                    color: Colors.grey.shade400,
                    fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
        // ─── الرصيد المميَّز + قائمة الخيارات ──────────────────────
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
                  decoration: ShapeDecoration(
                    color: balanceColor.withValues(alpha: 0.12),
                    shape: const StadiumBorder(),
                  ),
                  child: Text(
                    FormatHelper.formatAmount(balance),
                    style: TextStyle(
                      color: balanceColor,
                      fontWeight: FontWeight.bold,
                      fontSize: AppFontSize.subtitle,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  statusLabel,
                  style: TextStyle(
                    color: balanceColor,
                    fontSize: AppFontSize.micro,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(width: AppSpacing.xxs),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert,
                  size: AppIconSize.md, color: Colors.grey.shade400),
              tooltip: 'خيارات',
              onSelected: (v) {
                if (v == 'edit') onEdit();
                if (v == 'delete') onDelete();
                if (v == 'share') onShare();
              },
              itemBuilder: (_) => [
                const PopupMenuItem<String>(
                  value: 'edit',
                  child: Row(children: [
                    Icon(Icons.edit_outlined, size: AppIconSize.md),
                    SizedBox(width: AppSpacing.sm),
                    Text('تعديل'),
                  ]),
                ),
                const PopupMenuItem<String>(
                  value: 'share',
                  child: Row(children: [
                    Icon(Icons.share_outlined, size: AppIconSize.md),
                    SizedBox(width: AppSpacing.sm),
                    Text('مشاركة الرصيد'),
                  ]),
                ),
                const PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(children: [
                    Icon(Icons.delete_outline, size: AppIconSize.md, color: Colors.red),
                    SizedBox(width: AppSpacing.sm),
                    Text('حذف', style: TextStyle(color: Colors.red)),
                  ]),
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
