import 'package:material_ui/material_ui.dart';

import '../models/gap_region.dart';

/// 지도에서 구역을 칠하는 색. 글자색보다 밝게 해서 넓은 면적에서도 눈이 덜 피로하다.
Color levelFillColor(GapLevel? level) => switch (level) {
  GapLevel.red => Colors.red.shade400,
  GapLevel.orange => Colors.orange.shade300,
  GapLevel.green => Colors.green.shade200,
  null => Colors.grey.shade300, // 데이터 없음
};

/// 격차 등급 표시. 색을 구분하기 어려운 사람도 읽도록 아이콘과 글자를 함께 쓴다.
class LevelBadge extends StatelessWidget {
  const LevelBadge(this.level, {super.key});

  final GapLevel level;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (level) {
      // 흰 바탕에서 글자 대비 4.5:1 이상(WCAG AA)이 되는 색
      GapLevel.red => (Colors.red.shade700, Icons.error),
      GapLevel.orange => (const Color(0xFFB34700), Icons.warning),
      GapLevel.green => (Colors.green.shade800, Icons.check_circle),
    };
    return Row(
      mainAxisSize: .min,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 4),
        Text(
          level.label,
          style: TextStyle(color: color, fontWeight: .bold, fontSize: 16),
        ),
      ],
    );
  }
}
