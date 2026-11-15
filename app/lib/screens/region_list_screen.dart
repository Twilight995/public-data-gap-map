import 'package:material_ui/material_ui.dart';

import '../models/gap_region.dart';
import '../widgets/level_badge.dart';
import '../widgets/load_view.dart';
import 'region_detail_screen.dart';

/// 격차가 큰 순으로 지역을 보여주는 목록. 도서관·금연 탭이 함께 쓴다.
class RegionListScreen extends StatelessWidget {
  const RegionListScreen({super.key, required this.load, required this.notice});

  final Future<List<GapRegion>> Function() load;

  /// 목록 첫 줄에 보여줄 데이터 기준 안내.
  final String notice;

  @override
  Widget build(BuildContext context) {
    return LoadView<List<GapRegion>>(
      load: load,
      isEmpty: (regions) => regions.isEmpty,
      builder: (context, regions) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          // 안내문을 목록의 첫 줄로 둔다. 위에 고정하면 낮은 화면에서 목록 자리를 다 차지한다.
          child: ListView.builder(
            itemCount: regions.length + 1,
            itemBuilder: (context, i) => i == 0
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(notice),
                  )
                : _RegionTile(regions[i - 1]),
          ),
        ),
      ),
    );
  }
}

class _RegionTile extends StatelessWidget {
  const _RegionTile(this.region);

  final GapRegion region;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(region.title),
      subtitle: Text(region.subtitle),
      trailing: LevelBadge(region.level),
      onTap: () => openRegionDetail(context, region),
    );
  }
}
