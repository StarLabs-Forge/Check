import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/demo_mode.dart';
import 'config/supabase_config.dart';
import 'screens/admin_tickets_screen.dart';
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
import 'screens/mfa_screen.dart';
import 'screens/register_screen.dart';
import 'services/app_session.dart';
import 'services/auth_service.dart';
import 'services/errors.dart';
import 'services/superadmin_service.dart' show PlatformStatus;
import 'widgets/maintenance_gate.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kDemo) {
    final problem = SupabaseConfig.problem();
    if (problem != null) throw StateError(problem); // nunca pruebas sobre producción por error
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.anonKey,
    );
  }
  await PlatformStatus.instance.refresh();
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
      _authSub = Supabase.instance.client.auth.onAuthStateChange.listen(
        _onAuthChange,
        // OAuth cancelado o rechazado: el SDK lo informa como error del stream.
        onError: (Object e) => _messengerKey.currentState?.showSnackBar(SnackBar(content: Text(friendlyError(e)))),
      );
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
    nav.pushNamedAndRemoveUntil(signedIn ? AppSession.entryRoute : '/login', (route) => false);
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
        // Mantenimiento: solo el superadministrador puede entrar.
        await PlatformStatus.instance.refresh();
        if (PlatformStatus.instance.maintenance && AppSession.profile.value?.role != 'super_admin') {
          _messengerKey.currentState?.showSnackBar(
            const SnackBar(content: Text('La plataforma está en mantenimiento. Intenta más tarde.')),
          );
          await AuthService.signOut();
          return;
        }
        nav.pushNamedAndRemoveUntil(AppSession.entryRoute, (route) => false);
      case AuthChangeEvent.signedOut:
        AppSession.clear();
        nav.pushNamedAndRemoveUntil('/login', (route) => false);
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
      builder: (context, child) {
        final app = MaintenanceGate(navigatorKey: _navigatorKey, child: child ?? const SizedBox.shrink());
        // Distintivo permanente del entorno de desarrollo.
        return SupabaseConfig.isDev && !kDemo
            ? Banner(message: 'DEV', location: BannerLocation.topEnd, color: AppColors.error, child: app)
            : app;
      },
      // Cada enlace abre UNA sola pantalla: sin la pantalla de carga debajo, «volver»
      // nunca deja al usuario atascado.
      onGenerateInitialRoutes: (name) => [_initialRoute(name)],
      // Rutas con nombre usadas por la navegación lateral del panel Admin
      // (AdminScaffold) y por el listener de auth. Login/Registro/Verificación
      // se siguen navegando con Navigator.push directo.
      routes: _routes,
      onGenerateRoute: _onGenerateRoute,
      onUnknownRoute: _onUnknownRoute,
    );
  }

  Map<String, WidgetBuilder> get _routes => {
        // Públicas. Los compradores llegan desde el sitio web a «/comprar».
        '/login': (_) => const LoginScreen(),
        '/registro': (_) => const RegisterScreen(),
        '/comprar': (_) => const BuyerHome(),
        // Direcciones antiguas (selectores ya retirados): siguen funcionando.
        '/bienvenida': (_) => const RegisterScreen(),
        '/acceso-locales': (_) => const LoginScreen(),
        '/mfa': (_) => const RoleGuard(roles: {'admin', 'super_admin'}, allowMfaPending: true, child: MfaScreen()),
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
      };

  /// Rutas con parámetros: `/registro?origen=prueba|demo` conserva el contexto del
  /// botón de origen y `/comprar?evento=<id>` abre directamente ese evento.
  Route<void>? _onGenerateRoute(RouteSettings settings) {
    final uri = Uri.tryParse(settings.name ?? '');
    final Widget? screen = switch (uri?.path) {
      '/registro' => RegisterScreen(origin: uri!.queryParameters['origen']),
      '/comprar' => BuyerHome(initialEventId: uri!.queryParameters['evento']),
      _ => null,
    };
    return screen == null ? null : MaterialPageRoute<void>(settings: settings, builder: (_) => screen);
  }

  // 404 — mismo frame "Estado — Próximamente" del Figma, standalone.
  Route<void> _onUnknownRoute(RouteSettings settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const ComingSoonScreen(
          title: 'Página no encontrada',
          message: 'La sección que buscas no existe o todavía no está disponible.',
          icon: '🔍',
        ),
      );

  /// Primera pantalla según el enlace. Las públicas se abren tal cual; la raíz y
  /// las privadas pasan por [_Bootstrap], que recupera la sesión guardada.
  Route<dynamic> _initialRoute(String name) {
    final path = Uri.tryParse(name)?.path ?? '/';
    const public = {'/login', '/registro', '/comprar', '/bienvenida', '/acceso-locales'};
    if (public.contains(path)) {
      final settings = RouteSettings(name: name);
      return _onGenerateRoute(settings) ?? MaterialPageRoute<void>(settings: settings, builder: _routes[path]!);
    }
    if (path != '/' && !_routes.containsKey(path)) return _onUnknownRoute(RouteSettings(name: name));
    return MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/'),
      builder: (_) => _Bootstrap(signedOutRoute: path == '/' ? '/registro' : '/login'),
    );
  }
}

/// Splash: muestra el logo un instante mientras se resuelve si hay una sesión
/// persistida válida, y entonces va a su panel, o a [signedOutRoute] sin sesión.
class _Bootstrap extends StatefulWidget {
  const _Bootstrap({required this.signedOutRoute});

  final String signedOutRoute;

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
    // Flutter puede construir esta ruta debajo de un enlace directo. En ese
    // caso no debe reemplazar la pantalla que el usuario ya está viendo.
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;

    if (hasSession && error == null) {
      Navigator.of(context).pushReplacementNamed(AppSession.entryRoute);
    } else {
      // Con un error (cuenta suspendida...) o el registro cerrado, va a iniciar sesión.
      final register = error == null && PlatformStatus.instance.registrationOpen;
      Navigator.of(context).pushReplacementNamed(register ? widget.signedOutRoute : '/login');
      if (error != null) {
        _messengerKey.currentState?.showSnackBar(SnackBar(content: Text(error)));
      }
    }
  }

  @override
  Widget build(BuildContext context) => const LoadingScreen();
}
