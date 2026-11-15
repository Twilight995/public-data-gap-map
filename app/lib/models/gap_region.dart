import 'dart:convert';

/// 격차 등급. 판정 규칙은 tools/build_app_data.py 에만 있고, 앱은 결과만 읽는다.
enum GapLevel {
  red('부족'),
  orange('주의'),
  green('양호');

  const GapLevel(this.label);
  final String label;
}

typedef RegionStat = ({String label, String value});

/// 목록과 상세 화면이 함께 쓰는 지역 한 곳의 표시용 데이터.
class GapRegion {
  const GapRegion({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.level,
    required this.reason,
    required this.stats,
  });

  /// 지도 구역과 연결하는 키. 도서관은 "시도 시군구", 금연은 시도 이름.
  final String id;
  final String title;
  final String subtitle;
  final GapLevel level;
  final String reason;
  final List<RegionStat> stats;
}

List<GapRegion> parseLibraries(String json) => _parse(json, (data) {
  return [
    for (final Map<String, dynamic> r in data['regions'])
      GapRegion(
        id: '${r['sido']} ${r['sigungu']}',
        title: r['sigungu'],
        subtitle: r['sido'],
        level: GapLevel.values.byName(r['level']),
        reason: r['reason'],
        stats: [
          (label: '전체 도서관', value: '${_count(r['total'])}곳'),
          (label: '대형 거점 도서관', value: '${_count(r['hub'])}곳'),
          (label: '동네 작은도서관', value: '${_count(r['local'])}곳'),
          (label: '열람 전용 도서관', value: '${_count(r['readOnly'])}곳'),
          (label: '입력 오류 의심', value: '${_count(r['suspect'])}곳'),
          (label: '주말 전면 휴관 비율', value: '${_decimal(r['weekendClosedPct'])}%'),
        ],
      ),
  ];
});

List<GapRegion> parseSmoking(String json) => _parse(json, (data) {
  final Map<String, dynamic> national = data['national'];
  return [
    for (final Map<String, dynamic> r in data['regions'])
      GapRegion(
        id: r['sido'],
        title: r['sido'],
        subtitle: '등록자 ${_count(r['registered'])}명',
        level: GapLevel.values.byName(r['level']),
        reason: r['reason'],
        stats: [
          (label: '등록자', value: '${_count(r['registered'])}명'),
          (label: '고의존자', value: '${_count(r['high'])}명'),
          (
            label: '고의존자 비율',
            value:
                '${_decimal(r['highPct'])}% (전국 ${_decimal(national['highPct'])}%)',
          ),
          (label: '금연캠프 이용', value: '${_count(r['camp'])}건'),
          (
            label: '고의존자 1,000명당 캠프 이용',
            value:
                '${_count(r['campPer1000'])}건 (전국 ${_count(national['campPer1000'])}건)',
          ),
          (label: '금연 지원 기관', value: '${_count(r['orgs'])}곳'),
          (label: '기관 1곳당 등록자', value: '${_count(r['perOrg'])}명'),
        ],
      ),
  ];
});

/// JSON을 읽어 격차가 큰 순(부족 → 주의 → 양호), 같은 등급은 이름순, 이름도 같으면 부제(시도)순으로 돌려준다.
/// 모양이 다른 데이터는 전부 FormatException 하나로 모아 화면이 한 가지만 처리하게 한다.
List<GapRegion> _parse(
  String json,
  List<GapRegion> Function(Map<String, dynamic> data) build,
) {
  try {
    final regions = build(jsonDecode(json) as Map<String, dynamic>);
    return regions..sort((a, b) {
      final byLevel = a.level.index.compareTo(b.level.index);
      if (byLevel != 0) return byLevel;
      final byTitle = a.title.compareTo(b.title);
      return byTitle != 0 ? byTitle : a.subtitle.compareTo(b.subtitle);
    });
  } on FormatException {
    rethrow;
  } on Error catch (e) {
    // 빠진 필드(TypeError), 모르는 등급 값(ArgumentError)
    throw FormatException('지역 데이터 형식이 올바르지 않습니다: $e');
  }
}

/// 12023 → "12,023"
String _count(num n) => n.round().toString().replaceAllMapped(
  RegExp(r'\B(?=(\d{3})+(?!\d))'),
  (_) => ',',
);

/// 80.0 → "80", 21.8 → "21.8"
String _decimal(num n) =>
    n == n.roundToDouble() ? n.round().toString() : n.toStringAsFixed(1);
