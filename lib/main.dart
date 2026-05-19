import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'data/database.dart';
import 'services/backup_service.dart';
import 'services/sync_service.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen_pro.dart';
import 'screens/main_screen.dart';
import 'screens/parcel_detail_screen_pro.dart';
import 'screens/planta_form_screen.dart';
import 'screens/photo_gallery_screen_pro.dart';
import 'screens/settings_screen_pro.dart';
import 'screens/register_screen_pro.dart';
import 'screens/hierarchy_screen_pro.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await BackupService.runPendingRestore();

    final db = AppDatabase();
    final syncService = SyncService(db);

    await syncService.init();

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: syncService),
        ],
        child: const InventarioProApp(),
      ),
    );
  } catch (e, st) {
    debugPrint('ERRO FATAL NO STARTUP: $e\n$st');
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text('Erro ao iniciar o app', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text('$e', textAlign: TextAlign.center, style: const TextStyle(fontSize: 14)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class InventarioProApp extends StatelessWidget {
  const InventarioProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Inventário Pro',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      initialRoute: '/',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(
              builder: (_) => const SplashScreen(),
            );
          case '/login':
            return MaterialPageRoute(
              builder: (_) => const LoginScreenPro(),
            );
          case '/main':
            return MaterialPageRoute(
              builder: (_) => const MainScreen(),
            );
          case '/parcela/nova':
            final args = settings.arguments;
            if (args is Map<String, dynamic>) {
              return MaterialPageRoute(
                builder: (_) => ParcelDetailScreenPro(
                  prefilledPropriedade: args['propriedade'] as String?,
                  prefilledPropUt: args['propUt'] as String?,
                  prefilledNextParcela: args['nextParcela'] as int?,
                ),
              );
            }
            return MaterialPageRoute(
              builder: (_) => const ParcelDetailScreenPro(),
            );
          case '/parcela/editar':
            final args = settings.arguments;
            if (args is String) {
              return MaterialPageRoute(
                builder: (_) => ParcelDetailScreenPro(parcelaUuid: args),
              );
            }
            if (args is Map<String, dynamic>) {
              final uuid = args['uuid'] as String? ?? args['parcelaUuid'] as String?;
              final readOnly = args['readOnly'] == true;
              return MaterialPageRoute(
                builder: (_) => ParcelDetailScreenPro(
                  parcelaUuid: uuid,
                  readOnly: readOnly,
                ),
              );
            }
            return MaterialPageRoute(
              builder: (_) => const ParcelDetailScreenPro(),
            );
          case '/planta/nova':
            final args = settings.arguments;
            if (args is String) {
              return MaterialPageRoute(
                builder: (_) => PlantaFormScreen(parcelaUuid: args),
              );
            }
            return MaterialPageRoute(
              builder: (_) => const Scaffold(
                body: Center(child: Text('Erro: UUID da parcela não fornecido')),
              ),
            );
        case '/settings':
          return MaterialPageRoute(
            builder: (_) => const SettingsScreenPro(),
          );
        case '/gallery':
          return MaterialPageRoute(
            builder: (_) => const PhotoGalleryScreenPro(),
          );
        case '/register':
          return MaterialPageRoute(
            builder: (_) => const RegisterScreenPro(),
          );
        case '/explorer':
          return MaterialPageRoute(
            builder: (_) => const MainScreen(),
          );
        case '/home':
          return MaterialPageRoute(
            builder: (_) => const MainScreen(),
          );
        default:
            return MaterialPageRoute(
              builder: (_) => const LoginScreenPro(),
            );
        }
      },
    );
  }
}
