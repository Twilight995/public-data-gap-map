import 'dart:io';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter_test/flutter_test.dart';
import 'package:gap_map/main.dart';
import 'package:gap_map/models/gap_region.dart';
import 'package:gap_map/models/map_shape.dart';
import 'package:gap_map/screens/region_map_screen.dart';
import 'package:gap_map/screens/region_tab.dart';
import 'package:gap_map/widgets/gap_map.dart';
import 'package:gap_map/widgets/level_badge.dart';
import 'package:material_ui/material_ui.dart';

// 200×100 캔버스(실제 지도처럼 가로세로가 다르다): 왼쪽 절반은 '서쪽군', 오른쪽 절반은 '동쪽군'.
// 도서관 데이터는 서쪽군에만 있고, 금연 데이터는 둘이 속한 '가도'에 있다.
const _mapJson = '''
{"source": "테스트 경계", "width": 200, "height": 100, "shapes": [
 {"name": "서쪽군", "library": "가도 서쪽군", "smoking": "가도", "rings": [[0,0, 100,0, 100,100, 0,100]]},
 {"name": "동쪽군", "library": null, "smoking": "가도", "rings": [[100,0, 200,0, 200,100, 100,100]]}
]}
''';

const _west = GapRegion(
  id: '가도 서쪽군',
  title: '서쪽군',
  subtitle: '가도',
  level: GapLevel.red,
  reason: '서쪽군이 부족한 이유',
  stats: [],
);

const _province = GapRegion(
  id: '가도',
  title: '가도',
  subtitle: '등록자 10명',
  level: GapLevel.orange,
  reason: '가도가 주의인 이유',
  stats: [],
);

Rect _canvas(WidgetTester tester) =>
    tester.getRect(find.byKey(const Key('gap-map-canvas')));
Offset _westPoint(WidgetTester tester) =>
    _canvas(tester).centerLeft + Offset(_canvas(tester).width * 0.25, 0);
Offset _eastPoint(WidgetTester tester) =>
    _canvas(tester).centerRight - Offset(_canvas(tester).width * 0.25, 0);

void main() {
  group('parseMap', () {
    test('구역 이름, 연결 키, 테두리 좌표를 읽는다', () {
      final map = parseMap(_mapJson);

      expect(map.size, const Size(200, 100));
      expect(map.shapes.map((s) => s.name), ['서쪽군', '동쪽군']);
      expect(map.shapes[0].libraryId, '가도 서쪽군');
      expect(map.shapes[1].libraryId, isNull);
      expect(map.shapes[0].rings.single, const [
        Offset(0, 0),
        Offset(100, 0),
        Offset(100, 100),
        Offset(0, 100),
      ]);
    });

    test('깨진 데이터면 FormatException을 던진다', () {
      expect(() => parseMap('{"shapes": 3}'), throwsFormatException);
    });

    test('실제 경계 파일: 250개 구역이 모두 테두리를 갖고, 연결 키가 실제 지역을 가리킨다', () {
      final map = parseMap(File('assets/data/map.json').readAsStringSync());
      final libraries = parseLibraries(
        File('assets/data/libraries.json').readAsStringSync(),
      );
      final smoking = parseSmoking(
        File('assets/data/smoking.json').readAsStringSync(),
      );
      final libraryIds = {for (final r in libraries) r.id};

      expect(map.shapes, hasLength(250));
      expect(map.shapes.every((s) => s.rings.isNotEmpty), isTrue);
      expect(
        {for (final s in map.shapes) s.smokingId},
        {for (final r in smoking) r.id},
      );
      expect(
        map.shapes
            .where((s) => s.libraryId != null)
            .every((s) => libraryIds.contains(s.libraryId)),
        isTrue,
      );
    });
  });

  test('등급마다 칠하는 색이 다르고, 데이터 없음은 따로 구분된다', () {
    final colors = {
      for (final level in <GapLevel?>[...GapLevel.values, null])
        levelFillColor(level),
    };
    expect(colors, hasLength(4));
  });

  group('GapMap', () {
    Future<List<GapRegion>> pumpMap(WidgetTester tester) async {
      final tapped = <GapRegion>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GapMap(
              map: parseMap(_mapJson),
              regionOf: (shape) => shape.libraryId == _west.id ? _west : null,
              onTap: tapped.add,
            ),
          ),
        ),
      );
      return tapped;
    }

    testWidgets('범례가 색과 함께 글자로 보이고 경계 출처를 표시한다', (tester) async {
      await pumpMap(tester);

      for (final label in ['부족', '주의', '양호', '데이터 없음']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.textContaining('테스트 경계'), findsOneWidget);
    });

    testWidgets('출처 문구가 휴대폰 하단 조작 막대 영역과 겹치지 않는다', (tester) async {
      const barHeight = 48.0; // 화면 맨 아래, 시스템이 쓰는 영역
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(800, 600),
              padding: EdgeInsets.only(bottom: barHeight),
            ),
            child: Scaffold(
              body: GapMap(
                map: parseMap(_mapJson),
                regionOf: (_) => null,
                onTap: (_) {},
              ),
            ),
          ),
        ),
      );

      final source = tester.getRect(find.textContaining('테스트 경계'));
      expect(source.bottom, lessThanOrEqualTo(600 - barHeight));
    });

    testWidgets('화면 읽기 프로그램에 지도라는 것과 대체 수단(목록)을 알린다', (tester) async {
      await pumpMap(tester);
      expect(find.bySemanticsLabel(RegExp('색칠 지도.*목록')), findsOneWidget);
    });

    testWidgets('데이터가 있는 구역을 누르면 그 지역이 선택된다', (tester) async {
      final tapped = await pumpMap(tester);

      await tester.tapAt(_westPoint(tester));
      await tester.pump();

      expect(tapped, [_west]);
    });

    testWidgets('데이터가 없는 구역을 누르면 선택되지 않고 안내가 뜬다', (tester) async {
      final tapped = await pumpMap(tester);

      await tester.tapAt(_eastPoint(tester));
      await tester.pump();

      expect(tapped, isEmpty);
      expect(find.textContaining('동쪽군'), findsOneWidget);
    });

    testWidgets('확대한 뒤에도 누른 자리의 구역이 선택된다', (tester) async {
      final tapped = await pumpMap(tester);
      final center = _canvas(tester).center;

      // 휠로 지도 가운데(두 구역의 경계)를 기준으로 확대한다. 경계의 화면 위치는 그대로다.
      final pointer = TestPointer(1, PointerDeviceKind.mouse)..hover(center);
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, -200)));
      await tester.pump();

      await tester.tapAt(center - const Offset(20, 0));
      await tester.pump();
      expect(tapped, [_west]);
    });
  });

  group('RegionMapScreen', () {
    Future<void> pumpScreen(
      WidgetTester tester,
      String? Function(MapShape) idOf,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RegionMapScreen(
              loadRegions: () async => const [_west, _province],
              loadMap: () async => parseMap(_mapJson),
              idOf: idOf,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('도서관 기준이면 누른 시군구의 상세 화면이 열린다', (tester) async {
      await pumpScreen(tester, (shape) => shape.libraryId);

      await tester.tapAt(_westPoint(tester));
      await tester.pumpAndSettle();

      expect(find.text('서쪽군이 부족한 이유'), findsOneWidget);
    });

    testWidgets('금연 기준이면 어느 시군구를 눌러도 소속 시도의 상세 화면이 열린다', (tester) async {
      await pumpScreen(tester, (shape) => shape.smokingId);

      await tester.tapAt(_eastPoint(tester)); // 도서관 데이터가 없는 동쪽군도 시도 데이터는 있다
      await tester.pumpAndSettle();

      expect(find.text('가도가 주의인 이유'), findsOneWidget);
    });
  });

  group('RegionTab', () {
    Widget tab() => RegionTab(
      loadRegions: () async => const [_west],
      loadMap: () async => parseMap(_mapJson),
      idOf: (shape) => shape.libraryId,
      notice: '안내',
    );

    testWidgets('처음엔 목록이고 "지도"를 누르면 지도로 바뀐다', (tester) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: tab())));
      await tester.pumpAndSettle();
      expect(find.text('서쪽군'), findsOneWidget);
      expect(find.byType(GapMap), findsNothing);

      await tester.tap(find.text('지도'));
      await tester.pumpAndSettle();
      expect(find.byType(GapMap), findsOneWidget);
    });

    testWidgets('다른 탭에 다녀와도 지도 보기가 유지된다', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DefaultTabController(
            length: 2,
            child: Scaffold(
              appBar: AppBar(
                bottom: const TabBar(
                  tabs: [
                    Tab(text: '첫째'),
                    Tab(text: '둘째'),
                  ],
                ),
              ),
              body: TabBarView(children: [tab(), const Text('둘째 내용')]),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('지도'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('둘째'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('첫째'));
      await tester.pumpAndSettle();

      expect(find.byType(GapMap), findsOneWidget);
    });
  });

  testWidgets('앱: 좌우로 쓸어도 탭이 넘어가지 않는다 (확대한 지도를 옮길 수 있어야 한다)', (tester) async {
    await tester.pumpWidget(const GapMapApp());

    final tabs = tester.widget<TabBarView>(find.byType(TabBarView));
    expect(tabs.physics, isA<NeverScrollableScrollPhysics>());
  });
}
