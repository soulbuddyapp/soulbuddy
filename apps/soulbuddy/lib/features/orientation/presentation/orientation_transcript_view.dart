import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../domain/orientation_course.dart';

class OrientationTranscriptView extends StatefulWidget {
  const OrientationTranscriptView({
    required this.transcript,
    required this.position,
    required this.following,
    required this.onManualScroll,
    required this.onSeek,
    this.textScale = 1,
    this.reduceMotion = false,
    super.key,
  });
  final OrientationTranscript transcript;
  final Duration position;
  final bool following, reduceMotion;
  final double textScale;
  final VoidCallback onManualScroll;
  final ValueChanged<Duration> onSeek;
  @override
  State<OrientationTranscriptView> createState() => _TranscriptState();
}

class _TranscriptState extends State<OrientationTranscriptView> {
  final _scroll = ScrollController();
  late List<GlobalKey> _keys;
  bool _autoScrolling = false;
  int _scrollGeneration = 0;
  @override
  void initState() {
    super.initState();
    _keys = List.generate(
      widget.transcript.sentences.length,
      (_) => GlobalKey(),
    );
    _scheduleFollow();
  }

  @override
  void didUpdateWidget(covariant OrientationTranscriptView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.transcript != widget.transcript) {
      _keys = List.generate(
        widget.transcript.sentences.length,
        (_) => GlobalKey(),
      );
    }
    if (widget.following &&
        (!oldWidget.following ||
            oldWidget.transcript.sentenceAt(oldWidget.position) !=
                widget.transcript.sentenceAt(widget.position) ||
            oldWidget.textScale != widget.textScale)) {
      _scheduleFollow();
    }
  }

  void _scheduleFollow() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.following) return;
      final index = widget.transcript.sentenceAt(widget.position);
      if (index == null) return;
      final target = _keys[index].currentContext;
      if (target == null) return;
      final generation = ++_scrollGeneration;
      _autoScrolling = true;
      Scrollable.ensureVisible(
        target,
        alignment: .30,
        duration: widget.reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      ).whenComplete(() {
        if (generation == _scrollGeneration) _autoScrolling = false;
      });
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = widget.transcript.sentenceAt(widget.position);
    final wi = widget.transcript.wordAt(widget.position);
    final word = wi == null ? null : widget.transcript.words[wi];
    final base = theme.textTheme.bodyLarge!.copyWith(
      fontSize: 20,
      height: 1.65,
    );
    final fontSize =
        MediaQuery.textScalerOf(context).scale(20) * widget.textScale;
    return Focus(
      key: const Key('orientation-reading-focus'),
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            widget.following &&
            const [
              LogicalKeyboardKey.arrowDown,
              LogicalKeyboardKey.arrowUp,
              LogicalKeyboardKey.pageDown,
              LogicalKeyboardKey.pageUp,
              LogicalKeyboardKey.home,
              LogicalKeyboardKey.end,
            ].contains(event.logicalKey)) {
          widget.onManualScroll();
        }
        return KeyEventResult.ignored;
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (widget.following &&
              (notification is ScrollStartNotification &&
                      (notification.dragDetails != null || !_autoScrolling) ||
                  notification is UserScrollNotification &&
                      notification.direction != ScrollDirection.idle)) {
            widget.onManualScroll();
          }
          return false;
        },
        child: SingleChildScrollView(
          key: const Key('orientation-transcript'),
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < widget.transcript.sentences.length; i++)
                Builder(
                  builder: (context) {
                    final sentence = widget.transcript.sentences[i];
                    final selected = i == active;
                    final text = widget.transcript.text;
                    final hasWord =
                        word != null &&
                        word.charStart >= sentence.charStart &&
                        word.charEnd <= sentence.charEnd;
                    final spans = <InlineSpan>[];
                    if (hasWord) {
                      spans.add(
                        TextSpan(
                          text: text.substring(
                            sentence.charStart,
                            word.charStart,
                          ),
                        ),
                      );
                      spans.add(
                        TextSpan(
                          text: text.substring(word.charStart, word.charEnd),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline,
                            decorationThickness: 2,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      );
                      spans.add(
                        TextSpan(
                          text: text.substring(word.charEnd, sentence.charEnd),
                        ),
                      );
                    } else {
                      spans.add(
                        TextSpan(
                          text: text.substring(
                            sentence.charStart,
                            sentence.charEnd,
                          ),
                        ),
                      );
                    }
                    return Padding(
                      key: _keys[i],
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Semantics(
                        button: true,
                        selected: selected,
                        label: text.substring(
                          sentence.charStart,
                          sentence.charEnd,
                        ),
                        hint: 'Jump to this sentence',
                        child: Material(
                          color: selected
                              ? theme.colorScheme.primaryContainer
                              : theme.colorScheme.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: selected
                                  ? theme.colorScheme.primary
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: InkWell(
                            key: Key('orientation-sentence-$i'),
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => widget.onSeek(
                              Duration(milliseconds: sentence.startMs),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              child: ExcludeSemantics(
                                child: Text.rich(
                                  key: hasWord
                                      ? const Key('orientation-active-word')
                                      : null,
                                  TextSpan(children: spans),
                                  textScaler: TextScaler.noScaling,
                                  style: base.copyWith(
                                    fontSize: fontSize,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
