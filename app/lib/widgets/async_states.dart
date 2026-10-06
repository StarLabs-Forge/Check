import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Spinner centrado para pantallas que cargan datos de Supabase.
class LoadingBlock extends StatelessWidget {
  const LoadingBlock({super.key, this.height = 240});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.6, color: AppColors.accentPrimary),
        ),
      ),
    );
  }
}

/// Error de carga con botón "Reintentar".
class ErrorBlock extends StatelessWidget {
  const ErrorBlock({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, color: AppColors.textSecondary, size: 32),
            const SizedBox(height: AppSpacing.s3),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: AppTextSize.body),
            ),
            const SizedBox(height: AppSpacing.s4),
            OutlinedButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}
