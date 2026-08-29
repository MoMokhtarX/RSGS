import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/data_refresh_service.dart';
import '../../../core/network/api_client.dart';
import '../../finance/models/finance_models.dart';

class OperationsRepository {
  OperationsRepository(this._api); final ApiClient _api;
  Future<List<SupplierModel>> getSuppliers({bool activeOnly=false}) async => _list(await _api.get('/api/Suppliers',queryParameters:{'activeOnly':activeOnly})).map(SupplierModel.fromMap).toList();
  Future<SupplierModel> createSupplier({required String code,required String name,String? contactPerson,String? phone,String? email,String? address,String? taxNumber,String? notes}) async => SupplierModel.fromMap(_obj(await _api.post('/api/Suppliers',data:{'code':code,'name':name,'contactPerson':contactPerson,'phone':phone,'email':email,'address':address,'taxNumber':taxNumber,'notes':notes,'isActive':true})));
  Future<SupplierModel> updateSupplier(SupplierModel s) async => SupplierModel.fromMap(_obj(await _api.put('/api/Suppliers/${s.id}',data:{'code':s.code,'name':s.name,'contactPerson':s.contactPerson,'phone':s.phone,'email':s.email,'address':s.address,'taxNumber':s.taxNumber,'notes':s.notes,'isActive':s.isActive})));
  Future<void> setSupplierActive(int id,bool active) async=>_api.put('/api/Suppliers/$id/${active?'enable':'disable'}');
  Future<List<InventoryItemModel>> getInventory({bool lowStockOnly=false}) async=>_list(await _api.get('/api/Inventory',queryParameters:{'lowStockOnly':lowStockOnly})).map(InventoryItemModel.fromMap).toList();
  Future<List<StockMovementModel>> getStockMovements({int? productComponentId}) async => _list(await _api.get('/api/Inventory/movements', queryParameters: productComponentId == null ? null : {'productComponentId': productComponentId})).map(StockMovementModel.fromMap).toList();
  Future<InventoryItemModel> adjustInventory({required int productComponentId,required double quantity,required bool increase,String? notes}) async=>InventoryItemModel.fromMap(_obj(await _api.post('/api/Inventory/adjust',data:{'productComponentId':productComponentId,'quantity':quantity,'increase':increase,'notes':notes})));
  Future<InventoryItemModel> setReorderLevel(int productId,double level) async=>InventoryItemModel.fromMap(_obj(await _api.put('/api/Inventory/$productId/reorder-level',data:{'reorderLevel':level})));
  Future<List<PurchaseOrderModel>> getPurchaseOrders() async=>_list(await _api.get('/api/PurchaseOrders')).map(PurchaseOrderModel.fromMap).toList();
  Future<PurchaseOrderModel> createPurchaseOrder({required int supplierId,required List<Map<String,dynamic>> items,double tax=0,String? notes}) async=>PurchaseOrderModel.fromMap(_obj(await _api.post('/api/PurchaseOrders',data:{'supplierId':supplierId,'orderDate':DateTime.now().toUtc().toIso8601String(),'tax':tax,'notes':notes,'items':items})));
  List<Map<String,dynamic>> _list(dynamic r){if(r is List)return r.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList();if(r is Map&&r['data'] is List)return (r['data'] as List).whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList();return const[];}
  Map<String,dynamic> _obj(dynamic r){if(r is Map){final m=Map<String,dynamic>.from(r);if(m['data'] is Map)return Map<String,dynamic>.from(m['data']);if(m.containsKey('id'))return m;}throw const FormatException('Invalid response.');}
}
final operationsRepositoryProvider=Provider<OperationsRepository>((ref)=>OperationsRepository(ref.watch(apiClientProvider)));
final suppliersProvider=FutureProvider<List<SupplierModel>>((ref){ ref.watch(dataRefreshVersionProvider); return ref.watch(operationsRepositoryProvider).getSuppliers(); });
final inventoryProvider=FutureProvider<List<InventoryItemModel>>((ref){ ref.watch(dataRefreshVersionProvider); return ref.watch(operationsRepositoryProvider).getInventory(); });
final purchaseOrdersProvider=FutureProvider<List<PurchaseOrderModel>>((ref){ ref.watch(dataRefreshVersionProvider); return ref.watch(operationsRepositoryProvider).getPurchaseOrders(); });
