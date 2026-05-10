import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hard_kapitalizm/core/managers/asset_manager.dart';
import 'package:hard_kapitalizm/core/managers/auth_manager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  int _totalFiles = 0;
  int _currentFile = 0;
  String _currentFileName = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  Future<void> _startDownload() async {
    try {
      final authManager = ref.read(authManagerProvider);
      await authManager.signInAnonymouslyIfNeeded();

      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        try {
          await Supabase.instance.client.rpc(
            'complete_due_market_transfers',
            params: {
              'p_buyer_player_id': user.id,
              'p_limit': 100,
            },
          );
        } catch (_) {
          // Gecikmis transfer tamamlama basarisiz olsa bile giris akisini bloklamiyoruz.
        }
      }

      final assetManager = ref.read(assetManagerProvider);
      
      await assetManager.prefetchAssets((current, total, fileName) {
        if (mounted) {
          setState(() {
            _currentFile = current;
            _totalFiles = total;
            _currentFileName = fileName;
          });
        }
      });

      // İndirme bittikten sonra barın %100 olduğunu göstermek için state'i güncelle
      if (mounted) {
        setState(() {
          // Eğer totalFiles 0 geldiyse bile (RLS vs yüzünden) barı dolu göster
          if (_totalFiles == 0) {
            _totalFiles = 1;
            _currentFile = 1;
            _currentFileName = 'Tamamlandı';
          } else {
            _currentFile = _totalFiles;
          }
        });
        // %100 doluluk animasyonunun görünmesi için yarım saniye bekle
        await Future.delayed(const Duration(milliseconds: 500));
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _totalFiles > 0 ? _currentFile / _totalFiles : 0.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.factory_rounded, size: 80, color: Colors.blueGrey),
              const SizedBox(height: 32),
              const Text(
                'Hard Kapitalizm\nYükleniyor...',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 48),
              if (_error != null) ...[
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _error = null;
                    });
                    _startDownload();
                  },
                  child: const Text('Tekrar Dene'),
                )
              ] else ...[
                Text(
                  '%${(progress * 100).toInt()}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 16),
                Text(
                  progress == 1.0
                      ? 'Tamamlandı'
                      : (_totalFiles > 0
                          ? 'Kaynaklar indiriliyor...'
                          : 'Sunucu bağlantısı kuruluyor...'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    fontSize: 14,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
