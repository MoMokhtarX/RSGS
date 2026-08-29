import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/typography_extensions.dart';

class DashboardBarChart extends StatelessWidget {
  const DashboardBarChart({
    super.key,
    required this.data,
    this.height = 250,
  });

  final Map<String, int> data;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const _ChartEmpty();

    final entries = data.entries.toList();
    final maxValue = entries.fold<int>(0, (m, e) => e.value > m ? e.value : m);

    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          maxY: (maxValue == 0 ? 1 : maxValue).toDouble() * 1.2,
          alignment: BarChartAlignment.spaceAround,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxValue <= 5 ? 1 : (maxValue / 4).ceilToDouble(),
            getDrawingHorizontalLine: (_) => FlLine(
              color: context.borderColor.withValues(alpha: 0.5),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (v, _) => Text(
                  v.toInt().toString(),
                  style: context.labelSmall?.withColor(context.onSurfaceVariant),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= entries.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _shorten(entries[i].key),
                      style: context.labelSmall?.semiBold.withColor(context.onSurfaceVariant),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < entries.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: entries[i].value.toDouble(),
                    width: 24,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                    gradient: const LinearGradient(
                      colors: [AppColors.primaryTeal, AppColors.success],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                ],
              ),
          ],
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppColors.darkSurface.withValues(alpha: 0.9),
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  '${entries[groupIndex].key}\n',
                  context.labelSmall?.bold.white ?? const TextStyle(color: Colors.white),
                  children: [
                    TextSpan(
                      text: rod.toY.toInt().toString(),
                      style: context.bodyLarge?.bold.white,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  String _shorten(String value) => value.length > 10 ? '${value.substring(0, 9)}…' : value;
}

class DashboardHorizontalBarChart extends StatelessWidget {
  const DashboardHorizontalBarChart({
    super.key,
    required this.data,
    this.height = 300,
  });

  final Map<String, int> data;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const _ChartEmpty();

    final entries = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final maxValue = entries.fold<int>(0, (m, e) => e.value > m ? e.value : m);

    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          maxY: (maxValue == 0 ? 1 : maxValue).toDouble() * 1.1,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 100,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= entries.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Text(
                      entries[i].key,
                      textAlign: TextAlign.end,
                      style: context.labelSmall?.semiBold.withColor(context.onSurfaceVariant),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < entries.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: entries[i].value.toDouble(),
                    width: 16,
                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
                    color: AppColors.primaryTeal.withValues(alpha: 0.8),
                    backDrawRodData: BackgroundBarChartRodData(
                      show: true,
                      toY: maxValue.toDouble(),
                      color: context.borderColor.withValues(alpha: 0.3),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class DashboardMiniBarChart extends StatelessWidget {
  const DashboardMiniBarChart({
    super.key,
    required this.data,
    this.height = 200,
  });

  final Map<String, int> data;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const _ChartEmpty();

    final entries = data.entries.toList();
    final maxValue = entries.fold<int>(0, (m, e) => e.value > m ? e.value : m);

    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          maxY: (maxValue == 0 ? 1 : maxValue).toDouble() * 1.2,
          minY: 0,
          alignment: BarChartAlignment.spaceAround,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxValue <= 5 ? 1 : (maxValue / 4).ceilToDouble(),
            getDrawingHorizontalLine: (_) => FlLine(
              color: context.borderColor,
              strokeWidth: 1,
              dashArray: [5, 5],
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (v, _) => Text(
                  v.toInt().toString(),
                  style: context.labelSmall?.withColor(context.onSurfaceVariant),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= entries.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _shorten(entries[i].key),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.labelSmall?.semiBold.withColor(context.onSurfaceVariant),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < entries.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: entries[i].value.toDouble(),
                    width: 18,
                    borderRadius: BorderRadius.circular(4),
                    color: AppColors.primaryTeal,
                  ),
                ],
              ),
          ],
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppColors.darkSurface,
              tooltipRoundedRadius: 8,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  '${entries[groupIndex].key}: ${rod.toY.toInt()}',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  String _shorten(String value) => value.length > 8 ? '${value.substring(0, 7)}…' : value;
}

class DashboardDonutChart extends StatelessWidget {
  const DashboardDonutChart({super.key, required this.data});

  final Map<String, int> data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const _ChartEmpty();

    final entries = data.entries.toList();
    final total = entries.fold<int>(0, (s, e) => s + e.value);
    final colors = [
      AppColors.primaryTeal,
      AppColors.violet,
      AppColors.success,
      AppColors.warning,
      AppColors.error,
      AppColors.indigo,
    ];

    return Row(
      children: [
        SizedBox(
          width: 150,
          height: 150,
          child: PieChart(
            PieChartData(
              centerSpaceRadius: 45,
              sectionsSpace: 3,
              sections: [
                for (var i = 0; i < entries.length; i++)
                  PieChartSectionData(
                    value: entries[i].value.toDouble(),
                    color: colors[i % colors.length],
                    radius: 18,
                    showTitle: false,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ...entries.asMap().entries.map((entry) {
                final i = entry.key;
                final item = entry.value;
                final percentage = (item.value / total * 100).toStringAsFixed(0);
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: colors[i % colors.length],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item.key,
                          overflow: TextOverflow.ellipsis,
                          style: context.labelSmall?.semiBold,
                        ),
                      ),
                      Text(
                        '$percentage%',
                        style: context.labelSmall?.withColor(context.onSurfaceVariant),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChartEmpty extends StatelessWidget {
  const _ChartEmpty();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'No data available',
            style: context.labelSmall?.withColor(context.onSurfaceVariant),
          ),
        ),
      );
}
