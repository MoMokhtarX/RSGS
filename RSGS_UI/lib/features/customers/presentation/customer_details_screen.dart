import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/services/data_refresh_service.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/localization/language_provider.dart';
import '../../../core/localization/date_formatter.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/theme/typography_extensions.dart';
import '../../../core/models/app_models.dart';
import '../../auth/data/auth_repository.dart';
import '../../projects/presentation/projects_screen.dart';
import '../data/customers_repository.dart';
import '../../projects/data/projects_repository.dart';
import '../../customer_activity/data/customer_activity_repository.dart';
import '../../quotations/models/quotation_models.dart';
import '../../quotations/providers/quotations_provider.dart';
import 'customers_screen.dart';

final customerProjectsProvider = FutureProvider.family<List<ProjectModel>, int>((ref, customerId) async {
  ref.watch(dataRefreshVersionProvider);
  final projects = await ref.watch(projectsStreamProvider.future);
  return projects.where((p) => p.customerId == customerId).toList();
});

final customerStatsProvider = FutureProvider.family<Map<String, dynamic>, int>((ref, customerId) async {
  ref.watch(dataRefreshVersionProvider);
  final projects = await ref.watch(customerProjectsProvider(customerId).future);
  final quotations = await ref.watch(customerQuotationsProvider(customerId).future);
  
  final totalValue = projects.fold(0.0, (sum, p) => sum + p.totalValue);
  final totalKw = projects.fold(0.0, (sum, p) => sum + p.totalKw);
  final totalQuotationValue = quotations.fold(0.0, (sum, q) => sum + q.totalPrice);
  
  return {
    'count': projects.length,
    'totalValue': totalValue,
    'totalKw': totalKw,
    'active': projects.where((p) => p.status != 'Completed' && p.status != 'Cancelled').length,
    'quotationsCount': quotations.length,
    'totalQuotationValue': totalQuotationValue,
  };
});

class CustomerDetailsScreen extends ConsumerStatefulWidget {
  final int customerId;
  const CustomerDetailsScreen({super.key, required this.customerId});

  @override
  ConsumerState<CustomerDetailsScreen> createState() => _CustomerDetailsScreenState();
}

class _CustomerDetailsScreenState extends ConsumerState<CustomerDetailsScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customerAsync = ref.watch(customerDetailsProvider(widget.customerId));

    return Scaffold(
      backgroundColor: context.appTheme.surfaceSubtle,
      body: customerAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('${'error'.tr(ref)}: $err')),
        data: (customer) {
          if (customer == null) return Center(child: Text('customer_not_found'.tr(ref)));

          return CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              _ParallaxAppBar(customer: customer),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0), 
                  child: Column(
                    children: [
                      _QuickActionToolbar(customer: customer.customer),
                      const SizedBox(height: 32),
                      _MetricGrid(customerId: widget.customerId),
                      const SizedBox(height: 32),
                      _DashboardContent(customer: customer),
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

class _ParallaxAppBar extends ConsumerWidget {
  final CustomerWithDetails customer;
  const _ParallaxAppBar({required this.customer});

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
        'customer_details'.tr(ref),
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
                  child: _ProfileGlassCard(customer: customer),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileGlassCard extends ConsumerWidget {
  final CustomerWithDetails customer;
  const _ProfileGlassCard({required this.customer});

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
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Stack(
            children: [
              Positioned(
                top: 12,
                right: 12,
                child: _ActionMenu(
                  customer: customer.customer, 
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
                    children: [
                      _Avatar(name: customer.customer.name, size: isMobile ? 70 : 90),
                      const SizedBox(height: 16),
                      Text(
                        customer.customer.name,
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
                          StatusChip(status: customer.customer.followUpStatus ?? 'New'),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.person_outline_rounded, size: 16, color: context.onSurfaceVariant),
                              const SizedBox(width: 6),
                              () {
                                final name = customer.assignedUserName;
                                if (name != null && name.trim().isNotEmpty) {
                                  return Text(
                                    name,
                                    style: context.labelLarge?.medium.withColor(context.onSurfaceVariant),
                                  );
                                }

                                final userId = customer.customer.assignedUserId;
                                if (userId == null) {
                                  return Text(
                                    'unassigned'.tr(ref),
                                    style: context.labelLarge?.medium.withColor(context.onSurfaceVariant),
                                  );
                                }

                                final engineersAsync = ref.watch(engineersProvider);
                                return engineersAsync.when(
                                  loading: () => const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                                  error: (err, stack) => Text('unassigned'.tr(ref), style: context.labelLarge?.medium.withColor(context.onSurfaceVariant)),
                                  data: (users) {
                                    final user = users.cast<UserModel?>().firstWhere((u) => u?.id == userId, orElse: () => null);
                                    return Text(
                                      user?.fullName ?? 'unassigned'.tr(ref),
                                      style: context.labelLarge?.medium.withColor(context.onSurfaceVariant),
                                    );
                                  },
                                );
                              }(),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.phone_enabled_rounded, size: 16, color: context.primaryColor),
                          const SizedBox(width: 8),
                          Text(
                            customer.customer.phone,
                            style: context.bodyLarge?.bold.withColor(context.primaryColor),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 24,
                        runSpacing: 12,
                        alignment: WrapAlignment.center,
                        children: [
                          if (customer.customer.inquiryDate != null)
                            _ProfileInfoItem(
                              icon: Icons.calendar_today_rounded,
                              text: customer.customer.inquiryDate!.format('date_format'.tr(ref), ref.watch(localeProvider).languageCode),
                            ),
                          if (customer.customer.phone2 != null && customer.customer.phone2!.isNotEmpty)
                            _ProfileInfoItem(
                              icon: Icons.phone_iphone_rounded,
                              text: customer.customer.phone2!,
                            ),
                          if (customer.customer.email != null && customer.customer.email!.isNotEmpty)
                            _ProfileInfoItem(
                              icon: Icons.email_outlined,
                              text: customer.customer.email!,
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

class _QuickActionToolbar extends ConsumerWidget {
  final CustomerModel customer;
  const _QuickActionToolbar({required this.customer});

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.borderColor),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: QuickActionButton(
                icon: Icons.call_rounded,
                label: 'call'.tr(ref).toUpperCase(),
                onPressed: () => _launch('tel:${customer.phone}'),
                color: AppColors.success,
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: QuickActionButton(
                iconWidget: SvgPicture.asset(
                  'assets/svg/WhatsApp.svg',
                  width: 24,
                  height: 24,
                  colorFilter: const ColorFilter.mode(AppColors.socialWhatsapp, BlendMode.srcIn),
                ),
                label: 'whatsapp'.tr(ref),
                onPressed: () {
                   var phone = customer.phone.replaceAll(RegExp(r'[^0-9]'), '');
                   _launch('https://wa.me/$phone');
                },
                color: AppColors.socialWhatsapp,
              ),
            ),
            if (customer.email != null) ...[
              const VerticalDivider(width: 1),
              Expanded(
                child: QuickActionButton(
                  icon: Icons.email_rounded,
                  label: 'email'.tr(ref).toUpperCase(),
                  onPressed: () => _launch('mailto:${customer.email}'),
                  color: AppColors.info,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// REMOVED _ToolbarButton as it was replaced by QuickActionButton


class _MetricGrid extends ConsumerWidget {
  final int customerId;
  const _MetricGrid({required this.customerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(customerStatsProvider(customerId));

    return statsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (stats) {
        return Wrap(
          spacing: 20,
          runSpacing: 20,
          alignment: WrapAlignment.center,
          children: [
            _MetricCard(
              label: 'projects'.tr(ref),
              value: stats['count'].toString(),
              icon: Icons.folder_shared_rounded,
              color: AppColors.primaryTeal,
              glowColor: AppColors.primaryGlow,
            ),
            _MetricCard(
              label: 'total_kw'.tr(ref),
              value: '${stats['totalKw'].toStringAsFixed(1)} kW',
              icon: Icons.bolt_rounded,
              color: AppColors.accentGold,
              glowColor: AppColors.accentGold.withValues(alpha: 0.2),
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
    return Container(
      width: 200,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.borderColor),
        boxShadow: [
          BoxShadow(
            color: glowColor,
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
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
    );
  }
}

class _DashboardContent extends StatelessWidget {
  final CustomerWithDetails customer;
  const _DashboardContent({required this.customer});

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveBreakpoints.of(context).largerThan(MOBILE);

    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: _SidebarInfo(customer: customer)),
          const SizedBox(width: 32),
          Expanded(flex: 5, child: _MainFeed(customer: customer.customer)),
        ],
      );
    }

    return Column(
      children: [
        _SidebarInfo(customer: customer),
        const SizedBox(height: 32),
        _MainFeed(customer: customer.customer),
      ],
    );
  }
}

class _SidebarInfo extends ConsumerWidget {
  final CustomerWithDetails customer;
  const _SidebarInfo({required this.customer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        _NotesCard(customer: customer.customer),
        const SizedBox(height: 32),
        _TimelineSection(customerId: customer.customer.id),
      ],
    );
  }
}

class _MainFeed extends ConsumerWidget {
  final CustomerModel customer;
  const _MainFeed({required this.customer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        _ProjectPreviewSection(customerId: customer.id),
        const SizedBox(height: 32),
        _QuotationPreviewSection(customerId: customer.id),
        const SizedBox(height: 32),
        _InteractionTracking(customer: customer),
      ],
    );
  }
}

class _QuotationPreviewSection extends ConsumerWidget {
  final int customerId;
  const _QuotationPreviewSection({required this.customerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quotationsAsync = ref.watch(customerQuotationsProvider(customerId));

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('quotations'.tr(ref), style: context.titleMedium?.extraBold),
              const Spacer(),
              TextButton.icon(
                onPressed: () => context.push('/quotations/new?customerId=$customerId'),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text('add'.tr(ref)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          quotationsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('error'.tr(ref))),
            data: (quotations) {
              if (quotations.isEmpty) return _EmptyFeed(label: 'no_data'.tr(ref));
              return Column(
                children: quotations.map((q) => _FeedQuotationItem(quotation: q)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FeedQuotationItem extends StatefulWidget {
  final QuotationModel quotation;
  const _FeedQuotationItem({required this.quotation});

  @override
  State<_FeedQuotationItem> createState() => _FeedQuotationItemState();
}

class _FeedQuotationItemState extends State<_FeedQuotationItem> {
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
            subtitle: Text('${widget.quotation.type.label} • ${widget.quotation.status.label}'),
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

class _ProjectPreviewSection extends ConsumerWidget {
  final int customerId;
  const _ProjectPreviewSection({required this.customerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(customerProjectsProvider(customerId));

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('projects'.tr(ref), style: context.titleMedium?.extraBold),
              const Spacer(),
              TextButton.icon(
                onPressed: () => showProjectDialog(context, ref, initialCustomerId: customerId),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text('add'.tr(ref)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          projectsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('error'.tr(ref))),
            data: (projects) {
              if (projects.isEmpty) return _EmptyFeed(label: 'no_projects_found'.tr(ref));
              return Column(
                children: projects.map((p) => _FeedProjectItem(project: p)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FeedProjectItem extends StatefulWidget {
  final ProjectModel project;
  const _FeedProjectItem({required this.project});

  @override
  State<_FeedProjectItem> createState() => _FeedProjectItemState();
}

class _FeedProjectItemState extends State<_FeedProjectItem> {
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
        boxShadow: _isHovered ? [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ] : [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.go('/projects/${widget.project.id}'),
          onHover: (hovering) => setState(() => _isHovered = hovering),
          borderRadius: BorderRadius.circular(16),
          child: ListTile(
            leading: AnimatedScale(
              scale: _isHovered ? 1.1 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Icon(Icons.solar_power_rounded, color: context.primaryColor),
            ),
            title: Text(widget.project.name, style: context.titleSmall?.bold),
            subtitle: Text('${widget.project.totalKw} kW • ${widget.project.status}'),
            trailing: AnimatedPadding(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.only(right: _isHovered ? 0 : 4),
              child: const Icon(Icons.chevron_right_rounded, size: 20),
            ),
          ),
        ),
      ),
    );
  }
}

class _TimelineSection extends ConsumerWidget {
  final int customerId;
  const _TimelineSection({required this.customerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followUpsAsync = ref.watch(customerFollowUpsProvider(customerId));
    final interactionsAsync = ref.watch(customerInteractionsProvider(customerId));

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'activity_timeline'.tr(ref),
                  style: context.titleMedium?.extraBold,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              _ActivityActions(customerId: customerId),
            ],
          ),
          const SizedBox(height: 24),
          () {
            if (followUpsAsync.isLoading || interactionsAsync.isLoading) return const Center(child: CircularProgressIndicator());
            final f = followUpsAsync.value ?? [];
            final i = interactionsAsync.value ?? [];
            final items = [
              ...f.map((x) => _TimelineData(date: x.scheduledAt, title: x.type.tr(ref), desc: x.notes ?? '', icon: Icons.schedule_rounded, color: Colors.orange)),
              ...i.map((x) => _TimelineData(date: x.occurredAt, title: x.subject ?? x.type.tr(ref), desc: x.details, icon: Icons.forum_rounded, color: context.primaryColor)),
            ]..sort((a, b) => b.date.compareTo(a.date));

            if (items.isEmpty) return _EmptyFeed(label: 'no_activities'.tr(ref));

            return Column(
              children: items.take(5).map((item) => _FeedTimelineItem(data: item)).toList(),
            );
          }(),
        ],
      ),
    );
  }
}

class _TimelineData {
  final DateTime date; final String title; final String desc; final IconData icon; final Color color;
  _TimelineData({required this.date, required this.title, required this.desc, required this.icon, required this.color});
}

class _FeedTimelineItem extends StatelessWidget {
  final _TimelineData data;
  const _FeedTimelineItem({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: data.color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(data.icon, size: 16, color: data.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        data.title,
                        style: context.labelLarge?.extraBold,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      data.date.format('dd/MM/yyyy'),
                      style: context.labelSmall?.medium.withColor(context.onSurfaceVariant),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  data.desc,
                  style: context.bodySmall?.medium.withColor(context.onSurfaceVariant),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
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

class _InteractionTracking extends ConsumerWidget {
  final CustomerModel customer;
  const _InteractionTracking({required this.customer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: AppColors.primaryTeal,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'interaction_tracking'.tr(ref),
                style: context.titleMedium?.extraBold,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _InteractionStepItem(
            index: 1,
            title: 'first_contact'.tr(ref),
            comment: customer.firstCallNotes,
            date: customer.firstActionDate,
          ),
          _InteractionStepItem(
            index: 2,
            title: '${'follow_up'.tr(ref)} 1',
            comment: customer.secondCallNotes,
            date: customer.secondActionDate,
          ),
          _InteractionStepItem(
            index: 3,
            title: '${'follow_up'.tr(ref)} 2',
            comment: customer.thirdCallNotes,
            date: customer.thirdActionDate,
          ),
          _InteractionStepItem(
            index: 4,
            title: 'final_contact'.tr(ref),
            comment: customer.fourthCallNotes,
            date: customer.fourthActionDate,
          ),
        ],
      ),
    );
  }
}

class _InteractionStepItem extends ConsumerWidget {
  final int index;
  final String title;
  final String? comment;
  final DateTime? date;

  const _InteractionStepItem({
    required this.index,
    required this.title,
    this.comment,
    this.date,
  });

  @override
  Widget build(BuildContext context, WidgetRef widgetRef) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.appTheme.surfaceSubtle,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryTeal,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      index.toString(),
                      style: const TextStyle(
                        color: Colors.white, 
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    title, 
                    style: context.titleSmall?.bold,
                  ),
                ],
              ),
              if (date != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: context.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 12, color: context.primaryColor),
                      const SizedBox(width: 6),
                      Text(
                        date!.format('dd MMMM, yyyy'),
                        style: context.labelSmall?.bold.withColor(context.primaryColor),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'comment'.tr(widgetRef),
            style: context.labelSmall?.bold.withColor(context.onSurfaceVariant.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.borderColor),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.chat_bubble_outline_rounded, 
                  size: 18, 
                  color: context.primaryColor.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    (comment != null && comment!.isNotEmpty) ? comment! : '-',
                    style: context.bodyMedium?.medium.withHeight(1.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name; final double size;
  const _Avatar({required this.name, required this.size});

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
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(fontSize: size * 0.4, fontWeight: FontWeight.bold, color: context.primaryColor),
      ),
    );
  }
}

class _ActionMenu extends ConsumerStatefulWidget {
  final CustomerModel customer;
  final Color iconColor;
  const _ActionMenu({required this.customer, required this.iconColor});

  @override
  ConsumerState<_ActionMenu> createState() => _ActionMenuState();
}

class _ActionMenuState extends ConsumerState<_ActionMenu> {
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
                _ActionMenuItem(
                  icon: Icons.edit_rounded,
                  label: 'edit'.tr(ref),
                  onTap: () => _handleAction(() => showCustomerDialog(context, ref, customer: widget.customer)),
                ),
                const SizedBox(height: 4),
                _ActionMenuItem(
                  icon: Icons.delete_rounded,
                  label: 'delete'.tr(ref),
                  color: AppColors.error,
                  onTap: () => _handleAction(() => _showDeleteConfirmation(context, ref, widget.customer)),
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

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref, CustomerModel customer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('delete'.tr(ref)),
        content: Text('${'delete'.tr(ref)} ${customer.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('cancel'.tr(ref))),
          FilledButton(
            onPressed: () async {
              await ref.read(customersRepositoryProvider).deleteCustomer(customer.id);
              DataRefreshCoordinator.refresh(ref);
              if (context.mounted) {
                Navigator.pop(context);
                context.go('/customers');
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

class _ActionMenuItem extends StatefulWidget {
  const _ActionMenuItem({
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
  State<_ActionMenuItem> createState() => _ActionMenuItemState();
}

class _ActionMenuItemState extends State<_ActionMenuItem> {
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

class _NotesCard extends ConsumerWidget {
  final CustomerModel customer;
  const _NotesCard({required this.customer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = context.theme.brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.pinGoldBackgroundDark : AppColors.pinGoldBackground,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? AppColors.pinGoldBorderDark : AppColors.pinGoldBorder, width: 1.5),
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
                onPressed: () => _showEditCustomerNotesDialog(context, ref, customer),
                icon: const Icon(Icons.edit_note_rounded, color: AppColors.pinGold),
                tooltip: 'edit_notes'.tr(ref),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (customer.notes?.isNotEmpty == true)
            Text(
              customer.notes!, 
              style: context.bodyLarge?.medium.withHeight(1.6)
            )
          else
            Center(
              child: TextButton.icon(
                onPressed: () => _showEditCustomerNotesDialog(context, ref, customer),
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

class _ActivityActions extends ConsumerWidget {
  final int customerId;
  const _ActivityActions({required this.customerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        IconButton(onPressed: () => _showInteractionDialog(context, ref), icon: const Icon(Icons.add_comment_rounded, size: 20)),
        IconButton(onPressed: () => _showFollowUpDialog(context, ref), icon: const Icon(Icons.add_task_rounded, size: 20)),
      ],
    );
  }

  void _showInteractionDialog(BuildContext context, WidgetRef ref) async {
    final details = TextEditingController();
    final subject = TextEditingController();
    var type = 'call'.tr(ref);
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: Text('add_interaction'.tr(ref), style: context.titleLarge?.bold),
          content: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _StyledDropdown(
                  value: type,
                  items: ['call'.tr(ref), 'whatsapp'.tr(ref), 'email_item'.tr(ref), 'meeting'.tr(ref), 'note'.tr(ref)],
                  onChanged: (v) => setState(() => type = v),
                  label: 'type'.tr(ref),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: subject,
                  decoration: customInputDecoration(context, 'description'.tr(ref), icon: Icons.description_rounded),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: details,
                  maxLines: 3,
                  decoration: customInputDecoration(context, 'notes'.tr(ref), icon: Icons.notes_rounded),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('cancel'.tr(ref), style: context.labelLarge?.bold.withColor(AppColors.primaryTeal)),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () async {
                if (details.text.trim().isEmpty) return;
                await ref.read(customerActivityRepositoryProvider).createInteraction(
                      customerId,
                      type: type,
                      subject: subject.text.trim().isEmpty ? null : subject.text.trim(),
                      details: details.text.trim(),
                    );
                DataRefreshCoordinator.refresh(ref);
                if (context.mounted) Navigator.pop(context);
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryTeal,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text('save'.tr(ref), style: context.labelLarge?.bold.white),
            ),
          ],
          actionsPadding: const EdgeInsets.fromLTRB(0, 0, 24, 20),
        ),
      ),
    );
  }

  void _showFollowUpDialog(BuildContext context, WidgetRef ref) async {
    final notes = TextEditingController();
    var type = 'call'.tr(ref);
    var date = DateTime.now().add(const Duration(days: 1));
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: Text('add_follow_up'.tr(ref), style: context.titleLarge?.bold),
          content: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _StyledDropdown(
                  value: type,
                  items: ['call'.tr(ref), 'whatsapp'.tr(ref), 'meeting'.tr(ref), 'visit'.tr(ref)],
                  onChanged: (v) => setState(() => type = v),
                  label: 'type'.tr(ref),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: date,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setState(() => date = picked);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: customInputDecoration(context, 'date'.tr(ref), icon: Icons.calendar_month_rounded),
                    child: Text(date.format('dd/MM/yyyy'), style: context.bodyLarge?.bold),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: notes,
                  maxLines: 3,
                  decoration: customInputDecoration(context, 'notes'.tr(ref), icon: Icons.notes_rounded),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('cancel'.tr(ref), style: context.labelLarge?.bold.withColor(AppColors.primaryTeal)),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () async {
                await ref.read(customerActivityRepositoryProvider).createFollowUp(
                      customerId,
                      type: type,
                      scheduledAt: date,
                      notes: notes.text.trim(),
                    );
                DataRefreshCoordinator.refresh(ref);
                if (context.mounted) Navigator.pop(context);
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryTeal,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text('save'.tr(ref), style: context.labelLarge?.bold.white),
            ),
          ],
      ),
      )
    );
  }
}

class _StyledDropdown extends StatefulWidget {
  const _StyledDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
    required this.label,
  });

  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;
  final String label;

  @override
  State<_StyledDropdown> createState() => _StyledDropdownState();
}

class _StyledDropdownState extends State<_StyledDropdown> {
  final MenuController _controller = MenuController();
  bool _isClosing = false;

  void _handleSelect(String value) async {
    setState(() => _isClosing = true);
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) {
      widget.onChanged(value);
      _controller.close();
      setState(() => _isClosing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return MenuAnchor(
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
                offset: Offset(0, 15 * (1 - value)),
                child: Transform.scale(
                  scale: 0.96 + (0.04 * value),
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
              children: widget.items.map((item) {
                return _StyledDropdownItem(
                  label: item,
                  isSelected: widget.value == item,
                  onTap: () => _handleSelect(item),
                  isDark: isDark,
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
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: customInputDecoration(context, widget.label, icon: Icons.category_rounded).copyWith(
              suffixIcon: AnimatedRotation(
                turns: isOpen ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
              ),
            ),
            child: Text(widget.value, style: context.bodyLarge?.bold),
          ),
        );
      },
    );
  }
}

class _StyledDropdownItem extends StatefulWidget {
  const _StyledDropdownItem({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;

  @override
  State<_StyledDropdownItem> createState() => _StyledDropdownItemState();
}

class _StyledDropdownItemState extends State<_StyledDropdownItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 280,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: widget.isSelected 
                    ? AppColors.primaryTeal.withValues(alpha: 0.12) 
                    : _isHovered ? AppColors.primaryTeal.withValues(alpha: 0.05) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Text(
                    widget.label,
                    style: context.labelLarge?.medium.withColor(
                      widget.isSelected || _isHovered 
                          ? AppColors.primaryTeal 
                          : (widget.isDark ? Colors.white : context.onSurfaceColor),
                    ),
                  ),
                  if (widget.isSelected) ...[
                    const Spacer(),
                    const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.primaryTeal),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void _showEditCustomerNotesDialog(BuildContext context, WidgetRef ref, CustomerModel customer) async {
  final notesCtrl = TextEditingController(text: customer.notes);
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
                final updatedCustomer = customer.copyWith(notes: notesCtrl.text.trim());
                await ref.read(customersRepositoryProvider).updateCustomer(updatedCustomer);
                DataRefreshCoordinator.refresh(ref);
                ref.invalidate(customerDetailsProvider(customer.id));
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
