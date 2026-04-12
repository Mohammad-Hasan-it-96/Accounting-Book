import '../../core/constants/app_constants.dart';

/// موديل العملة مع الاسم المعروض
class Currency {
  final int? id;
  final String name;

  const Currency({this.id, required this.name});

  factory Currency.fromMap(Map<String, dynamic> map) {
    return Currency(
      id:   _toInt(map['ID']),
      name: map['name']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'ID': id,
        'name': name,
      };

  String get displayName {
    final key = name.trim().toLowerCase();
    for (final entry in AppConstants.currencyDisplayNames.entries) {
      if (entry.key.toLowerCase() == key) return entry.value;
    }
    return name;
  }

  bool get isLira   => displayName == 'ليرة';
  bool get isDollar => displayName == 'دولار';
}

// تحويل آمن — يقبل String أو num أو null
int? _toInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim());
  return null;
}
