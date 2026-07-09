// Lee los bytes de una grabación. Solo hace algo en web (blob URL); en nativo
// devuelve null (allí se graba directo a archivo).
export 'recorder_bytes_web.dart' if (dart.library.io) 'recorder_bytes_stub.dart';
