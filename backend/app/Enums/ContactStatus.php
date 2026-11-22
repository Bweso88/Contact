<?php

namespace App\Enums;

/**
 * Parcours d'une personne, du premier contact à l'intégration.
 *
 * Stocké en VARCHAR (et non en ENUM MySQL) : ajouter un statut ne demande
 * qu'une ligne ici, sans migration ALTER TABLE.
 */
enum ContactStatus: string
{
    case Nouveau = 'nouveau';
    case AContacter = 'a_contacter';
    case Contacte = 'contacte';
    case Invite = 'invite';
    case PremiereVisite = 'premiere_visite';
    case EnAccompagnement = 'en_accompagnement';
    case Integre = 'integre';
    case EnPause = 'en_pause';
    case Injoignable = 'injoignable';
    case NePlusContacter = 'ne_plus_contacter';

    public function label(): string
    {
        return match ($this) {
            self::Nouveau => 'Nouveau',
            self::AContacter => 'À contacter',
            self::Contacte => 'Contacté',
            self::Invite => 'Invité',
            self::PremiereVisite => 'Première visite',
            self::EnAccompagnement => 'En accompagnement',
            self::Integre => 'Intégré',
            self::EnPause => 'En pause',
            self::Injoignable => 'Injoignable',
            self::NePlusContacter => 'Ne souhaite plus être contacté',
        };
    }

    /** Statuts pour lesquels aucune relance ne doit être proposée. */
    public function excludedFromReminders(): bool
    {
        return in_array($this, [self::Integre, self::EnPause, self::NePlusContacter], true);
    }

    /**
     * « Intégré » ne se pose jamais à la main : il découle d'une
     * intégration confirmée dans une église de maison (Integration::confirm).
     */
    public function isManuallyAssignable(): bool
    {
        return $this !== self::Integre;
    }

    /** @return list<string> */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
