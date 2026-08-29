import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:responsive_framework/responsive_framework.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/utils/deterministic_color.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/localization/language_provider.dart';
import '../../search/presentation/global_search_dialog.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/theme_provider.dart';
import '../../auth/data/auth_repository.dart';
import '../../../core/permissions/user_role.dart';
import '../../notifications/data/notifications_repository.dart';
import '../../../core/theme/typography_extensions.dart';
import '../../../core/services/data_refresh_service.dart';

class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final showDrawer = ResponsiveBreakpoints.of(context).smallerThan(DESKTOP);
    
    final topPadding = MediaQuery.paddingOf(context).top;
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final navHeight = isMobile ? 64.0 : 80.0;
    final horizontalPadding = isMobile ? 12.0 : 24.0;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        drawer: showDrawer ? _MobileDrawer(userRole: user?.role) : null,
        body: Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Stack(
            children: [
              Positioned.fill(
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: EdgeInsets.only(top: navHeight + topPadding + 16),
                    child: child,
                  ),
                ),
              ),
              Positioned(
                top: topPadding + 12,
                left: horizontalPadding,
                right: horizontalPadding,
                child: const _TopNavbar(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const Map<String, List<String>> _navCategories = {
  'sales': ['/customers', '/quotations', '/invoices', '/payments'],
  'operations': ['/projects', '/calendar', '/products', '/price-list', '/operations'],
  'management': ['/reports', '/activity', '/users'],
};

class _TopNavbar extends ConsumerWidget {
  const _TopNavbar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final breakpoints = ResponsiveBreakpoints.of(context);
    final showDrawer = breakpoints.smallerThan(DESKTOP);
    final isMobile = breakpoints.isMobile;
    final isTablet = breakpoints.isTablet;
    
    final rawRoutes = routesForUser(user?.role);
    final uniqueRoutesMap = <String, AppRoute>{};
    for (final route in rawRoutes) {
      uniqueRoutesMap[route.path] = route;
    }
    final routes = uniqueRoutesMap.values.toList();
    
    final state = GoRouterState.of(context);
    final location = state.matchedLocation;

    return GlassContainer(
      borderRadius: 24,
      borderOpacity: 0.1,
      blur: 20,
      padding: EdgeInsets.symmetric(horizontal: showDrawer ? 12 : 20),
      child: SizedBox(
        height: 64,
        child: Row(
          children: [
            if (showDrawer) ...[
              IconButton(
                onPressed: () => Scaffold.of(context).openDrawer(),
                icon: const Icon(Icons.menu_rounded, color: AppColors.primaryTeal),
              ),
              const SizedBox(width: 4),
            ],

            GestureDetector(
              onTap: () => context.go('/dashboard'),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Hero(
                    tag: 'logo',
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryTeal.withValues(alpha: 0.12),
                            blurRadius: (isMobile ? 44.0 : (isTablet ? 52.0 : 58.0)) * 0.5,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/images/logo.png',
                        height: isMobile ? 44 : (isTablet ? 52 : 58),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (!showDrawer) ...[
              SizedBox(width: breakpoints.screenWidth < 1400 ? 12 : 32),
              _NavbarLink(
                label: 'dashboard'.tr(ref),
                icon: Icons.dashboard_rounded,
                isSelected: location == '/dashboard',
                onTap: () => context.go('/dashboard'),
              ),

              _NavDropdown(
                label: 'sales'.tr(ref),
                icon: Icons.trending_up_rounded,
                items: routes.where((r) => _navCategories['sales']!.contains(r.path)).toList(),
                currentLocation: location,
              ),

              _NavDropdown(
                label: 'operations'.tr(ref),
                icon: Icons.settings_suggest_rounded,
                items: routes.where((r) => _navCategories['operations']!.contains(r.path)).toList(),
                currentLocation: location,
              ),

              _NavDropdown(
                label: 'management'.tr(ref),
                icon: Icons.assessment_rounded,
                items: routes.where((r) => _navCategories['management']!.contains(r.path)).toList(),
                currentLocation: location,
              ),
            ],
            const Spacer(),
            
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SearchField(isCollapsed: showDrawer),
                SizedBox(width: isMobile ? 4 : 8),
                const _RefreshActionButton(),
                const SizedBox(width: 4),
                if (!isMobile) ...[
                  const _LanguageActionButton(),
                  const SizedBox(width: 4),
                  const _ThemeActionButton(),
                  const SizedBox(width: 8),
                ],
                const _NotificationIconButton(),
                SizedBox(width: isMobile ? 8 : 12),
                if (!showDrawer) ...[
                  Container(
                    height: 24,
                    width: 1,
                    color: AppColors.lightBorder.withValues(alpha: 0.3),
                  ),
                  const SizedBox(width: 12),
                ],
                _UserMenu(user: user, isCollapsed: showDrawer),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NavDropdown extends ConsumerStatefulWidget {
  const _NavDropdown({
    required this.label,
    required this.icon,
    required this.items,
    required this.currentLocation,
  });

  final String label;
  final IconData icon;
  final List<AppRoute> items;
  final String currentLocation;

  @override
  ConsumerState<_NavDropdown> createState() => _NavDropdownState();
}

class _NavDropdownState extends ConsumerState<_NavDropdown> {
  final MenuController _controller = MenuController();
  bool _isHovered = false;
  bool _isClosing = false;

  void _handleItemTap(AppRoute route) async {
    setState(() => _isClosing = true);
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) {
      context.go(route.path);
      _controller.close();
      setState(() => _isClosing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    final isAnyItemSelected = widget.items.any((item) => widget.currentLocation.startsWith(item.path));
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: MouseRegion(
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
            shadowColor: WidgetStateProperty.all(Colors.transparent),
            surfaceTintColor: WidgetStateProperty.all(Colors.transparent),
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: widget.items.map((route) {
                    final isSelected = widget.currentLocation.startsWith(route.path);
                    return _DropdownMenuItem(
                      route: route,
                      isSelected: isSelected,
                      onTap: () => _handleItemTap(route),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
          builder: (context, controller, child) {
            final isOpen = controller.isOpen;
            return InkWell(
              onTap: () => isOpen ? controller.close() : controller.open(),
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isAnyItemSelected
                      ? AppColors.primaryTeal.withValues(alpha: 0.12)
                      : (_isHovered || isOpen) ? AppColors.primaryTeal.withValues(alpha: 0.06) : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: (_isHovered || isOpen) ? [
                    BoxShadow(
                      color: AppColors.primaryTeal.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ] : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedScale(
                      scale: (_isHovered || isOpen) ? 1.05 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        widget.icon,
                        size: 18,
                        color: isAnyItemSelected ? AppColors.primaryTeal : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.label,
                      style: context.labelLarge?.withColor(
                        isAnyItemSelected ? AppColors.primaryTeal : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    AnimatedRotation(
                      turns: isOpen ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 14,
                        color: isAnyItemSelected ? AppColors.primaryTeal : AppColors.textSecondary.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _NavbarLink extends StatefulWidget {
  const _NavbarLink({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_NavbarLink> createState() => _NavbarLinkState();
}

class _NavbarLinkState extends State<_NavbarLink> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: widget.isSelected 
                  ? AppColors.primaryTeal.withValues(alpha: 0.12) 
                  : _isHovered ? AppColors.primaryTeal.withValues(alpha: 0.06) : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              boxShadow: (widget.isSelected || _isHovered) ? [
                BoxShadow(
                  color: AppColors.primaryTeal.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ] : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedScale(
                  scale: _isHovered ? 1.1 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    widget.icon,
                    size: 18,
                    color: widget.isSelected ? AppColors.primaryTeal : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.label,
                  style: context.labelLarge?.withColor(
                    widget.isSelected ? AppColors.primaryTeal : AppColors.textSecondary,
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

class _DropdownMenuItem extends ConsumerStatefulWidget {
  const _DropdownMenuItem({
    required this.route,
    required this.isSelected,
    required this.onTap,
  });

  final AppRoute route;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  ConsumerState<_DropdownMenuItem> createState() => _DropdownMenuItemState();
}

class _DropdownMenuItemState extends ConsumerState<_DropdownMenuItem> {
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
            width: 240,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: widget.isSelected 
                  ? AppColors.primaryTeal.withValues(alpha: 0.12) 
                  : _isHovered ? AppColors.primaryTeal.withValues(alpha: 0.06) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: widget.isSelected 
                        ? AppColors.primaryTeal.withValues(alpha: 0.15) 
                        : _isHovered ? AppColors.primaryTeal.withValues(alpha: 0.1) : AppColors.lightBackground.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: AnimatedScale(
                    scale: _isHovered ? 1.1 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      widget.route.icon,
                      size: 16,
                      color: widget.isSelected ? AppColors.primaryTeal : AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    widget.route.labelKey.tr(ref),
                    style: context.labelLarge?.withColor(
                      widget.isSelected ? AppColors.primaryTeal : context.onSurfaceColor,
                    ),
                  ),
                ),
                if (widget.isSelected)
                  const Icon(Icons.check_circle_rounded, size: 14, color: AppColors.primaryTeal),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatefulWidget {
  const _ActionButton({required this.icon, this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: _isHovered ? AppColors.primaryTeal.withValues(alpha: 0.08) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: AnimatedScale(
              scale: _isHovered ? 1.15 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                widget.icon, 
                color: _isHovered ? AppColors.primaryTeal : AppColors.textSecondary, 
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationIconButton extends ConsumerWidget {
  const _NotificationIconButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCountAsync = ref.watch(unreadCountProvider);

    return unreadCountAsync.when(
      data: (count) => Stack(
        clipBehavior: Clip.none,
        children: [
          _ActionButton(
            icon: Icons.notifications_none_rounded,
            onTap: () => context.go('/notifications'),
          ),
          if (count > 0)
            Positioned(
              right: 2,
              top: 2,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  count > 9 ? '9+' : '$count',
                  style: context.labelSmall?.bold.white.withSize(8),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
      loading: () => const _ActionButton(icon: Icons.notifications_none_rounded, onTap: null),
      error: (error, stack) => const _ActionButton(icon: Icons.notifications_none_rounded, onTap: null),
    );
  }
}

class _UserMenu extends ConsumerStatefulWidget {
  const _UserMenu({required this.user, this.isCollapsed = false});
  final AuthUser? user;
  final bool isCollapsed;

  @override
  ConsumerState<_UserMenu> createState() => _UserMenuState();
}

class _UserMenuState extends ConsumerState<_UserMenu> {
  final MenuController _controller = MenuController();
  bool _isClosing = false;

  void _handleAction(VoidCallback action) async {
    setState(() => _isClosing = true);
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) {
      action();
      _controller.close();
      setState(() => _isClosing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveBreakpoints.of(context).isDesktop;
    final (bgColor, textColor) = DeterministicColor.getColor(widget.user?.fullName ?? '');

    return MenuAnchor(
      controller: _controller,
      alignmentOffset: isDesktop ? const Offset(-60, 12) : const Offset(-80, 12),
      onClose: () => setState(() => _isClosing = false),
      style: MenuStyle(
        backgroundColor: WidgetStateProperty.all(Colors.transparent),
        elevation: WidgetStateProperty.all(0),
        padding: WidgetStateProperty.all(EdgeInsets.zero),
        shadowColor: WidgetStateProperty.all(Colors.transparent),
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
            borderRadius: 24,
            blur: 25,
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: bgColor,
                        child: Text(
                          widget.user?.fullName.isNotEmpty == true ? widget.user!.fullName[0].toUpperCase() : '?',
                          style: context.titleMedium?.bold.withColor(textColor),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.user?.fullName ?? '', style: context.titleSmall?.bold),
                          Text(
                            widget.user?.role.name.tr(ref) ?? '',
                            style: context.labelSmall?.withColor(context.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, indent: 8, endIndent: 8),
                const SizedBox(height: 8),
                if (ResponsiveBreakpoints.of(context).isMobile) ...[
                  _MenuActionItem(
                    icon: Icons.language_rounded,
                    label: ref.watch(localeProvider).languageCode == 'ar' ? 'English' : 'العربية',
                    onTap: () => _handleAction(() => ref.read(localeProvider.notifier).toggleLocale()),
                  ),
                  _MenuActionItem(
                    icon: Theme.of(context).brightness == Brightness.dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                    label: Theme.of(context).brightness == Brightness.dark ? 'light_mode'.tr(ref) : 'dark_mode'.tr(ref),
                    onTap: () => _handleAction(() => ref.read(themeModeProvider.notifier).toggleTheme()),
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1, indent: 8, endIndent: 8),
                  const SizedBox(height: 8),
                ],
                _MenuActionItem(
                  icon: Icons.logout_rounded,
                  label: 'logout'.tr(ref),
                  color: AppColors.error,
                  onTap: () => _handleAction(() => ref.read(authProvider.notifier).logout()),
                ),
              ],
            ),
          ),
        ),
      ],
      builder: (context, controller, child) {
        return InkWell(
          onTap: () => controller.isOpen ? controller.close() : controller.open(),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildUserAvatar(context, widget.user?.fullName ?? ''),
                if (!widget.isCollapsed) ...[
                  const SizedBox(width: 12),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.user?.fullName ?? '',
                        style: context.labelLarge,
                      ),
                      Text(
                        widget.user?.role.name.tr(ref) ?? '',
                        style: context.labelSmall?.withColor(context.onSurfaceVariant),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: context.onSurfaceVariant),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildUserAvatar(BuildContext ctx, String name) {
    final (bgColor, textColor) = DeterministicColor.getColor(name);
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: bgColor.withValues(alpha: 0.3),
            blurRadius: 10,
            spreadRadius: 2,
          )
        ],
      ),
      child: CircleAvatar(
        radius: 18,
        backgroundColor: bgColor,
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: ctx.titleSmall?.bold.withColor(textColor),
        ),
      ),
    );
  }
}

class _SearchField extends ConsumerStatefulWidget {
  const _SearchField({this.isCollapsed = false});
  final bool isCollapsed;

  @override
  ConsumerState<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends ConsumerState<_SearchField> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    if (widget.isCollapsed) {
      return _ActionButton(
        icon: Icons.search_rounded,
        onTap: () => showDialog(
          context: context,
          builder: (context) => const GlobalSearchDialog(),
        ),
      );
    }
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: () => showDialog(
          context: context,
          builder: (context) => const GlobalSearchDialog(),
        ),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          constraints: const BoxConstraints(maxWidth: 220),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: _isHovered 
                ? AppColors.primaryTeal.withValues(alpha: 0.15) 
                : context.onSurfaceColor.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isHovered ? AppColors.primaryTeal.withValues(alpha: 0.4) : Colors.transparent,
              width: 1.5,
            ),
            boxShadow: _isHovered ? [
              BoxShadow(
                color: AppColors.primaryTeal.withValues(alpha: 0.1),
                blurRadius: 15,
                spreadRadius: 2,
              )
            ] : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedRotation(
                turns: _isHovered ? 0.05 : 0,
                duration: const Duration(milliseconds: 300),
                child: Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: _isHovered ? AppColors.primaryTeal : context.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  'search'.tr(ref),
                  overflow: TextOverflow.ellipsis,
                  style: context.labelMedium?.withColor(
                    _isHovered ? AppColors.primaryTeal : context.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RefreshActionButton extends ConsumerWidget {
  const _RefreshActionButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _ActionButton(
      icon: Icons.refresh_rounded,
      onTap: () {
        DataRefreshCoordinator.refresh(ref);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('refreshing_data'.tr(ref)),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
            width: 200,
          ),
        );
      },
    );
  }
}

class _LanguageActionButton extends ConsumerWidget {
  const _LanguageActionButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(localeProvider);
    return _ActionButton(
      icon: Icons.language_rounded,
      onTap: () => ref.read(localeProvider.notifier).toggleLocale(),
    );
  }
}

class _ThemeActionButton extends ConsumerWidget {
  const _ThemeActionButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _ActionButton(
      icon: isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
      onTap: () => ref.read(themeModeProvider.notifier).toggleTheme(),
    );
  }
}

class _MenuActionItem extends StatelessWidget {
  const _MenuActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final displayColor = color ?? AppColors.textPrimary;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 240,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: displayColor),
            const SizedBox(width: 12),
            Text(
              label,
              style: context.labelLarge?.withColor(displayColor),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileDrawer extends ConsumerWidget {
  const _MobileDrawer({this.userRole});
  final UserRole? userRole;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routes = routesForUser(userRole);
    final location = GoRouterState.of(context).matchedLocation;

    return Drawer(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryTeal.withValues(alpha: 0.15),
                        blurRadius: 50,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/images/logo.png',
                    height: 100,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
          const Divider(height: 1, indent: 24, endIndent: 24, color: AppColors.lightBorder),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildDrawerSection(context, ref, '', routes, ['/dashboard'], location),
                
                _buildDrawerSection(context, ref, 'sales'.tr(ref), routes, _navCategories['sales']!, location),
                _buildDrawerSection(context, ref, 'operations'.tr(ref), routes, _navCategories['operations']!, location),
                _buildDrawerSection(context, ref, 'management'.tr(ref), routes, _navCategories['management']!, location),
                
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Divider(height: 1, color: AppColors.lightBorder),
                ),
                
                ListTile(
                  onTap: () => ref.read(authProvider.notifier).logout(),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  leading: const Icon(Icons.logout_rounded, color: AppColors.error),
                  title: Text(
                    'logout'.tr(ref),
                    style: context.bodyLarge?.withWeight(FontWeight.w600).withColor(AppColors.error),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerSection(
    BuildContext context, 
    WidgetRef ref, 
    String title, 
    List<AppRoute> allRoutes, 
    List<String> paths,
    String location,
  ) {
    final sectionRoutes = allRoutes.where((r) => paths.contains(r.path)).toList();
    if (sectionRoutes.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 16, bottom: 8),
            child: Text(
              title.toUpperCase(),
              style: context.labelSmall?.bold.withColor(context.onSurfaceVariant).withLetterSpacing(1.2),
            ),
          ),
        ...sectionRoutes.map((route) {
          final isSelected = location.startsWith(route.path);
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: ListTile(
              onTap: () {
                context.go(route.path);
                Navigator.pop(context);
              },
              selected: isSelected,
              selectedTileColor: AppColors.primaryTeal.withValues(alpha: 0.1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              leading: Icon(
                route.icon, 
                color: isSelected ? AppColors.primaryTeal : AppColors.textSecondary,
                size: 22,
              ),
              title: Text(
                route.labelKey.tr(ref),
                style: context.bodyLarge?.withWeight(FontWeight.w600).withColor(
                  isSelected ? AppColors.primaryTeal : AppColors.textSecondary,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}