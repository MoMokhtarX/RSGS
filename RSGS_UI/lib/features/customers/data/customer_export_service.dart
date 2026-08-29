import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/models/app_models.dart';
import '../../../core/localization/date_formatter.dart';
import '../../projects/data/projects_repository.dart';
import 'customers_repository.dart';

class CustomerExportService {
  CustomerExportService(this._customersRepository, this._projectsRepository);

  final CustomersRepository _customersRepository;
  final ProjectsRepository _projectsRepository;

  Future<String?> exportToExcel() async {
    final customers = await _customersRepository.getCustomersWithDetails();
    final allProjects = await _projectsRepository.getProjects();
    
    final excel = Excel.createExcel();
    final sheet = excel['Customers'];
    excel.delete('Sheet1');

    sheet.isRTL = true;

    final headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#008080'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    final bodyStyle = CellStyle(
      horizontalAlign: HorizontalAlign.Right,
      verticalAlign: VerticalAlign.Center,
    );

    final headers = [
      'الاسم',
      'رقم التواصل',
      'البريد الالكتروني',
      'مصدر العميل',
      'تاريخ الاستفسار',
      'نوع النظام',
      'القدرة',
      'المحافظة',
      'المدينة',
      'المسؤول',
      'العنوان',
      'ملاحظات',
      'الحالة',
      'المكالمة الاولى',
      'تاريخ الاجراء الاول',
      'المكالمة الثانية',
      'تاريخ الاجراء الثاني',
      'المكالمة الثالثة',
      'تاريخ الاجراء الثالث',
      'المكالمة الرابعة',
      'تاريخ الاجراء الرابع',
    ];

    for (var i = 0; i < headers.length; i++) {
      var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
      
      double width = 18.0;
      if (i == 0) width = 30.0;
      if (i == 1) width = 25.0;
      if (i == 10 || i == 11) width = 35.0;
      sheet.setColumnWidth(i, width);
    }
    
    sheet.setRowHeight(0, 30.0);

    var rowIndex = 1;
    for (final detail in customers) {
      final customer = detail.customer;
      final projects = allProjects.where((p) => p.customerId == customer.id).toList();

      final rowDataList = projects.isEmpty
          ? [_buildRow(customer, null, detail.assignedUserName)]
          : projects.map((p) => _buildRow(customer, p, detail.assignedUserName)).toList();

      for (final rowData in rowDataList) {
        for (var colIndex = 0; colIndex < rowData.length; colIndex++) {
          var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex, rowIndex: rowIndex));
          cell.value = rowData[colIndex];
          cell.cellStyle = bodyStyle;
        }
        rowIndex++;
      }
    }

    final bytes = excel.save();
    if (bytes == null) return null;

    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      final outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Exported Data',
        fileName: 'rsgs_customers_export_${DateTime.now().year}_${DateTime.now().month}_${DateTime.now().day}.xlsx',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );
      
      if (outputFile != null) {
        final file = File(outputFile);
        await file.writeAsBytes(bytes);
        return outputFile;
      }
    } else {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/customers_export_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final file = File(filePath);
      await file.writeAsBytes(bytes);
      return filePath;
    }
    
    return null;
  }

  List<CellValue?> _buildRow(CustomerModel customer, ProjectModel? project, String? responsible) {
    return [
      TextCellValue(customer.name),
      TextCellValue(customer.phone + (customer.phone2 != null ? ' / ${customer.phone2}' : '')),
      TextCellValue(customer.email ?? ''),
      TextCellValue(customer.channel ?? ''),
      TextCellValue(customer.inquiryDate?.format('dd/MM/yyyy') ?? ''),
      TextCellValue(project?.name ?? ''),
      DoubleCellValue(project?.totalKw ?? 0),
      TextCellValue(customer.governorate ?? project?.governorate ?? ''),
      TextCellValue(customer.city ?? project?.city ?? ''),
      TextCellValue(responsible ?? ''),
      TextCellValue(project?.address ?? ''),
      TextCellValue(customer.notes ?? ''),
      TextCellValue(customer.followUpStatus ?? ''),
      TextCellValue(customer.firstCallNotes ?? ''),
      TextCellValue(customer.firstActionDate?.format('dd/MM/yyyy') ?? ''),
      TextCellValue(customer.secondCallNotes ?? ''),
      TextCellValue(customer.secondActionDate?.format('dd/MM/yyyy') ?? ''),
      TextCellValue(customer.thirdCallNotes ?? ''),
      TextCellValue(customer.thirdActionDate?.format('dd/MM/yyyy') ?? ''),
      TextCellValue(customer.fourthCallNotes ?? ''),
      TextCellValue(customer.fourthActionDate?.format('dd/MM/yyyy') ?? ''),
    ];
  }
}

final customerExportServiceProvider = Provider((ref) => CustomerExportService(
  ref.watch(customersRepositoryProvider),
  ref.watch(projectsRepositoryProvider),
));
