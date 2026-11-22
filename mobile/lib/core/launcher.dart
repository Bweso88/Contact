import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'phone.dart';

/// Actions rapides de la fiche : appeler, SMS, WhatsApp.
abstract final class Launcher {
  static Future<void> call(BuildContext context, String phone) =>
      _open(context, Uri(scheme: 'tel', path: phone.replaceAll(' ', '')));

  static Future<void> sms(BuildContext context, String phone, {String? body}) =>
      _open(context, Uri(scheme: 'sms', path: phone.replaceAll(' ', ''), queryParameters: body == null ? null : {'body': body}));

  static Future<void> whatsapp(BuildContext context, String phone, {String? text}) {
    final number = whatsappNumber(phone) ?? phone;
    return _open(context, Uri.https('wa.me', '/$number', text == null ? null : {'text': text}));
  }

  static Future<void> _open(BuildContext context, Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Impossible d’ouvrir cette application sur ce téléphone.')));
    }
  }
}
