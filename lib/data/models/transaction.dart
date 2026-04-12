/// موديل الحركة المالية
class Transaction {
  final int? id;
  final int cusId;
  final int inFlag;   // 1 = له (دائن) | -1 = عليه (مدين)
  final double out;   // قيمة الحركة
  final String? date;
  final String? remarks;
  final int? currId;
  final int? tCusId;
  final String? now;

  const Transaction({
    this.id,
    required this.cusId,
    required this.inFlag,
    required this.out,
    this.date,
    this.remarks,
    this.currId,
    this.tCusId,
    this.now,
  });

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id:      _toInt(map['ID']),
      cusId:   _toInt(map['cus_id']) ?? 0,
      inFlag:  _toInt(map['in'])     ?? 1,
      out:     _toDouble(map['out']) ?? 0.0,
      date:    map['date_']?.toString(),
      remarks: map['remarks']?.toString(),
      currId:  _toInt(map['curr_id']),
      tCusId:  _toInt(map['t_cus_id']),
      now:     map['now_']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'ID': id,
      'cus_id': cusId,
      'in': inFlag,
      'out': out,
      'date_': date,
      'remarks': remarks,
      'curr_id': currId,
      't_cus_id': tCusId,
      'now_': now,
    };
  }

  Transaction copyWith({
    int? id,
    int? cusId,
    int? inFlag,
    double? out,
    String? date,
    String? remarks,
    int? currId,
    int? tCusId,
    String? now,
  }) {
    return Transaction(
      id: id ?? this.id,
      cusId: cusId ?? this.cusId,
      inFlag: inFlag ?? this.inFlag,
      out: out ?? this.out,
      date: date ?? this.date,
      remarks: remarks ?? this.remarks,
      currId: currId ?? this.currId,
      tCusId: tCusId ?? this.tCusId,
      now: now ?? this.now,
    );
  }
}

// ─── دوال مساعدة للتحويل الآمن ───────────────────────────────────────────────
// تتعامل مع قيم مخزّنة كـ String أو num أو null (قواعد بيانات قديمة)

int? _toInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim());
  return null;
}

double? _toDouble(dynamic v) {
  if (v == null) return null;
  if (v is double) return v;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.trim());
  return null;
}

