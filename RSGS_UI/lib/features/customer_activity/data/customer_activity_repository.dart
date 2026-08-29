import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/data_refresh_service.dart';
import '../../../core/network/api_client.dart';
import '../models/customer_activity_models.dart';

class CustomerActivityRepository {
  CustomerActivityRepository(this._api);
  final ApiClient _api;

  Future<List<CustomerFollowUpModel>> getFollowUps(int customerId) async {
    final response = await _api.get('/api/Customers/$customerId/follow-ups');
    return _list(response).map(CustomerFollowUpModel.fromMap).toList();
  }

  Future<CustomerFollowUpModel> createFollowUp(int customerId, {required String type, required DateTime scheduledAt, String status = 'Pending', String? notes}) async {
    final response = await _api.post('/api/Customers/$customerId/follow-ups', data: {'type': type, 'scheduledAt': scheduledAt.toUtc().toIso8601String(), 'status': status, 'notes': notes});
    return CustomerFollowUpModel.fromMap(_object(response));
  }

  Future<CustomerFollowUpModel> updateFollowUp(int customerId, int id, {required String type, required DateTime scheduledAt, String status = 'Pending', String? notes, DateTime? completedAt}) async {
    final response = await _api.put('/api/Customers/$customerId/follow-ups/$id', data: {'type': type, 'scheduledAt': scheduledAt.toUtc().toIso8601String(), 'status': status, 'notes': notes, 'completedAt': completedAt?.toUtc().toIso8601String()});
    return CustomerFollowUpModel.fromMap(_object(response));
  }

  Future<void> deleteFollowUp(int customerId, int id) => _api.delete('/api/Customers/$customerId/follow-ups/$id');

  Future<List<CustomerInteractionModel>> getInteractions(int customerId) async {
    final response = await _api.get('/api/Customers/$customerId/interactions');
    return _list(response).map(CustomerInteractionModel.fromMap).toList();
  }

  Future<CustomerInteractionModel> createInteraction(int customerId, {required String type, String? subject, required String details, DateTime? occurredAt}) async {
    final response = await _api.post('/api/Customers/$customerId/interactions', data: {'type': type, 'subject': subject, 'details': details, 'occurredAt': occurredAt?.toUtc().toIso8601String()});
    return CustomerInteractionModel.fromMap(_object(response));
  }

  List<Map<String, dynamic>> _list(dynamic response) {
    if (response is List) return response.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    if (response is Map) {
      final m = Map<String, dynamic>.from(response); final data = m['items'] ?? m['data'];
      if (data is List) return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return const [];
  }

  Map<String, dynamic> _object(dynamic response) {
    if (response is Map) return Map<String, dynamic>.from(response);
    throw const FormatException('Invalid API response.');
  }
}

final customerActivityRepositoryProvider = Provider<CustomerActivityRepository>((ref) => CustomerActivityRepository(ref.watch(apiClientProvider)));
final customerFollowUpsProvider = FutureProvider.family<List<CustomerFollowUpModel>, int>((ref, id) { ref.watch(dataRefreshVersionProvider); return ref.watch(customerActivityRepositoryProvider).getFollowUps(id); });
final customerInteractionsProvider = FutureProvider.family<List<CustomerInteractionModel>, int>((ref, id) { ref.watch(dataRefreshVersionProvider); return ref.watch(customerActivityRepositoryProvider).getInteractions(id); });
