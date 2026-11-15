import 'package:material_ui/material_ui.dart';

import 'data/region_repository.dart';
import 'screens/predict_screen.dart';
import 'screens/quality_screen.dart';
import 'screens/region_tab.dart';

void main() => runApp(const GapMapApp());

class GapMapApp extends StatelessWidget {
  const GapMapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '지역 격차 지도',
      theme: ThemeData(
        colorScheme: .fromSeed(seedColor: Colors.indigo),
        // pubspec.yaml 에 등록한 한글 글꼴. 웹에서 글꼴을 따로 받아오지 않게 한다.
        fontFamily: 'Pretendard',
      ),
      home: DefaultTabController(
        length: 4,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('공공데이터 지역 격차 지도'),
            bottom: const TabBar(
              // 기본 여백(16)이면 휴대폰 폭에서 탭 4개 중 긴 이름('데이터 품질')이 잘린다.
              labelPadding: EdgeInsets.symmetric(horizontal: 4),
              tabs: [
                Tab(icon: Icon(Icons.local_library), text: '도서관'),
                Tab(icon: Icon(Icons.smoke_free), text: '금연'),
                Tab(icon: Icon(Icons.fact_check), text: '등급 예측'),
                Tab(icon: Icon(Icons.report_problem), text: '데이터 품질'),
              ],
            ),
          ),
          body: TabBarView(
            // 좌우로 쓸어 탭을 넘기는 동작을 끈다. 켜 두면 확대한 지도를 좌우로 옮길 수 없다.
            physics: const NeverScrollableScrollPhysics(),
            children: [
              RegionTab(
                loadRegions: loadLibraryRegions,
                loadMap: loadMap,
                idOf: (shape) => shape.libraryId,
                notice:
                    '시군구별 도서관 인프라 격차입니다. 공공데이터포털에 등록된 도서관 기준(2026-10)이라, '
                    '등록되지 않은 도서관은 빠져 있을 수 있습니다. '
                    '전라남도와 광주광역시는 전남광주통합특별시로 합쳐 표시합니다.',
              ),
              RegionTab(
                loadRegions: loadSmokingRegions,
                loadMap: loadMap,
                idOf: (shape) => shape.smokingId,
                notice:
                    '시도별 니코틴 고의존자 수요와 금연캠프 이용 비교입니다. '
                    '국가금연지원서비스 등록자 기준(2024)입니다.',
              ),
              const PredictScreen(load: loadPredict),
              const QualityScreen(load: loadQuality),
            ],
          ),
        ),
      ),
    );
  }
}
