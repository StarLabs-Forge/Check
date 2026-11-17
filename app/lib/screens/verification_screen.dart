import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_scaffold.dart';
import 'home_screen.dart';

/// Código de verificación (2FA) — se pide en cada inicio de sesión del
/// Admin. Puramente visual por ahora: cualquier código de 6 dígitos navega
/// a la pantalla inicial; la generación/envío/validación real del código
/// queda para cuando se conecte el backend.
class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key, required this.email});

  final String email;

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  static const _codeLength = 6;
  static const _resendSeconds = 60;

  final List<TextEditingController> _controllers =
      List.generate(_codeLength, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(_codeLength, (_) => FocusNode());

  Timer? _timer;
  int _secondsLeft = _resendSeconds;
  bool _isVerifying = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = _resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft -= 1);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _code => _controllers.map((c) => c.text).join();

  void _onDigitChanged(int index, String value) {
    setState(() => _error = null);
    if (value.isNotEmpty && index < _codeLength - 1) {
      _focusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    if (_code.length == _codeLength) {
      _verify();
    }
  }

  Future<void> _verify() async {
    if (_code.length < _codeLength) {
      setState(() => _error = 'Ingresa los $_codeLength dígitos del código');
      return;
    }

    setState(() => _isVerifying = true);
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() => _isVerifying = false);

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  void _resend() {
    if (_secondsLeft > 0) return;
    for (final c in _controllers) {
      c.clear();
    }
    _focusNodes.first.requestFocus();
    _startTimer();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Código reenviado')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Verifica tu identidad',
      subtitle: 'Enviamos un código de 6 dígitos a ${widget.email}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(_codeLength, (index) {
              return SizedBox(
                width: 44,
                height: 56,
                child: TextField(
                  controller: _controllers[index],
                  focusNode: _focusNodes[index],
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  maxLength: 1,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: const InputDecoration(counterText: ''),
                  onChanged: (value) => _onDigitChanged(index, value),
                ),
              );
            }),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.s3),
            Text(
              _error!,
              style: const TextStyle(color: AppColors.error, fontSize: AppTextSize.caption),
            ),
          ],
          const SizedBox(height: AppSpacing.s6),
          ElevatedButton(
            onPressed: _isVerifying ? null : _verify,
            child: _isVerifying
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: AppColors.bgPrimary,
                    ),
                  )
                : const Text('Verificar'),
          ),
          const SizedBox(height: AppSpacing.s4),
          Center(
            child: TextButton(
              onPressed: _secondsLeft == 0 ? _resend : null,
              child: Text(
                _secondsLeft == 0
                    ? 'Reenviar código'
                    : 'Reenviar código en ${_secondsLeft}s',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
