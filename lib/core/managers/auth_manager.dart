import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final authManagerProvider = Provider((ref) => AuthManager(Supabase.instance.client));

class AuthManager {
  final SupabaseClient _supabase;

  AuthManager(this._supabase);

  /// Oyuncu oturumunu kontrol eder. Yoksa anonim olarak giriş yapar
  /// ve veritabanında 'players' tablosuna kaydını ekler.
  Future<void> signInAnonymouslyIfNeeded() async {
    try {
      final session = _supabase.auth.currentSession;
      
      if (session == null) {
        // Oturum yok, anonim giriş yap
        final response = await _supabase.auth.signInAnonymously();
        if (response.user != null) {
          await _ensurePlayerRecordExists(response.user!.id);
        }
      } else {
        // Zaten oturum var, kayıtlı mı kontrol et
        await _ensurePlayerRecordExists(session.user.id);
      }
    } catch (e) {
      throw Exception('Giriş işlemi başarısız: $e\nLütfen Supabase Dashboard -> Authentication -> Providers -> Anonymous Sign-In ayarının açık olduğundan emin olun.');
    }
  }

  /// Eğer oyuncunun veritabanında kaydı yoksa varsayılan değerlerle yeni kayıt oluşturur.
  Future<void> _ensurePlayerRecordExists(String userId) async {
    try {
      final data = await _supabase
          .from('players')
          .select('id')
          .eq('id', userId)
          .maybeSingle();

      if (data == null) {
        // Kullanıcı için ilk defa oyuncu kaydı oluşturuluyor
        await _supabase.from('players').insert({
          'id': userId,
          'player_name': 'Oyuncu ${userId.substring(0, 4)}',
          'company_name': 'Yeni Holding',
          'avatar_id': 'avatar_1.webp',
          'level': 1,
          'experience': 0,
          'cash': 100000, // Başlangıç parası
          'gold': 100,    // Başlangıç altını
        });
      }
    } catch (e) {
      throw Exception('Oyuncu kaydı oluşturulamadı veya okunamadı: $e');
    }
  }
}
