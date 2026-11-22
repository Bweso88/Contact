import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'formatters.dart';

/// Opérations comprises par POST /api/sync (voir README).
abstract final class SyncOp {
  static const create = 'create';
  static const update = 'update';
  static const statusChange = 'status_change';
}

abstract final class SyncEntity {
  static const contact = 'contact';
  static const followUp = 'follow_up';
  static const event = 'contact_event';
}

/// Ajoute une opération à la file, dans la MÊME transaction que l'écriture locale :
/// soit les deux sont enregistrées, soit aucune. Rien ne peut être perdu.
Future<void> enqueue(
  DatabaseExecutor txn, {
  required String entity,
  required String uuid,
  required String operation,
  required Map<String, Object?> payload,
  int? baseVersion,
}) {
  return txn.insert('sync_queue', {
    'entity': entity,
    'entity_uuid': uuid,
    'operation': operation,
    'payload': jsonEncode(payload),
    'base_version': baseVersion,
    'created_at': dateToDb(DateTime.now()),
  });
}
