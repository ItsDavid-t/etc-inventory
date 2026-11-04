import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../domain/app_user.dart';
import '../domain/auth_repository.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final AuthRepository _authRepository = GetIt.instance<AuthRepository>();

  bool _isLoading = true;
  String? _error;
  List<AppUser> _users = const [];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await _authRepository.listUsers();

    if (!mounted) return;

    result.match(
      (failure) {
        setState(() {
          _error = failure.message;
          _isLoading = false;
        });
      },
      (users) {
        setState(() {
          _users = users;
          _isLoading = false;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Usuarios'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _loadUsers,
            icon: const Icon(Icons.refresh_outlined),
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createViewer,
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: const Text('Nuevo usuario'),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadUsers,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (_users.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No hay usuarios registrados.'),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _users.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final user = _users[index];
        final isAdministrator = user.role == UserRole.administrator;

        return Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: isAdministrator
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).colorScheme.secondaryContainer,
                  child: Icon(
                    isAdministrator
                        ? Icons.admin_panel_settings_outlined
                        : Icons.person_outline,
                    color: isAdministrator
                        ? Theme.of(context).colorScheme.onPrimaryContainer
                        : Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.username,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isAdministrator
                            ? 'Administrador'
                            : 'Usuario de consulta',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 4),
                      _StatusChip(
                        isActive: user.isActive,
                        isAdministrator: isAdministrator,
                      ),
                    ],
                  ),
                ),
                if (!isAdministrator) ...[
                  Switch(
                    value: user.isActive,
                    onChanged: (_) => _toggleViewerStatus(user),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Restablecer contraseña',
                    onPressed: () => _resetViewerPassword(user),
                    icon: const Icon(Icons.lock_reset_outlined),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _toggleViewerStatus(AppUser user) async {
    final result = await _authRepository.setViewerActive(
      userId: user.id,
      isActive: !user.isActive,
    );

    if (!mounted) return;

    result.match(
      (failure) => _showMessage(failure.message),
      (_) async => _loadUsers(),
    );
  }

  Future<void> _resetViewerPassword(AppUser user) async {
    final password = await _showPasswordDialog(user.username);
    if (password == null || password.isEmpty) return;

    final result = await _authRepository.resetViewerPassword(
      userId: user.id,
      newPassword: password,
    );

    if (!mounted) return;

    result.match((failure) => _showMessage(failure.message), (_) {
      _showMessage('Contraseña restablecida para ${user.username}.');
    });
  }

  Future<void> _createViewer() async {
    final draft = await _showCreateViewerDialog();
    if (draft == null) return;

    final result = await _authRepository.createViewer(
      username: draft.username,
      initialPassword: draft.password,
    );

    if (!mounted) return;

    result.match((failure) => _showMessage(failure.message), (_) async {
      _showMessage('Usuario de consulta creado correctamente.');
      await _loadUsers();
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<_UserDraft?> _showCreateViewerDialog() {
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return showDialog<_UserDraft>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nuevo usuario de consulta'),
        content: Form(
          key: formKey,
          child: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: usernameController,
                  decoration: const InputDecoration(labelText: 'Usuario'),
                  validator: (value) {
                    final username = value?.trim() ?? '';
                    if (!RegExp(r'^[A-Za-z0-9._-]{3,32}$').hasMatch(username)) {
                      return 'Usa de 3 a 32 caracteres válidos.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Contraseña temporal',
                  ),
                  validator: (value) {
                    final password = value ?? '';
                    if (password.length < 12 || password.length > 72) {
                      return 'Debe tener entre 12 y 72 caracteres.';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.of(dialogContext).pop(
                _UserDraft(
                  username: usernameController.text.trim(),
                  password: passwordController.text,
                ),
              );
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }

  Future<String?> _showPasswordDialog(String username) {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restablecer contraseña'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'Nueva contraseña para $username',
            ),
            validator: (value) {
              final password = value ?? '';
              if (password.length < 12 || password.length > 72) {
                return 'Debe tener entre 12 y 72 caracteres.';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.of(dialogContext).pop(controller.text);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.isActive, required this.isAdministrator});

  final bool isActive;
  final bool isAdministrator;

  @override
  Widget build(BuildContext context) {
    final label = isAdministrator
        ? 'Administrador'
        : isActive
        ? 'Activo'
        : 'Inactivo';
    final color = isAdministrator
        ? Theme.of(context).colorScheme.primary
        : isActive
        ? Colors.green
        : Colors.orange;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium
            ?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _UserDraft {
  const _UserDraft({required this.username, required this.password});

  final String username;
  final String password;
}
