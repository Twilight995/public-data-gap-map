// 파일 저장은 브라우저에서만 된다. 안드로이드에서는 null 이라 내려받기 버튼을 숨긴다.
export 'save_file_stub.dart' if (dart.library.js_interop) 'save_file_web.dart';
