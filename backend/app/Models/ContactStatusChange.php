<?php

namespace App\Models;

use App\Enums\ContactStatus;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use LogicException;

/** Historique en ajout seul : toute modification ou suppression est bloquée. */
class ContactStatusChange extends Model
{
    public $timestamps = false;

    protected $fillable = ['contact_id', 'from_status', 'to_status', 'reason', 'changed_by', 'changed_at'];

    protected function casts(): array
    {
        return [
            'from_status' => ContactStatus::class,
            'to_status' => ContactStatus::class,
            'changed_at' => 'datetime',
        ];
    }

    protected static function booted(): void
    {
        static::updating(fn () => throw new LogicException('L’historique des statuts ne se modifie pas.'));
        static::deleting(fn () => throw new LogicException('L’historique des statuts ne se supprime pas.'));
    }

    public function contact(): BelongsTo
    {
        return $this->belongsTo(Contact::class);
    }

    public function author(): BelongsTo
    {
        return $this->belongsTo(User::class, 'changed_by');
    }
}
