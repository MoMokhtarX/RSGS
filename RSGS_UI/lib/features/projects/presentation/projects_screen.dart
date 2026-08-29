import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/data_refresh_service.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/app_models.dart';
import '../../../core/permissions/user_role.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/localization/language_provider.dart';
import '../../../core/localization/date_formatter.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/theme/typography_extensions.dart';
import '../data/projects_repository.dart';
import '../../auth/data/auth_repository.dart';
import '../../customers/data/customers_repository.dart';
import '../../../core/utils/deterministic_color.dart';

final projectSearchQueryProvider = StateProvider<String>((ref) => '');
final projectStatusFilterProvider = StateProvider<String?>((ref) => null);
final projectResponsibleFilterProvider = StateProvider<int?>((ref) => null);
final projectTypeFilterProvider = StateProvider<String?>((ref) => null);
final projectGovernorateFilterProvider = StateProvider<String?>((ref) => null);
final projectMinKwFilterProvider = StateProvider<double?>((ref) => null);
final projectMaxKwFilterProvider = StateProvider<double?>((ref) => null);
final projectMinValueFilterProvider = StateProvider<double?>((ref) => null);
final projectMaxValueFilterProvider = StateProvider<double?>((ref) => null);
final projectStartDateFilterProvider = StateProvider<DateTime?>((ref) => null);
final projectEndDateFilterProvider = StateProvider<DateTime?>((ref) => null);
final projectCurrentPageProvider = StateProvider<int>((ref) => 1);
final projectItemsPerPageProvider = StateProvider<int>((ref) => 10);

final projectSortAscendingProvider = StateProvider<bool>((ref) => false);

final filteredProjectsProvider = Provider<AsyncValue<List<ProjectWithDetails>>>((ref) {
  final projectsAsync = ref.watch(projectsWithDetailsProvider);
  final searchQuery = ref.watch(projectSearchQueryProvider).toLowerCase();
  final statusFilter = ref.watch(projectStatusFilterProvider);
  final responsibleFilter = ref.watch(projectResponsibleFilterProvider);
  final typeFilter = ref.watch(projectTypeFilterProvider);
  final govFilter = ref.watch(projectGovernorateFilterProvider);
  final minKw = ref.watch(projectMinKwFilterProvider);
  final maxKw = ref.watch(projectMaxKwFilterProvider);
  final minValue = ref.watch(projectMinValueFilterProvider);
  final maxValue = ref.watch(projectMaxValueFilterProvider);
  final startDate = ref.watch(projectStartDateFilterProvider);
  final endDate = ref.watch(projectEndDateFilterProvider);
  final sortAscending = ref.watch(projectSortAscendingProvider);

  return projectsAsync.whenData((projects) {
    final filtered = projects.where((p) {
      final matchesSearch = p.project.name.toLowerCase().contains(searchQuery) ||
          p.project.projectNumber.toLowerCase().contains(searchQuery) ||
          (p.customerName?.toLowerCase().contains(searchQuery) ?? false) ||
          (p.engineerName?.toLowerCase().contains(searchQuery) ?? false);
      final matchesStatus = statusFilter == null || p.project.status == statusFilter;
      final matchesResponsible = responsibleFilter == null || p.project.engineerId == responsibleFilter;
      final matchesType = typeFilter == null || p.project.name == typeFilter;
      final matchesGov = govFilter == null || p.project.governorate == govFilter;
      
      final matchesKw = (minKw == null || p.project.totalKw >= minKw) && 
                       (maxKw == null || p.project.totalKw <= maxKw);
      final matchesValue = (minValue == null || p.project.totalValue >= minValue) && 
                          (maxValue == null || p.project.totalValue <= maxValue);

      bool matchesDate = true;
      if (startDate != null && p.project.createdDate != null) {
        matchesDate = matchesDate && (p.project.createdDate!.isAfter(startDate) || DateUtils.isSameDay(p.project.createdDate, startDate));
      }
      if (endDate != null && p.project.createdDate != null) {
        matchesDate = matchesDate && (p.project.createdDate!.isBefore(endDate) || DateUtils.isSameDay(p.project.createdDate, endDate));
      }

      return matchesSearch && matchesStatus && matchesResponsible && matchesType && matchesGov && matchesKw && matchesValue && matchesDate;
    }).toList();

    filtered.sort((a, b) {
      final dateA = a.project.createdDate;
      final dateB = b.project.createdDate;
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

class ProjectsScreen extends ConsumerWidget {
  const ProjectsScreen({super.key});

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
                child: const _ProjectsFiltersBar(),
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
                    child: _ProjectsTable(isMobile: isMobile),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(vertical: isMobile ? 4 : 8, horizontal: 16),
                child: const _ProjectsPaginationFooter(),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProjectsTable extends ConsumerWidget {
  const _ProjectsTable({required this.isMobile});
  final bool isMobile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(filteredProjectsProvider);
    final currentPage = ref.watch(projectCurrentPageProvider);
    final itemsPerPage = ref.watch(projectItemsPerPageProvider);

    return projectsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('${'error'.tr(ref)}: $err')),
      data: (projects) {
        if (projects.isEmpty) return const _EmptyProjects();
        
        final totalPages = (projects.length / itemsPerPage).ceil();
        final actualPage = currentPage > totalPages ? (totalPages > 0 ? totalPages : 1) : currentPage;
        final startIndex = (actualPage - 1) * itemsPerPage;
        final endIndex = (startIndex + itemsPerPage).clamp(0, projects.length);
        
        final pageProjects = projects.sublist(startIndex, endIndex);

        if (isMobile) {
          return ListView.separated(
            key: const PageStorageKey('projects_mobile_list'),
            padding: const EdgeInsets.all(12),
            itemCount: pageProjects.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              return _ProjectCard(
                project: pageProjects[index],
              );
            },
          );
        }

        return Column(
          children: [
            const _TableHeader(),
            Expanded(
              child: ListView.builder(
                key: const PageStorageKey('projects_table_list'),
                padding: const EdgeInsets.only(top: 4),
                itemCount: pageProjects.length,
                itemBuilder: (context, index) {
                  return _TableRow(
                    key: ValueKey('project_row_${pageProjects[index].project.id}'),
                    project: pageProjects[index],
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
        final showResponsible = constraints.maxWidth > 1250;
        final showValue = constraints.maxWidth > 1150;

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
              _buildHeaderCell(context, ref, 'project'.tr(ref), Icons.folder_open_rounded, flex: 3),
              const SizedBox(width: 12),
              _buildHeaderCell(context, ref, 'customer'.tr(ref), Icons.person_outline_rounded, flex: 3),
              const SizedBox(width: 12),
              _buildHeaderCell(context, ref, 'status'.tr(ref), Icons.flag_outlined, flex: 2),
              const SizedBox(width: 12),
              _buildHeaderCell(context, ref, 'total_kw'.tr(ref), Icons.bolt_rounded, flex: 2),
              if (showValue) ...[
                const SizedBox(width: 12),
                _buildHeaderCell(context, ref, 'total_value'.tr(ref), Icons.payments_outlined, flex: 2),
              ],
              if (showResponsible) ...[
                const SizedBox(width: 12),
                _buildHeaderCell(context, ref, 'responsible'.tr(ref), Icons.assignment_ind_outlined, flex: 3),
              ],
              const SizedBox(width: 80),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeaderCell(BuildContext context, WidgetRef ref, String label, IconData? icon, {int? flex, double? width, String? sortKey, bool isCentered = false, bool hasDivider = false}) {
    final ascending = ref.watch(projectSortAscendingProvider);
    final isSorted = sortKey != null;

    final child = Row(
      children: [
        Expanded(
          child: Tooltip(
            message: sortKey != null ? 'click_to_sort'.tr(ref) : '',
            child: InkWell(
              onTap: sortKey == null ? null : () {
                ref.read(projectSortAscendingProvider.notifier).state = !ascending;
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
  const _TableRow({super.key, required this.project, required this.index});
  final ProjectWithDetails project;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(localeProvider).languageCode;
    return LayoutBuilder(
      builder: (context, constraints) {
        final showResponsible = constraints.maxWidth > 1250;
        final showValue = constraints.maxWidth > 1150;

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
              onTap: () => context.go('/projects/${project.project.id}'),
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
                              '${project.project.id}',
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
                          project.project.name,
                          style: context.titleSmall?.bold,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: Text(
                        project.customerName ?? '-',
                        style: context.titleSmall?.medium.withColor(context.onSurfaceVariant),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: _ProjectStatusBadge(status: project.project.status),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '${formatNumber(project.project.totalKw, locale: lang)} ${'kw_unit'.tr(ref)}',
                        style: context.titleSmall?.bold.withColor(AppColors.indigo),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (showValue) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: Text(
                          formatCurrency(project.project.totalValue),
                          style: context.titleSmall?.bold.primary,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    if (showResponsible) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: _AssignedUserBadge(userId: project.project.engineerId),
                        ),
                      ),
                    ],
                    SizedBox(
                      width: 80,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ActionButton(
                            icon: Icons.edit_rounded,
                            color: AppColors.primaryTeal,
                            tooltip: 'edit'.tr(ref),
                            onPressed: () => showProjectDialog(context, ref, project: project.project),
                          ),
                          const SizedBox(width: 4),
                          ActionButton(
                            icon: Icons.delete_outline_rounded,
                            color: AppColors.error,
                            tooltip: 'delete'.tr(ref),
                            onPressed: () => _showDeleteConfirmation(context, ref, project.project),
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

class _ProjectCard extends ConsumerWidget {
  const _ProjectCard({required this.project});
  final ProjectWithDetails project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(localeProvider).languageCode;
    return InkWell(
      onTap: () => context.go('/projects/${project.project.id}'),
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
                    project.project.name,
                    style: context.titleMedium?.bold,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '#${project.project.id}',
                  style: context.labelSmall?.withColor(context.appTheme.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.person_outline_rounded, size: 14, color: context.appTheme.textMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    project.customerName ?? '-',
                    style: context.titleSmall?.medium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.bolt_rounded, size: 14, color: AppColors.indigo),
                          const SizedBox(width: 6),
                          Text(
                            '${formatNumber(project.project.totalKw, locale: lang)} ${'kw_unit'.tr(ref)}',
                            style: context.titleSmall?.bold.withColor(AppColors.indigo),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.payments_outlined, size: 14, color: AppColors.primaryTeal),
                          const SizedBox(width: 6),
                          Text(
                            formatCurrency(project.project.totalValue),
                            style: context.titleSmall?.bold.primary,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _ProjectStatusBadge(status: project.project.status),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: _AssignedUserBadge(userId: project.project.engineerId),
                  ),
                ),
                Row(
                  children: [
                    ActionButton(
                      icon: Icons.edit_rounded,
                      color: AppColors.primaryTeal,
                      tooltip: 'edit'.tr(ref),
                      onPressed: () => showProjectDialog(context, ref, project: project.project),
                    ),
                    const SizedBox(width: 8),
                    ActionButton(
                      icon: Icons.delete_outline_rounded,
                      color: AppColors.error,
                      tooltip: 'delete'.tr(ref),
                      onPressed: () => _showDeleteConfirmation(context, ref, project.project),
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

class _ProjectsFiltersBar extends ConsumerWidget {
  const _ProjectsFiltersBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 700;
        final hasFilters = ref.watch(projectStatusFilterProvider) != null ||
            ref.watch(projectResponsibleFilterProvider) != null ||
            ref.watch(projectTypeFilterProvider) != null ||
            ref.watch(projectGovernorateFilterProvider) != null ||
            ref.watch(projectMinKwFilterProvider) != null ||
            ref.watch(projectMaxKwFilterProvider) != null ||
            ref.watch(projectMinValueFilterProvider) != null ||
            ref.watch(projectMaxValueFilterProvider) != null ||
            ref.watch(projectStartDateFilterProvider) != null ||
            ref.watch(projectEndDateFilterProvider) != null ||
            ref.watch(projectSearchQueryProvider).isNotEmpty;
        
        if (isMobile) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _FilterField(
                height: 44,
                hint: 'search_projects_hint'.tr(ref),
                icon: Icons.search_rounded,
                onChanged: (value) {
                  ref.read(projectSearchQueryProvider.notifier).state = value;
                  ref.read(projectCurrentPageProvider.notifier).state = 1;
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
                          const _ProjectFilterDialogButton(height: 44),
                          const SizedBox(width: 8),
                          if (hasFilters) ...[
                            const _ClearFiltersButton(),
                            const SizedBox(width: 8),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const SizedBox(
                width: double.infinity,
                child: _AddProjectButton(isCompact: false),
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
                  hint: 'search_projects_hint'.tr(ref),
                  icon: Icons.search_rounded,
                  style: context.labelMedium?.bold,
                  onChanged: (value) {
                    ref.read(projectSearchQueryProvider.notifier).state = value;
                    ref.read(projectCurrentPageProvider.notifier).state = 1;
                  },
                ),
              ),
              const SizedBox(width: 16),
              const _ProjectFilterDialogButton(height: 48),
              if (hasFilters) ...[
                const SizedBox(width: 8),
                const _ClearFiltersButton(),
              ],
              const SizedBox(width: 20),
              const _AddProjectButton(isCompact: true),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusDropdown(BuildContext context, WidgetRef ref, String? value, ValueChanged<String?> onChanged, {bool showAll = false}) {
    final List<_FilterMenuItem<String?>> items = [];
    if (showAll) {
      items.add(_FilterMenuItem(value: null, label: 'all_statuses'.tr(ref)));
    }
    items.addAll(AppConstants.projectStatuses.map((s) => _FilterMenuItem<String?>(value: s, label: s.tr(ref))));

    return _DialogMenuField<String?>(
      initialValue: value,
      label: 'select_status'.tr(ref),
      icon: Icons.flag_outlined,
      items: items.map((i) => _DialogMenuItem(value: i.value, label: i.label)).toList(),
      onSelected: onChanged,
    );
  }

  Widget _buildTypeDropdown(BuildContext context, WidgetRef ref, String? value, ValueChanged<String?> onChanged, {bool showAll = false}) {
    final List<_FilterMenuItem<String?>> items = [];
    if (showAll) {
      items.add(_FilterMenuItem(value: null, label: 'all_types'.tr(ref)));
    }
    items.addAll(AppConstants.projectTypes.map((t) => _FilterMenuItem<String?>(value: t, label: t.tr(ref))));

    return _DialogMenuField<String?>(
      initialValue: value,
      label: 'name'.tr(ref),
      icon: Icons.solar_power_rounded,
      items: items.map((i) => _DialogMenuItem(value: i.value, label: i.label)).toList(),
      onSelected: onChanged,
    );
  }

  Widget _buildGovernorateDropdown(BuildContext context, WidgetRef ref, String? value, ValueChanged<String?> onChanged, {bool showAll = false}) {
    final List<_FilterMenuItem<String?>> items = [];
    if (showAll) {
      items.add(_FilterMenuItem(value: null, label: 'select_gov'.tr(ref)));
    }
    items.addAll(AppConstants.governorates.map((g) => _FilterMenuItem<String?>(value: g, label: g.tr(ref))));

    return _DialogMenuField<String?>(
      initialValue: value,
      label: 'governorate'.tr(ref),
      icon: Icons.map_outlined,
      items: items.map((i) => _DialogMenuItem(value: i.value, label: i.label)).toList(),
      onSelected: onChanged,
    );
  }

  Widget _buildResponsibleDropdown(BuildContext context, WidgetRef ref, int? value, List<UserModel> engineers, bool isAdmin, ValueChanged<int?> onChanged) {
    final List<_DialogMenuItem<int?>> items = [
      _DialogMenuItem(value: null, label: 'responsible'.tr(ref)),
    ];
    items.addAll(engineers.map((u) => _DialogMenuItem(value: u.id, label: u.fullName)));

    return _DialogMenuField<int?>(
      initialValue: value,
      label: 'assign_user'.tr(ref),
      icon: Icons.person_outline_rounded,
      items: items,
      onSelected: onChanged,
      enabled: isAdmin,
    );
  }
}

class _ProjectFilterDialogButton extends ConsumerWidget {
  const _ProjectFilterDialogButton({required this.height});
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasExtraFilters = ref.watch(projectStatusFilterProvider) != null ||
        ref.watch(projectResponsibleFilterProvider) != null ||
        ref.watch(projectTypeFilterProvider) != null ||
        ref.watch(projectGovernorateFilterProvider) != null ||
        ref.watch(projectMinKwFilterProvider) != null ||
        ref.watch(projectMaxKwFilterProvider) != null ||
        ref.watch(projectMinValueFilterProvider) != null ||
        ref.watch(projectMaxValueFilterProvider) != null ||
        ref.watch(projectStartDateFilterProvider) != null ||
        ref.watch(projectEndDateFilterProvider) != null;

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
      builder: (context) => const _ProjectFilterDialog(),
    );
  }
}

class _ProjectFilterDialog extends ConsumerStatefulWidget {
  const _ProjectFilterDialog();

  @override
  ConsumerState<_ProjectFilterDialog> createState() => _ProjectFilterDialogState();
}

class _ProjectFilterDialogState extends ConsumerState<_ProjectFilterDialog> {
  String? _status;
  int? _responsible;
  String? _type;
  String? _gov;
  double? _minKw;
  double? _maxKw;
  double? _minValue;
  double? _maxValue;
  DateTime? _startDate;
  DateTime? _endDate;

  late final TextEditingController _minKwCtrl;
  late final TextEditingController _maxKwCtrl;
  late final TextEditingController _minValueCtrl;
  late final TextEditingController _maxValueCtrl;

  @override
  void initState() {
    super.initState();
    _status = ref.read(projectStatusFilterProvider);
    _responsible = ref.read(projectResponsibleFilterProvider);
    _type = ref.read(projectTypeFilterProvider);
    _gov = ref.read(projectGovernorateFilterProvider);
    _minKw = ref.read(projectMinKwFilterProvider);
    _maxKw = ref.read(projectMaxKwFilterProvider);
    _minValue = ref.read(projectMinValueFilterProvider);
    _maxValue = ref.read(projectMaxValueFilterProvider);
    _startDate = ref.read(projectStartDateFilterProvider);
    _endDate = ref.read(projectEndDateFilterProvider);

    _minKwCtrl = TextEditingController(text: _minKw?.toString() ?? '');
    _maxKwCtrl = TextEditingController(text: _maxKw?.toString() ?? '');
    _minValueCtrl = TextEditingController(text: _minValue?.toString() ?? '');
    _maxValueCtrl = TextEditingController(text: _maxValue?.toString() ?? '');
  }

  @override
  void dispose() {
    _minKwCtrl.dispose();
    _maxKwCtrl.dispose();
    _minValueCtrl.dispose();
    _maxValueCtrl.dispose();
    super.dispose();
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
                  Text('filter_projects'.tr(ref), style: context.headlineSmall?.bold),
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
                      const _ProjectsFiltersBar()._buildTypeDropdown(
                        context, 
                        ref, 
                        _type, 
                        (v) => setState(() => _type = v),
                        showAll: true,
                      ),
                      const SizedBox(height: 16),
                      const _ProjectsFiltersBar()._buildStatusDropdown(
                        context, 
                        ref, 
                        _status, 
                        (v) => setState(() => _status = v),
                        showAll: true,
                      ),
                      const SizedBox(height: 16),
                      const _ProjectsFiltersBar()._buildGovernorateDropdown(
                        context, 
                        ref, 
                        _gov, 
                        (v) => setState(() => _gov = v),
                        showAll: true,
                      ),
                      const SizedBox(height: 16),
                      if (isAdmin) ...[
                        const _ProjectsFiltersBar()._buildResponsibleDropdown(
                          context, 
                          ref, 
                          _responsible, 
                          engineers, 
                          isAdmin, 
                          (v) => setState(() => _responsible = v)
                        ),
                        const SizedBox(height: 16),
                      ],
                      _buildRangeFilter(
                        context, 
                        'total_kw'.tr(ref), 
                        _minKwCtrl, 
                        _maxKwCtrl,
                        onMinChanged: (v) => _minKw = double.tryParse(v),
                        onMaxChanged: (v) => _maxKw = double.tryParse(v),
                      ),
                      const SizedBox(height: 16),
                      _buildRangeFilter(
                        context, 
                        'total_value'.tr(ref), 
                        _minValueCtrl, 
                        _maxValueCtrl,
                        onMinChanged: (v) => _minValue = double.tryParse(v),
                        onMaxChanged: (v) => _maxValue = double.tryParse(v),
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
                        _type = null;
                        _gov = null;
                        _minKw = null;
                        _maxKw = null;
                        _minValue = null;
                        _maxValue = null;
                        _startDate = null;
                        _endDate = null;
                        _minKwCtrl.clear();
                        _maxKwCtrl.clear();
                        _minValueCtrl.clear();
                        _maxValueCtrl.clear();
                      });
                    },
                    child: Text('reset'.tr(ref), style: context.labelLarge?.withColor(AppColors.error)),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: () {
                      ref.read(projectStatusFilterProvider.notifier).state = _status;
                      ref.read(projectResponsibleFilterProvider.notifier).state = _responsible;
                      ref.read(projectTypeFilterProvider.notifier).state = _type;
                      ref.read(projectGovernorateFilterProvider.notifier).state = _gov;
                      ref.read(projectMinKwFilterProvider.notifier).state = _minKw;
                      ref.read(projectMaxKwFilterProvider.notifier).state = _maxKw;
                      ref.read(projectMinValueFilterProvider.notifier).state = _minValue;
                      ref.read(projectMaxValueFilterProvider.notifier).state = _maxValue;
                      ref.read(projectStartDateFilterProvider.notifier).state = _startDate;
                      ref.read(projectEndDateFilterProvider.notifier).state = _endDate;
                      ref.read(projectCurrentPageProvider.notifier).state = 1;
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

  Widget _buildRangeFilter(
    BuildContext context, 
    String label, 
    TextEditingController minCtrl, 
    TextEditingController maxCtrl,
    {required ValueChanged<String> onMinChanged, required ValueChanged<String> onMaxChanged}
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 4, bottom: 4),
          child: Text(label, style: context.labelSmall?.withColor(context.onSurfaceVariant)),
        ),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: minCtrl,
                keyboardType: TextInputType.number,
                decoration: customInputDecoration(context, 'min'.tr(ref)).copyWith(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onChanged: onMinChanged,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('-'),
            ),
            Expanded(
              child: TextFormField(
                controller: maxCtrl,
                keyboardType: TextInputType.number,
                decoration: customInputDecoration(context, 'max'.tr(ref)).copyWith(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onChanged: onMaxChanged,
              ),
            ),
          ],
        ),
      ],
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
    final hasFilters = ref.watch(projectStatusFilterProvider) != null || 
                      ref.watch(projectResponsibleFilterProvider) != null ||
                      ref.watch(projectTypeFilterProvider) != null ||
                      ref.watch(projectMinKwFilterProvider) != null ||
                      ref.watch(projectMaxKwFilterProvider) != null ||
                      ref.watch(projectMinValueFilterProvider) != null ||
                      ref.watch(projectMaxValueFilterProvider) != null ||
                      ref.watch(projectStartDateFilterProvider) != null ||
                      ref.watch(projectEndDateFilterProvider) != null ||
                      ref.watch(projectSearchQueryProvider).isNotEmpty;
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
    ref.read(projectStatusFilterProvider.notifier).state = null;
    ref.read(projectResponsibleFilterProvider.notifier).state = null;
    ref.read(projectTypeFilterProvider.notifier).state = null;
    ref.read(projectGovernorateFilterProvider.notifier).state = null;
    ref.read(projectMinKwFilterProvider.notifier).state = null;
    ref.read(projectMaxKwFilterProvider.notifier).state = null;
    ref.read(projectMinValueFilterProvider.notifier).state = null;
    ref.read(projectMaxValueFilterProvider.notifier).state = null;
    ref.read(projectStartDateFilterProvider.notifier).state = null;
    ref.read(projectEndDateFilterProvider.notifier).state = null;
    ref.read(projectSearchQueryProvider.notifier).state = '';
    ref.read(projectCurrentPageProvider.notifier).state = 1;
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

class _ProjectsPaginationFooter extends ConsumerWidget {
  const _ProjectsPaginationFooter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(filteredProjectsProvider);
    final currentPage = ref.watch(projectCurrentPageProvider);
    final itemsPerPage = ref.watch(projectItemsPerPageProvider);

    return projectsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (err, stack) => const SizedBox.shrink(),
      data: (projects) {
        final totalPages = (projects.length / itemsPerPage).ceil();
        return PaginationFooter(
          currentPage: currentPage,
          totalPages: totalPages,
          onPageChanged: (page) => ref.read(projectCurrentPageProvider.notifier).state = page,
        );
      },
    );
  }
}

class _AddProjectButton extends ConsumerWidget {
  const _AddProjectButton({this.isCompact = false});
  final bool isCompact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentUserProvider)?.role;

    if (!_canCreateOrEditProject(role)) {
      return const SizedBox.shrink();
    }

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
        onPressed: () => showProjectDialog(context, ref),
        icon: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.add_rounded, size: 20, color: AppColors.white),
        ),
        label: Text(
          'add_project'.tr(ref),
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

class _EmptyProjects extends ConsumerWidget {
  const _EmptyProjects();

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
                Icons.folder_shared_outlined, 
                size: 80, 
                color: AppColors.primaryTeal.withValues(alpha: 0.4)
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'no_projects'.tr(ref),
              style: context.headlineMedium?.black,
            ),
            const SizedBox(height: 8),
            Text(
              'try_adjusting_filters'.tr(ref),
              textAlign: TextAlign.center,
              style: context.bodyMedium?.medium.withColor(context.onSurfaceVariant),
            ),
            const SizedBox(height: 40),
            const _AddProjectButton(),
          ],
        ),
      ),
    );
  }
}

bool _canCreateOrEditProject(UserRole? role) {
  return role == UserRole.admin ||
      role == UserRole.manager ||
      role == UserRole.sales;
}

bool _canAssignProject(UserRole? role) {
  return role == UserRole.admin || role == UserRole.manager;
}

void showProjectDialog(BuildContext context, WidgetRef ref, {ProjectModel? project, int? initialCustomerId}) async {
  final customers = await ref.read(customersRepositoryProvider).getAllCustomers();
  if (!context.mounted) return;
  
  if (customers.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('please_add_customer'.tr(ref)), backgroundColor: AppColors.error));
    return;
  }

  final formKey = GlobalKey<FormState>();
  final notesCtrl = TextEditingController(text: project?.notes);
  final valueCtrl = TextEditingController(text: project == null ? '' : project.totalValue.toString());
  final kwCtrl = TextEditingController(text: project == null ? '' : project.totalKw.toString());
  final addressCtrl = TextEditingController(text: project?.address);
  final cityCtrl = TextEditingController(text: project?.city);
  final mapLinkCtrl = TextEditingController();
  
  int? selectedCustomerId = project?.customerId ?? initialCustomerId;
  int? selectedEngineerId = project?.engineerId;
  String? selectedStatus = project?.status;
  String? selectedGov = project?.governorate;
  String? selectedType = project?.name;
  DateTime? installationDate = project?.installationDate;

  final lat = project?.latitude;
  final lon = project?.longitude;
  LatLng? pickedLocation = (lat != null && lon != null) ? LatLng(lat, lon) : null;

  bool isSaving = false;
  final mapController = MapController();
  Timer? debounceTimer;

  void fetchAddressDetails(LatLng point, Function(String address, String city, String? gov) onResult) async {
    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/reverse?lat=${point.latitude}&lon=${point.longitude}&format=json&accept-language=en');
      final response = await http.get(url, headers: {'User-Agent': 'com.rsgs.crm'});
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final addressData = data['address'];
        if (addressData != null) {
          final String street = addressData['road'] ?? addressData['suburb'] ?? addressData['neighbourhood'] ?? '';
          final String city = addressData['city'] ?? addressData['town'] ?? addressData['village'] ?? addressData['suburb'] ?? '';
          final String state = addressData['state'] ?? '';
          String? matchedGov;
          for (final g in AppConstants.governorates) {
            if (state.toLowerCase().contains(g.toLowerCase()) || g.toLowerCase().contains(state.toLowerCase())) {
              matchedGov = g;
              break;
            }
          }
          onResult(street, city, matchedGov);
        }
      }
    } catch (_) {}
  }

  void autoDetectLocation(String? gov, String city, String addr, Function(LatLng) onDetected, {Function(String address, String city, String? gov)? onAddressDetected}) async {
    debounceTimer?.cancel();
    debounceTimer = Timer(const Duration(milliseconds: 800), () async {
      String query = '';
      if (addr.isNotEmpty) query = '$addr, ';
      if (city.isNotEmpty) query += '$city, ';
      if (gov != null) query += '$gov, ';
      query += 'Egypt';
      if (query.trim() == 'Egypt') return;
      try {
        final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=1');
        final response = await http.get(url, headers: {'User-Agent': 'com.rsgs.crm'});
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data is List && data.isNotEmpty) {
            final lat = double.parse(data[0]['lat']);
            final lon = double.parse(data[0]['lon']);
            final point = LatLng(lat, lon);
            onDetected(point);
            mapController.move(point, 16);
            if (onAddressDetected != null) fetchAddressDetails(point, onAddressDetected);
          }
        }
      } catch (_) {}
    });
  }

  void parseAndSetLocationFromLink(String link, Function(LatLng) onDetected, {Function(String address, String city, String? gov)? onAddressDetected}) async {
    if (link.isEmpty) return;
    try {
      LatLng? point;
      final coordRegExp = RegExp(r'(-?\d+\.\d+)\s*,\s*(-?\d+\.\d+)');
      final coordMatch = coordRegExp.firstMatch(link.trim());
      if (coordMatch != null) {
        point = LatLng(double.parse(coordMatch.group(1)!), double.parse(coordMatch.group(2)!));
      } else {
        String finalUrl = link.trim();
        if (finalUrl.contains('goo.gl') || finalUrl.contains('maps.app.goo.gl')) {
          final client = http.Client();
          final request = http.Request('GET', Uri.parse(finalUrl))..followRedirects = false;
          final response = await client.send(request);
          if (response.isRedirect) finalUrl = response.headers['location'] ?? finalUrl;
        }
        final pathCoords = RegExp(r'@(-?\d+\.\d+),(-?\d+\.\d+)').firstMatch(finalUrl);
        if (pathCoords != null) {
          point = LatLng(double.parse(pathCoords.group(1)!), double.parse(pathCoords.group(2)!));
        } else {
          final dataCoords = RegExp(r'!3d(-?\d+\.\d+)!4d(-?\d+\.\d+)').firstMatch(finalUrl);
          if (dataCoords != null) point = LatLng(double.parse(dataCoords.group(1)!), double.parse(dataCoords.group(2)!));
        }
      }
      if (point != null) {
        onDetected(point);
        mapController.move(point, 16);
        if (onAddressDetected != null) fetchAddressDetails(point, onAddressDetected);
      }
    } catch (_) {}
  }

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => Consumer(
        builder: (context, ref, _) {
          final engineers = ref.watch(engineersProvider).value ?? [];
          final currentUser = ref.watch(currentUserProvider);
          final canAssignEngineer = _canAssignProject(currentUser?.role);
          final isNarrow = MediaQuery.of(context).size.width < 650;

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
                            project == null ? 'add_project'.tr(ref) : 'edit'.tr(ref),
                            style: isNarrow ? context.headlineSmall : context.headlineMedium,
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
                              _sectionHeader(context, 'basic_info'.tr(ref), icon: Icons.info_outline_rounded),
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
                                    _labeledField(
                                      context, 
                                      'name'.tr(ref), 
                                      _DialogMenuField<String>(
                                        initialValue: selectedType,
                                        label: 'name'.tr(ref),
                                        icon: Icons.solar_power_rounded,
                                        items: AppConstants.projectTypes.map((t) => _DialogMenuItem(value: t, label: t.tr(ref))).toList(),
                                        onSelected: (v) => setState(() => selectedType = v),
                                        enabled: !isSaving,
                                        validator: (v) => v == null ? 'required'.tr(ref) : null,
                                      ),
                                      required: true,
                                    ),
                                    const SizedBox(height: 12),
                                    if (isNarrow) ...[
                                      _labeledField(
                                        context,
                                        'customer'.tr(ref),
                                        _DialogMenuField<int?>(
                                          initialValue: selectedCustomerId,
                                          label: 'select_customer'.tr(ref),
                                          icon: Icons.person_rounded,
                                          items: customers.map((c) => _DialogMenuItem(value: c.id, label: c.name)).toList(),
                                          onSelected: (v) => setState(() => selectedCustomerId = v),
                                          enabled: !isSaving,
                                          validator: (v) => v == null ? 'required'.tr(ref) : null,
                                        ),
                                        required: true,
                                      ),
                                      const SizedBox(height: 12),
                                      _labeledField(
                                        context,
                                        'engineer'.tr(ref),
                                        _DialogMenuField<int?>(
                                          initialValue: selectedEngineerId,
                                          label: 'assign_engineer'.tr(ref),
                                          icon: Icons.engineering_rounded,
                                          items: engineers.map((e) => _DialogMenuItem(value: e.id, label: e.fullName)).toList(),
                                          onSelected: (v) => setState(() => selectedEngineerId = v),
                                          enabled: !isSaving && canAssignEngineer,
                                          validator: (v) => v == null ? 'required'.tr(ref) : null,
                                        ),
                                        required: true,
                                      ),
                                    ] else ...[
                                      Row(
                                        children: [
                                          Expanded(child: _labeledField(
                                            context,
                                            'customer'.tr(ref),
                                            _DialogMenuField<int?>(
                                              initialValue: selectedCustomerId,
                                              label: 'select_customer'.tr(ref),
                                              icon: Icons.person_rounded,
                                              items: customers.map((c) => _DialogMenuItem(value: c.id, label: c.name)).toList(),
                                              onSelected: (v) => setState(() => selectedCustomerId = v),
                                              enabled: !isSaving,
                                              validator: (v) => v == null ? 'required'.tr(ref) : null,
                                            ),
                                            required: true,
                                          )),
                                          const SizedBox(width: 16),
                                          Expanded(child: _labeledField(
                                            context,
                                            'engineer'.tr(ref),
                                            _DialogMenuField<int?>(
                                              initialValue: selectedEngineerId,
                                              label: 'assign_engineer'.tr(ref),
                                              icon: Icons.engineering_rounded,
                                              items: engineers.map((e) => _DialogMenuItem(value: e.id, label: e.fullName)).toList(),
                                              onSelected: (v) => setState(() => selectedEngineerId = v),
                                              enabled: !isSaving && canAssignEngineer,
                                              validator: (v) => v == null ? 'required'.tr(ref) : null,
                                            ),
                                            required: true,
                                          )),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                              _sectionHeader(context, 'project_details'.tr(ref), icon: Icons.folder_shared_outlined),
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
                                      _labeledField(
                                        context,
                                        'status'.tr(ref),
                                        _DialogMenuField<String>(
                                          initialValue: selectedStatus,
                                          label: 'select_status'.tr(ref),
                                          icon: Icons.flag_outlined,
                                          items: AppConstants.projectStatuses.map((s) => _DialogMenuItem(value: s, label: s.tr(ref))).toList(),
                                          onSelected: (v) => setState(() => selectedStatus = v),
                                          enabled: !isSaving,
                                          validator: (v) => v == null ? 'required'.tr(ref) : null,
                                        ),
                                        required: true,
                                      ),
                                      const SizedBox(height: 12),
                                      _labeledField(context, 'total_value'.tr(ref), TextFormField(controller: valueCtrl, decoration: customInputDecoration(context, 'total_value'.tr(ref), icon: Icons.payments_rounded), keyboardType: TextInputType.number, enabled: !isSaving)),
                                      const SizedBox(height: 12),
                                      _labeledField(context, 'total_kw'.tr(ref), TextFormField(controller: kwCtrl, decoration: customInputDecoration(context, 'total_kw'.tr(ref), icon: Icons.bolt_rounded), keyboardType: TextInputType.number, enabled: !isSaving)),
                                      const SizedBox(height: 12),
                                      _labeledField(
                                        context,
                                        'created_date'.tr(ref),
                                        _DatePickerField(
                                          label: 'select_date'.tr(ref),
                                          selectedDate: project?.createdDate ?? DateTime.now(),
                                          onChanged: (_) {},
                                          enabled: false,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      _labeledField(
                                        context,
                                        'installation_date'.tr(ref),
                                        _DatePickerField(
                                          label: 'select_date'.tr(ref),
                                          selectedDate: installationDate,
                                          onChanged: isSaving ? (_) {} : (d) => setState(() => installationDate = d),
                                        ),
                                      ),
                                    ] else ...[
                                      Row(
                                        children: [
                                          Expanded(child: _labeledField(
                                            context,
                                            'status'.tr(ref),
                                            _DialogMenuField<String>(
                                              initialValue: selectedStatus,
                                              label: 'select_status'.tr(ref),
                                              icon: Icons.flag_outlined,
                                              items: AppConstants.projectStatuses.map((s) => _DialogMenuItem(value: s, label: s.tr(ref))).toList(),
                                              onSelected: (v) => setState(() => selectedStatus = v),
                                              enabled: !isSaving,
                                              validator: (v) => v == null ? 'required'.tr(ref) : null,
                                            ),
                                            required: true,
                                          )),
                                          const SizedBox(width: 16),
                                          Expanded(child: _labeledField(context, 'total_value'.tr(ref), TextFormField(controller: valueCtrl, decoration: customInputDecoration(context, 'total_value'.tr(ref), icon: Icons.payments_rounded), keyboardType: TextInputType.number, enabled: !isSaving))),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(child: _labeledField(context, 'total_kw'.tr(ref), TextFormField(controller: kwCtrl, decoration: customInputDecoration(context, 'total_kw'.tr(ref), icon: Icons.bolt_rounded), keyboardType: TextInputType.number, enabled: !isSaving))),
                                          const SizedBox(width: 16),
                                          Expanded(child: _labeledField(
                                            context,
                                            'created_date'.tr(ref),
                                            _DatePickerField(
                                              label: 'select_date'.tr(ref),
                                              selectedDate: project?.createdDate ?? DateTime.now(),
                                              onChanged: (_) {},
                                              enabled: false,
                                            ),
                                          )),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      _labeledField(
                                        context,
                                        'installation_date'.tr(ref),
                                        _DatePickerField(
                                          label: 'select_date'.tr(ref),
                                          selectedDate: installationDate,
                                          onChanged: isSaving ? (_) {} : (d) => setState(() => installationDate = d),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 24),
                                    _sectionHeader(context, 'location'.tr(ref), icon: Icons.map_outlined),
                                    const SizedBox(height: 12),
                                    if (isNarrow) ...[
                                      _labeledField(
                                        context,
                                        'governorate'.tr(ref),
                                        _DialogMenuField<String>(
                                          initialValue: selectedGov,
                                          label: 'select_gov'.tr(ref),
                                          icon: Icons.map_outlined,
                                          items: AppConstants.governorates.map((g) => _DialogMenuItem(value: g, label: g.tr(ref))).toList(),
                                          onSelected: (v) {
                                            setState(() => selectedGov = v);
                                            autoDetectLocation(selectedGov, cityCtrl.text, addressCtrl.text, (p) => setState(() => pickedLocation = p));
                                          },
                                          enabled: !isSaving,
                                          validator: (v) => v == null ? 'required'.tr(ref) : null,
                                        ),
                                        required: true,
                                      ),
                                      const SizedBox(height: 12),
                                      _labeledField(context, 'city'.tr(ref), TextFormField(controller: cityCtrl, decoration: customInputDecoration(context, 'city'.tr(ref), icon: Icons.location_city_outlined), enabled: !isSaving)),
                                    ] else ...[
                                      Row(
                                        children: [
                                          Expanded(child: _labeledField(
                                            context,
                                            'governorate'.tr(ref),
                                            _DialogMenuField<String>(
                                              initialValue: selectedGov,
                                              label: 'select_gov'.tr(ref),
                                              icon: Icons.map_outlined,
                                              items: AppConstants.governorates.map((g) => _DialogMenuItem(value: g, label: g.tr(ref))).toList(),
                                              onSelected: (v) {
                                                setState(() => selectedGov = v);
                                                autoDetectLocation(selectedGov, cityCtrl.text, addressCtrl.text, (p) => setState(() => pickedLocation = p));
                                              },
                                              enabled: !isSaving,
                                              validator: (v) => v == null ? 'required'.tr(ref) : null,
                                            ),
                                            required: true,
                                          )),
                                          const SizedBox(width: 16),
                                          Expanded(child: _labeledField(context, 'city'.tr(ref), TextFormField(controller: cityCtrl, decoration: customInputDecoration(context, 'city'.tr(ref), icon: Icons.location_city_outlined), enabled: !isSaving))),
                                        ],
                                      ),
                                    ],
                                    const SizedBox(height: 12),
                                    _labeledField(context, 'address'.tr(ref), TextFormField(controller: addressCtrl, decoration: customInputDecoration(context, 'address'.tr(ref), icon: Icons.home_outlined), enabled: !isSaving)),
                                    const SizedBox(height: 12),
                                    _labeledField(context, 'google_maps_link'.tr(ref), TextFormField(
                                      controller: mapLinkCtrl, 
                                      decoration: customInputDecoration(context, 'google_maps_hint'.tr(ref), icon: Icons.link_rounded), 
                                      onChanged: (v) => parseAndSetLocationFromLink(v, (p) => setState(() => pickedLocation = p))
                                    )),
                                    const SizedBox(height: 12),
                                    Container(
                                      height: 240,
                                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: context.borderColor)),
                                      clipBehavior: Clip.antiAlias,
                                      child: FlutterMap(
                                        mapController: mapController,
                                        options: MapOptions(
                                          initialCenter: pickedLocation ?? const LatLng(30.0444, 31.2357),
                                          initialZoom: pickedLocation != null ? 15 : 6,
                                          onTap: (tapPosition, point) {
                                            if (!isSaving) setState(() => pickedLocation = point);
                                          },
                                        ),
                                        children: [
                                          TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.rsgs.crm'),
                                          if (pickedLocation != null) MarkerLayer(markers: [Marker(point: pickedLocation!, width: 40, height: 40, child: const Icon(Icons.location_on, color: AppColors.error, size: 40))]),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
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
                          child: Text('cancel'.tr(ref), style: context.labelLarge?.primary),
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
                                final String projectNumber;
                                if (project == null) {
                                  projectNumber = await ref.read(projectsRepositoryProvider).newProjectNumber();
                                } else {
                                  projectNumber = project.projectNumber;
                                }

                                final model = ProjectModel(
                                  id: project?.id ?? 0,
                                  projectNumber: projectNumber,
                                  name: selectedType ?? '',
                                  customerId: selectedCustomerId!,
                                  engineerId: selectedEngineerId,
                                  status: selectedStatus!,
                                  totalValue: double.tryParse(valueCtrl.text) ?? 0,
                                  totalKw: double.tryParse(kwCtrl.text) ?? 0,
                                  notes: notesCtrl.text.trim(),
                                  createdDate: project?.createdDate,
                                  installationDate: installationDate,
                                  address: addressCtrl.text.trim(),
                                  governorate: selectedGov,
                                  city: cityCtrl.text.trim(),
                                  latitude: pickedLocation?.latitude,
                                  longitude: pickedLocation?.longitude,
                                );

                                if (project == null) {
                                  await ref.read(projectsRepositoryProvider).createProject(model);
                                } else {
                                  await ref.read(projectsRepositoryProvider).updateProject(model);
                                }
                                DataRefreshCoordinator.refresh(ref);
                                ref.invalidate(projectsStreamProvider);
                                ref.invalidate(projectsWithDetailsProvider);
                                ref.invalidate(filteredProjectsProvider);
                                if (context.mounted) Navigator.pop(context);
                              } catch (e) {
                                setState(() => isSaving = false);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${'error'.tr(ref)}: $e'), backgroundColor: AppColors.error));
                                }
                              }
                            },
                            child: Text(isSaving ? 'saving'.tr(ref) : 'save'.tr(ref), style: context.labelLarge?.white),
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
      ),
    ),
  );
}

void _showDeleteConfirmation(BuildContext context, WidgetRef ref, ProjectModel project) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('delete'.tr(ref), style: context.titleLarge?.bold.withColor(context.errorColor)),
      content: Text('${'delete'.tr(ref)} ${project.name}?', style: context.bodyLarge),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('cancel'.tr(ref), style: context.labelLarge?.withColor(context.onSurfaceVariant))),
        FilledButton(
          onPressed: () async {
            try {
              await ref.read(projectsRepositoryProvider).deleteProject(project.id);
              DataRefreshCoordinator.refresh(ref);
              ref.invalidate(projectsStreamProvider);
              ref.invalidate(projectsWithDetailsProvider);
              ref.invalidate(filteredProjectsProvider);
              if (context.mounted) Navigator.pop(context);
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${'error'.tr(ref)}: $e'), backgroundColor: AppColors.error));
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

class _AssignedUserBadge extends ConsumerWidget {
  const _AssignedUserBadge({this.userId});
  final int? userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (userId == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: context.appTheme.textMuted.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(10), border: Border.all(color: context.appTheme.textMuted.withValues(alpha: 0.1))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.help_outline_rounded, size: 12, color: context.appTheme.textMuted), const SizedBox(width: 8), Text('unassigned'.tr(ref), style: context.labelSmall?.withColor(context.appTheme.textMuted).copyWith(fontStyle: FontStyle.italic))]),
      );
    }
    final engineersAsync = ref.watch(engineersProvider);
    return engineersAsync.when(
      data: (users) {
        final user = users.firstWhere((u) => u.id == userId, orElse: () => UserModel(id: 0, username: '', passwordHash: '', fullName: 'Unknown', email: '', role: ''));
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
              Flexible(child: Text(user.fullName, style: context.labelMedium?.bold, overflow: TextOverflow.ellipsis)),
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

class _ProjectStatusBadge extends ConsumerWidget {
  const _ProjectStatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Color color = context.appTheme.textMuted;
    if (status == 'Completed') color = AppColors.success;
    if (status == 'Cancelled') color = AppColors.error;
    if (status == 'Approved') color = AppColors.info;
    if (status == 'In Progress') color = AppColors.indigo;
    if (status == 'Pending') color = AppColors.warning;
    if (status == 'Draft') color = AppColors.pink;

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
        Text(title, style: context.titleMedium?.bold.primary.withHeight(1.0)),
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
              TextSpan(text: label, style: context.labelSmall?.withColor(context.onSurfaceVariant)),
              if (required) const TextSpan(text: ' *', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
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
      controller: TextEditingController(text: selectedDate == null ? '' : selectedDate!.toFullDate()),
      readOnly: true,
      enabled: enabled,
      onTap: !enabled ? null : () async {
        final d = await showDatePicker(
          context: context,
          initialDate: selectedDate ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
          builder: (context, child) => Theme(
            data: Theme.of(context).copyWith(
              colorScheme: Theme.of(context).colorScheme.copyWith(primary: AppColors.primaryTeal),
            ),
            child: child!,
          ),
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
