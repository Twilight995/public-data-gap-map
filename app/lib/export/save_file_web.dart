import 'dart:js_interop';

/// 브라우저의 내려받기 기능으로 글자를 파일로 저장한다.
const saveTextFile = _save;

// 새 패키지(package:web) 없이 필요한 브라우저 기능 두 개만 직접 선언한다.
@JS('document')
external _Document get _document;

extension type _Document._(JSObject _) implements JSObject {
  external _Anchor createElement(String tag);
}

extension type _Anchor._(JSObject _) implements JSObject {
  external set href(String value);
  external set download(String value);
  external void click();
}

void _save(String name, String text) {
  // ponytail: 내용을 주소(data URI)에 통째로 넣는다. 크롬 한도 2MB, 표가 그보다 커지면 Blob 으로 바꾼다.
  _document.createElement('a')
    ..href = 'data:text/csv;charset=utf-8,${Uri.encodeComponent(text)}'
    ..download = name
    ..click();
}
