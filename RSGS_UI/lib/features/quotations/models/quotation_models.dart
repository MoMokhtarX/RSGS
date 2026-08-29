enum QuotationType {
  onGrid(1, 'On-Grid', 'On-Grid'),
  offGrid(2, 'Off-Grid', 'Off-Grid'),
  solarPump(3, 'Solar Pump', 'Solar Pump');

  const QuotationType(this.value, this.label, this.labelKey);

  final int value;
  final String label;
  final String labelKey;

  static QuotationType fromValue(dynamic value) {
    final intValue = value is int
        ? value
        : int.tryParse(value.toString()) ?? 1;

    return QuotationType.values.firstWhere(
          (e) => e.value == intValue,
      orElse: () => QuotationType.onGrid,
    );
  }
}

enum QuotationStatus {
  draft(1, 'Draft', 'Draft'),
  sent(2, 'Sent', 'Sent'),
  approved(3, 'Approved', 'Approved'),
  rejected(4, 'Rejected', 'Rejected'),
  expired(5, 'Expired', 'Expired');

  const QuotationStatus(this.value, this.label, this.labelKey);

  final int value;
  final String label;
  final String labelKey;

  static QuotationStatus fromValue(dynamic value) {
    final intValue = value is int
        ? value
        : int.tryParse(value.toString()) ?? 1;

    return QuotationStatus.values.firstWhere(
          (e) => e.value == intValue,
      orElse: () => QuotationStatus.draft,
    );
  }
}

enum QuotationItemCategory {
  solarPanels(1, 'Solar Panels', 'solar_panels'),
  structure(2, 'Structure', 'mounting_structure'),
  inverter(3, 'Inverter', 'inverter'),
  dcCables(4, 'DC Cables', 'dc_cables'),
  dcCombiner(5, 'DC Combiner', 'dc_combiner'),
  cableTray(6, 'Cable Tray', 'cable_tray'),
  grounding(7, 'Grounding', 'grounding_system'),
  mc4(8, 'MC4', 'mc4'),
  transportation(9, 'Transportation', 'transportation_item'),
  installation(10, 'Installation', 'installation_item'),
  maintenance(11, 'Maintenance', 'maintenance'),
  batteries(12, 'Batteries', 'batteries'),
  inverterPanel(13, 'Inverter Panel', 'inverter_panel'),
  cablePipes(14, 'Cable Pipes', 'cable_pipes'),
  other(99, 'Other', 'other');

  const QuotationItemCategory(
      this.value,
      this.label,
      this.labelKey,
      );

  final int value;
  final String label;
  final String labelKey;

  static QuotationItemCategory fromValue(
      dynamic value,
      ) {
    final intValue = value is int
        ? value
        : int.tryParse(value.toString()) ?? 99;

    return QuotationItemCategory.values.firstWhere(
          (e) => e.value == intValue,
      orElse: () => QuotationItemCategory.other,
    );
  }
}

class QuotationItemModel {
  QuotationItemModel({
    this.id,
    this.productComponentId,
    this.productCode,
    this.productName,
    required this.description,
    required this.item,
    required this.category,
    this.quantity,
    this.unit,
    this.countryOfOrigin,
    this.sortOrder = 0,
    this.internalNotes,
  });

  int? id;
  int? productComponentId;
  String? productCode;
  String? productName;
  String description;
  String item;
  QuotationItemCategory category;
  double? quantity;
  String? unit;
  String? countryOfOrigin;
  int sortOrder;
  String? internalNotes;
  double? unitCost;
  double? unitPrice;
  double totalCost = 0;
  double totalPrice = 0;

  factory QuotationItemModel.fromMap(
    Map<String, dynamic> map,
  ) {
    return QuotationItemModel(
      id: _toInt(map['id']),
      productComponentId: _toInt(map['productComponentId'] ?? map['product_component_id']),
      productCode: _nullableString(map['productCode'] ?? map['product_code']),
      productName: _nullableString(map['productName'] ?? map['product_name']),
      description: _toString(map['description']),
      item: _toString(map['item']),
      category: QuotationItemCategory.fromValue(map['category']),
      quantity: _toDouble(map['quantity']),
      unit: _nullableString(map['unit']),
      countryOfOrigin: _nullableString(
        map['countryOfOrigin'] ?? map['country_of_origin'],
      ),
      sortOrder: _toInt(map['sortOrder'] ?? map['sort_order']) ?? 0,
      internalNotes: _nullableString(
        map['internalNotes'] ?? map['internal_notes'],
      ),
    )
      ..unitCost = _toDouble(map['unitCost'] ?? map['unit_cost'])
      ..unitPrice = _toDouble(map['unitPrice'] ?? map['unit_price'])
      ..totalCost = _toDouble(map['totalCost'] ?? map['total_cost']) ?? 0
      ..totalPrice = _toDouble(map['totalPrice'] ?? map['total_price']) ?? 0;
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static String _toString(dynamic value) => value?.toString() ?? '';

  static String? _nullableString(dynamic value) {
    if (value == null) return null;
    final result = value.toString().trim();
    return result.isEmpty ? null : result;
  }

  Map<String, dynamic> toCreateMap() {
    return {
      'productComponentId': productComponentId,
      'description': description,
      'item': item,
      'category': category.value,
      'quantity': quantity,
      'unit': unit,
      'countryOfOrigin': countryOfOrigin,
      'sortOrder': sortOrder,
      'internalNotes': internalNotes,
      'unitCost': unitCost,
      'unitPrice': unitPrice,
    };
  }
}

class QuotationModel {
  QuotationModel({
    required this.id,
    required this.quotationNumber,
    required this.type,
    required this.status,
    required this.customerId,
    this.projectId,
    this.quotationDate,
    this.validUntil,
    this.systemDescription,
    this.systemCapacity,
    this.capacityUnit = 'kW',
    this.totalPrice = 0,
    this.materialsCost = 0,
    this.transportationCost = 0,
    this.installationCost = 0,
    this.otherCost = 0,
    this.profitMargin = 0,
    this.discount = 0,
    this.tax = 0,
    this.introduction,
    this.generalTerms,
    this.paymentTerms,
    this.notes,
    this.sentAt,
    this.sentByUserId,
    this.sentMethod,
    this.sentRecipient,
    this.items = const [],
  });

  final int id;
  final String quotationNumber;
  final QuotationType type;
  final QuotationStatus status;
  final int customerId;
  final int? projectId;
  final DateTime? quotationDate;
  final DateTime? validUntil;
  final String? systemDescription;
  final double? systemCapacity;
  final String capacityUnit;
  final double totalPrice;

  final double materialsCost;
  final double transportationCost;
  final double installationCost;
  final double otherCost;
  final double profitMargin;
  final double discount;
  final double tax;

  final String? introduction;
  final String? generalTerms;
  final String? paymentTerms;
  final String? notes;
  final DateTime? sentAt;
  final int? sentByUserId;
  final String? sentMethod;
  final String? sentRecipient;
  final List<QuotationItemModel> items;

  factory QuotationModel.fromMap(
    Map<String, dynamic> map,
  ) {
    final rawItems = map['items'];

    return QuotationModel(
      id: _toInt(map['id']) ?? 0,
      quotationNumber: _toString(
        map['quotationNumber'] ?? map['quotation_number'],
      ),
      type: QuotationType.fromValue(map['type']),
      status: QuotationStatus.fromValue(map['status']),
      customerId: _toInt(
        map['customerId'] ?? map['customer_id'],
      ) ?? 0,
      projectId: _toInt(
        map['projectId'] ?? map['project_id'],
      ),
      quotationDate: _parseDate(
        map['quotationDate'] ?? map['quotation_date'],
      ),
      validUntil: _parseDate(
        map['validUntil'] ?? map['valid_until'],
      ),
      systemDescription: _nullableString(
        map['systemDescription'] ?? map['system_description'],
      ),
      systemCapacity: _toDouble(
        map['systemCapacity'] ?? map['system_capacity'],
      ),
      capacityUnit: _toString(
        map['capacityUnit'] ?? map['capacity_unit'] ?? 'kW',
      ),
      totalPrice: _toDouble(map['totalPrice'] ?? map['total_price']) ?? 0,
      materialsCost: _toDouble(
        map['materialsCost'] ?? map['materials_cost'],
      ) ?? 0,
      transportationCost: _toDouble(
        map['transportationCost'] ?? map['transportation_cost'],
      ) ?? 0,
      installationCost: _toDouble(
        map['installationCost'] ?? map['installation_cost'],
      ) ?? 0,
      otherCost: _toDouble(
        map['otherCost'] ?? map['other_cost'],
      ) ?? 0,
      profitMargin: _toDouble(
        map['profitMargin'] ?? map['profit_margin'],
      ) ?? 0,
      discount: _toDouble(map['discount']) ?? 0,
      tax: _toDouble(map['tax']) ?? 0,
      introduction: _nullableString(map['introduction']),
      generalTerms: _nullableString(
        map['generalTerms'] ?? map['general_terms'],
      ),
      paymentTerms: _nullableString(
        map['paymentTerms'] ?? map['payment_terms'],
      ),
      notes: _nullableString(map['notes']),
      sentAt: _parseDate(map['sentAt'] ?? map['sent_at']),
      sentByUserId: _toInt(map['sentByUserId'] ?? map['sent_by_user_id']),
      sentMethod: _nullableString(map['sentMethod'] ?? map['sent_method']),
      sentRecipient: _nullableString(map['sentRecipient'] ?? map['sent_recipient']),
      items: rawItems is List
          ? rawItems
              .whereType<Map>()
              .map((e) => QuotationItemModel.fromMap(
                    Map<String, dynamic>.from(e),
                  ))
              .toList()
          : const [],
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static String _toString(dynamic value) => value?.toString() ?? '';

  static String? _nullableString(dynamic value) {
    if (value == null) return null;
    final result = value.toString().trim();
    return result.isEmpty ? null : result;
  }
}
