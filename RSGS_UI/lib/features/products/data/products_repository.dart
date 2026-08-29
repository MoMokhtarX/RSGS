import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/data_refresh_service.dart';

import '../../../core/network/api_client.dart';
import '../models/product_models.dart';

class ProductsRepository {
  ProductsRepository(this._api);
  final ApiClient _api;

  Future<List<ProductComponentModel>> getAll({
    String? search,
    ProductCategory? category,
    bool activeOnly = false,
  }) async {
    final response = await _api.get(
      '/api/Products',
      queryParameters: {
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        if (category != null) 'category': category.value,
        'activeOnly': activeOnly,
      },
    );
    return _list(response).map(ProductComponentModel.fromMap).toList();
  }

  Future<ProductComponentModel> create({
    required String code,
    required String name,
    required ProductCategory category,
    String? brand,
    String? model,
    String? specification,
    required String unit,
    String? countryOfOrigin,
    required double costPrice,
    required double sellingPrice,
  }) async {
    final response = await _api.post('/api/Products', data: {
      'code': code.trim(),
      'name': name.trim(),
      'category': category.value,
      'brand': _nullable(brand),
      'model': _nullable(model),
      'specification': _nullable(specification),
      'unit': unit.trim(),
      'countryOfOrigin': _nullable(countryOfOrigin),
      'costPrice': costPrice,
      'sellingPrice': sellingPrice,
    });
    return ProductComponentModel.fromMap(_object(response));
  }

  Future<ProductComponentModel> update(
    int id, {
    required String name,
    required ProductCategory category,
    String? brand,
    String? model,
    String? specification,
    required String unit,
    String? countryOfOrigin,
    required double costPrice,
    required double sellingPrice,
    required bool isActive,
  }) async {
    final response = await _api.put('/api/Products/$id', data: {
      'name': name.trim(),
      'category': category.value,
      'brand': _nullable(brand),
      'model': _nullable(model),
      'specification': _nullable(specification),
      'unit': unit.trim(),
      'countryOfOrigin': _nullable(countryOfOrigin),
      'costPrice': costPrice,
      'sellingPrice': sellingPrice,
      'isActive': isActive,
    });
    return ProductComponentModel.fromMap(_object(response));
  }

  Future<void> setActive(int id, bool active) async {
    await _api.put('/api/Products/$id/${active ? 'enable' : 'disable'}');
  }

  String? _nullable(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }

  List<Map<String, dynamic>> _list(dynamic response) {
    if (response is List) return response.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    if (response is Map) {
      final data = response['data'] ?? response['items'];
      if (data is List) return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return const [];
  }

  Map<String, dynamic> _object(dynamic response) {
    if (response is Map) {
      final map = Map<String, dynamic>.from(response);
      if (map.containsKey('id')) return map;
      if (map['data'] is Map) return Map<String, dynamic>.from(map['data']);
    }
    throw const FormatException('Invalid product response.');
  }
}

final productsRepositoryProvider = Provider<ProductsRepository>(
  (ref) => ProductsRepository(ref.watch(apiClientProvider)),
);

final productsProvider = FutureProvider<List<ProductComponentModel>>(
  (ref) { ref.watch(dataRefreshVersionProvider); return ref.watch(productsRepositoryProvider).getAll(); },
);

final activeProductsProvider = FutureProvider<List<ProductComponentModel>>(
  (ref) { ref.watch(dataRefreshVersionProvider); return ref.watch(productsRepositoryProvider).getAll(activeOnly: true); },
);
