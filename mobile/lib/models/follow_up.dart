import '../core/formatters.dart';
import 'enums.dart';

class FollowUp {
  const FollowUp({
    required this.uuid,
    required this.contactUuid,
    this.userId,
    this.userName,
    required this.actionType,
    this.description,
    this.result,
    this.scheduledAt,
    this.completedAt,
    this.syncState = SyncState.pending,
    required this.createdAt,
    this.contactName,
    this.contactPhone,
  });

  final String uuid;
  final String contactUuid;
  final int? userId;
  final String? userName;
  final FollowUpActionType actionType;
  final String? description;
  final FollowUpResult? result;
  final DateTime? scheduledAt;
  final DateTime? completedAt;
  final SyncState syncState;
  final DateTime createdAt;

  // Renseignés par jointure pour l'écran « Suivi ».
  final String? contactName;
  final String? contactPhone;

  bool get isDone => completedAt != null;
  bool get isOverdue => !isDone && scheduledAt != null && scheduledAt!.isBefore(startOfDay(DateTime.now()));

  factory FollowUp.fromDb(Map<String, Object?> r) => FollowUp(
    uuid: r['uuid'] as String,
    contactUuid: r['contact_uuid'] as String,
    userId: r['user_id'] as int?,
    userName: r['user_name'] as String?,
    actionType: FollowUpActionType.from(r['action_type']),
    description: r['description'] as String?,
    result: FollowUpResult.from(r['result']),
    scheduledAt: dateFromDb(r['scheduled_at']),
    completedAt: dateFromDb(r['completed_at']),
    syncState: SyncState.from(r['sync_state']),
    createdAt: dateFromDb(r['created_at'])!,
    contactName: r['contact_name'] as String?,
    contactPhone: r['contact_phone'] as String?,
  );

  Map<String, Object?> toApi() => {
    'uuid': uuid,
    'contact_uuid': contactUuid,
    'action_type': actionType.value,
    'description': description,
    'result': result?.value,
    'scheduled_at': scheduledAt?.toUtc().toIso8601String(),
    'completed_at': completedAt?.toUtc().toIso8601String(),
  };

  factory FollowUp.fromApi(Map<String, dynamic> j) {
    DateTime? d(String k) => j[k] == null ? null : DateTime.parse(j[k] as String).toLocal();
    final user = j['user'] as Map<String, dynamic>?;
    return FollowUp(
      uuid: j['uuid'] as String,
      contactUuid: j['contact_uuid'] as String,
      userId: user?['id'] as int?,
      userName: user?['name'] as String?,
      actionType: FollowUpActionType.from(j['action_type']),
      description: j['description'] as String?,
      result: FollowUpResult.from(j['result']),
      scheduledAt: d('scheduled_at'),
      completedAt: d('completed_at'),
      syncState: SyncState.synced,
      createdAt: d('created_at') ?? DateTime.now(),
    );
  }

  Map<String, Object?> toDb() => {
    'uuid': uuid,
    'contact_uuid': contactUuid,
    'user_id': userId,
    'user_name': userName,
    'action_type': actionType.value,
    'description': description,
    'result': result?.value,
    'scheduled_at': scheduledAt == null ? null : dateToDb(scheduledAt!),
    'completed_at': completedAt == null ? null : dateToDb(completedAt!),
    'sync_state': syncState.value,
    'created_at': dateToDb(createdAt),
    'updated_at': dateToDb(DateTime.now()),
  };
}
