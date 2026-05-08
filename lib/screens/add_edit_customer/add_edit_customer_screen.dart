import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/customer.dart';
import '../../data/repositories/customer_repository.dart';
import '../../providers/app_provider.dart';
import '../../core/constants/app_constants.dart';

class _LookupItem {
  final int id;
  final String name;

  const _LookupItem({required this.id, required this.name});
}

class AddEditCustomerScreen extends StatefulWidget {
  final Customer? customer; // null = إضافة جديدة

  const AddEditCustomerScreen({super.key, this.customer});

  @override
  State<AddEditCustomerScreen> createState() => _AddEditCustomerScreenState();
}

class _AddEditCustomerScreenState extends State<AddEditCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _gsmCtrl;
  bool _saving = false;
  int? _selectedGroupId;
  int? _selectedTypeId;
  List<_LookupItem> _groups = const [];
  List<_LookupItem> _types = const [];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.customer?.name ?? '');
    _gsmCtrl = TextEditingController(text: widget.customer?.gsm ?? '');
    _selectedGroupId = widget.customer?.gId;
    _selectedTypeId = widget.customer?.cusTypeId;
    _loadDropdownData();
  }

  Future<void> _loadDropdownData() async {
    final db = await context.read<AppProvider>().dbHelper.db;
    final groupRows = await db.query(AppConstants.tableGroups, orderBy: 'name');
    final typeRows = await db.query(AppConstants.tableCusType, orderBy: 'name');

    if (!mounted) return;

    setState(() {
      _groups = groupRows
          .where((r) => r['ID'] != null)
          .map(
            (r) => _LookupItem(
              id: (r['ID'] as num).toInt(),
              name: r['name']?.toString() ?? '',
            ),
          )
          .toList();
      _types = typeRows
          .where((r) => r['ID'] != null)
          .map(
            (r) => _LookupItem(
              id: (r['ID'] as num).toInt(),
              name: r['name']?.toString() ?? '',
            ),
          )
          .toList();
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _gsmCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final dbHelper = context.read<AppProvider>().dbHelper;
    final repo = CustomerRepository(dbHelper);

    final customer = Customer(
      id: widget.customer?.id,
      name: _nameCtrl.text.trim(),
      gsm: _gsmCtrl.text.trim().isEmpty ? null : _gsmCtrl.text.trim(),
      gId: _selectedGroupId,
      cusTypeId: _selectedTypeId,
    );

    if (widget.customer == null) {
      final newId = await repo.insert(customer);
      if (!mounted) return;
      Navigator.pop(context, customer.copyWith(id: newId));
      return;
    } else {
      await repo.update(customer);
    }

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Future<void> _deleteCustomer() async {
    final id = widget.customer?.id;
    if (id == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل تريد حذف العميل نهائيًا؟'),
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

    if (confirm != true) return;
    if (!mounted) return;

    setState(() => _saving = true);
    try {
      final dbHelper = context.read<AppProvider>().dbHelper;
      final repo = CustomerRepository(dbHelper);
      await repo.delete(id);
      if (mounted) Navigator.pop(context, true);
    } on StateError catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      final hasTx = e.message == 'customer_has_transactions';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            hasTx
                ? 'لا يمكن حذف العميل لأنه يملك حركات. احذف الحركات أولاً.'
                : 'تعذر حذف العميل',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر حذف العميل')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.customer != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'تعديل عميل' : 'إضافة عميل'),
        actions: [
          if (isEdit)
            IconButton(
              tooltip: 'حذف العميل',
              onPressed: _saving ? null : _deleteCustomer,
              icon: const Icon(Icons.delete_outline, color: Colors.red),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // الاسم
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'الاسم *',
                prefixIcon: Icon(Icons.person),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'الاسم مطلوب' : null,
            ),
            const SizedBox(height: 12),
            // رقم الهاتف
            TextFormField(
              controller: _gsmCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'رقم الهاتف (اختياري)',
                prefixIcon: Icon(Icons.phone),
              ),
            ),
            const SizedBox(height: 12),
            // المجموعة
            DropdownButtonFormField<int?>(
              initialValue: _groups.any((g) => g.id == _selectedGroupId)
                  ? _selectedGroupId
                  : null,
              decoration: const InputDecoration(
                labelText: 'المجموعة (اختياري)',
                prefixIcon: Icon(Icons.group_work_outlined),
              ),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('بدون مجموعة'),
                ),
                ..._groups.map(
                  (g) => DropdownMenuItem<int?>(
                    value: g.id,
                    child: Text(g.name),
                  ),
                ),
              ],
              onChanged: (v) => setState(() => _selectedGroupId = v),
            ),
            const SizedBox(height: 12),
            // النوع
            DropdownButtonFormField<int?>(
              initialValue: _types.any((t) => t.id == _selectedTypeId)
                  ? _selectedTypeId
                  : null,
              decoration: const InputDecoration(
                labelText: 'النوع (اختياري)',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('بدون نوع'),
                ),
                ..._types.map(
                  (t) => DropdownMenuItem<int?>(
                    value: t.id,
                    child: Text(t.name),
                  ),
                ),
              ],
              onChanged: (v) => setState(() => _selectedTypeId = v),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(isEdit ? 'حفظ التعديلات' : 'إضافة العميل'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

