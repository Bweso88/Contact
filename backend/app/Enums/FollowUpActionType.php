<?php

namespace App\Enums;

enum FollowUpActionType: string
{
    case Appel = 'appel';
    case Sms = 'sms';
    case Whatsapp = 'whatsapp';
    case Visite = 'visite';
    case InvitationCulte = 'invitation_culte';
    case RendezVous = 'rendez_vous';
    case Note = 'note';

    public function label(): string
    {
        return match ($this) {
            self::Appel => 'Appel',
            self::Sms => 'SMS',
            self::Whatsapp => 'WhatsApp',
            self::Visite => 'Visite',
            self::InvitationCulte => 'Invitation au culte',
            self::RendezVous => 'Rendez-vous',
            self::Note => 'Note',
        };
    }

    /** Actions qui sollicitent la personne : interdites sans consentement. */
    public function requiresConsent(): bool
    {
        return $this !== self::Note;
    }
}
