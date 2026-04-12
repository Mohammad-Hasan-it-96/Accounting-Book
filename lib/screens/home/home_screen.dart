import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers/app_provider.dart';
import '../../core/helpers/format_helper.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().loadCurrencies();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
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

    // إذا لا تزال تُحمَّل العملات → انتظر
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
    );
  }

  @override
  Widget build(BuildContext context) {
    // watch بدل read حتى تتحدث الواجهة عند انتهاء تحميل العملات
    final provider = context.watch<AppProvider>();
    final isLoading = provider.loading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('دفتر حسابات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'الإعدادات',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
          )
        ],
      ),
      body: Column(
        children: [
          // ─── بحث سريع ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'بحث سريع عن عميل...',
                prefixIcon: const Icon(Icons.search),
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
          // ─── نتائج سريعة خفيفة تحت حقل البحث ─────────────────────
          if (_searchCtrl.text.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ConstrainedBox(
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
            ),
          if (_searchCtrl.text.trim().isNotEmpty &&
              provider.liraCurrency != null &&
              provider.dollarCurrency != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'عند فتح عميل من البحث سيتم سؤالك عن الدفتر (ليرة/دولار).',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ),
            ),
          const SizedBox(height: 8),
          // ─── أزرار الدفاتر ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: _BookButton(
                    label: 'دفتر الليرة',
                    icon: Icons.account_balance_wallet,
                    color: const Color(0xFF1565C0),
                    // تعطيل الزر أثناء التحميل
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
          ),
          const SizedBox(height: 12),
          // ─── أزرار النسخ الاحتياطي ──────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.upload_file),
                    label: const Text('استيراد'),
                    onPressed: _importBackup,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.download),
                    label: const Text('تصدير'),
                    onPressed: _exportBackup,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 24),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.menu_book,
                      size: 72, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text(
                    isLoading ? 'جارٍ التحميل...' : 'اختر دفتراً للبدء',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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
      color: loading ? color.withValues(alpha: 0.5) : color,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            children: [
              loading
                  ? const SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5),
                    )
                  : Icon(icon, color: Colors.white, size: 32),
              const SizedBox(height: 8),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ],
          ),
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
      separatorBuilder: (_, __) => const Divider(height: 1),
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



