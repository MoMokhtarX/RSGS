class ReportBucket {
  const ReportBucket({required this.label, required this.value});

  final String label;
  final double value;

  factory ReportBucket.fromJson(Map<String, dynamic> json) => ReportBucket(
        label: json['label']?.toString() ?? '',
        value: _toDouble(json['value']),
      );
}

class ReportSummary {
  const ReportSummary({
    required this.from,
    required this.to,
    required this.totalCustomers,
    required this.totalProjects,
    required this.activeProjects,
    required this.completedProjects,
    required this.totalQuotations,
    required this.approvedQuotations,
    required this.quotationValue,
    required this.invoicedAmount,
    required this.collectedAmount,
    required this.outstandingAmount,
    required this.purchaseOrderSpend,
    required this.grossCashMargin,
    required this.projectsByStatus,
    required this.revenueByMonth,
    required this.collectionsByMonth,
  });

  final DateTime from;
  final DateTime to;
  final int totalCustomers;
  final int totalProjects;
  final int activeProjects;
  final int completedProjects;
  final int totalQuotations;
  final int approvedQuotations;
  final double quotationValue;
  final double invoicedAmount;
  final double collectedAmount;
  final double outstandingAmount;
  final double purchaseOrderSpend;
  final double grossCashMargin;
  final List<ReportBucket> projectsByStatus;
  final List<ReportBucket> revenueByMonth;
  final List<ReportBucket> collectionsByMonth;

  factory ReportSummary.fromJson(Map<String, dynamic> json) {
    List<ReportBucket> buckets(dynamic value) {
      if (value is! List) return const [];
      return value
          .whereType<Map>()
          .map((e) => ReportBucket.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    return ReportSummary(
      from: DateTime.tryParse(json['from']?.toString() ?? '') ?? DateTime.now(),
      to: DateTime.tryParse(json['to']?.toString() ?? '') ?? DateTime.now(),
      totalCustomers: _toInt(json['totalCustomers']),
      totalProjects: _toInt(json['totalProjects']),
      activeProjects: _toInt(json['activeProjects']),
      completedProjects: _toInt(json['completedProjects']),
      totalQuotations: _toInt(json['totalQuotations']),
      approvedQuotations: _toInt(json['approvedQuotations']),
      quotationValue: _toDouble(json['quotationValue']),
      invoicedAmount: _toDouble(json['invoicedAmount']),
      collectedAmount: _toDouble(json['collectedAmount']),
      outstandingAmount: _toDouble(json['outstandingAmount']),
      purchaseOrderSpend: _toDouble(json['purchaseOrderSpend']),
      grossCashMargin: _toDouble(json['grossCashMargin']),
      projectsByStatus: buckets(json['projectsByStatus']),
      revenueByMonth: buckets(json['revenueByMonth']),
      collectionsByMonth: buckets(json['collectionsByMonth']),
    );
  }
}

int _toInt(dynamic value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;
double _toDouble(dynamic value) => value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
