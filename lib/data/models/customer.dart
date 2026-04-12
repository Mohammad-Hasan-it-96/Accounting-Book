/// موديل العميل
class Customer {
  final int? id;
  final String name;
  final String? gsm;
  final int? gId;
  final int? cusTypeId;
  final String? groupName;

  const Customer({
    this.id,
    required this.name,
    this.gsm,
    this.gId,
    this.cusTypeId,
    this.groupName,
  });

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id:        _toInt(map['ID']),
      name:      map['name']?.toString() ?? '',
      gsm:       map['gsm']?.toString(),
      gId:       _toInt(map['g_id']),
      cusTypeId: _toInt(map['cus_type_id']),
      groupName: map['group_name']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'ID': id,
      'name': name,
      'gsm': gsm,
      'g_id': gId,
      'cus_type_id': cusTypeId,
    };
  }

  Customer copyWith({
    int? id,
    String? name,
    String? gsm,
    int? gId,
    int? cusTypeId,
    String? groupName,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      gsm: gsm ?? this.gsm,
      gId: gId ?? this.gId,
      cusTypeId: cusTypeId ?? this.cusTypeId,
      groupName: groupName ?? this.groupName,
    );
  }
}

// تحويل آمن — يقبل String أو num أو null
int? _toInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim());
  return null;
}

