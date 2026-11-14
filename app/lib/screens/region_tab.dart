import 'package:material_ui/material_ui.dart';

import '../models/gap_region.dart';
import '../models/map_shape.dart';
import 'region_list_screen.dart';
import 'region_map_screen.dart';

/// 탭 한 개의 내용. 같은 데이터를 목록 또는 지도로 본다.
class RegionTab extends StatefulWidget {
  const RegionTab({
    super.key,
    required this.loadRegions,
    required this.loadMap,
    required this.idOf,
    required this.notice,
  });

  final Future<List<GapRegion>> Function() loadRegions;
  final Future<MapData> Function() loadMap;
  final String? Function(MapShape shape) idOf;
  final String notice;

  @override
  State<RegionTab> createState() => _RegionTabState();
}

// 다른 탭에 다녀와도 목록/지도 선택이 유지되도록 상태를 살려 둔다.
class _RegionTabState extends State<RegionTab> with AutomaticKeepAliveClientMixin {
  bool _showMap = false;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8),
          // 폭을 정해 주지 않으면 버튼이 최소 폭으로 줄어 글자가 세로로 꺾인다.
          child: SizedBox(
            width: 280,
            child: SegmentedButton<bool>(
              expandedInsets: EdgeInsets.zero,
              segments: const [
                ButtonSegment(
                  value: false,
                  icon: Icon(Icons.list),
                  label: Text('목록'),
                ),
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.map),
                  label: Text('지도'),
                ),
              ],
              selected: {_showMap},
              onSelectionChanged: (selected) {
                setState(() {
                  _showMap = selected.first;
                });
              },
            ),
          ),
        ),
        Expanded(
          child: _showMap
              ? RegionMapScreen(
                  loadRegions: widget.loadRegions,
                  loadMap: widget.loadMap,
                  idOf: widget.idOf,
                )
              : RegionListScreen(
                  load: widget.loadRegions,
                  notice: widget.notice,
                ),
        ),
      ],
    );
  }
}
