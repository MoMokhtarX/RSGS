import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/data_refresh_service.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/permissions/user_role.dart';
import '../../../core/theme/typography_extensions.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/widgets/common_widgets.dart';
import '../data/users_repository.dart';
import '../models/user_management_models.dart';

final userSearchQueryProvider = StateProvider<String>((ref) => '');
final userRoleFilterProvider = StateProvider<UserRole?>((ref) => null);
final userCurrentPageProvider = StateProvider<int>((ref) => 1);
final userItemsPerPageProvider = StateProvider<int>((ref) => 15);

final filteredUsersProvider = Provider<AsyncValue<List<ManagedUser>>>((ref) {
  final usersAsync = ref.watch(usersProvider);
  final searchQuery = ref.watch(userSearchQueryProvider).toLowerCase();
  final roleFilter = ref.watch(userRoleFilterProvider);

  return usersAsync.whenData((users) {
    return users.where((u) {
      final matchesSearch = u.fullName.toLowerCase().contains(searchQuery) ||
          u.username.toLowerCase().contains(searchQuery) ||
          u.email.toLowerCase().contains(searchQuery);
      final matchesRole = roleFilter == null || u.role == roleFilter;
      return matchesSearch && matchesRole;
    }).toList();
  });
});

class UsersScreen extends ConsumerWidget {
  const UsersScreen({super.key});

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
                child: const _UsersFiltersBar(),
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
                    child: _UsersView(isMobile: isMobile),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(vertical: isMobile ? 4 : 8, horizontal: 16),
                child: const _UsersPaginationFooter(),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _UsersView extends ConsumerWidget {
  const _UsersView({required this.isMobile});
  final bool isMobile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(filteredUsersProvider);
    final currentPage = ref.watch(userCurrentPageProvider);
    final itemsPerPage = ref.watch(userItemsPerPageProvider);

    return usersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('${'error'.tr(ref)}: $err')),
      data: (users) {
        if (users.isEmpty) return const _EmptyUsers();
        
        final totalPages = (users.length / itemsPerPage).ceil();
        final actualPage = currentPage > totalPages ? (totalPages > 0 ? totalPages : 1) : currentPage;
        final startIndex = (actualPage - 1) * itemsPerPage;
        final endIndex = (startIndex + itemsPerPage).clamp(0, users.length);
        
        final pageUsers = users.sublist(startIndex, endIndex);

        if (isMobile) {
          return ListView.separated(
            key: const PageStorageKey('users_mobile_list'),
            padding: const EdgeInsets.all(12),
            itemCount: pageUsers.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              return _UserCard(
                user: pageUsers[index],
              );
            },
          );
        }

        return Column(
          children: [
            const _TableHeader(),
            Expanded(
              child: ListView.builder(
                key: const PageStorageKey('users_table_list'),
                padding: const EdgeInsets.only(top: 4),
                itemCount: pageUsers.length,
                itemBuilder: (context, index) {
                  return _TableRow(
                    key: ValueKey('user_row_${pageUsers[index].id}'),
                    user: pageUsers[index],
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
          _buildHeaderCell(context, ref, 'user'.tr(ref), Icons.person_outline_rounded, flex: 3),
          const SizedBox(width: 12),
          _buildHeaderCell(context, ref, 'email'.tr(ref), Icons.email_outlined, flex: 3),
          const SizedBox(width: 12),
          _buildHeaderCell(context, ref, 'role'.tr(ref), Icons.admin_panel_settings_outlined, flex: 2),
          const SizedBox(width: 12),
          _buildHeaderCell(context, ref, 'status'.tr(ref), Icons.flag_outlined, flex: 2),
          const SizedBox(width: 120),
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
  const _TableRow({super.key, required this.user, required this.index});
  final ManagedUser user;
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
                        '${user.id}',
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
                      Text(user.fullName, style: context.titleSmall?.bold),
                      Text('@${user.username}', style: context.bodySmall?.copyWith(color: context.onSurfaceVariant)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: Text(
                  user.email,
                  style: context.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: _RoleBadge(role: user.role),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: _StatusBadge(active: user.isActive),
                ),
              ),
              SizedBox(
                width: 120,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ActionButton(
                      icon: Icons.edit_rounded,
                      color: AppColors.primaryTeal,
                      onPressed: () => showUserDialog(context, ref, user: user),
                      tooltip: 'edit'.tr(ref),
                    ),
                    const SizedBox(width: 4),
                    ActionButton(
                      icon: Icons.lock_reset_rounded,
                      color: AppColors.warning,
                      onPressed: () async {
                        final changed = await showDialog<bool>(
                          context: context,
                          builder: (_) => _ResetPasswordDialog(user: user),
                        );
                        if (changed == true) ref.invalidate(usersProvider);
                      },
                      tooltip: 'reset_password'.tr(ref),
                    ),
                    const SizedBox(width: 4),
                    ActionButton(
                      icon: user.isActive ? Icons.person_off_outlined : Icons.person_outline_rounded,
                      color: user.isActive ? AppColors.error : AppColors.success,
                      onPressed: () => _toggleUser(context, ref, user),
                      tooltip: user.isActive ? 'disable'.tr(ref) : 'enable'.tr(ref),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UsersFiltersBar extends ConsumerWidget {
  const _UsersFiltersBar();

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
                hint: 'search_users_hint'.tr(ref),
                icon: Icons.search_rounded,
                onChanged: (value) {
                  ref.read(userSearchQueryProvider.notifier).state = value;
                  ref.read(userCurrentPageProvider.notifier).state = 1;
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _buildRoleDropdown(context, ref, height: 44)),
                ],
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    if (ref.watch(userRoleFilterProvider) != null ||
                        ref.watch(userSearchQueryProvider).isNotEmpty) ...[
                      const _ClearFiltersButton(),
                      const SizedBox(width: 8),
                    ],
                    const _AddUserButton(isCompact: true),
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
                  hint: 'search_users_hint'.tr(ref),
                  icon: Icons.search_rounded,
                  style: context.labelMedium?.bold,
                  onChanged: (value) {
                    ref.read(userSearchQueryProvider.notifier).state = value;
                    ref.read(userCurrentPageProvider.notifier).state = 1;
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: _buildRoleDropdown(context, ref, height: 48),
              ),
              if (ref.watch(userRoleFilterProvider) != null ||
                  ref.watch(userSearchQueryProvider).isNotEmpty) ...[
                const SizedBox(width: 8),
                const _ClearFiltersButton(),
              ],
              const SizedBox(width: 20),
              const _AddUserButton(isCompact: true),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRoleDropdown(BuildContext context, WidgetRef ref, {double height = 44}) {
    final selectedRole = ref.watch(userRoleFilterProvider);
    
    return _FilterMenu<UserRole?>(
      label: selectedRole?.label ?? 'role'.tr(ref),
      icon: Icons.admin_panel_settings_outlined,
      value: selectedRole,
      items: [
        _FilterMenuItem(value: null, label: 'all_roles'.tr(ref)),
        ...UserRole.values.map((r) => _FilterMenuItem(value: r, label: r.label)),
      ],
      onSelected: (v) {
        ref.read(userRoleFilterProvider.notifier).state = v;
        ref.read(userCurrentPageProvider.notifier).state = 1;
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
    final hasFilters = ref.watch(userRoleFilterProvider) != null || 
                      ref.watch(userSearchQueryProvider).isNotEmpty;
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
    ref.read(userRoleFilterProvider.notifier).state = null;
    ref.read(userSearchQueryProvider.notifier).state = '';
    ref.read(userCurrentPageProvider.notifier).state = 1;
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

class _AddUserButton extends ConsumerWidget {
  const _AddUserButton({this.isCompact = false});
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
        onPressed: () => showUserDialog(context, ref),
        icon: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.add_rounded, size: 20, color: AppColors.white),
        ),
        label: Text(
          'Add User',
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

class _UsersPaginationFooter extends ConsumerWidget {
  const _UsersPaginationFooter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(filteredUsersProvider);
    final currentPage = ref.watch(userCurrentPageProvider);
    final itemsPerPage = ref.watch(userItemsPerPageProvider);

    return usersAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (err, stack) => const SizedBox.shrink(),
      data: (users) {
        final totalPages = (users.length / itemsPerPage).ceil();
        return PaginationFooter(
          currentPage: currentPage,
          totalPages: totalPages,
          onPageChanged: (page) => ref.read(userCurrentPageProvider.notifier).state = page,
        );
      },
    );
  }
}

class _UserCard extends ConsumerWidget {
  const _UserCard({required this.user});
  final ManagedUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () => showUserDialog(context, ref, user: user),
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
                    user.fullName,
                    style: context.titleMedium?.bold,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '#${user.id}',
                  style: context.labelSmall?.withColor(context.appTheme.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.alternate_email_rounded, size: 14, color: AppColors.primaryTeal),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    user.username,
                    style: context.titleSmall?.bold,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _RoleBadge(role: user.role),
              ],
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 20),
              child: Text(
                user.email,
                style: context.labelMedium?.withColor(context.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 12),
            _StatusBadge(active: user.isActive),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ActionButton(
                  icon: Icons.edit_rounded,
                  color: AppColors.primaryTeal,
                  onPressed: () => showUserDialog(context, ref, user: user),
                  tooltip: 'edit'.tr(ref),
                ),
                const SizedBox(width: 8),
                ActionButton(
                  icon: Icons.lock_reset_rounded,
                  color: AppColors.warning,
                  onPressed: () async {
                    final changed = await showDialog<bool>(
                      context: context,
                      builder: (_) => _ResetPasswordDialog(user: user),
                    );
                    if (changed == true) ref.invalidate(usersProvider);
                  },
                  tooltip: 'reset_password'.tr(ref),
                ),
                const SizedBox(width: 8),
                ActionButton(
                  icon: user.isActive ? Icons.person_off_outlined : Icons.person_outline_rounded,
                  color: user.isActive ? AppColors.error : AppColors.success,
                  onPressed: () => _toggleUser(context, ref, user),
                  tooltip: user.isActive ? 'disable'.tr(ref) : 'enable'.tr(ref),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _toggleUser(BuildContext context, WidgetRef ref, ManagedUser user) async {
  final action = user.isActive ? 'disable' : 'enable';
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('${action[0].toUpperCase()}${action.substring(1)} user', style: context.titleLarge?.bold.withColor(user.isActive ? context.errorColor : AppColors.success)),
      content: Text('Are you sure you want to $action ${user.fullName}?', style: context.bodyLarge),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text('cancel'.tr(ref), style: context.labelLarge?.withColor(context.onSurfaceVariant))),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true), 
          style: FilledButton.styleFrom(backgroundColor: user.isActive ? AppColors.error : AppColors.success),
          child: Text(action, style: context.labelLarge?.white),
        ),
      ],
    ),
  );
  if (confirmed != true) return;

  try {
    await ref.read(usersRepositoryProvider).setActive(user.id, !user.isActive);
    DataRefreshCoordinator.refresh(ref);
    ref.invalidate(usersProvider);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error));
    }
  }
}


class _EmptyUsers extends ConsumerWidget {
  const _EmptyUsers();

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
                  'No users found',
                  style: (isMobile ? context.titleLarge : context.headlineMedium),
                ),
                const SizedBox(height: 8),
                Text(
                  'try_adjusting_filters'.tr(ref),
                  textAlign: TextAlign.center,
                  style: context.bodyMedium?.withColor(context.onSurfaceVariant),
                ),
                SizedBox(height: isMobile ? 24 : 40),
                const _AddUserButton(),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});
  final UserRole role;

  @override
  Widget build(BuildContext context) {
    Color color = AppColors.primaryTeal;
    if (role == UserRole.admin) color = AppColors.error;
    if (role == UserRole.engineer) color = AppColors.indigo;

    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.12), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            role.label,
            style: context.labelSmall?.withWeight(FontWeight.w700).withColor(color).withSize(10),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.success : AppColors.error;
    
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
          Text(
            active ? 'Active' : 'Disabled',
            style: context.labelSmall?.withColor(color).withSize(10).bold,
          ),
        ],
      ),
    );
  }
}

void showUserDialog(BuildContext context, WidgetRef ref, {ManagedUser? user}) {
  final formKey = GlobalKey<FormState>();

  final usernameCtrl = TextEditingController(text: user?.username);
  final passwordCtrl = TextEditingController();
  final fullNameCtrl = TextEditingController(text: user?.fullName);
  final emailCtrl = TextEditingController(text: user?.email);
  UserRole selectedRole = user?.role ?? UserRole.sales;
  bool active = user?.isActive ?? true;

  bool isSaving = false;
  bool obscurePassword = true;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => Consumer(
        builder: (context, ref, _) {
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
                                user == null ? 'add_user'.tr(ref) : 'edit_user'.tr(ref),
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
                                          _labeledField(context, 'full_name'.tr(ref), TextFormField(controller: fullNameCtrl, decoration: customInputDecoration(context, 'full_name'.tr(ref), icon: Icons.badge_outlined), validator: (v) => v == null || v.trim().isEmpty ? 'required'.tr(ref) : null, enabled: !isSaving), required: true),
                                          const SizedBox(height: 12),
                                          _labeledField(context, 'email'.tr(ref), TextFormField(controller: emailCtrl, decoration: customInputDecoration(context, 'email'.tr(ref), icon: Icons.email_outlined), keyboardType: TextInputType.emailAddress, validator: (v) {
                                            if (v == null || v.trim().isEmpty) return 'required'.tr(ref);
                                            if (!v.contains('@')) return 'invalid_email'.tr(ref);
                                            return null;
                                          }, enabled: !isSaving), required: true),
                                        ] else ...[
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Expanded(child: _labeledField(context, 'full_name'.tr(ref), TextFormField(controller: fullNameCtrl, decoration: customInputDecoration(context, 'full_name'.tr(ref), icon: Icons.badge_outlined), validator: (v) => v == null || v.trim().isEmpty ? 'required'.tr(ref) : null, enabled: !isSaving), required: true)),
                                              const SizedBox(width: 16),
                                              Expanded(child: _labeledField(context, 'email'.tr(ref), TextFormField(controller: emailCtrl, decoration: customInputDecoration(context, 'email'.tr(ref), icon: Icons.email_outlined), keyboardType: TextInputType.emailAddress, validator: (v) {
                                                if (v == null || v.trim().isEmpty) return 'required'.tr(ref);
                                                if (!v.contains('@')) return 'invalid_email'.tr(ref);
                                                return null;
                                              }, enabled: !isSaving), required: true)),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 20),
                                  _sectionHeader(context, 'account_settings'.tr(ref), icon: Icons.settings_outlined),
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
                                        if (user == null) ...[
                                          if (isNarrow) ...[
                                            _labeledField(context, 'username'.tr(ref), TextFormField(controller: usernameCtrl, decoration: customInputDecoration(context, 'username'.tr(ref), icon: Icons.alternate_email_rounded), validator: (v) => v == null || v.trim().isEmpty ? 'required'.tr(ref) : null, enabled: !isSaving), required: true),
                                            const SizedBox(height: 12),
                                            _labeledField(context, 'password'.tr(ref), TextFormField(
                                              controller: passwordCtrl, 
                                              decoration: customInputDecoration(context, 'password'.tr(ref), icon: Icons.lock_outline_rounded).copyWith(
                                                suffixIcon: IconButton(
                                                  icon: Icon(obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                                                  onPressed: () => setState(() => obscurePassword = !obscurePassword),
                                                ),
                                              ), 
                                              obscureText: obscurePassword, 
                                              validator: (v) => (v ?? '').length < 12 ? 'Min 12 chars' : null, 
                                              enabled: !isSaving
                                            ), required: true),
                                          ] else ...[
                                            Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Expanded(child: _labeledField(context, 'username'.tr(ref), TextFormField(controller: usernameCtrl, decoration: customInputDecoration(context, 'username'.tr(ref), icon: Icons.alternate_email_rounded), validator: (v) => v == null || v.trim().isEmpty ? 'required'.tr(ref) : null, enabled: !isSaving), required: true)),
                                                const SizedBox(width: 16),
                                                Expanded(child: _labeledField(context, 'password'.tr(ref), TextFormField(
                                                  controller: passwordCtrl, 
                                                  decoration: customInputDecoration(context, 'password'.tr(ref), icon: Icons.lock_outline_rounded).copyWith(
                                                    suffixIcon: IconButton(
                                                      icon: Icon(obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                                                      onPressed: () => setState(() => obscurePassword = !obscurePassword),
                                                    ),
                                                  ), 
                                                  obscureText: obscurePassword, 
                                                  validator: (v) => (v ?? '').length < 12 ? 'Min 12 chars' : null, 
                                                  enabled: !isSaving
                                                ), required: true)),
                                              ],
                                            ),
                                          ],
                                          const SizedBox(height: 12),
                                        ],
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _labeledField(
                                                context, 
                                                'role'.tr(ref), 
                                                _buildUserRoleDropdown(context, ref, selectedRole, isSaving, (v) => setState(() => selectedRole = v!)),
                                                required: true
                                              ),
                                            ),
                                            if (user != null) ...[
                                              const SizedBox(width: 16),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Padding(
                                                      padding: const EdgeInsetsDirectional.only(start: 4, bottom: 4),
                                                      child: Text('status'.tr(ref), style: context.labelSmall?.withColor(context.onSurfaceVariant)),
                                                    ),
                                                    SwitchListTile.adaptive(
                                                      contentPadding: EdgeInsets.zero,
                                                      title: Text(active ? 'active'.tr(ref) : 'disabled'.tr(ref), style: context.bodyMedium),
                                                      value: active,
                                                      activeTrackColor: AppColors.primaryTeal,
                                                      onChanged: isSaving ? null : (v) => setState(() => active = v),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
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
                              onPressed: isSaving ? null : () => Navigator.pop(context),
                              child: Text(
                                'cancel'.tr(ref),
                                style: context.labelLarge?.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              height: 44,
                              width: 150,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                gradient: isSaving ? null : const LinearGradient(
                                  colors: [AppColors.primaryTeal, Color(0xFF0D9488)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                color: isSaving ? context.borderColor : null,
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
                                    final repo = ref.read(usersRepositoryProvider);
                                    if (user == null) {
                                      await repo.create(
                                        username: usernameCtrl.text.trim(),
                                        password: passwordCtrl.text,
                                        fullName: fullNameCtrl.text.trim(),
                                        email: emailCtrl.text.trim(),
                                        role: selectedRole.apiValue,
                                      );
                                    } else {
                                      await repo.update(
                                        user.id,
                                        fullName: fullNameCtrl.text.trim(),
                                        email: emailCtrl.text.trim(),
                                        role: selectedRole.apiValue,
                                        isActive: active,
                                      );
                                    }
                                    DataRefreshCoordinator.refresh(ref);
                                    ref.invalidate(usersProvider);
                                    if (context.mounted) Navigator.pop(context, true);
                                  } catch (e) {
                                    setState(() => isSaving = false);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error));
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

Widget _buildUserRoleDropdown(BuildContext context, WidgetRef ref, UserRole selectedRole, bool isSaving, Function(UserRole?) onChanged) {
  return _DialogMenuField<UserRole>(
    initialValue: selectedRole,
    label: 'select_role'.tr(ref),
    icon: Icons.admin_panel_settings_outlined,
    items: UserRole.values.map((r) => _DialogMenuItem<UserRole>(value: r, label: r.label)).toList(),
    onSelected: onChanged,
    enabled: !isSaving,
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

class _ResetPasswordDialog extends ConsumerStatefulWidget {
  const _ResetPasswordDialog({required this.user});
  final ManagedUser user;

  @override
  ConsumerState<_ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends ConsumerState<_ResetPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${'reset_password_for'.tr(ref)}${widget.user.fullName}', style: context.titleLarge?.bold),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _password,
                obscureText: _obscurePassword,
                validator: (v) => (v ?? '').length < 12 ? 'min_12_chars'.tr(ref) : null,
                decoration: customInputDecoration(context, 'new_password'.tr(ref), icon: Icons.lock_outline_rounded).copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _confirm,
                obscureText: _obscureConfirm,
                validator: (v) => v != _password.text ? 'passwords_no_match'.tr(ref) : null,
                decoration: customInputDecoration(context, 'confirm_password'.tr(ref), icon: Icons.lock_reset_rounded).copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: Text('cancel'.tr(ref))),
        FilledButton(
          onPressed: _saving ? null : _save, 
          style: FilledButton.styleFrom(backgroundColor: AppColors.primaryTeal),
          child: Text(_saving ? 'saving'.tr(ref) : 'reset'.tr(ref)),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(usersRepositoryProvider).resetPassword(widget.user.id, _password.text);
      DataRefreshCoordinator.refresh(ref);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
