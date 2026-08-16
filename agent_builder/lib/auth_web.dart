import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;

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
  Future<EntraUser?> currentUser() async {
    final response = await http.get(Uri.base.resolve('/.auth/me'));
    if (response.statusCode != 200) return null;
    final payload = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    final principal = payload['clientPrincipal'];
    if (principal is! Map) return null;
    final values = Map<String, dynamic>.from(principal);
    final roles = (values['userRoles'] as List? ?? const [])
        .map((role) => role.toString())
        .toList();
    if (!roles.contains('authenticated')) return null;
    return EntraUser(
      id: values['userId'] as String,
      displayName:
          values['userDetails'] as String? ?? 'Signed-in Microsoft user',
      roles: roles,
    );
  }

  void signIn() =>
      web.window.location.assign('/.auth/login/aad?post_login_redirect_uri=/');

  void signOut() =>
      web.window.location.assign('/.auth/logout?post_logout_redirect_uri=/');
}
