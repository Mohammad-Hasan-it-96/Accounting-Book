import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../providers/app_provider.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  List<_GroupItem> _groups = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final db = await context.read<AppProvider>().dbHelper.db;
      final rows = await db.rawQuery('''
        SELECT g.ID, g.name,
               COUNT(c.ID) AS customer_count
        FROM ${AppConstants.tableGroups} g
        LEFT JOIN ${AppConstants.tableCustomers} c ON c.g_id = g.ID
        GROUP BY g.ID, g.name
        ORDER BY g.name
      ''');
      _groups = rows
          .map((r) => _GroupItem(
                id: (r['ID'] as num).toInt(),
                name: r['name']?.toString() ?? '',
                customerCount: (r['customer_count'] as num?)?.toInt() ?? 0,
              ))
          .toList();
    } catch (_) {
      _groups = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  // ─── إضافة مجموعة ────────────────────────────────────────────────────────
  Future<void> _addGroup() async {
    final name = await _nameDialog(title: 'مجموعة جديدة');
    if (name == null || name.isEmpty || !mounted) return;
    final db = await context.read<AppProvider>().dbHelper.db;
    await db.insert(AppConstants.tableGroups, {'name': name});
    await _load();
  }

  // ─── تعديل اسم المجموعة ──────────────────────────────────────────────────
  Future<void> _renameGroup(_GroupItem group) async {
    final name = await _nameDialog(title: 'تعديل اسم المجموعة', initial: group.name);
    if (name == null || name.isEmpty || name == group.name || !mounted) return;
    final db = await context.read<AppProvider>().dbHelper.db;
    await db.update(
      AppConstants.tableGroups,
      {'name': name},
      where: 'ID = ?',
      whereArgs: [group.id],
    );
    await _load();
  }

  // ─── حذف مجموعة ──────────────────────────────────────────────────────────
  Future<void> _deleteGroup(_GroupItem group) async {
    if (group.customerCount > 0) {
      // اسأل المستخدم هل يريد إلغاء تعيين العملاء أيضاً
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('حذف المجموعة'),
          content: Text(
            'المجموعة "${group.name}" تحتوي على ${group.customerCount} عميل.\n'
            'سيتم إلغاء تعيينهم من المجموعة عند الحذف.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('حذف'),
            ),
          ],
        ),
      );
      if (confirm != true || !mounted) return;
    } else {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('حذف المجموعة'),
          content: Text('هل تريد حذف مجموعة "${group.name}"؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('حذف'),
            ),
          ],
        ),
      );
      if (confirm != true || !mounted) return;
    }

    final db = await context.read<AppProvider>().dbHelper.db;
    // إلغاء تعيين العملاء من المجموعة
    await db.update(
      AppConstants.tableCustomers,
      {'g_id': null},
      where: 'g_id = ?',
      whereArgs: [group.id],
    );
    await db.delete(
      AppConstants.tableGroups,
      where: 'ID = ?',
      whereArgs: [group.id],
    );
    await _load();
  }

  // ─── حوار إدخال الاسم ────────────────────────────────────────────────────
  Future<String?> _nameDialog({required String title, String? initial}) async {
    final ctrl = TextEditingController(text: initial ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'اسم المجموعة',
            prefixIcon: Icon(Icons.group_work_outlined),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المجموعات'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _groups.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.group_work_outlined,
                          size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text(
                        'لا توجد مجموعات',
                        style: TextStyle(
                            fontSize: 16, color: Colors.grey.shade500),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'اضغط + لإضافة مجموعة جديدة',
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade400),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  itemCount: _groups.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final g = _groups[i];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.12),
                        child: Icon(
                          Icons.group_work_outlined,
                          color: Theme.of(context).colorScheme.primary,
                          size: 20,
                        ),
                      ),
                      title: Text(g.name,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        g.customerCount == 0
                            ? 'لا يوجد عملاء'
                            : '${g.customerCount} عميل',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade500),
                      ),
                      trailing: PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert,
                            size: 20, color: Colors.grey.shade400),
                        tooltip: 'خيارات',
                        onSelected: (v) {
                          if (v == 'rename') _renameGroup(g);
                          if (v == 'delete') _deleteGroup(g);
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'rename',
                            child: Row(children: [
                              Icon(Icons.edit_outlined, size: 18),
                              SizedBox(width: 8),
                              Text('تعديل الاسم'),
                            ]),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(children: [
                              Icon(Icons.delete_outline,
                                  size: 18, color: Colors.red),
                              SizedBox(width: 8),
                              Text('حذف',
                                  style: TextStyle(color: Colors.red)),
                            ]),
                          ),
                        ],
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'إضافة مجموعة',
        onPressed: _addGroup,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _GroupItem {
  final int id;
  final String name;
  final int customerCount;
  const _GroupItem({
    required this.id,
    required this.name,
    required this.customerCount,
  });
}
