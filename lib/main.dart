import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'data/database.dart';
import 'services/backup_service.dart';
import 'services/sync_service.dart';
import 'services/theme_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/parcela_form_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/admin_screen.dart';
import 'screens/explorer_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await BackupService.runPendingRestore();

  final db = AppDatabase();
  final syncService = SyncService(db);
  final themeProvider = ThemeProvider();

  await Future.wait([
    syncService.init(),
    themeProvider.init(),
  ]);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: syncService),
        ChangeNotifierProvider.value(value: themeProvider),
      ],
      child: const InventarioApp(),
    ),
  );
}

class InventarioApp extends StatelessWidget {
  const InventarioApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    final isHighContrast = themeProvider.isHighContrast;
    return MaterialApp(
      title: 'Inventário Florestal',
      debugShowCheckedModeBanner: false,
      theme: themeProvider.theme,
      // Sempre sem animação de tema para evitar queda de FPS ao ligar/desligar contraste
      themeAnimationDuration: Duration.zero,
      themeAnimationCurve: Curves.easeInOut,
      initialRoute: '/',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(
              builder: (_) => const SplashScreen(),
            );
          case '/login':
            return MaterialPageRoute(
              builder: (_) => const LoginScreen(),
            );
          case '/home':
            return MaterialPageRoute(
              builder: (_) => const HomeScreen(),
            );
          case '/explorer':
            return MaterialPageRoute(
              builder: (_) => const ExplorerScreen(),
            );
          case '/parcela/nova':
            // Aceita Map com propriedade, propUt, nextParcela pré-preenchidos
            final args = settings.arguments;
            if (args is Map<String, dynamic>) {
              return MaterialPageRoute(
                builder: (_) => ParcelaFormScreen(
                  prefilledPropriedade: args['propriedade'] as String?,
                  prefilledPropUt: args['propUt'] as String?,
                  prefilledNextParcela: args['nextParcela'] as int?,
                ),
              );
            }
            return MaterialPageRoute(
              builder: (_) => const ParcelaFormScreen(),
            );
          case '/parcela/editar':
            final args = settings.arguments;
            if (args is String) {
              return MaterialPageRoute(
                builder: (_) => ParcelaFormScreen(parcelaUuid: args),
              );
            }
            if (args is Map<String, dynamic>) {
              final uuid = args['uuid'] as String? ?? args['parcelaUuid'] as String?;
              final readOnly = args['readOnly'] == true;
              return MaterialPageRoute(
                builder: (_) => ParcelaFormScreen(parcelaUuid: uuid, readOnly: readOnly),
              );
            }
            return MaterialPageRoute(
              builder: (_) => const ParcelaFormScreen(),
            );
          case '/settings':
            return MaterialPageRoute(
              builder: (_) => const SettingsScreen(),
            );
          case '/admin':
            return MaterialPageRoute(
              builder: (_) => const AdminScreen(),
            );
          default:
            return MaterialPageRoute(
              builder: (_) => const LoginScreen(),
            );
        }
      },
    );
  }
}
