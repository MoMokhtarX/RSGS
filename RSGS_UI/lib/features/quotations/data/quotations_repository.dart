import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../models/quotation_models.dart';

class QuotationPage { final List<QuotationModel> items; final int totalPages; final int totalRecords; const QuotationPage({required this.items,required this.totalPages,required this.totalRecords}); }

class QuotationsRepository {
  QuotationsRepository(this._api);

  final ApiClient _api;

  Future<List<QuotationModel>> getAll() async {
    final all=<QuotationModel>[]; var page=1;
    while(true){
      final response=await _api.get('/api/Quotations/paged',queryParameters:{'pageNumber':'$page','pageSize':'100'});
      final items=_extractList(response).map(QuotationModel.fromMap).toList(); all.addAll(items);
      final totalPages=response is Map&&response['totalPages'] is num?(response['totalPages'] as num).toInt():null;
      if(totalPages==null||page>=totalPages||items.isEmpty)break; page++;
    }
    return all;
  }

  Future<QuotationPage> getPage({int pageNumber=1,int pageSize=20,String? search,String? status,String? type}) async {
    final queryParameters = <String, dynamic>{
      'pageNumber': '$pageNumber',
      'pageSize': '$pageSize',
    };

    final trimmedSearch = search?.trim();
    if (trimmedSearch != null && trimmedSearch.isNotEmpty) {
      queryParameters['search'] = trimmedSearch;
    }
    if (status != null && status.isNotEmpty) {
      queryParameters['status'] = status;
    }
    if (type != null && type.isNotEmpty) {
      queryParameters['type'] = type;
    }

    final response=await _api.get('/api/Quotations/paged',queryParameters: queryParameters);
    final list=_extractList(response).map(QuotationModel.fromMap).toList(); final m=response is Map?response:const <String,dynamic>{};
    return QuotationPage(items:list,totalPages:m['totalPages'] is num?(m['totalPages'] as num).toInt():1,totalRecords:m['totalRecords'] is num?(m['totalRecords'] as num).toInt():list.length);
  }

  Future<QuotationModel?> getById(int id) async {
    final response = await _api.get('/api/Quotations/$id');
    if (response == null) return null;
    final map = _extractObject(response);
    return map == null ? null : QuotationModel.fromMap(map);
  }

  Future<QuotationModel> create(Map<String, dynamic> data) async {
    final response = await _api.post(
      '/api/Quotations',
      data: data,
    );
    final map = _extractObject(response);
    if (map == null) {
      throw const FormatException(
        'Invalid quotation create response.',
      );
    }
    return QuotationModel.fromMap(map);
  }

  Future<QuotationModel> update(
    int id,
    Map<String, dynamic> data,
  ) async {
    final response = await _api.put(
      '/api/Quotations/$id',
      data: data,
    );
    final map = _extractObject(response);
    if (map == null) {
      throw const FormatException(
        'Invalid quotation update response.',
      );
    }
    final result = QuotationModel.fromMap(map);
    // No easy way to get ref here, but we can assume the UI will invalidate the provider
    // Or we could pass WidgetRef to repository methods if needed, but the current pattern 
    // seems to be ref.invalidate in the UI. 
    // Wait, let's see how create was doing it.
    return result;
  }

  Future<void> deleteQuotation(int id) async {
    await _api.delete('/api/Quotations/$id');
  }

  Future<QuotationModel> changeStatus(
    int id,
    QuotationStatus status, {
    String method = 'Manual',
    String? recipient,
  }) async {
    final response = await _api.patch(
      '/api/Quotations/$id/status',
      data: {'status': status.value, 'tracking': {'method': method, 'recipient': recipient}},
    );
    final map = _extractObject(response);
    if (map == null) {
      throw const FormatException(
        'Invalid quotation status response.',
      );
    }
    final result = QuotationModel.fromMap(map);
    return result;
  }

  Future<List<int>> downloadQuotationPdf(int id) {
    return _api.getBytes('/api/Quotations/$id/pdf');
  }

  List<Map<String, dynamic>> _extractList(dynamic response) {
    dynamic current = response;
    for (var i = 0; i < 4; i++) {
      if (current is List) {
        return current
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      if (current is! Map) break;
      final map = Map<String, dynamic>.from(current);
      final items = map['items'];
      if (items is List) {
        return items
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      final data = map['data'];
      if (data is List) {
        return data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      current = data;
    }
    throw const FormatException('Invalid quotations response.');
  }

  Map<String, dynamic>? _extractObject(dynamic response) {
    dynamic current = response;
    for (var i = 0; i < 4; i++) {
      if (current is! Map) return null;
      final map = Map<String, dynamic>.from(current);
      if (map.containsKey('id') ||
          map.containsKey('quotationNumber') ||
          map.containsKey('quotation_number')) {
        return map;
      }
      final data = map['data'];
      if (data is Map) {
        current = data;
      } else {
        return null;
      }
    }
    return null;
  }
}

final quotationsRepositoryProvider =
Provider<QuotationsRepository>((ref) {
  return QuotationsRepository(
    ref.watch(apiClientProvider),
  );
});