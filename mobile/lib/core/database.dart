import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Base SQLite locale : copie de travail des contacts visibles par l'utilisateur,
/// plus la file d'attente des opérations à envoyer au serveur.
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  static const _version = 1;
  Database? _db;

  Future<Database> get db async => _db ??= await _open();

  Future<Database> _open() async {
    final path = p.join(await getDatabasesPath(), 'eglise_connect.db');
    return openDatabase(
      path,
      version: _version,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        final batch = db.batch();
        for (final sql in _schemaV1) {
          batch.execute(sql);
        }
        await batch.commit(noResult: true);
      },
      // Futures évolutions : if (oldVersion < 2) { ALTER TABLE … }
      onUpgrade: (db, oldVersion, newVersion) async {},
    );
  }

  /// Vide toutes les données (déconnexion).
  Future<void> wipe() async {
    final d = await db;
    await d.transaction((txn) async {
      for (final t in ['sync_queue', 'status_changes', 'contact_events', 'follow_ups', 'contacts', 'meta']) {
        await txn.delete(t);
      }
    });
  }

  static const _schemaV1 = <String>[
    '''
    CREATE TABLE contacts (
      uuid TEXT PRIMARY KEY,
      first_name TEXT NOT NULL,
      last_name TEXT NOT NULL,
      phone TEXT,
      phone_normalized TEXT,
      gender TEXT,
      age_range TEXT,
      neighborhood TEXT,
      arrondissement TEXT,
      address_hint TEXT,
      source TEXT NOT NULL,
      status TEXT NOT NULL,
      first_met_at TEXT NOT NULL,
      team_id INTEGER,
      team_name TEXT,
      assigned_user_id INTEGER,
      assigned_user_name TEXT,
      created_by_id INTEGER,
      created_by_name TEXT,
      wants_contact INTEGER NOT NULL DEFAULT 1,
      preferred_channel TEXT,
      do_not_contact INTEGER NOT NULL DEFAULT 0,
      wants_spiritual_support INTEGER,
      wants_service_invitation INTEGER,
      wants_house_church INTEGER,
      last_follow_up_at TEXT,
      version INTEGER NOT NULL DEFAULT 1,
      sync_state TEXT NOT NULL DEFAULT 'pending',
      server_payload TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )''',
    'CREATE INDEX idx_contacts_phone ON contacts(phone_normalized)',
    'CREATE INDEX idx_contacts_status ON contacts(status)',
    'CREATE INDEX idx_contacts_name ON contacts(last_name, first_name)',
    '''
    CREATE TABLE follow_ups (
      uuid TEXT PRIMARY KEY,
      contact_uuid TEXT NOT NULL REFERENCES contacts(uuid) ON DELETE CASCADE,
      user_id INTEGER,
      user_name TEXT,
      action_type TEXT NOT NULL,
      description TEXT,
      result TEXT,
      scheduled_at TEXT,
      completed_at TEXT,
      sync_state TEXT NOT NULL DEFAULT 'pending',
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )''',
    'CREATE INDEX idx_follow_ups_contact ON follow_ups(contact_uuid)',
    'CREATE INDEX idx_follow_ups_due ON follow_ups(completed_at, scheduled_at)',
    '''
    CREATE TABLE contact_events (
      uuid TEXT PRIMARY KEY,
      contact_uuid TEXT NOT NULL REFERENCES contacts(uuid) ON DELETE CASCADE,
      type TEXT NOT NULL,
      occurred_at TEXT NOT NULL,
      location TEXT,
      notes TEXT,
      recorded_by_name TEXT,
      sync_state TEXT NOT NULL DEFAULT 'pending',
      created_at TEXT NOT NULL
    )''',
    'CREATE INDEX idx_events_contact ON contact_events(contact_uuid, occurred_at)',
    '''
    CREATE TABLE status_changes (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      contact_uuid TEXT NOT NULL REFERENCES contacts(uuid) ON DELETE CASCADE,
      from_status TEXT,
      to_status TEXT NOT NULL,
      reason TEXT,
      changed_by_name TEXT,
      changed_at TEXT NOT NULL
    )''',
    'CREATE INDEX idx_status_changes_contact ON status_changes(contact_uuid, changed_at)',
    // File d'attente : chaque écriture locale y ajoute une opération, envoyée
    // dans l'ordre à /api/sync puis supprimée après confirmation du serveur.
    '''
    CREATE TABLE sync_queue (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      entity TEXT NOT NULL,
      entity_uuid TEXT NOT NULL,
      operation TEXT NOT NULL,
      payload TEXT NOT NULL,
      base_version INTEGER,
      attempts INTEGER NOT NULL DEFAULT 0,
      last_error TEXT,
      created_at TEXT NOT NULL
    )''',
    '''
    CREATE TABLE meta (
      key TEXT PRIMARY KEY,
      value TEXT
    )''',
  ];
}

final databaseProvider = Provider<AppDatabase>((ref) => AppDatabase.instance);

/// Compteur incrémenté après chaque écriture ou synchronisation :
/// les écrans qui le surveillent se rechargent automatiquement.
class DataRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final dataRevisionProvider = NotifierProvider<DataRevision, int>(DataRevision.new);
