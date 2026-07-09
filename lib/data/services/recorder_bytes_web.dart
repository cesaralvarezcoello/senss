import 'dart:html' as html;
import 'dart:typed_data';

/// Web: descarga los bytes de la grabación desde su blob URL y devuelve
/// (bytes, mime).
Future<(Uint8List, String)?> fetchRecordingBytes(String url) async {
  final resp = await html.HttpRequest.request(url, responseType: 'blob');
  final blob = resp.response;
  if (blob is! html.Blob) return null;

  final reader = html.FileReader();
  reader.readAsArrayBuffer(blob);
  await reader.onLoadEnd.first;

  final result = reader.result;
  final Uint8List bytes;
  if (result is ByteBuffer) {
    bytes = result.asUint8List();
  } else if (result is Uint8List) {
    bytes = result;
  } else {
    return null;
  }
  return (bytes, blob.type);
}
