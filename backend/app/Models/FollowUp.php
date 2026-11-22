<?php

namespace App\Models;

use App\Enums\FollowUpActionType;
use App\Enums\FollowUpResult;
use App\Models\Concerns\Auditable;
use App\Models\Concerns\HasUuid;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\SoftDeletes;

class FollowUp extends Model
{
    use Auditable, HasFactory, HasUuid, SoftDeletes;

    protected $fillable = [
        'uuid', 'contact_id', 'user_id', 'action_type', 'description',
        'result', 'scheduled_at', 'completed_at',
    ];

    protected function casts(): array
    {
        return [
            'action_type' => FollowUpActionType::class,
            'result' => FollowUpResult::class,
            'scheduled_at' => 'datetime',
            'completed_at' => 'datetime',
        ];
    }

    protected static function booted(): void
    {
        // Tient à jour contacts.last_follow_up_at quand une action est réalisée.
        static::saved(function (FollowUp $f) {
            if ($f->completed_at && ($f->wasRecentlyCreated || $f->wasChanged('completed_at'))) {
                Contact::query()
                    ->whereKey($f->contact_id)
                    ->where(fn (Builder $q) => $q->whereNull('last_follow_up_at')->orWhere('last_follow_up_at', '<', $f->completed_at))
                    ->update(['last_follow_up_at' => $f->completed_at]);
            }
        });
    }

    public function contact(): BelongsTo
    {
        return $this->belongsTo(Contact::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /** Actions programmées non réalisées, à faire au plus tard à la date donnée. */
    public function scopeDueBy(Builder $query, \DateTimeInterface $date): Builder
    {
        return $query->whereNull('completed_at')->whereNotNull('scheduled_at')->where('scheduled_at', '<=', $date);
    }

    /**
     * Un évangéliste ne modifie pas librement le suivi d'un autre :
     * seul l'auteur, ou un titulaire de follow_ups.update_all, peut modifier.
     */
    public function isEditableBy(User $user): bool
    {
        return $this->user_id === $user->id
            ? $user->hasPermission('follow_ups.update_own') || $user->hasPermission('follow_ups.update_all')
            : $user->isAdmin() || $user->hasPermission('follow_ups.update_all');
    }
}
