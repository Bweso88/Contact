import 'config.dart';

/// Même règle que App\Support\PhoneNumber côté Laravel :
/// « 06 123 45 67 », « +242 061234567 », « 00242061234567 » → 242061234567.
/// La détection des doublons fonctionne ainsi même hors connexion.
String? normalizePhone(String? raw, {String countryCode = AppConfig.defaultCountryCode}) {
  if (raw == null || raw.trim().isEmpty) return null;

  var digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('00')) digits = digits.substring(2);
  if (!digits.startsWith(countryCode) && digits.length <= 10) {
    digits = '$countryCode$digits';
  }
  if (digits.length < 8) return null;
  return digits.length > 20 ? digits.substring(0, 20) : digits;
}

/// Numéro au format international pour WhatsApp (wa.me attend les chiffres seuls).
String? whatsappNumber(String? raw) => normalizePhone(raw);
