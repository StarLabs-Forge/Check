import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'check_logo.dart';

/// Layout compartido por Login / Registro / Verificación: tarjeta centrada
/// sobre el fondo oscuro de la app, con el wordmark de CHECK arriba.
///
/// Nota de diseño: el archivo de Figma de referencia solo trae el Dashboard
/// Web ("🖥️ Dashboard Web"), no las pantallas de auth. Esta tarjeta reutiliza
/// los mismos tokens (colores, radios, tipografía Inter) que ese dashboard
/// para que, cuando el diseño de auth exista en Figma, el salto visual sea
/// mínimo.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.maxWidth = 420,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s6,
              vertical: AppSpacing.s8,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CheckLogo(fontSize: 32, alignment: CrossAxisAlignment.center, brand: true),
                  const SizedBox(height: AppSpacing.s8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.s8),
                    decoration: BoxDecoration(
                      color: AppColors.bgSurface,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: AppColors.bgBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: AppTextSize.h3,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s2),
                        Text(
                          subtitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: AppTextSize.body,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s6),
                        child,
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Botón "Continuar con Google" — solo UI, sin integración real todavía.
/// El ícono se arma con formas nativas (sin asset) para no depender de un
/// paquete de íconos de terceros en esta etapa de solo-frontend.
class GoogleButton extends StatelessWidget {
  const GoogleButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        side: const BorderSide(color: AppColors.bgBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            child: const Text(
              'G',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Color(0xFF4285F4),
                height: 1,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s3),
          Text(label),
        ],
      ),
    );
  }
}

/// Separador "o continúa con" reutilizado en Login/Registro.
class OrDivider extends StatelessWidget {
  const OrDivider({super.key, this.label = 'o continúa con'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.bgBorder)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s3),
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: AppTextSize.caption,
            ),
          ),
        ),
        const Expanded(child: Divider(color: AppColors.bgBorder)),
      ],
    );
  }
}
