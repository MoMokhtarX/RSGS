import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:responsive_framework/responsive_framework.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/typography_extensions.dart';
import '../../../core/permissions/user_role.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/services/data_refresh_service.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/localization/language_provider.dart';
import '../../../core/localization/date_formatter.dart';
import '../../auth/data/auth_repository.dart';
import '../../customers/data/customers_repository.dart';
import '../../projects/data/projects_repository.dart';
import '../data/quotations_repository.dart';
import '../models/quotation_models.dart';
import '../providers/quotations_provider.dart';
import '../widgets/quotation_status_actions.dart';

class QuotationDetailsScreen extends ConsumerStatefulWidget {
  const QuotationDetailsScreen({
    super.key,
    required this.quotationId,
  });

  final int quotationId;

  @override
  ConsumerState<QuotationDetailsScreen> createState() =>
      _QuotationDetailsScreenState();
}

class _QuotationDetailsScreenState extends ConsumerState<QuotationDetailsScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _changingStatus = false;
  bool _downloadingPdf = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final quotationAsync = ref.watch(quotationProvider(widget.quotationId));
    final role = ref.watch(currentUserProvider)?.role;
    final canManage = role == UserRole.admin || role == UserRole.manager || role == UserRole.sales;

    return Scaffold(
      backgroundColor: context.appTheme.surfaceSubtle,
      body: quotationAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('${'error'.tr(ref)}: $err')),
        data: (quotation) {
          if (quotation == null) return Center(child: Text('quotation_not_found'.tr(ref)));

          return CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              _ParallaxAppBar(
                quotation: quotation, 
                downloadingPdf: _downloadingPdf, 
                canManage: canManage, 
                onPrint: () => _printPdf(quotation), 
                onOpen: () => _openPdf(quotation),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: Column(
                    children: [
                      _QuickActionToolbar(
                        quotation: quotation, 
                        changingStatus: _changingStatus, 
                        onStatusChanged: (status) => _changeStatus(quotation, status), 
                        canManage: canManage,
                        onPrint: () => _printPdf(quotation),
                        onOpen: () => _openPdf(quotation),
                      ),
                      const SizedBox(height: 32),
                      _MetricGrid(quotation: quotation),
                      const SizedBox(height: 32),
                      _DashboardContent(quotation: quotation),
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

  // Helper methods moved here to stay in state scope
  Future<void> _changeStatus(QuotationModel quotation, QuotationStatus status) async {
    try {
      setState(() => _changingStatus = true);
      await ref.read(quotationsRepositoryProvider).changeStatus(quotation.id, status);
      DataRefreshCoordinator.refresh(ref);
      ref.invalidate(quotationProvider(quotation.id));
      ref.invalidate(quotationsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Quotation status changed to ${status.label}')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _changingStatus = false);
    }
  }

  Future<File> _ensurePdfFile(QuotationModel quotation) async {
    final repository = ref.read(quotationsRepositoryProvider);
    final bytes = await repository.downloadQuotationPdf(quotation.id);
    final directory = await getApplicationDocumentsDirectory();
    final quotationsDirectory = Directory(path.join(directory.path, 'Quotations'));
    if (!await quotationsDirectory.exists()) await quotationsDirectory.create(recursive: true);
    final file = File(path.join(quotationsDirectory.path, 'Quotation-${quotation.id}.pdf'));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<void> _openPdf(QuotationModel quotation) async {
    try {
      setState(() => _downloadingPdf = true);
      final file = await _ensurePdfFile(quotation);
      final opened = await launchUrl(Uri.file(file.path), mode: LaunchMode.externalApplication);
      if (!mounted) return;
      if (!opened) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF saved to:\n${file.path}')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to open PDF: $e'), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _downloadingPdf = false);
    }
  }

  Future<void> _printPdf(QuotationModel quotation) async {
    try {
      setState(() => _downloadingPdf = true);
      final file = await _ensurePdfFile(quotation);
      if (!Platform.isWindows) {
        final opened = await launchUrl(Uri.file(file.path), mode: LaunchMode.externalApplication);
        if (!opened) throw Exception('No PDF application is available.');
      } else {
        final result = await Process.run(
          'powershell', 
          ['-Command', 'Start-Process -FilePath "${file.path}" -Verb Print'], 
          runInShell: true,
        );
        if (result.exitCode != 0) {
          throw Exception(result.stderr.toString().trim().isEmpty 
              ? 'Windows could not send PDF to printer.' 
              : result.stderr.toString());
        }
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Print command sent successfully.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to print PDF: $e'), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _downloadingPdf = false);
    }
  }
}

class _ParallaxAppBar extends ConsumerWidget {
  final QuotationModel quotation;
  final bool downloadingPdf;
  final bool canManage;
  final VoidCallback onPrint;
  final VoidCallback onOpen;

  const _ParallaxAppBar({
    required this.quotation,
    required this.downloadingPdf,
    required this.canManage,
    required this.onPrint,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SliverAppBar(
      expandedHeight: 500,
      pinned: false,
      stretch: true,
      clipBehavior: Clip.none,
      backgroundColor: context.primaryColor,
      leading: IconButton(
        onPressed: () => context.pop(),
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
      ),
      title: Text(
        'quotation_details'.tr(ref),
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
                  padding: const EdgeInsets.only(top: 40, bottom: 20, left: 20, right: 20),
                  child: _QuotationGlassCard(quotation: quotation, canManage: canManage),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuotationGlassCard extends ConsumerWidget {
  final QuotationModel quotation;
  final bool canManage;
  const _QuotationGlassCard({required this.quotation, required this.canManage});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final customerAsync = ref.watch(customerProvider(quotation.customerId));

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
              if (canManage)
                Positioned(
                  top: 12,
                  right: 12,
                  child: IconButton(
                    onPressed: () => context.push('/quotations/${quotation.id}/edit'),
                    icon: Icon(Icons.edit_rounded, color: isDark ? Colors.white70 : context.onSurfaceVariant),
                    style: IconButton.styleFrom(
                      backgroundColor: context.onSurfaceColor.withValues(alpha: 0.05),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 20 : 32, vertical: isMobile ? 20 : 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: isMobile ? 60 : 80,
                        height: isMobile ? 60 : 80,
                        decoration: BoxDecoration(
                          color: AppColors.primaryTeal.withValues(alpha: 0.1), 
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.primaryTeal.withValues(alpha: 0.2), width: 4),
                        ),
                        child: Icon(Icons.request_quote_rounded, color: AppColors.primaryTeal, size: isMobile ? 30 : 40),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        quotation.quotationNumber,
                        textAlign: TextAlign.center,
                        style: (isMobile ? context.headlineSmall : context.displaySmall)?.extraBold.withHeight(1.1),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _QuotationStatusBadge(status: quotation.status),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.primaryTeal.withValues(alpha: 0.12), 
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.primaryTeal.withValues(alpha: 0.1), width: 1),
                            ),
                            child: Text(quotation.type.label, style: context.labelSmall?.bold.primary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      customerAsync.when(
                        data: (customer) => InkWell(
                          onTap: customer != null ? () => context.go('/customers/${customer.id}') : null,
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.person_outline_rounded, size: 18, color: context.onSurfaceVariant),
                                const SizedBox(width: 8),
                                Text(customer?.name ?? 'unnamed_customer'.tr(ref), style: context.titleMedium?.bold.primary),
                              ],
                            ),
                          ),
                        ),
                        loading: () => const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                        error: (err, stack) => const SizedBox.shrink(),
                      ),
                      if (quotation.projectId != null) ...[
                        const SizedBox(height: 2),
                        Consumer(
                          builder: (context, ref, child) {
                            final projectAsync = ref.watch(projectProvider(quotation.projectId!));
                            return projectAsync.when(
                              data: (details) => InkWell(
                                onTap: () => context.go('/projects/${quotation.projectId}'),
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.solar_power_rounded, size: 16, color: context.onSurfaceVariant),
                                      const SizedBox(width: 8),
                                      Text(details?.project.name ?? 'Project #${quotation.projectId}', style: context.titleSmall?.bold.primary),
                                    ],
                                  ),
                                ),
                              ),
                              loading: () => const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                              error: (err, stack) => const SizedBox.shrink(),
                            );
                          },
                        ),
                      ],
                      if (quotation.quotationDate != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: context.onSurfaceColor.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.calendar_today_rounded, size: 12, color: context.onSurfaceVariant),
                              const SizedBox(width: 6),
                              Text(
                                quotation.quotationDate!.format('full_date_format'.tr(ref), ref.watch(localeProvider).languageCode),
                                style: context.labelMedium?.medium.withColor(context.onSurfaceVariant).copyWith(
                                  letterSpacing: ref.watch(localeProvider).languageCode == 'ar' ? 1.1 : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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

class _QuickActionToolbar extends ConsumerWidget {
  final QuotationModel quotation;
  final bool changingStatus;
  final Function(QuotationStatus) onStatusChanged;
  final bool canManage;
  final VoidCallback onPrint;
  final VoidCallback onOpen;

  const _QuickActionToolbar({
    required this.quotation, 
    required this.changingStatus, 
    required this.onStatusChanged, 
    required this.canManage,
    required this.onPrint,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: context.surfaceColor, 
        borderRadius: BorderRadius.circular(20), 
        border: Border.all(color: context.borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: QuickActionButton(
                icon: Icons.picture_as_pdf_rounded,
                label: 'open_pdf'.tr(ref).toUpperCase(),
                onPressed: onOpen,
                color: AppColors.error,
              ),
            ),
            // VerticalDivider(width: 1, color: context.borderColor, indent: 8, endIndent: 8),
            // Expanded(
            //   child: QuickActionButton(
            //     icon: Icons.print_rounded,
            //     label: 'print'.tr(ref).toUpperCase(),
            //     onPressed: onPrint,
            //     color: AppColors.info,
            //   ),
            // ),
            if (canManage && quotation.status != QuotationStatus.approved && quotation.status != QuotationStatus.rejected && quotation.status != QuotationStatus.expired) ...[
              VerticalDivider(width: 1, color: context.borderColor, indent: 8, endIndent: 8),
              Expanded(
                flex: quotation.status == QuotationStatus.sent ? 2 : 1,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: QuotationStatusActions(
                    status: quotation.status,
                    loading: changingStatus,
                    onStatusChanged: onStatusChanged,
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

// REMOVED _ToolbarButton as it was replaced by QuickActionButton


class _MetricGrid extends ConsumerWidget {
  final QuotationModel quotation;
  const _MetricGrid({required this.quotation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: 20,
      runSpacing: 20,
      alignment: WrapAlignment.center,
      children: [
        _MetricCard(
          label: 'total_price'.tr(ref),
          value: formatCurrency(quotation.totalPrice),
          icon: Icons.payments_outlined,
          color: AppColors.success,
          glowColor: AppColors.successGlow,
        ),
        _MetricCard(
          label: 'capacity'.tr(ref),
          value: quotation.systemCapacity != null ? '${quotation.systemCapacity} ${quotation.capacityUnit}' : '-',
          icon: Icons.bolt_rounded,
          color: AppColors.accentGold,
          glowColor: AppColors.accentGold.withValues(alpha: 0.2),
        ),
        _MetricCard(
          label: 'order_items'.tr(ref),
          value: quotation.items.length.toString(),
          icon: Icons.inventory_2_outlined,
          color: AppColors.primaryTeal,
          glowColor: AppColors.primaryGlow,
        ),
      ],
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
  final QuotationModel quotation;
  const _DashboardContent({required this.quotation});

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveBreakpoints.of(context).largerThan(MOBILE);

    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: _SidebarInfo(quotation: quotation)),
          const SizedBox(width: 32),
          Expanded(flex: 5, child: _MainContent(quotation: quotation)),
        ],
      );
    }

    return Column(
      children: [
        _SidebarInfo(quotation: quotation),
        const SizedBox(height: 32),
        _MainContent(quotation: quotation),
      ],
    );
  }
}

class _SidebarInfo extends StatelessWidget {
  final QuotationModel quotation;
  const _SidebarInfo({required this.quotation});

  @override
  Widget build(BuildContext context) {
    final hasIntroduction = quotation.introduction != null && quotation.introduction!.trim().isNotEmpty;

    return Column(
      children: [
        if (hasIntroduction) ...[
          _IntroductionCard(introduction: quotation.introduction!),
          const SizedBox(height: 32),
        ],
        _PricingSummaryCard(quotation: quotation),
        const SizedBox(height: 32),
        _TermsCard(quotation: quotation),
        if (quotation.notes != null && quotation.notes!.trim().isNotEmpty) ...[
          const SizedBox(height: 32),
          _GeneralNotesCard(notes: quotation.notes!),
        ],
      ],
    );
  }
}

class _IntroductionCard extends ConsumerWidget {
  final String introduction;
  const _IntroductionCard({required this.introduction});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'introduction'.tr(ref).toUpperCase(),
            style: context.labelSmall?.extraBold.primary.withLetterSpacing(1.1),
          ),
          const SizedBox(height: 16),
          Text(introduction, style: context.bodyMedium),
        ],
      ),
    );
  }
}

class _GeneralNotesCard extends ConsumerWidget {
  final String notes;
  const _GeneralNotesCard({required this.notes});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: double.infinity,
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
              Icon(Icons.notes_rounded, color: context.primaryColor, size: 20),
              const SizedBox(width: 12),
              Text(
                'notes'.tr(ref).toUpperCase(),
                style: context.labelSmall?.extraBold.withColor(context.onSurfaceVariant).withLetterSpacing(1.1),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(notes, style: context.bodyMedium),
        ],
      ),
    );
  }
}

class _MainContent extends StatelessWidget {
  final QuotationModel quotation;
  const _MainContent({required this.quotation});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ItemsSection(items: quotation.items),
        if (quotation.systemDescription != null && quotation.systemDescription!.isNotEmpty) ...[
          const SizedBox(height: 32),
          _DescriptionCard(description: quotation.systemDescription!),
        ],
      ],
    );
  }
}

class _ItemsSection extends ConsumerWidget {
  final List<QuotationItemModel> items;
  const _ItemsSection({required this.items});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.surfaceColor, 
        borderRadius: BorderRadius.circular(24), 
        border: Border.all(color: context.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('bill_of_materials'.tr(ref).toUpperCase(), style: context.labelSmall?.extraBold.withColor(context.onSurfaceVariant).withLetterSpacing(1.1)),
          const SizedBox(height: 20),
          if (items.isEmpty)
            Center(child: Text('no_data'.tr(ref), style: context.bodyMedium?.withColor(context.onSurfaceVariant)))
          else
            Column(
              children: items.map((item) => _ItemRow(item: item)).toList(),
            ),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final QuotationItemModel item;
  const _ItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: context.appTheme.surfaceSubtle, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.borderColor)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.item, style: context.titleSmall?.bold),
                    const SizedBox(height: 4),
                    Text(item.description, style: context.bodySmall?.withColor(context.onSurfaceVariant)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${item.quantity ?? '-'} ${item.unit ?? ''}', style: context.bodyLarge?.bold),
                  Text(item.category.label, style: context.labelSmall?.primary.bold),
                ],
              ),
            ],
          ),
          if (item.internalNotes != null && item.internalNotes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: context.surfaceColor, borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  Icon(Icons.note_rounded, size: 14, color: context.primaryColor.withValues(alpha: 0.5)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(item.internalNotes!, style: context.labelSmall?.italic)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PricingSummaryCard extends ConsumerWidget {
  final QuotationModel quotation;
  const _PricingSummaryCard({required this.quotation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.surfaceColor, 
        borderRadius: BorderRadius.circular(24), 
        border: Border.all(color: context.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('pricing_logic'.tr(ref).toUpperCase(), style: context.labelSmall?.extraBold.primary.withLetterSpacing(1.1)),
          const SizedBox(height: 20),
          _PriceRow(label: 'additional_materials'.tr(ref), value: quotation.materialsCost),
          _PriceRow(label: 'transportation'.tr(ref), value: quotation.transportationCost),
          _PriceRow(label: 'installation'.tr(ref), value: quotation.installationCost),
          _PriceRow(label: 'other_cost'.tr(ref), value: quotation.otherCost),
          _PriceRow(label: 'profit_margin'.tr(ref), value: quotation.profitMargin, isPercentage: true),
          _PriceRow(label: 'discount'.tr(ref), value: -quotation.discount, isNegative: true),
          _PriceRow(label: 'tax'.tr(ref), value: quotation.tax, isPercentage: true),
          const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider()),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('total'.tr(ref).toUpperCase(), style: context.titleSmall?.extraBold.primary),
              Text(formatCurrency(quotation.totalPrice), style: context.titleLarge?.extraBold.primary),
            ],
          ),
        ],
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label; final double value; final bool isNegative; final bool isPercentage;
  const _PriceRow({required this.label, required this.value, this.isNegative = false, this.isPercentage = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: context.bodyMedium?.medium.withColor(AppColors.textSecondary)),
          Text(
            isPercentage ? '${value.toStringAsFixed(1)} %' : formatCurrency(value),
            style: context.bodyMedium?.bold.withColor(isNegative ? AppColors.error : context.onSurfaceColor),
          ),
        ],
      ),
    );
  }
}

class _DescriptionCard extends ConsumerWidget {
  final String description;
  const _DescriptionCard({required this.description});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.surfaceColor, 
        borderRadius: BorderRadius.circular(24), 
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('system_description'.tr(ref).toUpperCase(), style: context.labelSmall?.extraBold.withColor(context.onSurfaceVariant).withLetterSpacing(1.1)),
          const SizedBox(height: 16),
          Text(description, style: context.bodyLarge?.medium.withHeight(1.6)),
        ],
      ),
    );
  }
}

class _TermsCard extends ConsumerWidget {
  final QuotationModel quotation;
  const _TermsCard({required this.quotation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPaymentTerms = quotation.paymentTerms != null && quotation.paymentTerms!.trim().isNotEmpty;
    final hasGeneralTerms = quotation.generalTerms != null && quotation.generalTerms!.trim().isNotEmpty;

    if (!hasPaymentTerms && !hasGeneralTerms) return const SizedBox.shrink();

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
              const Icon(Icons.description_rounded, color: AppColors.pinGold, size: 24),
              const SizedBox(width: 12),
              Text('terms_and_conditions'.tr(ref).toUpperCase(), style: context.titleMedium?.extraBold.withColor(AppColors.pinGold)),
            ],
          ),
          const SizedBox(height: 16),
          if (hasPaymentTerms) ...[
            Text('payment_terms'.tr(ref).toUpperCase(), style: context.labelSmall?.extraBold.withColor(AppColors.pinGold).withLetterSpacing(1.1)),
            const SizedBox(height: 4),
            Text(quotation.paymentTerms!, style: context.bodyMedium),
            if (hasGeneralTerms) const SizedBox(height: 16),
          ],
          if (hasGeneralTerms) ...[
            Text('general_terms'.tr(ref).toUpperCase(), style: context.labelSmall?.extraBold.withColor(AppColors.pinGold).withLetterSpacing(1.1)),
            const SizedBox(height: 4),
            Text(quotation.generalTerms!, style: context.bodyMedium),
          ],
        ],
      ),
    );
  }
}

class _QuotationStatusBadge extends ConsumerWidget {
  const _QuotationStatusBadge({required this.status});
  final QuotationStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Color color = AppColors.textSecondary;
    switch (status) {
      case QuotationStatus.draft: color = Colors.grey; break;
      case QuotationStatus.sent: color = AppColors.info; break;
      case QuotationStatus.approved: color = AppColors.success; break;
      case QuotationStatus.rejected: color = AppColors.error; break;
      case QuotationStatus.expired: color = Colors.orange; break;
    }

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
          Text(status.label, style: context.labelSmall?.withColor(color).withSize(10)),
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
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
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
          width: 6, height: 6,
          decoration: BoxDecoration(color: widget.color.withValues(alpha: 0.6 + (0.4 * _controller.value)), shape: BoxShape.circle),
        );
      },
    );
  }
}
