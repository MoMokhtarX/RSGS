import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/data_refresh_service.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/typography_extensions.dart';
import '../../../core/permissions/user_role.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/localization/date_formatter.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../auth/data/auth_repository.dart';
import '../data/finance_repository.dart';
import '../models/finance_models.dart';

final invoiceSearchQueryProvider = StateProvider<String>((ref) => '');
final invoiceStatusFilterProvider = StateProvider<InvoiceStatus?>((ref) => null);
final invoiceCurrentPageProvider = StateProvider<int>((ref) => 1);
final invoiceItemsPerPageProvider = StateProvider<int>((ref) => 15);

final filteredInvoicesProvider = Provider<AsyncValue<List<InvoiceModel>>>((ref) {
  final invoicesAsync = ref.watch(invoicesProvider);
  final searchQuery = ref.watch(invoiceSearchQueryProvider).toLowerCase();
  final statusFilter = ref.watch(invoiceStatusFilterProvider);

  return invoicesAsync.whenData((invoices) {
    return invoices.where((i) {
      final matchesSearch = i.invoiceNumber.toLowerCase().contains(searchQuery) ||
          i.customerName.toLowerCase().contains(searchQuery);
      final matchesStatus = statusFilter == null || i.status == statusFilter;
      return matchesSearch && matchesStatus;
    }).toList();
  });
});

class InvoicesScreen extends ConsumerWidget {
  const InvoicesScreen({super.key});

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
                child: const _InvoicesFiltersBar(),
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
                    child: _InvoicesView(isMobile: isMobile),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(vertical: isMobile ? 4 : 8, horizontal: 16),
                child: const _InvoicesPaginationFooter(),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _InvoicesView extends ConsumerWidget {
  const _InvoicesView({required this.isMobile});
  final bool isMobile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoicesAsync = ref.watch(filteredInvoicesProvider);
    final currentPage = ref.watch(invoiceCurrentPageProvider);
    final itemsPerPage = ref.watch(invoiceItemsPerPageProvider);

    return invoicesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
      data: (invoices) {
        if (invoices.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.receipt_long_rounded,
            title: 'no_data',
            message: 'try_adjusting_filters',
          );
        }
        
        final startIndex = (currentPage - 1) * itemsPerPage;
        final endIndex = (startIndex + itemsPerPage).clamp(0, invoices.length);
        final pageInvoices = invoices.sublist(startIndex, endIndex);

        if (isMobile) {
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: pageInvoices.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) => _InvoiceCard(
              invoice: pageInvoices[index],
            ),
          );
        }

        return Column(
          children: [
            const _TableHeader(),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(top: 4),
                itemCount: pageInvoices.length,
                itemBuilder: (context, index) => _TableRow(
                  invoice: pageInvoices[index],
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
          _buildHeaderCell(context, 'invoice'.tr(ref), flex: 3, icon: Icons.receipt_long_rounded),
          const SizedBox(width: 12),
          _buildHeaderCell(context, 'customer'.tr(ref), flex: 3, icon: Icons.person_outline_rounded),
          const SizedBox(width: 12),
          _buildHeaderCell(context, 'status'.tr(ref), flex: 2, icon: Icons.flag_outlined),
          const SizedBox(width: 12),
          _buildHeaderCell(context, 'total'.tr(ref), flex: 2, icon: Icons.payments_outlined),
          const SizedBox(width: 12),
          _buildHeaderCell(context, 'remaining'.tr(ref), flex: 2),
          const SizedBox(width: 80),
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
  const _TableRow({required this.invoice, required this.index});
  final InvoiceModel invoice;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canManagePayments = ref.watch(authProvider).user?.role.can(AppPermission.managePayments) ?? false;

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
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(invoice.invoiceNumber, style: context.titleSmall?.bold),
                      Text(invoice.issueDate.toFullDate(), style: context.labelSmall?.withColor(context.onSurfaceVariant)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(flex: 3, child: Text(invoice.customerName, style: context.bodyMedium?.medium)),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: Align(alignment: AlignmentDirectional.centerStart, child: _InvoiceStatusChip(status: invoice.status))),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: Text(formatCurrency(invoice.total), style: context.titleSmall?.extraBold)),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2, 
                  child: Text(
                    formatCurrency(invoice.remaining), 
                    style: context.titleSmall?.extraBold.withColor(invoice.remaining > 0 ? AppColors.error : AppColors.success),
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (canManagePayments && invoice.remaining > 0)
                        ActionButton(
                          icon: Icons.payments_rounded,
                          color: AppColors.primaryTeal,
                          tooltip: 'record_payment'.tr(ref),
                          onPressed: () => _showPaymentDialog(context, ref, invoice),
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
  }
}

class _InvoicesFiltersBar extends ConsumerWidget {
  const _InvoicesFiltersBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canManageInvoices = ref.watch(authProvider).user?.role.can(AppPermission.manageInvoices) ?? false;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 700;
        
        if (isMobile) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _FilterField(
                height: 44,
                hint: 'search_invoices_hint'.tr(ref),
                icon: Icons.search_rounded,
                onChanged: (v) {
                  ref.read(invoiceSearchQueryProvider.notifier).state = v;
                  ref.read(invoiceCurrentPageProvider.notifier).state = 1;
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _buildStatusDropdown(context, ref, height: 44)),
                  if (canManageInvoices) ...[
                    const SizedBox(width: 8),
                    const _AddInvoiceButton(isCompact: true),
                  ],
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
                  hint: 'search_invoices_hint'.tr(ref),
                  icon: Icons.search_rounded,
                  style: context.labelMedium?.bold,
                  onChanged: (v) {
                    ref.read(invoiceSearchQueryProvider.notifier).state = v;
                    ref.read(invoiceCurrentPageProvider.notifier).state = 1;
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: _buildStatusDropdown(context, ref, height: 48),
              ),
              const SizedBox(width: 20),
              if (canManageInvoices) const _AddInvoiceButton(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusDropdown(BuildContext context, WidgetRef ref, {double height = 44}) {
    final selectedStatus = ref.watch(invoiceStatusFilterProvider);
    
    return _FilterMenu<InvoiceStatus?>(
      label: selectedStatus?.label ?? 'status'.tr(ref),
      icon: Icons.flag_outlined,
      value: selectedStatus,
      items: [
        _FilterMenuItem(value: null, label: 'status'.tr(ref)),
        ...InvoiceStatus.values.map((s) => _FilterMenuItem(value: s, label: s.label)),
      ],
      onSelected: (v) {
        ref.read(invoiceStatusFilterProvider.notifier).state = v;
        ref.read(invoiceCurrentPageProvider.notifier).state = 1;
      },
    );
  }
}

class _AddInvoiceButton extends ConsumerWidget {
  const _AddInvoiceButton({this.isCompact = false});
  final bool isCompact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
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
      child: ElevatedButton.icon(
        onPressed: () => _showCreateInvoice(context, ref),
        icon: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.add_rounded, size: 20, color: AppColors.white),
        ),
        label: Text(
          'new_invoice'.tr(ref),
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

  Future<void> _showCreateInvoice(BuildContext context, WidgetRef ref) async {
    final customerId = TextEditingController();
    final description = TextEditingController(text: 'solar_invoice_desc'.tr(ref));
    final amount = TextEditingController();
    final tax = TextEditingController(text: '0');

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
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
                  Text('new_invoice'.tr(ref), style: context.headlineSmall?.bold),
                  IconButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    icon: const Icon(Icons.close_rounded),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _labeledField(
                context,
                'customer_id'.tr(ref),
                TextFormField(
                  controller: customerId,
                  keyboardType: TextInputType.number,
                  decoration: customInputDecoration(context, '').copyWith(
                    hintText: 'customer_id'.tr(ref),
                    floatingLabelBehavior: FloatingLabelBehavior.never,
                  ),
                ),
                required: true,
              ),
              const SizedBox(height: 16),
              _labeledField(
                context,
                'description'.tr(ref),
                TextFormField(
                  controller: description,
                  decoration: customInputDecoration(context, '').copyWith(
                    hintText: 'description'.tr(ref),
                    floatingLabelBehavior: FloatingLabelBehavior.never,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _labeledField(
                      context,
                      'amount'.tr(ref),
                      TextFormField(
                        controller: amount,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: customInputDecoration(context, '').copyWith(
                          hintText: 'amount'.tr(ref),
                          floatingLabelBehavior: FloatingLabelBehavior.never,
                        ),
                      ),
                      required: true,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _labeledField(
                      context,
                      'tax_amount'.tr(ref),
                      TextFormField(
                        controller: tax,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: customInputDecoration(context, '').copyWith(
                          hintText: 'tax_amount'.tr(ref),
                          floatingLabelBehavior: FloatingLabelBehavior.never,
                        ),
                      ),
                    ),
                  ),
                ],
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
                      child: Text('create'.tr(ref), style: context.titleSmall?.bold.white),
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
    final id = int.tryParse(customerId.text.trim());
    final value = double.tryParse(amount.text.trim());
    final taxValue = double.tryParse(tax.text.trim()) ?? 0;
    if (id == null || value == null || value <= 0 || taxValue < 0) return;
    try {
      await ref.read(financeRepositoryProvider).createInvoice(
        customerId: id,
        tax: taxValue,
        items: [
          {'description': description.text.trim().isEmpty ? 'invoice_item'.tr(ref) : description.text.trim(), 'quantity': 1, 'unit': 'project', 'unitPrice': value, 'sortOrder': 0},
        ],
      );
      DataRefreshCoordinator.refresh(ref);
      ref.invalidate(invoicesProvider);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString()), backgroundColor: AppColors.error));
      }
    }
  }
}

class _InvoicesPaginationFooter extends ConsumerWidget {
  const _InvoicesPaginationFooter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoicesAsync = ref.watch(filteredInvoicesProvider);
    final currentPage = ref.watch(invoiceCurrentPageProvider);
    final itemsPerPage = ref.watch(invoiceItemsPerPageProvider);

    return invoicesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (err, stack) => const SizedBox.shrink(),
      data: (invoices) {
        final totalPages = (invoices.length / itemsPerPage).ceil();
        return PaginationFooter(
          currentPage: currentPage,
          totalPages: totalPages,
          onPageChanged: (page) => ref.read(invoiceCurrentPageProvider.notifier).state = page,
        );
      },
    );
  }
}

class _InvoiceCard extends ConsumerWidget {
  const _InvoiceCard({required this.invoice});
  final InvoiceModel invoice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canManagePayments = ref.watch(authProvider).user?.role.can(AppPermission.managePayments) ?? false;

    return Container(
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(color: AppColors.primaryTeal.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  alignment: Alignment.center,
                  child: const Icon(Icons.receipt_long_rounded, color: AppColors.primaryTeal),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(invoice.invoiceNumber, style: context.titleMedium?.bold), Text(invoice.customerName, style: context.bodySmall?.copyWith(color: context.onSurfaceVariant))]),
                ),
                _InvoiceStatusChip(status: invoice.status),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('total'.tr(ref), style: context.labelSmall), Text(formatCurrency(invoice.total), style: context.titleMedium?.bold)]),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text('remaining'.tr(ref), style: context.labelSmall), Text(formatCurrency(invoice.remaining), style: context.titleMedium?.bold.withColor(invoice.remaining > 0 ? AppColors.error : AppColors.success))]),
              ],
            ),
            if (canManagePayments && invoice.remaining > 0) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(
                      colors: [AppColors.primaryTeal, AppColors.primaryTealDark],
                    ),
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () => _showPaymentDialog(context, ref, invoice),
                    icon: const Icon(Icons.payments_rounded, color: Colors.white),
                    label: Text('record_payment'.tr(ref), style: context.labelMedium?.white),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InvoiceStatusChip extends StatelessWidget {
  const _InvoiceStatusChip({required this.status});
  final InvoiceStatus status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
      child: Text(status.label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }

  Color _statusColor(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.draft: return Colors.grey;
      case InvoiceStatus.issued: return Colors.blue;
      case InvoiceStatus.partiallyPaid: return Colors.orange;
      case InvoiceStatus.paid: return AppColors.success;
      case InvoiceStatus.overdue: return AppColors.error;
      case InvoiceStatus.cancelled: return Colors.red;
    }
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

Future<void> _showPaymentDialog(BuildContext context, WidgetRef ref, InvoiceModel invoice) async {
  final amount = TextEditingController();
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 500,
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
                    '${'record_payment'.tr(ref)} • ${invoice.invoiceNumber}',
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
                  const Icon(Icons.receipt_long_rounded, color: AppColors.primaryTeal),
                  const SizedBox(width: 12),
                  Text(
                    '${'remaining'.tr(ref)}: ${formatCurrency(invoice.remaining)}',
                    style: context.titleSmall?.bold.primary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _labeledField(
              context, 
              'amount'.tr(ref), 
              TextFormField(
                controller: amount, 
                keyboardType: const TextInputType.numberWithOptions(decimal: true), 
                decoration: customInputDecoration(context, '').copyWith(
                  hintText: 'amount'.tr(ref),
                  floatingLabelBehavior: FloatingLabelBehavior.never,
                ),
              ),
              required: true,
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
  );
  if (result != true) return;
  final value = double.tryParse(amount.text.trim());
  if (value == null || value <= 0) return;
  try {
    await ref.read(financeRepositoryProvider).addPayment(invoiceId: invoice.id, amount: value, method: PaymentMethod.cash);
    DataRefreshCoordinator.refresh(ref);
    ref.invalidate(invoicesProvider);
    ref.invalidate(paymentsProvider);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error));
    }
  }
}

// --- Helpers ---

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
