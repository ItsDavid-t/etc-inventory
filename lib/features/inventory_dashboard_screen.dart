import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:get_it/get_it.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'auth/domain/app_user.dart';
import 'auth/presentation/auth_cubit.dart';
import 'auth/presentation/user_management_screen.dart';
import 'inventory_dashboard_stats_service.dart';
import 'inventory_excel_service.dart';
import 'inventory_explorer_screen.dart';
import '../core/theme/app_theme.dart';

class InventoryDashboardScreen extends StatefulWidget {
  const InventoryDashboardScreen({required this.user, super.key});

  final AppUser user;

  @override
  State<InventoryDashboardScreen> createState() =>
      _InventoryDashboardScreenState();
}

class _InventoryDashboardScreenState extends State<InventoryDashboardScreen> {
  final _statsService = GetIt.instance<InventoryDashboardStatsService>();
  late Future<InventoryDashboardStats> _stats;

  @override
  void initState() {
    super.initState();
    _stats = _loadStats();
  }

  Future<InventoryDashboardStats> _loadStats() async {
    final result = await _statsService.load();
    return result.match(
      (failure) => throw StateError(failure.message),
      (stats) => stats,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdministrator = widget.user.role == UserRole.administrator;
    final excelService = GetIt.instance<InventoryExcelService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventario Etecsa'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: () => context.read<AuthCubit>().signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _WelcomeCard(user: widget.user)
                  .animate()
                  .fadeIn(duration: 320.ms)
                  .slideY(begin: .04, end: 0),
              const SizedBox(height: 20),
              Text(
                'Resumen del inventario',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              FutureBuilder<InventoryDashboardStats>(
                future: _stats,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Text('No se pudo cargar el resumen.');
                  }
                  if (!snapshot.hasData) {
                    return const SizedBox(
                      height: 140,
                      child: Center(
                        child: SpinKitPulse(
                          color: AppTheme.secondary,
                          size: 46,
                        ),
                      ),
                    );
                  }
                  final stats = snapshot.data!;
                  return GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    mainAxisExtent: 140,
                    children: [
                      _MetricCard(
                        title: 'Ubicaciones',
                        value: '${stats.locationCount}',
                        icon: LucideIcons.mapPin,
                      ).animate(delay: 40.ms).fadeIn(duration: 280.ms),
                      _MetricCard(
                        title: 'Equipos',
                        value: '${stats.deviceCount}',
                        icon: LucideIcons.package,
                      ).animate(delay: 90.ms).fadeIn(duration: 280.ms),
                      _MetricCard(
                        title: 'Clasificaciones',
                        value: '${stats.classificationCount}',
                        icon: LucideIcons.layers2,
                      ).animate(delay: 140.ms).fadeIn(duration: 280.ms),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              Text(
                'Acciones rápidas',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _ActionChip(
                    label: 'Inventario',
                    icon: LucideIcons.package,
                    enabled: true,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const InventoryExplorerScreen(),
                      ),
                    ),
                  ),
                  _ActionChip(
                    label: 'Importar Excel',
                    icon: LucideIcons.upload,
                    enabled: isAdministrator,
                    onPressed: isAdministrator
                        ? () async {
                            final messenger = ScaffoldMessenger.of(context);
                            messenger
                              ..hideCurrentSnackBar()
                              ..showSnackBar(
                                const SnackBar(
                                  content: Text('Procesando archivo Excel...'),
                                  duration: Duration(minutes: 1),
                                ),
                              );
                            final result = await excelService.importInventory();
                            if (!context.mounted) return;
                            result.match(
                              (failure) {
                                messenger
                                  ..hideCurrentSnackBar()
                                  ..showSnackBar(
                                    SnackBar(
                                      content: Text(failure.message),
                                      duration: const Duration(seconds: 8),
                                    ),
                                  );
                              },
                              (summary) {
                                messenger
                                  ..hideCurrentSnackBar()
                                  ..showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Importación finalizada: ${summary.totalLocations} ubicaciones, ${summary.totalDevices} equipos.',
                                      ),
                                    ),
                                  );
                                setState(() => _stats = _loadStats());
                              },
                            );
                          }
                        : () {},
                  ),
                  _ActionChip(
                    label: 'Exportar Excel',
                    icon: LucideIcons.download,
                    enabled: isAdministrator,
                    onPressed: isAdministrator
                        ? () async {
                            final result = await excelService.exportInventory();
                            result.match(
                              (failure) => ScaffoldMessenger.of(context)
                                  .showSnackBar(
                                    SnackBar(content: Text(failure.message)),
                                  ),
                              (path) => ScaffoldMessenger.of(context)
                                  .showSnackBar(
                                    SnackBar(
                                      content: Text('Archivo exportado: $path'),
                                    ),
                                  ),
                            );
                          }
                        : () {},
                  ),
                  _ActionChip(
                    label: 'Usuarios',
                    icon: Icons.people_alt_outlined,
                    enabled: isAdministrator,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const UserManagementScreen(),
                      ),
                    ),
                  ),
                  _ActionChip(
                    label: 'Acerca de',
                    icon: LucideIcons.info,
                    enabled: true,
                    onPressed: () => _showAboutDialog(context),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Center(
                child: Text(
                  'ETC Inventory · Sistema de gestión y consulta de inventario\n'
                  'Desarrollado por David Álvarez · Software Developer | Flutter & Dart\n'
                  '© ${DateTime.now().year}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.6,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'ETC Inventory',
      applicationLegalese:
          'Sistema de gestión y consulta de inventario\n\n'
          'Desarrollado por David Álvarez\n'
          'Software Developer | Flutter & Dart\n\n'
          '© ${DateTime.now().year}',
      applicationIcon: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Icon(
          LucideIcons.package,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final isAdministrator = user.role == UserRole.administrator;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(
                isAdministrator
                    ? Icons.admin_panel_settings_outlined
                    : Icons.verified_user_outlined,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bienvenido, ${user.username}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isAdministrator
                        ? 'Administrador del sistema'
                        : 'Usuario de consulta',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(title, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: enabled ? onPressed : null,
      backgroundColor: enabled
          ? Theme.of(context).colorScheme.primaryContainer
          : Theme.of(context).colorScheme.surfaceContainerHighest,
    );
  }
}
