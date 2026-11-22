import 'package:flutter/material.dart';

/// Élément de l'historique d'une fiche : rencontre, suivi ou changement de statut.
class TimelineItem {
  const TimelineItem({
    required this.date,
    required this.icon,
    required this.title,
    this.subtitle,
    this.author,
    this.pendingSync = false,
  });

  final DateTime date;
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? author;
  final bool pendingSync;
}
