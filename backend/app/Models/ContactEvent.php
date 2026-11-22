<?php

namespace App\Models;

use App\Enums\ContactEventType;
use App\Models\Concerns\Auditable;
use App\Models\Concerns\HasUuid;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\SoftDeletes;

class ContactEvent extends Model
{
    use Auditable, HasFactory, HasUuid, SoftDeletes;

    protected $fillable = [
        'uuid', 'contact_id', 'type', 'occurred_at', 'location',
        'team_id', 'house_church_id', 'recorded_by', 'notes',
    ];

    protected function casts(): array
    {
        return [
            'type' => ContactEventType::class,
            'occurred_at' => 'datetime',
        ];
    }

    public function contact(): BelongsTo
    {
        return $this->belongsTo(Contact::class);
    }

    public function team(): BelongsTo
    {
        return $this->belongsTo(Team::class);
    }

    public function houseChurch(): BelongsTo
    {
        return $this->belongsTo(HouseChurch::class);
    }

    public function recorder(): BelongsTo
    {
        return $this->belongsTo(User::class, 'recorded_by');
    }
}
