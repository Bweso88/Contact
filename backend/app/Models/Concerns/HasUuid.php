<?php

namespace App\Models\Concerns;

use Illuminate\Support\Str;

/**
 * Le mobile génère l'UUID hors connexion et l'envoie avec l'enregistrement.
 * Si rien n'est fourni (création depuis le serveur), on en génère un ici.
 * L'API expose l'UUID, jamais l'id auto-incrémenté.
 */
trait HasUuid
{
    public static function bootHasUuid(): void
    {
        static::creating(function ($model) {
            if (empty($model->uuid)) {
                $model->uuid = (string) Str::uuid();
            }
        });
    }

    public function getRouteKeyName(): string
    {
        return 'uuid';
    }
}
