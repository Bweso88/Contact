<?php

namespace App\Enums;

enum RoleSlug: string
{
    case Administrateur = 'administrateur';
    case ResponsableEglise = 'responsable_eglise';
    case ResponsableEvangelisation = 'responsable_evangelisation';
    case ResponsableAccueil = 'responsable_accueil';
    case ResponsableSuivi = 'responsable_suivi';
    case Evangeliste = 'evangeliste';
    case AgentAccueil = 'agent_accueil';
    case ResponsablePriere = 'responsable_priere';
    case Intercesseur = 'intercesseur';

    public function label(): string
    {
        return match ($this) {
            self::Administrateur => 'Administrateur',
            self::ResponsableEglise => 'Responsable de l’église',
            self::ResponsableEvangelisation => 'Responsable évangélisation',
            self::ResponsableAccueil => 'Responsable accueil',
            self::ResponsableSuivi => 'Responsable suivi',
            self::Evangeliste => 'Évangéliste',
            self::AgentAccueil => 'Agent d’accueil',
            self::ResponsablePriere => 'Responsable prière',
            self::Intercesseur => 'Intercesseur / intercesseuse',
        };
    }
}
