/// Utilisateur connecté, tel que renvoyé par POST /api/login.
class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.username,
    this.roles = const [],
    this.permissions = const [],
    this.teams = const [],
  });

  final int id;
  final String name;
  final String username;
  final List<String> roles;
  final List<String> permissions;
  final List<UserTeam> teams;

  bool get isAdmin => roles.contains('administrateur');

  /// Sert uniquement à adapter l'interface : le serveur revérifie toujours.
  bool can(String permission) => isAdmin || permissions.contains(permission);

  UserTeam? get primaryTeam => teams.isEmpty ? null : teams.first;

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
    id: j['id'] as int,
    name: j['name'] as String,
    username: j['username'] as String,
    roles: List<String>.from(j['roles'] as List? ?? const []),
    permissions: List<String>.from(j['permissions'] as List? ?? const []),
    teams: (j['teams'] as List? ?? const []).map((t) => UserTeam.fromJson(t as Map<String, dynamic>)).toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'username': username,
    'roles': roles,
    'permissions': permissions,
    'teams': teams.map((t) => t.toJson()).toList(),
  };
}

class UserTeam {
  const UserTeam({required this.id, required this.name, this.isLeader = false});

  final int id;
  final String name;
  final bool isLeader;

  factory UserTeam.fromJson(Map<String, dynamic> j) =>
      UserTeam(id: j['id'] as int, name: j['name'] as String, isLeader: (j['is_leader'] as bool?) ?? false);

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'is_leader': isLeader};
}
