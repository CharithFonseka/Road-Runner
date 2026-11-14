// Road Runner — Native TrackingBridge Implementation (MethodChannel + EventChannel)
// Owner: Aadila
// SRS reference: Section 4.5, 8.3

import 'dart:async';
import 'package:flutter/services.dart';
import 'package:road_runner/core/contract/contract.dart';
import 'tracking_bridge.dart';

/// Real implementation of [TrackingBridge] that communicates with the native
/// Kotlin TrackingService using MethodChannel and EventChannel.
class NativeTrackingBridge implements TrackingBridge {
  final MethodChannel _controlChannel;
  final EventChannel _eventsChannel;

  StreamSubscription<dynamic>? _subscription;
  final StreamController<TrackingEvent> _eventController =
      StreamController<TrackingEvent>.broadcast();

  NativeTrackingBridge({
    MethodChannel? controlChannel,
    EventChannel? eventsChannel,
  })  : _controlChannel =
            controlChannel ?? const MethodChannel(kControlChannel),
        _eventsChannel =
            eventsChannel ?? const EventChannel(kEventsChannel) {
    _initEventStream();
  }

  void _initEventStream() {
    _subscription = _eventsChannel.receiveBroadcastStream().listen(
      (dynamic rawEvent) {
        if (rawEvent is Map) {
          final event = TrackingEvent.fromMap(rawEvent);
          if (event != null) {
            _eventController.add(event);
          }
        }
      },
      onError: (Object error) {
        String code = kErrorServiceFailed;
        String message = error.toString();
        if (error is PlatformException) {
          code = _mapErrorCode(error.code);
          message = error.message ?? error.toString();
        }
        _eventController.add(TrackingErrorEvent(
          code: code,
          message: message,
        ));
      },
      cancelOnError: false,
    );
  }

  @override
  Stream<TrackingEvent> get events => _eventController.stream;

  @override
  Future<String> startRun() async {
    try {
      final result = await _controlChannel.invokeMethod<Map<dynamic, dynamic>>(
        kMethodStartRun,
      );
      final runId = result?[kKeyRunId] as String?;
      if (runId == null || runId.isEmpty) {
        throw PlatformException(
          code: kErrorServiceFailed,
          message: 'Native startRun did not return a valid runId',
        );
      }
      return runId;
    } on PlatformException catch (e) {
      _rethrowMappedError(e);
    }
  }

  @override
  Future<void> pauseRun() async {
    try {
      await _controlChannel.invokeMethod<void>(kMethodPauseRun);
    } on PlatformException catch (e) {
      _rethrowMappedError(e);
    }
  }

  @override
  Future<void> resumeRun() async {
    try {
      await _controlChannel.invokeMethod<void>(kMethodResumeRun);
    } on PlatformException catch (e) {
      _rethrowMappedError(e);
    }
  }

  @override
  Future<RunResult> stopRun() async {
    try {
      final result = await _controlChannel.invokeMethod<Map<dynamic, dynamic>>(
        kMethodStopRun,
      );
      if (result == null) {
        throw PlatformException(
          code: kErrorServiceFailed,
          message: 'Native stopRun returned null payload',
        );
      }
      return RunResult.fromMap(result);
    } on PlatformException catch (e) {
      _rethrowMappedError(e);
    }
  }

  @override
  Future<TrackingStatus> getState() async {
    try {
      final result = await _controlChannel.invokeMethod<Map<dynamic, dynamic>>(
        kMethodGetState,
      );
      if (result == null) {
        return const TrackingStatus(state: kStateIdle);
      }
      return TrackingStatus.fromMap(result);
    } on PlatformException catch (e) {
      _rethrowMappedError(e);
    }
  }

  @override
  Future<RunResult?> getUnfinishedRun() async {
    try {
      final result = await _controlChannel.invokeMethod<Map<dynamic, dynamic>>(
        kMethodGetUnfinishedRun,
      );
      if (result == null) {
        return null;
      }
      return RunResult.fromMap(result);
    } on PlatformException catch (e) {
      _rethrowMappedError(e);
    }
  }

  @override
  Future<void> discardRun(String runId) async {
    try {
      await _controlChannel.invokeMethod<void>(
        kMethodDiscardRun,
        {kKeyRunId: runId},
      );
    } on PlatformException catch (e) {
      _rethrowMappedError(e);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _eventController.close();
  }

  String _mapErrorCode(String? rawCode) {
    switch (rawCode) {
      case kErrorLocationOff:
        return kErrorLocationOff;
      case kErrorPermissionDenied:
        return kErrorPermissionDenied;
      default:
        return kErrorServiceFailed;
    }
  }

  Never _rethrowMappedError(PlatformException e) {
    throw PlatformException(
      code: _mapErrorCode(e.code),
      message: e.message ?? 'Unknown tracking error',
      details: e.details,
    );
  }
}
