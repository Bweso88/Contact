<?php

namespace App\Enums;

enum ContactSource: string
{
    case Evangelisation = 'evangelisation';
    case Accueil = 'accueil';
    case InvitationMembre = 'invitation_membre';
    case AutreActivite = 'autre_activite';

    public function label(): string
    {
        return match ($this) {
            self::Evangelisation => 'Évangélisation',
            self::Accueil => 'Accueil',
            self::InvitationMembre => 'Invitation par un membre',
            self::AutreActivite => 'Autre activité de l’église',
        };
    }
}
