import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/demo_mode.dart';
import 'config/supabase_config.dart';
import 'screens/admin_tickets_screen.dart';
import 'screens/platform_select_screen.dart';
import 'screens/welcome_screen.dart';
import 'staff/staff_panel.dart';
import 'widgets/role_guard.dart';
import 'screens/coming_soon_screen.dart';
import 'screens/complete_profile_screen.dart';
import 'screens/events_list_screen.dart';
import 'screens/home_screen.dart';
import 'proto/buyer/buyer_flow.dart';
import 'proto/superadmin/superadmin_flow.dart';
import 'screens/loading_screen.dart';
import 'screens/payments_screens.dart';
import 'screens/venue_settings_screen.dart';
import 'screens/login_screen.dart';
import 'services/app_session.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kDemo) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.anonKey,
    );
  }
  runApp(const CheckApp());
}

final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> _messengerKey = GlobalKey<ScaffoldMessengerState>();

class CheckApp extends StatefulWidget {
  const CheckApp({super.key});

  @override
  State<CheckApp> createState() => _CheckAppState();
}

class _CheckAppState extends State<CheckApp> {
  StreamSubscription<AuthState>? _authSub;
  StreamSubscription<bool>? _demoSub;

  @override
  void initState() {
    super.initState();
    // Única fuente de verdad de la navegación post-auth: cualquier pantalla
    // (login, registro, verificación, OAuth, cierre de sesión) solo
    // autentica; acá se decide a dónde ir.
    if (kDemo) {
      _demoSub = AuthService.demoSession.stream.listen(_onDemoChange);
    } else {
      _authSub = Supabase.instance.client.auth.onAuthStateChange.listen(_onAuthChange);
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _demoSub?.cancel();
    super.dispose();
  }

  void _onDemoChange(bool signedIn) {
    final nav = _navigatorKey.currentState;
    if (nav == null) return;
    nav.pushNamedAndRemoveUntil(signedIn ? AppSession.entryRoute : '/bienvenida', (route) => false);
  }

  Future<void> _onAuthChange(AuthState state) async {
    final nav = _navigatorKey.currentState;
    if (nav == null) return;

    switch (state.event) {
      case AuthChangeEvent.signedIn:
        final user = state.session?.user;
        if (user == null) return;
        // Evita re-navegar si el evento se repite para el mismo usuario
        // (p. ej. al volver el foco a la pestaña en web).
        if (AppSession.profile.value?.id == user.id) return;

        final error = await AppSession.load();
        if (error != null) {
          _messengerKey.currentState?.showSnackBar(SnackBar(content: Text(error)));
          return; // load() ya cerró la sesión → llegará signedOut.
        }
        nav.pushNamedAndRemoveUntil(AppSession.entryRoute, (route) => false);
      case AuthChangeEvent.signedOut:
        AppSession.clear();
        nav.pushNamedAndRemoveUntil('/bienvenida', (route) => false);
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CHECK',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: _messengerKey,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      home: const _Bootstrap(),
      // Rutas con nombre usadas por la navegación lateral del panel Admin
      // (AdminScaffold) y por el listener de auth. Login/Registro/Verificación
      // se siguen navegando con Navigator.push directo.
      routes: {
        // Públicas: bienvenida, selección de plataforma, login único y compra.
        '/bienvenida': (_) => const WelcomeScreen(),
        '/acceso-locales': (_) => const PlatformSelectScreen(),
        '/login': (_) => const LoginScreen(),
        '/comprar': (_) => const BuyerHome(),
        // Privadas: cada una exige el rol correspondiente (RoleGuard).
        '/completar-perfil': (_) => const RoleGuard(roles: {'admin'}, child: CompleteProfileScreen()),
        '/home': (_) => const RoleGuard(roles: {'admin'}, child: HomeScreen()),
        '/eventos': (_) => const RoleGuard(roles: {'admin'}, child: EventsListScreen()),
        '/tickets': (_) => const RoleGuard(roles: {'admin'}, child: AdminTicketsScreen()),
        '/pagos': (_) => const RoleGuard(roles: {'admin'}, child: AdminPaymentsScreen()),
        '/verificadores': (_) => const RoleGuard(roles: {'admin'}, child: AdminVerifiersScreen()),
        '/personal': (_) => const RoleGuard(roles: {'admin'}, child: AdminStaffScreen()),
        '/auditoria': (_) => const RoleGuard(roles: {'admin'}, child: AdminAuditScreen()),
        '/configuracion': (_) => RoleGuard(
              roles: const {'admin'},
              child: const VenueSettingsScreen(),
            ),
        '/superadmin': (_) => RoleGuard(
              roles: const {'super_admin'},
              child: SuperadminExperience(onExit: AuthService.signOut),
            ),
        '/staff': (_) => const RoleGuard(roles: {'staff'}, child: StaffPanel()),
      },
      // 404 — mismo frame "Estado — Próximamente" del Figma, standalone.
      onUnknownRoute: (settings) => MaterialPageRoute(
        builder: (_) => const ComingSoonScreen(
          title: 'Página no encontrada',
          message: 'La sección que buscas no existe o todavía no está disponible.',
          icon: '🔍',
        ),
      ),
    );
  }
}

/// Splash: muestra el logo un instante mientras se resuelve si hay una sesión
/// persistida válida, y entonces va a Home o a Login.
class _Bootstrap extends StatefulWidget {
  const _Bootstrap();

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    final minSplash = Future<void>.delayed(const Duration(milliseconds: 1200));

    String? error;
    final hasSession = !kDemo && Supabase.instance.client.auth.currentSession != null;
    if (hasSession) {
      error = await AppSession.load();
    }
    await minSplash;
    if (!mounted) return;

    if (hasSession && error == null) {
      Navigator.of(context).pushReplacementNamed(AppSession.entryRoute);
    } else {
      Navigator.of(context).pushReplacementNamed('/bienvenida');
      if (error != null) {
        _messengerKey.currentState?.showSnackBar(SnackBar(content: Text(error)));
      }
    }
  }

  @override
  Widget build(BuildContext context) => const LoadingScreen();
}
