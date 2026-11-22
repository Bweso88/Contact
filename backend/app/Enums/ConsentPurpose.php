<?php

namespace App\Enums;

enum ConsentPurpose: string
{
    /** Accepte d'être recontacté (appel, SMS, WhatsApp, visite). */
    case Suivi = 'suivi';
    case InvitationsCulte = 'invitations_culte';
    case AccompagnementSpirituel = 'accompagnement_spirituel';
    case EgliseDeMaison = 'eglise_de_maison';

    public function label(): string
    {
        return match ($this) {
            self::Suivi => 'Être recontacté',
            self::InvitationsCulte => 'Recevoir des invitations au culte',
            self::AccompagnementSpirituel => 'Être accompagné spirituellement',
            self::EgliseDeMaison => 'Découvrir une église de maison',
        };
    }
}
