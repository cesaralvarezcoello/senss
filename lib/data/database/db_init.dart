// Selección del backend de base de datos según la plataforma.
export 'db_init_web.dart' if (dart.library.io) 'db_init_io.dart';
