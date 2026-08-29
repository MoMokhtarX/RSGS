import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/typography_extensions.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/constants/app_colors.dart';
import '../models/product_models.dart';
import 'products_screen.dart';

class PriceListScreen extends ConsumerWidget {
  const PriceListScreen({super.key});

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
                child: const _PriceListFiltersBar(),
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
                    child: _PriceListView(isMobile: isMobile),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(vertical: isMobile ? 4 : 8, horizontal: 16),
                child: const _PriceListPaginationFooter(),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PriceListView extends ConsumerWidget {
  const _PriceListView({required this.isMobile});
  final bool isMobile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isMobile) {
      return const _PriceListItems();
    }
    return const _PriceListTable();
  }
}

class _PriceListItems extends ConsumerWidget {
  const _PriceListItems();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(filteredProductsProvider);
    final currentPage = ref.watch(productCurrentPageProvider);
    final itemsPerPage = ref.watch(productItemsPerPageProvider);

    return productsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('${'error'.tr(ref)}: $err')),
      data: (products) {
        if (products.isEmpty) return const _EmptyPriceList();
        
        final totalPages = (products.length / itemsPerPage).ceil();
        final actualPage = currentPage > totalPages ? (totalPages > 0 ? totalPages : 1) : currentPage;
        final startIndex = (actualPage - 1) * itemsPerPage;
        final endIndex = (startIndex + itemsPerPage).clamp(0, products.length);
        
        final pageProducts = products.sublist(startIndex, endIndex);

        return ListView.separated(
          key: const PageStorageKey('price_list_mobile_list'),
          padding: const EdgeInsets.all(12),
          itemCount: pageProducts.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) => _PriceListCard(product: pageProducts[index]),
        );
      },
    );
  }
}

class _PriceListTable extends ConsumerWidget {
  const _PriceListTable();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(filteredProductsProvider);
    final currentPage = ref.watch(productCurrentPageProvider);
    final itemsPerPage = ref.watch(productItemsPerPageProvider);

    return productsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('${'error'.tr(ref)}: $err')),
      data: (products) {
        if (products.isEmpty) return const _EmptyPriceList();
        
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
                key: const PageStorageKey('price_list_table_list'),
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
          _buildHeaderCell(context, ref, 'selling'.tr(ref), Icons.sell_outlined, flex: 2),
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
    return Container(
      decoration: BoxDecoration(
        color: index % 2 == 0 ? context.surfaceColor : context.appTheme.surfaceSubtle.withValues(alpha: 0.2),
        border: Border(
          bottom: BorderSide(color: context.borderColor, width: 1),
        ),
      ),
      child: Material(
        color: AppColors.transparent,
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
                child: Text(formatCurrency(product.sellingPrice), style: context.titleSmall?.bold.primary),
              ),
              const SizedBox(width: 80),
            ],
          ),
        ),
      ),
    );
  }
}

class _PriceListFiltersBar extends ConsumerWidget {
  const _PriceListFiltersBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              if (ref.watch(productSearchQueryProvider).isNotEmpty || 
                  ref.watch(productCategoryFilterProvider) != null) ...[
                const _ClearFiltersButton(),
              ],
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
              if (ref.watch(productSearchQueryProvider).isNotEmpty || 
                  ref.watch(productCategoryFilterProvider) != null) ...[
                const SizedBox(width: 8),
                const _ClearFiltersButton(),
              ],
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

class _PriceListPaginationFooter extends ConsumerWidget {
  const _PriceListPaginationFooter();

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

class _PriceListCard extends StatelessWidget {
  const _PriceListCard({required this.product});
  final ProductComponentModel product;

  @override
  Widget build(BuildContext context) {
    return Container(
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
        ],
      ),
    );
  }
}

class _EmptyPriceList extends ConsumerWidget {
  const _EmptyPriceList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: AppColors.primaryTeal.withValues(alpha: 0.04),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primaryTeal.withValues(alpha: 0.08), width: 2),
              ),
              child: Icon(
                Icons.inventory_2_outlined,
                size: 80,
                color: AppColors.primaryTeal.withValues(alpha: 0.4)
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'no_data'.tr(ref),
              style: context.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'try_adjusting_filters'.tr(ref),
              textAlign: TextAlign.center,
              style: context.bodyMedium?.withColor(context.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
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

class _DialogMenuItem<T> {
  final T value;
  final String label;
  final Widget? leading;
  _DialogMenuItem({required this.value, required this.label, this.leading});
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
