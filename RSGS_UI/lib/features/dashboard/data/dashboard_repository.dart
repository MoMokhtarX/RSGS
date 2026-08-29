import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/data_refresh_service.dart';

import '../../../core/network/api_client.dart';

class DashboardChartData {
  const DashboardChartData({required this.label, required this.value});

  final String label;
  final int value;

  factory DashboardChartData.fromJson(Map<String, dynamic> json) {
    return DashboardChartData(
      label: json['label']?.toString() ?? '',
      value: (json['value'] as num?)?.toInt() ?? 0,
    );
  }
}

class DashboardRecentCustomer {
  const DashboardRecentCustomer({
    required this.id,
    required this.name,
    this.phone,
    this.createdAt,
  });

  final int id;
  final String name;
  final String? phone;
  final DateTime? createdAt;

  factory DashboardRecentCustomer.fromJson(Map<String, dynamic> json) {
    return DashboardRecentCustomer(
      id: _toInt(json['id']),
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString(),
      createdAt: _date(json['createdAt'] ?? json['created_at']),
    );
  }
}

class DashboardRecentProject {
  const DashboardRecentProject({
    required this.id,
    required this.projectNumber,
    required this.name,
    required this.projectStatus,
    required this.totalValue,
    this.createdDate,
    this.customerName,
  });

  final int id;
  final String projectNumber;
  final String name;
  final String projectStatus;
  final double totalValue;
  final DateTime? createdDate;
  final String? customerName;

  factory DashboardRecentProject.fromJson(Map<String, dynamic> json) {
    return DashboardRecentProject(
      id: _toInt(json['id']),
      projectNumber: json['projectNumber']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      projectStatus: _projectStatusText(json['projectStatus'] ?? json['status']),
      totalValue: _toDouble(json['totalValue']),
      createdDate: _date(json['createdDate'] ?? json['created_date']),
      customerName: json['customerName']?.toString(),
    );
  }
}

class DashboardData {
  const DashboardData({
    required this.totalCustomers,
    required this.totalProjects,
    required this.totalUsers,
    required this.activeProjects,
    required this.draftProjects,
    required this.finishedProjects,
    required this.totalProjectsValue,
    required this.totalKw,
    required this.recentCustomers,
    required this.recentProjects,
    required this.projectsByStatus,
    required this.projectsByEngineer,
    required this.customersByGovernorate,
  });

  final int totalCustomers;
  final int totalProjects;
  final int totalUsers;
  final int activeProjects;
  final int draftProjects;
  final int finishedProjects;
  final double totalProjectsValue;
  final double totalKw;
  final List<DashboardRecentCustomer> recentCustomers;
  final List<DashboardRecentProject> recentProjects;
  final List<DashboardChartData> projectsByStatus;
  final List<DashboardChartData> projectsByEngineer;
  final List<DashboardChartData> customersByGovernorate;

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    List<T> list<T>(
      dynamic value,
      T Function(Map<String, dynamic>) mapper,
    ) {
      if (value is! List) return <T>[];
      return value
          .whereType<Map>()
          .map((e) => mapper(Map<String, dynamic>.from(e)))
          .toList();
    }

    return DashboardData(
      totalCustomers: _toInt(json['totalCustomers']),
      totalProjects: _toInt(json['totalProjects']),
      totalUsers: _toInt(json['totalUsers']),
      activeProjects: _toInt(json['activeProjects']),
      draftProjects: _toInt(json['draftProjects']),
      finishedProjects: _toInt(json['finishedProjects']),
      totalProjectsValue: _toDouble(json['totalProjectsValue']),
      totalKw: _toDouble(json['totalKW'] ?? json['totalKw']),
      recentCustomers: list(
        json['recentCustomers'],
        DashboardRecentCustomer.fromJson,
      ),
      recentProjects: list(
        json['recentProjects'],
        DashboardRecentProject.fromJson,
      ),
      projectsByStatus: list(
        json['projectsByStatus'],
        DashboardChartData.fromJson,
      ),
      projectsByEngineer: list(
        json['projectsByEngineer'],
        DashboardChartData.fromJson,
      ),
      customersByGovernorate: list(
        json['customersByGovernorate'],
        DashboardChartData.fromJson,
      ),
    );
  }
}

class DashboardRepository {
  DashboardRepository(this._api);

  final ApiClient _api;

  Future<DashboardData> getDashboard() async {
    final response = await _api.get('/api/Dashboard');

    dynamic current = response;
    for (var i = 0; i < 3; i++) {
      if (current is Map<String, dynamic>) {
        if (current.containsKey('totalCustomers')) {
          return DashboardData.fromJson(current);
        }
        final nested = current['data'];
        if (nested is Map) {
          current = Map<String, dynamic>.from(nested);
          continue;
        }
      }
      break;
    }

    if (current is Map) {
      return DashboardData.fromJson(Map<String, dynamic>.from(current));
    }

    throw const FormatException('Invalid dashboard response.');
  }
}

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(ref.watch(apiClientProvider));
});

final dashboardProvider = FutureProvider<DashboardData>((ref) {
  ref.watch(dataRefreshVersionProvider);
  return ref.watch(dashboardRepositoryProvider).getDashboard();
});

int _toInt(dynamic value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;
double _toDouble(dynamic value) => value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

DateTime? _date(dynamic value) =>
    value == null ? null : DateTime.tryParse(value.toString());

String _projectStatusText(dynamic value) {
  if (value is num) {
    switch (value.toInt()) {
      case 1: return 'Draft';
      case 2: return 'Pending';
      case 3: return 'Approved';
      case 4: return 'In Progress';
      case 5: return 'Completed';
      case 6: return 'Cancelled';
    }
  }
  return value?.toString() ?? '';
}
