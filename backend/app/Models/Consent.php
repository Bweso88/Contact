<?php

namespace App\Models;

use App\Enums\ContactChannel;
use App\Enums\ContactStatus;
use App\Enums\ConsentPurpose;
use App\Models\Concerns\Auditable;
use App\Models\Concerns\HasUuid;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Facades\DB;

class Consent extends Model
{
    use Auditable, HasFactory, HasUuid;

    protected $fillable = ['uuid', 'contact_id', 'purpose', 'channel', 'method', 'granted_at', 'collected_by', 'notes'];

    protected function casts(): array
    {
        return [
            'purpose' => ConsentPurpose::class,
            'channel' => ContactChannel::class,
            'granted_at' => 'datetime',
            'withdrawn_at' => 'datetime',
        ];
    }

    public function contact(): BelongsTo
    {
        return $this->belongsTo(Contact::class);
    }

    public function scopeActive(Builder $query): Builder
    {
        return $query->whereNull('withdrawn_at');
    }

    /**
     * Retrait du consentement. Retirer le consentement « suivi » exclut
     * immédiatement la personne de toutes les relances.
     */
    public function withdraw(User $by, ?string $notes = null): void
    {
        if ($this->withdrawn_at !== null) {
            return;
        }

        DB::transaction(function () use ($by, $notes) {
            $this->withdrawn_at = now();
            $this->withdrawn_recorded_by = $by->id;
            if ($notes) {
                $this->notes = $notes;
            }
            $this->save();

            if ($this->purpose === ConsentPurpose::Suivi) {
                $contact = $this->contact;
                $contact->changeStatus(ContactStatus::NePlusContacter, $by, 'Retrait du consentement');
                // changeStatus ne fait rien si le statut était déjà celui-là :
                // on garantit l'exclusion dans tous les cas.
                if (! $contact->do_not_contact) {
                    $contact->do_not_contact = true;
                    $contact->save();
                }
            }
        });
    }
}
