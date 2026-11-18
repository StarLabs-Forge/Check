import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../widgets/access_card.dart';
import '../widgets/check_logo.dart';

/// Primera pantalla de CHECK: bienvenida y elección de experiencia.
/// Comprador → eventos públicos (sin login). Local/plataforma → selección de
/// plataforma y luego el login único.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final buyer = AccessCard(
      icon: Icons.confirmation_number_outlined,
      title: 'Soy comprador',
      description: 'Descubre eventos, compra tus entradas sin crear una cuenta y recibe tu QR.',
      buttonLabel: 'Explorar eventos',
      primary: true,
      onTap: () => Navigator.of(context).pushNamed('/comprar'),
    );
    final venue = AccessCard(
      icon: Icons.storefront_outlined,
      title: 'Soy parte de un local',
      description: 'Administradores, personal de puerta y equipo de la plataforma. Tu rol se detecta al iniciar sesión.',
      buttonLabel: 'Acceso al sistema',
      onTap: () => Navigator.of(context).pushNamed('/acceso-locales'),
    );

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s6, vertical: AppSpacing.s8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 880),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeOutCubic,
                builder: (context, t, child) => Opacity(
                  opacity: t,
                  child: Transform.translate(offset: Offset(0, (1 - t) * 14), child: child),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CheckLogo(fontSize: 56, alignment: CrossAxisAlignment.center, showIcon: true),
                    const SizedBox(height: AppSpacing.s4),
                    Text(
                      'Control de acceso, reservas y entradas para eventos',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(fontSize: AppTextSize.bodyLg, color: AppColors.textSecondary, height: 1.45),
                    ),
                    const SizedBox(height: AppSpacing.s8),
                    LayoutBuilder(
                      builder: (context, c) {
                        if (c.maxWidth >= 640) {
                          return IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(child: buyer),
                                const SizedBox(width: AppSpacing.s4),
                                Expanded(child: venue),
                              ],
                            ),
                          );
                        }
                        return Column(children: [buyer, const SizedBox(height: AppSpacing.s4), venue]);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
