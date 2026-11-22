import 'dart:io';

import 'package:excel/excel.dart' as xl;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'formatters.dart';

/// Une feuille du classeur : en-têtes + lignes.
class ExportSheet {
  const ExportSheet(this.name, this.headers, this.rows);

  final String name;
  final List<String> headers;
  final List<List<Object?>> rows;
}

/// Crée un fichier Excel (.xlsx) et ouvre le partage du téléphone
/// (WhatsApp, e-mail, Google Drive, enregistrer dans Fichiers…).
///
/// Les exports contiennent des données personnelles : ils sont réservés
/// aux rôles qui en ont la permission (voir les écrans appelants).
abstract final class ExcelExport {
  static Future<void> share(BuildContext context, {required String fileName, required List<ExportSheet> sheets}) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final excel = xl.Excel.createExcel();
      final defaultSheet = excel.getDefaultSheet();

      for (final (i, s) in sheets.indexed) {
        final name = _sheetName(s.name);
        if (i == 0 && defaultSheet != null) excel.rename(defaultSheet, name);
        final sheet = excel[name];

        sheet.appendRow([for (final h in s.headers) xl.TextCellValue(h)]);
        for (var c = 0; c < s.headers.length; c++) {
          sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0)).cellStyle = xl.CellStyle(
            bold: true,
            backgroundColorHex: xl.ExcelColor.fromHexString('#F3EFEA'),
          );
          sheet.setColumnWidth(c, 22);
        }
        for (final row in s.rows) {
          sheet.appendRow([for (final v in row) _cell(v)]);
        }
      }

      final bytes = excel.save();
      if (bytes == null) throw StateError('Classeur vide');

      final stamp = DateTime.now();
      final safe = fileName.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${safe}_${toApiDate(stamp)}_${stamp.hour}h${stamp.minute.toString().padLeft(2, '0')}.xlsx');
      await file.writeAsBytes(bytes, flush: true);

      await Share.shareXFiles([
        XFile(file.path, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'),
      ], subject: fileName);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Export impossible : $e')));
    }
  }

  static xl.CellValue? _cell(Object? v) => switch (v) {
    null => null,
    int n => xl.IntCellValue(n),
    double d => xl.DoubleCellValue(d),
    bool b => xl.TextCellValue(b ? 'Oui' : 'Non'),
    DateTime d => xl.TextCellValue(formatDateTime(d)),
    _ => xl.TextCellValue(v.toString()),
  };

  /// Excel limite les noms de feuilles à 31 caractères, sans certains symboles.
  static String _sheetName(String n) {
    final clean = n.replaceAll(RegExp(r'[\\/*?:\[\]]'), ' ');
    return clean.length > 31 ? clean.substring(0, 31) : clean;
  }
}

/// Bouton « Exporter en Excel » pour les barres d'outils.
class ExportButton extends StatelessWidget {
  const ExportButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) =>
      IconButton(tooltip: 'Exporter en Excel', icon: const Icon(Icons.file_download_outlined), onPressed: onPressed);
}
