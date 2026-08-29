import '../../../core/services/data_refresh_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/models/app_models.dart';
import '../../../core/permissions/user_role.dart';
import '../../auth/data/auth_repository.dart';

class ProjectWithDetails {
  ProjectWithDetails({
    required this.project,
    this.customerName,
    this.customerChannel,
    this.engineerName,
  });

  final ProjectModel project;
  final String? customerName;
  final String? customerChannel;
  final String? engineerName;

  factory ProjectWithDetails.fromJson(Map<String, dynamic> json) {
    final customer = json['customer'];
    final engineer = json['engineer'];
    return ProjectWithDetails(
      project: ProjectModel.fromMap(json),
      customerName: json['customerName'] as String? ??
          (customer is Map ? customer['name'] as String? : null),
      customerChannel: json['customerChannel'] as String? ??
          (customer is Map ? customer['channel'] as String? : null),
      engineerName: json['engineerName'] as String? ??
          (engineer is Map ? (engineer['fullName'] ?? engineer['username']) as String? : null),
    );
  }
}

class ProjectPage { final List<ProjectModel> items; final int totalPages; final int totalRecords; const ProjectPage({required this.items,required this.totalPages,required this.totalRecords}); }
int? _meta(dynamic response)=>response is Map&&response['totalPages'] is num?(response['totalPages'] as num).toInt():null;
int _total(dynamic response)=>response is Map&&response['totalRecords'] is num?(response['totalRecords'] as num).toInt():0;

class ProjectsRepository {
  ProjectsRepository(this._api);
  final ApiClient _api;

  List<Map<String, dynamic>> _list(dynamic response) {
    if (response is List) {
      return response
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    if (response is Map) {
      final map = Map<String, dynamic>.from(response);
      final items = map['items'];
      if (items is List) {
        return items
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    }

    return const [];
  }

  Map<String, dynamic>? _object(dynamic response) {
    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }
    return null;
  }

  Future<List<ProjectModel>> getProjects([int? engineerId]) async {
    final all=<ProjectModel>[]; var page=1;
    while(true){
      final response=await _api.get('/api/Projects/paged',queryParameters:{'pageNumber':'$page','pageSize':'100','engineerId': engineerId?.toString()});
      final items=_list(response).map(ProjectModel.fromMap).toList(); all.addAll(items);
      final totalPages=_meta(response); if(totalPages==null||page>=totalPages||items.isEmpty)break; page++;
    }
    return all;
  }

  Future<ProjectPage> getPage({int pageNumber=1,int pageSize=20,String? search,String? status,int? engineerId}) async {
    final response=await _api.get('/api/Projects/paged',queryParameters:{'pageNumber':'$pageNumber','pageSize':'$pageSize','search': search?.trim(),'status': status,'engineerId': engineerId?.toString()});
    return ProjectPage(items:_list(response).map(ProjectModel.fromMap).toList(),totalPages:_meta(response)??1,totalRecords:_total(response));
  }

  Future<List<ProjectWithDetails>> getProjectsWithDetails([int? engineerId]) async {
    final response=await _api.get('/api/Projects');
    return _list(response).map(ProjectWithDetails.fromJson).toList();
  }

  Future<List<ProjectModel>> searchProjects(String query,[int? engineerId]) async {
    final response=await _api.get('/api/Projects/paged',queryParameters:{'pageNumber':'1','pageSize':'100','search':query,'engineerId': engineerId?.toString()});
    return _list(response).map(ProjectModel.fromMap).toList();
  }

  Future<ProjectWithDetails?> getProject(int id) async {
    final response = await _api.get('/api/Projects/$id');
    final map = _object(response);
    return map == null ? null : ProjectWithDetails.fromJson(map);
  }

  Future<int> createProject(ProjectModel project) async {
    final response = await _api.post('/api/Projects', data: project.toApiCreateJson());
    final data = _object(response);
    final id = (data?['id'] as num?)?.toInt();
    if (id == null) {
      throw const FormatException(
        'Project was created, but the API did not return the project id.',
      );
    }
    return id;
  }

  Future<void> updateProject(ProjectModel project) async {
    await _api.put('/api/Projects/${project.id}', data: project.toApiUpdateJson());
  }

  Future<void> deleteProject(int id) async {
    await _api.delete('/api/Projects/$id');
  }

  Future<int> deleteAllProjects() async {
    final response = await _api.delete('/api/Projects/all');
    final data = _object(response);
    return (data?['count'] as num?)?.toInt() ?? 0;
  }

  Future<void> assignEngineer(int projectId, int engineerId) async {
    await _api.put('/api/Projects/$projectId/assign-engineer/$engineerId');
  }

  Future<void> changeStatus(int projectId, String status) async {
    await _api.put('/api/Projects/$projectId/status', data: _statusToApi(status));
  }

  Future<String> newProjectNumber() async {
    final response = await _api.get('/api/Projects/next-number');
    final data = _object(response);
    final number = data?['number']?.toString();
    if (number != null && number.isNotEmpty) return number;
    throw const FormatException(
      'Invalid next project number response.',
    );
  }

  int _statusToApi(String status) {
    switch (status.trim().toLowerCase()) {
      case 'pending': return 2;
      case 'approved': return 3;
      case 'in progress':
      case 'inprogress': return 4;
      case 'completed': return 5;
      case 'cancelled':
      case 'canceled': return 6;
      default: return 1;
    }
  }
}

final projectsRepositoryProvider = Provider<ProjectsRepository>((ref) {
  return ProjectsRepository(ref.watch(apiClientProvider));
});

final projectsStreamProvider = FutureProvider<List<ProjectModel>>((ref) {
  ref.watch(dataRefreshVersionProvider);
  final user = ref.watch(currentUserProvider);
  final engineerId = user?.role == UserRole.engineer ? user?.id : null;
  return ref.watch(projectsRepositoryProvider).getProjects(engineerId);
});

final projectsWithDetailsProvider = FutureProvider<List<ProjectWithDetails>>((ref) {
  ref.watch(dataRefreshVersionProvider);
  final user = ref.watch(currentUserProvider);
  final engineerId = user?.role == UserRole.engineer ? user?.id : null;
  return ref.watch(projectsRepositoryProvider).getProjectsWithDetails(engineerId);
});

final projectProvider =
    FutureProvider.family<ProjectWithDetails?, int>((ref, id) {
  ref.watch(dataRefreshVersionProvider);
  return ref.watch(projectsRepositoryProvider).getProject(id);
});

final projectStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  ref.watch(dataRefreshVersionProvider);
  final projects = await ref.watch(projectsStreamProvider.future);
  return {
    'total': projects.length,
    'inProgress': projects.where((p) => p.status == 'In Progress').length,
    'completed': projects.where((p) => p.status == 'Completed').length,
    'revenue': projects.fold<double>(0, (sum, p) => sum + p.totalValue),
  };
});

final recentProjectsProvider = FutureProvider<List<ProjectModel>>((ref) async {
  ref.watch(dataRefreshVersionProvider);
  final projects = [...await ref.watch(projectsStreamProvider.future)];
  projects.sort((a, b) => (b.createdDate ?? DateTime.fromMillisecondsSinceEpoch(0))
      .compareTo(a.createdDate ?? DateTime.fromMillisecondsSinceEpoch(0)));
  return projects.take(5).toList();
});
