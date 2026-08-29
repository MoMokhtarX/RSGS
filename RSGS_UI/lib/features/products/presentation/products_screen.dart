import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/data_refresh_service.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/typography_extensions.dart';
import '../../auth/data/auth_repository.dart';
import '../../../core/permissions/user_role.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/widgets/common_widgets.dart';
import '../data/products_repository.dart';
import '../models/product_models.dart';

final productSearchQueryProvider = StateProvider<String>((ref) => '');
final productCategoryFilterProvider = StateProvider<ProductCategory?>((ref) => null);
final productActiveOnlyFilterProvider = StateProvider<bool>((ref) => false);
final productCurrentPageProvider = StateProvider<int>((ref) => 1);
final productItemsPerPageProvider = StateProvider<int>((ref) => 15);

final filteredProductsProvider = Provider<AsyncValue<List<ProductComponentModel>>>((ref) {
  final productsAsync = ref.watch(productsProvider);
  final searchQuery = ref.watch(productSearchQueryProvider).toLowerCase();
  final categoryFilter = ref.watch(productCategoryFilterProvider);
  final activeOnly = ref.watch(productActiveOnlyFilterProvider);

  return productsAsync.whenData((products) {
    return products.where((p) {
      final matchesSearch = p.name.toLowerCase().contains(searchQuery) ||
          p.code.toLowerCase().contains(searchQuery) ||
          (p.brand?.toLowerCase().contains(searchQuery) ?? false) ||
          (p.model?.toLowerCase().contains(searchQuery) ?? false);
      final matchesCategory = categoryFilter == null || p.category == categoryFilter;
      final matchesActive = !activeOnly || p.isActive;
      return matchesSearch && matchesCategory && matchesActive;
    }).toList();
  });
});

class ProductsScreen extends ConsumerWidget {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 1100;
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(16, isMobile ? 8 : 10, 16, 0),
                child: const _ProductsFiltersBar(),
              ),
              SizedBox(height: isMobile ? 4 : 6),
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
                    child: _ProductsView(isMobile: isMobile),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(vertical: isMobile ? 4 : 8, horizontal: 16),
                child: const _ProductsPaginationFooter(),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProductsView extends ConsumerWidget {
  const _ProductsView({required this.isMobile});
  final bool isMobile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isMobile) {
      return const _ProductsList();
    }

    return const _ProductsTable();
  }
}

class _ProductsList extends ConsumerWidget {
  const _ProductsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(filteredProductsProvider);
    final currentPage = ref.watch(productCurrentPageProvider);
    final itemsPerPage = ref.watch(productItemsPerPageProvider);

    return productsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('${'error'.tr(ref)}: $err')),
      data: (products) {
        if (products.isEmpty) return const _EmptyProducts();
        
        final totalPages = (products.length / itemsPerPage).ceil();
        final actualPage = currentPage > totalPages ? (totalPages > 0 ? totalPages : 1) : currentPage;
        final startIndex = (actualPage - 1) * itemsPerPage;
        final endIndex = (startIndex + itemsPerPage).clamp(0, products.length);
        
        final pageProducts = products.sublist(startIndex, endIndex);

        return ListView.separated(
          key: const PageStorageKey('products_mobile_list'),
          padding: const EdgeInsets.all(12),
          itemCount: pageProducts.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) => _ProductCard(
            product: pageProducts[index],
          ),
        );
      },
    );
  }
}

class _ProductsTable extends ConsumerWidget {
  const _ProductsTable();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(filteredProductsProvider);
    final currentPage = ref.watch(productCurrentPageProvider);
    final itemsPerPage = ref.watch(productItemsPerPageProvider);

    return productsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('${'error'.tr(ref)}: $err')),
      data: (products) {
        if (products.isEmpty) return const _EmptyProducts();
        
        final totalPages = (products.length / itemsPerPage).ceil();
        final actualPage = currentPage > totalPages ? (totalPages > 0 ? totalPages : 1) : currentPage;
        final startIndex = (actualPage - 1) * itemsPerPage;
        final endIndex = (startIndex + itemsPerPage).clamp(0, products.length);
        
        final pageProducts = products.sublist(startIndex, endIndex);

        return Column(
          children: [
            const _TableHeader(),
            Expanded(
              child: ListView.builder(
                key: const PageStorageKey('products_table_list'),
                padding: const EdgeInsets.only(top: 4),
                itemCount: pageProducts.length,
                itemBuilder: (context, index) => _TableRow(
                  product: pageProducts[index],
                  index: startIndex + index + 1,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TableHeader extends ConsumerWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: context.appTheme.surfaceSubtle,
        border: Border(
          bottom: BorderSide(color: context.borderColor, width: 1),
        ),
      ),
      child: Row(
        children: [
          _buildHeaderCell(context, ref, '#', null, width: 60, isCentered: true, hasDivider: true),
          const SizedBox(width: 12),
          _buildHeaderCell(context, ref, 'product'.tr(ref), Icons.inventory_2_outlined, flex: 3),
          const SizedBox(width: 12),
          _buildHeaderCell(context, ref, 'category'.tr(ref), Icons.category_outlined, flex: 2),
          const SizedBox(width: 12),
          _buildHeaderCell(context, ref, 'unit'.tr(ref), Icons.straighten_rounded, flex: 1),
          const SizedBox(width: 12),
          _buildHeaderCell(context, ref, 'cost'.tr(ref), Icons.payments_outlined, flex: 2),
          const SizedBox(width: 12),
          _buildHeaderCell(context, ref, 'selling'.tr(ref), Icons.sell_outlined, flex: 2),
          const SizedBox(width: 12),
          _buildHeaderCell(context, ref, 'status'.tr(ref), Icons.flag_outlined, flex: 2),
          const SizedBox(width: 80),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(BuildContext context, WidgetRef ref, String label, IconData? icon, {int? flex, double? width, bool isCentered = false, bool hasDivider = false}) {
    final child = Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: isCentered ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                const SizedBox(width: 8),
                if (icon != null) ...[
                  Icon(icon, size: 14, color: context.appTheme.textMuted),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    label.toUpperCase(),
                    style: context.labelSmall?.withWeight(FontWeight.w700).withColor(context.onSurfaceVariant).withLetterSpacing(0.8),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (hasDivider)
          Container(
            height: 20,
            width: 1,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            color: context.borderColor,
          ),
      ],
    );

    if (width != null) return SizedBox(width: width, child: child);
    return Expanded(flex: flex ?? 1, child: child);
  }
}

class _TableRow extends ConsumerWidget {
  const _TableRow({required this.product, required this.index});
  final ProductComponentModel product;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canManage = ref.watch(authProvider).user?.role.can(AppPermission.manageProducts) ?? false;

    return Container(
      decoration: BoxDecoration(
        color: index % 2 == 0 ? context.surfaceColor : context.appTheme.surfaceSubtle.withValues(alpha: 0.2),
        border: Border(
          bottom: BorderSide(color: context.borderColor, width: 1),
        ),
      ),
      child: Material(
        color: AppColors.transparent,
        child: InkWell(
          onTap: () => showProductDialog(context, ref, product: product),
          hoverColor: AppColors.primaryTeal.withValues(alpha: 0.04),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                SizedBox(
                  width: 60,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$index',
                          textAlign: TextAlign.center,
                          style: context.labelSmall?.withWeight(FontWeight.w700).withColor(context.appTheme.textMuted),
                        ),
                      ),
                      Container(
                        height: 24,
                        width: 1,
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        color: context.borderColor,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12), 
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(product.name, style: context.titleSmall?.bold),
                        Text(product.code, style: context.labelSmall?.withColor(context.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Text(product.category.label, style: context.bodyMedium),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: Text(product.unit, style: context.bodyMedium),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Text(formatCurrency(product.costPrice), style: context.bodyMedium),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Text(formatCurrency(product.sellingPrice), style: context.titleSmall?.bold.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: StatusChip(status: product.isActive ? 'active' : 'disabled'),
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (canManage) ...[
                        ActionButton(
                          icon: Icons.edit_rounded,
                          color: AppColors.primaryTeal,
                          tooltip: 'edit'.tr(ref),
                          onPressed: () => showProductDialog(context, ref, product: product),
                        ),
                        const SizedBox(width: 4),
                        ActionButton(
                          icon: product.isActive ? Icons.block_rounded : Icons.check_circle_rounded,
                          color: product.isActive ? AppColors.error : AppColors.success,
                          tooltip: (product.isActive ? 'disable' : 'enable').tr(ref),
                          onPressed: () => _toggle(context, ref, product),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref, ProductComponentModel product) async {
    try {
      await ref.read(productsRepositoryProvider).setActive(product.id, !product.isActive);
      DataRefreshCoordinator.refresh(ref);
      ref.invalidate(productsProvider);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error));
    }
  }
}

class _ProductsFiltersBar extends ConsumerWidget {
  const _ProductsFiltersBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canManage = ref.watch(authProvider).user?.role.can(AppPermission.manageProducts) ?? false;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 700;
        
        if (isMobile) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _FilterField(
                height: 44,
                hint: 'search_products_hint'.tr(ref),
                icon: Icons.search_rounded,
                onChanged: (value) {
                  ref.read(productSearchQueryProvider.notifier).state = value;
                  ref.read(productCurrentPageProvider.notifier).state = 1;
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _buildCategoryDropdown(context, ref, height: 44)),
                ],
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilterChip(
                      label: Text('active_only'.tr(ref)),
                      selected: ref.watch(productActiveOnlyFilterProvider),
                      onSelected: (v) => ref.read(productActiveOnlyFilterProvider.notifier).state = v,
                    ),
                    if (ref.watch(productSearchQueryProvider).isNotEmpty || 
                        ref.watch(productCategoryFilterProvider) != null) ...[
                      const SizedBox(width: 8),
                      const _ClearFiltersButton(),
                    ],
                    if (canManage) ...[
                      const SizedBox(width: 12),
                      const _AddProductButton(isCompact: true),
                    ],
                  ],
                ),
              ),
            ],
          );
        }

        return Container(
          width: double.infinity,
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 20),
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
              Expanded(
                flex: 4,
                child: _FilterField(
                  height: 48,
                  hint: 'search_products_hint'.tr(ref),
                  icon: Icons.search_rounded,
                  style: context.labelMedium?.bold,
                  onChanged: (value) {
                    ref.read(productSearchQueryProvider.notifier).state = value;
                    ref.read(productCurrentPageProvider.notifier).state = 1;
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: _buildCategoryDropdown(context, ref, height: 48),
              ),
              const SizedBox(width: 16),
              FilterChip(
                label: Text('active_only'.tr(ref)),
                selected: ref.watch(productActiveOnlyFilterProvider),
                onSelected: (v) => ref.read(productActiveOnlyFilterProvider.notifier).state = v,
              ),
              if (ref.watch(productSearchQueryProvider).isNotEmpty || 
                  ref.watch(productCategoryFilterProvider) != null) ...[
                const SizedBox(width: 8),
                const _ClearFiltersButton(),
              ],
              const SizedBox(width: 24),
              if (canManage) const _AddProductButton(isCompact: true),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoryDropdown(BuildContext context, WidgetRef ref, {double height = 44}) {
    final selectedCategory = ref.watch(productCategoryFilterProvider);
    
    return _FilterMenu<ProductCategory?>(
      label: selectedCategory?.label ?? 'category'.tr(ref),
      icon: Icons.category_outlined,
      value: selectedCategory,
      items: [
        _DialogMenuItem(value: null, label: 'all_categories'.tr(ref)),
        ...ProductCategory.values.map((c) => _DialogMenuItem(value: c, label: c.label)),
      ],
      onSelected: (v) {
        ref.read(productCategoryFilterProvider.notifier).state = v;
        ref.read(productCurrentPageProvider.notifier).state = 1;
      },
    );
  }
}

class _AddProductButton extends ConsumerWidget {
  const _AddProductButton({this.isCompact = false});
  final bool isCompact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
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
      child: Consumer(
        builder: (context, ref, _) => ElevatedButton.icon(
          onPressed: () => showProductDialog(context, ref),
          icon: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.add_rounded, size: 20, color: AppColors.white),
          ),
          label: Text('add_product'.tr(ref), style: context.labelMedium?.white),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            padding: EdgeInsets.symmetric(horizontal: isCompact ? 16 : 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }
}

class _EmptyProducts extends ConsumerWidget {
  const _EmptyProducts();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        
        return Center(
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 20 : 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(isMobile ? 24 : 40),
                  decoration: BoxDecoration(
                    color: AppColors.primaryTeal.withValues(alpha: 0.04),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primaryTeal.withValues(alpha: 0.08), width: 2),
                  ),
                  child: Icon(
                    Icons.inventory_2_outlined,
                    size: isMobile ? 48 : 80,
                    color: AppColors.primaryTeal.withValues(alpha: 0.4)
                  ),
                ),
                SizedBox(height: isMobile ? 16 : 32),
                Text(
                  'no_data'.tr(ref),
                  style: (isMobile ? context.titleLarge : context.headlineMedium),
                ),
                const SizedBox(height: 8),
                Text(
                  'try_adjusting_filters'.tr(ref),
                  textAlign: TextAlign.center,
                  style: context.bodyMedium?.withColor(context.onSurfaceVariant),
                ),
                SizedBox(height: isMobile ? 24 : 40),
                const _AddProductButton(),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProductCard extends ConsumerWidget {
  const _ProductCard({required this.product});
  final ProductComponentModel product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canManage = ref.watch(authProvider).user?.role.can(AppPermission.manageProducts) ?? false;

    return InkWell(
      onTap: () => showProductDialog(context, ref, product: product),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    product.name,
                    style: context.titleMedium?.bold,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '#${product.code}',
                  style: context.labelSmall?.withColor(context.appTheme.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.category_outlined, size: 14, color: AppColors.primaryTeal),
                const SizedBox(width: 6),
                Text(
                  product.category.label,
                  style: context.titleSmall?.bold,
                ),
                const Spacer(),
                StatusChip(status: product.isActive ? 'active' : 'disabled'),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Selling: ${formatCurrency(product.sellingPrice)}',
                  style: context.titleSmall?.bold.primary,
                ),
                Text(
                  'Unit: ${product.unit}',
                  style: context.labelMedium?.withColor(context.onSurfaceVariant),
                ),
              ],
            ),
            if (canManage) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ActionButton(
                    icon: Icons.edit_rounded,
                    color: AppColors.primaryTeal,
                    tooltip: 'edit'.tr(ref),
                    onPressed: () => showProductDialog(context, ref, product: product),
                  ),
                  const SizedBox(width: 8),
                  ActionButton(
                    icon: product.isActive ? Icons.block_rounded : Icons.check_circle_rounded,
                    color: product.isActive ? AppColors.error : AppColors.success,
                    tooltip: (product.isActive ? 'disable' : 'enable').tr(ref),
                    onPressed: () => _toggle(context, ref, product),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref, ProductComponentModel product) async {
    try {
      await ref.read(productsRepositoryProvider).setActive(product.id, !product.isActive);
      DataRefreshCoordinator.refresh(ref);
      ref.invalidate(productsProvider);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error));
    }
  }
}

class _FilterMenu<T> extends ConsumerStatefulWidget {
  const _FilterMenu({
    required this.label,
    required this.icon,
    required this.items,
    required this.onSelected,
    required this.value,
  });

  final String label;
  final IconData icon;
  final List<_DialogMenuItem<T>> items;
  final ValueChanged<T> onSelected;
  final T value;

  @override
  ConsumerState<_FilterMenu<T>> createState() => _FilterMenuState<T>();
}

class _FilterMenuState<T> extends ConsumerState<_FilterMenu<T>> {
  final MenuController _controller = MenuController();
  bool _isHovered = false;
  bool _isClosing = false;

  void _handleSelection(T value) async {
    setState(() => _isClosing = true);
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) {
      widget.onSelected(value);
      _controller.close();
      setState(() => _isClosing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.value != null;
    final isOpen = _controller.isOpen;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: MenuAnchor(
        controller: _controller,
        alignmentOffset: const Offset(0, 8),
        onClose: () => setState(() => _isClosing = false),
        style: MenuStyle(
          backgroundColor: WidgetStateProperty.all(Colors.transparent),
          elevation: WidgetStateProperty.all(0),
          padding: WidgetStateProperty.all(EdgeInsets.zero),
        ),
        menuChildren: [
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            tween: Tween(begin: 0.0, end: _isClosing ? 0.0 : 1.0),
            builder: (context, value, child) {
              return Opacity(
                opacity: value.clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - value)),
                  child: Transform.scale(
                    scale: 0.95 + (0.05 * value),
                    child: child,
                  ),
                ),
              );
            },
            child: GlassContainer(
              borderRadius: 20,
              blur: 25,
              padding: const EdgeInsets.all(8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 200, maxWidth: 280),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: widget.items.map((item) {
                    return _DialogMenuItemRow<T>(
                      item: item,
                      isActive: widget.value == item.value,
                      onTap: () => _handleSelection(item.value),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
        builder: (context, controller, child) {
          return InkWell(
            onTap: () => controller.isOpen ? controller.close() : controller.open(),
            borderRadius: BorderRadius.circular(14),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              height: 48,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primaryTeal.withValues(alpha: 0.1)
                    : (_isHovered || isOpen) ? AppColors.primaryTeal.withValues(alpha: 0.06) : context.onSurfaceColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: (_isHovered || isOpen) ? AppColors.primaryTeal.withValues(alpha: 0.2) : Colors.transparent,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  AnimatedScale(
                    scale: (_isHovered || isOpen) ? 1.05 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      widget.icon,
                      size: 18,
                      color: isSelected ? AppColors.primaryTeal : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.label,
                      overflow: TextOverflow.ellipsis,
                      style: context.labelMedium?.bold.withColor(
                        isSelected ? AppColors.primaryTeal : AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: isOpen ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: isSelected ? AppColors.primaryTeal : AppColors.textSecondary.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DialogMenuField<T> extends FormField<T> {
  _DialogMenuField({
    super.key,
    super.initialValue,
    required String label,
    required IconData icon,
    required List<_DialogMenuItem<T>> items,
    required void Function(T?) onSelected,
    super.validator,
    bool enabled = true,
  }) : super(
          builder: (FormFieldState<T> state) {
            return _DialogMenuFieldWidget<T>(
              label: label,
              icon: icon,
              items: items,
              value: state.value,
              onSelected: (val) {
                state.didChange(val);
                onSelected(val);
              },
              errorText: state.errorText,
              enabled: enabled,
            );
          },
        );
}

class _DialogMenuItem<T> {
  final T value;
  final String label;
  final Widget? leading;
  _DialogMenuItem({required this.value, required this.label, this.leading});
}

class _DialogMenuFieldWidget<T> extends StatefulWidget {
  const _DialogMenuFieldWidget({
    required this.label,
    required this.icon,
    required this.items,
    required this.onSelected,
    required this.value,
    this.errorText,
    this.enabled = true,
  });

  final String label;
  final IconData icon;
  final List<_DialogMenuItem<T>> items;
  final ValueChanged<T?> onSelected;
  final T? value;
  final String? errorText;
  final bool enabled;

  @override
  State<_DialogMenuFieldWidget<T>> createState() => _DialogMenuFieldWidgetState<T>();
}

class _DialogMenuFieldWidgetState<T> extends State<_DialogMenuFieldWidget<T>> {
  final MenuController _controller = MenuController();
  bool _isHovered = false;
  bool _isClosing = false;

  void _handleSelection(T? value) async {
    setState(() => _isClosing = true);
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) {
      widget.onSelected(value);
      _controller.close();
      setState(() => _isClosing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    _DialogMenuItem<T>? selectedItem;
    for (final item in widget.items) {
      if (item.value == widget.value) {
        selectedItem = item;
        break;
      }
    }
    
    final leading = selectedItem?.leading;

    return MenuAnchor(
      controller: _controller,
      alignmentOffset: const Offset(0, 8),
      onClose: () => setState(() => _isClosing = false),
      style: MenuStyle(
        backgroundColor: WidgetStateProperty.all(Colors.transparent),
        elevation: WidgetStateProperty.all(0),
        padding: WidgetStateProperty.all(EdgeInsets.zero),
      ),
      menuChildren: [
        TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutBack,
          tween: Tween(begin: 0.0, end: _isClosing ? 0.0 : 1.0),
          builder: (context, value, child) {
            return Opacity(
              opacity: value.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, 20 * (1 - value)),
                child: Transform.scale(
                  scale: 0.95 + (0.05 * value),
                  child: child,
                ),
              ),
            );
          },
          child: GlassContainer(
            borderRadius: 20,
            blur: 25,
            padding: const EdgeInsets.all(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 200, maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: widget.items.map((item) {
                  return _DialogMenuItemRow<T>(
                    item: item,
                    isActive: widget.value == item.value,
                    onTap: () => _handleSelection(item.value),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ],
      builder: (context, controller, child) {
        final isOpen = controller.isOpen;
        return MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: InkWell(
            onTap: widget.enabled ? () => isOpen ? controller.close() : controller.open() : null,
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: (_isHovered || isOpen) ? AppColors.primaryTeal.withValues(alpha: 0.05) : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: InputDecorator(
                decoration: customInputDecoration(
                  context,
                  '', 
                  icon: widget.icon,
                ).copyWith(
                  errorText: widget.errorText,
                  enabled: widget.enabled,
                  floatingLabelBehavior: FloatingLabelBehavior.never,
                ),
                isEmpty: widget.value == null,
                child: Row(
                  children: [
                    if (leading != null) ...[
                      leading,
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Text(
                        selectedItem?.label ?? widget.label,
                        style: context.bodyMedium?.withWeight(FontWeight.w600).withColor(
                          widget.value != null ? context.onSurfaceColor : context.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    AnimatedRotation(
                      turns: isOpen ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 20,
                        color: context.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DialogMenuItemRow<T> extends StatefulWidget {
  const _DialogMenuItemRow({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  final _DialogMenuItem<T> item;
  final bool isActive;
  final VoidCallback onTap;

  @override
  State<_DialogMenuItemRow<T>> createState() => _DialogMenuItemRowState<T>();
}

class _DialogMenuItemRowState<T> extends State<_DialogMenuItemRow<T>> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: widget.isActive 
                  ? AppColors.primaryTeal.withValues(alpha: 0.12) 
                  : _isHovered ? AppColors.primaryTeal.withValues(alpha: 0.06) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                if (widget.item.leading != null) ...[
                  AnimatedScale(
                    scale: _isHovered ? 1.1 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: widget.item.leading!,
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    widget.item.label,
                    style: context.labelLarge?.withColor(
                      widget.isActive ? AppColors.primaryTeal : context.onSurfaceColor,
                    ),
                  ),
                ),
                if (widget.isActive)
                  const Icon(Icons.check_circle_rounded, size: 14, color: AppColors.primaryTeal),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ClearFiltersButton extends ConsumerWidget {
  const _ClearFiltersButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasFilters = ref.watch(productCategoryFilterProvider) != null || 
                      ref.watch(productSearchQueryProvider).isNotEmpty;
    if (!hasFilters) return const SizedBox.shrink();

    return Tooltip(
      message: 'clear_filters'.tr(ref),
      child: IconButton(
        onPressed: () {
          ref.read(productCategoryFilterProvider.notifier).state = null;
          ref.read(productSearchQueryProvider.notifier).state = '';
          ref.read(productActiveOnlyFilterProvider.notifier).state = false;
          ref.read(productCurrentPageProvider.notifier).state = 1;
        },
        icon: const Icon(Icons.filter_alt_off_outlined, color: AppColors.error),
      ),
    );
  }
}

class _FilterField extends StatefulWidget {
  const _FilterField({required this.hint, required this.icon, this.onChanged, this.height = 52, this.style});
  final String hint;
  final IconData icon;
  final void Function(String)? onChanged;
  final double height;
  final TextStyle? style;

  @override
  State<_FilterField> createState() => _FilterFieldState();
}

class _FilterFieldState extends State<_FilterField> {
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
        height: widget.height,
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
              widget.icon, 
              size: 20, 
              color: active ? AppColors.primaryTeal : context.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Focus(
                onFocusChange: (focused) => setState(() => _isFocused = focused),
                child: TextField(
                  onChanged: widget.onChanged,
                  style: widget.style ?? context.labelMedium,
                  textAlignVertical: TextAlignVertical.center,
                  decoration: InputDecoration(
                    hintText: widget.hint,
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
            const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }
}


Widget _sectionHeader(BuildContext context, String title, {IconData? icon}) {
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
    decoration: const BoxDecoration(border: Border(left: BorderSide(color: AppColors.primaryTeal, width: 3))),
    child: Row(
      children: [
        if (icon != null) ...[
          Icon(icon, color: AppColors.primaryTeal, size: 16),
          const SizedBox(width: 8),
        ],
        Text(
          title,
          style: context.titleMedium?.bold.primary.withHeight(1.0),
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
        padding: const EdgeInsetsDirectional.only(start: 4, bottom: 4),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: label,
                style: context.labelSmall?.withColor(context.onSurfaceVariant),
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


void showProductDialog(BuildContext context, WidgetRef ref, {ProductComponentModel? product}) async {
  final changed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ProductDialog(product: product),
  );
  if (changed == true) ref.invalidate(productsProvider);
}

class _ProductsPaginationFooter extends ConsumerWidget {
  const _ProductsPaginationFooter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(filteredProductsProvider);
    final currentPage = ref.watch(productCurrentPageProvider);
    final itemsPerPage = ref.watch(productItemsPerPageProvider);

    return productsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (err, stack) => const SizedBox.shrink(),
      data: (products) {
        final totalPages = (products.length / itemsPerPage).ceil();
        return PaginationFooter(
          currentPage: currentPage,
          totalPages: totalPages,
          onPageChanged: (page) => ref.read(productCurrentPageProvider.notifier).state = page,
        );
      },
    );
  }
}

class _ProductDialog extends ConsumerStatefulWidget {
  const _ProductDialog({this.product});
  final ProductComponentModel? product;
  @override
  ConsumerState<_ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends ConsumerState<_ProductDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _code;
  late final TextEditingController _name;
  late final TextEditingController _brand;
  late final TextEditingController _model;
  late final TextEditingController _specification;
  late final TextEditingController _unit;
  late final TextEditingController _origin;
  late final TextEditingController _cost;
  late final TextEditingController _selling;
  late ProductCategory _category;
  late bool _active;
  bool _saving = false;

  bool get isEdit => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _code = TextEditingController(text: p?.code ?? '');
    _name = TextEditingController(text: p?.name ?? '');
    _brand = TextEditingController(text: p?.brand ?? '');
    _model = TextEditingController(text: p?.model ?? '');
    _specification = TextEditingController(text: p?.specification ?? '');
    _unit = TextEditingController(text: p?.unit ?? 'pcs'.tr(ref));
    _origin = TextEditingController(text: p?.countryOfOrigin ?? '');
    _cost = TextEditingController(text: p?.costPrice.toString() ?? '0');
    _selling = TextEditingController(text: p?.sellingPrice.toString() ?? '0');
    _category = p?.category ?? ProductCategory.other;
    _active = p?.isActive ?? true;
  }

  @override
  void dispose() {
    for (final controller in [
      _code,
      _name,
      _brand,
      _model,
      _specification,
      _unit,
      _origin,
      _cost,
      _selling,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 650;
        
        return Dialog(
          backgroundColor: context.surfaceColor,
          insetPadding: EdgeInsets.all(isNarrow ? 12 : 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 800,
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            child: Container(
              padding: EdgeInsets.all(isNarrow ? 16 : 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          isEdit ? 'edit_product'.tr(ref) : 'add_product'.tr(ref),
                          style: (isNarrow ? context.headlineSmall : context.headlineMedium),
                        ),
                      ),
                      if (_saving)
                        const Padding(
                          padding: EdgeInsetsDirectional.only(end: 12),
                          child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                        ),
                      IconButton(
                        onPressed: _saving ? null : () => Navigator.pop(context, false),
                        icon: const Icon(Icons.close),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionHeader(context, 'basic_info'.tr(ref), icon: Icons.inventory_2_outlined),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: context.appTheme.surfaceSubtle,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: context.borderColor),
                              ),
                              child: Column(
                                children: [
                                  if (isNarrow) ...[
                                    _labeledField(context, 'code'.tr(ref), _field(_code, 'code'.tr(ref), enabled: !isEdit, validator: _required), required: true),
                                    const SizedBox(height: 12),
                                    _labeledField(context, 'name'.tr(ref), _field(_name, 'name'.tr(ref), validator: _required), required: true),
                                    const SizedBox(height: 12),
                                    _labeledField(context, 'category'.tr(ref), _buildCategoryDropdownInDialog(context), required: true),
                                  ] else ...[
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(child: _labeledField(context, 'code'.tr(ref), _field(_code, 'code'.tr(ref), enabled: !isEdit, validator: _required), required: true)),
                                        const SizedBox(width: 16),
                                        Expanded(child: _labeledField(context, 'name'.tr(ref), _field(_name, 'name'.tr(ref), validator: _required), required: true)),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    _labeledField(context, 'category'.tr(ref), _buildCategoryDropdownInDialog(context), required: true),
                                  ],
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),
                            _sectionHeader(context, 'specifications'.tr(ref), icon: Icons.straighten_rounded),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: context.appTheme.surfaceSubtle,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: context.borderColor),
                              ),
                              child: Column(
                                children: [
                                  if (isNarrow) ...[
                                    _labeledField(context, 'brand'.tr(ref), _field(_brand, 'brand'.tr(ref))),
                                    const SizedBox(height: 12),
                                    _labeledField(context, 'model'.tr(ref), _field(_model, 'model'.tr(ref))),
                                  ] else ...[
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(child: _labeledField(context, 'brand'.tr(ref), _field(_brand, 'brand'.tr(ref)))),
                                        const SizedBox(width: 16),
                                        Expanded(child: _labeledField(context, 'model'.tr(ref), _field(_model, 'model'.tr(ref)))),
                                      ],
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  _labeledField(context, 'specification'.tr(ref), _field(_specification, 'specification'.tr(ref), maxLines: 3)),
                                  const SizedBox(height: 12),
                                  if (isNarrow) ...[
                                    _labeledField(context, 'unit'.tr(ref), _field(_unit, 'unit'.tr(ref), validator: _required), required: true),
                                    const SizedBox(height: 12),
                                    _labeledField(context, 'country_of_origin'.tr(ref), _field(_origin, 'country_of_origin'.tr(ref))),
                                  ] else ...[
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(child: _labeledField(context, 'unit'.tr(ref), _field(_unit, 'unit'.tr(ref), validator: _required), required: true)),
                                        const SizedBox(width: 16),
                                        Expanded(child: _labeledField(context, 'country_of_origin'.tr(ref), _field(_origin, 'country_of_origin'.tr(ref)))),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),
                            _sectionHeader(context, 'pricing'.tr(ref), icon: Icons.payments_outlined),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: context.appTheme.surfaceSubtle,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: context.borderColor),
                              ),
                              child: Column(
                                children: [
                                  if (isNarrow) ...[
                                    _labeledField(context, 'cost_price'.tr(ref), _field(_cost, 'cost_price'.tr(ref), keyboard: const TextInputType.numberWithOptions(decimal: true), validator: _money), required: true),
                                    const SizedBox(height: 12),
                                    _labeledField(context, 'selling_price'.tr(ref), _field(_selling, 'selling_price'.tr(ref), keyboard: const TextInputType.numberWithOptions(decimal: true), validator: _money), required: true),
                                  ] else ...[
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(child: _labeledField(context, 'cost_price'.tr(ref), _field(_cost, 'cost_price'.tr(ref), keyboard: const TextInputType.numberWithOptions(decimal: true), validator: _money), required: true)),
                                        const SizedBox(width: 16),
                                        Expanded(child: _labeledField(context, 'selling_price'.tr(ref), _field(_selling, 'selling_price'.tr(ref), keyboard: const TextInputType.numberWithOptions(decimal: true), validator: _money), required: true)),
                                      ],
                                    ),
                                  ],
                                  if (isEdit) ...[
                                    const SizedBox(height: 12),
                                    SwitchListTile.adaptive(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text('active'.tr(ref), style: context.labelLarge?.bold),
                                      activeThumbColor: AppColors.primaryTeal,
                                      value: _active,
                                      onChanged: (v) => setState(() => _active = v),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _saving ? null : () => Navigator.pop(context, false),
                        child: Text(
                          'cancel'.tr(ref),
                          style: context.labelLarge?.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        height: 44,
                        width: isNarrow ? 120 : 150,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: _saving ? null : const LinearGradient(
                            colors: [AppColors.primaryTeal, Color(0xFF0D9488)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          color: _saving ? context.borderColor : null,
                          boxShadow: _saving ? null : [
                            BoxShadow(
                              color: AppColors.primaryTeal.withValues(alpha: 0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _saving ? null : _save,
                          child: Text(
                            _saving ? 'saving'.tr(ref) : 'save'.tr(ref),
                            style: context.labelLarge?.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoryDropdownInDialog(BuildContext context) {
    return _DialogMenuField<ProductCategory>(
      initialValue: _category,
      label: 'select_category'.tr(ref),
      icon: Icons.category_outlined,
      items: ProductCategory.values.map((x) => _DialogMenuItem(value: x, label: x.label)).toList(),
      onSelected: (v) {
        if (v != null) setState(() => _category = v);
      },
      validator: (v) => v == null ? 'required'.tr(ref) : null,
      enabled: !_saving,
    );
  }

  String? _required(String? v) => v?.trim().isEmpty ?? true ? 'required'.tr(ref) : null;
  String? _money(String? v) => double.tryParse(v?.trim() ?? '') == null || double.parse(v!.trim()) < 0 ? 'enter_valid_amount'.tr(ref) : null;
  
  Widget _field(TextEditingController c, String label, {bool enabled = true, int maxLines = 1, TextInputType? keyboard, String? Function(String?)? validator}) => TextFormField(
    controller: c, 
    enabled: enabled && !_saving, 
    maxLines: maxLines, 
    keyboardType: keyboard, 
    validator: validator,
    decoration: customInputDecoration(context, '').copyWith(
      hintText: label,
      floatingLabelBehavior: FloatingLabelBehavior.never,
    ),
  );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final cost = double.parse(_cost.text.trim());
    final selling = double.parse(_selling.text.trim());
    if (selling < cost) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selling price cannot be lower than cost price.'))); return; }
    setState(() => _saving = true);
    try {
      final repo = ref.read(productsRepositoryProvider);
      if (isEdit) {
        await repo.update(widget.product!.id, name: _name.text, category: _category, brand: _brand.text, model: _model.text, specification: _specification.text, unit: _unit.text, countryOfOrigin: _origin.text, costPrice: cost, sellingPrice: selling, isActive: _active);
        DataRefreshCoordinator.refresh(ref);
      } else {
        await repo.create(code: _code.text, name: _name.text, category: _category, brand: _brand.text, model: _model.text, specification: _specification.text, unit: _unit.text, countryOfOrigin: _origin.text, costPrice: cost, sellingPrice: selling);
        DataRefreshCoordinator.refresh(ref);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error));
    } finally { if (mounted) setState(() => _saving = false); }
  }
}
