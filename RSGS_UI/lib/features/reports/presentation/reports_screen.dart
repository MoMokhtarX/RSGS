import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../data/reports_repository.dart';
import '../models/report_models.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/typography_extensions.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/localization/date_formatter.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/localization/language_provider.dart';

final reportStartDateProvider = StateProvider<DateTime?>((ref) => null);
final reportEndDateProvider = StateProvider<DateTime?>((ref) => null);

final reportsProvider = FutureProvider<ReportSummary>((ref) async {
  final startDate = ref.watch(reportStartDateProvider);
  final endDate = ref.watch(reportEndDateProvider);
  return ref.watch(reportsRepositoryProvider).getSummary(from: startDate, to: endDate);
});

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(reportsProvider);
    
    return Scaffold(
      backgroundColor: context.theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: const _ReportsFiltersBar(),
            ),
          ),
          reportAsync.when(
            loading: () => const SliverFillRemaining(child: Center(child: LoadingOverlay())),
            error: (error, _) => SliverFillRemaining(
              child: Center(
                child: EmptyStateWidget(
                  icon: Icons.error_outline_rounded,
                  title: 'error',
                  message: '$error',
                  action: () => ref.invalidate(reportsProvider),
                  actionLabel: 'retry',
                ),
              ),
            ),
            data: (data) => SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 16),
                  _SummaryGrid(data: data),
                  const SizedBox(height: 32),
                  _MainChartsGrid(data: data),
                  const SizedBox(height: 32),
                  _MonthlyTrendsSection(data: data),
                  const SizedBox(height: 48),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryGrid extends ConsumerWidget {
  const _SummaryGrid({required this.data});
  final ReportSummary data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(localeProvider).languageCode;
    final items = <({String title, String value, IconData icon, Color color})>[
      (title: 'customers'.tr(ref), value: formatNumber(data.totalCustomers, locale: lang), icon: Icons.people_alt_rounded, color: AppColors.primaryTeal),
      (title: 'projects'.tr(ref), value: formatNumber(data.totalProjects, locale: lang), icon: Icons.folder_copy_rounded, color: AppColors.indigo),
      (title: 'quotations'.tr(ref), value: formatNumber(data.totalQuotations, locale: lang), icon: Icons.request_quote_rounded, color: AppColors.violet),
      (title: 'report_approved_quotes'.tr(ref), value: formatNumber(data.approvedQuotations, locale: lang), icon: Icons.verified_rounded, color: AppColors.success),
      (title: 'report_invoiced'.tr(ref), value: formatCurrency(data.invoicedAmount, locale: lang), icon: Icons.receipt_long_rounded, color: AppColors.orange),
      (title: 'report_collected'.tr(ref), value: formatCurrency(data.collectedAmount, locale: lang), icon: Icons.payments_rounded, color: AppColors.success),
      (title: 'report_outstanding'.tr(ref), value: formatCurrency(data.outstandingAmount, locale: lang), icon: Icons.account_balance_wallet_rounded, color: AppColors.error),
      (title: 'report_cash_margin'.tr(ref), value: formatCurrency(data.grossCashMargin, locale: lang), icon: Icons.trending_up_rounded, color: AppColors.primaryTeal),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1400 ? 4 : constraints.maxWidth >= 800 ? 2 : 1;
        
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
            mainAxisExtent: 130,
          ),
          itemBuilder: (_, index) {
            final item = items[index];
            return ResultTile(
              label: item.title,
              value: item.value,
              icon: item.icon,
              color: item.color,
            );
          },
        );
      },
    );
  }
}

class _MainChartsGrid extends ConsumerWidget {
  const _MainChartsGrid({required this.data});
  final ReportSummary data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 900;
        
        if (isMobile) {
          return Column(
            children: [
              _ChartCard(
                title: 'project_pipeline'.tr(ref),
                subtitle: 'projects_by_status_desc'.tr(ref),
                child: SizedBox(height: 300, child: _StatusPieChart(data.projectsByStatus)),
              ),
              const SizedBox(height: 24),
              _ChartCard(
                title: 'financial_overview'.tr(ref),
                subtitle: 'financial_overview_desc'.tr(ref),
                child: SizedBox(height: 300, child: _FinancialComparisonChart(data)),
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: _ChartCard(
                title: 'financial_overview'.tr(ref),
                subtitle: 'financial_overview_desc'.tr(ref),
                child: SizedBox(height: 350, child: _FinancialComparisonChart(data)),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              flex: 1,
              child: _ChartCard(
                title: 'project_pipeline'.tr(ref),
                subtitle: 'projects_by_status_desc'.tr(ref),
                child: SizedBox(height: 350, child: _StatusPieChart(data.projectsByStatus)),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MonthlyTrendsSection extends ConsumerWidget {
  const _MonthlyTrendsSection({required this.data});
  final ReportSummary data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _ChartCard(
      title: 'monthly_performance'.tr(ref),
      subtitle: 'monthly_performance_desc'.tr(ref),
      child: SizedBox(
        height: 350,
        child: _MonthlyBarChart(
          revenue: data.revenueByMonth,
          collections: data.collectionsByMonth,
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.subtitle, required this.child});
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: context.borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.titleLarge?.extraBold),
                    const SizedBox(height: 4),
                    Text(subtitle, style: context.bodySmall?.medium.withColor(context.appTheme.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          child,
        ],
      ),
    );
  }
}

class _StatusPieChart extends ConsumerWidget {
  const _StatusPieChart(this.items);
  final List<ReportBucket> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) return Center(child: Text('no_data'.tr(ref)));

    final total = items.fold<double>(0, (sum, item) => sum + item.value);

    return PieChart(
      PieChartData(
        sectionsSpace: 4,
        centerSpaceRadius: 60,
        sections: items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final color = AppColors.chartColors[index % AppColors.chartColors.length];
          final percentage = (item.value / total * 100).toStringAsFixed(1);

          return PieChartSectionData(
            color: color,
            value: item.value,
            title: '$percentage%',
            radius: 50,
            titleStyle: context.labelSmall?.bold.white,
            badgeWidget: _PieBadge(item.label.tr(ref), color),
            badgePositionPercentageOffset: 1.3,
          );
        }).toList(),
      ),
    );
  }
}

class _PieBadge extends StatelessWidget {
  const _PieBadge(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
          ),
        ],
      ),
      child: Text(label, style: context.labelSmall?.bold.withColor(color)),
    );
  }
}

class _FinancialComparisonChart extends ConsumerWidget {
  const _FinancialComparisonChart(this.data);
  final ReportSummary data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: [data.invoicedAmount, data.collectedAmount, data.grossCashMargin].fold(0.0, (max, v) => v > max ? v : max) * 1.2,
        barTouchData: BarTouchData(enabled: true),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                switch (value.toInt()) {
                  case 0: return Text('report_invoiced'.tr(ref));
                  case 1: return Text('report_collected'.tr(ref));
                  case 2: return Text('report_cash_margin'.tr(ref));
                  default: return const SizedBox();
                }
              },
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: [
          BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: data.invoicedAmount, color: AppColors.orange, width: 40, borderRadius: BorderRadius.circular(8))]),
          BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: data.collectedAmount, color: AppColors.success, width: 40, borderRadius: BorderRadius.circular(8))]),
          BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: data.grossCashMargin, color: AppColors.primaryTeal, width: 40, borderRadius: BorderRadius.circular(8))]),
        ],
      ),
    );
  }
}

class _MonthlyBarChart extends ConsumerWidget {
  const _MonthlyBarChart({required this.revenue, required this.collections});
  final List<ReportBucket> revenue;
  final List<ReportBucket> collections;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (revenue.isEmpty) return Center(child: Text('no_data'.tr(ref)));
    final lang = ref.watch(localeProvider).languageCode;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.center,
        maxY: revenue.fold<double>(0, (max, item) => item.value > max ? item.value : max) * 1.2,
        groupsSpace: 32,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final label = revenue[groupIndex].label;
              final value = formatCurrency(rod.toY, locale: lang);
              return BarTooltipItem(
                '$label\n$value',
                context.labelMedium?.bold.white ?? const TextStyle(color: Colors.white),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < revenue.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      revenue[value.toInt()].label.substring(0, 3),
                      style: context.labelSmall?.semiBold.withColor(context.appTheme.textMuted),
                    ),
                  );
                }
                return const SizedBox();
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 60,
              getTitlesWidget: (value, meta) => Text(
                '${formatNumber(value / 1000, decimals: 0, locale: lang)}k',
                style: context.labelSmall?.medium.withColor(context.appTheme.textMuted),
              ),
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(color: context.borderColor.withValues(alpha: 0.1), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(revenue.length, (index) {
          final rev = revenue[index].value;
          final coll = index < collections.length ? collections[index].value : 0.0;
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(toY: rev, color: AppColors.orange, width: 12, borderRadius: BorderRadius.circular(4)),
              BarChartRodData(toY: coll, color: AppColors.success, width: 12, borderRadius: BorderRadius.circular(4)),
            ],
          );
        }),
      ),
    );
  }
}

class _ReportsFiltersBar extends ConsumerWidget {
  const _ReportsFiltersBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasFilters = ref.watch(reportStartDateProvider) != null || ref.watch(reportEndDateProvider) != null;

    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('analytics_dashboard'.tr(ref), style: context.headlineSmall?.black),
            const SizedBox(height: 4),
            Text(
              'business_metrics_desc'.tr(ref),
              style: context.bodySmall?.medium.withColor(context.appTheme.textMuted),
            ),
          ],
        ),
        const Spacer(),
        if (hasFilters) ...[
          const _ClearFiltersButton(),
          const SizedBox(width: 12),
        ],
        const _ReportFilterDialogButton(),
      ],
    );
  }
}

class _ReportFilterDialogButton extends ConsumerWidget {
  const _ReportFilterDialogButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasFilters = ref.watch(reportStartDateProvider) != null || ref.watch(reportEndDateProvider) != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => showDialog(context: context, builder: (_) => const _ReportFilterDialog()),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: hasFilters ? AppColors.primaryTeal : context.surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasFilters ? AppColors.primaryTeal : context.borderColor,
              width: 1.5,
            ),
            boxShadow: hasFilters ? [
              BoxShadow(
                color: AppColors.primaryTeal.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              )
            ] : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.tune_rounded,
                size: 20,
                color: hasFilters ? Colors.white : AppColors.primaryTeal,
              ),
              const SizedBox(width: 10),
              Text(
                'filter_range'.tr(ref),
                style: context.labelLarge?.extraBold.withColor(hasFilters ? Colors.white : context.onSurfaceColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportFilterDialog extends ConsumerStatefulWidget {
  const _ReportFilterDialog();
  @override
  ConsumerState<_ReportFilterDialog> createState() => _ReportFilterDialogState();
}

class _ReportFilterDialogState extends ConsumerState<_ReportFilterDialog> {
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _startDate = ref.read(reportStartDateProvider);
    _endDate = ref.read(reportEndDateProvider);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: context.surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 450),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('filter_range'.tr(ref), style: context.headlineSmall?.black),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: context.onSurfaceColor.withValues(alpha: 0.05),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              _labeledField(
                context,
                'start_date'.tr(ref),
                _DatePickerField(
                  label: 'from'.tr(ref),
                  selectedDate: _startDate,
                  onChanged: (d) => setState(() => _startDate = d),
                ),
              ),
              const SizedBox(height: 20),
              _labeledField(
                context,
                'end_date'.tr(ref),
                _DatePickerField(
                  label: 'to'.tr(ref),
                  selectedDate: _endDate,
                  onChanged: (d) => setState(() => _endDate = d),
                ),
              ),
              const SizedBox(height: 40),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() { _startDate = null; _endDate = null; });
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: AppColors.error),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text('clear_all'.tr(ref), style: context.labelLarge?.bold.withColor(AppColors.error)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: () {
                        ref.read(reportStartDateProvider.notifier).state = _startDate;
                        ref.read(reportEndDateProvider.notifier).state = _endDate;
                        Navigator.pop(context);
                      },
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: AppColors.primaryTeal,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text('apply_filter'.tr(ref)),
                    ),
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

class _ClearFiltersButton extends ConsumerWidget {
  const _ClearFiltersButton();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ActionButton(
      icon: Icons.history_rounded,
      color: AppColors.error,
      onPressed: () {
        ref.read(reportStartDateProvider.notifier).state = null;
        ref.read(reportEndDateProvider.notifier).state = null;
      },
      tooltip: 'reset_filters'.tr(ref),
    );
  }
}

Widget _labeledField(BuildContext context, String label, Widget field) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(label, style: context.labelMedium?.bold.withColor(context.appTheme.textMuted)),
      ),
      field,
    ],
  );
}

class _DatePickerField extends ConsumerWidget {
  const _DatePickerField({required this.label, this.selectedDate, required this.onChanged});
  final String label;
  final DateTime? selectedDate;
  final Function(DateTime?) onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: selectedDate ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
          builder: (context, child) => Theme(
            data: Theme.of(context).copyWith(
              colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: AppColors.primaryTeal,
                onPrimary: Colors.white,
              ),
            ),
            child: child!,
          ),
        );
        if (d != null) onChanged(d);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: context.onSurfaceColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.borderColor),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_month_rounded, size: 20, color: context.appTheme.textMuted),
            const SizedBox(width: 12),
            Text(
              selectedDate == null ? 'select_date'.tr(ref) : selectedDate!.format('full_date_format'.tr(ref), ref.watch(localeProvider).languageCode),
              style: context.bodyMedium?.semiBold,
            ),
          ],
        ),
      ),
    );
  }
}
