import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

class SearchResult {
  SearchResult({required this.title, required this.subtitle, required this.type, required this.route});
  final String title; final String subtitle; final String type; final String route;
  factory SearchResult.fromMap(Map<String,dynamic> m)=>SearchResult(title:m['title']?.toString()??'',subtitle:m['subtitle']?.toString()??'',type:m['type']?.toString()??'',route:m['route']?.toString()??'/');
}

class GlobalSearchService {
  GlobalSearchService(this._api);
  final ApiClient _api;
  Future<List<SearchResult>> search(String query) async {
    if(query.trim().length<2)return [];
    final response=await _api.get('/api/search',queryParameters:{'q':query.trim()});
    if(response is List)return response.whereType<Map>().map((e)=>SearchResult.fromMap(Map<String,dynamic>.from(e))).toList();
    return [];
  }
}
final globalSearchServiceProvider=Provider<GlobalSearchService>((ref)=>GlobalSearchService(ref.watch(apiClientProvider)));
final globalSearchProvider=FutureProvider.family<List<SearchResult>,String>((ref,query)=>ref.watch(globalSearchServiceProvider).search(query));
