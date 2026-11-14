import 'dart:convert';
import 'dart:ui' show Offset, Size;

/// 지도의 구역 한 개. 좌표는 tools/build_map_data.py 가 미리 화면용으로 바꿔 둔 값이다.
class MapShape {
  const MapShape({
    required this.name,
    required this.libraryId,
    required this.smokingId,
    required this.rings,
  });

  final String name;

  /// 도서관 데이터의 지역 id. 맞는 지역이 없으면 null.
  final String? libraryId;

  /// 금연 데이터의 지역 id(시도 이름).
  final String smokingId;

  /// 테두리 여러 개(본토 + 섬). 각 테두리는 꼭짓점 목록.
  final List<List<Offset>> rings;
}

class MapData {
  const MapData({required this.size, required this.source, required this.shapes});

  final Size size;
  final String source;
  final List<MapShape> shapes;
}

MapData parseMap(String json) {
  try {
    final data = jsonDecode(json) as Map<String, dynamic>;
    return MapData(
      size: Size((data['width'] as num).toDouble(), (data['height'] as num).toDouble()),
      source: data['source'],
      shapes: [
        for (final Map<String, dynamic> s in data['shapes'])
          MapShape(
            name: s['name'],
            libraryId: s['library'],
            smokingId: s['smoking'],
            rings: [
              for (final List<dynamic> flat in s['rings'])
                [
                  for (var i = 0; i < flat.length; i += 2)
                    Offset((flat[i] as num).toDouble(), (flat[i + 1] as num).toDouble()),
                ],
            ],
          ),
      ],
    );
  } on FormatException {
    rethrow;
  } on Error catch (e) {
    throw FormatException('지도 데이터 형식이 올바르지 않습니다: $e');
  }
}
