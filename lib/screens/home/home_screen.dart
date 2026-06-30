import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_durations.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/app_provider.dart';
import '../../core/helpers/format_helper.dart';
import '../../core/services/activation_service.dart';
import '../../core/services/update_service.dart';
import '../../core/widgets/update_dialog.dart';
import '../../data/repositories/customer_repository.dart';
import '../../data/models/customer.dart';
import '../../data/models/currency.dart';
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
  bool _backupInProgress = false;

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
    try {
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
    } catch (_) {
      if (!mounted) return;
      setState(() { _isActivated = false; _customerCount = 0; });
    }
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
    setState(() => _backupInProgress = true);
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (result == null || result.files.single.path == null) {
      if (mounted) setState(() => _backupInProgress = false);
      return;
    }
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
    if (confirm != true) {
      if (mounted) setState(() => _backupInProgress = false);
      return;
    }
    if (!mounted) return;

    final provider = context.read<AppProvider>();
    await provider.dbHelper.autoBackup();

    final ok = await provider.dbHelper.importDatabase(path);
    if (!mounted) return;
    if (!ok) {
      setState(() => _backupInProgress = false);
      _showSnack('تعذر استيراد النسخة الاحتياطية', isError: true);
      return;
    }
    final valid = await provider.dbHelper.validateTables();
    if (!mounted) return;
    if (!valid) {
      setState(() => _backupInProgress = false);
      _showSnack('الملف غير متوافق: الجداول أو الأعمدة الأساسية ناقصة', isError: true);
      return;
    }
    await provider.reload();
    if (!mounted) return;
    setState(() => _backupInProgress = false);
    _showSnack('تم استيراد النسخة الاحتياطية بنجاح');
    _loadActivationStatus();
  }

  // ─── تصدير نسخة احتياطية ─────────────────────────────────────────────────
  Future<void> _exportBackup() async {
    setState(() => _backupInProgress = true);
    final provider = context.read<AppProvider>();
    final fileName = FormatHelper.backupFileName();
    final path = await provider.dbHelper.exportDatabase(fileName);
    if (!mounted) return;
    if (path == null) {
      setState(() => _backupInProgress = false);
      _showSnack('تعذر تصدير النسخة الاحتياطية', isError: true);
      return;
    }
    await Share.shareXFiles(
      [XFile(path)],
      text: 'نسخة احتياطية - دفتر حسابات',
    );
    if (!mounted) return;
    setState(() => _backupInProgress = false);
    _showSnack('تم تصدير النسخة الاحتياطية بنجاح');
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
      behavior: SnackBarBehavior.floating,
      duration: AppDurations.snackbar,
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
          // حالة التفعيل بشكل خفيف داخل الشريط العلوي
          _ActivationIndicator(
            isActivated: _isActivated,
            customerCount: _customerCount,
          ),
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
      // زر الإضافة الرئيسي — بارز ودائم الظهور
      floatingActionButton: FloatingActionButton.extended(
        onPressed: isLoading ? null : _startAddCustomer,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('إضافة عميل'),
      ),
      body: ListView(
        // الحشوة السفلية تترك مساحة للزر العائم
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 80),
        children: [
          if (provider.hasError)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: AppIconSize.sm, color: Colors.orange.shade700),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'تعذر تحميل العملات. أعد تشغيل التطبيق.',
                      style: TextStyle(
                          fontSize: AppFontSize.small,
                          color: Colors.orange.shade700),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.md),

          // ── بحث سريع ────────────────────────────────────────────
          TextField(
            controller: _searchCtrl,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'ابحث عن عميل بالاسم...',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              filled: true,
              fillColor: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.grey.shade100,
              border: const OutlineInputBorder(
                borderRadius: AppRadius.lgAll,
                borderSide: BorderSide.none,
              ),
              enabledBorder: const OutlineInputBorder(
                borderRadius: AppRadius.lgAll,
                borderSide: BorderSide.none,
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: AppRadius.lgAll,
                borderSide: BorderSide(color: AppColors.primary, width: 1.5),
              ),
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
            const SizedBox(height: AppSpacing.xs),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: AppRadius.mdAll,
                ),
                child: ClipRRect(
                  borderRadius: AppRadius.mdAll,
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
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  'عند فتح عميل من البحث سيتم سؤالك عن الدفتر.',
                  style: TextStyle(
                      fontSize: AppFontSize.caption,
                      color: Colors.grey.shade500),
                ),
              ),
          ],

          const SizedBox(height: AppSpacing.lg),

          // ── زرا الدفاتر الرئيسيان ────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _BookButton(
                  label: 'دفتر الليرة',
                  icon: Icons.account_balance_wallet_outlined,
                  color: AppColors.primary,
                  onTap: isLoading ? null : () => _openCurrencyBook('ليرة'),
                  loading: isLoading,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _BookButton(
                  label: 'دفتر الدولار',
                  icon: Icons.attach_money,
                  color: AppColors.income,
                  onTap: isLoading ? null : () => _openCurrencyBook('دولار'),
                  loading: isLoading,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),

          // ── بطاقة النسخ الاحتياطي ────────────────────────────────
          _BackupCard(
            onImport: _importBackup,
            onExport: _exportBackup,
            inProgress: _backupInProgress,
          ),
        ],
      ),
    );
  }

  // ─── بدء إضافة عميل من الرئيسية ──────────────────────────────────────────
  // يسأل عن الدفتر (عند توفّر عملتين) ثم يفتح دفتر تلك العملة على وضع الإضافة
  // مباشرةً، فيُعاد استخدام فحص الحد المجاني وتدفّق الإضافة الموجودَين أصلاً.
  void _startAddCustomer() {
    final provider = context.read<AppProvider>();
    if (provider.loading) {
      _showSnack('جارٍ تحميل البيانات...');
      return;
    }
    final lira = provider.liraCurrency;
    final dollar = provider.dollarCurrency;

    if (lira == null && dollar == null) {
      _showSnack(
        'لا توجد عملة متاحة.\nاستورد قاعدة بيانات أو أعد تشغيل التطبيق.',
        isError: true,
      );
      return;
    }
    if (lira != null && dollar == null) {
      _openBookToAdd(lira);
      return;
    }
    if (dollar != null && lira == null) {
      _openBookToAdd(dollar);
      return;
    }

    // عملتان متاحتان → اسأل عن الدفتر (كلاهما غير فارغ بعد الفحوص أعلاه)
    final Currency liraBook = lira!;
    final Currency dollarBook = dollar!;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: AppRadius.lgRadius),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
              child: Row(
                children: [
                  const Icon(Icons.person_add_alt_1, color: AppColors.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Text('إضافة عميل إلى:', style: AppTextStyles.subtitleBold),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.account_balance_wallet,
                  color: AppColors.primary),
              title: const Text('دفتر الليرة'),
              onTap: () {
                Navigator.pop(context);
                _openBookToAdd(liraBook);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.attach_money, color: AppColors.income),
              title: const Text('دفتر الدولار'),
              onTap: () {
                Navigator.pop(context);
                _openBookToAdd(dollarBook);
              },
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
        ),
      ),
    );
  }

  void _openBookToAdd(Currency currency) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CurrencyAccountsScreen(currency: currency, openAddOnStart: true),
      ),
    ).then((_) => _loadActivationStatus());
  }
}

// ─── مؤشّر حالة التفعيل (خفيف داخل الشريط العلوي) ────────────────────────────
class _ActivationIndicator extends StatelessWidget {
  final bool isActivated;
  final int  customerCount;
  const _ActivationIndicator({
    required this.isActivated,
    required this.customerCount,
  });

  @override
  Widget build(BuildContext context) {
    // مفعّل → شارة تحقّق بسيطة فقط
    if (isActivated) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: Tooltip(
          message: 'مفعّل',
          child: Icon(Icons.verified,
              color: Colors.white, size: AppIconSize.md),
        ),
      );
    }

    // غير مفعّل → عدّاد خفيف (شريحة شفّافة فوق لون الشريط)
    final remaining = AppConstants.trialCustomerLimit - customerCount;
    final isNearLimit = remaining <= 10;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Center(
        child: Tooltip(
          message:
              'الحساب المجاني: $customerCount من ${AppConstants.trialCustomerLimit}',
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
            decoration: ShapeDecoration(
              color: Colors.white
                  .withValues(alpha: isNearLimit ? 0.28 : 0.16),
              shape: const StadiumBorder(),
            ),
            child: Text(
              '$customerCount/${AppConstants.trialCustomerLimit}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: AppFontSize.caption,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
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
      color: loading ? color.withValues(alpha: 0.45) : color,
      borderRadius: AppRadius.mdAll,
      elevation: loading ? 0 : 2,
      child: InkWell(
        borderRadius: AppRadius.mdAll,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
          child: Column(
            children: [
              loading
                  ? const SizedBox(
                      width: AppIconSize.xl,
                      height: AppIconSize.xl,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5),
                    )
                  : Icon(icon, color: Colors.white, size: AppIconSize.xl),
              const SizedBox(height: AppSpacing.md),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: AppFontSize.subtitle,
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
  final bool inProgress;
  const _BackupCard({
    required this.onImport,
    required this.onExport,
    this.inProgress = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.mdAll,
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          if (inProgress)
            const ClipRRect(
              borderRadius:
                  BorderRadius.vertical(top: AppRadius.mdRadius),
              child: LinearProgressIndicator(minHeight: 3),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.md),
            child: Row(
              children: [
                Icon(Icons.save_outlined,
                    size: AppIconSize.md, color: Colors.grey.shade500),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'النسخ الاحتياطي',
                  style: TextStyle(
                      fontSize: AppFontSize.body,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: inProgress ? null : onImport,
                  icon: const Icon(Icons.upload_file, size: AppIconSize.sm),
                  label: const Text('استيراد'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey.shade700,
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                TextButton.icon(
                  onPressed: inProgress ? null : onExport,
                  icon: const Icon(Icons.download_outlined,
                      size: AppIconSize.sm),
                  label: const Text('تصدير'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey.shade700,
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                  ),
                ),
              ],
            ),
          ),
        ],
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
        borderRadius: BorderRadius.vertical(top: AppRadius.lgRadius),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm,
                    AppSpacing.lg, AppSpacing.md),
                child: Row(
                  children: [
                    CircleAvatar(
                      child: Text(
                        customer.name.isNotEmpty ? customer.name[0] : '؟',
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customer.name,
                            style: AppTextStyles.subtitleBold,
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
                      color: AppColors.primary),
                  title: const Text('دفتر الليرة'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _navigate(context, customer, lira);
                  },
                ),
              if (dollar != null)
                ListTile(
                  leading: const Icon(Icons.attach_money,
                      color: AppColors.income),
                  title: const Text('دفتر الدولار'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _navigate(context, customer, dollar);
                  },
                ),
              const SizedBox(height: AppSpacing.xs),
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
            Icon(Icons.search_off,
                size: AppIconSize.xxl, color: Colors.grey.shade300),
            const SizedBox(height: AppSpacing.sm),
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
          contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.xxs),
          leading: CircleAvatar(
            radius: widget.compact ? 14 : 18,
            backgroundColor:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
            child: Text(
              c.name.isNotEmpty ? c.name[0] : '؟',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: widget.compact
                    ? AppFontSize.small
                    : AppFontSize.bodyLg,
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



