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

  Future<CustomerImportResult> importFromFile(String filePath, [int? assignedUserId]) async {
    final extension = filePath.toLowerCase().split('.').last;
    if (extension == 'xlsx') {
      return _importFromExcel(filePath, assignedUserId);
    } else if (extension == 'csv') {
      return _importFromCsv(filePath, assignedUserId);
    } else {
      throw const CustomerImportException('Please select an .xlsx or .csv file.');
    }
  }

  Future<CustomerImportResult> _importFromExcel(String filePath, [int? fallbackUserId]) async {
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
      fallbackUserId: fallbackUserId,
      cellExtractor: (row, index) {
        if (index == null || index < 0 || index >= row.length) return '';
        final value = row[index]?.value;
        return value?.toString().trim() ?? '';
      },
    );
  }

  Future<CustomerImportResult> _importFromCsv(String filePath, [int? fallbackUserId]) async {
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

    final delimiters = [',', ';', '\t', '|'];
    String bestDelimiter = ',';
    int maxFields = 0;
    
    final lines = content.split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty).take(5).toList();
    for (final delimiter in delimiters) {
      int fields = 0;
      for (final line in lines) {
        fields += line.split(delimiter).length;
      }
      if (fields > maxFields) {
        maxFields = fields;
        bestDelimiter = delimiter;
      }
    }

    final converter = CsvToListConverter(
      fieldDelimiter: bestDelimiter,
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
      
      if (columns.containsKey('phone') && !columns.containsKey('name') && rows[i].length >= 2) {
        final phoneIdx = columns['phone']!;
        columns['name'] = phoneIdx == 0 ? 1 : 0;
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
      fallbackUserId: fallbackUserId,
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
    int? fallbackUserId,
  }) async {
    final engineers = await _authRepository.getEngineers();
    final skippedRows = <CustomerImportSkippedRow>[];
    var customersImported = 0;
    var projectsCreated = 0;

    for (var rowIndex = headerRowIndex + 1; rowIndex < rows.length; rowIndex++) {
      final row = rows[rowIndex];
      if (_isEmptyRow(row, cellExtractor)) continue;

      final name = cellExtractor(row, columnMapping['name']);
      final sourcePhone = cellExtractor(row, columnMapping['phone']);
      final phones = _extractPhones(sourcePhone);
      final phone = phones.isNotEmpty ? phones[0] : '';
      final phone2 = phones.length > 1 ? phones[1] : null;
      
      final displayedRow = rowIndex + 1;

      var finalName = name.isEmpty ? 'Unknown (Row $displayedRow)' : name;
      var finalPhone = phone.isEmpty ? 'N/A-$displayedRow' : phone;
      var finalPhone2 = phone2;

      if (_isProbablyPhone(finalName) && !_isProbablyPhone(finalPhone) && finalPhone.isNotEmpty && !finalPhone.startsWith('N/A')) {
        final temp = finalName;
        finalName = finalPhone;
        final processedPhones = _extractPhones(temp);
        finalPhone = processedPhones.isNotEmpty ? processedPhones[0] : '';
        if (finalPhone2 == null && processedPhones.length > 1) {
          finalPhone2 = processedPhones[1];
        }
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
      
      int? assignedUserId;
      if (fallbackUserId != null) {
        assignedUserId = fallbackUserId;
      } else {
        assignedUserId = _findEngineerId(engineers, responsible);
      }

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

      final finalDate = inquiryDate ?? DateTime.now();

      (DateTime? date, String notes) processCall(String noteValue, String dateValue) {
        DateTime? parsedDate = _parseDate(dateValue);
        String finalNote = noteValue;

        if (parsedDate == null && noteValue.isNotEmpty) {
          final extracted = _extractDateAndNotes(noteValue);
          if (extracted.$1 != null) {
            parsedDate = extracted.$1;
            finalNote = extracted.$2;
          }
        }
        return (parsedDate, finalNote);
      }

      final firstCall = processCall(
        cellExtractor(row, columnMapping['firstCallNotes']),
        cellExtractor(row, columnMapping['firstActionDate']),
      );
      final secondCall = processCall(
        cellExtractor(row, columnMapping['secondCallNotes']),
        cellExtractor(row, columnMapping['secondActionDate']),
      );
      final thirdCall = processCall(
        cellExtractor(row, columnMapping['thirdCallNotes']),
        cellExtractor(row, columnMapping['thirdActionDate']),
      );
      final fourthCall = processCall(
        cellExtractor(row, columnMapping['fourthCallNotes']),
        cellExtractor(row, columnMapping['fourthActionDate']),
      );

      final existing = await _repository.getCustomerByPhone(finalPhone);
      int customerId;

      final customerModel = CustomerModel(
        id: existing?.id ?? 0,
        name: finalName,
        phone: finalPhone,
        phone2: finalPhone2,
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
        inquiryDate: finalDate,
        assignedUserId: assignedUserId,
        governorate: governorate,
        city: cellExtractor(row, columnMapping['city']).isEmpty
            ? null
            : cellExtractor(row, columnMapping['city']),
        firstCallNotes: _emptyToNull(firstCall.$2),
        firstActionDate: firstCall.$1,
        secondCallNotes: _emptyToNull(secondCall.$2),
        secondActionDate: secondCall.$1,
        thirdCallNotes: _emptyToNull(thirdCall.$2),
        thirdActionDate: thirdCall.$1,
        fourthCallNotes: _emptyToNull(fourthCall.$2),
        fourthActionDate: fourthCall.$1,
      );

      if (existing != null) {
        await _repository.updateCustomer(customerModel);
        customerId = existing.id;
      } else {
        customerId = await _repository.createCustomer(customerModel);
      }

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
          createdDate: finalDate,
          installationDate: finalDate,
        ));
        projectsCreated++;
      }

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
        
        if (columns.containsKey('phone') && !columns.containsKey('name') && rows[rowIndex].length >= 2) {
          final phoneIdx = columns['phone']!;
          columns['name'] = phoneIdx == 0 ? 1 : 0;
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
    final phones = _extractPhones(value);
    return phones.isNotEmpty ? phones.first : '';
  }

  List<String> _extractPhones(String value) {
    if (value.isEmpty) return [];
    
    final initialParts = value.split(RegExp(r'[/,;\n&|]|or', caseSensitive: false));
    final List<String> results = [];

    for (var part in initialParts) {
      final cleaned = _cleanPhone(part);
      if (cleaned.isEmpty) continue;

      if (cleaned.length == 22 && (cleaned.startsWith('01') || cleaned.startsWith('201'))) {
        if (cleaned.startsWith('01')) {
          results.add(cleaned.substring(0, 11));
          results.add(cleaned.substring(11));
          continue;
        }
      }
      
      if (cleaned.length == 24 && cleaned.startsWith('201')) {
        results.add(cleaned.substring(0, 12));
        results.add(cleaned.substring(12));
        continue;
      }

      if (part.trim().contains(' ')) {
        final spaceParts = part.trim().split(RegExp(r'\s+'));
        final cleanedSpaceParts = spaceParts.map((p) => _cleanPhone(p)).where((p) => p.isNotEmpty).toList();
        
        if (cleanedSpaceParts.length > 1 && cleanedSpaceParts.every((p) => p.length >= 11)) {
          results.addAll(cleanedSpaceParts);
          continue;
        }
      }

      results.add(cleaned);
    }

    return results.where((s) => s.isNotEmpty).toList();
  }

  String _cleanPhone(String value) {
    final compact = value.trim().replaceAll(RegExp(r'[\s\-()]'), '');
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

    final isoMatch = RegExp(r'^(\d{4})[/-](\d{1,2})[/-](\d{1,2})$').firstMatch(value);
    if (isoMatch != null) {
      return DateTime(int.parse(isoMatch.group(1)!), int.parse(isoMatch.group(2)!), int.parse(isoMatch.group(3)!));
    }

    final match = RegExp(r'^(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})$').firstMatch(value);
    if (match == null) return null;
    final first = int.parse(match.group(1)!);
    final second = int.parse(match.group(2)!);
    var year = int.parse(match.group(3)!);
    if (year < 100) year += 2000;
    return second > 12 ? DateTime(year, first, second) : DateTime(year, second, first);
  }

  (DateTime? date, String notes) _extractDateAndNotes(String value) {
    if (value.trim().isEmpty) return (null, '');

    final regex = RegExp(r'^(\d{1,4}[/-]\d{1,2}[/-]\d{1,4})(?:\s*[-:–]\s*)?(.*)$');
    final match = regex.firstMatch(value.trim());

    if (match != null) {
      final dateStr = match.group(1)!;
      final remaining = match.group(2)!.trim();
      final parsed = _parseDate(dateStr);
      if (parsed != null) {
        return (parsed, remaining);
      }
    }

    return (null, value.trim());
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
    
    if (_normalisePhone(sourcePhone) != sourcePhone.replaceAll(RegExp(r'[^0-9+]'), '')) {
      parts.add('Original contact: $sourcePhone');
    }
    return parts.join('\n');
  }

  String? _emptyToNull(String value) => value.isEmpty ? null : value;

  bool _isProbablyPhone(String value) {
    if (value.isEmpty) return false;
    final digitCount = value.replaceAll(RegExp(r'\D'), '').length;
    return digitCount >= 8 && digitCount <= 15;
  }
}

class _ImportSourceInfo<T> {
  const _ImportSourceInfo(this.name, this.rows, this.headerRowIndex, this.columns);

  final String name;
  final List<List<T>> rows;
  final int headerRowIndex;
  final Map<String, int> columns;
}

const Map<String, Set<String>> _headerAliases = {
  'name': {'customername', 'name', 'clientname', 'اسم', 'اسمالعميل', 'الاسم'},
  'phone': {'phone', 'mobile', 'phonenumber', 'telephone', 'رقمالتواصل', 'رقمالهاتف', 'موبايل', 'تليفون', 'تلفون', 'الرقم'},
  'email': {'email', 'emailaddress', 'البريدالالكتروني', 'ايميل', 'الايميل'},
  'channel': {'channel', 'source', 'leadsource', 'مصدر', 'مصدرالعميل', 'القناة', 'قناةالتواصل'},
  'inquiryDate': {'inquirydate', 'date', 'leaddate', 'تاريخالاستفسار', 'تاريخ'},
  'systemType': {'systemtype', 'stationtype', 'projecttype', 'نوعالمحطة', 'نوعالنظام', 'النظام'},
  'capacity': {'capacity', 'kw', 'kwp', 'systemcapacity', 'قدرةالمحطةالمطلوبة', 'القدرة', 'السعة', 'كيلو'},
  'governorate': {'area', 'governorate', 'region', 'المحافظة', 'المنطقة', 'المكان'},
  'city': {'city', 'town', 'المدينة', 'المركز'},
  'responsible': {'responsible', 'assignedto', 'salesperson', 'responsibleperson', 'المسؤولعنالتواصل', 'المسئولعنالتواصل', 'المسؤول', 'المسئول', 'المندوب'},
  'address': {'address', 'customeraddress', 'العنوان', 'عنوانالعميل'},
  'notes': {'notes', 'comments', 'comment', 'remarks', 'التعليق', 'ملاحظات'},
  'followUp': {'followupby', 'followupowner', 'المتابعة'},
  'followUpStatus': {'status', 'followupstatus', 'followup', 'الحالة', 'حالةالمتابعة'},
  'firstCallNotes': {'firstcall', 'call1', 'المكالمةالاولى', 'المكالمة١'},
  'firstActionDate': {'firstactiondate', 'fisrtactiondate', '1stactiondate', 'تاريخالاجراءالاول', 'تاريخ١'},
  'secondCallNotes': {'secondcall', 'call2', 'المكالمةالثانية', 'المكالمة٢'},
  'secondActionDate': {'secondactiondate', 'sndactiondate', '2ndactiondate', 'تاريخالاجراءالثاني', 'تاريخ٢'},
  'thirdCallNotes': {'thirdcall', 'call3', 'المكالمةالثالثة', 'المكالمة٣'},
  'thirdActionDate': {'thirdactiondate', '3rdactiondate', 'تاريخالاجراءالثالث', 'تاريخ٣'},
  'fourthCallNotes': {'fourthcall', '4thcall', 'call4', 'المكالمةالرابعة', 'المكالمة٤'},
  'fourthActionDate': {'fourthactiondate', '4thactiondate', 'تاريخالاجراءالرابع', 'تاريخ٤'},
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
