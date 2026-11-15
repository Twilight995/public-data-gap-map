import 'package:material_ui/material_ui.dart';

import '../models/quality_data.dart';
import '../widgets/load_view.dart';

/// 원본 데이터에서 확인이 필요한 곳을 종류별로 보여주는 목록.
class QualityScreen extends StatelessWidget {
  const QualityScreen({super.key, required this.load});

  final Future<QualityData> Function() load;

  @override
  Widget build(BuildContext context) {
    return LoadView<QualityData>(
      load: load,
      isEmpty: (data) => data.sections.isEmpty,
      emptyText: '확인이 필요한 데이터 품질 경고가 없습니다',
      builder: (context, data) {
        // 구역 제목과 항목을 한 줄로 펴서, 화면에 보이는 줄만 만든다.
        final rows = <Widget>[
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(data.notice),
          ),
          for (final section in data.sections) ...[
            _SectionHeader(section),
            for (final item in section.items)
              // 같은 지역이 여러 구역에 나오므로 구역 제목까지 넣어 구분한다.
              // 이 키가 있어야 펼친 항목이 화면 밖으로 나갔다 와도 펼쳐진 채로 남는다.
              _ItemTile(
                item,
                key: PageStorageKey('${section.title}/${item.title}'),
              ),
          ],
        ];
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView.builder(
              itemCount: rows.length,
              itemBuilder: (context, i) => rows[i],
            ),
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.section);

  final QualitySection section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          const Divider(),
          Row(
            crossAxisAlignment: .start,
            children: [
              // 아이콘은 꾸밈이다. 뜻은 옆의 제목 글자가 전한다.
              const ExcludeSemantics(child: Icon(Icons.report_problem)),
              const SizedBox(width: 8),
              Expanded(
                child: Semantics(
                  // container 가 없으면 건수·설명까지 한 덩어리로 머리글이 된다.
                  container: true,
                  header: true,
                  child: Text(section.title, style: theme.textTheme.titleLarge),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            section.count,
            style: theme.textTheme.titleSmall!.copyWith(fontWeight: .bold),
          ),
          const SizedBox(height: 4),
          Text(section.description),
        ],
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile(this.item, {super.key});

  final QualityItem item;

  @override
  Widget build(BuildContext context) {
    if (item.details.isEmpty) {
      return ListTile(title: Text(item.title), subtitle: Text(item.summary));
    }
    return ExpansionTile(
      key: key,
      title: Text(item.title),
      subtitle: Text(item.summary),
      expandedCrossAxisAlignment: .start,
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      children: [
        for (final line in item.details)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(line),
          ),
      ],
    );
  }
}
