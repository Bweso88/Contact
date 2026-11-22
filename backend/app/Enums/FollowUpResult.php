<?php

namespace App\Enums;

enum FollowUpResult: string
{
    case Joint = 'joint';
    case NonJoint = 'non_joint';
    case ARappeler = 'a_rappeler';
    case Interesse = 'interesse';
    case PasInteresse = 'pas_interesse';
    case RefusContact = 'refus_contact';
    case Effectue = 'effectue';

    public function label(): string
    {
        return match ($this) {
            self::Joint => 'Joint',
            self::NonJoint => 'Non joint',
            self::ARappeler => 'À rappeler',
            self::Interesse => 'Intéressé',
            self::PasInteresse => 'Pas intéressé',
            self::RefusContact => 'Refuse d’être recontacté',
            self::Effectue => 'Effectué',
        };
    }
}
