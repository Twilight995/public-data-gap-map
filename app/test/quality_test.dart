import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gap_map/main.dart';
import 'package:gap_map/models/quality_data.dart';
import 'package:gap_map/screens/quality_screen.dart';
import 'package:material_ui/material_ui.dart';

const _notice = '원본 데이터에서 확인이 필요한 곳입니다.';

QualityData _data(List<QualitySection> sections) =>
    QualityData(notice: _notice, sections: sections);

const _sections = [
  QualitySection(
    title: '입력 오류가 의심되는 도서관',
    count: '1개 지역 · 도서관 2곳',
    description: '대출 한도 칸에 천 권 이상이 적힌 도서관입니다.',
    items: [
      QualityItem(
        title: '경상남도 진주시',
        summary: '도서관 2곳의 1인 대출 한도가 1,000권~8,400권으로 적혀 있습니다. 원본 값을 확인해 주세요.',
        details: ['채움 작은도서관 (작은도서관) · 1인 대출 한도 8,400권', '진주은평도서관 (작은도서관) · 1인 대출 한도 1,000권'],
      ),
    ],
  ),
  QualitySection(
    title: '등록 도서관이 1곳뿐인 지역',
    count: '1개 지역',
    description: '실제로 1곳인지 등록이 빠진 것인지 알 수 없습니다.',
    items: [
      QualityItem(
        title: '경상북도 울릉군',
        summary: '등록된 도서관이 1곳입니다.',
        details: [],
      ),
    ],
  ),
];

Widget _screen(Future<QualityData> Function() load) =>
    MaterialApp(home: Scaffold(body: QualityScreen(load: load)));

void main() {
  group('parseQuality', () {
    test('앱에 든 실제 파일을 읽는다: 구역마다 제목·건수·설명·항목이 있다', () {
      final data = parseQuality(
        File('assets/data/quality.json').readAsStringSync(),
      );
      final sections = data.sections;

      expect(data.notice, contains('전국도서관표준데이터'));

      expect(sections, hasLength(5));
      for (final section in sections) {
        expect(section.title, isNotEmpty);
        expect(section.count, isNotEmpty);
        expect(section.description, isNotEmpty);
        expect(section.items, isNotEmpty);
      }
      final jinju = sections
          .expand((s) => s.items)
          .firstWhere((i) => i.details.length == 73);
      expect(jinju.title, '경상남도 진주시');
    });

    test('경고가 없으면 빈 목록이다', () {
      expect(
        parseQuality('{"notice": "안내", "sections": []}').sections,
        isEmpty,
      );
    });

    test('깨진 데이터면 FormatException을 던진다', () {
      expect(() => parseQuality('{"sections": 1}'), throwsFormatException);
      expect(
        () => parseQuality('{"notice": "안내", "sections": [{"title": "제목"}]}'),
        throwsFormatException,
      );
      expect(() => parseQuality('{"sections": []}'), throwsFormatException);
    });
  });

  group('QualityScreen', () {
    testWidgets('로딩 상태: 불러오는 동안 진행 표시가 보인다', (tester) async {
      final pending = Completer<QualityData>();
      await tester.pumpWidget(_screen(() => pending.future));

      expect(find.text('불러오는 중입니다'), findsOneWidget);
    });

    testWidgets('오류 상태: 실패 문구가 보이고 다시 시도하면 목록이 뜬다', (tester) async {
      var calls = 0;
      Future<QualityData> load() async {
        calls++;
        if (calls == 1) throw const FormatException('broken');
        return _data(_sections);
      }

      await tester.pumpWidget(_screen(load));
      await tester.pumpAndSettle();
      expect(find.text('데이터를 불러오지 못했습니다'), findsOneWidget);

      await tester.tap(find.text('다시 시도'));
      await tester.pumpAndSettle();
      expect(find.text('경상남도 진주시'), findsOneWidget);
    });

    testWidgets('빈 상태: 경고가 없으면 지역 목록과 다른 전용 문구가 보인다', (tester) async {
      await tester.pumpWidget(_screen(() async => _data([])));
      await tester.pumpAndSettle();

      expect(find.text('확인이 필요한 데이터 품질 경고가 없습니다'), findsOneWidget);
      expect(find.text('표시할 지역이 없습니다'), findsNothing);
    });

    testWidgets('정상 상태: 구역 제목·건수·설명과 지역별 경고 문구가 보인다', (tester) async {
      await tester.pumpWidget(_screen(() async => _data(_sections)));
      await tester.pumpAndSettle();

      expect(find.text(_notice), findsOneWidget);
      expect(find.text('입력 오류가 의심되는 도서관'), findsOneWidget);
      expect(find.text('1개 지역 · 도서관 2곳'), findsOneWidget);
      expect(find.text('대출 한도 칸에 천 권 이상이 적힌 도서관입니다.'), findsOneWidget);
      expect(find.text('경상남도 진주시'), findsOneWidget);
      expect(find.textContaining('원본 값을 확인해 주세요'), findsOneWidget);
      expect(find.text('경상북도 울릉군'), findsOneWidget);
    });

    testWidgets('지역을 누르면 도서관 이름이 펼쳐지고, 다시 누르면 접힌다', (tester) async {
      await tester.pumpWidget(_screen(() async => _data(_sections)));
      await tester.pumpAndSettle();
      expect(find.textContaining('채움 작은도서관'), findsNothing);

      await tester.tap(find.text('경상남도 진주시'));
      await tester.pumpAndSettle();
      expect(find.textContaining('채움 작은도서관'), findsOneWidget);
      expect(find.textContaining('진주은평도서관'), findsOneWidget);

      await tester.tap(find.text('경상남도 진주시'));
      await tester.pumpAndSettle();
      expect(find.textContaining('채움 작은도서관'), findsNothing);
    });

    testWidgets('펼친 지역은 화면 밖으로 스크롤했다 돌아와도 펼쳐져 있다', (tester) async {
      final many = [
        _sections[0],
        QualitySection(
          title: '긴 구역',
          count: '40개 지역',
          description: '설명',
          items: [
            for (var i = 0; i < 40; i++)
              QualityItem(title: '지역 $i', summary: '요약', details: const []),
          ],
        ),
      ];
      await tester.pumpWidget(_screen(() async => _data(many)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('경상남도 진주시'));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ListView), const Offset(0, -2500));
      await tester.pumpAndSettle();
      expect(find.text('경상남도 진주시'), findsNothing);
      await tester.drag(find.byType(ListView), const Offset(0, 2500));
      await tester.pumpAndSettle();

      expect(find.textContaining('채움 작은도서관'), findsOneWidget);
    });

    testWidgets('같은 지역이 두 구역에 있어도 누른 쪽만 펼쳐진다', (tester) async {
      final twice = [
        _sections[0],
        QualitySection(
          title: '지역 이름을 고치거나 합친 지역',
          count: '1개 지역',
          description: '설명',
          items: [
            QualityItem(
              title: _sections[0].items[0].title,
              summary: '원본 2행을 합쳤습니다.',
              details: const ['원본 표기 줄'],
            ),
          ],
        ),
      ];
      await tester.pumpWidget(_screen(() async => _data(twice)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('경상남도 진주시').first);
      await tester.pumpAndSettle();

      expect(find.textContaining('채움 작은도서관'), findsOneWidget);
      expect(find.text('원본 표기 줄'), findsNothing);
    });

    testWidgets('펼칠 내용이 없는 지역에는 펼침 화살표가 없다', (tester) async {
      await tester.pumpWidget(_screen(() async => _data([_sections[1]])));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.expand_more), findsNothing);
    });

    testWidgets('좁은 화면에서 글자를 2배로 키워도 깨지지 않는다 (펼친 상태 포함)', (tester) async {
      // 폭은 좁게, 높이는 넉넉히 두어 모든 항목이 그려지게 한다.
      await tester.binding.setSurfaceSize(const Size(320, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 4000),
            textScaler: TextScaler.linear(2),
          ),
          child: _screen(() async => _data(_sections)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('경상남도 진주시'));
      await tester.pumpAndSettle();

      expect(find.textContaining('채움 작은도서관'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('앱: 데이터 품질 탭이 있고 좁은 화면·2배 글자에서도 탭 막대가 깨지지 않는다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 640),
          textScaler: TextScaler.linear(2),
        ),
        child: const GapMapApp(),
      ),
    );

    expect(find.text('데이터 품질'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
