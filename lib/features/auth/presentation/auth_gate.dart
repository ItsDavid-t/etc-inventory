import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../inventory_dashboard_screen.dart';
import 'auth_cubit.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) => switch (state.status) {
        AuthStatus.checking => const _LoadingScreen(),
        AuthStatus.setupRequired => const InitialAdministratorScreen(),
        AuthStatus.signedOut => LoginScreen(message: state.message),
        AuthStatus.authenticated => InventoryDashboardScreen(user: state.user!),
        AuthStatus.failure => _StartupFailureScreen(message: state.message),
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({this.message, super.key});

  final String? message;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _AuthCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _BrandHeader(
                  title: 'Inventario ETECSA',
                  subtitle: 'Gestión local de equipos',
                ),
                const SizedBox(height: 28),
                TextField(
                  controller: _usernameController,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.username],
                  decoration: const InputDecoration(
                    labelText: 'Usuario',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  onSubmitted: (_) => _signIn(),
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                ),
                if (widget.message != null) ...[
                  const SizedBox(height: 16),
                  _InlineMessage(widget.message!),
                ],
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _signIn,
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('Ingresar'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _signIn() {
    context.read<AuthCubit>().signIn(
      username: _usernameController.text,
      password: _passwordController.text,
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

class InitialAdministratorScreen extends StatefulWidget {
  const InitialAdministratorScreen({super.key});

  @override
  State<InitialAdministratorScreen> createState() =>
      _InitialAdministratorScreenState();
}

class _InitialAdministratorScreenState
    extends State<InitialAdministratorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _AuthCard(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _BrandHeader(
                    title: 'Configuración inicial',
                    subtitle: 'Crea la única cuenta administradora',
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _usernameController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Usuario administrador',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (value) {
                      final username = value?.trim() ?? '';
                      if (!RegExp(r'^[A-Za-z0-9._-]{3,32}$')
                          .hasMatch(username)) {
                        return 'Usa de 3 a 32 letras, números, punto, guion o guion bajo.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Contraseña (mínimo 12 caracteres)',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    validator: (value) {
                      final password = value ?? '';
                      if (password.length < 12 ||
                          password.length > 72 ||
                          password.runes.length != password.length) {
                        return 'Debe tener al menos 12 caracteres y hasta 72 bytes UTF-8.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmationController,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    decoration: const InputDecoration(
                      labelText: 'Confirmar contraseña',
                      prefixIcon: Icon(Icons.lock_reset_outlined),
                    ),
                    validator: (value) {
                      if (value != _passwordController.text) {
                        return 'Las contraseñas no coinciden.';
                      }
                      return null;
                    },
                  ),
                  BlocBuilder<AuthCubit, AuthState>(
                    buildWhen: (previous, current) =>
                        previous.message != current.message,
                    builder: (context, state) => state.message == null
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: _InlineMessage(state.message!),
                          ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.admin_panel_settings_outlined),
                    label: const Text('Crear administrador'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
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

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<AuthCubit>().createInitialAdministrator(
      username: _usernameController.text.trim(),
      password: _passwordController.text,
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class _StartupFailureScreen extends StatelessWidget {
  const _StartupFailureScreen({required this.message});

  final String? message;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 16),
            Text(message ?? 'No se pudo iniciar la aplicación.'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.read<AuthCubit>().checkInitialSetup(),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _AuthCard extends StatelessWidget {
  const _AuthCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    elevation: 3,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: Padding(padding: const EdgeInsets.all(28), child: child),
    ),
  );
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const Icon(
        Icons.inventory_2_outlined,
        size: 68,
        color: Color(0xFF0B5DA9),
      ),
      const SizedBox(height: 16),
      Text(
        title,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineSmall
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      Text(subtitle, textAlign: TextAlign.center),
    ],
  );
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      message,
      style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
    ),
  );
}
