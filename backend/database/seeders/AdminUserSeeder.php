<?php

namespace Database\Seeders;

use App\Enums\RoleSlug;
use App\Models\Role;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Str;

/**
 * Crée le premier administrateur à partir du .env :
 *   ADMIN_USERNAME=admin
 *   ADMIN_PASSWORD=un-mot-de-passe-solide
 * Sans ADMIN_PASSWORD, un mot de passe aléatoire est affiché une seule fois.
 */
class AdminUserSeeder extends Seeder
{
    public function run(): void
    {
        $username = env('ADMIN_USERNAME', 'admin');

        if (User::where('username', $username)->exists()) {
            return;
        }

        $password = env('ADMIN_PASSWORD') ?: Str::password(16);

        $admin = User::create([
            'name' => env('ADMIN_NAME', 'Administrateur'),
            'username' => $username,
            'email' => env('ADMIN_EMAIL'),
            'password' => $password,
        ]);

        $admin->roles()->attach(Role::where('slug', RoleSlug::Administrateur->value)->value('id'));

        if (! env('ADMIN_PASSWORD')) {
            $this->command?->warn("Administrateur « {$username} » créé. Mot de passe : {$password}");
            $this->command?->warn('Notez-le maintenant, il ne sera plus affiché.');
        }
    }
}
