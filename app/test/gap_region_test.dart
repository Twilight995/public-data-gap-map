import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gap_map/models/gap_region.dart';

const _libraryJson = '''
{"regions": [
 {"sido": "경기도", "sigungu": "수원시", "total": 20, "hub": 8, "local": 12, "readOnly": 0,
  "suspect": 0, "weekendClosedPct": 10.0, "level": "green", "reason": "양호 이유"},
 {"sido": "인천광역시", "sigungu": "강화군", "total": 1, "hub": 0, "local": 1, "readOnly": 0,
  "suspect": 0, "weekendClosedPct": 0.0, "level": "red", "reason": "대형 거점 도서관이 없습니다."},
 {"sido": "강원특별자치도", "sigungu": "양양군", "total": 5, "hub": 1, "local": 0, "readOnly": 4,
  "suspect": 0, "weekendClosedPct": 80.0, "level": "orange", "reason": "주의 이유"}
]}
''';

const _smokingJson = '''
{"national": {"highPct": 17.8, "campPer1000": 160}, "regions": [
 {"sido": "울산광역시", "registered": 6183, "high": 881, "highPct": 14.2, "camp": 450,
  "campPer1000": 511, "orgs": 6, "perOrg": 1030, "level": "green", "reason": "양호 이유"},
 {"sido": "대구광역시", "registered": 12023, "high": 2625, "highPct": 21.8, "camp": 325,
  "campPer1000": 124, "orgs": 10, "perOrg": 1202, "level": "red", "reason": "부족 이유"}
]}
''';

void main() {
  group('parseLibraries', () {
    test('격차가 큰 지역이 먼저 온다 (부족 → 주의 → 양호)', () {
      final regions = parseLibraries(_libraryJson);

      expect(regions.map((r) => r.title), ['강화군', '양양군', '수원시']);
      expect(regions.first.level, GapLevel.red);
      expect(regions.first.subtitle, '인천광역시');
    });

    test('상세 항목에 유형별 도서관 수와 주말 휴관 비율이 들어간다', () {
      final yangyang = parseLibraries(_libraryJson)[1];
      final stats = {for (final s in yangyang.stats) s.label: s.value};

      expect(stats['대형 거점 도서관'], '1곳');
      expect(stats['열람 전용 도서관'], '4곳');
      expect(stats['주말 전면 휴관 비율'], '80%');
    });

    test('깨진 JSON이면 FormatException을 던진다', () {
      expect(() => parseLibraries('{not json'), throwsFormatException);
    });

    test('모르는 등급 값이면 FormatException을 던진다', () {
      final bad = _libraryJson.replaceFirst('"green"', '"purple"');
      expect(() => parseLibraries(bad), throwsFormatException);
    });

    test('등급과 이름이 같으면 시도 이름순이다 (중구가 여러 시도에 있다)', () {
      String junggu(String sido) =>
          '{"sido": "$sido", "sigungu": "중구", "total": 9, "hub": 3, "local": 6, "readOnly": 0, '
          '"suspect": 0, "weekendClosedPct": 0.0, "level": "green", "reason": "r"}';
      final json = '{"regions": [${junggu('서울특별시')}, ${junggu('부산광역시')}, ${junggu('대구광역시')}]}';

      expect(parseLibraries(json).map((r) => r.subtitle), ['대구광역시', '부산광역시', '서울특별시']);
    });

    test('실제 데이터 파일은 중복 없이 229개 지역이다', () {
      final regions = parseLibraries(File('assets/data/libraries.json').readAsStringSync());

      expect(regions, hasLength(229));
      expect({for (final r in regions) '${r.subtitle} ${r.title}'}, hasLength(229));
    });
  });

  group('parseSmoking', () {
    test('부족 지역이 먼저 오고 전국 평균을 함께 보여준다', () {
      final regions = parseSmoking(_smokingJson);
      final stats = {for (final s in regions.first.stats) s.label: s.value};

      expect(regions.map((r) => r.title), ['대구광역시', '울산광역시']);
      expect(stats['고의존자 비율'], '21.8% (전국 17.8%)');
      expect(stats['고의존자 1,000명당 캠프 이용'], '124건 (전국 160건)');
      expect(stats['등록자'], '12,023명');
    });

    test('실제 데이터 파일은 17개 시도다', () {
      final json = File('assets/data/smoking.json').readAsStringSync();
      expect(parseSmoking(json), hasLength(17));
    });
  });
}
