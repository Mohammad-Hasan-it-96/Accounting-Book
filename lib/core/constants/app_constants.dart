// ثوابت التطبيق
class AppConstants {
  // اسم ملف قاعدة البيانات
  static const String dbName = 'daftar_hesabat.db';
  // v4: فهرس مركّب idx_tx_cus_curr على (cus_id, curr_id)
  static const int dbVersion = 4;

  // أسماء الجداول
  static const String tableCustomers = 'customers';
  static const String tableTransactions = 'transactions';
  static const String tableCurrency = 'currency';
  static const String tableGroups = 'groups';
  static const String tableCusType = 'cus_type';

  // IDs العملات الافتراضية (يُحدَّد بعد قراءة قاعدة البيانات)
  // الـ mapping يربط بين اسم العملة في DB والاسم المعروض
  static const Map<String, String> currencyDisplayNames = {
    'محلي': 'ليرة',
    'ليرة': 'ليرة',
    'دولار': 'دولار',
    'dollar': 'دولار',
    'usd': 'دولار',
  };

  // الحد الأقصى للعملاء في النسخة المجانية
  static const int trialCustomerLimit = 150;
  static const int trialWarningThreshold = 140;
}

