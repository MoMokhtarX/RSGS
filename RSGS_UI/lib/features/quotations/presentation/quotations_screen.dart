import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/typography_extensions.dart';
import '../../../core/permissions/user_role.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../auth/data/auth_repository.dart';
import '../data/quotations_repository.dart';
import '../models/quotation_models.dart';
import '../providers/quotations_provider.dart';

final quotationSearchQueryProvider = StateProvider<String>((ref) => '');
final quotationTypeFilterProvider = StateProvider<QuotationType?>((ref) => null);
final quotationStatusFilterProvider = StateProvider<QuotationStatus?>((ref) => null);
final quotationCurrentPageProvider = StateProvider<int>((ref) => 1);
final quotationItemsPerPageProvider = StateProvider<int>((ref) => 10);
final quotationSortAscendingProvider = StateProvider<bool>((ref) => false);

final filteredQuotationsProvider = Provider<AsyncValue<List<QuotationModel>>>((ref) {
  final quotationsAsync = ref.watch(quotationsProvider);
  final searchQuery = ref.watch(quotationSearchQueryProvider).toLowerCase();
  final typeFilter = ref.watch(quotationTypeFilterProvider);
  final statusFilter = ref.watch(quotationStatusFilterProvider);
  final sortAscending = ref.watch(quotationSortAscendingProvider);

  return quotationsAsync.whenData((quotations) {
    final filtered = quotations.where((q) {
      final matchesSearch = q.quotationNumber.toLowerCase().contains(searchQuery) ||
          (q.systemDescription?.toLowerCase().contains(searchQuery) ?? false);
      final matchesType = typeFilter == null || q.type == typeFilter;
      final matchesStatus = statusFilter == null || q.status == statusFilter;
      return matchesSearch && matchesType && matchesStatus;
    }).toList();

    filtered.sort((a, b) {
      final dateA = a.quotationDate;
      final dateB = b.quotationDate;
      int cmp;
      if (dateA == null && dateB == null) {
        cmp = 0;
      } else if (dateA == null) {
        cmp = 1;
      } else if (dateB == null) {
        cmp = -1;
      } else {
        cmp = dateA.compareTo(dateB);
      }
      return sortAscending ? cmp : -cmp;
    });

    return filtered;
  });
});

class QuotationsScreen extends ConsumerWidget {
  const QuotationsScreen({super.key});

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
                child: const _QuotationsFiltersBar(),
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
                    child: _QuotationsTable(isMobile: isMobile),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(vertical: isMobile ? 4 : 8, horizontal: 16),
                child: const _PaginationFooter(),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _QuotationsTable extends ConsumerWidget {
  const _QuotationsTable({required this.isMobile});
  final bool isMobile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quotationsAsync = ref.watch(filteredQuotationsProvider);
    final currentPage = ref.watch(quotationCurrentPageProvider);
    final itemsPerPage = ref.watch(quotationItemsPerPageProvider);

    return quotationsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('${'error'.tr(ref)}: $err')),
      data: (quotations) {
        if (quotations.isEmpty) return const _EmptyQuotations();
        
        final totalPages = (quotations.length / itemsPerPage).ceil();
        final actualPage = currentPage > totalPages ? (totalPages > 0 ? totalPages : 1) : currentPage;
        final startIndex = (actualPage - 1) * itemsPerPage;
        final endIndex = (startIndex + itemsPerPage).clamp(0, quotations.length);
        
        final pageQuotations = quotations.sublist(startIndex, endIndex);

        if (isMobile) {
          return ListView.separated(
            key: const PageStorageKey('quotations_mobile_list'),
            padding: const EdgeInsets.all(12),
            itemCount: pageQuotations.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              return _QuotationCard(
                quotation: pageQuotations[index],
              );
            },
          );
        }

        return Column(
          children: [
            const _TableHeader(),
            Expanded(
              child: ListView.builder(
                key: const PageStorageKey('quotations_table_list'),
                padding: const EdgeInsets.only(top: 4),
                itemCount: pageQuotations.length,
                itemBuilder: (context, index) {
                  return _TableRow(
                    key: ValueKey('quotation_row_${pageQuotations[index].id}'),
                    quotation: pageQuotations[index],
                    index: startIndex + index + 1,
                  );
                },
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final showCapacity = constraints.maxWidth > 1200;

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
              _buildHeaderCell(context, ref, 'quotation'.tr(ref), Icons.receipt_long_rounded, flex: 3),
              const SizedBox(width: 12),
              _buildHeaderCell(context, ref, 'type'.tr(ref), Icons.category_rounded, flex: 2),
              const SizedBox(width: 12),
              _buildHeaderCell(context, ref, 'status'.tr(ref), Icons.flag_outlined, flex: 2),
              if (showCapacity) ...[
                const SizedBox(width: 12),
                _buildHeaderCell(context, ref, 'capacity'.tr(ref), Icons.bolt_rounded, flex: 2),
              ],
              const SizedBox(width: 12),
              _buildHeaderCell(context, ref, 'total'.tr(ref), Icons.payments_outlined, flex: 2, sortKey: 'total'),
              const SizedBox(width: 80),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeaderCell(BuildContext context, WidgetRef ref, String label, IconData? icon, {int? flex, double? width, String? sortKey, bool isCentered = false, bool hasDivider = false}) {
    final ascending = ref.watch(quotationSortAscendingProvider);
    final isSorted = sortKey != null;

    final child = Row(
      children: [
        Expanded(
          child: Tooltip(
            message: sortKey != null ? 'click_to_sort'.tr(ref) : '',
            child: InkWell(
              onTap: sortKey == null ? null : () {
                ref.read(quotationSortAscendingProvider.notifier).state = !ascending;
              },
              hoverColor: AppColors.primaryTeal.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: isCentered ? MainAxisAlignment.center : MainAxisAlignment.start,
                  children: [
                    const SizedBox(width: 8),
                    if (icon != null) ...[
                      Icon(icon, size: 14, color: isSorted ? AppColors.primaryTeal : context.appTheme.textMuted),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(
                        label.toUpperCase(),
                        style: context.labelSmall?.withWeight(FontWeight.w700).withColor(
                          isSorted ? AppColors.primaryTeal : context.onSurfaceVariant,
                        ).withLetterSpacing(0.8),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isSorted) ...[
                      const SizedBox(width: 2),
                      Icon(
                        ascending ? Icons.arrow_drop_up_rounded : Icons.arrow_drop_down_rounded,
                        size: 14,
                        color: AppColors.primaryTeal,
                      ),
                    ],
                  ],
                ),
              ),
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

    if (width != null) {
      return SizedBox(width: width, child: child);
    }

    return Expanded(
      flex: flex ?? 1,
      child: child,
    );
  }
}

class _TableRow extends ConsumerWidget {
  const _TableRow({super.key, required this.quotation, required this.index});
  final QuotationModel quotation;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showCapacity = constraints.maxWidth > 1200;

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
              onTap: () => context.push('/quotations/${quotation.id}'),
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
                        child: Text(
                          quotation.quotationNumber,
                          style: context.titleSmall?.bold,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Text(
                        quotation.type.labelKey.tr(ref),
                        style: context.titleSmall?.medium,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: _QuotationStatusBadge(status: quotation.status),
                      ),
                    ),
                    if (showCapacity) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: Text(
                          quotation.systemCapacity != null ? '${quotation.systemCapacity} ${quotation.capacityUnit}' : '—',
                          style: context.titleSmall?.bold,
                        ),
                      ),
                    ],
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Text(
                        formatCurrency(quotation.totalPrice),
                        style: context.titleSmall?.bold.primary,
                      ),
                    ),
                    SizedBox(
                      width: 80,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ActionButton(
                            icon: Icons.edit_rounded,
                            color: AppColors.primaryTeal,
                            tooltip: 'edit'.tr(ref),
                            onPressed: () => context.push('/quotations/${quotation.id}/edit'),
                          ),
                          const SizedBox(width: 4),
                          ActionButton(
                            icon: Icons.delete_outline_rounded,
                            color: AppColors.error,
                            tooltip: 'delete'.tr(ref),
                            onPressed: () => _showDeleteConfirmation(context, ref, quotation),
                          ),
                        ],
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

class _QuotationCard extends ConsumerWidget {
  const _QuotationCard({required this.quotation});
  final QuotationModel quotation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () => context.push('/quotations/${quotation.id}'),
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
                    quotation.quotationNumber,
                    style: context.titleMedium?.bold,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _QuotationStatusBadge(status: quotation.status),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.category_rounded, size: 14, color: AppColors.primaryTeal),
                const SizedBox(width: 6),
                Text(
                  quotation.type.labelKey.tr(ref),
                  style: context.titleSmall?.medium,
                ),
                const Spacer(),
                Text(
                  formatCurrency(quotation.totalPrice),
                  style: context.titleSmall?.bold.primary,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  quotation.systemCapacity != null ? '${quotation.systemCapacity} ${quotation.capacityUnit}' : '—',
                  style: context.labelLarge?.bold,
                ),
                Row(
                  children: [
                    ActionButton(
                      icon: Icons.edit_rounded,
                      color: AppColors.primaryTeal,
                      tooltip: 'edit'.tr(ref),
                      onPressed: () => context.push('/quotations/${quotation.id}/edit'),
                    ),
                    const SizedBox(width: 8),
                    ActionButton(
                      icon: Icons.delete_outline_rounded,
                      color: AppColors.error,
                      tooltip: 'delete'.tr(ref),
                      onPressed: () => _showDeleteConfirmation(context, ref, quotation),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuotationsFiltersBar extends ConsumerWidget {
  const _QuotationsFiltersBar();

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
                hint: 'search_quotations_hint'.tr(ref),
                icon: Icons.search_rounded,
                onChanged: (value) {
                  ref.read(quotationSearchQueryProvider.notifier).state = value;
                  ref.read(quotationCurrentPageProvider.notifier).state = 1;
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _buildTypeDropdown(context, ref)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildStatusDropdown(context, ref)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (ref.watch(quotationStatusFilterProvider) != null ||
                      ref.watch(quotationTypeFilterProvider) != null ||
                      ref.watch(quotationSearchQueryProvider).isNotEmpty) ...[
                    const _ClearFiltersButton(),
                    const SizedBox(width: 8),
                  ],
                  const Spacer(),
                  const _AddQuotationButton(isCompact: true),
                ],
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
                  hint: 'search_quotations_hint'.tr(ref),
                  icon: Icons.search_rounded,
                  style: context.labelMedium?.bold,
                  onChanged: (value) {
                    ref.read(quotationSearchQueryProvider.notifier).state = value;
                    ref.read(quotationCurrentPageProvider.notifier).state = 1;
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: _buildTypeDropdown(context, ref),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: _buildStatusDropdown(context, ref),
              ),
              if (ref.watch(quotationStatusFilterProvider) != null ||
                  ref.watch(quotationTypeFilterProvider) != null ||
                  ref.watch(quotationSearchQueryProvider).isNotEmpty) ...[
                const SizedBox(width: 8),
                const _ClearFiltersButton(),
              ],
              const SizedBox(width: 20),
              const _AddQuotationButton(isCompact: true),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusDropdown(BuildContext context, WidgetRef ref) {
    final selectedStatus = ref.watch(quotationStatusFilterProvider);
    
    return _FilterMenu<QuotationStatus?>(
      label: selectedStatus?.labelKey.tr(ref) ?? 'status'.tr(ref),
      icon: Icons.flag_outlined,
      value: selectedStatus,
      items: [
        _FilterMenuItem(value: null, label: 'all_statuses'.tr(ref)),
        ...QuotationStatus.values.map((s) => _FilterMenuItem(value: s, label: s.labelKey.tr(ref))),
      ],
      onSelected: (v) {
        ref.read(quotationStatusFilterProvider.notifier).state = v;
        ref.read(quotationCurrentPageProvider.notifier).state = 1;
      },
    );
  }

  Widget _buildTypeDropdown(BuildContext context, WidgetRef ref) {
    final selectedType = ref.watch(quotationTypeFilterProvider);
    
    return _FilterMenu<QuotationType?>(
      label: selectedType?.labelKey.tr(ref) ?? 'type'.tr(ref),
      icon: Icons.category_rounded,
      value: selectedType,
      items: [
        _FilterMenuItem(value: null, label: 'all_types'.tr(ref)),
        ...QuotationType.values.map((t) => _FilterMenuItem(value: t, label: t.labelKey.tr(ref))),
      ],
      onSelected: (v) {
        ref.read(quotationTypeFilterProvider.notifier).state = v;
        ref.read(quotationCurrentPageProvider.notifier).state = 1;
      },
    );
  }
}

class _FilterMenuItem<T> {
  final T value;
  final String label;
  _FilterMenuItem({required this.value, required this.label});
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
  final List<_FilterMenuItem<T>> items;
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
                    return _FilterMenuItemRow<T>(
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

class _FilterMenuItemRow<T> extends StatefulWidget {
  const _FilterMenuItemRow({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  final _FilterMenuItem<T> item;
  final bool isActive;
  final VoidCallback onTap;

  @override
  State<_FilterMenuItemRow<T>> createState() => _FilterMenuItemRowState<T>();
}

class _FilterMenuItemRowState<T> extends State<_FilterMenuItemRow<T>> {
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
    final hasFilters = ref.watch(quotationStatusFilterProvider) != null || 
                      ref.watch(quotationTypeFilterProvider) != null || 
                      ref.watch(quotationSearchQueryProvider).isNotEmpty;
    if (!hasFilters) return const SizedBox.shrink();

    return Tooltip(
      message: 'clear_filters'.tr(ref),
      child: IconButton(
        onPressed: () => _clear(ref),
        icon: const Icon(Icons.filter_alt_off_outlined, color: AppColors.error),
      ),
    );
  }

  void _clear(WidgetRef ref) {
    ref.read(quotationStatusFilterProvider.notifier).state = null;
    ref.read(quotationTypeFilterProvider.notifier).state = null;
    ref.read(quotationSearchQueryProvider.notifier).state = '';
    ref.read(quotationCurrentPageProvider.notifier).state = 1;
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

class _PaginationFooter extends ConsumerWidget {
  const _PaginationFooter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quotationsAsync = ref.watch(filteredQuotationsProvider);
    final currentPage = ref.watch(quotationCurrentPageProvider);
    final itemsPerPage = ref.watch(quotationItemsPerPageProvider);

    return quotationsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (err, stack) => const SizedBox.shrink(),
      data: (quotations) {
        final totalPages = (quotations.length / itemsPerPage).ceil();
        return PaginationFooter(
          currentPage: currentPage,
          totalPages: totalPages,
          onPageChanged: (page) => ref.read(quotationCurrentPageProvider.notifier).state = page,
        );
      },
    );
  }
}

class _AddQuotationButton extends ConsumerWidget {
  const _AddQuotationButton({this.isCompact = false});
  final bool isCompact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentUserProvider)?.role;
    final canManage = role == UserRole.admin || role == UserRole.manager || role == UserRole.sales;
    if (!canManage) return const SizedBox.shrink();

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
      child: ElevatedButton.icon(
        onPressed: () => context.push('/quotations/new'),
        icon: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.add_rounded, size: 20, color: AppColors.white),
        ),
        label: Text(
          'new_quotation'.tr(ref),
          style: context.labelMedium?.white,
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: EdgeInsets.symmetric(horizontal: isCompact ? 16 : 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}


class _EmptyQuotations extends ConsumerWidget {
  const _EmptyQuotations();

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
                    Icons.request_quote_outlined,
                    size: isMobile ? 48 : 80,
                    color: AppColors.primaryTeal.withValues(alpha: 0.4)
                  ),
                ),
                SizedBox(height: isMobile ? 16 : 32),
                Text(
                  'no_quotations_found'.tr(ref),
                  style: (isMobile ? context.titleLarge : context.headlineMedium),
                ),
                const SizedBox(height: 8),
                Text(
                  'try_adjusting_filters'.tr(ref),
                  textAlign: TextAlign.center,
                  style: context.bodyMedium?.withColor(context.onSurfaceVariant),
                ),
                SizedBox(height: isMobile ? 24 : 40),
                const _AddQuotationButton(),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _QuotationStatusBadge extends ConsumerWidget {
  const _QuotationStatusBadge({required this.status});
  final QuotationStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Color color = AppColors.textSecondary;
    switch (status) {
      case QuotationStatus.draft: color = Colors.grey; break;
      case QuotationStatus.sent: color = AppColors.info; break;
      case QuotationStatus.approved: color = AppColors.success; break;
      case QuotationStatus.rejected: color = AppColors.error; break;
      case QuotationStatus.expired: color = Colors.orange; break;
    }

    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.12), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PulseDot(color: color),
          const SizedBox(width: 6),
          Text(
            status.labelKey.tr(ref),
            style: context.labelSmall?.withColor(color).withSize(10),
          ),
        ],
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot({required this.color});
  final Color color;

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: 0.6 + (0.4 * _controller.value)),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}

Future<void> _showDeleteConfirmation(BuildContext context, WidgetRef ref, QuotationModel quotation) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('delete'.tr(ref), style: context.titleLarge?.bold.withColor(context.errorColor)),
      content: Text('${'delete'.tr(ref)} ${quotation.quotationNumber}?', style: context.bodyLarge),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('cancel'.tr(ref), style: context.labelLarge?.withColor(context.onSurfaceVariant))),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          child: Text('delete'.tr(ref), style: context.labelLarge?.white),
        ),
      ],
    ),
  );

  if (confirmed == true) {
    try {
      await ref.read(quotationsRepositoryProvider).deleteQuotation(quotation.id);
      ref.invalidate(quotationsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error));
      }
    }
  }
}
