import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:senss/app.dart';
import 'package:senss/data/repositories/memory_repository.dart';
import 'package:senss/state/memory_provider.dart';

/// Repositorio falso: siempre devuelve un feed vacío sin abrir SQLite ni tocar
/// path_provider, para que la app pueda montarse en un test de widgets.
class _EmptyFeedRepository extends MemoryRepository {
  @override
  Future<List<MemoryWithAudios>> getFeed() async => const [];
}

/// Monta la app real con un provider respaldado por el repositorio falso.
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
  testWidgets('arranca y muestra el estado vacío del feed', (tester) async {
    await _pumpApp(tester);

    // Barra superior con el nombre y el acceso a copia de seguridad.
    expect(find.text('senss'), findsOneWidget);
    expect(find.byTooltip('Copia de seguridad'), findsOneWidget);

    // Estado vacío y llamada a la acción.
    expect(find.text('Aún no hay recuerdos'), findsOneWidget);
    expect(find.text('Crear mi primer recuerdo'), findsOneWidget);

    // Botón flotante para crear un recuerdo.
    expect(find.text('Nuevo recuerdo'), findsOneWidget);
  });

  testWidgets('el icono de escudo abre la pantalla de copia de seguridad',
      (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.byTooltip('Copia de seguridad'));
    await tester.pumpAndSettle();

    expect(find.text('Copia de seguridad'), findsOneWidget); // título AppBar
    expect(find.text('Crear copia'), findsOneWidget);
    expect(find.text('Restaurar'), findsOneWidget);
  });
}
