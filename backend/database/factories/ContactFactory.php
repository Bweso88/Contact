<?php

namespace Database\Factories;

use App\Enums\AgeRange;
use App\Enums\ContactChannel;
use App\Enums\ContactSource;
use App\Enums\Gender;
use App\Models\Contact;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/** @extends Factory<Contact> */
class ContactFactory extends Factory
{
    private const QUARTIERS = [
        ['Mafouta', 'Djiri'], ['Mansimou', 'Madibou'], ['Kinsoundi', 'Makélékélé'],
        ['Moukondo', 'Moungali'], ['Massengo', 'Djiri'], ['Bacongo', 'Bacongo'],
    ];

    public function definition(): array
    {
        $gender = fake()->randomElement(Gender::cases());
        [$quartier, $arrondissement] = fake()->randomElement(self::QUARTIERS);

        return [
            'first_name' => fake('fr_FR')->firstName($gender === Gender::Homme ? 'male' : 'female'),
            'last_name' => fake('fr_FR')->lastName(),
            'phone' => fake()->boolean(90) ? '06'.fake()->unique()->numerify('#######') : null,
            'gender' => fake()->boolean(80) ? $gender : null,
            'age_range' => fake()->boolean(70) ? fake()->randomElement(AgeRange::cases()) : null,
            'neighborhood' => $quartier,
            'arrondissement' => $arrondissement,
            'source' => fake()->randomElement(ContactSource::cases()),
            'first_met_at' => fake()->dateTimeBetween('-3 months'),
            'created_by' => User::factory(),
            'wants_contact' => fake()->boolean(92),
            'preferred_channel' => fake()->randomElement(ContactChannel::cases()),
            'wants_service_invitation' => fake()->optional(0.6)->boolean(70),
        ];
    }
}
