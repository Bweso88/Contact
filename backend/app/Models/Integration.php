<?php

namespace App\Models;

use App\Enums\ContactStatus;
use App\Enums\IntegrationStatus;
use App\Models\Concerns\Auditable;
use App\Models\Concerns\HasUuid;
use DomainException;
use Illuminate\Auth\Access\AuthorizationException;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Facades\DB;

class Integration extends Model
{
    use Auditable, HasFactory, HasUuid;

    protected $fillable = ['uuid', 'contact_id', 'house_church_id', 'proposed_by', 'proposed_at', 'notes'];

    protected function casts(): array
    {
        return [
            'status' => IntegrationStatus::class,
            'proposed_at' => 'datetime',
            'confirmed_at' => 'datetime',
            'ended_at' => 'datetime',
        ];
    }

    protected static function booted(): void
    {
        static::creating(function (Integration $i) {
            $i->status ??= IntegrationStatus::Proposee;
            $i->proposed_at ??= now();
        });
    }

    public function contact(): BelongsTo
    {
        return $this->belongsTo(Contact::class);
    }

    public function houseChurch(): BelongsTo
    {
        return $this->belongsTo(HouseChurch::class);
    }

    public function proposer(): BelongsTo
    {
        return $this->belongsTo(User::class, 'proposed_by');
    }

    public function confirmer(): BelongsTo
    {
        return $this->belongsTo(User::class, 'confirmed_by');
    }

    /**
     * Confirme l'affectation : seul moment où un contact devient « Intégré ».
     * Une éventuelle affectation confirmée précédente est clôturée.
     */
    public function confirm(User $by): void
    {
        if (! $by->isAdmin() && ! $by->hasPermission('integrations.confirm')) {
            throw new AuthorizationException('Seul un responsable habilité peut confirmer une intégration.');
        }

        if ($this->status !== IntegrationStatus::Proposee) {
            throw new DomainException('Seule une intégration proposée peut être confirmée.');
        }

        DB::transaction(function () use ($by) {
            static::query()
                ->where('contact_id', $this->contact_id)
                ->where('status', IntegrationStatus::Confirmee->value)
                ->update(['status' => IntegrationStatus::Terminee->value, 'ended_at' => now()]);

            $this->status = IntegrationStatus::Confirmee;
            $this->confirmed_by = $by->id;
            $this->confirmed_at = now();
            $this->save();

            $this->contact->changeStatus(
                ContactStatus::Integre,
                $by,
                'Intégration confirmée : '.$this->houseChurch->name,
                viaIntegration: true,
            );
        });
    }
}
