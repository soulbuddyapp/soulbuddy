import 'package:flutter/material.dart';

/// Page-local audio must not outlive a visible reading or meditation.
class PracticeAudioScope extends StatefulWidget {
  const PracticeAudioScope({
    required this.onVisibilityChanged,
    required this.child,
    super.key,
  });
  final ValueChanged<bool> onVisibilityChanged;
  final Widget child;

  @override
  State<PracticeAudioScope> createState() => _PracticeAudioScopeState();
}

class _PracticeAudioScopeState extends State<PracticeAudioScope>
    with WidgetsBindingObserver {
  bool _routeVisible = false;
  bool _foreground = true;
  bool _popped = false;
  bool? _visible;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _routeVisible =
        TickerMode.of(context) && (ModalRoute.of(context)?.isCurrent ?? true);
    _sync();
  }

  void _sync() {
    final visible = _routeVisible && _foreground && !_popped;
    if (visible && visible == _visible) return;
    _visible = visible;
    widget.onVisibilityChanged(visible);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _sync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.onVisibilityChanged(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    onPopInvokedWithResult: (didPop, _) {
      if (didPop) {
        _popped = true;
        _sync();
      }
    },
    child: widget.child,
  );
}
