import 'dart:convert';

/// 데이터 품질 탭 전체: 첫 줄 안내문과 경고 구역들.
/// 경고 규칙과 문구는 tools/build_quality_data.py 가 만들고, 앱은 읽기만 한다.
class QualityData {
  const QualityData({required this.notice, required this.sections});

  final String notice;
  final List<QualitySection> sections;
}

/// 데이터 품질 경고의 한 종류(예: 입력 오류가 의심되는 도서관).
class QualitySection {
  const QualitySection({
    required this.title,
    required this.count,
    required this.description,
    required this.items,
  });

  final String title;

  /// 건수 문구. 예: '9개 지역 · 도서관 155곳'
  final String count;
  final String description;
  final List<QualityItem> items;
}

/// 경고 한 건. 보통 지역 하나다.
class QualityItem {
  const QualityItem({
    required this.title,
    required this.summary,
    required this.details,
  });

  final String title;
  final String summary;

  /// 펼쳤을 때 보여 줄 줄들(도서관 이름, 원본 표기 등). 없을 수 있다.
  final List<String> details;
}

QualityData parseQuality(String json) {
  try {
    final data = jsonDecode(json) as Map<String, dynamic>;
    return QualityData(
      notice: data['notice'],
      sections: [
        for (final Map<String, dynamic> s in data['sections'])
          QualitySection(
            title: s['title'],
            count: s['count'],
            description: s['description'],
            items: [
              for (final Map<String, dynamic> i in s['items'])
                QualityItem(
                  title: i['title'],
                  summary: i['summary'],
                  details: (i['details'] as List).cast<String>().toList(),
                ),
            ],
          ),
      ],
    );
  } on FormatException {
    rethrow;
  } on Error catch (e) {
    throw FormatException('데이터 품질 경고 형식이 올바르지 않습니다: $e');
  }
}
