<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        // Données indispensables, en production comme en développement.
        $this->call([
            RolePermissionSeeder::class,
            SettingsSeeder::class,
            AdminUserSeeder::class,
        ]);

        // Données fictives : jamais en production.
        if (app()->environment('local', 'testing')) {
            $this->call(DemoSeeder::class);
        }
    }
}
