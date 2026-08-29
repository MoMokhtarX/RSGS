import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/typography_extensions.dart';
import '../../auth/data/auth_repository.dart';
import '../data/dashboard_repository.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/localization/language_provider.dart';
import '../../../core/localization/date_formatter.dart';
import 'widgets/dashboard_charts.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef widgetRef) {
    final async = widgetRef.watch(dashboardProvider);
    final user = widgetRef.watch(authProvider).user;

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _ErrorState(
        message: error.toString(),
        onRetry: () => widgetRef.invalidate(dashboardProvider),
      ),
      data: (data) => LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 1100;
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(user: user, data: data),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: wide ? 32 : 16,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1400),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 24),
                          _EntryAnimation(
                            index: 0,
                            child: _QuickActionsBar(),
                          ),
                          const SizedBox(height: 32),
                          _EntryAnimation(
                            index: 1,
                            child: _StatsGrid(data: data),
                          ),
                          const SizedBox(height: 32),
                          _EntryAnimation(
                            index: 2,
                            child: _MainContent(data: data, wide: wide),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({this.user, required this.data});
  final AuthUser? user;
  final DashboardData data;

  @override
  Widget build(BuildContext context, WidgetRef widgetRef) {
    final firstName = user?.fullName.trim().split(RegExp(r'\s+')).first ?? 'user_default'.tr(widgetRef);
    final hour = DateTime.now().hour;
    String greeting;
    if (hour < 12) {
      greeting = 'good_morning'.tr(widgetRef);
    } else if (hour < 17) {
      greeting = 'good_afternoon'.tr(widgetRef);
    } else {
      greeting = 'good_evening'.tr(widgetRef);
    }

    final isWide = MediaQuery.of(context).size.width >= 1100;

    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(horizontal: isWide ? 32 : 16),
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryTeal, AppColors.primaryTealDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryTeal.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$greeting, $firstName',
                  style: context.headlineMedium?.white.bold,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 14, color: Colors.white60),
                    const SizedBox(width: 8),
                    Text(
                      DateTime.now().format('full_date_format'.tr(widgetRef), widgetRef.watch(localeProvider).languageCode),
                      style: context.bodySmall?.white.withValues(alpha: 0.6).semiBold.copyWith(
                        letterSpacing: widgetRef.watch(localeProvider).languageCode == 'ar' ? 1.1 : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.group_rounded, size: 12, color: Colors.white70),
                          const SizedBox(width: 6),
                          Text(
                            '${data.totalUsers} ${'users'.tr(widgetRef)}',
                            style: context.labelSmall?.white.semiBold,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _GlassHeaderButton(
            icon: Icons.notifications_none_rounded,
            onTap: () => context.go('/notifications'),
            hasBadge: true,
          ),
          const SizedBox(width: 12),
          _GlassHeaderButton(
            icon: Icons.refresh_rounded,
            onTap: () => widgetRef.invalidate(dashboardProvider),
          ),
        ],
      ),
    );
  }
}

class _GlassHeaderButton extends StatelessWidget {
  const _GlassHeaderButton({
    required this.icon,
    required this.onTap,
    this.hasBadge = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool hasBadge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(icon, size: 22, color: Colors.white),
              if (hasBadge)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
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

class _QuickActionsBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef widgetRef) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _QuickActionItem(
            icon: Icons.person_add_alt_1_rounded,
            label: 'add_customer'.tr(widgetRef),
            onTap: () => context.go('/customers'),
            color: AppColors.primaryTeal,
          ),
          const SizedBox(width: 12),
          _QuickActionItem(
            icon: Icons.note_add_rounded,
            label: 'new_quotation'.tr(widgetRef),
            onTap: () => context.go('/quotations'),
            color: AppColors.violet,
          ),
          const SizedBox(width: 12),
          _QuickActionItem(
            icon: Icons.analytics_rounded,
            label: 'view_reports'.tr(widgetRef),
            onTap: () => context.go('/reports'),
            color: AppColors.success,
          ),
          const SizedBox(width: 12),
          _QuickActionItem(
            icon: Icons.settings_rounded,
            label: 'settings'.tr(widgetRef),
            onTap: () {},
            color: context.appTheme.textMuted,
          ),
        ],
      ),
    );
  }
}

class _QuickActionItem extends StatelessWidget {
  const _QuickActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.surfaceColor,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 10),
              Text(label, style: context.labelLarge?.semiBold),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsGrid extends ConsumerWidget {
  const _StatsGrid({required this.data});
  final DashboardData data;

  @override
  Widget build(BuildContext context, WidgetRef widgetRef) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 1200 ? 4 : (constraints.maxWidth > 800 ? 2 : 1);
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 20,
          crossAxisSpacing: 20,
          childAspectRatio: constraints.maxWidth > 1200 ? 1.6 : 2.5,
          children: [
            _KpiCard(
              title: 'kpi_total_customers'.tr(widgetRef),
              value: _number(data.totalCustomers, widgetRef),
              icon: Icons.people_alt_rounded,
              color: AppColors.primaryTeal,
              subtitle: 'customers_in_system'.tr(widgetRef),
            ),
            _KpiCard(
              title: 'kpi_projects'.tr(widgetRef),
              value: _number(data.totalProjects, widgetRef),
              icon: Icons.solar_power_rounded,
              color: AppColors.violet,
              subtitle: '${data.activeProjects} ${'active_projects'.tr(widgetRef)}',
            ),
            _KpiCard(
              title: 'kpi_portfolio_value'.tr(widgetRef),
              value: _money(data.totalProjectsValue, widgetRef),
              icon: Icons.account_balance_wallet_rounded,
              color: AppColors.success,
              subtitle: 'estimated_valuation'.tr(widgetRef),
            ),
            _KpiCard(
              title: 'kpi_installed_capacity'.tr(widgetRef),
              value: '${_numberDouble(data.totalKw, widgetRef)} kW',
              icon: Icons.bolt_rounded,
              color: AppColors.warning,
              subtitle: 'solar_capacity_recorded'.tr(widgetRef),
            ),
          ],
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: context.borderColor),
        boxShadow: context.appTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: context.headlineSmall?.bold,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: context.labelSmall?.withColor(context.onSurfaceVariant).semiBold,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: context.bodySmall?.withColor(AppColors.textMuted).withSize(10),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _MainContent extends ConsumerWidget {
  const _MainContent({required this.data, required this.wide});
  final DashboardData data;
  final bool wide;

  @override
  Widget build(BuildContext context, WidgetRef widgetRef) {
    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Column(
              children: [
                _AnalyticsSection(data: data),
                const SizedBox(height: 32),
                _EnvironmentalImpact(capacity: data.totalKw),
              ],
            ),
          ),
          const SizedBox(width: 32),
          Expanded(
            flex: 1,
            child: Column(
              children: [
                _RecentActivityBox(data: data),
                const SizedBox(height: 32),
                _GeographyBox(data: data),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        _AnalyticsSection(data: data),
        const SizedBox(height: 32),
        _EnvironmentalImpact(capacity: data.totalKw),
        const SizedBox(height: 32),
        _RecentActivityBox(data: data),
        const SizedBox(height: 32),
        _GeographyBox(data: data),
      ],
    );
  }
}

class _AnalyticsSection extends ConsumerWidget {
  const _AnalyticsSection({required this.data});
  final DashboardData data;

  @override
  Widget build(BuildContext context, WidgetRef widgetRef) {
    return Column(
      children: [
        _SectionCard(
          title: 'project_pipeline'.tr(widgetRef),
          subtitle: 'distribution_by_status'.tr(widgetRef),
          child: DashboardDonutChart(data: {
            for (final item in data.projectsByStatus) item.label: item.value,
          }),
        ),
        const SizedBox(height: 32),
        _SectionCard(
          title: 'engineer_performance'.tr(widgetRef),
          subtitle: 'projects_count_by_engineer'.tr(widgetRef),
          child: DashboardBarChart(data: {
            for (final item in data.projectsByEngineer) item.label: item.value,
          }),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    this.subtitle,
    required this.child,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    const padding = EdgeInsets.all(32);
    return Container(
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: context.borderColor),
        boxShadow: context.appTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 32, 32, 0),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.titleLarge?.bold),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: context.bodySmall?.withColor(context.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
                const Spacer(),
                Icon(Icons.more_vert_rounded, color: context.appTheme.textMuted),
              ],
            ),
          ),
          Padding(
            padding: padding,
            child: child,
          ),
        ],
      ),
    );
  }
}

class _GeographyBox extends ConsumerWidget {
  const _GeographyBox({required this.data});
  final DashboardData data;

  @override
  Widget build(BuildContext context, WidgetRef widgetRef) {
    return _SectionCard(
      title: 'customer_geography'.tr(widgetRef),
      subtitle: 'customers_by_gov'.tr(widgetRef),
      child: DashboardHorizontalBarChart(data: {
        for (final item in data.customersByGovernorate) item.label: item.value,
      }),
    );
  }
}

class _EnvironmentalImpact extends ConsumerWidget {
  const _EnvironmentalImpact({required this.capacity});
  final double capacity;

  @override
  Widget build(BuildContext context, WidgetRef widgetRef) {
    final co2 = capacity * 1.2;
    final trees = (co2 * 45).round();

    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF059669), Color(0xFF10B981)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF059669).withValues(alpha: 0.3),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'env_impact'.tr(widgetRef),
                  style: context.titleMedium?.white.bold,
                ),
                const SizedBox(height: 24),
                Text(
                  '${_numberDouble(co2, widgetRef)} ${'ton_co2'.tr(widgetRef)}',
                  style: context.headlineMedium?.white.bold,
                ),
                Text(
                  'co2_saved_yearly'.tr(widgetRef),
                  style: context.bodySmall?.white.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
          Container(
            height: 100,
            width: 1,
            color: Colors.white24,
          ),
          const SizedBox(width: 40),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.forest_rounded, color: Colors.white, size: 32),
                const SizedBox(height: 12),
                Text(
                  _number(trees, widgetRef),
                  style: context.headlineSmall?.white.bold,
                ),
                Text(
                  'trees_equivalent'.tr(widgetRef),
                  style: context.bodySmall?.white.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentActivityBox extends ConsumerWidget {
  const _RecentActivityBox({required this.data});
  final DashboardData data;

  @override
  Widget build(BuildContext context, WidgetRef widgetRef) {
    return Container(
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(32),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('recent_activity'.tr(widgetRef), style: context.titleLarge?.bold),
                TextButton(
                  onPressed: () {},
                  child: Text('view_all'.tr(widgetRef)),
                ),
              ],
            ),
          ),
          _RecentActivityFeed(data: data),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _RecentActivityFeed extends ConsumerWidget {
  const _RecentActivityFeed({required this.data});
  final DashboardData data;

  @override
  Widget build(BuildContext context, WidgetRef widgetRef) {
    final items = [
      ...data.recentProjects.map((p) => _ActivityItem(
        title: p.name.isEmpty ? p.projectNumber : p.name,
        subtitle: '${'project'.tr(widgetRef)} • ${p.projectStatus}',
        icon: Icons.solar_power_rounded,
        color: AppColors.violet,
        time: p.createdDate != null ? p.createdDate!.format('date_format'.tr(widgetRef), widgetRef.watch(localeProvider).languageCode) : '',
        onTap: () => context.go('/projects'),
      )),
      ...data.recentCustomers.map((c) => _ActivityItem(
        title: c.name,
        subtitle: '${'customer'.tr(widgetRef)} • ${c.phone ?? 'no_phone'.tr(widgetRef)}',
        icon: Icons.person_add_rounded,
        color: AppColors.primaryTeal,
        time: c.createdAt != null ? c.createdAt!.format('date_format'.tr(widgetRef), widgetRef.watch(localeProvider).languageCode) : '',
        onTap: () => context.go('/customers'),
      )),
    ];

    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Text('no_recent_activity'.tr(widgetRef), style: context.bodySmall),
        ),
      );
    }

    return Column(
      children: items.take(8).map((item) {
        return item;
      }).toList(),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  const _ActivityItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.time,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.bodyLarge?.bold, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(subtitle, style: context.labelSmall?.withColor(context.onSurfaceVariant)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(time, style: context.labelSmall?.withColor(context.appTheme.textMuted)),
          ],
        ),
      ),
    );
  }
}

class _EntryAnimation extends StatelessWidget {
  const _EntryAnimation({required this.child, required this.index});
  final Widget child;
  final int index;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 600 + (index * 150)),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _ErrorState extends ConsumerWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef widgetRef) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded, size: 64, color: AppColors.error),
          const SizedBox(height: 16),
          Text('dashboard_error'.tr(widgetRef), style: context.titleLarge?.bold),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(message, textAlign: TextAlign.center, style: context.bodyMedium),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: Text('retry'.tr(widgetRef)),
          ),
        ],
      ),
    );
  }
}

String _number(num value, WidgetRef ref) => 
    NumberFormat.decimalPattern(ref.watch(localeProvider).languageCode).format(value);

String _numberDouble(double value, WidgetRef ref) =>
    NumberFormat('#,##0.##', ref.watch(localeProvider).languageCode).format(value);

String _money(double value, WidgetRef ref) {
  final isAr = ref.watch(localeProvider).languageCode == 'ar';
  return NumberFormat.compactCurrency(
    symbol: isAr ? 'ج.م ' : 'EGP ', 
    decimalDigits: 0,
    locale: ref.watch(localeProvider).languageCode,
  ).format(value);
}
