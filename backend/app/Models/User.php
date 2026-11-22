<?php

namespace App\Models;

use App\Enums\RoleSlug;
use App\Models\Concerns\Auditable;
use App\Models\Concerns\HasUuid;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    use Auditable, HasApiTokens, HasFactory, HasUuid, Notifiable, SoftDeletes;

    protected $fillable = ['uuid', 'name', 'username', 'email', 'phone', 'password', 'is_active'];

    protected $hidden = ['password', 'remember_token'];

    protected array $auditExclude = ['last_login_at'];

    /** Cache mémoire des permissions pour la durée de la requête. */
    private ?array $permissionSlugs = null;

    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'last_login_at' => 'datetime',
            'password' => 'hashed',
            'is_active' => 'boolean',
        ];
    }

    // ── Relations ───────────────────────────────────────────────

    public function roles(): BelongsToMany
    {
        return $this->belongsToMany(Role::class, 'user_roles')->withPivot('assigned_by', 'created_at');
    }

    public function teams(): BelongsToMany
    {
        return $this->belongsToMany(Team::class, 'team_members')->withPivot('is_leader', 'joined_at')->withTimestamps();
    }

    public function assignedContacts(): HasMany
    {
        return $this->hasMany(Contact::class, 'assigned_user_id');
    }

    public function createdContacts(): HasMany
    {
        return $this->hasMany(Contact::class, 'created_by');
    }

    public function followUps(): HasMany
    {
        return $this->hasMany(FollowUp::class);
    }

    public function devices(): HasMany
    {
        return $this->hasMany(Device::class);
    }

    // ── Habilitations ───────────────────────────────────────────

    public function hasRole(RoleSlug|string $role): bool
    {
        $slug = $role instanceof RoleSlug ? $role->value : $role;

        return $this->roles->contains('slug', $slug);
    }

    public function isAdmin(): bool
    {
        return $this->hasRole(RoleSlug::Administrateur);
    }

    public function hasPermission(string $permission): bool
    {
        if ($this->permissionSlugs === null) {
            $this->permissionSlugs = $this->roles()
                ->with('permissions:id,slug')
                ->get()
                ->flatMap(fn (Role $r) => $r->permissions->pluck('slug'))
                ->unique()
                ->values()
                ->all();
        }

        return in_array($permission, $this->permissionSlugs, true);
    }

    /** @return list<int> */
    public function teamIds(): array
    {
        return $this->teams->pluck('id')->all();
    }
}
