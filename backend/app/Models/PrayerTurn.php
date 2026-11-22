<?php

namespace App\Models;

use App\Enums\PrayerVisual;
use App\Models\Concerns\HasUuid;
use DomainException;
use Illuminate\Auth\Access\AuthorizationException;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\QueryException;

/**
 * Un tour de prière : de « Je prends la main » à « Je rends la main ».
 */
class PrayerTurn extends Model
{
    use HasUuid;

    protected $fillable = ['uuid', 'prayer_session_id', 'prayer_slot_id', 'user_id', 'visual', 'started_at', 'ended_at', 'auto_ended'];

    protected function casts(): array
    {
        return [
            'visual' => PrayerVisual::class,
            'started_at' => 'datetime',
            'ended_at' => 'datetime',
            'auto_ended' => 'boolean',
        ];
    }

    public function session(): BelongsTo
    {
        return $this->belongsTo(PrayerSession::class, 'prayer_session_id');
    }

    public function slot(): BelongsTo
    {
        return $this->belongsTo(PrayerSlot::class, 'prayer_slot_id');
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function durationMinutes(): int
    {
        return (int) $this->started_at->diffInMinutes($this->ended_at ?? now());
    }

    /**
     * « Je prends la main ».
     * Règles : être intercesseur, être dans son créneau (sauf responsable),
     * et que personne d'autre ne tienne déjà la main.
     */
    public static function take(PrayerSession $session, User $user, PrayerVisual $visual): self
    {
        if (! $user->isAdmin() && ! $user->hasPermission('prayer.access')) {
            throw new AuthorizationException('Réservé aux intercesseurs et intercesseuses.');
        }

        $now = now();
        $slot = $session->slots()
            ->where('user_id', $user->id)
            ->where('starts_at', '<=', $now->copy()->addMinutes(PrayerSlot::EARLY_START_MINUTES))
            ->where('ends_at', '>', $now)
            ->first();

        $isManager = $user->isAdmin() || $user->hasPermission('prayer.manage');
        if ($slot === null && ! $isManager) {
            throw new DomainException('Ce n’est pas encore votre créneau de prière.');
        }

        // Le précédent a dépassé la fin de son créneau : son tour se clôt d'abord.
        $session->closeExpiredTurn();

        $current = $session->currentTurn()->first();
        if ($current !== null) {
            throw new DomainException(
                $current->user_id === $user->id
                    ? 'Vous tenez déjà la main.'
                    : $current->user->name.' prie en ce moment. Attendez que la main soit rendue.'
            );
        }

        try {
            return static::create([
                'prayer_session_id' => $session->id,
                'prayer_slot_id' => $slot?->id,
                'user_id' => $user->id,
                'visual' => $visual,
                'started_at' => $now,
            ]);
        } catch (QueryException $e) {
            // Deux personnes au même instant : l'index unique open_session_lock a tranché.
            throw new DomainException('Quelqu’un vient de prendre la main juste avant vous.', 0, $e);
        }
    }

    /** « Je rends la main ». Le responsable peut aussi clore un tour oublié. */
    public function release(User $by): void
    {
        if ($this->ended_at !== null) {
            return;
        }

        $isManager = $by->isAdmin() || $by->hasPermission('prayer.manage');
        if ($this->user_id !== $by->id && ! $isManager) {
            throw new AuthorizationException('Seule la personne qui prie peut rendre la main.');
        }

        $this->ended_at = now();
        $this->save();
    }
}
