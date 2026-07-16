import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:senss/app.dart';
import 'package:senss/data/models/person.dart';
import 'package:senss/data/repositories/memory_repository.dart';
import 'package:senss/state/memory_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Repositorio falso: siempre devuelve un feed vacío sin abrir SQLite ni tocar
/// path_provider, para que la app pueda montarse en un test de widgets.
class _EmptyFeedRepository extends MemoryRepository {
  @override
  Future<List<MemoryWithAudios>> getFeed() async => const [];

  @override
  Future<List<Person>> getPeople() async => const [];
}

Future<void> _pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<MemoryProvider>(
      create: (_) => MemoryProvider(repository: _EmptyFeedRepository())
        ..loadFeed(),
      child: const SenssApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Perfil con la bienvenida ya vista, para que arranque en el modo paciente.
  SharedPreferences.setMockInitialValues({
    'senss_profile': jsonEncode(
        {'onboarded': true, 'configured': true, 'name': '', 'age': 1}),
  });

  testWidgets('arranca en el modo paciente y muestra el estado vacío',
      (tester) async {
    await _pumpApp(tester);

    expect(find.text('Aquí vivirán tus recuerdos'), findsOneWidget);
    expect(find.text('Entrar como familia'), findsOneWidget);
  });

  testWidgets('desde el modo paciente se puede entrar al modo familia',
      (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.text('Entrar como familia'));
    await tester.pumpAndSettle();

    // Diálogo de confirmación antes de abrir el modo familia.
    expect(find.text('Modo familia'), findsOneWidget);
    expect(find.text('Entrar'), findsWidgets);
  });
}
