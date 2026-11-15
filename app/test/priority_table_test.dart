import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gap_map/export/priority_table.dart';
import 'package:gap_map/export/save_file.dart';
import 'package:gap_map/models/gap_region.dart';
import 'package:gap_map/screens/region_list_screen.dart';
import 'package:material_ui/material_ui.dart';

const _libraryJson = '''
{"regions": [
 {"sido": "경기도", "sigungu": "수원시", "total": 20, "hub": 8, "local": 12, "readOnly": 0,
  "suspect": 0, "weekendClosedPct": 10.0, "level": "green", "reason": "양호 이유"},
 {"sido": "인천광역시", "sigungu": "강화군", "total": 1, "hub": 0, "local": 1, "readOnly": 0,
  "suspect": 0, "weekendClosedPct": 0.0, "level": "red", "reason": "대형 거점 도서관이 없습니다."},
 {"sido": "강원특별자치도", "sigungu": "양양군", "total": 5, "hub": 1, "local": 0, "readOnly": 4,
  "suspect": 0, "weekendClosedPct": 80.5, "level": "orange", "reason": "주의 이유"}
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

GapRegion _region(List<ExportCell> cells) => GapRegion(
  id: 'x',
  title: 'x',
  subtitle: 'x',
  level: GapLevel.red,
  reason: 'x',
  stats: const [],
  cells: cells,
);

final bom = String.fromCharCode(0xFEFF);

void main() {
  group('priorityRows', () {
    test('맨 위에 데이터 기준 안내와 정렬 설명이 먼저 나온다', () {
      final rows = priorityRows('등록 기준 안내', parseLibraries(_libraryJson));

      expect(rows[0], ['등록 기준 안내']);
      expect(rows[1].single, contains('같은 등급 안에서는 이름순'));
      expect(rows[2], isEmpty);
    });

    test('도서관: 열 순서가 고정이고 수치는 단위 없는 숫자다', () {
      final rows = priorityRows('안내', parseLibraries(_libraryJson));

      expect(rows[3], [
        '순위',
        '시도',
        '시군구',
        '등급',
        '이유',
        '전체 도서관(곳)',
        '대형 거점 도서관(곳)',
        '동네 작은도서관(곳)',
        '열람 전용 도서관(곳)',
        '입력 오류 의심(곳)',
        '주말 전면 휴관 비율(%)',
      ]);
      expect(rows[4], [
        1, '인천광역시', '강화군', '부족', '대형 거점 도서관이 없습니다.', 1, 0, 1, 0, 0, 0.0, //
      ]);
    });

    test('격차가 큰 순(부족 → 주의 → 양호)으로 순위가 매겨진다', () {
      final rows = priorityRows('안내', parseLibraries(_libraryJson));

      expect(
        [for (final row in rows.skip(4)) '${row[0]} ${row[2]} ${row[3]}'],
        ['1 강화군 부족', '2 양양군 주의', '3 수원시 양호'],
      );
    });

    test('금연: 시도만 있고 전국 평균이 열로 함께 나온다', () {
      final rows = priorityRows('안내', parseSmoking(_smokingJson));

      expect(rows[3], [
        '순위',
        '시도',
        '등급',
        '이유',
        '등록자(명)',
        '고의존자(명)',
        '고의존자 비율(%)',
        '전국 고의존자 비율(%)',
        '금연캠프 이용(건)',
        '고의존자 1,000명당 캠프 이용(건)',
        '전국 고의존자 1,000명당 캠프 이용(건)',
        '금연 지원 기관(곳)',
        '기관 1곳당 등록자(명)',
      ]);
      expect(rows[4], [
        1, '대구광역시', '부족', '부족 이유', 12023, 2625, 21.8, 17.8, 325, 124, 160, 10, 1202, //
      ]);
    });
  });

  group('toCsv', () {
    test('한글이 엑셀에서 깨지지 않게 UTF-8 BOM으로 시작하고 줄은 CRLF로 끝난다', () {
      expect(
        toCsv([
          ['가', 1],
          ['나', 2.5],
        ]),
        '$bom가,1\r\n나,2.5\r\n',
      );
    });

    test('쉼표·따옴표·줄바꿈이 든 값은 따옴표로 감싸고 따옴표는 두 번 쓴다', () {
      expect(
        toCsv([
          ['a,b', 'say "hi"', 'line1\nline2'],
        ]),
        '$bom"a,b","say ""hi""","line1\nline2"\r\n',
      );
    });

    test('수식으로 실행될 수 있는 글자로 시작하는 값은 작은따옴표를 앞에 붙인다', () {
      expect(
        toCsv([
          ['=1+1', '+82', '-cmd', '@SUM(A1)', '\t=1'],
        ]),
        "$bom'=1+1,'+82,'-cmd,'@SUM(A1),'\t=1\r\n",
      );
    });

    test('숫자는 음수여도 그대로 두고, 소수점 0은 정수로 쓴다', () {
      expect(
        toCsv([
          [-3, 0.0, 80.5],
        ]),
        '$bom-3,0,80.5\r\n',
      );
    });

    test('실제 표에도 적용된다: 안내 줄의 쉼표가 감싸진다', () {
      final csv = toCsv(priorityRows('기준(2026-10)이라, 빠질 수 있음', const []));

      expect(csv, startsWith('$bom"기준(2026-10)이라, 빠질 수 있음"\r\n'));
    });
  });

  group('toTsv', () {
    test('탭으로 칸을 나누고, 탭·줄바꿈은 빈칸으로 바꾸고, 따옴표가 든 값은 감싼다', () {
      expect(
        toTsv([
          ['a\tb', 'line1\r\nline2', 3],
          ['=1', 'say "hi"', 0.0],
        ]),
        "a b\tline1 line2\t3\n'=1\t\"say \"\"hi\"\"\"\t0\n",
      );
    });
  });

  group('내보내기 버튼', () {
    final regions = [
      _region([(header: '시도', value: '가도')]),
      _region([(header: '시도', value: '나도')]),
    ];

    Widget screen({SaveFile? saveFile}) => MaterialApp(
      home: Scaffold(
        body: RegionListScreen(
          load: () async => regions,
          notice: '등록 기준 안내',
          exportName: '도서관_우선순위표',
          saveFile: saveFile,
        ),
      ),
    );

    void mockClipboard(
      WidgetTester tester,
      Future<Object?> Function(MethodCall call) handler,
    ) {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        handler,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
    }

    testWidgets('복사하기를 누르면 안내 줄이 든 표가 복사되고 완료 문구가 뜬다', (tester) async {
      String? copied;
      mockClipboard(tester, (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      });
      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('우선순위표 복사하기'));
      await tester.pump();

      expect(copied, toTsv(priorityRows('등록 기준 안내', regions)));
      expect(copied, startsWith('등록 기준 안내\n'));
      expect(find.text('우선순위표 2개 지역을 복사했습니다. 엑셀에 붙여넣으세요.'), findsOneWidget);
    });

    testWidgets('복사에 실패하면 이유를 알리고 다시 시도할 수 있다', (tester) async {
      var calls = 0;
      mockClipboard(tester, (call) async {
        if (call.method != 'Clipboard.setData') return null;
        calls++;
        if (calls == 1) throw PlatformException(code: 'denied');
        return null;
      });
      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('우선순위표 복사하기'));
      await tester.pumpAndSettle();

      expect(find.textContaining('복사하지 못했습니다'), findsOneWidget);

      await tester.tap(find.text('다시 시도'));
      await tester.pumpAndSettle();

      expect(calls, 2);
      expect(find.textContaining('복사했습니다'), findsOneWidget);
    });

    testWidgets('파일을 저장할 수 없는 곳(안드로이드)에서는 내려받기 버튼이 없다', (tester) async {
      // 테스트는 안드로이드와 같은 Dart VM에서 돌므로, 조건부 가져오기가 고른 값이 null 이어야 한다.
      expect(saveTextFile, isNull);
      await tester.pumpWidget(screen(saveFile: saveTextFile));
      await tester.pumpAndSettle();

      expect(find.text('CSV 파일로 내려받기'), findsNothing);
    });

    testWidgets('내려받기를 누르면 CSV가 파일로 넘어가고 완료 문구가 뜬다', (tester) async {
      String? savedName;
      String? savedText;
      await tester.pumpWidget(
        screen(
          saveFile: (name, text) {
            savedName = name;
            savedText = text;
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('CSV 파일로 내려받기'));
      await tester.pump();

      expect(savedName, '도서관_우선순위표.csv');
      expect(savedText, toCsv(priorityRows('등록 기준 안내', regions)));
      expect(find.textContaining('도서관_우선순위표.csv'), findsOneWidget);
    });

    testWidgets('복사가 끝나지 않으면 10초 뒤 실패로 알린다', (tester) async {
      mockClipboard(tester, (call) => Completer<Object?>().future);
      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('우선순위표 복사하기'));
      await tester.pump(const Duration(seconds: 10));
      await tester.pump();

      expect(find.textContaining('복사하지 못했습니다'), findsOneWidget);
    });

    testWidgets('내려받기에 실패하면 이유를 알리고 다시 시도할 수 있다', (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        screen(
          saveFile: (name, text) {
            calls++;
            if (calls == 1) throw StateError('blocked');
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('CSV 파일로 내려받기'));
      await tester.pumpAndSettle();

      expect(find.textContaining('내려받지 못했습니다'), findsOneWidget);

      await tester.tap(find.text('다시 시도'));
      await tester.pumpAndSettle();

      expect(calls, 2);
      expect(find.textContaining('내려받기를 시작했습니다'), findsOneWidget);
    });
  });
}
