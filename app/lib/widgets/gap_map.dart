import 'package:material_ui/material_ui.dart';

import '../models/gap_region.dart';
import '../models/map_shape.dart';
import 'level_badge.dart';

/// 구역을 격차 등급 색으로 칠한 지도. 두 손가락(또는 휠)으로 확대·이동하고, 구역을 누르면 [onTap]을 부른다.
class GapMap extends StatefulWidget {
  const GapMap({
    super.key,
    required this.map,
    required this.regionOf,
    required this.onTap,
  });

  final MapData map;

  /// 구역에 해당하는 지역. 데이터가 없으면 null(회색으로 칠한다).
  final GapRegion? Function(MapShape shape) regionOf;
  final void Function(GapRegion region) onTap;

  @override
  State<GapMap> createState() => _GapMapState();
}

class _GapMapState extends State<GapMap> {
  final _zoom = TransformationController();
  late List<_Area> _areas = _buildAreas();

  @override
  void didUpdateWidget(GapMap old) {
    super.didUpdateWidget(old);
    if (old.map != widget.map) _areas = _buildAreas();
  }

  @override
  void dispose() {
    _zoom.dispose();
    super.dispose();
  }

  // 테두리 좌표를 그릴 수 있는 Path로 한 번만 바꿔 둔다.
  List<_Area> _buildAreas() => [
    for (final shape in widget.map.shapes)
      _Area(shape, widget.regionOf(shape), Path()..addPolygonList(shape.rings)),
  ];

  void _handleTap(Offset position, double scale) {
    final point = position / scale; // 화면 좌표 → 지도 좌표
    for (final area in _areas) {
      if (!area.path.contains(point)) continue;
      final region = area.region;
      if (region != null) {
        widget.onTap(region);
      } else {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text('${area.shape.name}: 등록된 데이터가 없습니다')),
          );
      }
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.map.size;
    return Column(
      children: [
        const _Legend(),
        Expanded(
          child: Semantics(
            label: '지역별 격차 색칠 지도. 지역별 정보는 목록 보기에서 글자로 볼 수 있습니다.',
            child: InteractiveViewer(
              transformationController: _zoom,
              maxScale: 24, // 서울·부산의 작은 구도 누를 수 있을 만큼
              child: Center(
                child: AspectRatio(
                  aspectRatio: size.width / size.height,
                  child: LayoutBuilder(
                    builder: (context, box) {
                      final scale = box.maxHeight / size.height;
                      return GestureDetector(
                        onTapUp: (tap) => _handleTap(tap.localPosition, scale),
                        // 지도를 다시 그려도 범례 등 주변은 다시 그리지 않게 한다.
                        child: RepaintBoundary(
                          child: CustomPaint(
                            key: const Key('gap-map-canvas'),
                            size: box.biggest,
                            painter: _MapPainter(_areas, scale, _zoom),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            '경계 출처: ${widget.map.source}',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: .center,
          ),
        ),
      ],
    );
  }
}

class _Area {
  const _Area(this.shape, this.region, this.path);

  final MapShape shape;
  final GapRegion? region;
  final Path path;
}

extension on Path {
  void addPolygonList(List<List<Offset>> rings) {
    for (final ring in rings) {
      addPolygon(ring, true);
    }
  }
}

class _MapPainter extends CustomPainter {
  // 확대 배율이 바뀌면 다시 그린다(선 굵기를 맞추기 위해).
  _MapPainter(this.areas, this.scale, this.zoom) : super(repaint: zoom);

  final List<_Area> areas;
  final double scale;
  final TransformationController zoom;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(scale);
    for (final area in areas) {
      canvas.drawPath(
        area.path,
        Paint()..color = levelFillColor(area.region?.level),
      );
    }
    // 경계선은 색을 다 칠한 뒤에 그린다(이웃 구역 색에 덮이지 않게).
    // 화면 맞춤 배율과 사용자가 확대한 배율로 나눠, 확대해도 화면에서 같은 굵기로 보이게 한다.
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.white
      ..strokeWidth = 0.6 / (scale * zoom.value.getMaxScaleOnAxis());
    for (final area in areas) {
      canvas.drawPath(area.path, border);
    }
  }

  @override
  bool shouldRepaint(_MapPainter old) =>
      old.areas != areas || old.scale != scale;
}

/// 색만으로 구분하지 않도록 색 칸 옆에 글자를 함께 둔다.
class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Wrap(
        spacing: 16,
        runSpacing: 4,
        alignment: .center,
        children: [
          for (final level in GapLevel.values)
            _LegendItem(levelFillColor(level), level.label),
          _LegendItem(levelFillColor(null), '데이터 없음'),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem(this.color, this.label);

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: .min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            border: Border.all(color: Colors.black54),
          ),
        ),
        const SizedBox(width: 4),
        Text(label),
      ],
    );
  }
}
