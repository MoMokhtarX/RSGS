import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/data_refresh_service.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/deterministic_color.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/app_models.dart';
import '../../../core/permissions/user_role.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/localization/language_provider.dart';
import '../../../core/localization/date_formatter.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/theme/typography_extensions.dart';
import '../data/customers_repository.dart';
import '../../auth/data/auth_repository.dart';
import '../../projects/data/projects_repository.dart';
import '../data/customer_import_service.dart';
import '../data/customer_export_service.dart';
import 'package:file_picker/file_picker.dart';

final searchQueryProvider = StateProvider<String>((ref) => '');
final statusFilterProvider = StateProvider<String?>((ref) => null);
final channelFilterProvider = StateProvider<String?>((ref) => null);
final governorateFilterProvider = StateProvider<String?>((ref) => null);
final responsibleFilterProvider = StateProvider<int?>((ref) => null);
final startDateFilterProvider = StateProvider<DateTime?>((ref) => null);
final endDateFilterProvider = StateProvider<DateTime?>((ref) => null);
final currentPageProvider = StateProvider<int>((ref) => 1);
final itemsPerPageProvider = StateProvider<int>((ref) => 10);

final customerSortAscendingProvider = StateProvider<bool>((ref) => true);

final filteredCustomersProvider = Provider<AsyncValue<List<CustomerWithDetails>>>((ref) {
  final customersAsync = ref.watch(customersWithDetailsProvider);
  final searchQuery = ref.watch(searchQueryProvider).toLowerCase();
  final statusFilter = ref.watch(statusFilterProvider);
  final channelFilter = ref.watch(channelFilterProvider);
  final governorateFilter = ref.watch(governorateFilterProvider);
  final responsibleFilter = ref.watch(responsibleFilterProvider);
  final startDate = ref.watch(startDateFilterProvider);
  final endDate = ref.watch(endDateFilterProvider);
  final sortAscending = ref.watch(customerSortAscendingProvider);

  return customersAsync.whenData((customers) {
    final filtered = customers.where((item) {
      final c = item.customer;
      final matchesSearch = c.name.toLowerCase().contains(searchQuery) ||
          c.phone.contains(searchQuery) ||
          (c.email?.toLowerCase().contains(searchQuery) ?? false) ||
          (c.notes?.toLowerCase().contains(searchQuery) ?? false);
      final matchesStatus = statusFilter == null || c.followUpStatus == statusFilter;
      final matchesChannel = channelFilter == null || c.channel == channelFilter;
      final matchesGovernorate = governorateFilter == null || c.governorate == governorateFilter;
      final matchesResponsible = responsibleFilter == null || c.assignedUserId == responsibleFilter;
      
      bool matchesDate = true;
      if (startDate != null && c.inquiryDate != null) {
        matchesDate = matchesDate && (c.inquiryDate!.isAfter(startDate) || DateUtils.isSameDay(c.inquiryDate, startDate));
      }
      if (endDate != null && c.inquiryDate != null) {
        matchesDate = matchesDate && (c.inquiryDate!.isBefore(endDate) || DateUtils.isSameDay(c.inquiryDate, endDate));
      }

      return matchesSearch && matchesStatus && matchesChannel && matchesGovernorate && matchesResponsible && matchesDate;
    }).toList();

    filtered.sort((a, b) {
      final dateA = a.customer.inquiryDate;
      final dateB = b.customer.inquiryDate;
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

class CustomersScreen extends ConsumerWidget {
  const CustomersScreen({super.key});

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
                child: const _FiltersBar(),
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
                    child: _CustomersTable(isMobile: isMobile),
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

class _CustomersTable extends ConsumerWidget {
  const _CustomersTable({required this.isMobile});
  final bool isMobile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customersAsync = ref.watch(filteredCustomersProvider);
    final currentPage = ref.watch(currentPageProvider);
    final itemsPerPage = ref.watch(itemsPerPageProvider);

    return customersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('${'error'.tr(ref)}: $err')),
      data: (customers) {
        if (customers.isEmpty) return const _EmptyCustomers();
        
        final totalPages = (customers.length / itemsPerPage).ceil();
        final actualPage = currentPage > totalPages ? (totalPages > 0 ? totalPages : 1) : currentPage;
        final startIndex = (actualPage - 1) * itemsPerPage;
        final endIndex = (startIndex + itemsPerPage).clamp(0, customers.length);
        
        final pageCustomers = customers.sublist(startIndex, endIndex);

        if (isMobile) {
          return ListView.separated(
            key: const PageStorageKey('customers_mobile_list'),
            padding: const EdgeInsets.all(12),
            itemCount: pageCustomers.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              return _CustomerCard(
                customer: pageCustomers[index].customer,
              );
            },
          );
        }

        return Column(
          children: [
            const _TableHeader(),
            Expanded(
              child: ListView.builder(
                key: const PageStorageKey('customers_table_list'),
                padding: const EdgeInsets.only(top: 4),
                itemCount: pageCustomers.length,
                itemBuilder: (context, index) {
                  return _TableRow(
                    key: ValueKey('customer_row_${pageCustomers[index].customer.id}'),
                    customer: pageCustomers[index].customer,
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
        final showChannel = constraints.maxWidth > 1250;
        final showDate = constraints.maxWidth > 1150;

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
              _buildHeaderCell(context, ref, 'name'.tr(ref), Icons.person_outline_rounded, flex: 3),
              const SizedBox(width: 12),
              _buildHeaderCell(context, ref, 'phone'.tr(ref), Icons.phone_outlined, flex: 2),
              if (showChannel) ...[
                const SizedBox(width: 12),
                _buildHeaderCell(context, ref, 'channel'.tr(ref), Icons.campaign_outlined, flex: 2),
              ],
              if (showDate) ...[
                const SizedBox(width: 12),
                _buildHeaderCell(context, ref, 'inquiry_date'.tr(ref), Icons.calendar_today_outlined, flex: 2, sortKey: 'date'),
              ],
              const SizedBox(width: 12),
              _buildHeaderCell(context, ref, 'status'.tr(ref), Icons.flag_outlined, flex: 2),
              const SizedBox(width: 12),
              _buildHeaderCell(context, ref, 'responsible'.tr(ref), Icons.assignment_ind_outlined, flex: 3),
              const SizedBox(width: 80),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeaderCell(BuildContext context, WidgetRef ref, String label, IconData? icon, {int? flex, double? width, String? sortKey, bool isCentered = false, bool hasDivider = false}) {
    final ascending = ref.watch(customerSortAscendingProvider);
    final isSorted = sortKey != null;

    final child = Row(
      children: [
        Expanded(
          child: Tooltip(
            message: sortKey != null ? 'click_to_sort'.tr(ref) : '',
            child: InkWell(
              onTap: sortKey == null ? null : () {
                ref.read(customerSortAscendingProvider.notifier).state = !ascending;
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
  const _TableRow({super.key, required this.customer, required this.index});
  final CustomerModel customer;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showChannel = constraints.maxWidth > 1250;
        final showDate = constraints.maxWidth > 1150;

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
              onTap: () => context.go('/customers/${customer.id}'),
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
                              '${customer.id}',
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
                          customer.name,
                          style: context.titleSmall?.bold,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Row(
                        children: [
                          const Icon(Icons.phone_enabled_rounded, size: 14, color: AppColors.primaryTeal),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              customer.phone,
                              style: context.titleSmall?.bold,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (showChannel) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: ChannelChip(channel: customer.channel ?? '-'),
                        ),
                      ),
                    ],
                    if (showDate) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: Text(
                          customer.inquiryDate != null ? customer.inquiryDate!.format('date_format'.tr(ref), ref.watch(localeProvider).languageCode) : '-',
                          style: context.labelLarge?.withColor(context.onSurfaceVariant).copyWith(
                            letterSpacing: ref.watch(localeProvider).languageCode == 'ar' ? 1.2 : null,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: _FollowUpBadge(status: customer.followUpStatus ?? 'New'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: _AssignedUserBadge(userId: customer.assignedUserId),
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
                            onPressed: () => showCustomerDialog(context, ref, customer: customer),
                          ),
                          const SizedBox(width: 4),
                          ActionButton(
                            icon: Icons.delete_outline_rounded,
                            color: AppColors.error,
                            tooltip: 'delete'.tr(ref),
                            onPressed: () => _showDeleteConfirmation(context, ref, customer),
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

class _CustomerCard extends ConsumerWidget {
  const _CustomerCard({required this.customer});
  final CustomerModel customer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () => context.go('/customers/${customer.id}'),
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
                    customer.name,
                    style: context.titleMedium?.bold,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '#${customer.id}',
                  style: context.labelSmall?.withColor(context.appTheme.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.phone_enabled_rounded, size: 14, color: AppColors.primaryTeal),
                const SizedBox(width: 6),
                Text(
                  customer.phone,
                  style: context.titleSmall?.bold,
                ),
                const Spacer(),
                ChannelChip(channel: customer.channel ?? '-'),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _FollowUpBadge(status: customer.followUpStatus ?? 'New'),
                Text(
                  customer.inquiryDate != null ? customer.inquiryDate!.format('date_format'.tr(ref), ref.watch(localeProvider).languageCode) : '-',
                  style: context.labelMedium?.withColor(context.onSurfaceVariant).copyWith(
                    letterSpacing: ref.watch(localeProvider).languageCode == 'ar' ? 1.2 : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: _AssignedUserBadge(userId: customer.assignedUserId),
                  ),
                ),
                Row(
                  children: [
                    ActionButton(
                      icon: Icons.edit_rounded,
                      color: AppColors.primaryTeal,
                      tooltip: 'edit'.tr(ref),
                      onPressed: () => showCustomerDialog(context, ref, customer: customer),
                    ),
                    const SizedBox(width: 8),
                    ActionButton(
                      icon: Icons.delete_outline_rounded,
                      color: AppColors.error,
                      tooltip: 'delete'.tr(ref),
                      onPressed: () => _showDeleteConfirmation(context, ref, customer),
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

void showCustomerDialog(BuildContext context, WidgetRef ref, {CustomerModel? customer}) {
  final formKey = GlobalKey<FormState>();

  final nameCtrl = TextEditingController(text: customer?.name);
  final phoneCtrl = TextEditingController(text: customer?.phone);
  final phone2Ctrl = TextEditingController(text: customer?.phone2);
  final emailCtrl = TextEditingController(text: customer?.email);
  final notesCtrl = TextEditingController(text: customer?.notes);

  final firstCallCtrl = TextEditingController(text: customer?.firstCallNotes);
  final secondCallCtrl = TextEditingController(text: customer?.secondCallNotes);
  final thirdCallCtrl = TextEditingController(text: customer?.thirdCallNotes);
  final fourthCallCtrl = TextEditingController(text: customer?.fourthCallNotes);

  DateTime? inquiryDate = customer?.inquiryDate ?? DateTime.now();
  DateTime? action1Date = customer?.firstActionDate;
  DateTime? action2Date = customer?.secondActionDate;
  DateTime? action3Date = customer?.thirdActionDate;
  DateTime? action4Date = customer?.fourthActionDate;

  String? selectedChannel = customer?.channel;
  String? selectedStatus = customer?.followUpStatus;

  if (selectedChannel != null) {
    for (final c in AppConstants.customerChannels) {
      if (c.toLowerCase() == selectedChannel!.toLowerCase()) {
        selectedChannel = c;
        break;
      }
    }
  }
  if (selectedStatus != null) {
    for (final s in AppConstants.customerFollowUpStatuses) {
      if (s.toLowerCase() == selectedStatus!.toLowerCase()) {
        selectedStatus = s;
        break;
      }
    }
  }

  final currentUser = ref.read(currentUserProvider);
  final isAdmin = currentUser?.role == UserRole.admin;
  int? selectedAssignedId = customer?.assignedUserId ?? (isAdmin ? null : currentUser?.id);

  bool isSaving = false;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => Consumer(
        builder: (context, ref, _) {
          final engineers = ref.watch(engineersProvider).value ?? [];

          return LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 650;
              
              return Dialog(
                backgroundColor: context.surfaceColor,
                insetPadding: EdgeInsets.all(isNarrow ? 12 : 24),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 1100,
                    maxHeight: MediaQuery.of(context).size.height * 0.95,
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
                                customer == null ? 'add_customer'.tr(ref) : 'edit_customer'.tr(ref),
                                style: (isNarrow ? context.headlineSmall : context.headlineMedium),
                              ),
                            ),
                            if (isSaving)
                              const Padding(
                                padding: EdgeInsetsDirectional.only(end: 12),
                                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                              ),
                            IconButton(
                              onPressed: isSaving ? null : () => Navigator.pop(context),
                              icon: const Icon(Icons.close),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Flexible(
                          child: SingleChildScrollView(
                            child: Form(
                              key: formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _sectionHeader(context, 'basic_info'.tr(ref), icon: Icons.person_outline_rounded),
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
                                          _labeledField(context, 'name'.tr(ref), TextFormField(controller: nameCtrl, decoration: customInputDecoration(context, 'name'.tr(ref), icon: Icons.badge_outlined), validator: (v) => v == null || v.trim().isEmpty ? 'required'.tr(ref) : null, enabled: !isSaving), required: true),
                                          const SizedBox(height: 12),
                                          _labeledField(context, 'phone'.tr(ref), TextFormField(
                                            controller: phoneCtrl, 
                                            decoration: customInputDecoration(context, 'phone'.tr(ref), icon: Icons.phone_outlined), 
                                            keyboardType: TextInputType.phone,
                                            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(11)],
                                            validator: (v) {
                                              if (v == null || v.trim().isEmpty) return 'required'.tr(ref);
                                              if (v.trim().length != 11) return 'invalid_phone'.tr(ref);
                                              return null;
                                            }, 
                                            enabled: !isSaving
                                          ), required: true),
                                          const SizedBox(height: 12),
                                          _labeledField(context, 'phone2'.tr(ref), TextFormField(
                                            controller: phone2Ctrl, 
                                            decoration: customInputDecoration(context, 'phone2'.tr(ref), icon: Icons.phone_iphone_rounded), 
                                            keyboardType: TextInputType.phone,
                                            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(11)],
                                            validator: (v) {
                                              if (v != null && v.trim().isNotEmpty && v.trim().length != 11) return 'invalid_phone'.tr(ref);
                                              return null;
                                            },
                                            enabled: !isSaving
                                          )),
                                          const SizedBox(height: 12),
                                          _labeledField(context, 'email'.tr(ref), TextFormField(controller: emailCtrl, decoration: customInputDecoration(context, 'email'.tr(ref), icon: Icons.email_outlined), enabled: !isSaving)),
                                        ] else ...[
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Expanded(child: _labeledField(context, 'name'.tr(ref), TextFormField(controller: nameCtrl, decoration: customInputDecoration(context, 'name'.tr(ref), icon: Icons.badge_outlined), validator: (v) => v == null || v.trim().isEmpty ? 'required'.tr(ref) : null, enabled: !isSaving), required: true)),
                                              const SizedBox(width: 16),
                                              Expanded(child: _labeledField(context, 'phone'.tr(ref), TextFormField(
                                                controller: phoneCtrl, 
                                                decoration: customInputDecoration(context, 'phone'.tr(ref), icon: Icons.phone_outlined), 
                                                keyboardType: TextInputType.phone,
                                                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(11)],
                                                validator: (v) {
                                                  if (v == null || v.trim().isEmpty) return 'required'.tr(ref);
                                                  if (v.trim().length != 11) return 'invalid_phone'.tr(ref);
                                                  return null;
                                                },
                                                enabled: !isSaving
                                              ), required: true)),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Expanded(child: _labeledField(context, 'phone2'.tr(ref), TextFormField(
                                                controller: phone2Ctrl, 
                                                decoration: customInputDecoration(context, 'phone2'.tr(ref), icon: Icons.phone_iphone_rounded), 
                                                keyboardType: TextInputType.phone,
                                                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(11)],
                                                validator: (v) {
                                                  if (v != null && v.trim().isNotEmpty && v.trim().length != 11) return 'invalid_phone'.tr(ref);
                                                  return null;
                                                },
                                                enabled: !isSaving
                                              ))),
                                              const SizedBox(width: 16),
                                              Expanded(child: _labeledField(context, 'email'.tr(ref), TextFormField(controller: emailCtrl, decoration: customInputDecoration(context, 'email'.tr(ref), icon: Icons.email_outlined), enabled: !isSaving))),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 20),
                                  _sectionHeader(context, 'lead_tracking'.tr(ref), icon: Icons.track_changes_rounded),
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
                                          _labeledField(context, 'channel'.tr(ref), _buildChannelDropdown(context, ref, selectedChannel, isSaving, (v) => setState(() => selectedChannel = v)), required: true),
                                          const SizedBox(height: 12),
                                          _labeledField(context, 'inquiry_date'.tr(ref), _DatePickerField(label: 'select_date'.tr(ref), selectedDate: inquiryDate, onChanged: (_) {}, enabled: false), required: true),
                                          const SizedBox(height: 12),
                                          _labeledField(context, 'follow_up_status'.tr(ref), _buildStatusDropdown(context, ref, selectedStatus, isSaving, (v) => setState(() => selectedStatus = v)), required: true),
                                          const SizedBox(height: 12),
                                          _labeledField(context, 'responsible_person'.tr(ref), _buildResponsibleDropdown(context, ref, selectedAssignedId, engineers, isAdmin, isSaving, (v) => setState(() => selectedAssignedId = v)), required: true),
                                        ] else ...[
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Expanded(child: _labeledField(context, 'channel'.tr(ref), _buildChannelDropdown(context, ref, selectedChannel, isSaving, (v) => setState(() => selectedChannel = v)), required: true)),
                                              const SizedBox(width: 16),
                                              Expanded(child: _labeledField(context, 'inquiry_date'.tr(ref), _DatePickerField(label: 'select_date'.tr(ref), selectedDate: inquiryDate, onChanged: (_) {}, enabled: false), required: true)),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Expanded(child: _labeledField(context, 'follow_up_status'.tr(ref), _buildStatusDropdown(context, ref, selectedStatus, isSaving, (v) => setState(() => selectedStatus = v)), required: true)),
                                              const SizedBox(width: 16),
                                              Expanded(child: _labeledField(context, 'responsible_person'.tr(ref), _buildResponsibleDropdown(context, ref, selectedAssignedId, engineers, isAdmin, isSaving, (v) => setState(() => selectedAssignedId = v)), required: true)),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 20),
                                  _sectionHeader(context, 'interaction_tracking'.tr(ref), icon: Icons.history_edu_rounded),
                                  const SizedBox(height: 8),
                                  _interactionRow(context, 'first_call'.tr(ref), firstCallCtrl, action1Date, isSaving ? (_) {} : (d) => setState(() => action1Date = d), index: 1, ref: ref, isNarrow: isNarrow),
                                  const SizedBox(height: 8),
                                  _interactionRow(context, 'second_call'.tr(ref), secondCallCtrl, action2Date, isSaving ? (_) {} : (d) => setState(() => action2Date = d), index: 2, ref: ref, isNarrow: isNarrow),
                                  const SizedBox(height: 8),
                                  _interactionRow(context, 'third_call'.tr(ref), thirdCallCtrl, action3Date, isSaving ? (_) {} : (d) => setState(() => action3Date = d), index: 3, ref: ref, isNarrow: isNarrow),
                                  const SizedBox(height: 8),
                                  _interactionRow(context, 'fourth_call'.tr(ref), fourthCallCtrl, action4Date, isSaving ? (_) {} : (d) => setState(() => action4Date = d), index: 4, ref: ref, isNarrow: isNarrow),

                                  const SizedBox(height: 20),
                                  _sectionHeader(context, 'notes'.tr(ref), icon: Icons.note_alt_outlined),
                                  const SizedBox(height: 8),
                                  TextFormField(controller: notesCtrl, decoration: customInputDecoration(context, 'notes'.tr(ref)), maxLines: 3, enabled: !isSaving),
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
                              onPressed: isSaving ? null : () => Navigator.pop(context),
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
                                gradient: isSaving ? null : const LinearGradient(
                                  colors: [AppColors.primaryTeal, Color(0xFF0D9488)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                color: isSaving ? context.borderColor : null,
                                boxShadow: isSaving ? null : [
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
                                onPressed: isSaving ? null : () async {
                                  if (!formKey.currentState!.validate()) return;

                                  setState(() => isSaving = true);

                                  try {
                                    final model = CustomerModel(
                                      id: customer?.id ?? 0,
                                      name: nameCtrl.text.trim(),
                                      phone: phoneCtrl.text.trim(),
                                      phone2: phone2Ctrl.text.trim().isEmpty ? null : phone2Ctrl.text.trim(),
                                      email: emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
                                      notes: notesCtrl.text.trim(),
                                      channel: selectedChannel,
                                      inquiryDate: inquiryDate,
                                      followUpStatus: selectedStatus,
                                      assignedUserId: selectedAssignedId,
                                      firstCallNotes: firstCallCtrl.text.trim(),
                                      firstActionDate: action1Date,
                                      secondCallNotes: secondCallCtrl.text.trim(),
                                      secondActionDate: action2Date,
                                      thirdCallNotes: thirdCallCtrl.text.trim(),
                                      thirdActionDate: action3Date,
                                      fourthCallNotes: fourthCallCtrl.text.trim(),
                                      fourthActionDate: action4Date,
                                    );

                                    if (customer == null) {
                                      await ref.read(customersRepositoryProvider).createCustomer(model);
                                      DataRefreshCoordinator.refresh(ref);
                                    } else {
                                      await ref.read(customersRepositoryProvider).updateCustomer(model);
                                      DataRefreshCoordinator.refresh(ref);
                                      ref.invalidate(customerProvider(model.id));
                                    }

                                    ref.invalidate(customersStreamProvider);
                                    ref.invalidate(filteredCustomersProvider);
                                    if (context.mounted) Navigator.pop(context);
                                  } catch (e) {
                                    setState(() => isSaving = false);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('${'error'.tr(ref)}: $e'), backgroundColor: AppColors.error),
                                      );
                                    }
                                  }
                                },
                                child: Text(
                                  isSaving ? 'saving'.tr(ref) : 'save'.tr(ref),
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
        },
      ),
    ),
  );
}

Widget _buildChannelDropdown(BuildContext context, WidgetRef ref, String? selectedChannel, bool isSaving, Function(String?) onChanged, {bool showAll = false}) {
  final List<_DialogMenuItem<String?>> items = [];
  if (showAll) {
    items.add(_DialogMenuItem(value: null, label: 'all_channels'.tr(ref)));
  }
  items.addAll(AppConstants.customerChannels.map((c) {
    final (color, svgPath, icon) = ChannelChip.getChannelData(c);
    return _DialogMenuItem<String?>(
      value: c,
      label: c.tr(ref),
      leading: svgPath != null
          ? SvgPicture.asset(svgPath, width: 18, height: 18)
          : icon != null ? Icon(icon, size: 18, color: color) : null,
    );
  }));

  if (selectedChannel != null && !AppConstants.customerChannels.contains(selectedChannel)) {
    items.add(_DialogMenuItem<String?>(
      value: selectedChannel,
      label: selectedChannel,
      leading: Icon(Icons.help_outline_rounded, size: 18, color: context.appTheme.textMuted),
    ));
  }

  return _DialogMenuField<String?>(
    initialValue: selectedChannel,
    label: 'select_channel'.tr(ref),
    icon: Icons.campaign_outlined,
    items: items,
    onSelected: onChanged,
    enabled: !isSaving,
    validator: showAll ? null : (v) => v == null ? 'required'.tr(ref) : null,
  );
}

Widget _buildStatusDropdown(BuildContext context, WidgetRef ref, String? selectedStatus, bool isSaving, Function(String?) onChanged, {bool showAll = false}) {
  final List<_DialogMenuItem<String?>> items = [];
  if (showAll) {
    items.add(_DialogMenuItem(value: null, label: 'all_statuses'.tr(ref)));
  }
  items.addAll(AppConstants.customerFollowUpStatuses.map((s) => _DialogMenuItem<String?>(
    value: s,
    label: s.tr(ref),
  )));

  if (selectedStatus != null && !AppConstants.customerFollowUpStatuses.contains(selectedStatus)) {
    items.add(_DialogMenuItem<String?>(
      value: selectedStatus,
      label: selectedStatus.tr(ref),
    ));
  }

  return _DialogMenuField<String?>(
    initialValue: selectedStatus,
    label: 'select_status'.tr(ref),
    icon: Icons.flag_outlined,
    items: items,
    onSelected: onChanged,
    enabled: !isSaving,
    validator: showAll ? null : (v) => v == null ? 'required'.tr(ref) : null,
  );
}

Widget _buildGovernorateDropdown(BuildContext context, WidgetRef ref, String? selectedGov, bool isSaving, Function(String?) onChanged, {bool showAll = false}) {
  final List<_DialogMenuItem<String?>> items = [];
  if (showAll) {
    items.add(_DialogMenuItem(value: null, label: 'select_gov'.tr(ref)));
  }
  items.addAll(AppConstants.governorates.map((g) => _DialogMenuItem<String?>(
    value: g,
    label: g.tr(ref),
  )));

  return _DialogMenuField<String?>(
    initialValue: selectedGov,
    label: 'governorate'.tr(ref),
    icon: Icons.map_outlined,
    items: items,
    onSelected: onChanged,
    enabled: !isSaving,
    validator: showAll ? null : (v) => v == null ? 'required'.tr(ref) : null,
  );
}

Widget _buildResponsibleDropdown(BuildContext context, WidgetRef ref, int? selectedAssignedId, List<UserModel> engineers, bool isAdmin, bool isSaving, Function(int?) onChanged) {
  final List<_DialogMenuItem<int?>> items = [
    _DialogMenuItem(value: null, label: 'unassigned'.tr(ref)),
  ];
  items.addAll(engineers.map((u) => _DialogMenuItem(value: u.id, label: u.fullName)));

  if (selectedAssignedId != null && !engineers.any((e) => e.id == selectedAssignedId)) {
    items.add(_DialogMenuItem(value: selectedAssignedId, label: 'unknown_user'.tr(ref)));
  }

  return _DialogMenuField<int?>(
    initialValue: selectedAssignedId,
    label: 'assign_user'.tr(ref),
    icon: Icons.person_outline_rounded,
    items: items,
    onSelected: onChanged,
    enabled: !isSaving && isAdmin,
    validator: (v) => v == null ? 'required'.tr(ref) : null,
  );
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
                  '', // Hide label to avoid overlap with _labeledField
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

class _FiltersBar extends ConsumerWidget {
  const _FiltersBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 700;
        final hasFilters = ref.watch(statusFilterProvider) != null ||
            ref.watch(responsibleFilterProvider) != null ||
            ref.watch(channelFilterProvider) != null ||
            ref.watch(governorateFilterProvider) != null ||
            ref.watch(startDateFilterProvider) != null ||
            ref.watch(endDateFilterProvider) != null ||
            ref.watch(searchQueryProvider).isNotEmpty;
        
        if (isMobile) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _FilterField(
                height: 44,
                hint: 'search_customers'.tr(ref),
                icon: Icons.search_rounded,
                onChanged: (value) {
                  ref.read(searchQueryProvider.notifier).state = value;
                  ref.read(currentPageProvider.notifier).state = 1;
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          const _FilterDialogButton(height: 44),
                          const SizedBox(width: 8),
                          if (hasFilters) ...[
                            const _ClearFiltersButton(),
                            const SizedBox(width: 8),
                          ],
                          const _ImportDataButton(isIconOnly: true),
                          const SizedBox(width: 8),
                          const _ExportDataButton(isIconOnly: true),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const SizedBox(
                width: double.infinity,
                child: _AddCustomerButton(isCompact: false),
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
                  hint: 'search_customers'.tr(ref),
                  icon: Icons.search_rounded,
                  style: context.labelMedium?.bold,
                  onChanged: (value) {
                    ref.read(searchQueryProvider.notifier).state = value;
                    ref.read(currentPageProvider.notifier).state = 1;
                  },
                ),
              ),
              const SizedBox(width: 16),
              const _FilterDialogButton(height: 48),
              if (hasFilters) ...[
                const SizedBox(width: 16),
                const _ClearFiltersButton(),
              ],
              const SizedBox(width: 24),
              const _ImportDataButton(isIconOnly: true),
              const SizedBox(width: 12),
              const _ExportDataButton(isIconOnly: true),
              const SizedBox(width: 20),
              const _AddCustomerButton(isCompact: true),
            ],
          ),
        );
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
    final hasFilters = ref.watch(statusFilterProvider) != null || 
                      ref.watch(responsibleFilterProvider) != null || 
                      ref.watch(channelFilterProvider) != null ||
                      ref.watch(governorateFilterProvider) != null ||
                      ref.watch(startDateFilterProvider) != null ||
                      ref.watch(endDateFilterProvider) != null ||
                      ref.watch(searchQueryProvider).isNotEmpty;
    if (!hasFilters) return const SizedBox.shrink();

    return TextButton.icon(
      onPressed: () => _clear(ref),
      icon: const Icon(Icons.refresh_rounded, size: 16, color: AppColors.error),
      label: Text(
        'Reset', 
        style: context.labelMedium?.bold.withColor(AppColors.error),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _clear(WidgetRef ref) {
    ref.read(statusFilterProvider.notifier).state = null;
    ref.read(responsibleFilterProvider.notifier).state = null;
    ref.read(channelFilterProvider.notifier).state = null;
    ref.read(governorateFilterProvider.notifier).state = null;
    ref.read(startDateFilterProvider.notifier).state = null;
    ref.read(endDateFilterProvider.notifier).state = null;
    ref.read(searchQueryProvider.notifier).state = '';
    ref.read(currentPageProvider.notifier).state = 1;
  }
}

class _FilterDialogButton extends ConsumerWidget {
  const _FilterDialogButton({required this.height});
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasExtraFilters = ref.watch(responsibleFilterProvider) != null ||
        ref.watch(channelFilterProvider) != null ||
        ref.watch(governorateFilterProvider) != null ||
        ref.watch(startDateFilterProvider) != null ||
        ref.watch(endDateFilterProvider) != null;

    return Tooltip(
      message: 'filter'.tr(ref),
      child: InkWell(
        onTap: () => _showFilterDialog(context),
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          height: height,
          decoration: BoxDecoration(
            color: hasExtraFilters
                ? AppColors.primaryTeal.withValues(alpha: 0.1)
                : context.onSurfaceColor.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: hasExtraFilters ? AppColors.primaryTeal.withValues(alpha: 0.2) : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.filter_list_rounded,
                size: 18,
                color: hasExtraFilters ? AppColors.primaryTeal : AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                'filter'.tr(ref),
                style: context.labelMedium?.bold.withColor(
                  hasExtraFilters ? AppColors.primaryTeal : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _FilterDialog(),
    );
  }
}

class _FilterDialog extends ConsumerStatefulWidget {
  const _FilterDialog();

  @override
  ConsumerState<_FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends ConsumerState<_FilterDialog> {
  String? _status;
  int? _responsible;
  String? _channel;
  String? _gov;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _status = ref.read(statusFilterProvider);
    _responsible = ref.read(responsibleFilterProvider);
    _channel = ref.read(channelFilterProvider);
    _gov = ref.read(governorateFilterProvider);
    _startDate = ref.read(startDateFilterProvider);
    _endDate = ref.read(endDateFilterProvider);
  }

  @override
  Widget build(BuildContext context) {
    final engineers = ref.watch(engineersProvider).value ?? [];
    final user = ref.watch(currentUserProvider);
    final isAdmin = user?.role == UserRole.admin;

    return Dialog(
      backgroundColor: context.surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('filter_customers'.tr(ref), style: context.headlineSmall?.bold),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _labeledField(
                        context,
                        'status'.tr(ref),
                        _buildStatusDropdown(context, ref, _status, false, (v) => setState(() => _status = v), showAll: true),
                      ),
                      const SizedBox(height: 16),
                      if (isAdmin) ...[
                        _labeledField(
                          context,
                          'responsible'.tr(ref),
                          _buildResponsibleDropdown(context, ref, _responsible, engineers, isAdmin, false, (v) => setState(() => _responsible = v)),
                        ),
                        const SizedBox(height: 16),
                      ],
                      _labeledField(
                        context,
                        'channel'.tr(ref),
                        _buildChannelDropdown(context, ref, _channel, false, (v) => setState(() => _channel = v), showAll: true),
                      ),
                      const SizedBox(height: 16),
                      _labeledField(
                        context,
                        'governorate'.tr(ref),
                        _buildGovernorateDropdown(context, ref, _gov, false, (v) => setState(() => _gov = v), showAll: true),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _labeledField(
                              context,
                              'from'.tr(ref),
                              _DatePickerField(
                                label: 'start_date'.tr(ref),
                                selectedDate: _startDate,
                                onChanged: (d) => setState(() => _startDate = d),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _labeledField(
                              context,
                              'to'.tr(ref),
                              _DatePickerField(
                                label: 'end_date'.tr(ref),
                                selectedDate: _endDate,
                                onChanged: (d) => setState(() => _endDate = d),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _status = null;
                        _responsible = null;
                        _channel = null;
                        _gov = null;
                        _startDate = null;
                        _endDate = null;
                      });
                    },
                    child: Text('reset'.tr(ref), style: context.labelLarge?.withColor(AppColors.error)),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: () {
                      ref.read(statusFilterProvider.notifier).state = _status;
                      ref.read(responsibleFilterProvider.notifier).state = _responsible;
                      ref.read(channelFilterProvider.notifier).state = _channel;
                      ref.read(governorateFilterProvider.notifier).state = _gov;
                      ref.read(startDateFilterProvider.notifier).state = _startDate;
                      ref.read(endDateFilterProvider.notifier).state = _endDate;
                      ref.read(currentPageProvider.notifier).state = 1;
                      Navigator.pop(context);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryTeal,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('apply_filters'.tr(ref)),
                  ),
                ],
              ),
            ],
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

class _PaginationFooter extends ConsumerWidget {
  const _PaginationFooter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customersAsync = ref.watch(filteredCustomersProvider);
    final currentPage = ref.watch(currentPageProvider);
    final itemsPerPage = ref.watch(itemsPerPageProvider);

    return customersAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (err, stack) => const SizedBox.shrink(),
      data: (customers) {
        final totalPages = (customers.length / itemsPerPage).ceil();
        return PaginationFooter(
          currentPage: currentPage,
          totalPages: totalPages,
          onPageChanged: (page) => ref.read(currentPageProvider.notifier).state = page,
        );
      },
    );
  }
}

class _ImportDataButton extends ConsumerStatefulWidget {
  const _ImportDataButton({this.isIconOnly = false});
  final bool isIconOnly;

  @override
  ConsumerState<_ImportDataButton> createState() => _ImportDataButtonState();
}

class _ImportDataButtonState extends ConsumerState<_ImportDataButton> {
  bool _isImporting = false;

  Future<void> _handleImport() async {
    setState(() => _isImporting = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'csv'],
      );

      if (result != null && result.files.single.path != null) {
        final user = ref.read(currentUserProvider);
        final assignedUserId = user?.role == UserRole.engineer ? user?.id : null;
        final importResult = await ref.read(customerImportServiceProvider).importFromFile(
          result.files.single.path!,
          assignedUserId,
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_importSummary(importResult, ref)),
              backgroundColor: AppColors.success,
            ),
          );
          ref.invalidate(customersStreamProvider);
          ref.invalidate(filteredCustomersProvider);
          ref.invalidate(projectsStreamProvider);
        }
      }
    } on CustomerImportException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${'import_error'.tr(ref)}: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  String _importSummary(CustomerImportResult result, WidgetRef ref) {
    final summary = '${'import_success'.tr(ref)} '
        '${result.customersImported} customers, ${result.projectsCreated} projects.';
    if (result.skippedRows.isEmpty) return summary;

    final examples = result.skippedRows
        .take(3)
        .map((row) => 'row ${row.rowNumber}: ${row.reason}')
        .join('; ');
    final remaining = result.skippedRows.length - 3;
    return '$summary ${result.skippedRows.length} skipped ($examples${remaining > 0 ? '; +$remaining more' : ''}).';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      width: widget.isIconOnly ? 48 : null,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: context.surfaceColor,
        border: Border.all(color: AppColors.primaryTeal.withValues(alpha: 0.5), width: 1.5),
      ),
      child: widget.isIconOnly 
        ? Tooltip(
            message: 'import_data'.tr(ref),
            child: InkWell(
              onTap: _isImporting ? null : _handleImport,
              borderRadius: BorderRadius.circular(12),
              child: Center(
                child: _isImporting 
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryTeal))
                  : const Icon(Icons.file_upload_outlined, size: 20, color: AppColors.primaryTeal),
              ),
            ),
          )
        : ElevatedButton.icon(
            onPressed: _isImporting ? null : _handleImport,
            icon: _isImporting 
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryTeal))
              : const Icon(Icons.file_upload_outlined, size: 20, color: AppColors.primaryTeal),
            label: Text(
              'import_data'.tr(ref),
              style: context.labelSmall?.primary,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
    );
  }
}

class _ExportDataButton extends ConsumerStatefulWidget {
  const _ExportDataButton({this.isIconOnly = false});
  final bool isIconOnly;

  @override
  ConsumerState<_ExportDataButton> createState() => _ExportDataButtonState();
}

class _ExportDataButtonState extends ConsumerState<_ExportDataButton> {
  bool _isExporting = false;

  Future<void> _handleExport() async {
    setState(() => _isExporting = true);
    try {
      final path = await ref.read(customerExportServiceProvider).exportToExcel();
      
      if (mounted && path != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('export_success'.tr(ref)),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${'export_error'.tr(ref)}: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      width: widget.isIconOnly ? 48 : null,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: context.surfaceColor,
        border: Border.all(color: AppColors.primaryTeal.withValues(alpha: 0.5), width: 1.5),
      ),
      child: widget.isIconOnly 
        ? Tooltip(
            message: 'export_data'.tr(ref),
            child: InkWell(
              onTap: _isExporting ? null : _handleExport,
              borderRadius: BorderRadius.circular(12),
              child: Center(
                child: _isExporting 
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryTeal))
                  : const Icon(Icons.file_download_outlined, size: 20, color: AppColors.primaryTeal),
              ),
            ),
          )
        : ElevatedButton.icon(
            onPressed: _isExporting ? null : _handleExport,
            icon: _isExporting 
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryTeal))
              : const Icon(Icons.file_download_outlined, size: 20, color: AppColors.primaryTeal),
            label: Text(
              'export_data'.tr(ref),
              style: context.labelSmall?.primary,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
    );
  }
}

class _AddCustomerButton extends ConsumerWidget {
  const _AddCustomerButton({this.isCompact = false});
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
      child: ElevatedButton.icon(
        onPressed: () => showCustomerDialog(context, ref),
        icon: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.add_rounded, size: 20, color: AppColors.white),
        ),
        label: Text(
          'add_customer'.tr(ref),
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

class _AssignedUserBadge extends ConsumerWidget {
  const _AssignedUserBadge({this.userId});
  final int? userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (userId == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: context.appTheme.textMuted.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.appTheme.textMuted.withValues(alpha: 0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.help_outline_rounded, size: 12, color: context.appTheme.textMuted),
            const SizedBox(width: 8),
            Text(
              'unassigned'.tr(ref),
              style: context.labelSmall?.withColor(context.appTheme.textMuted).copyWith(fontStyle: FontStyle.italic),
            ),
          ],
        ),
      );
    }

    final engineersAsync = ref.watch(engineersProvider);

    return engineersAsync.when(
      data: (users) {
        final user = users.firstWhere(
          (u) => u.id == userId,
          orElse: () => UserModel(id: 0, username: '', passwordHash: '', fullName: 'Unknown', email: '', role: ''),
        );
        return Container(
          height: 32,
          padding: const EdgeInsetsDirectional.fromSTEB(4, 4, 12, 4),
          decoration: BoxDecoration(
            color: AppColors.primaryTeal.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.primaryTeal.withValues(alpha: 0.1)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSmallAvatar(context, user.fullName),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  user.fullName,
                  style: context.labelMedium?.bold,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
      error: (error, stack) => Text('error'.tr(ref), style: context.labelSmall?.withColor(context.errorColor)),
    );
  }

  Widget _buildSmallAvatar(BuildContext context, String name) {
    final (bgColor, textColor) = DeterministicColor.getColor(name);
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: context.labelMedium?.withColor(textColor),
      ),
    );
  }
}



Widget _interactionRow(BuildContext context, String label, TextEditingController ctrl, DateTime? date, Function(DateTime?) onDateChanged, {int index = 1, required WidgetRef ref, bool isNarrow = false}) {
  final commentField = _labeledField(context, label, TextFormField(controller: ctrl, decoration: customInputDecoration(context, 'comment'.tr(ref), icon: Icons.chat_bubble_outline_rounded)));
  final dateField = _labeledField(
    context,
    'action_date'.tr(ref),
    _DatePickerField(
      label: 'select_date'.tr(ref),
      selectedDate: date,
      onChanged: onDateChanged,
    ),
  );

  return Container(
    padding: EdgeInsets.all(isNarrow ? 12 : 24),
    decoration: BoxDecoration(
      color: context.appTheme.surfaceSubtle,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: context.borderColor),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: context.theme.brightness == Brightness.dark ? 0.2 : 0.015),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primaryTeal, AppColors.primaryTealLight],
            ),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            '$index',
            style: context.labelSmall?.white,
          ),
        ),
        SizedBox(width: isNarrow ? 10 : 16),
        Expanded(
          child: isNarrow 
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  commentField,
                  const SizedBox(height: 12),
                  dateField,
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: commentField),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: dateField),
                ],
              ),
        ),
      ],
    ),
  );
}

class _EmptyCustomers extends ConsumerWidget {
  const _EmptyCustomers();

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
                    Icons.people_outline_rounded,
                    size: isMobile ? 48 : 80,
                    color: AppColors.primaryTeal.withValues(alpha: 0.4)
                  ),
                ),
                SizedBox(height: isMobile ? 16 : 32),
                Text(
                  'no_customers'.tr(ref),
                  style: (isMobile ? context.titleLarge : context.headlineMedium),
                ),
                const SizedBox(height: 8),
                Text(
                  'try_adjusting_filters'.tr(ref),
                  textAlign: TextAlign.center,
                  style: context.bodyMedium?.withColor(context.onSurfaceVariant),
                ),
                SizedBox(height: isMobile ? 24 : 40),
                const _AddCustomerButton(),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FollowUpBadge extends ConsumerWidget {
  const _FollowUpBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Color color = context.appTheme.textMuted;
    if (status == AppConstants.customerFollowUpStatuses[5]) color = AppColors.success;
    if (status == AppConstants.customerFollowUpStatuses[6]) color = AppColors.error;
    if (status == AppConstants.customerFollowUpStatuses[4]) color = AppColors.warning;
    if (status == AppConstants.customerFollowUpStatuses[3]) color = AppColors.info;
    if (status == AppConstants.customerFollowUpStatuses[1]) color = AppColors.indigo;
    if (status == AppConstants.customerFollowUpStatuses[2]) color = AppColors.pink;
    if (status == AppConstants.customerFollowUpStatuses[0]) color = AppColors.primaryTeal;

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
            status.tr(ref),
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

void _showDeleteConfirmation(BuildContext context, WidgetRef ref, CustomerModel customer) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('delete'.tr(ref), style: context.titleLarge?.bold.withColor(context.errorColor)),
      content: Text('${'delete'.tr(ref)} ${customer.name}?', style: context.bodyLarge),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('cancel'.tr(ref), style: context.labelLarge?.withColor(context.onSurfaceVariant))),
        FilledButton(
          onPressed: () async {
            try {
              await ref.read(customersRepositoryProvider).deleteCustomer(customer.id);
              DataRefreshCoordinator.refresh(ref);
              ref.invalidate(customersStreamProvider);
              ref.invalidate(filteredCustomersProvider);
              if (context.mounted) Navigator.pop(context);
            } catch (e) {
              if (context.mounted) {
                final errorKey = e.toString().contains('customer_has_projects')
                    ? 'customer_has_projects'
                    : 'error';

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(errorKey.tr(ref)),
                    backgroundColor: AppColors.error,
                  ),
                );
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

class _DatePickerField extends ConsumerWidget {
  const _DatePickerField({required this.label, this.selectedDate, required this.onChanged, this.enabled = true});
  final String label;
  final DateTime? selectedDate;
  final Function(DateTime?) onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextFormField(
      controller: TextEditingController(
        text: selectedDate == null ? '' : selectedDate!.toFullDate(),
      ),
      readOnly: true,
      enabled: enabled,
      onTap: !enabled ? null : () async {
        final d = await showDatePicker(
          context: context,
          initialDate: selectedDate ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.primaryTeal,
                  onPrimary: AppColors.white,
                  surface: context.surfaceColor,
                  onSurface: context.onSurfaceColor,
                ),
                datePickerTheme: DatePickerThemeData(
                  backgroundColor: context.surfaceColor,
                  headerBackgroundColor: AppColors.primaryTeal,
                  headerForegroundColor: AppColors.white,
                  surfaceTintColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  dayStyle: context.bodyMedium,
                  yearStyle: context.bodyMedium,
                  headerHeadlineStyle: context.headlineSmall?.white.bold,
                  headerHelpStyle: context.labelMedium?.white,
                  dayForegroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) return AppColors.white;
                    return context.onSurfaceColor;
                  }),
                  todayForegroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) return AppColors.white;
                    return AppColors.primaryTeal;
                  }),
                  todayBorder: const BorderSide(color: AppColors.primaryTeal),
                ),
                textButtonTheme: TextButtonThemeData(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primaryTeal,
                    textStyle: context.labelLarge?.bold,
                  ),
                ),
              ),
              child: child!,
            );
          },
        );
        if (d != null) onChanged(d);
      },
      style: context.bodyMedium?.withWeight(FontWeight.w600),
      decoration: customInputDecoration(context, '', icon: Icons.calendar_today_rounded).copyWith(
        fillColor: enabled ? null : context.onSurfaceColor.withValues(alpha: 0.05),
        filled: !enabled,
        floatingLabelBehavior: FloatingLabelBehavior.never,
      ),
    );
  }
}
