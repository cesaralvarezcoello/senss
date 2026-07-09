import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// Web: usa sqflite sobre IndexedDB/WASM. La "ruta" es solo un nombre.
Future<void> configureDatabase() async {
  databaseFactory = databaseFactoryFfiWeb;
}

Future<String> databasePath(String name) async => name;
