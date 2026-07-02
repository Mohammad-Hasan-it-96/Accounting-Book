import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/activation_service.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/app_form_field.dart';
import '../../core/widgets/app_loading.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../data/models/customer.dart';
import '../../data/repositories/customer_repository.dart';
import '../../providers/app_provider.dart';
import '../activation/activation_screen.dart';

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
  late final TextEditingController _notesCtrl;
  bool _saving      = false;
  bool _dirty       = false; // تتبع التغييرات غير المحفوظة
  bool _isArchived  = false;
  int? _selectedGroupId;
  int? _selectedTypeId;
  List<_LookupItem> _groups = const [];
  List<_LookupItem> _types = const [];

  void _markDirty() { if (!_dirty) setState(() => _dirty = true); }

  @override
  void initState() {
    super.initState();
    _nameCtrl   = TextEditingController(text: widget.customer?.name ?? '');
    _gsmCtrl    = TextEditingController(text: widget.customer?.gsm ?? '');
    _notesCtrl  = TextEditingController(text: widget.customer?.notes ?? '');
    _isArchived = widget.customer?.isArchived ?? false;
    _selectedGroupId = widget.customer?.gId;
    _selectedTypeId  = widget.customer?.cusTypeId;
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
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.lightImpact();
      return;
    }
    setState(() => _saving = true);

    final dbHelper = context.read<AppProvider>().dbHelper;
    final repo = CustomerRepository(dbHelper);
    final name = _nameCtrl.text.trim();

    if (widget.customer == null) {
      // التحقق من الحد المجاني
      final count     = await repo.count();
      final activated = await ActivationService().isActivated();
      if (!activated && count >= AppConstants.trialCustomerLimit) {
        if (!mounted) return;
        setState(() => _saving = false);
        final go = await AppDialog.confirm(
          context,
          title: 'وصلت إلى الحد المجاني',
          message:
              'يمكنك إضافة حتى ${AppConstants.trialCustomerLimit} عميلاً مجاناً.\n'
              'فعّل التطبيق للاستمرار بدون حدود.',
          confirmLabel: 'تفعيل الآن',
          cancelLabel: 'لاحقاً',
          icon: Icons.lock_outline,
        );
        if (go && mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ActivationScreen()),
          );
        }
        return;
      }

      // تحقق من الاسم المكرر
      final all = await repo.getAll();
      final duplicate = all.any(
        (c) => c.name.trim().toLowerCase() == name.toLowerCase(),
      );
      if (duplicate && mounted) {
        setState(() => _saving = false);
        final proceed = await AppDialog.confirm(
          context,
          title: 'اسم مكرر',
          message: 'يوجد عميل بالاسم "$name" مسبقاً.\nهل تريد المتابعة؟',
          confirmLabel: 'متابعة',
          cancelLabel: 'تعديل الاسم',
          icon: Icons.info_outline,
        );
        if (!proceed || !mounted) return;
        setState(() => _saving = true);
      }
    }

    final customer = Customer(
      id:         widget.customer?.id,
      name:       name,
      gsm:        _gsmCtrl.text.trim().isEmpty ? null : _gsmCtrl.text.trim(),
      gId:        _selectedGroupId,
      cusTypeId:  _selectedTypeId,
      notes:      _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      isArchived: _isArchived,
    );

    try {
      if (widget.customer == null) {
        final newId = await repo.insert(customer);
        if (!mounted) return;
        HapticFeedback.mediumImpact();
        Navigator.pop(context, customer.copyWith(id: newId));
        return;
      } else {
        await repo.update(customer);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppSnackBar.error(context, 'تعذر حفظ العميل');
      return;
    }

    if (!mounted) return;
    HapticFeedback.mediumImpact();
    Navigator.pop(context, true);
  }

  Future<void> _deleteCustomer() async {
    final id = widget.customer?.id;
    if (id == null) return;

    final confirm = await AppDialog.confirm(
      context,
      title: 'حذف العميل',
      message: 'هل تريد حذف العميل نهائياً؟ سيتم حذف بياناته ولا يمكن التراجع.',
      confirmLabel: 'حذف',
      destructive: true,
    );

    if (!confirm) return;
    if (!mounted) return;

    HapticFeedback.heavyImpact();
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
      if (hasTx) {
        AppSnackBar.warning(
            context, 'لا يمكن حذف العميل لأنه يملك حركات. احذف الحركات أولاً.');
      } else {
        AppSnackBar.error(context, 'تعذر حذف العميل');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppSnackBar.error(context, 'تعذر حذف العميل');
    }
  }

  Future<bool> _confirmDiscard() async {
    return AppDialog.confirm(
      context,
      title: 'تجاهل التغييرات؟',
      message: 'لديك تغييرات غير محفوظة. هل تريد المغادرة؟',
      confirmLabel: 'تجاهل',
      cancelLabel: 'تابع التعديل',
      destructive: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.customer != null;
    return PopScope(
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        if (await _confirmDiscard() && mounted) nav.pop();
      },
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          appBar: AppBar(
            title: Text(isEdit ? 'تعديل عميل' : 'إضافة عميل'),
            actions: [
              if (isEdit)
                IconButton(
                  tooltip: 'حذف العميل',
                  onPressed: _saving ? null : _deleteCustomer,
                  icon: const Icon(Icons.delete_outline),
                ),
            ],
          ),
          body: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                // الاسم
                AppTextField(
                  controller: _nameCtrl,
                  label: 'الاسم',
                  icon: Icons.person,
                  required: true,
                  requiredMessage: 'الاسم مطلوب',
                  onChanged: (_) => _markDirty(),
                ),
                Gap.h12,
                // رقم الهاتف
                AppTextField(
                  controller: _gsmCtrl,
                  label: 'رقم الهاتف (اختياري)',
                  icon: Icons.phone,
                  keyboardType: TextInputType.phone,
                  onChanged: (_) => _markDirty(),
                ),
                Gap.h12,
                // المجموعة
                AppDropdownField<int?>(
                  value: _groups.any((g) => g.id == _selectedGroupId)
                      ? _selectedGroupId
                      : null,
                  label: 'المجموعة (اختياري)',
                  icon: Icons.group_work_outlined,
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
                  onChanged: (v) {
                    setState(() => _selectedGroupId = v);
                    _markDirty();
                  },
                ),
                Gap.h12,
                // الملاحظات
                AppTextField(
                  controller: _notesCtrl,
                  label: 'ملاحظات (اختياري)',
                  icon: Icons.notes_outlined,
                  maxLines: 3,
                  onChanged: (_) => _markDirty(),
                ),
                Gap.h12,
                // النوع
                AppDropdownField<int?>(
                  value: _types.any((t) => t.id == _selectedTypeId)
                      ? _selectedTypeId
                      : null,
                  label: 'النوع (اختياري)',
                  icon: Icons.category_outlined,
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
                  onChanged: (v) {
                    setState(() => _selectedTypeId = v);
                    _markDirty();
                  },
                ),
                // أرشفة (في وضع التعديل فقط)
                if (widget.customer != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.archive_outlined),
                    title: const Text('أرشفة العميل'),
                    subtitle: const Text('يُخفى عن القوائم الرئيسية'),
                    value: _isArchived,
                    onChanged: (v) {
                      setState(() => _isArchived = v);
                      _markDirty();
                    },
                  ),
                ],
                const SizedBox(height: AppSpacing.xxl),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const AppLoading.inline()
                        : Text(isEdit ? 'حفظ التعديلات' : 'إضافة العميل'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

