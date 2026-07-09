import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'state/memory_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // La inicialización de fechas no debe impedir que la app arranque.
  try {
    await initializeDateFormatting('es');
  } catch (_) {}

  runApp(
    ChangeNotifierProvider(
      create: (_) => MemoryProvider()..loadFeed(),
      child: const SenssApp(),
    ),
  );
}
