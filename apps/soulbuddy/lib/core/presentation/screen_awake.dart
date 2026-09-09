import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Multiple visible practices can share a wake request without cancelling peers.
class ScreenAwakeController {
  ScreenAwakeController({Future<void> Function(bool)? apply})
    : _apply = apply ?? _applyPlatform;

  static final shared = ScreenAwakeController();
  static const channel = MethodChannel('app.soulbuddy/screen_awake');
  final Future<void> Function(bool) _apply;
  final Set<Object> _owners = {};
  Future<void> _pending = Future.value();
  bool _foreground = true;
  bool _requested = false;

  static Future<void> _applyPlatform(bool enabled) async {
    try {
      await channel.invokeMethod<void>('setEnabled', enabled);
    } on MissingPluginException {
      // Other targets retain their normal platform screen behavior.
    } on PlatformException catch (error) {
      debugPrint('Screen awake unavailable: ${error.code}');
    }
  }

  void acquire(Object owner) {
    _owners.add(owner);
    _sync();
  }

  void release(Object owner) {
    _owners.remove(owner);
    _sync();
  }

  void setForeground(bool value) {
    _foreground = value;
    _sync();
  }

  Future<void> get settled => _pending;

  void _sync() {
    final next = _foreground && _owners.isNotEmpty;
    if (next == _requested) return;
    _requested = next;
    _pending = _pending.then((_) => _apply(next));
  }
}

/// Keeps a visible prayer/reading awake and releases on navigation or app pause.
class ScreenAwake extends StatefulWidget {
  const ScreenAwake({required this.child, this.controller, super.key});
  final Widget child;
  final ScreenAwakeController? controller;

  @override
  State<ScreenAwake> createState() => _ScreenAwakeState();
}

class _ScreenAwakeState extends State<ScreenAwake> with WidgetsBindingObserver {
  late final _controller = widget.controller ?? ScreenAwakeController.shared;
  final _owner = Object();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _controller.setForeground(
      lifecycle == null || lifecycle == AppLifecycleState.resumed,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible =
        TickerMode.of(context) && (ModalRoute.of(context)?.isCurrent ?? true);
    if (visible) {
      _controller.acquire(_owner);
    } else {
      _controller.release(_owner);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      _controller.setForeground(state == AppLifecycleState.resumed);

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.release(_owner);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
