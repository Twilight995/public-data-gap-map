import 'package:material_ui/material_ui.dart';

/// 데이터를 불러오는 화면의 네 가지 상태(로딩, 오류, 빈, 정상)를 한 곳에서 처리한다.
class LoadView<T> extends StatefulWidget {
  const LoadView({
    super.key,
    required this.load,
    required this.isEmpty,
    required this.builder,
    this.emptyText = '표시할 지역이 없습니다',
  });

  final Future<T> Function() load;
  final bool Function(T data) isEmpty;
  final Widget Function(BuildContext context, T data) builder;

  /// 빈 상태에서 보여줄 문구.
  final String emptyText;

  @override
  State<LoadView<T>> createState() => _LoadViewState<T>();
}

class _LoadViewState<T> extends State<LoadView<T>> {
  late Future<T> _data = widget.load();

  void _retry() {
    // 화살표 함수로 쓰면 Future가 반환돼 setState가 거부한다.
    setState(() {
      _data = widget.load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _Message(
            icon: CircularProgressIndicator(),
            text: '불러오는 중입니다',
          );
        }
        if (snapshot.hasError) {
          // 내부 오류 내용은 사용자에게 보여주지 않는다.
          return _Message(
            icon: const Icon(Icons.cloud_off, size: 48),
            text: '데이터를 불러오지 못했습니다',
            action: FilledButton(onPressed: _retry, child: const Text('다시 시도')),
          );
        }
        final data = snapshot.data as T;
        if (widget.isEmpty(data)) {
          return _Message(
            icon: const Icon(Icons.inbox, size: 48),
            text: widget.emptyText,
          );
        }
        return widget.builder(context, data);
      },
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.action});

  final Widget icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: .min,
        children: [
          icon,
          const SizedBox(height: 16),
          Text(text, style: Theme.of(context).textTheme.titleMedium),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}
