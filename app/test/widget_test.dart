import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gap_map/main.dart';
import 'package:gap_map/models/gap_region.dart';
import 'package:gap_map/screens/region_detail_screen.dart';
import 'package:gap_map/screens/region_list_screen.dart';
import 'package:material_ui/material_ui.dart';

const _regions = [
  GapRegion(
    id: 'test-id',
    title: '강화군',
    subtitle: '인천광역시',
    level: GapLevel.red,
    reason: '대형 거점 도서관이 없습니다.',
    stats: [(label: '전체 도서관', value: '1곳')],
  ),
  GapRegion(
    id: 'test-id',
    title: '수원시',
    subtitle: '경기도',
    level: GapLevel.green,
    reason: '양호 이유',
    stats: [(label: '전체 도서관', value: '20곳')],
  ),
];

Widget _screen(Future<List<GapRegion>> Function() load) => MaterialApp(
  home: Scaffold(
    body: RegionListScreen(load: load, notice: '등록 기준 안내'),
  ),
);

void main() {
  testWidgets('로딩 상태: 불러오는 동안 진행 표시가 보인다', (tester) async {
    final pending = Completer<List<GapRegion>>();
    await tester.pumpWidget(_screen(() => pending.future));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('불러오는 중입니다'), findsOneWidget);
  });

  testWidgets('빈 상태: 지역이 없으면 안내 문구가 보인다', (tester) async {
    await tester.pumpWidget(_screen(() async => []));
    await tester.pumpAndSettle();

    expect(find.text('표시할 지역이 없습니다'), findsOneWidget);
  });

  testWidgets('오류 상태: 실패 문구가 보이고 다시 시도하면 목록이 뜬다', (tester) async {
    var calls = 0;
    Future<List<GapRegion>> load() async {
      calls++;
      if (calls == 1) throw const FormatException('broken');
      return _regions;
    }

    await tester.pumpWidget(_screen(load));
    await tester.pumpAndSettle();
    expect(find.text('데이터를 불러오지 못했습니다'), findsOneWidget);
    expect(find.textContaining('broken'), findsNothing); // 내부 오류 문구는 숨긴다

    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(find.text('강화군'), findsOneWidget);
  });

  testWidgets('정상 상태: 지역과 등급이 색이 아닌 글자로도 보인다', (tester) async {
    await tester.pumpWidget(_screen(() async => _regions));
    await tester.pumpAndSettle();

    expect(find.text('등록 기준 안내'), findsOneWidget);
    expect(find.text('강화군'), findsOneWidget);
    expect(find.text('부족'), findsOneWidget);
    expect(find.text('양호'), findsOneWidget);
  });

  testWidgets('지역을 누르면 상세 화면에 이유와 수치가 보인다', (tester) async {
    await tester.pumpWidget(_screen(() async => _regions));
    await tester.pumpAndSettle();

    await tester.tap(find.text('강화군'));
    await tester.pumpAndSettle();

    expect(find.text('대형 거점 도서관이 없습니다.'), findsOneWidget);
    expect(find.text('전체 도서관'), findsOneWidget);
    expect(find.text('1곳'), findsOneWidget);
  });

  testWidgets('좁은 화면에서 글자를 2배로 키워도 상세 화면이 깨지지 않는다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const region = GapRegion(
      id: 'test-id',
      title: '대구광역시',
      subtitle: '등록자 12,023명',
      level: GapLevel.red,
      reason: '고의존자 비율은 전국 평균보다 높은데 금연캠프 이용은 평균보다 적습니다.',
      stats: [(label: '고의존자 1,000명당 캠프 이용', value: '124건 (전국 160건)')],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: const RegionDetailScreen(region),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('124건 (전국 160건)'), findsOneWidget);
  });

  testWidgets('앱: 도서관·금연 탭 2개가 보인다', (tester) async {
    await tester.pumpWidget(const GapMapApp());

    expect(find.text('도서관'), findsOneWidget);
    expect(find.text('금연'), findsOneWidget);
  });
}
