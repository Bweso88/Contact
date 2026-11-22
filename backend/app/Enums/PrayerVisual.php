<?php

namespace App\Enums;

/** Animation choisie par l'intercesseur pour son tour. */
enum PrayerVisual: string
{
    case Feu = 'feu';
    case Eau = 'eau';

    public function label(): string
    {
        return match ($this) {
            self::Feu => 'Feu',
            self::Eau => 'Eau',
        };
    }
}
