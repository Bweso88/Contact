<?php

namespace App\Enums;

enum ContactEventType: string
{
    case PremiereRencontre = 'premiere_rencontre';
    case VisiteCulte = 'visite_culte';
    case Activite = 'activite';
    case RencontreCampagne = 'rencontre_campagne';
    case VisiteEgliseMaison = 'visite_eglise_maison';
    case VisiteDomicile = 'visite_domicile';
    /** Distinct de l'intégration : accepter Jésus-Christ n'intègre pas automatiquement. */
    case DecisionDeFoi = 'decision_de_foi';

    public function label(): string
    {
        return match ($this) {
            self::PremiereRencontre => 'Première rencontre',
            self::VisiteCulte => 'Visite au culte',
            self::Activite => 'Participation à une activité',
            self::RencontreCampagne => 'Rencontre pendant une campagne',
            self::VisiteEgliseMaison => 'Visite dans une église de maison',
            self::VisiteDomicile => 'Visite à domicile',
            self::DecisionDeFoi => 'Décision de foi',
        };
    }

    /** Événements qui comptent comme un « retour » au culte (indicateur « Personnes revenues »). */
    public function isChurchVisit(): bool
    {
        return $this === self::VisiteCulte;
    }
}
