import 'package:flutter_test/flutter_test.dart';
import 'package:soulbuddy/core/playback/spiritual_session.dart';
import 'package:soulbuddy/core/playback/spiritual_session_controller.dart';

void main() {
  test('pauses resumes and completes one active session', () async {
    final events = <String>[];
    final controller = SpiritualSessionController();
    await controller.begin(_session('one', events));

    await controller.pause();
    await controller.resume();
    controller.updateProgress(
      position: const Duration(seconds: 4),
      duration: const Duration(seconds: 10),
    );
    expect(controller.state.position, const Duration(seconds: 4));
    await controller.complete();

    expect(events, ['pause:one', 'resume:one', 'complete:one']);
    expect(controller.state.status, SpiritualSessionStatus.idle);
  });

  test('starting another session closes the active one', () async {
    final events = <String>[];
    final controller = SpiritualSessionController();
    await controller.begin(_session('one', events));
    await controller.begin(_session('two', events));

    expect(events, ['close:one']);
    expect(controller.state.session?.id, 'two');
  });
}

SpiritualSession _session(String id, List<String> events) => SpiritualSession(
  id: id,
  kind: SpiritualSessionKind.memory,
  title: 'Session $id',
  route: '/remember/$id',
  canPause: true,
  onPause: () async => events.add('pause:$id'),
  onResume: () async => events.add('resume:$id'),
  onComplete: () async => events.add('complete:$id'),
  onClose: () async => events.add('close:$id'),
);
