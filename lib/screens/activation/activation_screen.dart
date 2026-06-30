import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/activation_service.dart';
import '../../core/services/settings_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_durations.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_form_field.dart';
import '../../core/widgets/app_snackbar.dart';
import '../home/home_screen.dart';
class ActivationScreen extends StatefulWidget {
  const ActivationScreen({super.key});
  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}
class _ActivationScreenState extends State<ActivationScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _nameCtrl  = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String? _deviceId;
  bool _loadingDeviceId = true;
  bool _sendingRequest  = false;
  bool _checkingStatus  = false;
  // نتيجة آخر عملية
  _ResultBanner? _banner;
  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }
  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }
  // ─── تحميل البيانات الأولية ───────────────────────────────────────────────
  Future<void> _loadInitialData() async {
    final service = ActivationService();
    final deviceId = await service.getDeviceId();
    final name     = await service.getUserName()  ?? '';
    final phone    = await service.getUserPhone() ?? '';
    if (!mounted) return;
    setState(() {
      _deviceId         = deviceId;
      _loadingDeviceId  = false;
      _nameCtrl.text    = name;
      _phoneCtrl.text   = phone;
    });
  }
  // ─── إرسال طلب التفعيل ───────────────────────────────────────────────────
  Future<void> _sendRequest() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _sendingRequest = true; _banner = null; });
    final result = await ActivationService().requestActivation(
      name:  _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() { _sendingRequest = false; });
    if (result.isSuccess) {
      _showSuccessAndNavigate(result.message);
    } else {
      setState(() {
        _banner = _ResultBanner(
          message: result.message,
          type: result.isPending ? _BannerType.pending : _BannerType.error,
        );
      });
    }
  }
  // ─── التحقق من التفعيل ───────────────────────────────────────────────────
  Future<void> _checkStatus() async {
    setState(() { _checkingStatus = true; _banner = null; });
    final result = await ActivationService().checkActivation();
    if (!mounted) return;
    setState(() { _checkingStatus = false; });
    if (result.isSuccess) {
      _showSuccessAndNavigate(result.message);
    } else {
      setState(() {
        _banner = _ResultBanner(
          message: result.message,
          type: result.isPending ? _BannerType.pending : _BannerType.error,
        );
      });
    }
  }
  void _showSuccessAndNavigate(String message) {
    setState(() {
      _banner = _ResultBanner(message: message, type: _BannerType.success);
    });
    Future.delayed(AppDurations.slow, () {
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    });
  }
  // ─── نسخ Device ID ───────────────────────────────────────────────────────
  void _copyDeviceId() {
    if (_deviceId == null) return;
    Clipboard.setData(ClipboardData(text: _deviceId!));
    AppSnackBar.success(context, 'تم نسخ معرّف الجهاز');
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      body: SafeArea(
        child: _loadingDeviceId
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xxl, vertical: AppSpacing.xl),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: AppSpacing.xl),
                      // ─── أيقونة ──────────────────────────────────
                      Center(
                        child: Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            color: primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.lock_open_outlined,
                              size: 38, color: primary),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      // ─── العنوان ─────────────────────────────────
                      Text('تفعيل دفتر الحسابات',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.headlineBold),
                      const SizedBox(height: AppSpacing.sm),
                       Text(
                         'التطبيق مجاني لإدارة حتى 50 حسابًا.\nبعد ذلك، يكفي التفعيل مرة واحدة للاستخدام غير المحدود.',
                         textAlign: TextAlign.center,
                         style: TextStyle(fontSize: AppFontSize.body, color: Colors.grey.shade600, height: 1.5),
                       ),
                      const SizedBox(height: AppSpacing.xxl),
                      // ─── حقل الاسم ───────────────────────────────
                      AppTextField(
                        controller: _nameCtrl,
                        label: 'الاسم',
                        icon: Icons.person_outline,
                        required: true,
                        requiredMessage: 'الاسم مطلوب',
                        textInputAction: TextInputAction.next,
                      ),
                      Gap.h12,
                      // ─── حقل الهاتف ──────────────────────────────
                      AppTextField(
                        controller: _phoneCtrl,
                        label: 'رقم الهاتف',
                        icon: Icons.phone_outlined,
                        required: true,
                        requiredMessage: 'رقم الهاتف مطلوب',
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.done,
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      // ─── زر إرسال الطلب ──────────────────────────
                      ElevatedButton.icon(
                        onPressed: (_sendingRequest || _checkingStatus)
                            ? null
                            : _sendRequest,
                        icon: _sendingRequest
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.send_outlined),
                        label: Text(
                            _sendingRequest ? 'جارٍ الإرسال...' : 'إرسال طلب التفعيل'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      // ─── زر التحقق ───────────────────────────────
                      OutlinedButton.icon(
                        onPressed: (_sendingRequest || _checkingStatus)
                            ? null
                            : _checkStatus,
                        icon: _checkingStatus
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: primary),
                              )
                            : const Icon(Icons.verified_outlined),
                        label: Text(_checkingStatus
                            ? 'جارٍ التحقق...'
                            : 'تحقق من التفعيل'),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      // ─── البانر ──────────────────────────────────
                      if (_banner != null) _BannerWidget(banner: _banner!),
                      if (_banner != null) const SizedBox(height: AppSpacing.lg),
                      // ─── بطاقة معرّف الجهاز ──────────────────────
                      _DeviceIdCard(
                        deviceId: _deviceId ?? '',
                        onCopy: _copyDeviceId,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      // ─── أزرار التواصل ────────────────────────────
                      const _ContactRow(),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
// ─── بانر النتيجة ─────────────────────────────────────────────────────────────
enum _BannerType { success, pending, error }
class _ResultBanner {
  final String message;
  final _BannerType type;
  const _ResultBanner({required this.message, required this.type});
}
class _BannerWidget extends StatelessWidget {
  final _ResultBanner banner;
  const _BannerWidget({required this.banner});
  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color border;
    final Color fg;
    final IconData icon;
    switch (banner.type) {
      case _BannerType.success:
        bg     = Colors.green.shade50;
        border = Colors.green.shade400;
        fg     = Colors.green.shade900;
        icon   = Icons.check_circle_outline;
      case _BannerType.pending:
        bg     = Colors.orange.shade50;
        border = Colors.orange.shade400;
        fg     = Colors.orange.shade900;
        icon   = Icons.hourglass_top_outlined;
      case _BannerType.error:
        bg     = Colors.red.shade50;
        border = Colors.red.shade400;
        fg     = Colors.red.shade900;
        icon   = Icons.error_outline;
    }
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: AppRadius.mdAll,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: fg, size: AppIconSize.md),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              banner.message,
              style: TextStyle(color: fg, fontSize: AppFontSize.body, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
// ─── بطاقة معرّف الجهاز ──────────────────────────────────────────────────────
class _DeviceIdCard extends StatelessWidget {
  final String deviceId;
  final VoidCallback onCopy;
  const _DeviceIdCard({required this.deviceId, required this.onCopy});
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.fingerprint,
                  size: AppIconSize.md,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: AppSpacing.sm),
              const Text('معرّف الجهاز',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: AppFontSize.body)),
              const Spacer(),
              IconButton(
                onPressed: onCopy,
                icon: const Icon(Icons.copy, size: AppIconSize.sm),
                tooltip: 'نسخ',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ]),
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.08),
                borderRadius: AppRadius.smAll,
              ),
              child: SelectableText(
                deviceId,
                style: const TextStyle(
                    fontFamily: 'monospace', fontSize: AppFontSize.caption),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'شارك هذا المعرّف مع المطوّر لتسريع عملية التفعيل.',
              style: TextStyle(fontSize: AppFontSize.caption, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }
}
// ─── أزرار التواصل ────────────────────────────────────────────────────────────
class _ContactRow extends StatelessWidget {
  const _ContactRow();
  Future<void> _open(BuildContext ctx, String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (ctx.mounted) {
        AppSnackBar.error(ctx, 'تعذر فتح الرابط');
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('للتواصل مع المطوّر عبر واتساب:',
            style: TextStyle(fontSize: AppFontSize.small, color: Colors.grey.shade600)),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _open(context,
                'https://wa.me/${SettingsService.supportWhatsApp}?text=${Uri.encodeComponent("مرحباً، أريد تفعيل دفتر الحسابات")}'),
            icon: const Icon(Icons.chat, size: AppIconSize.sm,
                color: AppColors.whatsApp),
            label: const Text('مراسلة على واتساب',
                style: TextStyle(
                    color: AppColors.whatsApp, fontSize: AppFontSize.body)),
          ),
        ),
      ],
    );
  }
}
