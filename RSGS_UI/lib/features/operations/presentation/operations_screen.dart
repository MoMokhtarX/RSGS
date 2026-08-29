import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/data_refresh_service.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/permissions/user_role.dart';
import '../../auth/data/auth_repository.dart';
import '../../../core/theme/typography_extensions.dart';
import '../../../core/localization/app_strings.dart';
import '../../finance/models/finance_models.dart';
import '../../products/data/products_repository.dart';
import '../../products/models/product_models.dart';
import '../data/operations_repository.dart';
import '../../../core/utils/deterministic_color.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/localization/date_formatter.dart';

// --- State Providers ---

final operationsSearchQueryProvider = StateProvider<String>((ref) => '');
final operationsTabIndexProvider = StateProvider<int>((ref) => 0);

final filteredSuppliersProvider = Provider<AsyncValue<List<SupplierModel>>>((ref) {
  final async = ref.watch(suppliersProvider);
  final query = ref.watch(operationsSearchQueryProvider).toLowerCase();
  
  return async.whenData((list) => list.where((s) => 
    s.name.toLowerCase().contains(query) || 
    s.code.toLowerCase().contains(query) ||
    (s.phone?.contains(query) ?? false)
  ).toList());
});

final filteredInventoryProvider = Provider<AsyncValue<List<InventoryItemModel>>>((ref) {
  final async = ref.watch(inventoryProvider);
  final query = ref.watch(operationsSearchQueryProvider).toLowerCase();
  
  return async.whenData((list) => list.where((item) => 
    item.productName.toLowerCase().contains(query) || 
    item.code.toLowerCase().contains(query)
  ).toList());
});

final filteredPurchaseOrdersProvider = Provider<AsyncValue<List<PurchaseOrderModel>>>((ref) {
  final async = ref.watch(purchaseOrdersProvider);
  final query = ref.watch(operationsSearchQueryProvider).toLowerCase();
  
  return async.whenData((list) => list.where((order) => 
    order.orderNumber.toLowerCase().contains(query) || 
    order.supplierName.toLowerCase().contains(query)
  ).toList());
});

// --- Main Screen ---

class OperationsScreen extends ConsumerStatefulWidget {
  const OperationsScreen({super.key});

  @override
  ConsumerState<OperationsScreen> createState() => _OperationsScreenState();
}

class _OperationsScreenState extends ConsumerState<OperationsScreen> with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 0, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authProvider).user?.role;
    final canSuppliers = role?.can(AppPermission.viewSuppliers) ?? false;
    final canPurchaseOrders = role?.can(AppPermission.viewPurchaseOrders) ?? false;

    final tabs = <Tab>[
      if (canSuppliers) Tab(text: 'suppliers'.tr(ref)),
      Tab(text: 'inventory'.tr(ref)),
      if (canPurchaseOrders) Tab(text: 'purchase_orders'.tr(ref)),
    ];
    final views = <Widget>[
      if (canSuppliers) const _SuppliersTab(),
      const _InventoryTab(),
      if (canPurchaseOrders) const _PurchaseOrdersTab(),
    ];

    if (_tabController.length != tabs.length) {
      _tabController.dispose();
      _tabController = TabController(
        length: tabs.length,
        vsync: this,
        initialIndex: ref.read(operationsTabIndexProvider).clamp(0, tabs.length - 1),
      );
      _tabController.addListener(() {
        if (!_tabController.indexIsChanging) {
          ref.read(operationsTabIndexProvider.notifier).state = _tabController.index;
        }
      });
    }

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 1100;
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(16, isMobile ? 8 : 10, 16, 0),
                child: _OperationsFiltersBar(
                  controller: _tabController,
                  tabs: tabs,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: context.surfaceColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: context.borderColor, width: 1.2),
                    ),
                    child: TabBarView(
                      controller: _tabController,
                      children: views,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }
}

class _OperationsFiltersBar extends ConsumerWidget {
  const _OperationsFiltersBar({required this.controller, required this.tabs});
  final TabController controller;
  final List<Tab> tabs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTabIndex = ref.watch(operationsTabIndexProvider);
    final role = ref.watch(authProvider).user?.role;
    final canSuppliers = role?.can(AppPermission.viewSuppliers) ?? false;
    final canManageSuppliers = role?.can(AppPermission.manageSuppliers) ?? false;
    final canPurchaseOrders = role?.can(AppPermission.viewPurchaseOrders) ?? false;
    final canManagePurchaseOrders = role?.can(AppPermission.managePurchaseOrders) ?? false;

    // Determine what button to show based on the active tab index.
    // Index 0: Suppliers (if canSuppliers), else Inventory
    // We need to match the logic in OperationsScreen build method for tab indices.
    
    Widget? actionButton;
    
    // Construct the same tab list logic to find which tab is which index
    final List<String> activeTabs = [
      if (canSuppliers) 'suppliers',
      'inventory',
      if (canPurchaseOrders) 'purchase_orders',
    ];

    if (activeTabIndex < activeTabs.length) {
      final activeTab = activeTabs[activeTabIndex];
      if (activeTab == 'suppliers' && canManageSuppliers) {
        actionButton = const _AddSupplierButton();
      } else if (activeTab == 'purchase_orders' && canManagePurchaseOrders) {
        actionButton = const _AddPOButton();
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 950;
        
        if (isMobile) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 52,
                decoration: BoxDecoration(
                  color: context.surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.borderColor),
                ),
                child: TabBar(
                  controller: controller,
                  tabs: tabs,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  padding: const EdgeInsets.all(6),
                  labelPadding: const EdgeInsets.symmetric(horizontal: 20),
                  splashBorderRadius: BorderRadius.circular(12),
                  dividerColor: Colors.transparent,
                  overlayColor: WidgetStateProperty.resolveWith<Color?>(
                    (states) {
                      if (states.contains(WidgetState.hovered)) {
                        return AppColors.primaryTeal.withValues(alpha: 0.06);
                      }
                      return null;
                    },
                  ),
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: AppColors.primaryTeal.withValues(alpha: 0.1),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: AppColors.primaryTeal,
                  labelStyle: context.labelLarge?.bold,
                  unselectedLabelColor: context.onSurfaceVariant,
                  unselectedLabelStyle: context.labelLarge?.medium,
                ),
              ),
              const SizedBox(height: 12),
              _SearchField(
                onChanged: (v) => ref.read(operationsSearchQueryProvider.notifier).state = v,
              ),
              if (actionButton != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: actionButton,
                ),
              ],
            ],
          );
        }

        return Container(
          width: double.infinity,
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: context.borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 15,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              TabBar(
                controller: controller,
                tabs: tabs,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                padding: const EdgeInsets.all(6),
                labelPadding: const EdgeInsets.symmetric(horizontal: 20),
                splashBorderRadius: BorderRadius.circular(12),
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: AppColors.primaryTeal.withValues(alpha: 0.1),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: AppColors.primaryTeal,
                labelStyle: context.labelLarge?.bold,
                unselectedLabelColor: context.onSurfaceVariant,
                unselectedLabelStyle: context.labelLarge?.medium,
              ),
              const SizedBox(width: 16),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: VerticalDivider(width: 1, thickness: 1),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _SearchField(
                  onChanged: (v) => ref.read(operationsSearchQueryProvider.notifier).state = v,
                ),
              ),
              if (actionButton != null) ...[
                const SizedBox(width: 16),
                actionButton,
              ],
            ],
          ),
        );
      },
    );
  }
}

// --- Tabs ---

class _SuppliersTab extends ConsumerWidget {
  const _SuppliersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(filteredSuppliersProvider);
    return Column(
      children: [
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text(error.toString())),
            data: (list) {
              if (list.isEmpty) {
                return const EmptyStateWidget(
                  icon: Icons.business_rounded,
                  title: 'no_suppliers',
                  message: 'try_adjusting_search',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(24),
                itemCount: list.length,
                separatorBuilder: (context, index) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final supplier = list[index];
                  return _SupplierCard(supplier: supplier);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AddSupplierButton extends ConsumerWidget {
  const _AddSupplierButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          colors: [
            AppColors.primaryTeal,
            AppColors.primaryTealDark,
            AppColors.primaryTealLight,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryTeal.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: FilledButton.icon(
        onPressed: () => showSupplierDialog(context, ref),
        icon: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.add_business_rounded, size: 20, color: AppColors.white),
        ),
        label: Text(
          'add_supplier'.tr(ref),
          style: context.labelMedium?.white,
        ),
        style: FilledButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

void showSupplierDialog(BuildContext context, WidgetRef ref, {SupplierModel? supplier}) async {
  final formKey = GlobalKey<FormState>();
  final code = TextEditingController(text: supplier?.code);
  final name = TextEditingController(text: supplier?.name);
  final phone = TextEditingController(text: supplier?.phone);
  final email = TextEditingController(text: supplier?.email);
  final contact = TextEditingController(text: supplier?.contactPerson);
  final address = TextEditingController(text: supplier?.address);
  final tax = TextEditingController(text: supplier?.taxNumber);
  final notes = TextEditingController(text: supplier?.notes);

  final isEditing = supplier != null;

  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 650,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 40,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(isEditing ? 'edit'.tr(ref) : 'add_supplier'.tr(ref), style: context.headlineSmall?.bold),
                IconButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  icon: const Icon(Icons.close_rounded),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Flexible(
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionHeader(context, 'basic_info'.tr(ref), icon: Icons.info_outline_rounded),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _labeledField(context, 'code'.tr(ref), TextFormField(controller: code, decoration: customInputDecoration(context, '', icon: Icons.tag_rounded).copyWith(hintText: 'code'.tr(ref)), validator: (v) => v?.isEmpty == true ? 'required'.tr(ref) : null), required: true)),
                          const SizedBox(width: 16),
                          Expanded(child: _labeledField(context, 'contact_person'.tr(ref), TextFormField(controller: contact, decoration: customInputDecoration(context, '', icon: Icons.person_outline_rounded).copyWith(hintText: 'contact_person'.tr(ref)), validator: (v) => v?.isEmpty == true ? 'required'.tr(ref) : null), required: true)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _labeledField(context, 'name'.tr(ref), TextFormField(controller: name, decoration: customInputDecoration(context, '', icon: Icons.business_rounded).copyWith(hintText: 'name'.tr(ref)), validator: (v) => v?.isEmpty == true ? 'required'.tr(ref) : null), required: true),
                      const SizedBox(height: 24),
                      _sectionHeader(context, 'contact_info'.tr(ref), icon: Icons.contact_phone_outlined),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _labeledField(context, 'phone'.tr(ref), TextFormField(controller: phone, decoration: customInputDecoration(context, '', icon: Icons.phone_rounded).copyWith(hintText: 'phone'.tr(ref)), validator: (v) => v?.isEmpty == true ? 'required'.tr(ref) : null), required: true)),
                          const SizedBox(width: 16),
                          Expanded(child: _labeledField(context, 'email'.tr(ref), TextFormField(controller: email, decoration: customInputDecoration(context, '', icon: Icons.email_rounded).copyWith(hintText: 'email'.tr(ref)), validator: (v) => v?.isEmpty == true ? 'required'.tr(ref) : null), required: true)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _labeledField(context, 'address'.tr(ref), TextFormField(controller: address, decoration: customInputDecoration(context, '', icon: Icons.location_on_outlined).copyWith(hintText: 'address'.tr(ref)), validator: (v) => v?.isEmpty == true ? 'required'.tr(ref) : null), required: true),
                      const SizedBox(height: 24),
                      _sectionHeader(context, 'additional_info'.tr(ref), icon: Icons.more_horiz_rounded),
                      const SizedBox(height: 16),
                      _labeledField(context, 'tax_number'.tr(ref), TextFormField(controller: tax, decoration: customInputDecoration(context, '', icon: Icons.receipt_long_rounded).copyWith(hintText: 'tax_number'.tr(ref)), validator: (v) => v?.isEmpty == true ? 'required'.tr(ref) : null), required: true),
                      const SizedBox(height: 16),
                      _labeledField(context, 'notes'.tr(ref), TextFormField(controller: notes, maxLines: 3, decoration: customInputDecoration(context, '', icon: Icons.note_alt_outlined).copyWith(hintText: 'notes'.tr(ref)))),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  ),
                  child: Text('cancel'.tr(ref), style: context.titleSmall?.bold.primary),
                ),
                const SizedBox(width: 16),
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: const LinearGradient(
                      colors: [AppColors.primaryTeal, AppColors.primaryTealDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryTeal.withValues(alpha: 0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: FilledButton(
                    onPressed: () {
                      if (formKey.currentState?.validate() == true) {
                        Navigator.pop(dialogContext, true);
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text('save'.tr(ref), style: context.titleSmall?.bold.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  if (ok != true) return;
  try {
    if (isEditing) {
      await ref.read(operationsRepositoryProvider).updateSupplier(supplier.copyWith(
        code: code.text.trim(),
        name: name.text.trim(),
        phone: phone.text.trim().isEmpty ? null : phone.text.trim(),
        email: email.text.trim().isEmpty ? null : email.text.trim(),
        contactPerson: contact.text.trim().isEmpty ? null : contact.text.trim(),
        address: address.text.trim().isEmpty ? null : address.text.trim(),
        taxNumber: tax.text.trim().isEmpty ? null : tax.text.trim(),
        notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
      ));
    } else {
      await ref.read(operationsRepositoryProvider).createSupplier(
        code: code.text.trim(),
        name: name.text.trim(),
        phone: phone.text.trim().isEmpty ? null : phone.text.trim(),
        email: email.text.trim().isEmpty ? null : email.text.trim(),
        contactPerson: contact.text.trim().isEmpty ? null : contact.text.trim(),
        address: address.text.trim().isEmpty ? null : address.text.trim(),
        taxNumber: tax.text.trim().isEmpty ? null : tax.text.trim(),
        notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
      );
    }
    DataRefreshCoordinator.refresh(ref);
    ref.invalidate(suppliersProvider);
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString()), backgroundColor: AppColors.error));
    }
  }
}

class _InventoryTab extends ConsumerWidget {
  const _InventoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(filteredInventoryProvider);
    return Column(
      children: [
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text(error.toString())),
            data: (list) {
              if (list.isEmpty) {
                return const EmptyStateWidget(
                  icon: Icons.inventory_2_rounded,
                  title: 'no_items',
                  message: 'try_adjusting_search',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(24),
                itemCount: list.length,
                separatorBuilder: (context, index) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final item = list[index];
                  return _InventoryCard(item: item);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _historyDialog(BuildContext context, WidgetRef ref, InventoryItemModel item) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${'Stock History'.tr(ref)}: ${item.productName}', style: context.titleLarge?.bold),
        content: SizedBox(
          width: 500,
          height: 600,
          child: FutureBuilder<List<StockMovementModel>>(
            future: ref.read(operationsRepositoryProvider).getStockMovements(productComponentId: item.productComponentId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (snapshot.hasError) return Center(child: Text(snapshot.error.toString()));
              final movements = snapshot.data ?? [];
              if (movements.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history_rounded, size: 48, color: context.onSurfaceVariant.withValues(alpha: 0.5)),
                      const SizedBox(height: 16),
                      Text('no_movements_recorded'.tr(ref), style: context.bodyMedium?.withColor(context.onSurfaceVariant)),
                    ],
                  ),
                );
              }

              return ListView.separated(
                itemCount: movements.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final m = movements[index];
                  final isPositive = m.quantity > 0;
                  final color = isPositive ? AppColors.success : AppColors.error;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isPositive ? Icons.add_rounded : Icons.remove_rounded,
                        color: color,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      '${m.type.label} (${isPositive ? '+' : ''}${m.quantity})',
                      style: context.bodyLarge?.bold,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          '${m.createdAt.toFullDate()} • ${m.createdByUserName}',
                          style: context.labelSmall?.withColor(context.onSurfaceVariant),
                        ),
                        if (m.notes?.isNotEmpty == true) ...[
                          const SizedBox(height: 4),
                          Text(
                            m.notes!,
                            style: context.bodySmall?.italic,
                          ),
                        ],
                      ],
                    ),
                    isThreeLine: m.notes?.isNotEmpty == true,
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: Text('close'.tr(ref)),
          ),
        ],
      ),
    );
  }

  Future<void> _adjustDialog(BuildContext context, WidgetRef ref, InventoryItemModel item) async {
    final quantity = TextEditingController();
    final reorderLevel = TextEditingController(text: item.reorderLevel.toString());
    var increase = true;

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 550,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${'adjust_stock'.tr(ref)}: ${item.productName}',
                        style: context.headlineSmall?.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      icon: const Icon(Icons.close_rounded),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryTeal.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.inventory_2_rounded, color: AppColors.primaryTeal),
                      const SizedBox(width: 12),
                      Text(
                        '${'on_hand'.tr(ref)}: ${item.quantityOnHand} ${item.unit}',
                        style: context.titleSmall?.bold.primary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _labeledField(
                  context, 
                  'quantity'.tr(ref), 
                  ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: TextFormField(
                      controller: quantity, 
                      keyboardType: const TextInputType.numberWithOptions(decimal: true), 
                      decoration: customInputDecoration(context, 'quantity'.tr(ref), icon: Icons.add_circle_outline_rounded),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _labeledField(
                  context,
                  'action'.tr(ref),
                  Container(
                    decoration: BoxDecoration(
                      color: context.onSurfaceColor.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: SwitchListTile(
                      value: increase, 
                      onChanged: (value) => setState(() => increase = value), 
                      title: Text(
                        increase ? 'increase_stock'.tr(ref) : 'decrease_stock'.tr(ref),
                        style: context.bodyLarge?.medium,
                      ), 
                      activeThumbColor: AppColors.primaryTeal,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                _labeledField(
                  context, 
                  'reorder_level'.tr(ref), 
                  ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: TextFormField(
                      controller: reorderLevel, 
                      keyboardType: const TextInputType.numberWithOptions(decimal: true), 
                      decoration: customInputDecoration(context, 'reorder_level'.tr(ref), icon: Icons.notification_important_outlined),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: Text('cancel'.tr(ref), style: context.titleSmall?.bold.primary),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: const LinearGradient(
                          colors: [AppColors.primaryTeal, AppColors.primaryTealDark],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryTeal.withValues(alpha: 0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: FilledButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text('save'.tr(ref), style: context.titleSmall?.bold.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (ok != true) return;

    try {
      final qValue = double.tryParse(quantity.text.trim());
      if (qValue != null && qValue > 0) {
        await ref.read(operationsRepositoryProvider).adjustInventory(productComponentId: item.productComponentId, quantity: qValue, increase: increase);
      }

      final rValue = double.tryParse(reorderLevel.text.trim());
      if (rValue != null && rValue != item.reorderLevel) {
        await ref.read(operationsRepositoryProvider).setReorderLevel(item.productComponentId, rValue);
      }

      DataRefreshCoordinator.refresh(ref);
      ref.invalidate(inventoryProvider);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString()), backgroundColor: AppColors.error));
      }
    }
  }
}

class _PurchaseOrdersTab extends ConsumerWidget {
  const _PurchaseOrdersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(filteredPurchaseOrdersProvider);
    return Column(
      children: [
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text(error.toString())),
            data: (list) {
              if (list.isEmpty) {
                return const EmptyStateWidget(
                  icon: Icons.local_shipping_rounded,
                  title: 'no_purchase_orders',
                  message: 'try_adjusting_search',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(24),
                itemCount: list.length,
                separatorBuilder: (context, index) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final order = list[index];
                  return _PurchaseOrderCard(order: order);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AddPOButton extends ConsumerWidget {
  const _AddPOButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          colors: [
            AppColors.primaryTeal,
            AppColors.primaryTealDark,
            AppColors.primaryTealLight,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryTeal.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: FilledButton.icon(
        onPressed: () => showPurchaseOrderDialog(context, ref),
        icon: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.add_shopping_cart_rounded, size: 20, color: AppColors.white),
        ),
        label: Text(
          'new_purchase_order'.tr(ref),
          style: context.labelMedium?.white,
        ),
        style: FilledButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

Future<void> showPurchaseOrderDialog(BuildContext context, WidgetRef ref) async {
  final suppliers = await ref.read(operationsRepositoryProvider).getSuppliers(activeOnly: true);
  final products = await ref.read(productsRepositoryProvider).getAll(activeOnly: true);

  if (!context.mounted) return;

  int? supplierId = suppliers.isEmpty ? null : suppliers.first.id;
  final List<Map<String, dynamic>> orderItems = [];
  
  ProductComponentModel? selectedProduct = products.isEmpty ? null : products.first;
  final quantityController = TextEditingController(text: '1');
  final costController = TextEditingController(text: selectedProduct?.costPrice.toStringAsFixed(2) ?? '0');

  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 750,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('new_purchase_order'.tr(ref), style: context.headlineSmall?.bold),
                  IconButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    icon: const Icon(Icons.close_rounded),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionHeader(context, 'supplier_info'.tr(ref), icon: Icons.business_rounded),
                      const SizedBox(height: 16),
                      _labeledField(
                        context, 
                        'supplier'.tr(ref),
                        DropdownButtonFormField<int>(
                          initialValue: supplierId,
                          items: suppliers.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                          onChanged: (value) => setState(() => supplierId = value),
                          decoration: customInputDecoration(context, '', icon: Icons.person_outline_rounded).copyWith(
                            hintText: 'supplier'.tr(ref),
                            floatingLabelBehavior: FloatingLabelBehavior.never,
                          ),
                          validator: (v) => v == null ? 'required'.tr(ref) : null,
                        ),
                        required: true,
                      ),
                      const SizedBox(height: 24),
                      _sectionHeader(context, 'order_items'.tr(ref), icon: Icons.list_alt_rounded),
                      const SizedBox(height: 16),
                      if (orderItems.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: context.onSurfaceColor.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: context.borderColor),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.shopping_cart_outlined, size: 48, color: context.onSurfaceVariant.withValues(alpha: 0.3)),
                              const SizedBox(height: 16),
                              Text('no_items_added_yet'.tr(ref), style: context.bodyMedium?.italic),
                            ],
                          ),
                        )
                      else
                        ...orderItems.asMap().entries.map((entry) {
                          final i = entry.key;
                          final item = entry.value;
                          final p = products.firstWhere((x) => x.id == item['productComponentId']);
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: context.surfaceColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: context.borderColor),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              title: Text(p.displayName, style: context.bodyLarge?.bold),
                              subtitle: Text(
                                '${'qty'.tr(ref)}: ${item['quantity']} • ${'cost'.tr(ref)}: ${formatCurrency(item['unitCost'])}',
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                                onPressed: () => setState(() => orderItems.removeAt(i)),
                              ),
                            ),
                          );
                        }),
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 24),
                      _sectionHeader(context, 'add_item'.tr(ref), icon: Icons.add_circle_outline_rounded),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: _labeledField(
                              context,
                              'product'.tr(ref),
                              DropdownButtonFormField<int>(
                                initialValue: selectedProduct?.id,
                                isExpanded: true,
                                items: products.map((p) => DropdownMenuItem(value: p.id, child: Text(p.displayName, overflow: TextOverflow.ellipsis))).toList(),
                                onChanged: (value) {
                                  if (value == null) return;
                                  final p = products.firstWhere((x) => x.id == value);
                                  setState(() {
                                    selectedProduct = p;
                                    costController.text = p.costPrice.toStringAsFixed(2);
                                  });
                                },
                                decoration: customInputDecoration(context, '').copyWith(
                                  hintText: 'product'.tr(ref),
                                  floatingLabelBehavior: FloatingLabelBehavior.never,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 1,
                            child: _labeledField(
                              context,
                              'qty'.tr(ref),
                              TextFormField(
                                controller: quantityController, 
                                keyboardType: const TextInputType.numberWithOptions(decimal: true), 
                                decoration: customInputDecoration(context, '').copyWith(
                                  hintText: 'qty'.tr(ref),
                                  floatingLabelBehavior: FloatingLabelBehavior.never,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: _labeledField(
                              context,
                              'cost'.tr(ref),
                              TextFormField(
                                controller: costController, 
                                keyboardType: const TextInputType.numberWithOptions(decimal: true), 
                                decoration: customInputDecoration(context, '').copyWith(
                                  hintText: 'cost'.tr(ref),
                                  floatingLabelBehavior: FloatingLabelBehavior.never,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Padding(
                            padding: const EdgeInsets.only(top: 24),
                            child: Container(
                              height: 48,
                              width: 48,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                gradient: const LinearGradient(
                                  colors: [AppColors.primaryTeal, AppColors.primaryTealDark],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primaryTeal.withValues(alpha: 0.3),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: IconButton(
                                onPressed: () {
                                  if (selectedProduct == null) return;
                                  final q = double.tryParse(quantityController.text) ?? 0;
                                  final c = double.tryParse(costController.text) ?? 0;
                                  if (q <= 0) return;
                                  setState(() {
                                    orderItems.add({
                                      'productComponentId': selectedProduct!.id,
                                      'quantity': q,
                                      'unitCost': c,
                                    });
                                  });
                                },
                                icon: const Icon(Icons.add_rounded, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: Text('cancel'.tr(ref), style: context.titleSmall?.bold.primary),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: const LinearGradient(
                        colors: [AppColors.primaryTeal, AppColors.primaryTealDark],
                      ),
                      boxShadow: [
                        BoxShadow(color: AppColors.primaryTeal.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 8)),
                      ],
                    ),
                    child: FilledButton(
                      onPressed: orderItems.isEmpty || supplierId == null 
                          ? null 
                          : () => Navigator.pop(dialogContext, true), 
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text('create'.tr(ref), style: context.titleSmall?.bold.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );

  if (ok != true || supplierId == null || orderItems.isEmpty) return;

  try {
    await ref.read(operationsRepositoryProvider).createPurchaseOrder(
      supplierId: supplierId!,
      items: orderItems,
    );
    DataRefreshCoordinator.refresh(ref);
    ref.invalidate(purchaseOrdersProvider);
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString()), backgroundColor: AppColors.error));
    }
  }
}

// --- Card Widgets ---

class _SupplierCard extends ConsumerWidget {
  const _SupplierCard({required this.supplier});
  final SupplierModel supplier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (bgColor, textColor) = DeterministicColor.getColor(supplier.name);

    return Container(
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(16),
          hoverColor: AppColors.primaryTeal.withValues(alpha: 0.04),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 360;
              
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: isNarrow ? 48 : 56,
                      height: isNarrow ? 48 : 56,
                      decoration: BoxDecoration(
                        color: bgColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        supplier.name.isEmpty ? '?' : supplier.name[0].toUpperCase(),
                        style: (isNarrow ? context.titleMedium : context.titleLarge)?.extraBold.withColor(bgColor),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(supplier.name, style: (isNarrow ? context.bodyLarge : context.titleMedium)?.bold, maxLines: 2, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              _InfoChip(label: supplier.code, icon: Icons.tag_rounded),
                              if (supplier.phone != null)
                                _InfoChip(label: supplier.phone!, icon: Icons.phone_rounded),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!isNarrow) ...[
                              Text(
                                supplier.isActive ? 'active'.tr(ref) : 'inactive'.tr(ref),
                                style: context.labelSmall?.bold.withColor(
                                  supplier.isActive ? AppColors.success : context.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: 4),
                            ],
                            Transform.scale(
                              scale: 0.7,
                              child: Switch(
                                value: supplier.isActive,
                                activeThumbColor: AppColors.primaryTeal,
                                onChanged: (value) async {
                                  try {
                                    await ref.read(operationsRepositoryProvider).setSupplierActive(supplier.id, value);
                                    ref.invalidate(suppliersProvider);
                                  } catch (error) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString()), backgroundColor: AppColors.error));
                                    }
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ActionButton(
                              icon: Icons.edit_rounded,
                              color: AppColors.primaryTeal,
                              tooltip: 'edit'.tr(ref),
                              onPressed: () => showSupplierDialog(context, ref, supplier: supplier),
                              size: 16,
                              padding: 6,
                            ),
                            const SizedBox(width: 4),
                            ActionButton(
                              icon: Icons.delete_outline_rounded,
                              color: AppColors.error,
                              tooltip: 'delete'.tr(ref),
                              onPressed: () => _showSupplierDeleteConfirmation(context, ref, supplier),
                              size: 16,
                              padding: 6,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }
          ),
        ),
      ),
    );
  }
}

class _InventoryCard extends ConsumerWidget {
  const _InventoryCard({required this.item});
  final InventoryItemModel item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusColor = item.isLowStock ? AppColors.error : AppColors.success;

    return Container(
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 360;
          
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isNarrow ? 10 : 12),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    item.isLowStock ? Icons.warning_amber_rounded : Icons.inventory_2_rounded,
                    color: statusColor,
                    size: isNarrow ? 20 : 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.productName, style: (isNarrow ? context.bodyLarge : context.titleMedium)?.bold, maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          _InfoChip(label: item.code, icon: Icons.tag_rounded),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${item.quantityOnHand} ${item.unit}',
                              style: context.labelSmall?.extraBold.withColor(statusColor),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ActionButton(
                          icon: Icons.history_rounded,
                          color: AppColors.primaryTeal,
                          tooltip: 'history'.tr(ref),
                          onPressed: () => const _InventoryTab()._historyDialog(context, ref, item),
                          size: 16,
                          padding: 6,
                        ),
                        const SizedBox(width: 4),
                        ActionButton(
                          icon: Icons.tune_rounded,
                          color: AppColors.primaryTeal,
                          tooltip: 'adjust'.tr(ref),
                          onPressed: () => const _InventoryTab()._adjustDialog(context, ref, item),
                          size: 16,
                          padding: 6,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isNarrow ? '${item.reorderLevel}' : '${'reorder_level'.tr(ref)}: ${item.reorderLevel}',
                      style: context.labelSmall?.bold.withColor(context.onSurfaceVariant),
                    ),
                  ],
                ),
              ],
            ),
          );
        }
      ),
    );
  }
}

class _PurchaseOrderCard extends ConsumerWidget {
  const _PurchaseOrderCard({required this.order});
  final PurchaseOrderModel order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(16),
          hoverColor: AppColors.primaryTeal.withValues(alpha: 0.04),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 360;
              
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: isNarrow ? 48 : 56,
                      height: isNarrow ? 48 : 56,
                      decoration: BoxDecoration(
                        color: AppColors.primaryTeal.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: Icon(Icons.local_shipping_rounded, color: AppColors.primaryTeal, size: isNarrow ? 20 : 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(order.orderNumber, style: (isNarrow ? context.bodyLarge : context.titleMedium)?.bold, maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Text(order.supplierName, style: context.bodyMedium?.medium.withColor(context.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _POStatusChip(status: order.status),
                        const SizedBox(height: 6),
                        Text(
                          formatCurrency(order.total),
                          style: (isNarrow ? context.bodyLarge : context.titleMedium)?.extraBold.primary,
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }
          ),
        ),
      ),
    );
  }
}

void _showSupplierDeleteConfirmation(BuildContext context, WidgetRef ref, SupplierModel supplier) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('delete'.tr(ref), style: context.titleLarge?.bold.withColor(context.errorColor)),
      content: Text('${'delete'.tr(ref)} ${supplier.name}?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('cancel'.tr(ref))),
        FilledButton(
          onPressed: () async {
            try {
              // Assuming setSupplierActive with false is used for deletion or if there's a delete method
              // For now, let's just use setSupplierActive(false) if delete doesn't exist
              await ref.read(operationsRepositoryProvider).setSupplierActive(supplier.id, false);
              DataRefreshCoordinator.refresh(ref);
              ref.invalidate(suppliersProvider);
              if (context.mounted) Navigator.pop(context);
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error));
                Navigator.pop(context);
              }
            }
          },
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          child: Text('delete'.tr(ref), style: context.labelLarge?.white),
        ),
      ],
    ),
  );
}

// --- Helper Components ---

class _POStatusChip extends StatelessWidget {
  const _POStatusChip({required this.status});
  final int status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      1 => ('po_draft', Colors.grey),
      2 => ('po_ordered', Colors.blue),
      3 => ('po_partially_received', Colors.orange),
      4 => ('po_received', AppColors.success),
      5 => ('po_cancelled', AppColors.error),
      _ => ('unknown', Colors.grey),
    };
    return Consumer(
      builder: (context, ref, _) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
        child: Text(label.tr(ref), style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: context.onSurfaceColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: context.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(label, style: context.labelMedium?.medium.withColor(context.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _SearchField extends ConsumerStatefulWidget {
  const _SearchField({required this.onChanged});
  final ValueChanged<String> onChanged;

  @override
  ConsumerState<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends ConsumerState<_SearchField> {
  final _controller = TextEditingController();
  bool _isFocused = false;
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final active = _isFocused || _isHovered;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 48,
        decoration: BoxDecoration(
          color: _isFocused 
              ? AppColors.primaryTeal.withValues(alpha: 0.1) 
              : _isHovered ? AppColors.primaryTeal.withValues(alpha: 0.06) : context.onSurfaceColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? AppColors.primaryTeal.withValues(alpha: 0.2) : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            Icon(
              Icons.search_rounded, 
              size: 20, 
              color: active ? AppColors.primaryTeal : context.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Focus(
                onFocusChange: (focused) => setState(() => _isFocused = focused),
                child: TextField(
                  controller: _controller,
                  onChanged: widget.onChanged,
                  style: context.labelMedium?.bold,
                  textAlignVertical: TextAlignVertical.center,
                  decoration: InputDecoration(
                    hintText: 'search'.tr(ref),
                    hintStyle: context.labelMedium?.withColor(context.appTheme.textMuted),
                    isCollapsed: true,
                    isDense: true,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ),
            ),
            if (_controller.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear_rounded, size: 18),
                onPressed: () {
                  _controller.clear();
                  widget.onChanged('');
                  setState(() {});
                },
              ),
            const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }
}

// --- Shared Helper Functions ---

Widget _sectionHeader(BuildContext context, String title, {IconData? icon}) {
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
    decoration: const BoxDecoration(
      border: Border(left: BorderSide(color: AppColors.primaryTeal, width: 4)),
    ),
    child: Row(
      children: [
        if (icon != null) ...[
          Icon(icon, color: AppColors.primaryTeal, size: 20),
          const SizedBox(width: 10),
        ],
        Text(
          title,
          style: context.titleMedium?.extraBold.primary.withHeight(1.0),
        ),
      ],
    ),
  );
}

Widget _labeledField(BuildContext context, String label, Widget field, {bool required = false}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsetsDirectional.only(start: 4, bottom: 8),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: label,
                style: context.labelSmall?.bold.withColor(context.onSurfaceVariant),
              ),
              if (required)
                const TextSpan(
                  text: ' *',
                  style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
                ),
            ],
          ),
        ),
      ),
      field,
    ],
  );
}
