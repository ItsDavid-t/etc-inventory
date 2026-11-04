import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'features/auth/presentation/auth_cubit.dart';
import 'features/auth/presentation/auth_gate.dart';
import 'core/theme/app_theme.dart';

class InventoryApp extends StatelessWidget {
  const InventoryApp({required this.authCubit, super.key});

  final AuthCubit authCubit;

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: authCubit,
      child: MaterialApp(
        title: 'Inventario Etecsa',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.light,
        home: const AuthGate(),
      ),
    );
  }
}
