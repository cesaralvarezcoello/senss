import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// Web: sqflite sobre WASM. Usa la variante **sin web worker** porque el worker
/// compartido necesita SharedArrayBuffer (cabeceras COOP/COEP), que hosts como
/// GitHub Pages no envían. Sin worker corre en el hilo principal y funciona.
Future<void> configureDatabase() async {
  databaseFactory = databaseFactoryFfiWebNoWebWorker;
}

Future<String> databasePath(String name) async => name;
