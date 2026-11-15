import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:material_ui/material_ui.dart';

import '../export/priority_table.dart';
import '../export/save_file.dart';
import '../models/gap_region.dart';
import '../widgets/level_badge.dart';
import '../widgets/load_view.dart';
import 'region_detail_screen.dart';

typedef SaveFile = void Function(String name, String text);

/// 격차가 큰 순으로 지역을 보여주는 목록. 도서관·금연 탭이 함께 쓴다.
class RegionListScreen extends StatelessWidget {
  const RegionListScreen({
    super.key,
    required this.load,
    required this.notice,
    this.exportName = '우선순위표',
    this.saveFile = saveTextFile,
  });

  final Future<List<GapRegion>> Function() load;

  /// 목록 첫 줄에 보여줄 데이터 기준 안내. 가져가는 표의 맨 위에도 똑같이 들어간다.
  final String notice;

  /// 내려받는 파일 이름(확장자 제외).
  final String exportName;

  /// 파일로 저장하는 방법. 저장할 수 없는 플랫폼에서는 null 이고 내려받기 버튼이 숨는다.
  final SaveFile? saveFile;

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
                    child: Column(
                      crossAxisAlignment: .start,
                      children: [
                        Text(notice),
                        const SizedBox(height: 8),
                        _ExportButtons(
                          rows: priorityRows(notice, regions),
                          count: regions.length,
                          fileName: '$exportName.csv',
                          saveFile: saveFile,
                        ),
                      ],
                    ),
                  )
                : _RegionTile(regions[i - 1]),
          ),
        ),
      ),
    );
  }
}

/// 우선순위표를 복사하거나 파일로 내려받는 버튼. 누른 결과는 화면 아래 문구로 알린다.
class _ExportButtons extends StatelessWidget {
  const _ExportButtons({
    required this.rows,
    required this.count,
    required this.fileName,
    required this.saveFile,
  });

  final List<List<Object>> rows;
  final int count;
  final String fileName;
  final SaveFile? saveFile;

  /// [action]을 실행하고 성공·실패를 문구로 알린다. 실패하면 같은 동작을 다시 시도할 수 있다.
  Future<void> _run(
    ScaffoldMessengerState messenger, {
    required Future<void> Function() action,
    required String done,
    required String failed,
  }) async {
    Object? error;
    try {
      await action();
    } catch (e) {
      error = e;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(error == null ? done : failed),
          // 버튼이 달린 안내는 저절로 사라지지 않으므로 닫기 단추를 함께 둔다.
          showCloseIcon: error != null,
          action: error == null
              ? null
              : SnackBarAction(
                  label: '다시 시도',
                  onPressed: () => _run(
                    messenger,
                    action: action,
                    done: done,
                    failed: failed,
                  ),
                ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    final save = saveFile;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.tonalIcon(
          icon: const Icon(Icons.copy),
          label: const Text('우선순위표 복사하기'),
          onPressed: () => _run(
            messenger,
            // 브라우저가 권한 창을 띄운 채 답하지 않으면 끝없이 기다리게 된다. 10초가 지나면 실패로 알린다.
            action: () => Clipboard.setData(
              ClipboardData(text: toTsv(rows)),
            ).timeout(const Duration(seconds: 10)),
            done: '우선순위표 $count개 지역을 복사했습니다. 엑셀에 붙여넣으세요.',
            failed: '복사하지 못했습니다. 기기나 브라우저가 복사를 막았을 수 있습니다.',
          ),
        ),
        if (save != null)
          OutlinedButton.icon(
            icon: const Icon(Icons.download),
            label: const Text('CSV 파일로 내려받기'),
            onPressed: () => _run(
              messenger,
              action: () async => save(fileName, toCsv(rows)),
              done: '$fileName 파일 내려받기를 시작했습니다.',
              failed: '파일을 내려받지 못했습니다. 브라우저가 내려받기를 막았을 수 있습니다.',
            ),
          ),
      ],
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
