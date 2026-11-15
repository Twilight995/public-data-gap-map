import 'package:material_ui/material_ui.dart';

import '../models/gap_region.dart';
import '../widgets/level_badge.dart';

/// 목록과 지도가 함께 쓰는 상세 화면 열기.
void openRegionDetail(BuildContext context, GapRegion region) {
  Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => RegionDetailScreen(region)));
}

/// 지역 한 곳의 등급, 이유, 수치.
class RegionDetailScreen extends StatelessWidget {
  const RegionDetailScreen(this.region, {super.key});

  final GapRegion region;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(region.title)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: .start,
                    children: [
                      LevelBadge(region.level),
                      const SizedBox(height: 8),
                      Text(
                        region.reason,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
              ),
              for (final stat in region.stats)
                // 값을 오른쪽 끝(trailing)에 두면 좁은 화면·큰 글자에서 폭이 모자라 깨진다.
                ListTile(
                  title: Text(stat.label),
                  subtitle: Text(
                    stat.value,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
