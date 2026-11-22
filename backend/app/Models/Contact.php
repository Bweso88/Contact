<?php

namespace App\Models;

use App\Enums\AgeRange;
use App\Enums\ContactChannel;
use App\Enums\ContactSource;
use App\Enums\ContactStatus;
use App\Enums\FollowUpAssignmentMode;
use App\Enums\Gender;
use App\Enums\IntegrationStatus;
use App\Models\Concerns\Auditable;
use App\Models\Concerns\HasUuid;
use App\Support\PhoneNumber;
use DomainException;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Casts\Attribute;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Support\Facades\DB;

class Contact extends Model
{
    use Auditable, HasFactory, HasUuid, SoftDeletes;

    protected $fillable = [
        'uuid', 'first_name', 'last_name', 'phone', 'gender', 'age_range',
        'neighborhood', 'arrondissement', 'address_hint',
        'source', 'first_met_at', 'team_id', 'assigned_user_id', 'invited_by_user_id', 'created_by',
        'wants_contact', 'preferred_channel',
        'wants_spiritual_support', 'wants_service_invitation', 'wants_house_church',
    ];

    // status, do_not_contact et version ne sont PAS remplissables en masse :
    // ils ne changent que via les méthodes métier ci-dessous.

    protected array $auditExclude = ['version', 'last_follow_up_at', 'phone_normalized'];

    protected function casts(): array
    {
        return [
            'gender' => Gender::class,
            'age_range' => AgeRange::class,
            'source' => ContactSource::class,
            'status' => ContactStatus::class,
            'preferred_channel' => ContactChannel::class,
            'first_met_at' => 'date',
            'status_changed_at' => 'datetime',
            'last_follow_up_at' => 'datetime',
            'wants_contact' => 'boolean',
            'do_not_contact' => 'boolean',
            'wants_spiritual_support' => 'boolean',
            'wants_service_invitation' => 'boolean',
            'wants_house_church' => 'boolean',
            'version' => 'integer',
        ];
    }

    protected static function booted(): void
    {
        static::creating(function (Contact $contact) {
            $contact->status ??= ContactStatus::Nouveau;
            $contact->status_changed_at ??= now();
            $contact->version ??= 1;
            $contact->assigned_user_id ??= $contact->resolveDefaultAssignee();
            if ($contact->wants_contact === false) {
                $contact->do_not_contact = true;
            }
        });

        // Statut initial dans l'historique, pour des statistiques complètes.
        static::created(function (Contact $contact) {
            $contact->statusChanges()->create([
                'from_status' => null,
                'to_status' => $contact->status->value,
                'reason' => 'Enregistrement',
                'changed_by' => $contact->created_by,
                'changed_at' => $contact->created_at,
            ]);
        });

        static::updating(function (Contact $contact) {
            $contact->version = ($contact->getOriginal('version') ?? 0) + 1;
        });
    }

    // ── Attributs ───────────────────────────────────────────────

    /** Remplit automatiquement phone_normalized à chaque saisie du numéro. */
    protected function phone(): Attribute
    {
        return Attribute::make(
            set: fn (?string $value) => [
                'phone' => $value ? trim($value) : null,
                'phone_normalized' => PhoneNumber::normalize(
                    $value,
                    (string) Setting::getValue('phone.default_country_code', '242')
                ),
            ],
        );
    }

    protected function fullName(): Attribute
    {
        return Attribute::get(fn () => trim("{$this->first_name} {$this->last_name}"));
    }

    // ── Relations ───────────────────────────────────────────────

    public function team(): BelongsTo
    {
        return $this->belongsTo(Team::class);
    }

    public function assignedUser(): BelongsTo
    {
        return $this->belongsTo(User::class, 'assigned_user_id');
    }

    public function creator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    public function invitedBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'invited_by_user_id');
    }

    public function events(): HasMany
    {
        return $this->hasMany(ContactEvent::class)->orderByDesc('occurred_at');
    }

    public function followUps(): HasMany
    {
        return $this->hasMany(FollowUp::class)->latest();
    }

    public function statusChanges(): HasMany
    {
        return $this->hasMany(ContactStatusChange::class)->orderByDesc('changed_at');
    }

    public function integrations(): HasMany
    {
        return $this->hasMany(Integration::class);
    }

    public function consents(): HasMany
    {
        return $this->hasMany(Consent::class);
    }

    // ── Scopes (filtres réutilisables) ──────────────────────────

    /**
     * Ce qu'un utilisateur a le droit de voir :
     *  - contacts.view_all  → tout
     *  - contacts.view_team → contacts de ses équipes + les siens
     *  - sinon              → ceux qu'il a enregistrés ou qui lui sont confiés
     */
    public function scopeVisibleTo(Builder $query, User $user): Builder
    {
        if ($user->isAdmin() || $user->hasPermission('contacts.view_all')) {
            return $query;
        }

        return $query->where(function (Builder $q) use ($user) {
            $q->where('created_by', $user->id)->orWhere('assigned_user_id', $user->id);

            if ($user->hasPermission('contacts.view_team') && $user->teamIds() !== []) {
                $q->orWhereIn('team_id', $user->teamIds());
            }
        });
    }

    /** Personnes qu'on a le droit de relancer. */
    public function scopeReachable(Builder $query): Builder
    {
        $excluded = array_map(
            fn (ContactStatus $s) => $s->value,
            array_filter(ContactStatus::cases(), fn (ContactStatus $s) => $s->excludedFromReminders())
        );

        return $query->where('do_not_contact', false)->whereNotIn('status', $excluded);
    }

    /** « Personnes sans suivi depuis plusieurs jours ». */
    public function scopeWithoutFollowUpSince(Builder $query, int $days): Builder
    {
        $limit = now()->subDays($days);

        return $query->where(fn (Builder $q) => $q
            ->where('last_follow_up_at', '<', $limit)
            ->orWhere(fn (Builder $q2) => $q2->whereNull('last_follow_up_at')->where('created_at', '<', $limit))
        );
    }

    /** Contacts existants avec le même numéro (vérification, pas rejet). */
    public function scopeSamePhoneAs(Builder $query, ?string $phone): Builder
    {
        $normalized = PhoneNumber::normalize($phone, (string) Setting::getValue('phone.default_country_code', '242'));

        return $normalized === null
            ? $query->whereRaw('1 = 0')
            : $query->where('phone_normalized', $normalized);
    }

    // ── Règles métier ───────────────────────────────────────────

    /**
     * Change le statut et l'historise (date, utilisateur, motif).
     * « Intégré » est refusé ici : il passe par Integration::confirm().
     */
    public function changeStatus(ContactStatus $to, User $by, ?string $reason = null, bool $viaIntegration = false): void
    {
        if ($to === ContactStatus::Integre && ! $viaIntegration) {
            throw new DomainException('Le statut « Intégré » découle d’une intégration confirmée dans une église de maison.');
        }

        if ($this->status === $to) {
            return;
        }

        DB::transaction(function () use ($to, $by, $reason) {
            $from = $this->status;

            $this->status = $to;
            $this->status_changed_at = now();
            if ($to === ContactStatus::NePlusContacter) {
                $this->do_not_contact = true;
            }
            $this->save();

            $this->statusChanges()->create([
                'from_status' => $from?->value,
                'to_status' => $to->value,
                'reason' => $reason,
                'changed_by' => $by->id,
                'changed_at' => $this->status_changed_at,
            ]);
        });
    }

    public function hasConfirmedIntegration(): bool
    {
        return $this->integrations()->where('status', IntegrationStatus::Confirmee->value)->exists();
    }

    /** Applique le réglage `follow_up.assignment_mode` (décision n°3). */
    protected function resolveDefaultAssignee(): ?int
    {
        $mode = FollowUpAssignmentMode::tryFrom(
            (string) Setting::getValue('follow_up.assignment_mode', FollowUpAssignmentMode::TeamLeader->value)
        ) ?? FollowUpAssignmentMode::TeamLeader;

        return match ($mode) {
            FollowUpAssignmentMode::Creator => $this->created_by,
            FollowUpAssignmentMode::TeamLeader => $this->team_id ? Team::query()->whereKey($this->team_id)->value('leader_id') : null,
            FollowUpAssignmentMode::CentralTeam => null,
        };
    }
}
