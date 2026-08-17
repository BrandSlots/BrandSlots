import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

@JS('captureVideoThumbnail')
external void _captureVideoThumbnailJs(JSString url, JSFunction callback);

Future<Uint8List?> captureVideoThumbnailWeb(String url) async {
  final completer = Completer<Uint8List?>();
  _captureVideoThumbnailJs(
    url.toJS,
    ((JSAny? result) {
      if (result == null) {
        completer.complete(null);
        return;
      }
      try {
        // result is a JS Uint8Array
        final jsArr = result as JSUint8Array;
        completer.complete(jsArr.toDart);
      } catch (_) {
        completer.complete(null);
      }
    }).toJS,
  );
  return completer.future;
}
