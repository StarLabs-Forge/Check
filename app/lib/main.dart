import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/events_list_screen.dart';
import 'screens/admin_tickets_screen.dart';
import 'screens/loading_screen.dart';
import 'screens/coming_soon_screen.dart';
import 'widgets/admin_scaffold.dart';

void main() {
  runApp(const CheckApp());
}

class CheckApp extends StatelessWidget {
  const CheckApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CHECK',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      // Arranca en el splash ("Splash — Cargando" en Figma) y de ahí pasa a
      // Login — simulado por ahora ya que todavía no hay backend que
      // consultar en el arranque real.
      home: const _Bootstrap(),
      // Rutas con nombre usadas por la navegación lateral del panel Admin
      // (AdminScaffold) para saltar entre Dashboard/Eventos/Tickets/
      // Configuración y para "Cerrar sesión" — Login/Registro/Verificación
      // se siguen navegando con Navigator.push directo como antes.
      routes: {
        '/login': (_) => const LoginScreen(),
        '/home': (_) => const HomeScreen(),
        '/eventos': (_) => const EventsListScreen(),
        '/tickets': (_) => const AdminTicketsScreen(),
        '/configuracion': (_) => const ComingSoonScreen(current: AdminRoute.configuracion),
      },
      // 404 — implementa el mismo frame "Estado — Próximamente" del Figma,
      // pero standalone (sin sidebar) y con copy de "no encontrado".
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

/// Muestra el splash un momento y luego navega a Login. Sin backend real
/// todavía, así que el delay es solo para que el splash sea visible — el
/// día que haya sesión persistida/backend, acá se resuelve a Login u Home
/// según corresponda.
class _Bootstrap extends StatefulWidget {
  const _Bootstrap();

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) Navigator.of(context).pushReplacementNamed('/login');
    });
  }

  @override
  Widget build(BuildContext context) => const LoadingScreen();
}
