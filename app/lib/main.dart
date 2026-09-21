import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/events_list_screen.dart';
import 'screens/admin_tickets_screen.dart';

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
      home: const LoginScreen(),
      // Rutas con nombre usadas por la navegación lateral del panel Admin
      // (AdminScaffold) para saltar entre Dashboard/Eventos/Tickets y para
      // "Cerrar sesión" — Login/Registro/Verificación se siguen navegando
      // con Navigator.push directo como antes.
      routes: {
        '/login': (_) => const LoginScreen(),
        '/home': (_) => const HomeScreen(),
        '/eventos': (_) => const EventsListScreen(),
        '/tickets': (_) => const AdminTicketsScreen(),
      },
    );
  }
}
