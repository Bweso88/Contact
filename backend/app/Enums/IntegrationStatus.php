<?php

namespace App\Enums;

enum IntegrationStatus: string
{
    case Proposee = 'proposee';
    case Confirmee = 'confirmee';
    case Annulee = 'annulee';
    case Terminee = 'terminee';

    public function label(): string
    {
        return match ($this) {
            self::Proposee => 'Proposée',
            self::Confirmee => 'Confirmée',
            self::Annulee => 'Annulée',
            self::Terminee => 'Terminée',
        };
    }
}
