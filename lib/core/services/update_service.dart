import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'settings_service.dart';

// ─── نموذج بيانات التحديث ────────────────────────────────────────────────────
class UpdateInfo {
  final String latestVersion;
  final int    latestBuild;
  final String apkUrl;
  final String changelog;
  final bool   forceUpdate;
  final String? supportWhatsapp;
  final String? supportTelegram;
  final String? apiBaseUrl;

  const UpdateInfo({
    required this.latestVersion,
    required this.latestBuild,
    required this.apkUrl,
    required this.changelog,
    required this.forceUpdate,
    this.supportWhatsapp,
    this.supportTelegram,
    this.apiBaseUrl,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) => UpdateInfo(
        latestVersion:   json['latest_version']   as String? ?? '0.0.0',
        latestBuild:     (json['latest_build']    as num?)?.toInt() ?? 0,
        apkUrl:          json['apk_url']          as String? ?? '',
        changelog:       json['changelog']        as String? ?? '',
        forceUpdate:     json['force_update']     as bool?   ?? false,
        supportWhatsapp: json['support_whatsapp'] as String?,
        supportTelegram: json['support_telegram'] as String?,
        apiBaseUrl:      json['api_base_url']     as String?,
      );
}

// ─── نتيجة فحص التحديث ───────────────────────────────────────────────────────
class UpdateResult {
  final bool       hasUpdate;
  final UpdateInfo? info;
  final String?    error;

  const UpdateResult._({this.hasUpdate = false, this.info, this.error});

  factory UpdateResult.noUpdate()                 => const UpdateResult._();
  factory UpdateResult.available(UpdateInfo info) => UpdateResult._(hasUpdate: true, info: info);
  factory UpdateResult.failure(String msg)        => UpdateResult._(error: msg);

  bool get isFailure => error != null;
}

// ─── خدمة التحديث ────────────────────────────────────────────────────────────
class UpdateService {
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  /// يفحص التحديث ويُطبّق الإعدادات الديناميكية من السيرفر.
  Future<UpdateResult> checkForUpdate() async {
    try {
      final response = await http
          .get(Uri.parse(SettingsService.updateConfigUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return UpdateResult.failure('فشل تحميل إعدادات التحديث (${response.statusCode})');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final info = UpdateInfo.fromJson(json);

      // تطبيق الإعدادات الديناميكية
      await _applyRemoteSettings(info);

      // مقارنة مع الإصدار الحالي
      final pkg = await PackageInfo.fromPlatform();
      final curBuild = int.tryParse(pkg.buildNumber) ?? 0;

      final isNewer = _isNewerVersion(info.latestVersion, pkg.version) ||
          (info.latestVersion == pkg.version && info.latestBuild > curBuild);

      return isNewer ? UpdateResult.available(info) : UpdateResult.noUpdate();
    } on SocketException {
      return UpdateResult.failure('لا يوجد اتصال بالإنترنت');
    } on http.ClientException {
      return UpdateResult.failure('تعذر الوصول إلى السيرفر');
    } on Exception catch (e) {
      return UpdateResult.failure('خطأ: $e');
    }
  }

  // ─── تطبيق الإعدادات من السيرفر ──────────────────────────────────────────
  Future<void> _applyRemoteSettings(UpdateInfo info) async {
    if (info.apiBaseUrl != null && info.apiBaseUrl!.isNotEmpty) {
      await SettingsService().setApiUrl(info.apiBaseUrl!);
    }
  }

  // ─── مقارنة semver (major.minor.patch) ───────────────────────────────────
  bool _isNewerVersion(String remote, String current) {
    final r = _parts(remote);
    final c = _parts(current);
    for (var i = 0; i < 3; i++) {
      final rv = r.length > i ? r[i] : 0;
      final cv = c.length > i ? c[i] : 0;
      if (rv > cv) return true;
      if (rv < cv) return false;
    }
    return false;
  }

  List<int> _parts(String v) => v
      .split('.')
      .map((p) => int.tryParse(p.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
      .toList();
}
