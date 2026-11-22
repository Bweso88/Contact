/// Miroir exact des enums PHP de app/Enums (mêmes valeurs en base et dans l'API).
abstract interface class ApiEnum {
  String get value;
  String get label;
}

T enumFromValue<T extends ApiEnum>(List<T> values, Object? raw, T fallback) {
  for (final e in values) {
    if (e.value == raw) return e;
  }
  return fallback;
}

T? enumFromValueOrNull<T extends ApiEnum>(List<T> values, Object? raw) {
  if (raw == null) return null;
  for (final e in values) {
    if (e.value == raw) return e;
  }
  return null;
}

enum ContactStatus implements ApiEnum {
  nouveau('nouveau', 'Nouveau'),
  aContacter('a_contacter', 'À contacter'),
  contacte('contacte', 'Contacté'),
  invite('invite', 'Invité'),
  premiereVisite('premiere_visite', 'Première visite'),
  enAccompagnement('en_accompagnement', 'En accompagnement'),
  integre('integre', 'Intégré'),
  enPause('en_pause', 'En pause'),
  injoignable('injoignable', 'Injoignable'),
  nePlusContacter('ne_plus_contacter', 'Ne souhaite plus être contacté');

  const ContactStatus(this.value, this.label);
  @override
  final String value;
  @override
  final String label;

  static ContactStatus from(Object? v) => enumFromValue(values, v, nouveau);

  bool get excludedFromReminders => this == integre || this == enPause || this == nePlusContacter;

  /// « Intégré » découle d'une intégration confirmée, jamais d'un choix manuel.
  bool get manuallyAssignable => this != integre;
}

enum ContactSource implements ApiEnum {
  evangelisation('evangelisation', 'Évangélisation'),
  accueil('accueil', 'Accueil'),
  invitationMembre('invitation_membre', 'Invitation par un membre'),
  autreActivite('autre_activite', 'Autre activité');

  const ContactSource(this.value, this.label);
  @override
  final String value;
  @override
  final String label;

  static ContactSource from(Object? v) => enumFromValue(values, v, evangelisation);
}

enum ContactChannel implements ApiEnum {
  appel('appel', 'Appel'),
  sms('sms', 'SMS'),
  whatsapp('whatsapp', 'WhatsApp'),
  visite('visite', 'Visite');

  const ContactChannel(this.value, this.label);
  @override
  final String value;
  @override
  final String label;

  static ContactChannel? from(Object? v) => enumFromValueOrNull(values, v);
}

enum Gender implements ApiEnum {
  homme('homme', 'Homme'),
  femme('femme', 'Femme');

  const Gender(this.value, this.label);
  @override
  final String value;
  @override
  final String label;

  static Gender? from(Object? v) => enumFromValueOrNull(values, v);
}

enum AgeRange implements ApiEnum {
  moins18('moins_18', '-18'),
  de18a25('18_25', '18-25'),
  de26a35('26_35', '26-35'),
  de36a50('36_50', '36-50'),
  plus50('plus_50', '50+');

  const AgeRange(this.value, this.label);
  @override
  final String value;
  @override
  final String label;

  static AgeRange? from(Object? v) => enumFromValueOrNull(values, v);
}

enum ContactEventType implements ApiEnum {
  premiereRencontre('premiere_rencontre', 'Première rencontre'),
  visiteCulte('visite_culte', 'Visite au culte'),
  activite('activite', 'Participation à une activité'),
  rencontreCampagne('rencontre_campagne', 'Rencontre pendant une campagne'),
  visiteEgliseMaison('visite_eglise_maison', 'Visite en église de maison'),
  visiteDomicile('visite_domicile', 'Visite à domicile'),
  decisionDeFoi('decision_de_foi', 'Décision de foi');

  const ContactEventType(this.value, this.label);
  @override
  final String value;
  @override
  final String label;

  static ContactEventType from(Object? v) => enumFromValue(values, v, premiereRencontre);
}

enum FollowUpActionType implements ApiEnum {
  appel('appel', 'Appel'),
  sms('sms', 'SMS'),
  whatsapp('whatsapp', 'WhatsApp'),
  visite('visite', 'Visite'),
  invitationCulte('invitation_culte', 'Invitation au culte'),
  rendezVous('rendez_vous', 'Rendez-vous'),
  note('note', 'Note');

  const FollowUpActionType(this.value, this.label);
  @override
  final String value;
  @override
  final String label;

  static FollowUpActionType from(Object? v) => enumFromValue(values, v, note);

  bool get requiresConsent => this != note;
}

enum FollowUpResult implements ApiEnum {
  joint('joint', 'Joint'),
  nonJoint('non_joint', 'Non joint'),
  aRappeler('a_rappeler', 'À rappeler'),
  interesse('interesse', 'Intéressé'),
  pasInteresse('pas_interesse', 'Pas intéressé'),
  refusContact('refus_contact', 'Refuse d’être recontacté'),
  effectue('effectue', 'Effectué');

  const FollowUpResult(this.value, this.label);
  @override
  final String value;
  @override
  final String label;

  static FollowUpResult? from(Object? v) => enumFromValueOrNull(values, v);
}

/// État local d'un enregistrement vis-à-vis du serveur.
enum SyncState implements ApiEnum {
  pending('pending', 'En attente de synchronisation'),
  synced('synced', 'Synchronisé'),
  conflict('conflict', 'Conflit à résoudre');

  const SyncState(this.value, this.label);
  @override
  final String value;
  @override
  final String label;

  static SyncState from(Object? v) => enumFromValue(values, v, pending);
}
