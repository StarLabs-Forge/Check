import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../widgets/access_card.dart';
import '../widgets/check_logo.dart';
import '../widgets/motion.dart';

/// Selección de plataforma (web / app móvil) antes del login único.
/// Elegir plataforma NO define el rol: los permisos salen de la identidad
/// autenticada.
///
/// La app móvil (carpeta `lib/staff`, `lib/main_staff.dart`) existe solo como
/// build de desarrollo: no está publicada ni tiene login propio, así que acá
/// se muestra como "En desarrollo" sin simular una instalación.
class PlatformSelectScreen extends StatelessWidget {
  const PlatformSelectScreen({super.key});

  void _mobileInfo(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgSurface,
        title: const Text('Aplicación móvil en desarrollo'),
        content: const Text(
          'La app móvil de CHECK todavía no se puede instalar. Mientras tanto, el personal puede ingresar por la versión web, que funciona en celulares, y llegará a su panel según sus permisos.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Entendido')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).pushNamed('/login');
            },
            child: const Text('Continuar en la web', style: TextStyle(color: AppColors.accentPrimary)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(backgroundColor: Colors.transparent),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth >= 640 + AppSpacing.s6 * 2;

            final web = AccessCard(
              icon: Icons.computer_outlined,
              title: 'Versión web',
              description: 'Accede desde el navegador, en computadora o celular. Un solo inicio de sesión para todo el personal.',
              buttonLabel: 'Continuar en la web',
              primary: true,
              compact: !wide,
              onTap: () => Navigator.of(context).pushNamed('/login'),
            );
            final mobile = AccessCard(
              icon: Icons.smartphone_outlined,
              title: 'Aplicación móvil',
              badge: 'En desarrollo',
              description: 'La app para el personal de puerta: escaneo de QR y operación en el evento.',
              buttonLabel: 'Acceder a la app',
              compact: !wide,
              onTap: () => _mobileInfo(context),
            );

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s6, vertical: AppSpacing.s2),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: c.maxHeight - AppSpacing.s4),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 880),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Reveal(scale: 0.94, child: CheckLogo(fontSize: 32, alignment: CrossAxisAlignment.center)),
                        const SizedBox(height: AppSpacing.s5),
                        Reveal(
                          delay: const Duration(milliseconds: 70),
                          child: Text(
                            '¿Cómo quieres acceder?',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(fontSize: AppTextSize.h2, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s1),
                        Reveal(
                          delay: const Duration(milliseconds: 110),
                          child: Text(
                            'Tu rol y permisos se detectan al iniciar sesión.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(fontSize: AppTextSize.body, color: AppColors.textSecondary),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s6),
                        if (wide)
                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(child: Reveal(delay: const Duration(milliseconds: 160), child: web)),
                                const SizedBox(width: AppSpacing.s4),
                                Expanded(child: Reveal(delay: const Duration(milliseconds: 240), child: mobile)),
                              ],
                            ),
                          )
                        else ...[
                          Reveal(delay: const Duration(milliseconds: 160), child: web),
                          const SizedBox(height: AppSpacing.s3),
                          Reveal(delay: const Duration(milliseconds: 240), child: mobile),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
