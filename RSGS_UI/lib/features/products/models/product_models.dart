enum ProductCategory {
  solarPanels(1, 'Solar Panels'),
  structure(2, 'Structure'),
  inverter(3, 'Inverter'),
  dcCables(4, 'DC Cables'),
  dcCombiner(5, 'DC Combiner'),
  cableTray(6, 'Cable Tray'),
  grounding(7, 'Grounding'),
  mc4(8, 'MC4'),
  transportation(9, 'Transportation'),
  installation(10, 'Installation'),
  maintenance(11, 'Maintenance'),
  batteries(12, 'Batteries'),
  inverterPanel(13, 'Inverter Panel'),
  cablePipes(14, 'Cable Pipes'),
  other(99, 'Other');

  const ProductCategory(this.value, this.label);
  final int value;
  final String label;

  static ProductCategory fromValue(dynamic value) {
    final number = value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 99;
    return values.firstWhere((x) => x.value == number, orElse: () => ProductCategory.other);
  }
}

class ProductComponentModel {
  const ProductComponentModel({
    required this.id,
    required this.code,
    required this.name,
    required this.category,
    this.brand,
    this.model,
    this.specification,
    required this.unit,
    this.countryOfOrigin,
    required this.costPrice,
    required this.sellingPrice,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String code;
  final String name;
  final ProductCategory category;
  final String? brand;
  final String? model;
  final String? specification;
  final String unit;
  final String? countryOfOrigin;
  final double costPrice;
  final double sellingPrice;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get displayName {
    final suffix = [brand, model].where((x) => x != null && x.trim().isNotEmpty).join(' ');
    return suffix.isEmpty ? name : '$name — $suffix';
  }

  factory ProductComponentModel.fromMap(Map<String, dynamic> map) {
    return ProductComponentModel(
      id: _int(map['id']) ?? 0,
      code: map['code']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      category: ProductCategory.fromValue(map['category']),
      brand: _nullable(map['brand']),
      model: _nullable(map['model']),
      specification: _nullable(map['specification']),
      unit: map['unit']?.toString() ?? 'pcs',
      countryOfOrigin: _nullable(map['countryOfOrigin'] ?? map['country_of_origin']),
      costPrice: _double(map['costPrice'] ?? map['cost_price']) ?? 0,
      sellingPrice: _double(map['sellingPrice'] ?? map['selling_price']) ?? 0,
      isActive: map['isActive'] == true || map['is_active'] == true,
      createdAt: _date(map['createdAt'] ?? map['created_at']),
      updatedAt: _date(map['updatedAt'] ?? map['updated_at']),
    );
  }

  static int? _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static double? _double(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  static String? _nullable(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static DateTime? _date(dynamic value) => value == null ? null : DateTime.tryParse(value.toString());
}
