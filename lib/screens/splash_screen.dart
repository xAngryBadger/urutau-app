import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import '../services/sync_service.dart';

/// Splash screen com animação Lottie de árvore.
/// Exibida por ~3 segundos antes de navegar ao destino adequado.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        _navigate();
      }
    });
  }

  Future<void> _navigate() async {
    final syncService = context.read<SyncService>();
    final user = syncService.currentUser;
    if (user != null) {
      // Foco em modo utilizador: todos vão para o explorer (admin injetado fora do app)
      Navigator.of(context).pushReplacementNamed('/explorer');
    } else {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF304d36),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animação Lottie
            SizedBox(
              width: 220,
              height: 220,
              child: Lottie.asset(
                'assets/animations/tree.json',
                controller: _controller,
                onLoaded: (composition) {
                  _controller.forward();
                },
                errorBuilder: (ctx, error, stackTrace) {
                  // Fallback se a animação falhar
                  Future.delayed(const Duration(seconds: 2), () {
                    if (mounted) {
                      _navigate();
                    }
                  });
                  return const Icon(
                    Icons.forest,
                    size: 120,
                    color: Color(0xFFFFD54F),
                  );
                },
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Inventário',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const Text(
              'Florestal',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFFFFD54F),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
