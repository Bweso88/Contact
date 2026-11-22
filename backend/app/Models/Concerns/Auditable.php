<?php

namespace App\Models\Concerns;

use App\Models\AuditLog;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\MorphMany;

/**
 * Écrit une ligne dans audit_logs à chaque création, modification ou
 * suppression. Un modèle peut lister des champs à ne jamais journaliser
 * dans la propriété $auditExclude.
 */
trait Auditable
{
    public static function bootAuditable(): void
    {
        static::created(fn (Model $m) => $m->writeAudit('created', [], $m->auditableAttributes($m->getAttributes())));

        static::updated(function (Model $m) {
            $changes = $m->auditableAttributes($m->getChanges());
            if ($changes === []) {
                return;
            }
            $old = array_intersect_key($m->getOriginal(), $changes);
            $m->writeAudit('updated', $m->auditableAttributes($old), $changes);
        });

        static::deleted(fn (Model $m) => $m->writeAudit('deleted', $m->auditableAttributes($m->getAttributes()), []));

        if (method_exists(static::class, 'restored')) {
            static::restored(fn (Model $m) => $m->writeAudit('restored', [], []));
        }
    }

    public function auditLogs(): MorphMany
    {
        return $this->morphMany(AuditLog::class, 'auditable');
    }

    protected function auditableAttributes(array $attributes): array
    {
        $exclude = array_merge(
            ['created_at', 'updated_at', 'password', 'remember_token'],
            property_exists($this, 'auditExclude') ? $this->auditExclude : []
        );

        // Les enums et dates sont convertis en valeurs simples pour le JSON.
        return collect($attributes)
            ->except($exclude)
            ->map(fn ($v) => $v instanceof \BackedEnum ? $v->value : ($v instanceof \DateTimeInterface ? $v->format(DATE_ATOM) : $v))
            ->all();
    }

    protected function writeAudit(string $event, array $old, array $new): void
    {
        $request = app()->runningInConsole() ? null : request();

        AuditLog::create([
            'user_id' => auth()->id(),
            'event' => $event,
            'auditable_type' => $this->getMorphClass(),
            'auditable_id' => $this->getKey(),
            'old_values' => $old ?: null,
            'new_values' => $new ?: null,
            'ip_address' => $request?->ip(),
            'user_agent' => $request ? substr((string) $request->userAgent(), 0, 255) : null,
        ]);
    }
}
