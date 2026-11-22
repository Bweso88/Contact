<?php

namespace Database\Seeders;

use App\Enums\FollowUpAssignmentMode;
use App\Models\Setting;
use Illuminate\Database\Seeder;

/**
 * Valeurs par défaut des quatre décisions du cahier des charges.
 * firstOrCreate : un réglage déjà modifié par l'église n'est jamais écrasé.
 */
class SettingsSeeder extends Seeder
{
    public function run(): void
    {
        $defaults = [
            // Décision 1 : identité configurable
            'church.name' => env('CHURCH_NAME', 'Mon église'),
            'church.short_name' => env('CHURCH_SHORT_NAME', 'Église Connect'),
            'church.logo_path' => null,
            'church.primary_color' => '#1F4E79',

            // Décision 3 : affectation du suivi
            'follow_up.assignment_mode' => FollowUpAssignmentMode::TeamLeader->value,
            'follow_up.reminder_after_days' => 7,          // « sans suivi depuis X jours »
            'follow_up.unreachable_after_attempts' => 3,  // proposition du statut « Injoignable »

            // Décision 4 : langue
            'app.locale' => 'fr',
            'app.available_locales' => ['fr'],

            // Divers
            'phone.default_country_code' => '242',
            'data.retention_months_inactive' => 24,
        ];

        foreach ($defaults as $key => $value) {
            Setting::query()->firstOrCreate(['key' => $key], ['value' => $value]);
        }

        cache()->forget('settings');
    }
}
