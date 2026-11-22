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

    protected $fillable = ['uuid', 'title', 'description', 'starts_at', 'ends_at', 'end_warning_minutes', 'whatsapp_group_url', 'created_by'];

    protected function casts(): array
    {
        return [
            'starts_at' => 'datetime',
            'ends_at' => 'datetime',
            'end_warning_minutes' => 'integer',
        ];
    }

    /**
     * Clôt le tour dont le créneau est terminé : « il a fini de prier ».
     * Appelé avant chaque lecture de l'état en direct et avant chaque prise de main,
     * ce qui évite une tâche planifiée.
     */
    public function closeExpiredTurn(): ?PrayerTurn
    {
        $turn = $this->currentTurn()->with('slot')->first();
        if ($turn === null || $turn->slot === null || $turn->slot->ends_at->isFuture()) {
            return null;
        }

        $turn->ended_at = $turn->slot->ends_at;
        $turn->auto_ended = true;
        $turn->save();

        return $turn;
    }

    /** La main est libre alors qu'un créneau a commencé : il faut « prendre la main ». */
    public function isWaitingForHand(): bool
    {
        $slot = $this->slotAt(now());

        return $slot !== null && $this->currentTurn()->doesntExist();
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
