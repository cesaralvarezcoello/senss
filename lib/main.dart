import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'state/memory_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Habilita formato de fechas en español (usado por TimeAgo.fullDate).
  await initializeDateFormatting('es');

  runApp(
    ChangeNotifierProvider(
      create: (_) => MemoryProvider()..loadFeed(),
      child: const SenssApp(),
    ),
  );
}
