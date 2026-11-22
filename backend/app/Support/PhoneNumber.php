<?php

namespace App\Support;

/**
 * Normalise un numéro pour détecter les doublons, quelle que soit la façon
 * dont il a été saisi : « 06 123 45 67 », « +242 06 123 4567 », « 00242061234567 »
 * donnent tous 242061234567.
 *
 * L'indicatif par défaut vient du réglage `phone.default_country_code`.
 */
final class PhoneNumber
{
    public static function normalize(?string $raw, string $defaultCountryCode = '242'): ?string
    {
        if ($raw === null || trim($raw) === '') {
            return null;
        }

        $digits = preg_replace('/\D+/', '', $raw);

        if (str_starts_with($digits, '00')) {
            $digits = substr($digits, 2);
        }

        // Numéro local (ex. Congo : 9 chiffres commençant par 0) → on ajoute l'indicatif.
        if (! str_starts_with($digits, $defaultCountryCode) && strlen($digits) <= 10) {
            $digits = $defaultCountryCode.$digits;
        }

        return strlen($digits) >= 8 ? substr($digits, 0, 20) : null;
    }
}
