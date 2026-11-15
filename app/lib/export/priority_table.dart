import '../models/gap_region.dart';

/// 우선순위표의 줄들. 맨 위에 데이터 기준 안내를 넣어, 표만 떼어 가도 한계가 함께 간다.
/// [regions]는 이미 격차가 큰 순으로 정렬돼 있어야 한다(파서가 정렬해 준다).
List<List<Object>> priorityRows(String notice, List<GapRegion> regions) => [
  [notice],
  ['순위는 격차가 큰 순(부족 → 주의 → 양호)입니다. 같은 등급 안에서는 이름순이라 순위 숫자에 우열이 없습니다.'],
  [],
  if (regions.isNotEmpty) ['순위', for (final cell in regions.first.cells) cell.header],
  for (final (i, region) in regions.indexed)
    [i + 1, for (final cell in region.cells) cell.value],
];

final _bom = String.fromCharCode(0xFEFF);

/// 엑셀용 CSV. UTF-8 BOM으로 시작해야 엑셀이 한글을 깨뜨리지 않는다.
String toCsv(List<List<Object>> rows) {
  String cell(Object value) {
    final text = _text(value);
    return RegExp('[,"\r\n]').hasMatch(text)
        ? '"${text.replaceAll('"', '""')}"'
        : text;
  }

  return '$_bom${rows.map((row) => '${row.map(cell).join(',')}\r\n').join()}';
}

/// 클립보드용. 탭으로 칸을 나누면 엑셀에 붙여넣을 때 칸이 나뉜다.
String toTsv(List<List<Object>> rows) {
  // 엑셀은 붙여넣을 때도 따옴표로 시작하는 칸을 "감싼 칸"으로 읽으므로 CSV와 같은 규칙으로 감싼다.
  String cell(Object value) {
    final text = _text(value).replaceAll(RegExp(r'\r\n|[\t\r\n]'), ' ');
    return text.contains('"') ? '"${text.replaceAll('"', '""')}"' : text;
  }

  return rows.map((row) => '${row.map(cell).join('\t')}\n').join();
}

/// 숫자는 그대로(80.0 → 80), 글자는 엑셀이 수식으로 실행하지 않게 막는다.
String _text(Object value) {
  if (value is num) {
    return value.isFinite && value == value.roundToDouble()
        ? value.round().toString()
        : value.toString();
  }
  final text = value.toString();
  // =, +, -, @, 탭, 줄바꿈으로 시작하면 엑셀이 수식으로 본다. 작은따옴표를 붙이면 글자로 읽는다.
  return RegExp(r'^[=+\-@\t\r]').hasMatch(text) ? "'$text" : text;
}
