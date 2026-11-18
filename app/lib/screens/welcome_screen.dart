import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../widgets/access_card.dart';
import '../widgets/check_logo.dart';
import '../widgets/motion.dart';

/// Primera pantalla de CHECK: bienvenida y elección de experiencia.
/// Comprador → eventos públicos (sin login). Local/plataforma → selección de
/// plataforma y luego el login único.
///
/// Todo cabe en una sola vista: si el alto es escaso se oculta el ícono de
/// marca y, en pantallas angostas, las tarjetas pasan a su versión compacta.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth >= 640 + AppSpacing.s6 * 2;
            final short = c.maxHeight < (wide ? 560 : 720);

            final buyer = AccessCard(
              icon: Icons.confirmation_number_outlined,
              title: 'Soy comprador',
              description: 'Descubre eventos, compra tus entradas sin crear una cuenta y recibe tu QR.',
              buttonLabel: 'Explorar eventos',
              primary: true,
              compact: !wide,
              onTap: () => Navigator.of(context).pushNamed('/comprar'),
            );
            final venue = AccessCard(
              icon: Icons.storefront_outlined,
              title: 'Soy parte de un local',
              description: 'Administradores, personal de puerta y equipo de la plataforma. Tu rol se detecta al iniciar sesión.',
              buttonLabel: 'Acceso al sistema',
              compact: !wide,
              onTap: () => Navigator.of(context).pushNamed('/acceso-locales'),
            );

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s6, vertical: AppSpacing.s4),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: c.maxHeight - AppSpacing.s8),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 880),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Reveal(
                          scale: 0.94,
                          dy: -6,
                          child: CheckLogo(
                            fontSize: short ? 40 : 52,
                            alignment: CrossAxisAlignment.center,
                            showIcon: !short,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s3),
                        Reveal(
                          delay: const Duration(milliseconds: 80),
                          child: Text(
                            'Control de acceso, reservas y entradas para eventos',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(fontSize: AppTextSize.bodyLg, color: AppColors.textSecondary, height: 1.45),
                          ),
                        ),
                        SizedBox(height: short ? AppSpacing.s5 : AppSpacing.s8),
                        if (wide)
                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(child: Reveal(delay: const Duration(milliseconds: 160), child: buyer)),
                                const SizedBox(width: AppSpacing.s4),
                                Expanded(child: Reveal(delay: const Duration(milliseconds: 240), child: venue)),
                              ],
                            ),
                          )
                        else ...[
                          Reveal(delay: const Duration(milliseconds: 160), child: buyer),
                          const SizedBox(height: AppSpacing.s3),
                          Reveal(delay: const Duration(milliseconds: 240), child: venue),
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
