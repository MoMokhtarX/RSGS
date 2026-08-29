import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../data/quotations_repository.dart';

class QuotationPdfService {
  QuotationPdfService(
      this._repository,
      );

  final QuotationsRepository _repository;

  Future<File> saveQuotationPdf(
      int quotationId,
      ) async {
    final bytes =
    await _repository
        .downloadQuotationPdf(
      quotationId,
    );

    final directory =
    await getApplicationDocumentsDirectory();

    final quotationsDirectory =
    Directory(
      '${directory.path}\\Quotations',
    );

    if (!await quotationsDirectory
        .exists()) {
      await quotationsDirectory
          .create(
        recursive: true,
      );
    }

    final file = File(
      '${quotationsDirectory.path}'
          '\\Quotation-$quotationId.pdf',
    );

    await file.writeAsBytes(
      bytes,
      flush: true,
    );

    return file;
  }
}