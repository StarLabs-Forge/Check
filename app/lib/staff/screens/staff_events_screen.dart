import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';
import '../data/staff_models.dart';
import '../staff_scope.dart';
import '../widgets/staff_badge.dart';
import '../widgets/staff_button.dart';
import '../widgets/staff_icon.dart';
import '../widgets/staff_progress_bar.dart';
import 'scanner_screen.dart';

/// Figma → 📱 App Móvil → "Eventos activos" (30:2), 390×844.
///
/// Cabecera "CHECK." + local, título "Eventos Activos", tarjeta del evento con
/// progreso, botón "Iniciar Scanner" (56px) y estado de conectividad.
/// Solo se listan eventos habilitados para la cuenta (RLS en la versión real).
class StaffEventsScreen extends StatefulWidget {
  const StaffEventsScreen({super.key, this.venueName = 'Dharma Club'});

  final String venueName;

  @override
  State<StaffEventsScreen> createState() => _StaffEventsScreenState();
}

class _StaffEventsScreenState extends State<StaffEventsScreen> {
  List<StaffEvent>? _events;
  int _selected = 0;
  bool _failed = false;
  bool _online = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = StaffScope.of(context);
    try {
      final list = await repo.assignedEvents();
      final online = await repo.isOnline();
      if (!mounted) return;
      setState(() {
        _events = list;
        _failed = false;
        _online = online;
        if (_selected >= list.length) _selected = 0;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _online = false;
      });
    }
  }

  Future<void> _startScanner(StaffEvent e) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ScannerScreen(event: e)));
    if (mounted) _load(); // refresca contadores al volver
  }

  @override
  Widget build(BuildContext context) {
    final events = _events;
    final selected = (events != null && events.isNotEmpty) ? events[_selected] : null;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.s6, AppSpacing.s8, AppSpacing.s6, AppSpacing.s6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.accentPrimary,
                  backgroundColor: AppColors.bgSurface,
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      _Header(venueName: widget.venueName),
                      const SizedBox(height: AppSpacing.s8),
                      Text(
                        'Eventos Activos',
                        style: GoogleFonts.inter(
                          fontSize: AppTextSize.h2,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s8),
                      ..._cards(events),
                      const SizedBox(height: AppSpacing.s8),
                      StaffButton(
                        label: 'Iniciar Scanner',
                        height: 56,
                        onPressed: selected == null ? null : () => _startScanner(selected),
                      ),
                      const SizedBox(height: AppSpacing.s8),
                      _Connectivity(online: _online),
                    ],
                  ),
                ),
              ),
              Text(
                'Solo eventos habilitados para tu cuenta',
                style: GoogleFonts.inter(fontSize: AppTextSize.caption, color: AppColors.textSecondary, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _cards(List<StaffEvent>? events) {
    if (_failed) {
      return [
        const Center(child: StaffIcon(StaffIcons.wifiOff, size: 48, color: AppColors.textSecondary)),
        const SizedBox(height: AppSpacing.s4),
        Center(
          child: Text(
            'No pudimos cargar tus eventos',
            style: GoogleFonts.inter(
              fontSize: AppTextSize.h3,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s4),
        StaffButton(label: 'Reintentar', variant: StaffButtonVariant.outline, onPressed: _load),
      ];
    }
    if (events == null) {
      return const [Center(child: CircularProgressIndicator(color: AppColors.accentPrimary))];
    }
    if (events.isEmpty) {
      return [
        Text(
          'Todavía no tienes eventos activos asignados.',
          style: GoogleFonts.inter(fontSize: AppTextSize.body, color: AppColors.textSecondary),
        ),
      ];
    }
    return [
      for (var i = 0; i < events.length; i++) ...[
        if (i > 0) const SizedBox(height: AppSpacing.s4),
        _EventCard(
          event: events[i],
          // Solo se marca la selección cuando hay más de un evento.
          selected: events.length > 1 && i == _selected,
          onTap: () => setState(() => _selected = i),
        ),
      ],
    ];
  }
}

/// "Cabecera": logo CHECK. (Inter Bold 32, punto en accent) + "Local · Staff".
class _Header extends StatelessWidget {
  const _Header({required this.venueName});

  final String venueName;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            style: GoogleFonts.inter(
              fontSize: AppTextSize.h1,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.4,
            ),
            children: const [
              TextSpan(text: 'CHECK'),
              TextSpan(text: '.', style: TextStyle(color: AppColors.accentPrimary)),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s2),
        Text(
          '$venueName · Staff',
          style: GoogleFonts.inter(fontSize: AppTextSize.body, color: AppColors.textSecondary, height: 1.4),
        ),
      ],
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event, required this.selected, required this.onTap});

  final StaffEvent event;
  final bool selected;
  final VoidCallback onTap;

  static const _months = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];

  String get _when {
    final d = event.startsAt.toLocal();
    return '${d.day} ${_months[d.month - 1]} ${d.year} · ${hhmm(event.startsAt)}';
  }

  @override
  Widget build(BuildContext context) {
    final remaining = (event.capacity - event.checkins).clamp(0, event.capacity);

    return Semantics(
      button: true,
      selected: selected,
      label: '${event.name}, $_when, ${event.checkins} de ${event.capacity} ingresados',
      child: Material(
        color: AppColors.bgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: selected ? AppColors.accentPrimary : AppColors.bgBorder),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const StaffBadge(StaffBadgeStatus.activo),
                const SizedBox(height: AppSpacing.s5),
                Text(
                  event.name,
                  style: GoogleFonts.inter(
                    fontSize: AppTextSize.h2,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: AppSpacing.s5),
                Text(
                  _when,
                  style: GoogleFonts.inter(fontSize: AppTextSize.body, color: AppColors.textSecondary, height: 1.4),
                ),
                const SizedBox(height: AppSpacing.s5),
                const Divider(height: 1, thickness: 1, color: AppColors.bgBorder),
                const SizedBox(height: AppSpacing.s5),
                Text(
                  '${event.checkins} / ${event.capacity} ingresados',
                  style: GoogleFonts.inter(
                    fontSize: AppTextSize.h3,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: AppSpacing.s5),
                StaffProgressBar(progress: event.progress),
                const SizedBox(height: AppSpacing.s5),
                Text(
                  '$remaining invitados por llegar',
                  style: GoogleFonts.inter(fontSize: AppTextSize.caption, color: AppColors.textSecondary, height: 1.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Conectividad": punto de 8px + estado.
class _Connectivity extends StatelessWidget {
  const _Connectivity({required this.online});

  final bool online;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: online ? AppColors.accentPrimary : AppColors.error,
            ),
          ),
          const SizedBox(width: AppSpacing.s2),
          Text(
            online ? 'Conectado · Listo para validar tickets' : 'Sin conexión · No se pueden validar tickets',
            style: GoogleFonts.inter(fontSize: AppTextSize.caption, color: AppColors.textSecondary, height: 1.4),
          ),
        ],
      ),
    );
  }
}
