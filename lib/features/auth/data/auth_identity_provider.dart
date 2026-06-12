import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthIdentityState {
  const AuthIdentityState({
    required this.isGoogleLinked,
    required this.isAnonymous,
    this.authEmail,
    this.googleEmail,
    this.displayName,
    this.avatarUrl,
  });

  final bool isGoogleLinked;
  final bool isAnonymous;
  final String? authEmail;
  final String? googleEmail;
  final String? displayName;
  final String? avatarUrl;

  String? get effectiveEmail => googleEmail ?? authEmail;
}

final authIdentityProvider = FutureProvider<AuthIdentityState>((ref) async {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;

  if (user == null) {
    return const AuthIdentityState(
      isGoogleLinked: false,
      isAnonymous: true,
    );
  }

  List<UserIdentity> identities;
  try {
    identities = await supabase.auth.getUserIdentities();
  } catch (_) {
    identities = user.identities ?? const <UserIdentity>[];
  }

  UserIdentity? googleIdentity;
  for (final identity in identities) {
    if (identity.provider == 'google') {
      googleIdentity = identity;
      break;
    }
  }

  final identityData = googleIdentity?.identityData ?? const <String, dynamic>{};
  final metadata = user.userMetadata ?? const <String, dynamic>{};

  return AuthIdentityState(
    isGoogleLinked: googleIdentity != null,
    isAnonymous: user.isAnonymous,
    authEmail: user.email,
    googleEmail:
        identityData['email']?.toString() ??
        metadata['linked_google_email']?.toString(),
    displayName:
        identityData['full_name']?.toString() ??
        identityData['name']?.toString() ??
        metadata['full_name']?.toString() ??
        metadata['name']?.toString(),
    avatarUrl:
        identityData['avatar_url']?.toString() ??
        identityData['picture']?.toString() ??
        metadata['avatar_url']?.toString(),
  );
});
