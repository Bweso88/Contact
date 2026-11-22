import 'package:intl/intl.dart';

/// Les dates sont stockées en UTC (ISO-8601) et affichées en heure locale.
String dateToDb(DateTime d) => d.toUtc().toIso8601String();
DateTime? dateFromDb(Object? v) => v == null ? null : DateTime.parse(v as String).toLocal();

/// Date seule pour l'API Laravel (colonnes DATE).
String toApiDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

String formatDate(DateTime d) => DateFormat('d MMM y', 'fr').format(d);
String formatDateTime(DateTime d) => DateFormat('d MMM y à HH:mm', 'fr').format(d);
String formatTime(DateTime d) => DateFormat('HH:mm', 'fr').format(d);

String formatRelative(DateTime d) {
  final diff = DateTime.now().difference(d);
  if (diff.isNegative) {
    final ahead = d.difference(DateTime.now());
    if (ahead.inDays == 0) return "aujourd'hui à ${formatTime(d)}";
    if (ahead.inDays == 1) return 'demain';
    return 'dans ${ahead.inDays} j';
  }
  if (diff.inMinutes < 1) return "à l'instant";
  if (diff.inHours < 1) return 'il y a ${diff.inMinutes} min';
  if (diff.inDays < 1) return 'il y a ${diff.inHours} h';
  if (diff.inDays == 1) return 'hier';
  if (diff.inDays < 30) return 'il y a ${diff.inDays} j';
  return formatDate(d);
}

DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

/// Conversions booléen ↔ entier pour SQLite.
int? boolToDb(bool? b) => b == null ? null : (b ? 1 : 0);
bool? boolFromDb(Object? v) => v == null ? null : (v as int) == 1;
