import 'platform_feedback_driver.dart';
import 'platform_feedback_driver_web.dart'
    if (dart.library.io) 'platform_feedback_driver_io.dart'
    as implementation;

PlatformFeedbackDriver createPlatformFeedbackDriver() =>
    implementation.createPlatformFeedbackDriver();
