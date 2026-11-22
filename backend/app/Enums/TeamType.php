<?php

namespace App\Enums;

enum TeamType: string
{
    case Evangelisation = 'evangelisation';
    case Accueil = 'accueil';
    case Suivi = 'suivi';
    case Autre = 'autre';

    public function label(): string
    {
        return match ($this) {
            self::Evangelisation => 'Évangélisation',
            self::Accueil => 'Accueil',
            self::Suivi => 'Suivi',
            self::Autre => 'Autre',
        };
    }
}
