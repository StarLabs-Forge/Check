import 'staff_models.dart';

/// Contrato de datos de la app Staff. La implementación real hablará con
/// Supabase (RLS + RPC `validate_qr` / `confirm_checkin` del README); mientras
/// tanto [MockStaffRepository] permite recorrer todo el flujo sin backend.
///
/// Cambiar de mock a real = cambiar la instancia en `StaffApp`; las pantallas
/// solo conocen esta interfaz.
abstract class StaffRepository {
  Future<void> signOut();

  /// `true` si hay conexión con el backend (la validación de QR es en línea).
  Future<bool> isOnline();

  /// Solo eventos asignados al staff (RLS en la versión real).
  Future<List<StaffEvent>> assignedEvents();

  /// Valida un QR escaneado y, si es válido y no usado, registra el ingreso.
  Future<ScanOutcome> scanQr({required String eventId, required String token});
}
