import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/data_refresh_service.dart';

import '../../../core/network/api_client.dart';
import '../../../core/models/app_models.dart';
import '../../../core/permissions/user_role.dart';
import '../../auth/data/auth_repository.dart';
import '../../customer_activity/models/customer_activity_models.dart';

class CustomerWithDetails {
  CustomerWithDetails({required this.customer, this.assignedUserName});

  final CustomerModel customer;
  final String? assignedUserName;

  factory CustomerWithDetails.fromJson(Map<String, dynamic> json) {
    final assigned = json['assignedUser'];
    return CustomerWithDetails(
      customer: _customerFromApi(json),
      assignedUserName: assigned is Map
          ? (assigned['fullName'] ?? assigned['full_name'])?.toString()
          : (json['assignedUserName'] ?? json['assigned_user_name'])?.toString(),
    );
  }
}

class CustomersRepository {
  CustomersRepository(this._api);

  final ApiClient _api;

  Future<List<CustomerModel>> getAllCustomers([
    int? assignedUserId,
    bool ascending = true,
  ]) async {
    final all = <CustomerModel>[];
    var page = 1;
    while (true) {
      final response = await _api.get('/api/Customers', queryParameters: {
        'pageNumber': '$page', 'pageSize': '100', 'descending': (!ascending).toString(),
        if (assignedUserId != null) 'assignedUserId': '$assignedUserId',
      });
      final items = _extractList(response).map(_customerFromApi).toList();
      all.addAll(items);
      final meta = _extractPageMeta(response);
      if (meta == null || page >= meta.totalPages || items.isEmpty) break;
      page++;
    }
    return all;
  }

  Future<CustomerPage> getPage({int pageNumber = 1, int pageSize = 20, String? search, int? assignedUserId, bool descending = true}) async {
    final response = await _api.get('/api/Customers', queryParameters: {
      'pageNumber': '$pageNumber', 'pageSize': '$pageSize', 'descending': '$descending',
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (assignedUserId != null) 'assignedUserId': '$assignedUserId',
    });
    return CustomerPage(items: _extractList(response).map(_customerFromApi).toList(), meta: _extractPageMeta(response));
  }

  Future<List<CustomerWithDetails>> getCustomersWithDetails([
    int? assignedUserId,
    bool ascending = true,
  ]) async {
    final all = <CustomerWithDetails>[];
    var page = 1;
    while (true) {
      final response = await _api.get('/api/Customers', queryParameters: {
        'pageNumber': '$page',
        'pageSize': '100',
        'descending': (!ascending).toString(),
        if (assignedUserId != null) 'assignedUserId': '$assignedUserId',
      });
      
      final rawItems = _extractList(response);
      final items = rawItems.map((json) => CustomerWithDetails.fromJson(json)).toList();
      all.addAll(items);
      
      final meta = _extractPageMeta(response);
      if (meta == null || page >= meta.totalPages || items.isEmpty) break;
      page++;
    }
    return all;
  }

  Future<List<CustomerModel>> searchCustomers(
    String query, [
    int? assignedUserId,
  ]) async {
    final response = await _api.get(
      '/api/Customers',
      queryParameters: {
        'pageNumber': '1',
        'pageSize': '100',
        'search': query,
        if (assignedUserId != null)
          'assignedUserId': assignedUserId.toString(),
      },
    );

    return _extractList(response).map(_customerFromApi).toList();
  }

  Future<CustomerModel?> getCustomer(
    int id, [
    int? assignedUserId,
  ]) async {
    final response = await _api.get('/api/Customers/$id');
    final map = _extractObject(response);
    return map == null ? null : _customerFromApi(map);
  }

  Future<CustomerModel?> getCustomerByPhone(String phone) async {
    final customers = await getAllCustomers();

    for (final customer in customers) {
      if (customer.phone == phone || customer.phone2 == phone) {
        return customer;
      }
    }

    return null;
  }

  Future<int> createCustomer(CustomerModel customer) async {
    final response = await _api.post(
      '/api/Customers',
      data: _customerToApi(customer),
    );

    final map = _extractObject(response);
    final id = _toInt(map?['id']);

    if (id == null) {
      throw const FormatException(
        'Customer was created, but the API did not return the customer id.',
      );
    }

    return id;
  }

  Future<void> updateCustomer(CustomerModel customer) async {
    await _api.put(
      '/api/Customers/${customer.id}',
      data: _customerToApi(customer),
    );
  }

  Future<void> deleteCustomer(int id) async {
    try {
      await _api.delete('/api/Customers/$id');
    } catch (e) {
      if (e is ApiException &&
          e.message.toLowerCase().contains('project')) {
        throw Exception('customer_has_projects');
      }
      rethrow;
    }
  }

  Future<int> deleteAllCustomers() async {
    throw ApiException(
      405,
      'Delete all customers is not supported by the current API.',
    );
  }

  Future<int> getCustomerCount([int? assignedUserId]) async {
    final customers = await getAllCustomers(assignedUserId);
    return customers.length;
  }

  Future<List<CustomerModel>> getRecentCustomers({
    int limit = 5,
    int? assignedUserId,
  }) async {
    final customers = await getAllCustomers(assignedUserId);

    customers.sort((a, b) {
      final aDate =
          a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate =
          b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });

    return customers.take(limit).toList();
  }

  Future<List<CustomerInteractionModel>> getInteractions(int customerId) async {
    final response = await _api.get('/api/Customers/$customerId/interactions');
    return _extractList(response).map((m) => CustomerInteractionModel.fromMap(m)).toList();
  }

  Future<void> addInteraction(int customerId, {required String type, required String details, String? subject}) async {
    await _api.post('/api/Customers/$customerId/interactions', data: {
      'customerId': customerId,
      'type': type,
      'details': details,
      'subject': subject,
      'occurredAt': DateTime.now().toUtc().toIso8601String(),
    });
  }
}

List<Map<String, dynamic>> _extractList(dynamic response) {
  dynamic current = response;

  for (var depth = 0; depth < 6; depth++) {
    if (current is List) {
      return current
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    if (current is! Map) {
      break;
    }

    final map = Map<String, dynamic>.from(current);

    final items = map['items'];
    if (items is List) {
      return items
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    if (map.containsKey('data')) {
      current = map['data'];
      continue;
    }

    if (map.containsKey('results')) {
      current = map['results'];
      continue;
    }

    break;
  }

  throw const FormatException(
    'Invalid customers response: expected a customer list.',
  );
}

Map<String, dynamic>? _extractObject(dynamic response) {
  dynamic current = response;

  for (var depth = 0; depth < 6; depth++) {
    if (current is! Map) return null;

    final map = Map<String, dynamic>.from(current);

    if (map.containsKey('id') || map.containsKey('name')) {
      return map;
    }

    if (map.containsKey('data')) {
      current = map['data'];
      continue;
    }

    if (map.containsKey('result')) {
      current = map['result'];
      continue;
    }

    return null;
  }

  return null;
}

class PageMeta { final int pageNumber; final int pageSize; final int totalRecords; final int totalPages; const PageMeta(this.pageNumber,this.pageSize,this.totalRecords,this.totalPages); }
class CustomerPage { final List<CustomerModel> items; final PageMeta? meta; const CustomerPage({required this.items, required this.meta}); }
PageMeta? _extractPageMeta(dynamic response) { if (response is! Map) return null; final m=Map<String,dynamic>.from(response); final pn=m['pageNumber'], ps=m['pageSize'], tr=m['totalRecords'], tp=m['totalPages']; if(pn is num&&ps is num&&tr is num&&tp is num) return PageMeta(pn.toInt(),ps.toInt(),tr.toInt(),tp.toInt()); return null; }

CustomerModel _customerFromApi(Map<String, dynamic> map) {
  return CustomerModel.fromMap({
    'id': map['id'],
    'name': map['name'],
    'phone': map['phone'],
    'phone2': map['phone2'],
    'email': map['email'],
    'notes': map['notes'],
    'created_at': map['createdAt'] ?? map['created_at'],
    'updated_at': map['updatedAt'] ?? map['updated_at'],
    'governorate': map['governorate'],
    'city': map['city'],
    'channel': map['channel'],
    'inquiry_date': map['inquiryDate'] ?? map['inquiry_date'],
    'follow_up_status':
        map['followUpStatus'] ?? map['follow_up_status'],
    'assigned_user_id':
        map['assignedUserId'] ?? map['assigned_user_id'],
    'first_call_notes':
        map['firstCallNotes'] ?? map['first_call_notes'],
    'first_action_date':
        map['firstActionDate'] ?? map['first_action_date'],
    'second_call_notes':
        map['secondCallNotes'] ?? map['second_call_notes'],
    'second_action_date':
        map['secondActionDate'] ?? map['second_action_date'],
    'third_call_notes':
        map['thirdCallNotes'] ?? map['third_call_notes'],
    'third_action_date':
        map['thirdActionDate'] ?? map['third_action_date'],
    'fourth_call_notes':
        map['fourthCallNotes'] ?? map['fourth_call_notes'],
    'fourth_action_date':
        map['fourthActionDate'] ?? map['fourth_action_date'],
  });
}

Map<String, Object?> _customerToApi(CustomerModel customer) {
  return {
    'name': customer.name,
    'phone': customer.phone,
    'phone2': customer.phone2,
    'email': customer.email,
    'notes': customer.notes,
    'governorate': customer.governorate,
    'city': customer.city,
    'channel': customer.channel,
    'inquiryDate': customer.inquiryDate?.toIso8601String(),
    'followUpStatus': customer.followUpStatus,
    'assignedUserId': customer.assignedUserId,
    'firstCallNotes': customer.firstCallNotes,
    'firstActionDate':
        customer.firstActionDate?.toIso8601String(),
    'secondCallNotes': customer.secondCallNotes,
    'secondActionDate':
        customer.secondActionDate?.toIso8601String(),
    'thirdCallNotes': customer.thirdCallNotes,
    'thirdActionDate':
        customer.thirdActionDate?.toIso8601String(),
    'fourthCallNotes': customer.fourthCallNotes,
    'fourthActionDate':
        customer.fourthActionDate?.toIso8601String(),
  };
}

int? _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

final customersRepositoryProvider =
    Provider<CustomersRepository>((ref) {
  return CustomersRepository(ref.watch(apiClientProvider));
});

final customersStreamProvider =
    FutureProvider<List<CustomerModel>>((ref) {
  ref.watch(dataRefreshVersionProvider);
  final user = ref.watch(currentUserProvider);
  final assignedUserId =
      user?.role == UserRole.engineer ? user?.id : null;

  return ref
      .watch(customersRepositoryProvider)
      .getAllCustomers(assignedUserId);
});

final customersWithDetailsProvider =
    FutureProvider<List<CustomerWithDetails>>((ref) {
  ref.watch(dataRefreshVersionProvider);
  final user = ref.watch(currentUserProvider);
  final assignedUserId =
      user?.role == UserRole.engineer ? user?.id : null;

  return ref
      .watch(customersRepositoryProvider)
      .getCustomersWithDetails(assignedUserId);
});

final customerCountProvider = FutureProvider<int>((ref) {
  ref.watch(dataRefreshVersionProvider);
  final user = ref.watch(currentUserProvider);
  final assignedUserId =
      user?.role == UserRole.engineer ? user?.id : null;

  return ref
      .watch(customersRepositoryProvider)
      .getCustomerCount(assignedUserId);
});

final recentCustomersProvider =
    FutureProvider<List<CustomerModel>>((ref) {
  ref.watch(dataRefreshVersionProvider);
  final user = ref.watch(currentUserProvider);
  final assignedUserId =
      user?.role == UserRole.engineer ? user?.id : null;

  return ref
      .watch(customersRepositoryProvider)
      .getRecentCustomers(
        assignedUserId: assignedUserId,
      );
});

final customerProvider =
    FutureProvider.family<CustomerModel?, int>((ref, id) {
  ref.watch(dataRefreshVersionProvider);
  final user = ref.watch(currentUserProvider);
  final assignedUserId =
      user?.role == UserRole.engineer ? user?.id : null;

  return ref
      .watch(customersRepositoryProvider)
      .getCustomer(id, assignedUserId);
});

final customerDetailsProvider =
    FutureProvider.family<CustomerWithDetails?, int>(
  (ref, id) async {
    ref.watch(dataRefreshVersionProvider);
    final customers =
        await ref.watch(customersWithDetailsProvider.future);

    try {
      return customers.firstWhere(
        (c) => c.customer.id == id,
      );
    } catch (_) {
      return null;
    }
  },
);
