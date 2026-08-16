class EntraUser {
  const EntraUser({
    required this.id,
    required this.displayName,
    required this.roles,
  });

  final String id;
  final String displayName;
  final List<String> roles;
}

class EntraAuthentication {
  Future<EntraUser?> currentUser() async => null;
  void signIn() {}
  void signOut() {}
}
