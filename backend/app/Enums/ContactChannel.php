<?php

namespace App\Enums;

/** Moyen de contact préféré, et canal visé par un consentement. */
enum ContactChannel: string
{
    case Appel = 'appel';
    case Sms = 'sms';
    case Whatsapp = 'whatsapp';
    case Visite = 'visite';

    public function label(): string
    {
        return match ($this) {
            self::Appel => 'Appel',
            self::Sms => 'SMS',
            self::Whatsapp => 'WhatsApp',
            self::Visite => 'Visite',
        };
    }
}
