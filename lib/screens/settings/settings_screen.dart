import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/activation_service.dart';
import '../../core/services/settings_service.dart';
import '../../core/services/update_service.dart';
import '../../core/widgets/update_dialog.dart';
import '../../data/models/customer.dart';
import '../../data/repositories/customer_repository.dart';
import '../../providers/app_provider.dart';
import '../../core/helpers/format_helper.dart';
import '../../providers/theme_provider.dart';
import '../activation/activation_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // ─── حالة ─────────────────────────────────────────────────────────────────
  String  _version        = '...';
  String  _buildNumber    = '';
  String  _apiUrl         = SettingsService.defaultApiUrl;
  String? _deviceId;
  bool    _isActivated    = false;
  int     _customerCount  = 0;

  bool _loadingInfo       = true;
  bool _checkingUpdate    = false;
  bool _recheckingActivation = false;

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

   // ─── تحميل البيانات الأولية ───────────────────────────────────────────────
   Future<void> _loadInfo() async {
     final results = await Future.wait([
       PackageInfo.fromPlatform(),
       SettingsService().getApiUrl(),
       ActivationService().getDeviceId(),
       ActivationService().isActivated(),
       CustomerRepository(context.read<AppProvider>().dbHelper).getAll(),
     ]);
     if (!mounted) return;
     final pkg       = results[0] as PackageInfo;
     final api       = results[1] as String;
     final device    = results[2] as String;
     final activated = results[3] as bool;
     final customers = results[4] as List<Customer>;
     setState(() {
       _version      = pkg.version;
       _buildNumber  = pkg.buildNumber;
       _apiUrl       = api;
       _deviceId     = device;
       _isActivated  = activated;
       _customerCount = customers.length;
       _loadingInfo  = false;
     });
   }

   // ─── فحص التحديثات ────────────────────────────────────────────────────────
   Future<void> _checkUpdates() async {
     setState(() => _checkingUpdate = true);
     final result = await UpdateService().checkForUpdate();
     if (!mounted) return;
     setState(() => _checkingUpdate = false);

     if (result.hasUpdate && result.info != null) {
       await UpdateDialog.show(context, result.info!);
     } else if (result.isFailure) {
       _showSnack(result.error!, isError: true);
     } else {
       _showSnack('✅  أنت تستخدم أحدث إصدار');
     }
   }

   // ─── تصدير الاحتياطي ────────────────────────────────────────────────────────
   Future<void> _exportBackup() async {
     final provider = context.read<AppProvider>();
     try {
       final fileName = FormatHelper.backupFileName();
       final path = await provider.dbHelper.exportDatabase(fileName);
       if (!mounted) return;
       if (path == null) {
         _showSnack('تعذر تصدير النسخة الاحتياطية', isError: true);
         return;
       }
       await Share.shareXFiles(
         [XFile(path)],
         text: 'نسخة احتياطية من دفتر الحسابات',
       );
       if (!mounted) return;
       _showSnack('تم تصدير النسخة الاحتياطية بنجاح');
     } catch (e) {
       if (!mounted) return;
       _showSnack('فشل التصدير: $e', isError: true);
     }
   }

   // ─── استيراد الاحتياطي ─────────────────────────────────────────────────────
   Future<void> _importBackup() async {
     final provider = context.read<AppProvider>();
     try {
       final result = await FilePicker.platform.pickFiles(
         type: FileType.any,
         allowMultiple: false,
       );
       if (result == null || result.files.single.path == null) return;
       final path = result.files.single.path!;
       final ok = await provider.dbHelper.importDatabase(path);
       if (!mounted) return;
       if (ok) {
         _showSnack('تم استيراد النسخة الاحتياطية بنجاح');
         // إعادة تحميل البيانات لتعكس التغييرات
         await _loadInfo();
       } else {
         _showSnack('فشل الاستيراد', isError: true);
       }
     } catch (e) {
       if (!mounted) return;
       _showSnack('خطأ في الاستيراد: $e', isError: true);
     }
   }

  // ─── إعادة فحص التفعيل ────────────────────────────────────────────────────
  Future<void> _recheckActivation() async {
    setState(() => _recheckingActivation = true);
    final result = await ActivationService().checkActivation();
    if (!mounted) return;
    setState(() {
      _recheckingActivation = false;
      if (result.isSuccess) _isActivated = true;
    });
    _showSnack(
      result.message,
      isError: result.isError,
      isSuccess: result.isSuccess,
    );
  }

  // ─── تعديل API URL ────────────────────────────────────────────────────────
  void _editApiUrl() {
    final ctrl = TextEditingController(text: _apiUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('رابط API'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            hintText: 'https://...',
            prefixIcon: Icon(Icons.link),
          ),
          keyboardType: TextInputType.url,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () async {
              await SettingsService().resetApiUrl();
              if (mounted) setState(() => _apiUrl = SettingsService.defaultApiUrl);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('إعادة الافتراضي'),
          ),
          ElevatedButton(
            onPressed: () async {
              final url = ctrl.text.trim();
              if (url.isNotEmpty) {
                await SettingsService().setApiUrl(url);
                if (mounted) setState(() => _apiUrl = url);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  // ─── فتح رابط خارجي ───────────────────────────────────────────────────────
  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) _showSnack('تعذر فتح الرابط', isError: true);
    }
  }

  // ─── نسخ Device ID ────────────────────────────────────────────────────────
  void _copyDeviceId() {
    if (_deviceId == null) return;
    Clipboard.setData(ClipboardData(text: _deviceId!));
    _showSnack('تم نسخ معرّف الجهاز');
  }

  // ─── تأكيد إعادة تعيين التفعيل ────────────────────────────────────────────
  Future<void> _confirmResetActivation() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إعادة تعيين التفعيل'),
        content: const Text(
          'سيتم إلغاء التفعيل وستحتاج إلى تفعيل التطبيق مجدداً.\nهل تريد المتابعة؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('إعادة التعيين'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await ActivationService().resetActivation();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const ActivationScreen()),
      (route) => false,
    );
  }

  void _showSnack(String msg, {bool isError = false, bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      backgroundColor: isError
          ? Colors.red.shade700
          : isSuccess
              ? Colors.green.shade700
              : null,
      duration: const Duration(seconds: 3),
    ));
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final primary       = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: _loadingInfo
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // ──────────────────────────────────────────────────────────
                // بطاقة معلومات التطبيق
                // ──────────────────────────────────────────────────────────
                 _AppInfoCard(
                   version:     _version,
                   buildNumber: _buildNumber,
                   deviceId:    _deviceId ?? '',
                   onCopy:      _copyDeviceId,
                   primary:     primary,
                   customerCount: _customerCount,
                 ),

                const SizedBox(height: 8),

                // ──────────────────────────────────────────────────────────
                // المظهر
                // ──────────────────────────────────────────────────────────
                _SectionHeader(title: 'المظهر'),
                SwitchListTile(
                  secondary: Icon(
                    themeProvider.isDark
                        ? Icons.dark_mode
                        : Icons.light_mode_outlined,
                  ),
                  title: const Text('الوضع الداكن'),
                  subtitle: Text(themeProvider.isDark ? 'مفعّل' : 'معطّل'),
                  value: themeProvider.isDark,
                  onChanged: (_) => themeProvider.toggle(),
                ),
                const Divider(),

                 // ──────────────────────────────────────────────────────────
                 // التحديثات
                 // ──────────────────────────────────────────────────────────
                 _SectionHeader(title: 'التحديثات'),
                 ListTile(
                   leading: const Icon(Icons.system_update_outlined),
                   title: const Text('التحقق من التحديثات'),
                   subtitle: const Text('البحث عن إصدارات جديدة'),
                   trailing: _checkingUpdate
                       ? const SizedBox(
                           width: 20,
                           height: 20,
                           child: CircularProgressIndicator(strokeWidth: 2),
                         )
                       : const Icon(Icons.chevron_left),
                   onTap: _checkingUpdate ? null : _checkUpdates,
                 ),
                 const Divider(),

                 // ──────────────────────────────────────────────────────────
                 // البيانات
                 // ──────────────────────────────────────────────────────────
                 _SectionHeader(title: 'البيانات'),
                 ListTile(
                   leading: const Icon(Icons.file_copy_outlined),
                   title: const Text('تصدير الاحتياطي'),
                   subtitle: const Text('حفظ نسخة احتياطية من البيانات'),
                   trailing: const Icon(Icons.chevron_left),
                   onTap: _exportBackup,
                 ),
                 ListTile(
                   leading: const Icon(Icons.file_upload_outlined),
                   title: const Text('استيراد الاحتياطي'),
                   subtitle: const Text('استعادة البيانات من نسخة احتياطية'),
                   trailing: const Icon(Icons.chevron_left),
                   onTap: _importBackup,
                 ),
                 const Divider(),

                 // ──────────────────────────────────────────────────────────
                 // إعدادات متقدمة
                 // ──────────────────────────────────────────────────────────
                 _SectionHeader(title: 'إعدادات متقدمة'),
                 ListTile(
                   leading: const Icon(Icons.api_outlined),
                   title: const Text('رابط API'),
                   subtitle: Text(
                     _apiUrl,
                     maxLines: 1,
                     overflow: TextOverflow.ellipsis,
                     style: const TextStyle(fontSize: 12),
                   ),
                   trailing: const Icon(Icons.edit_outlined),
                   onTap: _editApiUrl,
                 ),
                 const Divider(),

                // ──────────────────────────────────────────────────────────
                // الدعم الفني
                // ──────────────────────────────────────────────────────────
                _SectionHeader(title: 'الدعم الفني'),
                ListTile(
                  leading: const Icon(Icons.chat, color: Color(0xFF25D366)),
                  title: const Text('واتساب'),
                  subtitle: const Text('تواصل مع المطوّر'),
                  trailing: const Icon(Icons.open_in_new, size: 16),
                  onTap: () => _openUrl(
                      'https://wa.me/${SettingsService.supportWhatsApp}'
                      '?text=${Uri.encodeComponent("مرحباً، أحتاج مساعدة في دفتر الحسابات")}'),
                ),
                ListTile(
                  leading: const Icon(Icons.send, color: Color(0xFF0088CC)),
                  title: const Text('تيليغرام'),
                  subtitle: const Text('تواصل مع المطوّر'),
                  trailing: const Icon(Icons.open_in_new, size: 16),
                  onTap: () => _openUrl(SettingsService.supportTelegram),
                ),
                ListTile(
                  leading: const Icon(Icons.email_outlined),
                  title: const Text('البريد الإلكتروني'),
                  subtitle: const Text(SettingsService.supportEmail),
                  trailing: const Icon(Icons.open_in_new, size: 16),
                  onTap: () =>
                      _openUrl('mailto:${SettingsService.supportEmail}'),
                ),
                const Divider(),

                // ──────────────────────────────────────────────────────────
                // التفعيل
                // ──────────────────────────────────────────────────────────
                _SectionHeader(title: 'التفعيل'),

                // حالة التفعيل
                ListTile(
                  leading: Icon(
                    _isActivated
                        ? Icons.verified_outlined
                        : Icons.lock_outline,
                    color: _isActivated
                        ? Colors.green.shade600
                        : Colors.orange.shade700,
                  ),
                  title: const Text('حالة التفعيل'),
                  subtitle: Text(
                    _isActivated ? 'التطبيق مفعّل ✅' : 'التطبيق غير مفعّل ⏳',
                  ),
                  trailing: _isActivated
                      ? Chip(
                          label: const Text(
                            'مفعّل',
                            style: TextStyle(
                                color: Colors.white, fontSize: 11),
                          ),
                          backgroundColor: Colors.green.shade600,
                          padding: EdgeInsets.zero,
                        )
                      : Chip(
                          label: const Text(
                            'غير مفعّل',
                            style: TextStyle(
                                color: Colors.white, fontSize: 11),
                          ),
                          backgroundColor: Colors.orange.shade700,
                          padding: EdgeInsets.zero,
                        ),
                ),

                // إعادة فحص التفعيل
                ListTile(
                  leading: _recheckingActivation
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  title: const Text('إعادة فحص التفعيل'),
                  subtitle: const Text('التحقق من حالة التفعيل على السيرفر'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: _recheckingActivation ? null : _recheckActivation,
                ),

                // الانتقال لشاشة التفعيل
                ListTile(
                  leading: const Icon(Icons.lock_open_outlined),
                  title: const Text('شاشة التفعيل'),
                  subtitle: const Text('إرسال طلب تفعيل جديد'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ActivationScreen()),
                  ),
                ),

                // إعادة تعيين التفعيل
                ListTile(
                  leading: const Icon(Icons.lock_reset, color: Colors.red),
                  title: const Text(
                    'إعادة تعيين التفعيل',
                    style: TextStyle(color: Colors.red),
                  ),
                  subtitle: const Text(
                      'للاستخدام عند نقل التطبيق لجهاز جديد'),
                  onTap: _confirmResetActivation,
                ),

                const SizedBox(height: 32),
              ],
            ),
    );
  }
}

// ─── بطاقة معلومات التطبيق ───────────────────────────────────────────────────
class _AppInfoCard extends StatelessWidget {
  final String version;
  final String buildNumber;
  final String deviceId;
  final VoidCallback onCopy;
  final Color primary;
  final int customerCount;

  const _AppInfoCard({
    required this.version,
    required this.buildNumber,
    required this.deviceId,
    required this.onCopy,
    required this.primary,
    required this.customerCount,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ── أيقونة + اسم التطبيق + الإصدار ─────────────────────────
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.menu_book, color: primary, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'دفتر حسابات',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        'الإصدار $version+$buildNumber',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            // ── عدد العملاء والحد المجاني ─────────────────────────────────
            Row(
              children: [
                Icon(Icons.people_outline, size: 18, color: primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'العملاء: $customerCount',
                        style: TextStyle(fontSize: 13),
                      ),
                      Text(
                        'الحد المجاني: 50 حساب',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            // ── معرّف الجهاز ─────────────────────────────────────────────
            Row(
              children: [
                Icon(Icons.fingerprint, size: 16, color: primary),
                const SizedBox(width: 6),
                const Text(
                  'معرّف الجهاز',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const Spacer(),
                InkWell(
                  onTap: onCopy,
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.copy, size: 14, color: primary),
                        const SizedBox(width: 4),
                        Text(
                          'نسخ',
                          style: TextStyle(fontSize: 12, color: primary),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                deviceId,
                style: const TextStyle(
                    fontFamily: 'monospace', fontSize: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── رأس القسم ───────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }
}
