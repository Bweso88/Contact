<?php

namespace App\Models;

use App\Models\Concerns\HasUuid;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\SoftDeletes;

/** Message du mur de la session (sujets, encouragements). */
class PrayerMessage extends Model
{
    use HasUuid, SoftDeletes;

    public const UPDATED_AT = null;

    protected $fillable = ['uuid', 'prayer_session_id', 'user_id', 'body'];

    public function session(): BelongsTo
    {
        return $this->belongsTo(PrayerSession::class, 'prayer_session_id');
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
