import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/typography_extensions.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/localization/date_formatter.dart';
import '../../../core/widgets/common_widgets.dart';
import '../data/finance_repository.dart';
import '../models/finance_models.dart';

final paymentSearchQueryProvider = StateProvider<String>((ref) => '');
final paymentMethodFilterProvider = StateProvider<PaymentMethod?>((ref) => null);
final paymentCurrentPageProvider = StateProvider<int>((ref) => 1);
final paymentItemsPerPageProvider = StateProvider<int>((ref) => 15);

final filteredPaymentsProvider = Provider<AsyncValue<List<PaymentModel>>>((ref) {
  final paymentsAsync = ref.watch(paymentsProvider);
  final searchQuery = ref.watch(paymentSearchQueryProvider).toLowerCase();
  final methodFilter = ref.watch(paymentMethodFilterProvider);

  return paymentsAsync.whenData((payments) {
    return payments.where((p) {
      final matchesSearch = p.invoiceNumber.toLowerCase().contains(searchQuery) ||
          (p.reference?.toLowerCase().contains(searchQuery) ?? false);
      final matchesMethod = methodFilter == null || p.method == methodFilter;
      return matchesSearch && matchesMethod;
    }).toList();
  });
});

class PaymentsScreen extends ConsumerWidget {
  const PaymentsScreen({super.key});

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
                child: const _PaymentsFiltersBar(),
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
                    child: _PaymentsView(isMobile: isMobile),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(vertical: isMobile ? 4 : 8, horizontal: 16),
                child: const _PaymentsPaginationFooter(),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PaymentsView extends ConsumerWidget {
  const _PaymentsView({required this.isMobile});
  final bool isMobile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsAsync = ref.watch(filteredPaymentsProvider);
    final currentPage = ref.watch(paymentCurrentPageProvider);
    final itemsPerPage = ref.watch(paymentItemsPerPageProvider);

    return paymentsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
      data: (payments) {
        if (payments.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.payments_rounded,
            title: 'no_data',
            message: 'try_adjusting_filters',
          );
        }
        
        final startIndex = (currentPage - 1) * itemsPerPage;
        final endIndex = (startIndex + itemsPerPage).clamp(0, payments.length);
        final pagePayments = payments.sublist(startIndex, endIndex);

        if (isMobile) {
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: pagePayments.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) => _PaymentCard(
              payment: pagePayments[index],
            ),
          );
        }

        return Column(
          children: [
            const _TableHeader(),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(top: 4),
                itemCount: pagePayments.length,
                itemBuilder: (context, index) => _TableRow(
                  payment: pagePayments[index],
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
        border: Border(bottom: BorderSide(color: context.borderColor, width: 1)),
      ),
      child: Row(
        children: [
          _buildHeaderCell(context, '#', width: 60, isCentered: true, hasDivider: true),
          const SizedBox(width: 12),
          _buildHeaderCell(context, 'invoice'.tr(ref), flex: 2, icon: Icons.receipt_long_rounded),
          const SizedBox(width: 12),
          _buildHeaderCell(context, 'date'.tr(ref), flex: 2, icon: Icons.calendar_today_rounded),
          const SizedBox(width: 12),
          _buildHeaderCell(context, 'method'.tr(ref), flex: 2, icon: Icons.payments_rounded),
          const SizedBox(width: 12),
          _buildHeaderCell(context, 'amount'.tr(ref), flex: 2, icon: Icons.attach_money_rounded),
          const SizedBox(width: 12),
          _buildHeaderCell(context, 'reference'.tr(ref), flex: 2),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(BuildContext context, String label, {int? flex, double? width, IconData? icon, bool isCentered = false, bool hasDivider = false}) {
    final child = Row(
      children: [
        Expanded(
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
        if (hasDivider)
          Container(
            height: 20, width: 1,
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
  const _TableRow({required this.payment, required this.index});
  final PaymentModel payment;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: index % 2 == 0 ? context.surfaceColor : context.appTheme.surfaceSubtle.withValues(alpha: 0.2),
        border: Border(bottom: BorderSide(color: context.borderColor, width: 1)),
      ),
      child: Material(
        color: AppColors.transparent,
        child: InkWell(
          onTap: () {},
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
                        height: 24, width: 1,
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        color: context.borderColor,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: Text(payment.invoiceNumber, style: context.titleSmall?.bold)),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: Text(payment.paymentDate.toFullDate(), style: context.bodyMedium)),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: Text(payment.method.label, style: context.bodyMedium?.medium)),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: Text(formatCurrency(payment.amount), style: context.titleSmall?.extraBold.withColor(AppColors.success))),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: Text(payment.reference ?? '-', style: context.bodyMedium?.withColor(context.onSurfaceVariant), overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PaymentsFiltersBar extends ConsumerWidget {
  const _PaymentsFiltersBar();

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
                hint: 'search_payments_hint'.tr(ref),
                icon: Icons.search_rounded,
                onChanged: (v) {
                  ref.read(paymentSearchQueryProvider.notifier).state = v;
                  ref.read(paymentCurrentPageProvider.notifier).state = 1;
                },
              ),
              const SizedBox(height: 8),
              _buildMethodDropdown(context, ref, height: 44),
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
                  hint: 'search_payments_hint'.tr(ref),
                  icon: Icons.search_rounded,
                  style: context.labelMedium?.bold,
                  onChanged: (v) {
                    ref.read(paymentSearchQueryProvider.notifier).state = v;
                    ref.read(paymentCurrentPageProvider.notifier).state = 1;
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: _buildMethodDropdown(context, ref, height: 48),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMethodDropdown(BuildContext context, WidgetRef ref, {double height = 44}) {
    final selectedMethod = ref.watch(paymentMethodFilterProvider);
    
    return _FilterMenu<PaymentMethod?>(
      label: selectedMethod?.label ?? 'method'.tr(ref),
      icon: Icons.payments_rounded,
      value: selectedMethod,
      items: [
        _FilterMenuItem(value: null, label: 'all_methods'.tr(ref)),
        ...PaymentMethod.values.map((m) => _FilterMenuItem(value: m, label: m.label)),
      ],
      onSelected: (v) {
        ref.read(paymentMethodFilterProvider.notifier).state = v;
        ref.read(paymentCurrentPageProvider.notifier).state = 1;
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

class _PaymentsPaginationFooter extends ConsumerWidget {
  const _PaymentsPaginationFooter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsAsync = ref.watch(filteredPaymentsProvider);
    final currentPage = ref.watch(paymentCurrentPageProvider);
    final itemsPerPage = ref.watch(paymentItemsPerPageProvider);

    return paymentsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (err, stack) => const SizedBox.shrink(),
      data: (payments) {
        final totalPages = (payments.length / itemsPerPage).ceil();
        return PaginationFooter(
          currentPage: currentPage,
          totalPages: totalPages,
          onPageChanged: (page) => ref.read(paymentCurrentPageProvider.notifier).state = page,
        );
      },
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.payment});
  final PaymentModel payment;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor, 
        borderRadius: BorderRadius.circular(16), 
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
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(payment.invoiceNumber, style: context.titleMedium?.bold),
              Text(formatCurrency(payment.amount), style: context.titleMedium?.bold.withColor(AppColors.success)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(payment.paymentDate.toFullDate(), style: context.bodySmall?.withColor(context.onSurfaceVariant)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryTeal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  payment.method.label, 
                  style: context.labelSmall?.bold.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
