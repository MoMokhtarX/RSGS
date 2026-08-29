import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../auth/data/auth_repository.dart';
import '../../../core/models/app_models.dart';
import '../../projects/data/projects_repository.dart';
import 'customers_repository.dart';

class CustomerImportResult {
  const CustomerImportResult({
    required this.customersImported,
    required this.projectsCreated,
    required this.skippedRows,
    required this.sourceName,
  });

  final int customersImported;
  final int projectsCreated;
  final List<CustomerImportSkippedRow> skippedRows;
  final String sourceName;
}

class CustomerImportSkippedRow {
  const CustomerImportSkippedRow(this.rowNumber, this.reason);

  final int rowNumber;
  final String reason;
}

class CustomerImportException implements Exception {
  const CustomerImportException(this.message);

  final String message;

  @override
  String toString() => message;
}

class CustomerImportService {
  CustomerImportService(this._repository, this._projectsRepository, this._authRepository);

  final CustomersRepository _repository;
  final ProjectsRepository _projectsRepository;
  final AuthRepository _authRepository;

  Future<CustomerImportResult> importFromFile(String filePath) async {
    final extension = filePath.toLowerCase().split('.').last;
    if (extension == 'xlsx') {
      return _importFromExcel(filePath);
    } else if (extension == 'csv') {
      return _importFromCsv(filePath);
    } else {
      throw const CustomerImportException('Please select an .xlsx or .csv file.');
    }
  }

  Future<CustomerImportResult> _importFromExcel(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw const CustomerImportException('The selected file could not be found.');
    }

    final excel = Excel.decodeBytes(await file.readAsBytes());
    final source = _findCustomerSheet(excel);
    if (source == null) {
      throw const CustomerImportException(
        'No customer header was found. Include at least customer name and phone columns.',
      );
    }

    return _processRows(
      rows: source.rows,
      headerRowIndex: source.headerRowIndex,
      columnMapping: source.columns,
      sourceName: source.name,
      cellExtractor: (row, index) {
        if (index == null || index < 0 || index >= row.length) return '';
        final value = row[index]?.value;
        return value?.toString().trim() ?? '';
      },
    );
  }

  Future<CustomerImportResult> _importFromCsv(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw const CustomerImportException('The selected file could not be found.');
    }

    String content;
    try {
      content = await file.readAsString(encoding: utf8);
    } catch (_) {
      content = await file.readAsString(encoding: latin1);
    }

    final converter = const CsvToListConverter(
      shouldParseNumbers: false,
      allowInvalid: true,
    );
    final rows = converter.convert(content);

    if (rows.isEmpty) {
      throw const CustomerImportException('The CSV file is empty.');
    }

    _ImportSourceInfo? source;
    for (var i = 0; i < rows.length && i < 20; i++) {
      final columns = _mapHeaders(rows[i], (row, idx) => row[idx].toString().trim());
      if (columns.containsKey('phone') && !columns.containsKey('name') && columns.length >= 2) {
        columns['name'] = 0;
      }
      if (columns.containsKey('name') && columns.containsKey('phone')) {
        source = _ImportSourceInfo(file.path.split(Platform.pathSeparator).last, rows, i, columns);
        break;
      }
    }

    if (source == null) {
      throw const CustomerImportException(
        'No customer header was found in the CSV. Include at least customer name and phone columns.',
      );
    }

    return _processRows(
      rows: source.rows,
      headerRowIndex: source.headerRowIndex,
      columnMapping: source.columns,
      sourceName: source.name,
      cellExtractor: (row, index) {
        if (index == null || index < 0 || index >= row.length) return '';
        return row[index]?.toString().trim() ?? '';
      },
    );
  }

  Future<CustomerImportResult> _processRows<T>({
    required List<List<T>> rows,
    required int headerRowIndex,
    required Map<String, int> columnMapping,
    required String sourceName,
    required String Function(List<T> row, int? index) cellExtractor,
  }) async {
    final engineers = await _authRepository.getEngineers();
    final knownPhones = (await _repository.getAllCustomers())
        .map((customer) => _normalisePhone(customer.phone))
        .where((phone) => phone.isNotEmpty)
        .toSet();
    final skippedRows = <CustomerImportSkippedRow>[];
    var customersImported = 0;
    var projectsCreated = 0;

    for (var rowIndex = headerRowIndex + 1; rowIndex < rows.length; rowIndex++) {
      final row = rows[rowIndex];
      if (_isEmptyRow(row, cellExtractor)) continue;

      final name = cellExtractor(row, columnMapping['name']);
      final sourcePhone = cellExtractor(row, columnMapping['phone']);
      final phone = _normalisePhone(sourcePhone);
      final displayedRow = rowIndex + 1;

      if (name.isEmpty || phone.isEmpty) {
        skippedRows.add(CustomerImportSkippedRow(
          displayedRow,
          name.isEmpty && phone.isEmpty
              ? 'Customer name and phone are missing.'
              : name.isEmpty
                  ? 'Customer name is missing.'
                  : 'Phone is missing.',
        ));
        continue;
      }
      if (knownPhones.contains(phone)) {
        skippedRows.add(CustomerImportSkippedRow(displayedRow, 'A customer with this phone already exists.'));
        continue;
      }

      final channel = _canonicalValue(
        cellExtractor(row, columnMapping['channel']),
        AppConstants.customerChannels,
      );
      final governorate = _canonicalValue(
        cellExtractor(row, columnMapping['governorate']),
        AppConstants.governorates,
      );
      final inquiryDate = _parseDate(cellExtractor(row, columnMapping['inquiryDate']));
      final responsible = cellExtractor(row, columnMapping['responsible']);
      final assignedUserId = _findEngineerId(engineers, responsible);
      final notes = _importNotes(
        comments: cellExtractor(row, columnMapping['notes']),
        followUp: cellExtractor(row, columnMapping['followUp']),
        sourcePhone: sourcePhone,
        cellExtractor: cellExtractor,
        row: row,
      );
      final address = cellExtractor(row, columnMapping['address']);
      final systemType = cellExtractor(row, columnMapping['systemType']);
      final capacity = _parseCapacity(cellExtractor(row, columnMapping['capacity']));

      final customerId = await _repository.createCustomer(CustomerModel(
        id: 0,
        name: name,
        phone: phone,
        email: cellExtractor(row, columnMapping['email']).isEmpty
            ? null
            : cellExtractor(row, columnMapping['email']),
        notes: notes.isEmpty ? null : notes,
        channel: channel,
        followUpStatus: _canonicalValue(
              cellExtractor(row, columnMapping['followUpStatus']),
              AppConstants.customerFollowUpStatuses,
            ) ??
            'New',
        inquiryDate: inquiryDate ?? DateTime.now(),
        assignedUserId: assignedUserId,
        governorate: governorate,
        city: cellExtractor(row, columnMapping['city']).isEmpty
            ? null
            : cellExtractor(row, columnMapping['city']),
        firstCallNotes: _emptyToNull(cellExtractor(row, columnMapping['firstCallNotes'])),
        firstActionDate: _parseDate(cellExtractor(row, columnMapping['firstActionDate'])),
        secondCallNotes: _emptyToNull(cellExtractor(row, columnMapping['secondCallNotes'])),
        secondActionDate: _parseDate(cellExtractor(row, columnMapping['secondActionDate'])),
        thirdCallNotes: _emptyToNull(cellExtractor(row, columnMapping['thirdCallNotes'])),
        thirdActionDate: _parseDate(cellExtractor(row, columnMapping['thirdActionDate'])),
        fourthCallNotes: _emptyToNull(cellExtractor(row, columnMapping['fourthCallNotes'])),
        fourthActionDate: _parseDate(cellExtractor(row, columnMapping['fourthActionDate'])),
      ));

      if (systemType.isNotEmpty || capacity > 0) {
        await _projectsRepository.createProject(ProjectModel(
          id: 0,
          projectNumber: await _projectsRepository.newProjectNumber(),
          name: systemType.isNotEmpty ? systemType : 'Solar Project',
          customerId: customerId,
          engineerId: assignedUserId,
          status: 'Draft',
          totalKw: capacity,
          governorate: governorate,
          address: address.isEmpty ? null : address,
          notes: _projectNotes(systemType, cellExtractor(row, columnMapping['notes'])),
          createdDate: inquiryDate ?? DateTime.now(),
        ));
        projectsCreated++;
      }

      knownPhones.add(phone);
      customersImported++;
    }
    return CustomerImportResult(
      customersImported: customersImported,
      projectsCreated: projectsCreated,
      skippedRows: skippedRows,
      sourceName: sourceName,
    );
  }

  _ImportSourceInfo? _findCustomerSheet(Excel excel) {
    for (final entry in excel.tables.entries) {
      final rows = entry.value.rows;
      for (var rowIndex = 0; rowIndex < rows.length && rowIndex < 20; rowIndex++) {
        final columns = _mapHeaders(rows[rowIndex], (row, idx) {
          final value = row[idx]?.value;
          return value?.toString().trim() ?? '';
        });
        if (columns.containsKey('phone') && !columns.containsKey('name') && columns.length >= 2) {
          columns['name'] = 0;
        }
        if (columns.containsKey('name') && columns.containsKey('phone')) {
          return _ImportSourceInfo(entry.key, rows, rowIndex, columns);
        }
      }
    }
    return null;
  }

  Map<String, int> _mapHeaders<T>(List<T> row, String Function(List<T> row, int idx) cellText) {
    final result = <String, int>{};
    for (var index = 0; index < row.length; index++) {
      final header = _normaliseHeader(cellText(row, index));
      if (header.isEmpty) continue;
      for (final entry in _headerAliases.entries) {
        if (entry.value.contains(header)) {
          result.putIfAbsent(entry.key, () => index);
        }
      }
    }
    return result;
  }

  int? _findEngineerId(List<UserModel> engineers, String value) {
    var target = _normaliseHeader(value);
    if (target.isEmpty) return null;
    target = _arabicEngineerAliases[target] ?? target;
    for (final engineer in engineers) {
      if (_normaliseHeader(engineer.fullName) == target ||
          _normaliseHeader(engineer.username) == target) {
        return engineer.id;
      }
    }
    return null;
  }

  bool _isEmptyRow<T>(List<T> row, String Function(List<T> row, int idx) cellText) {
    for (var index = 0; index < row.length; index++) {
      if (cellText(row, index).isNotEmpty) return false;
    }
    return true;
  }

  String _normaliseHeader(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[\s_\-./()]+'), '')
      .replaceAll('أ', 'ا')
      .replaceAll('إ', 'ا')
      .replaceAll('آ', 'ا')
      .replaceAll('ى', 'ي');

  String _normalisePhone(String value) {
    final firstNumber = value.split(RegExp(r'[/,;\n]')).first;
    final compact = firstNumber.replaceAll(RegExp(r'[\s\-()]'), '');
    if (compact.startsWith('+')) {
      return '+${compact.substring(1).replaceAll(RegExp(r'\D'), '')}';
    }
    return compact.replaceAll(RegExp(r'\D'), '');
  }

  String? _canonicalValue(String value, List<String> choices) {
    if (value.trim().isEmpty) return null;
    final normalised = _normaliseHeader(value);
    for (final choice in choices) {
      if (_normaliseHeader(choice) == normalised) return choice;
    }
    return value.trim();
  }

  double _parseCapacity(String value) {
    if (value.isEmpty) return 0;
    final match = RegExp(r'[-+]?\d+(?:[.,]\d+)?').firstMatch(value.replaceAll(',', '.'));
    return match == null ? 0 : double.tryParse(match.group(0)!) ?? 0;
  }

  DateTime? _parseDate(String value) {
    if (value.isEmpty) return null;
    final direct = DateTime.tryParse(value);
    if (direct != null) return direct;

    final serial = double.tryParse(value);
    if (serial != null && serial > 20000 && serial < 100000) {
      return DateTime.utc(1899, 12, 30).add(Duration(milliseconds: (serial * 86400000).round())).toLocal();
    }

    final match = RegExp(r'^(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})$').firstMatch(value);
    if (match == null) return null;
    final first = int.parse(match.group(1)!);
    final second = int.parse(match.group(2)!);
    var year = int.parse(match.group(3)!);
    if (year < 100) year += 2000;
    return second > 12 ? DateTime(year, first, second) : DateTime(year, second, first);
  }

  String _projectNotes(String systemType, String notes) {
    final parts = <String>['Imported from File'];
    if (systemType.isNotEmpty) parts.add('System type: $systemType');
    if (notes.isNotEmpty) parts.add('Comments: $notes');
    return parts.join('. ');
  }

  String _importNotes<T>({
    required String comments,
    required String followUp,
    required String sourcePhone,
    required String Function(List<T> row, int? index) cellExtractor,
    required List<T> row,
  }) {
    final parts = <String>[];
    if (comments.isNotEmpty) parts.add(comments);
    if (followUp.isNotEmpty) parts.add('Follow-up: $followUp');
    if (_normalisePhone(sourcePhone) != sourcePhone.replaceAll(RegExp(r'[^0-9+]'), '')) {
      parts.add('Original contact: $sourcePhone');
    }
    return parts.join('\n');
  }

  String? _emptyToNull(String value) => value.isEmpty ? null : value;
}

class _ImportSourceInfo<T> {
  const _ImportSourceInfo(this.name, this.rows, this.headerRowIndex, this.columns);

  final String name;
  final List<List<T>> rows;
  final int headerRowIndex;
  final Map<String, int> columns;
}

const Map<String, Set<String>> _headerAliases = {
  'name': {'customername', 'name', 'clientname', 'اسم', 'اسم العميل'},
  'phone': {'phone', 'mobile', 'phonenumber', 'telephone', 'رقم التواصل', 'رقم الهاتف', 'موبايل', 'تليفون'},
  'email': {'email', 'emailaddress', 'البريدالالكتروني', 'ايميل'},
  'channel': {'channel', 'source', 'leadsource', 'مصدر', 'مصدرالعميل', 'القناة'},
  'inquiryDate': {'inquirydate', 'date', 'leaddate', 'تاريخ الاستفسار', 'تاريخ'},
  'systemType': {'systemtype', 'stationtype', 'projecttype', 'نوع المحطة', 'نوع النظام'},
  'capacity': {'capacity', 'kw', 'kwp', 'systemcapacity', 'قدرةالمحطةالمطلوبة', 'القدرة', 'السعة'},
  'governorate': {'area', 'governorate', 'region', 'المحافظة', 'المنطقة'},
  'city': {'city', 'town', 'المدينة'},
  'responsible': {'responsible', 'assignedto', 'salesperson', 'responsibleperson', 'المسؤول عن التواصل', 'المسئول عن التواصل', 'المسؤول', 'المسئول'},
  'address': {'address', 'customeraddress', 'العنوان', 'عنوان العميل'},
  'notes': {'notes', 'comments', 'comment', 'remarks', 'التعليق', 'ملاحظات'},
  'followUp': {'followupby', 'followupowner', 'المتابعة'},
  'followUpStatus': {'status', 'followupstatus', 'followup', 'الحالة', 'حالةالمتابعة'},
  'firstCallNotes': {'firstcall', 'call1', 'المكالمةالاولى'},
  'firstActionDate': {'firstactiondate', 'fisrtactiondate', '1stactiondate', 'تاريخ الاجراءالاول'},
  'secondCallNotes': {'secondcall', 'call2', 'المكالمةالثانية'},
  'secondActionDate': {'secondactiondate', 'sndactiondate', '2ndactiondate', 'تاريخ الاجراءالثاني'},
  'thirdCallNotes': {'thirdcall', 'call3', 'المكالمةالثالثة'},
  'thirdActionDate': {'thirdactiondate', '3rdactiondate', 'تاريخ الاجراءالثالث'},
  'fourthCallNotes': {'fourthcall', '4thcall', 'call4', 'المكالمةالرابعة'},
  'fourthActionDate': {'fourthactiondate', '4thactiondate', 'تاريخ الاجراءالرابع'},
};

const Map<String, String> _arabicEngineerAliases = {
  'اسراء': 'esraaatef',
  'اشاء': 'esraaatef',
  'محمدطارق': 'mohamedtarek',
  'محمدمختار': 'mohamedmokhtar',
  'اسامة': 'usamamakhlouf',
  'احمد': 'ahmedsoliman',
};

final customerImportServiceProvider = Provider<CustomerImportService>((ref) {
  return CustomerImportService(
    ref.watch(customersRepositoryProvider),
    ref.watch(projectsRepositoryProvider),
    ref.watch(authRepositoryProvider),
  );
});
