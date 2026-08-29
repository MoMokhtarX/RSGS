import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/data_refresh_service.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/typography_extensions.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/localization/language_provider.dart';
import '../../../core/localization/date_formatter.dart';
import '../../auth/data/auth_repository.dart';
import '../../customers/data/customers_repository.dart';
import '../data/activity_repository.dart';
import '../../../core/models/app_models.dart';
import '../../../core/permissions/user_role.dart';

// --- State Providers ---

final activitySearchQueryProvider = StateProvider<String>((ref) => '');
final activityDateFilterProvider = StateProvider<DateTime?>((ref) => null);
final activityCurrentPageProvider = StateProvider<int>((ref) => 1);
final activityItemsPerPageProvider = StateProvider<int>((ref) => 10);

final filteredActivitiesProvider = Provider.family<AsyncValue<List<ActivityModel>>, int?>((ref, userId) {
  final activitiesAsync = ref.watch(activitiesProvider(userId));
  final searchQuery = ref.watch(activitySearchQueryProvider).toLowerCase();
  final selectedDate = ref.watch(activityDateFilterProvider);

  return activitiesAsync.whenData((activities) {
    var filtered = activities;

    // Exact Date Filter
    if (selectedDate != null) {
      final targetDate = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
      
      filtered = filtered.where((a) {
        final localDate = a.createdAt.toLocal();
        final activityDate = DateTime(localDate.year, localDate.month, localDate.day);
        return activityDate.isAtSameMomentAs(targetDate);
      }).toList();
    }

    // Search Filter
    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((a) {
        return a.userName.toLowerCase().contains(searchQuery) ||
            a.action.toLowerCase().contains(searchQuery) ||
            a.details.toLowerCase().contains(searchQuery);
      }).toList();
    }
    
    return filtered;
  });
});

// --- Main Screen ---

class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final isAdmin = user?.role == UserRole.admin;
    final targetUserId = isAdmin ? null : user?.id;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isMobile = width < 700;
        final isTablet = width >= 700 && width < 1100;
        
        return Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(16, isMobile ? 8 : 12, 16, 0),
                child: _ActivityFiltersBar(targetUserId: targetUserId),
              ),
              SizedBox(height: isMobile ? 6 : 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: context.surfaceColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: context.borderColor, width: 1.2),
                    ),
                    child: _ActivityView(
                      targetUserId: targetUserId, 
                      isMobile: isMobile,
                      isTablet: isTablet,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(vertical: isMobile ? 6 : 12, horizontal: 16),
                child: _ActivityPaginationFooter(targetUserId: targetUserId),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ActivityView extends ConsumerWidget {
  const _ActivityView({
    required this.targetUserId, 
    required this.isMobile,
    required this.isTablet,
  });
  final int? targetUserId;
  final bool isMobile;
  final bool isTablet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activitiesAsync = ref.watch(filteredActivitiesProvider(targetUserId));
    final currentPage = ref.watch(activityCurrentPageProvider);
    final itemsPerPage = ref.watch(activityItemsPerPageProvider);

    return activitiesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('${'error'.tr(ref)}: $err')),
      data: (activities) {
        if (activities.isEmpty) return const _EmptyActivities();
        
        final totalPages = (activities.length / itemsPerPage).ceil();
        final actualPage = currentPage > totalPages ? (totalPages > 0 ? totalPages : 1) : currentPage;
        final startIndex = (actualPage - 1) * itemsPerPage;
        final endIndex = (startIndex + itemsPerPage).clamp(0, activities.length);
        
        final pageActivities = activities.sublist(startIndex, endIndex);

        if (isMobile) {
          return ListView.separated(
            key: const PageStorageKey('activities_mobile_list'),
            padding: const EdgeInsets.all(12),
            itemCount: pageActivities.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              return _ActivityCard(
                activity: pageActivities[index],
              );
            },
          );
        }

        return Column(
          children: [
            _TableHeader(isTablet: isTablet),
            Expanded(
              child: ListView.builder(
                key: const PageStorageKey('activities_table_list'),
                padding: const EdgeInsets.only(top: 4),
                itemCount: pageActivities.length,
                itemBuilder: (context, index) {
                  return _TableRow(
                    key: ValueKey('activity_row_${pageActivities[index].id}'),
                    activity: pageActivities[index],
                    index: startIndex + index + 1,
                    isTablet: isTablet,
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
  const _TableHeader({required this.isTablet});
  final bool isTablet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: context.appTheme.surfaceSubtle,
        border: Border(
          bottom: BorderSide(color: context.borderColor, width: 1.2),
        ),
      ),
      child: Row(
        children: [
          _buildHeaderCell(context, ref, '#', null, width: 60, isCentered: true, hasDivider: true),
          const SizedBox(width: 12),
          _buildHeaderCell(context, ref, 'user'.tr(ref), Icons.person_outline_rounded, flex: 2),
          const SizedBox(width: 12),
          _buildHeaderCell(context, ref, 'action'.tr(ref), Icons.bolt_outlined, flex: 2),
          const SizedBox(width: 12),
          if (!isTablet) ...[
            _buildHeaderCell(context, ref, 'reference'.tr(ref), Icons.link_rounded, flex: 2),
            const SizedBox(width: 12),
          ],
          _buildHeaderCell(context, ref, 'details'.tr(ref), Icons.info_outline_rounded, flex: 4),
          const SizedBox(width: 12),
          _buildHeaderCell(context, ref, 'time'.tr(ref), Icons.access_time_rounded, flex: 2),
          const SizedBox(width: 30),
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
                    style: context.labelSmall?.withWeight(FontWeight.w700).withColor(
                      context.onSurfaceVariant,
                    ).withLetterSpacing(0.8),
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
  const _TableRow({super.key, required this.activity, required this.index, required this.isTablet});
  final ActivityModel activity;
  final int index;
  final bool isTablet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actionColor = _getActionColor(activity.action);

    return Tooltip(
      message: 'view_details'.tr(ref),
      child: Container(
        decoration: BoxDecoration(
          color: index % 2 == 0 ? context.surfaceColor : context.appTheme.surfaceSubtle.withValues(alpha: 0.1),
          border: Border(
            bottom: BorderSide(color: context.borderColor, width: 1),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showActivityDetails(context, activity, ref),
            hoverColor: actionColor.withValues(alpha: 0.08),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  SizedBox(
                    width: 60,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${activity.id}',
                            textAlign: TextAlign.center,
                            style: context.labelSmall?.bold.withColor(context.appTheme.textMuted),
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
                    flex: 2,
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: AppColors.primaryTeal.withValues(alpha: 0.1),
                          child: Text(
                            activity.userName.isNotEmpty ? activity.userName[0].toUpperCase() : '?',
                            style: context.labelSmall?.bold.primary.withSize(10),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            activity.userName,
                            style: context.titleSmall?.bold,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: _ActionBadge(action: activity.action, color: actionColor),
                    ),
                  ),
                  if (!isTablet) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: activity.entityType != null 
                            ? _EntityBadge(type: activity.entityType!, id: activity.entityId)
                            : Text('-', style: context.bodyMedium?.withColor(context.appTheme.textMuted)),
                      ),
                    ),
                  ],
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 4,
                    child: Text(
                      _localizeActivityMessage(activity.details, ref, simplified: true).replaceAll('\n', ' '),
                      style: context.bodyMedium?.medium.withColor(context.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Text(
                      activity.createdAt.toLocal().format('date_time_format'.tr(ref), ref.watch(localeProvider).languageCode),
                      style: context.labelMedium?.semiBold.withColor(context.onSurfaceVariant).copyWith(
                        letterSpacing: ref.watch(localeProvider).languageCode == 'ar' ? 1.1 : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right_rounded, size: 20, color: context.appTheme.textMuted.withValues(alpha: 0.4)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActivityCard extends ConsumerWidget {
  const _ActivityCard({required this.activity});
  final ActivityModel activity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actionColor = _getActionColor(activity.action);

    return Tooltip(
      message: 'view_details'.tr(ref),
      child: InkWell(
        onTap: () => _showActivityDetails(context, activity, ref),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.borderColor, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
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
                      activity.userName,
                      style: context.titleMedium?.bold,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '#${activity.id}',
                    style: context.labelSmall?.bold.withColor(context.appTheme.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ActionBadge(action: activity.action, color: actionColor),
                  if (activity.entityType != null)
                    _EntityBadge(type: activity.entityType!, id: activity.entityId),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                _localizeActivityMessage(activity.details, ref, simplified: true),
                style: context.bodyMedium?.medium.withColor(context.onSurfaceVariant).withHeight(1.4),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(Icons.access_time_rounded, size: 14, color: context.appTheme.textMuted),
                  const SizedBox(width: 6),
                  Text(
                    activity.createdAt.toLocal().format('date_time_format'.tr(ref), ref.watch(localeProvider).languageCode),
                    style: context.labelSmall?.semiBold.withColor(context.appTheme.textMuted).copyWith(
                      letterSpacing: ref.watch(localeProvider).languageCode == 'ar' ? 1.1 : null,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.chevron_right_rounded, size: 20, color: actionColor.withValues(alpha: 0.5)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityFiltersBar extends ConsumerWidget {
  const _ActivityFiltersBar({this.targetUserId});
  final int? targetUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 700;
        
        if (isMobile) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ActivitySearchField(
                height: 44,
                hint: 'search_activity_hint'.tr(ref),
                icon: Icons.search_rounded,
                onChanged: (value) {
                  ref.read(activitySearchQueryProvider.notifier).state = value;
                  ref.read(activityCurrentPageProvider.notifier).state = 1;
                },
              ),
              const SizedBox(height: 8),
              _buildDatePicker(context, ref, height: 44),
              const SizedBox(height: 8),
              if (ref.watch(activityDateFilterProvider) != null || ref.watch(activitySearchQueryProvider).isNotEmpty)
                const _ClearFiltersButton(),
            ],
          );
        }

        return Container(
          width: double.infinity,
          height: 68,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: context.borderColor, width: 1.2),
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
              const SizedBox(width: 8),
              Expanded(
                flex: 4,
                child: _ActivitySearchField(
                  height: 48,
                  hint: 'search_activity_hint'.tr(ref),
                  icon: Icons.search_rounded,
                  onChanged: (value) {
                    ref.read(activitySearchQueryProvider.notifier).state = value;
                    ref.read(activityCurrentPageProvider.notifier).state = 1;
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: _buildDatePicker(context, ref, height: 48),
              ),
              const SizedBox(width: 8),
              if (ref.watch(activityDateFilterProvider) != null || ref.watch(activitySearchQueryProvider).isNotEmpty) ...[
                const SizedBox(width: 4),
                const _ClearFiltersButton(),
                const SizedBox(width: 4),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildDatePicker(BuildContext context, WidgetRef ref, {double height = 44}) {
    final selectedDate = ref.watch(activityDateFilterProvider);
    
    return _FilterMenu<DateTime?>(
      label: selectedDate != null ? selectedDate.format('date_format'.tr(ref), ref.watch(localeProvider).languageCode) : 'date'.tr(ref),
      icon: Icons.calendar_today_rounded,
      value: selectedDate,
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: selectedDate ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.primaryTeal,
                ),
              ),
              child: child!,
            );
          },
        );
        if (date != null) {
          ref.read(activityDateFilterProvider.notifier).state = date;
          ref.read(activityCurrentPageProvider.notifier).state = 1;
        }
      },
    );
  }
}

class _FilterMenu<T> extends StatefulWidget {
  const _FilterMenu({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.value,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final T? value;

  @override
  State<_FilterMenu<T>> createState() => _FilterMenuState<T>();
}

class _FilterMenuState<T> extends State<_FilterMenu<T>> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.value != null;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          height: 48,
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primaryTeal.withValues(alpha: 0.1)
                : _isHovered ? AppColors.primaryTeal.withValues(alpha: 0.06) : context.onSurfaceColor.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _isHovered ? AppColors.primaryTeal.withValues(alpha: 0.2) : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                widget.icon,
                size: 18,
                color: isSelected ? AppColors.primaryTeal : AppColors.textSecondary,
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
              if (isSelected)
                const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.primaryTeal),
            ],
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
    return Tooltip(
      message: 'clear_filters'.tr(ref),
      child: IconButton(
        onPressed: () {
          ref.read(activityDateFilterProvider.notifier).state = null;
          ref.read(activitySearchQueryProvider.notifier).state = '';
          ref.read(activityCurrentPageProvider.notifier).state = 1;
        },
        icon: const Icon(Icons.filter_alt_off_outlined, color: AppColors.error),
      ),
    );
  }
}

class _ActivitySearchField extends StatefulWidget {
  const _ActivitySearchField({required this.hint, required this.icon, this.onChanged, this.height = 48});
  final String hint;
  final IconData icon;
  final void Function(String)? onChanged;
  final double height;

  @override
  State<_ActivitySearchField> createState() => _ActivitySearchFieldState();
}

class _ActivitySearchFieldState extends State<_ActivitySearchField> {
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
                  style: context.labelMedium?.bold,
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

class _EmptyActivities extends ConsumerWidget {
  const _EmptyActivities();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: AppColors.primaryTeal.withValues(alpha: 0.04),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.history_rounded,
              size: 80,
              color: AppColors.primaryTeal.withValues(alpha: 0.4)
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'no_activities'.tr(ref),
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
    );
  }
}

class _ActionBadge extends ConsumerWidget {
  const _ActionBadge({required this.action, required this.color});
  final String action;
  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.15), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getActionIcon(action), size: 12, color: color),
          const SizedBox(width: 6),
          Text(
            _localizeAction(action, ref).toUpperCase(),
            style: context.labelSmall?.bold.withColor(color).withSize(10).withLetterSpacing(0.6),
          ),
        ],
      ),
    );
  }

  IconData _getActionIcon(String action) {
    final act = action.toLowerCase();
    if (act.contains('login')) return Icons.login_rounded;
    if (act.contains('logout')) return Icons.logout_rounded;
    if (act.contains('create') || act.contains('add')) return Icons.add_circle_outline_rounded;
    if (act.contains('update') || act.contains('edit')) return Icons.edit_note_rounded;
    if (act.contains('delete') || act.contains('remove')) return Icons.delete_outline_rounded;
    if (act.contains('status')) return Icons.sync_rounded;
    return Icons.bolt_rounded;
  }
}

String _localizeAction(String action, WidgetRef ref) {
  final act = action.toLowerCase();
  if (act.contains('login')) return 'action_login'.tr(ref);
  if (act.contains('logout')) return 'action_logout'.tr(ref);
  if (act.contains('create') || act.contains('add')) return 'action_create'.tr(ref);
  if (act.contains('update') || act.contains('edit')) return 'action_update'.tr(ref);
  if (act.contains('delete') || act.contains('remove')) return 'action_delete'.tr(ref);
  if (act.contains('status')) return 'action_status'.tr(ref);
  return action;
}

class _EntityBadge extends ConsumerWidget {
  const _EntityBadge({required this.type, this.id});
  final String type;
  final int? id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (color, icon) = _getEntityInfo(type);
    
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.15), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Text(
            _localizeEntityType(type, ref).toUpperCase(),
            style: context.labelSmall?.bold.withColor(color).withSize(9).withLetterSpacing(0.6),
          ),
          if (id != null) ...[
            const SizedBox(width: 4),
            Text(
              '#$id',
              style: context.labelSmall?.bold.withColor(color).withSize(9),
            ),
          ],
        ],
      ),
    );
  }

  (Color, IconData) _getEntityInfo(String type) {
    final t = type.toLowerCase();
    switch (t) {
      case 'customer': return (AppColors.primaryTeal, Icons.person_rounded);
      case 'project': return (AppColors.info, Icons.folder_shared_rounded);
      case 'quotation': return (Colors.indigo, Icons.request_quote_rounded);
      case 'user': return (Colors.blueGrey, Icons.manage_accounts_rounded);
      case 'invoice': return (Colors.amber.shade800, Icons.receipt_long_rounded);
      case 'payment': return (AppColors.success, Icons.payments_rounded);
      case 'product': return (Colors.deepPurple, Icons.inventory_2_rounded);
      case 'auth': return (Colors.grey, Icons.security_rounded);
      default: return (Colors.grey, Icons.link_rounded);
    }
  }
}

String _localizeEntityType(String type, WidgetRef ref) {
  final t = type.toLowerCase();
  if (t == 'customer') return 'customer'.tr(ref);
  if (t == 'project') return 'project'.tr(ref);
  if (t == 'quotation') return 'quotation'.tr(ref);
  if (t == 'user') return 'user'.tr(ref);
  if (t == 'invoice') return 'invoice'.tr(ref);
  if (t == 'payment') return 'payments'.tr(ref);
  if (t == 'product') return 'product'.tr(ref);
  return type;
}

class _ActivityPaginationFooter extends ConsumerWidget {
  const _ActivityPaginationFooter({this.targetUserId});
  final int? targetUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activitiesAsync = ref.watch(filteredActivitiesProvider(targetUserId));
    final currentPage = ref.watch(activityCurrentPageProvider);
    final itemsPerPage = ref.watch(activityItemsPerPageProvider);

    return activitiesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (err, stack) => const SizedBox.shrink(),
      data: (activities) {
        final totalPages = (activities.length / itemsPerPage).ceil();
        return PaginationFooter(
          currentPage: currentPage,
          totalPages: totalPages,
          onPageChanged: (page) => ref.read(activityCurrentPageProvider.notifier).state = page,
        );
      },
    );
  }
}

void _navigateToEntity(BuildContext context, String type, int id) {
  if (type.toLowerCase() == 'customer') {
    context.go('/customers/$id');
  } else if (type.toLowerCase() == 'project') {
    context.go('/projects/$id');
  }
}

void _showActivityDetails(BuildContext context, ActivityModel activity, WidgetRef ref) {
  final actionColor = _getActionColor(activity.action);
  final hasReference = activity.entityType != null && activity.entityId != null;
  final screenWidth = MediaQuery.of(context).size.width;
  final isMobile = screenWidth < 600;

  showDialog(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: context.surfaceColor,
      insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 40, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 550),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 20 : 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'activity_details'.tr(ref),
                      style: (isMobile ? context.titleLarge : context.headlineSmall)?.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      _sectionHeader(context, 'basic_info'.tr(ref), icon: Icons.info_outline_rounded),
                      const SizedBox(height: 12),
                      Container(
                        padding: EdgeInsets.all(isMobile ? 16 : 20),
                        decoration: BoxDecoration(
                          color: context.appTheme.surfaceSubtle,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: context.borderColor),
                        ),
                        child: Column(
                          children: [
                            _detailRow(context, 'performed_by'.tr(ref), activity.userName, icon: Icons.person_outline_rounded),
                            const Divider(height: 32),
                            _detailRow(context, 'action'.tr(ref), '', 
                              trailing: _ActionBadge(action: activity.action, color: actionColor),
                              icon: Icons.bolt_outlined
                            ),
                            const Divider(height: 32),
                            _detailRow(context, 'time'.tr(ref), activity.createdAt.toLocal().format('date_time_format'.tr(ref), ref.watch(localeProvider).languageCode), icon: Icons.access_time_rounded),
                            if (activity.entityType != null) ...[
                              const Divider(height: 32),
                              _detailRow(context, 'reference'.tr(ref), '', 
                                trailing: _EntityBadge(type: activity.entityType!, id: activity.entityId),
                                icon: Icons.link_rounded
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      _sectionHeader(context, 'details'.tr(ref), icon: Icons.description_outlined),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(isMobile ? 16 : 20),
                        decoration: BoxDecoration(
                          color: context.appTheme.surfaceSubtle,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: context.borderColor),
                        ),
                        child: _buildEnhancedDetails(context, activity.details, ref),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('close'.tr(ref)),
                  ),
                  if (hasReference)
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _navigateToEntity(context, activity.entityType!, activity.entityId!);
                      },
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      label: Text('view_reference'.tr(ref)),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryTeal,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
}

Widget _buildEnhancedDetails(BuildContext context, String details, WidgetRef ref) {
  final localized = _localizeActivityMessage(details, ref);
  final changesLabel = 'changes_log'.tr(ref);
  
  if (!localized.contains(changesLabel) && !details.contains('Changes:')) {
    return Text(
      localized,
      style: context.bodyLarge?.withHeight(1.5),
    );
  }

  final splitKey = localized.contains(changesLabel) ? changesLabel : 'Changes:';
  final parts = localized.split(splitKey);
  final header = parts[0].trim();
  final changesStr = parts[1].trim();
  final changes = changesStr.split(';').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        header,
        style: context.bodyLarge?.bold.withHeight(1.5),
      ),
      if (changes.isNotEmpty) ...[
        const SizedBox(height: 16),
        ...changes.map((change) => _buildChangeItem(context, change, ref)),
      ],
    ],
  );
}

Widget _buildChangeItem(BuildContext context, String change, WidgetRef ref) {
  // Pattern: FieldName: 'old' -> 'new'
  final colonIndex = change.indexOf(':');
  if (colonIndex == -1) return Text(change);

  final fieldNameRaw = change.substring(0, colonIndex).trim();
  final valuesPart = change.substring(colonIndex + 1).trim();
  
  final fieldName = _localizeFieldName(fieldNameRaw, ref);
  final noneLabel = 'none'.tr(ref);

  final arrowParts = valuesPart.split('->');
  if (arrowParts.length != 2) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(change, style: context.bodyMedium),
    );
  }

  final oldValRaw = arrowParts[0].trim().replaceAll("'", "");
  final newValRaw = arrowParts[1].trim().replaceAll("'", "");

  if (fieldNameRaw.toLowerCase().replaceAll('_', '') == 'itemssummary') {
    return _buildSummaryChangeItem(context, fieldName, oldValRaw, newValRaw, ref);
  }

  final oldVal = oldValRaw.isEmpty || oldValRaw == "null" ? noneLabel : _resolveValue(fieldNameRaw, oldValRaw, ref);
  final newVal = newValRaw.isEmpty || newValRaw == "null" ? noneLabel : _resolveValue(fieldNameRaw, newValRaw, ref);

  return Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Theme.of(context).brightness == Brightness.dark 
          ? Colors.white.withValues(alpha: 0.03) 
          : Colors.black.withValues(alpha: 0.02),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: context.borderColor.withValues(alpha: 0.5)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          fieldName,
          style: context.labelSmall?.bold.withColor(AppColors.primaryTeal),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Text(
                oldVal,
                style: context.bodySmall?.withColor(context.appTheme.textMuted).copyWith(
                  decoration: TextDecoration.lineThrough,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.primaryTeal.withValues(alpha: 0.5)),
            ),
            Expanded(
              child: Text(
                newVal,
                style: context.bodySmall?.bold.withColor(AppColors.success),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

String _resolveValue(String field, String value, WidgetRef ref) {
  final f = field.toLowerCase().replaceAll('_', '');
  final id = int.tryParse(value);
  if (id == null) return value;

  if (f == 'customerid') {
    final customers = ref.watch(customersStreamProvider).value;
    if (customers != null) {
      final customer = customers.cast<CustomerModel?>().firstWhere((c) => c?.id == id, orElse: () => null);
      if (customer != null) return '${customer.name} (#$id)';
    }
  } else if (f == 'engineerid' || f == 'assigneduserid' || f == 'assigned_user_id') {
    final users = ref.watch(engineersProvider).value;
    if (users != null) {
      final user = users.cast<UserModel?>().firstWhere((u) => u?.id == id, orElse: () => null);
      if (user != null) return '${user.fullName} (#$id)';
    }
  }
  
  return value;
}

String _localizeFieldName(String field, WidgetRef ref) {
  final f = field.toLowerCase().replaceAll('_', '');
  if (f == 'name') return 'name'.tr(ref);
  if (f == 'status') return 'status'.tr(ref);
  if (f == 'totalkw' || f == 'total_kw') return 'system_capacity'.tr(ref);
  if (f == 'totalvalue' || f == 'total_value') return 'total_value'.tr(ref);
  if (f == 'phone') return 'phone_label'.tr(ref);
  if (f == 'phone2') return 'phone2'.tr(ref);
  if (f == 'email') return 'email_label'.tr(ref);
  if (f == 'address') return 'address'.tr(ref);
  if (f == 'governorate') return 'governorate'.tr(ref);
  if (f == 'city') return 'city'.tr(ref);
  if (f == 'notes') return 'notes'.tr(ref);
  if (f == 'engineerid' || f == 'assigneduserid' || f == 'assigned_user_id') return 'responsible'.tr(ref);
  if (f == 'customerid') return 'customer'.tr(ref);
  if (f == 'itemssummary') return 'items_summary'.tr(ref);
  if (f == 'inquirydate' || f == 'inquiry_date') return 'inquiry_date'.tr(ref);
  if (f == 'followupstatus' || f == 'follow_up_status') return 'follow_up_status'.tr(ref);
  if (f == 'channel') return 'channel'.tr(ref);
  if (f == 'projectnumber' || f == 'project_number') return 'project_number'.tr(ref);
  if (f == 'installationdate' || f == 'installation_date') return 'installation_date'.tr(ref);
  
  if (f.contains('firstcall') || f.contains('1stcall')) return 'first_call'.tr(ref);
  if (f.contains('secondcall') || f.contains('2ndcall')) return 'second_call'.tr(ref);
  if (f.contains('thirdcall') || f.contains('3rdcall')) return 'third_call'.tr(ref);
  if (f.contains('fourthcall') || f.contains('4thcall')) return 'fourth_call'.tr(ref);
  if (f.contains('actiondate')) return 'action_date'.tr(ref);
  
  return field;
}

String _localizeActivityMessage(String message, WidgetRef ref, {bool simplified = false}) {
  if (message.isEmpty) return '';
  
  var result = message;

  if (simplified) {
    if (result.contains('Changes:')) {
      result = result.split('Changes:')[0].trim();
    }
    if (result.contains('|')) {
      result = result.split('|')[0].trim();
    }
    if (result.contains('Details:')) {
      result = result.split('Details:')[0].trim();
    }
    if (result.endsWith('.')) {
      result = result.substring(0, result.length - 1);
    }
  }
  
  // Handle "Changes:" separator
  if (result.contains('Changes:')) {
    result = result.replaceFirst('Changes:', 'changes_log'.tr(ref));
  }

  // Handle "with ID" pattern
  final withIdLabel = 'activity_with_id'.tr(ref);
  result = result.replaceAll('with ID', withIdLabel);

  // Handle Common Actions
  if (result.contains('Created')) {
     result = result.replaceFirst('Created', 'created_log'.tr(ref));
  } else if (result.contains('Updated')) {
     result = result.replaceFirst('Updated', 'updated_log'.tr(ref));
  } else if (result.contains('Deleted')) {
     result = result.replaceFirst('Deleted', 'deleted_log'.tr(ref));
  }
  
  // Handle Entity Types
  if (result.contains('Customer')) {
    result = result.replaceFirst('Customer', 'customer'.tr(ref));
  } else if (result.contains('Project')) {
    result = result.replaceFirst('Project', 'project'.tr(ref));
  } else if (result.contains('Quotation')) {
    result = result.replaceFirst('Quotation', 'quotation'.tr(ref));
  } else if (result.contains('User')) {
    result = result.replaceFirst('User', 'user'.tr(ref));
  } else if (result.contains('Invoice')) {
    result = result.replaceFirst('Invoice', 'invoice'.tr(ref));
  } else if (result.contains('Payment')) {
    result = result.replaceFirst('Payment', 'payments'.tr(ref));
  } else if (result.contains('Product')) {
    result = result.replaceFirst('Product', 'product'.tr(ref));
  }
  
  // Handle Auth
  if (result.contains('logged in')) {
    result = result.replaceFirst('logged in', 'logged_in_log'.tr(ref));
  } else if (result.contains('logged out')) {
    result = result.replaceFirst('logged out', 'logged_out_log'.tr(ref));
  }

  return result;
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
        Expanded(
          child: Text(
            title,
            style: context.titleMedium?.bold.primary.withHeight(1.0),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}

Widget _detailRow(BuildContext context, String label, String value, {IconData? icon, Widget? trailing}) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (icon != null) ...[
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 18, color: context.appTheme.textMuted),
        ),
        const SizedBox(width: 12),
      ],
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: context.bodyMedium?.withColor(context.appTheme.textMuted),
            ),
            if (trailing == null) ...[
              const SizedBox(height: 4),
              Text(
                value,
                style: context.bodyMedium?.bold,
              ),
            ],
          ],
        ),
      ),
      if (trailing != null) ...[
        const SizedBox(width: 12),
        trailing,
      ],
    ],
  );
}

Color _getActionColor(String action) {
  final act = action.toLowerCase();
  if (act.contains('login')) return Colors.green;
  if (act.contains('logout')) return Colors.orange;
  if (act.contains('create') || act.contains('add')) return AppColors.primaryTeal;
  if (act.contains('update') || act.contains('edit')) return Colors.blue;
  if (act.contains('delete') || act.contains('remove')) return Colors.red;
  if (act.contains('status')) return Colors.orange;
  return Colors.grey;
}

final activitiesProvider = FutureProvider.family<List<ActivityModel>, int?>((ref, userId) {
  ref.watch(dataRefreshVersionProvider);
  return ref.watch(activityRepositoryProvider).getActivities(userId);
});

Map<String, String> _parseSummary(String value) {
  final map = <String, String>{};
  if (value == 'none' || value.isEmpty || value == 'null') return map;

  final items = value.split('|').where((s) => s.trim().isNotEmpty).toList();
  for (var item in items) {
    var s = item.trim();
    while (s.startsWith(':')) {
      s = s.substring(1);
    }
    while (s.endsWith(':')) {
      s = s.substring(0, s.length - 1);
    }
    final parts = s.split(':');
    if (parts.length >= 2) {
      final k = parts[0].trim();
      final v = parts.sublist(1).join(':').trim();
      map[k] = v;
    }
  }
  return map;
}

Widget _buildSummaryChangeItem(BuildContext context, String fieldName, String oldValRaw, String newValRaw, WidgetRef ref) {
  final oldMap = _parseSummary(oldValRaw);
  final newMap = _parseSummary(newValRaw);
  final allKeys = {...oldMap.keys, ...newMap.keys}.toList();

  final List<Widget> changeWidgets = [];

  for (var key in allKeys) {
    final oldV = oldMap[key];
    final newV = newMap[key];
    if (oldV == newV) continue;

    // Prevent showing changes for numeric values that are actually equal (e.g. 5.000 vs 5.0)
    final oldD = double.tryParse(oldV ?? '');
    final newD = double.tryParse(newV ?? '');
    if (oldD != null && newD != null && oldD == newD) continue;

    changeWidgets.add(
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              key,
              style: context.bodySmall?.medium.withColor(context.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                if (oldV != null)
                  Expanded(
                    child: Text(
                      oldV,
                      style: context.bodySmall?.withColor(context.appTheme.textMuted).copyWith(
                            decoration: TextDecoration.lineThrough,
                          ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.arrow_forward_rounded,
                      size: 12, color: AppColors.primaryTeal.withValues(alpha: 0.5)),
                ),
                if (newV != null)
                  Expanded(
                    child: Text(
                      newV,
                      style: context.bodySmall?.bold.withColor(AppColors.success),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  if (changeWidgets.isEmpty) return const SizedBox.shrink();

  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).brightness == Brightness.dark
          ? Colors.white.withValues(alpha: 0.03)
          : Colors.black.withValues(alpha: 0.02),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: context.borderColor.withValues(alpha: 0.5)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.list_alt_rounded, size: 16, color: AppColors.primaryTeal),
            const SizedBox(width: 8),
            Text(
              fieldName,
              style: context.labelSmall?.bold.withColor(AppColors.primaryTeal),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...changeWidgets,
      ],
    ),
  );
}
