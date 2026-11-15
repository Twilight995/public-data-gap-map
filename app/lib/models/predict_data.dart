import 'dart:convert';

/// 2문항 답으로 니코틴 의존도 등급을 예측하는 표.
/// 예측 규칙과 수치는 tools/build_predict_data.py 가 만들고, 앱은 읽기만 한다.
class PredictData {
  const PredictData({
    required this.source,
    required this.total,
    required this.accuracyPct,
    required this.highRecallPct,
    required this.highAsMidPct,
    required this.questions,
    required this.levels,
    required this._cells,
  });

  final String source;
  final int total;

  /// 전체 등록자 중 예측이 실제 등급과 맞은 비율.
  final double accuracyPct;

  /// 실제 '높음'인 사람 중 '높음'으로 예측된 비율.
  final double highRecallPct;

  /// 실제 '높음'인 사람 중 '중간'으로 예측된 비율. ('낮음'으로 예측되는 경우는 없다.)
  final double highAsMidPct;
  final List<PredictQuestion> questions;
  final List<DependenceLevel> levels;
  final Map<(int, int), PredictCell> _cells;

  /// 첫째 문항 점수와 둘째 문항 점수에 해당하는 칸.
  PredictCell cellFor(int first, int second) => _cells[(first, second)]!;
}

class PredictQuestion {
  const PredictQuestion({required this.text, required this.options});

  final String text;
  final List<({int score, String label})> options;
}

class DependenceLevel {
  const DependenceLevel({
    required this.label,
    required this.range,
    required this.advice,
  });

  final String label;
  final String range;
  final String advice;
}

class PredictCell {
  const PredictCell({
    required this.level,
    required this.n,
    required this.shares,
  });

  /// 예측 등급: 같은 답을 한 등록자 중 가장 많았던 등급.
  final DependenceLevel level;
  final int n;

  /// 같은 답을 한 등록자의 실제 등급 비율(낮은 등급부터).
  final List<({DependenceLevel level, double pct})> shares;
}

PredictData parsePredict(String json) {
  try {
    final data = jsonDecode(json) as Map<String, dynamic>;
    final levels = {
      for (final Map<String, dynamic> l in data['levels'])
        l['id'] as String: DependenceLevel(
          label: l['label'],
          range: l['range'],
          advice: l['advice'],
        ),
    };
    final questions = [
      for (final Map<String, dynamic> q in data['questions'])
        PredictQuestion(
          text: q['text'],
          options: [
            for (final Map<String, dynamic> o in q['options'])
              (score: o['score'] as int, label: o['label'] as String),
          ],
        ),
    ];
    final cells = {
      for (final Map<String, dynamic> c in data['cells'])
        (c['q1'] as int, c['q4'] as int): PredictCell(
          level: levels[c['level']]!,
          n: c['n'],
          shares: [
            for (final id in levels.keys)
              (
                level: levels[id]!,
                pct: ((c['pct'] as Map<String, dynamic>)[id] as num).toDouble(),
              ),
          ],
        ),
    };
    // 칸은 (문항1 점수, 문항4 점수)로 찾는다. 문항 순서가 다르면 답이 엉뚱한 칸에 연결된다.
    final ids = [
      for (final Map<String, dynamic> q in data['questions']) q['id'],
    ];
    if (ids.length != 2 || ids[0] != 'q1' || ids[1] != 'q4') {
      throw FormatException('문항은 q1, q4 순서여야 합니다: $ids');
    }
    // 어떤 답을 골라도 결과가 있어야 한다.
    for (final first in questions[0].options) {
      for (final second in questions[1].options) {
        if (!cells.containsKey((first.score, second.score))) {
          throw FormatException(
            '답 조합 (${first.score}, ${second.score})의 예측이 없습니다',
          );
        }
      }
    }
    return PredictData(
      source: data['source'],
      total: data['total'],
      accuracyPct: (data['accuracyPct'] as num).toDouble(),
      highRecallPct: (data['highRecallPct'] as num).toDouble(),
      highAsMidPct: (data['highAsMidPct'] as num).toDouble(),
      questions: questions,
      levels: levels.values.toList(),
      cells: cells,
    );
  } on FormatException {
    rethrow;
  } on Error catch (e) {
    throw FormatException('예측 데이터 형식이 올바르지 않습니다: $e');
  }
}
