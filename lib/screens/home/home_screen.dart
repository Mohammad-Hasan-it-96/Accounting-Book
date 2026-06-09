import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers/app_provider.dart';
import '../../core/helpers/format_helper.dart';
import '../../core/services/activation_service.dart';
import '../../core/services/update_service.dart';
import '../../core/widgets/update_dialog.dart';
import '../../data/repositories/customer_repository.dart';
import '../../data/models/customer.dart';
import '../currency_accounts/currency_accounts_screen.dart';
import '../customer_details/customer_details_screen.dart';
import '../settings/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchCtrl = TextEditingController();

  // ─── حالة التفعيل ─────────────────────────────────────────────────────────
  bool _isActivated = false;
  int  _customerCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().loadCurrencies();
      _checkForUpdate();
      _loadActivationStatus();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ─── تحميل حالة التفعيل ───────────────────────────────────────────────────
  Future<void> _loadActivationStatus() async {
    final activated = await ActivationService().isActivated();
    if (!mounted) return;
    if (activated) {
      setState(() { _isActivated = true; _customerCount = 0; });
      return;
    }
    final dbHelper = context.read<AppProvider>().dbHelper;
    final count = await CustomerRepository(dbHelper).count();
    if (!mounted) return;
    setState(() { _isActivated = false; _customerCount = count; });
  }

  // ─── فحص التحديث عند بدء الشاشة ─────────────────────────────────────────
  Future<void> _checkForUpdate() async {
    final result = await UpdateService().checkForUpdate();
    if (!mounted) return;
    if (result.hasUpdate && result.info != null) {
      await UpdateDialog.show(context, result.info!);
    }
  }

  // ─── استيراد نسخة احتياطية ───────────────────────────────────────────────
  Future<void> _importBackup() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (result == null || result.files.single.path == null) return;
    final path = result.files.single.path!;
    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تأكيد الاستيراد'),
        content: const Text(
          'سيتم استبدال قاعدة البيانات الحالية بالملف المختار.\n'
          'سيتم أخذ نسخة احتياطية تلقائية قبل الاستيراد.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('استيراد')),
        ],
      ),
    );
    if (confirm != true) return;
    if (!mounted) return;

    final provider = context.read<AppProvider>();
    await provider.dbHelper.autoBackup();

    final ok = await provider.dbHelper.importDatabase(path);
    if (!mounted) return;
    if (!ok) {
      _showSnack('تعذر استيراد النسخة الاحتياطية', isError: true);
      return;
    }
    final valid = await provider.dbHelper.validateTables();
    if (!mounted) return;
    if (!valid) {
      _showSnack('الملف غير متوافق: الجداول أو الأعمدة الأساسية ناقصة', isError: true);
      return;
    }
    await provider.reload();
    if (!mounted) return;
    _showSnack('تم استيراد النسخة الاحتياطية بنجاح');
    _loadActivationStatus();
  }

  // ─── تصدير نسخة احتياطية ─────────────────────────────────────────────────
  Future<void> _exportBackup() async {
    final provider = context.read<AppProvider>();
    final fileName = FormatHelper.backupFileName();
    final path = await provider.dbHelper.exportDatabase(fileName);
    if (!mounted) return;
    if (path == null) {
      _showSnack('تعذر تصدير النسخة الاحتياطية', isError: true);
      return;
    }
    await Share.shareXFiles(
      [XFile(path)],
      text: 'نسخة احتياطية - دفتر حسابات',
    );
    if (!mounted) return;
    _showSnack('تم تصدير النسخة الاحتياطية بنجاح');
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
    ));
  }

  // ─── فتح دفتر عملة ───────────────────────────────────────────────────────
  void _openCurrencyBook(String displayName) {
    final provider = context.read<AppProvider>();
    if (provider.loading) {
      _showSnack('جارٍ تحميل البيانات...');
      return;
    }
    final currency =
        displayName == 'ليرة' ? provider.liraCurrency : provider.dollarCurrency;
    if (currency == null) {
      _showSnack(
        'عملة "$displayName" غير موجودة.\nاستورد قاعدة بيانات أو أعد تشغيل التطبيق.',
        isError: true,
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CurrencyAccountsScreen(currency: currency),
      ),
    ).then((_) => _loadActivationStatus());
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final provider  = context.watch<AppProvider>();
    final isLoading = provider.loading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('دفتر حسابات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'الإعدادات',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ).then((_) => _loadActivationStatus()),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        children: [
          // ── شريط حالة التفعيل ─────────────────────────────────────
          _ActivationBanner(
            isActivated: _isActivated,
            customerCount: _customerCount,
          ),
          const SizedBox(height: 10),

          // ── بحث سريع ────────────────────────────────────────────
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'بحث سريع عن عميل...',
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

          // ── نتائج البحث ──────────────────────────────────────────
          if (_searchCtrl.text.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: _QuickSearchResults(
                    query: _searchCtrl.text.trim(),
                    provider: provider,
                    compact: true,
                  ),
                ),
              ),
            ),
            if (provider.liraCurrency != null && provider.dollarCurrency != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'عند فتح عميل من البحث سيتم سؤالك عن الدفتر.',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ),
          ],

          const SizedBox(height: 16),

          // ── زرا الدفاتر الرئيسيان ────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _BookButton(
                  label: 'دفتر الليرة',
                  icon: Icons.account_balance_wallet_outlined,
                  color: const Color(0xFF1565C0),
                  onTap: isLoading ? null : () => _openCurrencyBook('ليرة'),
                  loading: isLoading,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _BookButton(
                  label: 'دفتر الدولار',
                  icon: Icons.attach_money,
                  color: const Color(0xFF2E7D32),
                  onTap: isLoading ? null : () => _openCurrencyBook('دولار'),
                  loading: isLoading,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ── بطاقة النسخ الاحتياطي ────────────────────────────────
          _BackupCard(
            onImport: _importBackup,
            onExport: _exportBackup,
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ─── شريط حالة التفعيل ───────────────────────────────────────────────────────
class _ActivationBanner extends StatelessWidget {
  final bool isActivated;
  final int  customerCount;
  const _ActivationBanner({
    required this.isActivated,
    required this.customerCount,
  });

  @override
  Widget build(BuildContext context) {
    if (isActivated) {
      return Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              border: Border.all(color: Colors.green.shade200),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_outlined,
                    size: 14, color: Colors.green.shade700),
                const SizedBox(width: 4),
                Text(
                  'مفعّل',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // غير مفعّل — اعرض العداد
    final remaining = 50 - customerCount;
    final isNearLimit = remaining <= 10;
    final color = isNearLimit ? Colors.orange : Colors.blueGrey;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            border: Border.all(color: color.withValues(alpha: 0.35)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_open_outlined, size: 14, color: color.shade700),
              const SizedBox(width: 4),
              Text(
                'مجاني: $customerCount / 50',
                style: TextStyle(
                  fontSize: 12,
                  color: color.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── زر الدفتر ───────────────────────────────────────────────────────────────
class _BookButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final bool loading;

  const _BookButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: loading ? color.withValues(alpha: 0.45) : color,
      borderRadius: BorderRadius.circular(14),
      elevation: loading ? 0 : 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 26),
          child: Column(
            children: [
              loading
                  ? const SizedBox(
                      width: 36,
                      height: 36,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5),
                    )
                  : Icon(icon, color: Colors.white, size: 36),
              const SizedBox(height: 10),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── بطاقة النسخ الاحتياطي ───────────────────────────────────────────────────
class _BackupCard extends StatelessWidget {
  final VoidCallback onImport;
  final VoidCallback onExport;
  const _BackupCard({required this.onImport, required this.onExport});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.save_outlined,
                size: 18, color: Colors.grey.shade500),
            const SizedBox(width: 8),
            Text(
              'النسخ الاحتياطي',
              style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: onImport,
              icon: const Icon(Icons.upload_file, size: 16),
              label: const Text('استيراد'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey.shade700,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              ),
            ),
            const SizedBox(width: 4),
            TextButton.icon(
              onPressed: onExport,
              icon: const Icon(Icons.download_outlined, size: 16),
              label: const Text('تصدير'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey.shade700,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── بحث سريع ────────────────────────────────────────────────────────────────
class _QuickSearchResults extends StatefulWidget {
  final String query;
  final AppProvider provider;
  final bool compact;

  const _QuickSearchResults({
    required this.query,
    required this.provider,
    this.compact = false,
  });

  @override
  State<_QuickSearchResults> createState() => _QuickSearchResultsState();
}

class _QuickSearchResultsState extends State<_QuickSearchResults> {
  List<Customer> _results = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void didUpdateWidget(_QuickSearchResults old) {
    super.didUpdateWidget(old);
    if (old.query != widget.query) _search();
  }

  Future<void> _search() async {
    setState(() => _loading = true);
    try {
      final repo = CustomerRepository(widget.provider.dbHelper);
      _results = await repo.search(widget.query);
    } catch (_) {
      _results = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  // ─── bottom sheet لاختيار الدفتر ─────────────────────────────────────────
  Future<void> _openCustomer(BuildContext context, Customer customer) async {
    final lira = widget.provider.liraCurrency;
    final dollar = widget.provider.dollarCurrency;

    if (lira == null && dollar == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد عملة متاحة')),
      );
      return;
    }

    // إذا عملة واحدة فقط → افتح مباشرة
    if (lira != null && dollar == null) {
      await _navigate(context, customer, lira);
      return;
    }
    if (dollar != null && lira == null) {
      await _navigate(context, customer, dollar);
      return;
    }

    // عملتان متاحتان → اسأل
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    CircleAvatar(
                      child: Text(
                        customer.name.isNotEmpty ? customer.name[0] : '؟',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customer.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (lira != null)
                ListTile(
                  leading: const Icon(Icons.account_balance_wallet,
                      color: Color(0xFF1565C0)),
                  title: const Text('دفتر الليرة'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _navigate(context, customer, lira);
                  },
                ),
              if (dollar != null)
                ListTile(
                  leading: const Icon(Icons.attach_money,
                      color: Color(0xFF2E7D32)),
                  title: const Text('دفتر الدولار'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _navigate(context, customer, dollar);
                  },
                ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _navigate(BuildContext context, Customer customer, currency) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CustomerDetailsScreen(customer: customer, currency: currency),
      ),
    );
    if (changed == true && mounted) {
      await _search();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 8),
            Text(
              'لا نتائج لـ "${widget.query}"',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }
    final displayResults =
        widget.compact ? _results.take(8).toList() : _results;

    return ListView.separated(
      itemCount: displayResults.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final c = displayResults[i];
        return ListTile(
          dense: widget.compact,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          leading: CircleAvatar(
            radius: widget.compact ? 14 : 18,
            backgroundColor:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
            child: Text(
              c.name.isNotEmpty ? c.name[0] : '؟',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: widget.compact ? 12 : 14,
              ),
            ),
          ),
          title: Text(
            c.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          trailing: const Icon(Icons.chevron_left, color: Colors.grey),
          onTap: () async => _openCustomer(context, c),
        );
      },
    );
  }
}



