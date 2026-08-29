import '../../../core/services/data_refresh_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../models/finance_models.dart';

class FinanceRepository {
  FinanceRepository(this._api); final ApiClient _api;
  Future<List<InvoiceModel>> getInvoices() async => _list(await _api.get('/api/Invoices')).map(InvoiceModel.fromMap).toList();
  Future<InvoiceModel> createInvoice({required int customerId,int? projectId,int? quotationId,DateTime? dueDate,double tax=0,required List<Map<String,dynamic>> items}) async => InvoiceModel.fromMap(_obj(await _api.post('/api/Invoices',data:{'customerId':customerId,'projectId':projectId,'quotationId':quotationId,'issueDate':DateTime.now().toUtc().toIso8601String(),'dueDate':dueDate?.toUtc().toIso8601String(),'tax':tax,'status':2,'items':items})));
  Future<InvoiceModel> createFromQuotation(int quotationId) async => InvoiceModel.fromMap(_obj(await _api.post('/api/Invoices/from-quotation/$quotationId')));
  Future<List<PaymentModel>> getPayments({int? invoiceId}) async => _list(await _api.get('/api/Invoices/payments',queryParameters:{'invoiceId': ?invoiceId})).map(PaymentModel.fromMap).toList();
  Future<PaymentModel> addPayment({required int invoiceId,required double amount,required PaymentMethod method,String? reference,String? notes}) async => PaymentModel.fromMap(_obj(await _api.post('/api/Invoices/payments',data:{'invoiceId':invoiceId,'amount':amount,'paymentDate':DateTime.now().toUtc().toIso8601String(),'method':method.value,'reference':reference,'notes':notes})));
  Future<List<Map<String,dynamic>>> getInstallments(int invoiceId) async => _list(await _api.get('/api/Invoices/$invoiceId/installments'));
  Future<void> addInstallment({required int invoiceId,required DateTime dueDate,required double amount}) async { await _api.post('/api/Invoices/installments',data:{'invoiceId':invoiceId,'dueDate':dueDate.toUtc().toIso8601String(),'amount':amount}); }
  List<Map<String,dynamic>> _list(dynamic r){if(r is List)return r.whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList(); if(r is Map&&r['data'] is List)return (r['data'] as List).whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList(); return const[];}
  Map<String,dynamic> _obj(dynamic r){if(r is Map){final m=Map<String,dynamic>.from(r); if(m['data'] is Map)return Map<String,dynamic>.from(m['data']); if(m.containsKey('id'))return m;} throw const FormatException('Invalid response.');}
}
final financeRepositoryProvider=Provider<FinanceRepository>((ref)=>FinanceRepository(ref.watch(apiClientProvider)));
final invoicesProvider=FutureProvider<List<InvoiceModel>>((ref){ref.watch(dataRefreshVersionProvider); return ref.watch(financeRepositoryProvider).getInvoices();});
final paymentsProvider=FutureProvider<List<PaymentModel>>((ref){ref.watch(dataRefreshVersionProvider); return ref.watch(financeRepositoryProvider).getPayments();});
