import '../core/formatters.dart';
import 'enums.dart';

/// Dossier d'une personne. L'identifiant est l'UUID généré sur le téléphone.
class Contact {
  const Contact({
    required this.uuid,
    required this.firstName,
    required this.lastName,
    this.phone,
    this.phoneNormalized,
    this.gender,
    this.ageRange,
    this.neighborhood,
    this.arrondissement,
    this.addressHint,
    required this.source,
    required this.status,
    required this.firstMetAt,
    this.teamId,
    this.teamName,
    this.assignedUserId,
    this.assignedUserName,
    this.createdById,
    this.createdByName,
    this.wantsContact = true,
    this.preferredChannel,
    this.doNotContact = false,
    this.wantsSpiritualSupport,
    this.wantsServiceInvitation,
    this.wantsHouseChurch,
    this.lastFollowUpAt,
    this.version = 1,
    this.syncState = SyncState.pending,
    this.serverPayload,
    required this.createdAt,
    required this.updatedAt,
  });

  final String uuid;
  final String firstName;
  final String lastName;
  final String? phone;
  final String? phoneNormalized;
  final Gender? gender;
  final AgeRange? ageRange;
  final String? neighborhood;
  final String? arrondissement;
  final String? addressHint;
  final ContactSource source;
  final ContactStatus status;
  final DateTime firstMetAt;
  final int? teamId;
  final String? teamName;
  final int? assignedUserId;
  final String? assignedUserName;
  final int? createdById;
  final String? createdByName;
  final bool wantsContact;
  final ContactChannel? preferredChannel;
  final bool doNotContact;
  final bool? wantsSpiritualSupport;
  final bool? wantsServiceInvitation;
  final bool? wantsHouseChurch;
  final DateTime? lastFollowUpAt;
  final int version;
  final SyncState syncState;

  /// Version du serveur conservée en cas de conflit (JSON brut).
  final String? serverPayload;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get fullName => '$firstName $lastName'.trim();

  String get initials {
    final f = firstName.isNotEmpty ? firstName[0] : '';
    final l = lastName.isNotEmpty ? lastName[0] : '';
    return (f + l).toUpperCase();
  }

  /// Peut-on solliciter cette personne (appel, SMS, WhatsApp) ?
  bool get canBeContacted => !doNotContact && status != ContactStatus.nePlusContacter;

  // ── SQLite ────────────────────────────────────────────────

  factory Contact.fromDb(Map<String, Object?> r) => Contact(
    uuid: r['uuid'] as String,
    firstName: r['first_name'] as String,
    lastName: r['last_name'] as String,
    phone: r['phone'] as String?,
    phoneNormalized: r['phone_normalized'] as String?,
    gender: Gender.from(r['gender']),
    ageRange: AgeRange.from(r['age_range']),
    neighborhood: r['neighborhood'] as String?,
    arrondissement: r['arrondissement'] as String?,
    addressHint: r['address_hint'] as String?,
    source: ContactSource.from(r['source']),
    status: ContactStatus.from(r['status']),
    firstMetAt: dateFromDb(r['first_met_at'])!,
    teamId: r['team_id'] as int?,
    teamName: r['team_name'] as String?,
    assignedUserId: r['assigned_user_id'] as int?,
    assignedUserName: r['assigned_user_name'] as String?,
    createdById: r['created_by_id'] as int?,
    createdByName: r['created_by_name'] as String?,
    wantsContact: boolFromDb(r['wants_contact']) ?? true,
    preferredChannel: ContactChannel.from(r['preferred_channel']),
    doNotContact: boolFromDb(r['do_not_contact']) ?? false,
    wantsSpiritualSupport: boolFromDb(r['wants_spiritual_support']),
    wantsServiceInvitation: boolFromDb(r['wants_service_invitation']),
    wantsHouseChurch: boolFromDb(r['wants_house_church']),
    lastFollowUpAt: dateFromDb(r['last_follow_up_at']),
    version: (r['version'] as int?) ?? 1,
    syncState: SyncState.from(r['sync_state']),
    serverPayload: r['server_payload'] as String?,
    createdAt: dateFromDb(r['created_at'])!,
    updatedAt: dateFromDb(r['updated_at'])!,
  );

  Map<String, Object?> toDb() => {
    'uuid': uuid,
    'first_name': firstName,
    'last_name': lastName,
    'phone': phone,
    'phone_normalized': phoneNormalized,
    'gender': gender?.value,
    'age_range': ageRange?.value,
    'neighborhood': neighborhood,
    'arrondissement': arrondissement,
    'address_hint': addressHint,
    'source': source.value,
    'status': status.value,
    'first_met_at': dateToDb(firstMetAt),
    'team_id': teamId,
    'team_name': teamName,
    'assigned_user_id': assignedUserId,
    'assigned_user_name': assignedUserName,
    'created_by_id': createdById,
    'created_by_name': createdByName,
    'wants_contact': boolToDb(wantsContact),
    'preferred_channel': preferredChannel?.value,
    'do_not_contact': boolToDb(doNotContact),
    'wants_spiritual_support': boolToDb(wantsSpiritualSupport),
    'wants_service_invitation': boolToDb(wantsServiceInvitation),
    'wants_house_church': boolToDb(wantsHouseChurch),
    'last_follow_up_at': lastFollowUpAt == null ? null : dateToDb(lastFollowUpAt!),
    'version': version,
    'sync_state': syncState.value,
    'server_payload': serverPayload,
    'created_at': dateToDb(createdAt),
    'updated_at': dateToDb(updatedAt),
  };

  // ── API Laravel ───────────────────────────────────────────

  /// Champs modifiables envoyés au serveur (statut exclu : il a son opération dédiée).
  Map<String, Object?> toApi() => {
    'uuid': uuid,
    'first_name': firstName,
    'last_name': lastName,
    'phone': phone,
    'gender': gender?.value,
    'age_range': ageRange?.value,
    'neighborhood': neighborhood,
    'arrondissement': arrondissement,
    'address_hint': addressHint,
    'source': source.value,
    'first_met_at': toApiDate(firstMetAt),
    'team_id': teamId,
    'wants_contact': wantsContact,
    'preferred_channel': preferredChannel?.value,
    'wants_spiritual_support': wantsSpiritualSupport,
    'wants_service_invitation': wantsServiceInvitation,
    'wants_house_church': wantsHouseChurch,
  };

  /// Contact reçu du serveur (ContactResource Laravel).
  factory Contact.fromApi(Map<String, dynamic> j) {
    DateTime? d(String k) => j[k] == null ? null : DateTime.parse(j[k] as String).toLocal();
    final team = j['team'] as Map<String, dynamic>?;
    final assigned = j['assigned_user'] as Map<String, dynamic>?;
    final creator = j['created_by'] as Map<String, dynamic>?;
    return Contact(
      uuid: j['uuid'] as String,
      firstName: j['first_name'] as String,
      lastName: j['last_name'] as String,
      phone: j['phone'] as String?,
      phoneNormalized: j['phone_normalized'] as String?,
      gender: Gender.from(j['gender']),
      ageRange: AgeRange.from(j['age_range']),
      neighborhood: j['neighborhood'] as String?,
      arrondissement: j['arrondissement'] as String?,
      addressHint: j['address_hint'] as String?,
      source: ContactSource.from(j['source']),
      status: ContactStatus.from(j['status']),
      firstMetAt: d('first_met_at') ?? DateTime.now(),
      teamId: team?['id'] as int?,
      teamName: team?['name'] as String?,
      assignedUserId: assigned?['id'] as int?,
      assignedUserName: assigned?['name'] as String?,
      createdById: creator?['id'] as int?,
      createdByName: creator?['name'] as String?,
      wantsContact: (j['wants_contact'] as bool?) ?? true,
      preferredChannel: ContactChannel.from(j['preferred_channel']),
      doNotContact: (j['do_not_contact'] as bool?) ?? false,
      wantsSpiritualSupport: j['wants_spiritual_support'] as bool?,
      wantsServiceInvitation: j['wants_service_invitation'] as bool?,
      wantsHouseChurch: j['wants_house_church'] as bool?,
      lastFollowUpAt: d('last_follow_up_at'),
      version: (j['version'] as int?) ?? 1,
      syncState: SyncState.synced,
      createdAt: d('created_at') ?? DateTime.now(),
      updatedAt: d('updated_at') ?? DateTime.now(),
    );
  }

  Contact copyWith({
    ContactStatus? status,
    bool? doNotContact,
    int? version,
    SyncState? syncState,
    String? serverPayload,
    bool clearServerPayload = false,
    DateTime? lastFollowUpAt,
    DateTime? updatedAt,
  }) => Contact(
    uuid: uuid,
    firstName: firstName,
    lastName: lastName,
    phone: phone,
    phoneNormalized: phoneNormalized,
    gender: gender,
    ageRange: ageRange,
    neighborhood: neighborhood,
    arrondissement: arrondissement,
    addressHint: addressHint,
    source: source,
    status: status ?? this.status,
    firstMetAt: firstMetAt,
    teamId: teamId,
    teamName: teamName,
    assignedUserId: assignedUserId,
    assignedUserName: assignedUserName,
    createdById: createdById,
    createdByName: createdByName,
    wantsContact: wantsContact,
    preferredChannel: preferredChannel,
    doNotContact: doNotContact ?? this.doNotContact,
    wantsSpiritualSupport: wantsSpiritualSupport,
    wantsServiceInvitation: wantsServiceInvitation,
    wantsHouseChurch: wantsHouseChurch,
    lastFollowUpAt: lastFollowUpAt ?? this.lastFollowUpAt,
    version: version ?? this.version,
    syncState: syncState ?? this.syncState,
    serverPayload: clearServerPayload ? null : (serverPayload ?? this.serverPayload),
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

/// Données saisies dans le formulaire d'enregistrement.
class ContactDraft {
  String firstName = '';
  String lastName = '';
  String phone = '';
  Gender? gender;
  AgeRange? ageRange;
  String neighborhood = '';
  String arrondissement = '';
  String addressHint = '';
  ContactSource source = ContactSource.evangelisation;
  DateTime firstMetAt = DateTime.now();
  int? teamId;
  String? teamName;
  bool wantsContact = true;
  ContactChannel? preferredChannel;
  bool? wantsSpiritualSupport;
  bool? wantsServiceInvitation;
  bool? wantsHouseChurch;
  String notes = '';
}
