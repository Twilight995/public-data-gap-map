import 'package:flutter/services.dart' show rootBundle;

import '../models/gap_region.dart';
import '../models/map_shape.dart';
import '../models/predict_data.dart';

// 지금은 앱에 든 JSON을 읽는다. 서버가 생기면 이 함수들만 바꾸면 된다.

Future<List<GapRegion>> loadLibraryRegions() async =>
    parseLibraries(await rootBundle.loadString('assets/data/libraries.json'));

Future<List<GapRegion>> loadSmokingRegions() async =>
    parseSmoking(await rootBundle.loadString('assets/data/smoking.json'));

Future<PredictData> loadPredict() async =>
    parsePredict(await rootBundle.loadString('assets/data/predict.json'));

Future<MapData>? _map;

/// 경계는 크고(좌표 5만 개) 두 탭이 함께 쓰므로 한 번만 읽는다. 실패하면 다음에 다시 읽는다.
Future<MapData> loadMap() => _map ??= _readMap();

Future<MapData> _readMap() async {
  try {
    return parseMap(await rootBundle.loadString('assets/data/map.json'));
  } catch (_) {
    _map = null;
    rethrow;
  }
}
