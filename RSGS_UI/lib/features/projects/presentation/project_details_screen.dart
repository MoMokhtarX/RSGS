import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/services/data_refresh_service.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/localization/language_provider.dart';
import '../../../core/localization/date_formatter.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/theme/typography_extensions.dart';
import '../../../core/models/app_models.dart';
import '../../quotations/models/quotation_models.dart';
import '../../quotations/providers/quotations_provider.dart';
import '../data/projects_repository.dart';
import 'projects_screen.dart';

final projectDetailsProvider =
FutureProvider.family<ProjectWithDetails?, int>((ref, projectId) async {
  ref.watch(dataRefreshVersionProvider);
  return ref.watch(projectsRepositoryProvider).getProject(projectId);
});

final projectStatsProvider = FutureProvider.family<Map<String, dynamic>, int>((ref, projectId) async {
  ref.watch(dataRefreshVersionProvider);
  final projectDetails = await ref.watch(projectDetailsProvider(projectId).future);
  final quotations = await ref.watch(projectQuotationsProvider(projectId).future);

  if (projectDetails == null) return {};

  return {
    'totalValue': projectDetails.project.totalValue,
    'totalKw': projectDetails.project.totalKw,
    'quotationsCount': quotations.length,
    'totalQuotationValue': quotations.fold(0.0, (sum, q) => sum + q.totalPrice),
    'status': projectDetails.project.status,
  };
});

class ProjectDetailsScreen extends ConsumerStatefulWidget {
  const ProjectDetailsScreen({
    super.key,
    required this.projectId,
  });

  final int projectId;

  @override
  ConsumerState<ProjectDetailsScreen> createState() => _ProjectDetailsScreenState();
}

class _ProjectDetailsScreenState extends ConsumerState<ProjectDetailsScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final projectAsync = ref.watch(projectDetailsProvider(widget.projectId));

    return Scaffold(
      backgroundColor: context.appTheme.surfaceSubtle,
      body: projectAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 56,
                  color: AppColors.error,
                ),
                const SizedBox(height: 16),
                Text(
                  '${'error'.tr(ref)}: $error',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () {
                    ref.invalidate(projectDetailsProvider(widget.projectId));
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text('retry'.tr(ref)),
                ),
              ],
            ),
          ),
        ),
        data: (project) {
          if (project == null) {
            return Center(
              child: Text(
                'project_not_found'.tr(ref),
                style: context.titleLarge?.extraBold,
              ),
            );
          }

          return CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              _ProjectParallaxAppBar(projectDetails: project),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 40, 16, 0),
                  child: Column(
                    children: [
                      _ProjectMetricGrid(projectId: widget.projectId),
                      const SizedBox(height: 32),
                      _ProjectDashboardContent(projectDetails: project),
                      const SizedBox(height: 64),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProjectParallaxAppBar extends ConsumerWidget {
  final ProjectWithDetails projectDetails;
  const _ProjectParallaxAppBar({required this.projectDetails});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SliverAppBar(
      expandedHeight: 460,
      pinned: false,
      stretch: true,
      clipBehavior: Clip.none,
      backgroundColor: context.primaryColor,
      leading: IconButton(
        onPressed: () => context.pop(),
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
      ),
      title: Text(
        'project_details'.tr(ref),
        style: context.titleMedium?.bold.white,
      ),
      centerTitle: false,
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground, StretchMode.blurBackground],
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                context.primaryColor,
                context.primaryColor.withValues(alpha: 0.8),
                AppColors.indigo,
              ],
            ),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                right: -30,
                top: -30,
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
              ),
              Positioned(
                left: 100,
                bottom: 80,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.accentGold.withValues(alpha: 0.15),
                  ),
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 50, bottom: 30, left: 20, right: 20),
                  child: _ProjectProfileGlassCard(projectDetails: projectDetails),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectProfileGlassCard extends ConsumerWidget {
  final ProjectWithDetails projectDetails;
  const _ProjectProfileGlassCard({required this.projectDetails});

  ProjectModel get project => projectDetails.project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 800),
      margin: EdgeInsets.zero,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark 
            ? [AppColors.darkSurface.withValues(alpha: 0.9), AppColors.darkSurfaceSubtle.withValues(alpha: 0.7)]
            : [Colors.white.withValues(alpha: 0.95), Colors.white.withValues(alpha: 0.8)],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark ? AppColors.glassBorderDark : context.primaryColor.withValues(alpha: 0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.1),
            blurRadius: 40,
            spreadRadius: 2,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
// ...
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Stack(
            children: [
              Positioned(
                top: 12,
                right: 12,
                child: _ProjectActionMenu(
                  project: project, 
                  iconColor: isDark ? Colors.white70 : context.onSurfaceVariant,
                ),
              ),
              Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 20 : 32,
                    vertical: isMobile ? 20 : 32,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _ProjectAvatar(size: isMobile ? 70 : 90),
                      const SizedBox(height: 16),
                      Text(
                        project.name,
                        textAlign: TextAlign.center,
                        style: (isMobile ? context.headlineSmall : context.displaySmall)?.extraBold.withHeight(1.1),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          StatusChip(status: project.status),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.engineering_outlined, size: 16, color: context.onSurfaceVariant),
                              const SizedBox(width: 6),
                              Text(
                                projectDetails.engineerName ?? 'unassigned'.tr(ref),
                                style: context.labelLarge?.medium.withColor(context.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        project.projectNumber,
                        textAlign: TextAlign.center,
                        style: context.bodyLarge?.bold.withColor(context.primaryColor),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 24,
                        runSpacing: 12,
                        alignment: WrapAlignment.center,
                        children: [
                          if (project.createdDate != null)
                            _ProfileInfoItem(
                              icon: Icons.calendar_today_rounded,
                              text: project.createdDate!.format('date_format'.tr(ref), ref.watch(localeProvider).languageCode),
                            ),
                          if (project.installationDate != null)
                            _ProfileInfoItem(
                              icon: Icons.event_available_outlined,
                              text: project.installationDate!.format('date_format'.tr(ref), ref.watch(localeProvider).languageCode),
                            ),
                          _ProfileInfoItem(
                            icon: Icons.solar_power_rounded,
                            text: '${project.totalKw} kW',
                          ),
                        ],
                      ),
                    ],
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

class _ProfileInfoItem extends ConsumerWidget {
  final IconData icon;
  final String text;

  const _ProfileInfoItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (text.isEmpty || text == '-') return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: context.onSurfaceVariant.withValues(alpha: 0.7)),
        const SizedBox(width: 6),
        Text(
          text,
          style: context.labelLarge?.medium.withColor(context.onSurfaceVariant).copyWith(
            letterSpacing: ref.watch(localeProvider).languageCode == 'ar' ? 1.2 : null,
          ),
        ),
      ],
    );
  }
}

class _ProjectMetricGrid extends ConsumerWidget {
  final int projectId;
  const _ProjectMetricGrid({required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(projectStatsProvider(projectId));

    return statsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (stats) {
        if (stats.isEmpty) return const SizedBox.shrink();
        return Wrap(
          spacing: 20,
          runSpacing: 20,
          alignment: WrapAlignment.center,
          children: [
            _MetricCard(
              label: 'capacity'.tr(ref),
              value: '${stats['totalKw'].toStringAsFixed(1)} kW',
              icon: Icons.solar_power_rounded,
              color: AppColors.primaryTeal,
              glowColor: AppColors.primaryGlow,
            ),
            _MetricCard(
              label: 'total_value'.tr(ref),
              value: formatCurrency(stats['totalValue']),
              icon: Icons.payments_outlined,
              color: AppColors.success,
              glowColor: AppColors.successGlow,
            ),
            _MetricCard(
              label: 'quotations'.tr(ref),
              value: stats['quotationsCount'].toString(),
              icon: Icons.request_quote_rounded,
              color: Colors.indigo,
              glowColor: Colors.indigo.withValues(alpha: 0.15),
            ),
            _MetricCard(
              label: 'quotation_value'.tr(ref),
              value: formatCurrency(stats['totalQuotationValue']),
              icon: Icons.account_balance_wallet_outlined,
              color: AppColors.primaryTeal,
              glowColor: AppColors.primaryGlow,
            ),
            _MetricCard(
              label: 'status'.tr(ref),
              value: stats['status'] ?? '-',
              icon: Icons.info_outline_rounded,
              color: AppColors.info,
              glowColor: AppColors.infoGlow,
            ),
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color glowColor;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.glowColor,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 28,
      padding: const EdgeInsets.all(24),
      child: SizedBox(
        width: 152,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 20),
            Text(
              value,
              style: context.titleLarge?.extraBold,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              label.toUpperCase(),
              style: context.labelSmall?.extraBold.withColor(context.onSurfaceVariant).withLetterSpacing(1),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectDashboardContent extends StatelessWidget {
  final ProjectWithDetails projectDetails;
  const _ProjectDashboardContent({required this.projectDetails});

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveBreakpoints.of(context).largerThan(MOBILE);

    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: _ProjectSidebarInfo(projectDetails: projectDetails)),
          const SizedBox(width: 32),
          Expanded(flex: 5, child: _ProjectMainFeed(projectDetails: projectDetails)),
        ],
      );
    }

    return Column(
      children: [
        _ProjectSidebarInfo(projectDetails: projectDetails),
        const SizedBox(height: 32),
        _ProjectMainFeed(projectDetails: projectDetails),
      ],
    );
  }
}

class _ProjectSidebarInfo extends ConsumerWidget {
  final ProjectWithDetails projectDetails;
  const _ProjectSidebarInfo({required this.projectDetails});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        _ProjectNotesCard(project: projectDetails.project),
        const SizedBox(height: 32),
        _ProjectLocationCard(project: projectDetails.project),
      ],
    );
  }
}

class _ProjectMainFeed extends ConsumerWidget {
  final ProjectWithDetails projectDetails;
  const _ProjectMainFeed({required this.projectDetails});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        _ProjectCustomerCard(projectDetails: projectDetails),
        const SizedBox(height: 32),
        _ProjectQuotationsSection(projectId: projectDetails.project.id),
        const SizedBox(height: 32),
        _ProjectMapCard(project: projectDetails.project),
      ],
    );
  }
}

class _ProjectNotesCard extends ConsumerWidget {
  final ProjectModel project;
  const _ProjectNotesCard({required this.project});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = context.theme.brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.pinGoldBackgroundDark : AppColors.pinGoldBackground,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: isDark ? AppColors.pinGoldBorderDark : AppColors.pinGoldBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.push_pin_rounded, color: AppColors.pinGold, size: 24),
              const SizedBox(width: 12),
              Text('notes'.tr(ref), style: context.titleMedium?.extraBold.withColor(AppColors.pinGold)),
              const Spacer(),
              IconButton(
                onPressed: () => _showEditNotesDialog(context, ref, project),
                icon: const Icon(Icons.edit_note_rounded, color: AppColors.pinGold),
                tooltip: 'edit_notes'.tr(ref),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (project.notes?.isNotEmpty == true)
            Text(
              project.notes!, 
              style: context.bodyLarge?.medium.withHeight(1.6)
            )
          else
            Center(
              child: TextButton.icon(
                onPressed: () => _showEditNotesDialog(context, ref, project),
                icon: const Icon(Icons.add_rounded),
                label: Text('add_note'.tr(ref)),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.pinGold,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProjectLocationCard extends ConsumerWidget {
  final ProjectModel project;
  const _ProjectLocationCard({required this.project});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GlassContainer(
      borderRadius: 28,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on_rounded, color: AppColors.primaryTeal, size: 24),
              const SizedBox(width: 12),
              Text('location'.tr(ref), style: context.titleMedium?.extraBold),
            ],
          ),
          const SizedBox(height: 24),
          _LocationItem(
            icon: Icons.location_city_rounded,
            label: 'governorate'.tr(ref),
            value: project.governorate?.tr(ref) ?? '-',
          ),
          const SizedBox(height: 16),
          _LocationItem(
            icon: Icons.map_rounded,
            label: 'city'.tr(ref),
            value: project.city ?? '-',
          ),
          const SizedBox(height: 16),
          _LocationItem(
            icon: Icons.home_rounded,
            label: 'address'.tr(ref),
            value: project.address ?? '-',
          ),
        ],
      ),
    );
  }
}

class _LocationItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _LocationItem({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: context.primaryColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: context.primaryColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: context.labelSmall?.medium.withColor(context.onSurfaceVariant)),
              Text(value, style: context.bodyMedium?.bold),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProjectCustomerCard extends ConsumerWidget {
  final ProjectWithDetails projectDetails;
  const _ProjectCustomerCard({required this.projectDetails});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GlassContainer(
      borderRadius: 28,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_rounded, color: AppColors.primaryTeal, size: 24),
              const SizedBox(width: 12),
              Text('customer'.tr(ref), style: context.titleMedium?.extraBold),
            ],
          ),
          const SizedBox(height: 24),
          InkWell(
            onTap: () => context.push('/customers/${projectDetails.project.customerId}'),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.appTheme.surfaceSubtle.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.borderColor.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: context.primaryColor.withValues(alpha: 0.1),
                    child: Text(
                      projectDetails.customerName?.isNotEmpty == true ? projectDetails.customerName![0].toUpperCase() : 'C',
                      style: TextStyle(color: context.primaryColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          projectDetails.customerName ?? '${'customer'.tr(ref)} #${projectDetails.project.customerId}',
                          style: context.titleSmall?.bold,
                        ),
                        Text(
                          '${'customer_id'.tr(ref)}: ${projectDetails.project.customerId}',
                          style: context.labelSmall?.medium.withColor(context.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectQuotationsSection extends ConsumerWidget {
  final int projectId;
  const _ProjectQuotationsSection({required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quotationsAsync = ref.watch(projectQuotationsProvider(projectId));

    return GlassContainer(
      borderRadius: 28,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('quotations'.tr(ref), style: context.titleMedium?.extraBold),
              const Spacer(),
              Consumer(
                builder: (context, ref, child) {
                  final projectAsync = ref.watch(projectDetailsProvider(projectId));
                  return projectAsync.maybeWhen(
                    data: (project) => TextButton.icon(
                      onPressed: () => context.push('/quotations/new?customerId=${project?.project.customerId}&projectId=$projectId'),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: Text('add'.tr(ref)),
                    ),
                    orElse: () => const SizedBox.shrink(),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          quotationsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('error'.tr(ref))),
            data: (quotations) {
              if (quotations.isEmpty) return _EmptyFeed(label: 'no_quotations_desc'.tr(ref));
              return Column(
                children: quotations.map((q) => _ProjectQuotationItem(quotation: q)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ProjectQuotationItem extends StatefulWidget {
  final QuotationModel quotation;
  const _ProjectQuotationItem({required this.quotation});

  @override
  State<_ProjectQuotationItem> createState() => _ProjectQuotationItemState();
}

class _ProjectQuotationItemState extends State<_ProjectQuotationItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _isHovered 
            ? context.primaryColor.withValues(alpha: 0.08) 
            : context.appTheme.surfaceSubtle,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isHovered ? context.primaryColor.withValues(alpha: 0.2) : context.borderColor,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.go('/quotations/${widget.quotation.id}'),
          onHover: (hovering) => setState(() => _isHovered = hovering),
          borderRadius: BorderRadius.circular(16),
          child: ListTile(
            leading: Icon(Icons.request_quote_rounded, color: context.primaryColor),
            title: Text(widget.quotation.quotationNumber, style: context.titleSmall?.bold),
            subtitle: Consumer(
              builder: (context, ref, child) => Text('${widget.quotation.type.label.tr(ref)} • ${widget.quotation.status.label.tr(ref)}'),
            ),
            trailing: Text(
              formatCurrency(widget.quotation.totalPrice),
              style: context.labelLarge?.bold.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyFeed extends StatelessWidget {
  final String label;
  const _EmptyFeed({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(child: Text(label, style: context.bodyMedium?.medium.withColor(context.onSurfaceVariant))),
    );
  }
}

class _ProjectAvatar extends StatelessWidget {
  final double size;
  const _ProjectAvatar({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: context.primaryColor.withValues(alpha: 0.1),
        shape: BoxShape.circle,
        border: Border.all(color: context.primaryColor.withValues(alpha: 0.2), width: 2),
      ),
      alignment: Alignment.center,
      child: Icon(Icons.solar_power_rounded, size: size * 0.5, color: context.primaryColor),
    );
  }
}

class _ProjectActionMenu extends ConsumerStatefulWidget {
  final ProjectModel project;
  final Color iconColor;
  const _ProjectActionMenu({required this.project, required this.iconColor});

  @override
  ConsumerState<_ProjectActionMenu> createState() => _ProjectActionMenuState();
}

class _ProjectActionMenuState extends ConsumerState<_ProjectActionMenu> {
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
    return MenuAnchor(
      controller: _controller,
      alignmentOffset: const Offset(-200, 10),
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
                _ProjectActionMenuItem(
                  icon: Icons.edit_rounded,
                  label: 'edit'.tr(ref),
                  onTap: () => _handleAction(() => showProjectDialog(context, ref, project: widget.project)),
                ),
                const SizedBox(height: 4),
                _ProjectActionMenuItem(
                  icon: Icons.delete_rounded,
                  label: 'delete'.tr(ref),
                  color: AppColors.error,
                  onTap: () => _handleAction(() => _showDeleteConfirmation(context, ref, widget.project)),
                ),
              ],
            ),
          ),
        ),
      ],
      builder: (context, controller, child) {
        return IconButton(
          onPressed: () => controller.isOpen ? controller.close() : controller.open(),
          icon: Icon(Icons.more_vert_rounded, color: widget.iconColor),
        );
      },
    );
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref, ProjectModel project) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('delete'.tr(ref)),
        content: Text('${'delete'.tr(ref)} ${project.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('cancel'.tr(ref))),
          FilledButton(
            onPressed: () async {
              await ref.read(projectsRepositoryProvider).deleteProject(project.id);
              DataRefreshCoordinator.refresh(ref);
              if (context.mounted) {
                Navigator.pop(context);
                context.go('/projects');
              }
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: Text('delete'.tr(ref)),
          ),
        ],
      ),
    );
  }
}

class _ProjectActionMenuItem extends StatefulWidget {
  const _ProjectActionMenuItem({
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
  State<_ProjectActionMenuItem> createState() => _ProjectActionMenuItemState();
}

class _ProjectActionMenuItemState extends State<_ProjectActionMenuItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final displayColor = widget.color ?? context.onSurfaceColor;
    final hoverColor = widget.color ?? AppColors.primaryTeal;

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
            width: 180,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _isHovered ? hoverColor.withValues(alpha: 0.08) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                AnimatedScale(
                  scale: _isHovered ? 1.1 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(widget.icon, size: 20, color: _isHovered ? hoverColor : displayColor),
                ),
                const SizedBox(width: 12),
                Text(
                  widget.label,
                  style: context.labelLarge?.withColor(_isHovered ? hoverColor : displayColor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProjectMapCard extends StatelessWidget {
  final ProjectModel project;
  const _ProjectMapCard({required this.project});

  @override
  Widget build(BuildContext context) {
    final lat = project.latitude;
    final lon = project.longitude;
    final point = (lat != null && lon != null) ? LatLng(lat, lon) : null;

    return GlassContainer(
      borderRadius: 28,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.map_rounded, color: AppColors.primaryTeal, size: 24),
              const SizedBox(width: 12),
              Consumer(builder: (context, ref, _) => Text('location'.tr(ref), style: context.titleMedium?.extraBold)),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            height: 400,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.borderColor.withValues(alpha: 0.3)),
            ),
            clipBehavior: Clip.antiAlias,
            child: point == null
                ? Center(
                    child: Consumer(
                      builder: (context, ref, _) => Text(
                        'no_location_data'.tr(ref),
                        style: context.bodyMedium?.medium.withColor(context.onSurfaceVariant),
                      ),
                    ),
                  )
                : FlutterMap(
                    options: MapOptions(
                      initialCenter: point,
                      initialZoom: 15,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.rsgs.crm',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: point,
                            width: 40,
                            height: 40,
                            child: const Icon(Icons.location_on, color: AppColors.error, size: 40),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

void _showEditNotesDialog(BuildContext context, WidgetRef ref, ProjectModel project) async {
  final notesCtrl = TextEditingController(text: project.notes);
  bool saving = false;

  await showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text('edit_notes'.tr(ref), style: context.titleLarge?.bold),
        content: SizedBox(
          width: 500,
          child: TextField(
            controller: notesCtrl,
            maxLines: 5,
            decoration: customInputDecoration(context, 'notes'.tr(ref), icon: Icons.notes_rounded),
            enabled: !saving,
          ),
        ),
        actions: [
          TextButton(
            onPressed: saving ? null : () => Navigator.pop(context),
            child: Text('cancel'.tr(ref)),
          ),
          FilledButton(
            onPressed: saving ? null : () async {
              setState(() => saving = true);
              try {
                final updatedProject = project.copyWith(notes: notesCtrl.text.trim());
                await ref.read(projectsRepositoryProvider).updateProject(updatedProject);
                DataRefreshCoordinator.refresh(ref);
                ref.invalidate(projectDetailsProvider(project.id));
                if (context.mounted) Navigator.pop(context);
              } catch (e) {
                setState(() => saving = false);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${'error'.tr(ref)}: $e'), backgroundColor: AppColors.error),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.primaryTeal),
            child: Text(saving ? 'saving'.tr(ref) : 'save'.tr(ref)),
          ),
        ],
      ),
    ),
  );
}
