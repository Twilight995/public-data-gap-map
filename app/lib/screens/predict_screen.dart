import 'package:material_ui/material_ui.dart';

import '../models/predict_data.dart';
import '../widgets/load_view.dart';

/// 2문항으로 니코틴 의존도 등급을 추정한다. 고른 답은 어디에도 저장하지 않는다.
class PredictScreen extends StatelessWidget {
  const PredictScreen({super.key, required this.load});

  final Future<PredictData> Function() load;

  @override
  Widget build(BuildContext context) {
    return LoadView<PredictData>(
      load: load,
      isEmpty: (_) => false,
      builder: (context, data) => _PredictForm(data),
    );
  }
}

class _PredictForm extends StatefulWidget {
  const _PredictForm(this.data);

  final PredictData data;

  @override
  State<_PredictForm> createState() => _PredictFormState();
}

class _PredictFormState extends State<_PredictForm> {
  /// 문항별로 고른 점수. 아직 안 골랐으면 null.
  final List<int?> _answers = [null, null];

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final [first, second] = _answers;
    final text = Theme.of(context).textTheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final (i, question) in data.questions.indexed) ...[
              Text('${i + 1}. ${question.text}', style: text.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final option in question.options)
                    ChoiceChip(
                      label: Text(option.label),
                      selected: _answers[i] == option.score,
                      onSelected: (_) {
                        setState(() {
                          _answers[i] = option.score;
                        });
                      },
                    ),
                ],
              ),
              const SizedBox(height: 24),
            ],
            if (first != null && second != null)
              _Result(data.cellFor(first, second))
            else
              Text('두 문항을 모두 선택하면 예측 등급이 나옵니다.', style: text.bodyLarge),
            const SizedBox(height: 24),
            Text(
              '2문항으로 추정한 값이며 의료 진단이 아닙니다. 정확한 결과는 정식 6문항 검사로 확인하세요.\n\n'
              '이 표는 금연지원서비스에 등록한 사람 ${_count(data.total)}명의 응답으로 만들었습니다'
              '(${data.source}). 같은 사람들에게 적용하면 ${data.accuracyPct}%가 실제 등급과 맞습니다. '
              "실제 '높음'인 사람은 ${data.highRecallPct}%만 '높음'으로, "
              "나머지 ${data.highAsMidPct}%는 '중간'으로 예측됩니다. "
              '서비스에 등록하지 않은 흡연자에게는 정확도가 다를 수 있습니다.\n\n'
              '선택한 답은 저장되지 않습니다. 비율은 반올림한 값이라 합이 100%가 아닐 수 있습니다.',
              style: text.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _Result extends StatelessWidget {
  const _Result(this.cell);

  final PredictCell cell;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: .start,
          children: [
            // 답을 고르면 결과가 새로 나타났다는 것을 화면 읽기 프로그램에도 알린다.
            Semantics(
              liveRegion: true,
              child: Text('예측 등급: ${cell.level.label}', style: text.titleLarge),
            ),
            const SizedBox(height: 4),
            // 점수 범위는 6문항 기준이다(2문항만으로는 최대 6점). 한계를 결과 바로 옆에 둔다.
            Text('6문항 합계 ${cell.level.range}에 해당하는 등급 · 2문항 추정이며 진단이 아닙니다'),
            const SizedBox(height: 12),
            Text(cell.level.advice, style: text.bodyLarge),
            const Divider(height: 32),
            Text('같은 답을 한 등록자 ${_count(cell.n)}명의 실제 등급'),
            const SizedBox(height: 8),
            for (final share in cell.shares)
              // 화면 읽기 프로그램에는 막대 대신 "높음 95.4%" 한 줄로 읽어 준다.
              Semantics(
                label: '${share.level.label} ${share.pct}%',
                excludeSemantics: true,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: .start,
                    children: [
                      Row(
                        mainAxisAlignment: .spaceBetween,
                        children: [
                          Text(share.level.label),
                          Text('${share.pct}%'),
                        ],
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(value: share.pct / 100),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 12023 → "12,023"
String _count(int n) =>
    n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
