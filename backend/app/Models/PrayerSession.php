<?php

namespace App\Models;

use App\Models\Concerns\HasUuid;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Database\Eloquent\SoftDeletes;

class PrayerSession extends Model
{
    use HasUuid, SoftDeletes;

    protected $fillable = ['uuid', 'title', 'description', 'starts_at', 'ends_at', 'whatsapp_group_url', 'created_by'];

    protected function casts(): array
    {
        return [
            'starts_at' => 'datetime',
            'ends_at' => 'datetime',
        ];
    }

    public function creator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    public function slots(): HasMany
    {
        return $this->hasMany(PrayerSlot::class)->orderBy('starts_at');
    }

    public function turns(): HasMany
    {
        return $this->hasMany(PrayerTurn::class)->orderBy('started_at');
    }

    public function messages(): HasMany
    {
        return $this->hasMany(PrayerMessage::class)->latest('created_at');
    }

    /** Le tour en cours (celui dont la flamme brûle), s'il y en a un. */
    public function currentTurn(): HasOne
    {
        return $this->hasOne(PrayerTurn::class)->whereNull('ended_at');
    }

    /** Créneau dont l'horaire couvre l'instant donné. */
    public function slotAt(\DateTimeInterface $at): ?PrayerSlot
    {
        return $this->slots()->where('starts_at', '<=', $at)->where('ends_at', '>', $at)->first();
    }

    public function scopeUpcoming(Builder $q): Builder
    {
        return $q->where('ends_at', '>=', now()->subHours(12))->orderBy('starts_at');
    }
}
