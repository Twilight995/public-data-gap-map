import 'package:material_ui/material_ui.dart';

import '../models/gap_region.dart';
import '../models/map_shape.dart';
import '../widgets/gap_map.dart';
import '../widgets/load_view.dart';
import 'region_detail_screen.dart';

/// 지역 데이터와 경계를 함께 불러와 색칠 지도로 보여준다.
class RegionMapScreen extends StatelessWidget {
  const RegionMapScreen({
    super.key,
    required this.loadRegions,
    required this.loadMap,
    required this.idOf,
  });

  final Future<List<GapRegion>> Function() loadRegions;
  final Future<MapData> Function() loadMap;

  /// 지도 구역이 어느 지역 데이터에 해당하는지 (도서관은 시군구, 금연은 시도).
  final String? Function(MapShape shape) idOf;

  @override
  Widget build(BuildContext context) {
    return LoadView<(List<GapRegion>, MapData)>(
      load: () async => (await loadRegions(), await loadMap()),
      isEmpty: (data) => data.$1.isEmpty,
      builder: (context, data) {
        final (regions, map) = data;
        final byId = {for (final r in regions) r.id: r};
        return GapMap(
          map: map,
          regionOf: (shape) => byId[idOf(shape)],
          onTap: (region) => openRegionDetail(context, region),
        );
      },
    );
  }
}
