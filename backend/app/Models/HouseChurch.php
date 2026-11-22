<?php

namespace App\Models;

use App\Enums\IntegrationStatus;
use App\Models\Concerns\Auditable;
use App\Models\Concerns\HasUuid;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

class HouseChurch extends Model
{
    use Auditable, HasFactory, HasUuid, SoftDeletes;

    protected $fillable = [
        'uuid', 'name', 'neighborhood', 'arrondissement', 'address_hint',
        'leader_id', 'meeting_day', 'meeting_time', 'capacity', 'is_active',
    ];

    protected function casts(): array
    {
        return [
            'meeting_day' => 'integer',
            'capacity' => 'integer',
            'is_active' => 'boolean',
        ];
    }

    public function leader(): BelongsTo
    {
        return $this->belongsTo(User::class, 'leader_id');
    }

    public function integrations(): HasMany
    {
        return $this->hasMany(Integration::class);
    }

    /** Personnes dont l'intégration est confirmée et toujours en cours. */
    public function members(): BelongsToMany
    {
        return $this->belongsToMany(Contact::class, 'integrations')
            ->wherePivot('status', IntegrationStatus::Confirmee->value)
            ->withPivot('confirmed_at');
    }
}
