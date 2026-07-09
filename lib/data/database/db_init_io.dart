import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Nativo: sqflite por defecto ya funciona; la base vive en un archivo dentro
/// del almacenamiento de la app.
Future<void> configureDatabase() async {}

Future<String> databasePath(String name) async {
  final dir = await getApplicationDocumentsDirectory();
  return p.join(dir.path, name);
}
