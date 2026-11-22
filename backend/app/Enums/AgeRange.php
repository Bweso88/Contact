<?php

namespace App\Enums;

enum AgeRange: string
{
    case Moins18 = 'moins_18';
    case De18a25 = '18_25';
    case De26a35 = '26_35';
    case De36a50 = '36_50';
    case Plus50 = 'plus_50';

    public function label(): string
    {
        return match ($this) {
            self::Moins18 => 'Moins de 18 ans',
            self::De18a25 => '18 – 25 ans',
            self::De26a35 => '26 – 35 ans',
            self::De36a50 => '36 – 50 ans',
            self::Plus50 => 'Plus de 50 ans',
        };
    }
}
