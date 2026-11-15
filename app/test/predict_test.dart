import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gap_map/main.dart';
import 'package:gap_map/models/predict_data.dart';
import 'package:gap_map/screens/predict_screen.dart';
import 'package:material_ui/material_ui.dart';

final _json = File('assets/data/predict.json').readAsStringSync();

Widget _screen() => MaterialApp(
  home: Scaffold(body: PredictScreen(load: () async => parsePredict(_json))),
);

void main() {
  group('parsePredict', () {
    test('문항 2개, 등급 3개, 답 조합 16칸을 읽는다', () {
      final data = parsePredict(_json);

      expect(data.questions.map((q) => q.options.length), [4, 4]);
      expect(data.levels.map((l) => l.label), ['낮음', '중간', '높음']);
      expect(data.cellFor(0, 0).level.label, '낮음');
      expect(data.cellFor(3, 3).level.label, '높음');
      expect(data.cellFor(3, 0).level.label, '중간');
    });

    test('칸마다 실제 등급 비율이 등급 순서대로 들어 있다', () {
      final shares = parsePredict(_json).cellFor(2, 3).shares;

      expect(shares.map((s) => s.level.label), ['낮음', '중간', '높음']);
      expect(
        shares.map((s) => s.pct).reduce((a, b) => a + b),
        closeTo(100, 0.2),
      );
    });

    test('깨진 데이터면 FormatException을 던진다', () {
      expect(() => parsePredict('{"cells": 1}'), throwsFormatException);
    });

    test('문항 순서가 바뀌면 답이 엉뚱한 칸에 연결되므로 FormatException을 던진다', () {
      final data = jsonDecode(_json) as Map<String, dynamic>;
      data['questions'] = (data['questions'] as List).reversed.toList();
      expect(() => parsePredict(jsonEncode(data)), throwsFormatException);
    });

    test('답 조합이 하나라도 빠지면 FormatException을 던진다', () {
      final data = jsonDecode(_json) as Map<String, dynamic>;
      (data['cells'] as List).removeLast();
      expect(() => parsePredict(jsonEncode(data)), throwsFormatException);
    });
  });

  group('PredictScreen', () {
    testWidgets('처음엔 결과 대신 안내가 보이고, 한계와 저장하지 않는다는 점을 알린다', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.text('두 문항을 모두 선택하면 예측 등급이 나옵니다.'), findsOneWidget);
      expect(find.textContaining('예측 등급:'), findsNothing);
      expect(find.textContaining('의료 진단이 아닙니다'), findsOneWidget);
      expect(find.textContaining('저장되지 않습니다'), findsOneWidget);
      // 한계를 숫자로 밝히고 정식 검사를 권한다
      for (final part in ['77.2%', '53.8%', '46.2%', '정식 6문항 검사', '등록한 사람']) {
        expect(find.textContaining(part), findsOneWidget);
      }
    });

    testWidgets('한 문항만 고르면 아직 결과가 나오지 않는다', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('5분 이내'));
      await tester.pumpAndSettle();

      expect(find.textContaining('예측 등급:'), findsNothing);
    });

    testWidgets('두 문항을 고르면 예측 등급, 권고, 실제 등급 비율이 보인다', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('5분 이내'));
      await tester.ensureVisible(find.text('31개비 이상'));
      await tester.tap(find.text('31개비 이상'));
      await tester.pumpAndSettle();

      expect(find.text('예측 등급: 높음'), findsOneWidget);
      // 결과 바로 아래에 기준과 한계를 함께 보여준다 (아래 안내문까지 내려가지 않아도 보이게)
      expect(find.textContaining('6문항 합계 7~10점'), findsOneWidget);
      expect(find.textContaining('2문항 추정이며 진단이 아닙니다'), findsOneWidget);
      expect(find.textContaining('단기금연캠프'), findsOneWidget);
      expect(find.textContaining('같은 답을 한 등록자'), findsOneWidget);
      expect(find.text('95.4%'), findsOneWidget); // 이 답을 한 사람 중 실제 '높음' 비율
    });

    testWidgets('답을 바꾸면 결과가 바뀐다', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();
      await tester.tap(find.text('5분 이내'));
      await tester.ensureVisible(find.text('31개비 이상'));
      await tester.tap(find.text('31개비 이상'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('10개비 이하'));
      await tester.tap(find.text('10개비 이하'));
      await tester.pumpAndSettle();

      expect(find.text('예측 등급: 중간'), findsOneWidget);
      expect(find.textContaining('예측 등급: 높음'), findsNothing);
    });

    testWidgets('불러오기에 실패하면 오류 안내와 다시 시도가 보인다', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PredictScreen(
              load: () async => throw const FormatException('broken'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('데이터를 불러오지 못했습니다'), findsOneWidget);
      expect(find.text('다시 시도'), findsOneWidget);
    });

    testWidgets('좁은 화면에서 글자를 2배로 키워도 깨지지 않는다', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(2),
          ),
          child: _screen(),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // 결과 카드가 나온 상태에서도 깨지지 않아야 한다.
      // 폭은 좁게 두고 높이만 늘려, 스크롤 없이 모든 항목이 그려지게 한 뒤 확인한다.
      await tester.binding.setSurfaceSize(const Size(320, 4000));
      await tester.pumpAndSettle();
      await tester.tap(find.text('5분 이내'));
      await tester.tap(find.text('31개비 이상'));
      await tester.pumpAndSettle();

      expect(find.text('예측 등급: 높음'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('앱: 등급 예측 탭이 있다', (tester) async {
    await tester.pumpWidget(const GapMapApp());
    expect(find.text('등급 예측'), findsOneWidget);
  });
}
