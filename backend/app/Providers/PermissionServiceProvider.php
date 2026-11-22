<?php

namespace App\Providers;

use App\Models\User;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\ServiceProvider;

/**
 * Branche les permissions de la base sur les Gates Laravel.
 * Partout dans le code on peut alors écrire :
 *   $user->can('contacts.create')
 *   Gate::authorize('integrations.confirm')
 *   Route::middleware('can:teams.manage')
 *
 * À déclarer dans bootstrap/providers.php.
 */
class PermissionServiceProvider extends ServiceProvider
{
    public function boot(): void
    {
        Gate::before(function (User $user, string $ability) {
            if (! $user->is_active) {
                return false;
            }

            if ($user->isAdmin()) {
                return true;
            }

            // Les permissions « à point » (contacts.create…) viennent de la base.
            // Pour le reste (policies de modèles), on laisse Laravel décider.
            if (str_contains($ability, '.')) {
                return $user->hasPermission($ability) ?: null;
            }

            return null;
        });
    }
}
