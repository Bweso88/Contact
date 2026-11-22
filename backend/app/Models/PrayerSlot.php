<?php

namespace App\Models;

use App\Models\Concerns\HasUuid;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class PrayerSlot extends Model
{
    use HasUuid;

    /** On peut prendre la main un peu avant le début de son créneau. */
    public const EARLY_START_MINUTES = 10;

    protected $fillable = ['uuid', 'prayer_session_id', 'user_id', 'starts_at', 'ends_at'];

    protected function casts(): array
    {
        return [
            'starts_at' => 'datetime',
            'ends_at' => 'datetime',
        ];
    }

    public function session(): BelongsTo
    {
        return $this->belongsTo(PrayerSession::class, 'prayer_session_id');
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function turns(): HasMany
    {
        return $this->hasMany(PrayerTurn::class);
    }

    /** Fenêtre pendant laquelle le titulaire peut prendre la main. */
    public function isOpenAt(\DateTimeInterface $at): bool
    {
        return $at >= $this->starts_at->copy()->subMinutes(self::EARLY_START_MINUTES) && $at < $this->ends_at;
    }
}
