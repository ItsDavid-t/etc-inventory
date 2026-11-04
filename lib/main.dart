import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/di/injection.dart';
import 'features/auth/presentation/auth_cubit.dart';
import 'inventory_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  configureDependencies();
  final authCubit = getIt<AuthCubit>();
  await authCubit.checkInitialSetup();
  runApp(InventoryApp(authCubit: authCubit));
}
