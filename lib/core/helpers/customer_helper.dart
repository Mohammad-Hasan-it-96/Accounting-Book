import '../../data/models/customer.dart';

/// Returns a safe, trimmed group name even if an old hot-reload snapshot
/// still uses a `Customer` shape that does not include `groupName`.
String? safeGroupName(Customer customer) {
  try {
    final dynamic value = (customer as dynamic).groupName;
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  } catch (_) {
    return null;
  }
}

