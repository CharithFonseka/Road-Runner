package com.roadrunner.app.bridge

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * Flutter plugin that hosts the MethodChannel (roadrunner/control)
 * and EventChannel (roadrunner/events).
 * Owner: Aadila
 * SRS Reference: Section 4.5, Section 8.3
 */
class TrackingBridgePlugin : FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler {

    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var eventSink: EventChannel.EventSink? = null
    private var context: Context? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        methodChannel = MethodChannel(binding.binaryMessenger, Contract.CONTROL_CHANNEL).apply {
            setMethodCallHandler(this@TrackingBridgePlugin)
        }
        eventChannel = EventChannel(binding.binaryMessenger, Contract.EVENTS_CHANNEL).apply {
            setStreamHandler(this@TrackingBridgePlugin)
        }
        instance = this
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
        eventChannel?.setStreamHandler(null)
        eventChannel = null
        eventSink = null
        context = null
        if (instance == this) {
            instance = null
        }
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        val delegate = serviceDelegate
        when (call.method) {
            Contract.METHOD_START_RUN -> {
                if (delegate != null) {
                    delegate.onStartRun(result)
                } else {
                    // Fallback stub if service is not yet bound
                    val runId = "run-${System.currentTimeMillis()}"
                    result.success(mapOf(Contract.KEY_RUN_ID to runId))
                }
            }
            Contract.METHOD_PAUSE_RUN -> {
                if (delegate != null) {
                    delegate.onPauseRun(result)
                } else {
                    result.success(emptyMap<String, Any>())
                }
            }
            Contract.METHOD_RESUME_RUN -> {
                if (delegate != null) {
                    delegate.onResumeRun(result)
                } else {
                    result.success(emptyMap<String, Any>())
                }
            }
            Contract.METHOD_STOP_RUN -> {
                if (delegate != null) {
                    delegate.onStopRun(result)
                } else {
                    val runId = "run-${System.currentTimeMillis()}"
                    result.success(
                        mapOf(
                            Contract.KEY_RUN_ID to runId,
                            Contract.KEY_FILE_PATH to "/data/user/0/com.roadrunner.app/files/runs/$runId.jsonl"
                        )
                    )
                }
            }
            Contract.METHOD_GET_STATE -> {
                if (delegate != null) {
                    delegate.onGetState(result)
                } else {
                    result.success(
                        mapOf(
                            Contract.KEY_STATE to Contract.STATE_IDLE
                        )
                    )
                }
            }
            Contract.METHOD_GET_UNFINISHED_RUN -> {
                if (delegate != null) {
                    delegate.onGetUnfinishedRun(result)
                } else {
                    result.success(null)
                }
            }
            Contract.METHOD_DISCARD_RUN -> {
                val runId = call.argument<String>(Contract.KEY_RUN_ID)
                if (delegate != null) {
                    delegate.onDiscardRun(runId, result)
                } else {
                    result.success(emptyMap<String, Any>())
                }
            }
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        serviceDelegate?.onEventChannelListening(true)
    }

    override fun onCancel(arguments: Any?) {
        serviceDelegate?.onEventChannelListening(false)
        eventSink = null
    }

    /**
     * Interface for the native tracking service to connect to this bridge.
     */
    interface ServiceDelegate {
        fun onStartRun(result: Result)
        fun onPauseRun(result: Result)
        fun onResumeRun(result: Result)
        fun onStopRun(result: Result)
        fun onGetState(result: Result)
        fun onGetUnfinishedRun(result: Result)
        fun onDiscardRun(runId: String?, result: Result)
        fun onEventChannelListening(isListening: Boolean)
    }

    companion object {
        var instance: TrackingBridgePlugin? = null
            private set

        var serviceDelegate: ServiceDelegate? = null

        /**
         * Pushes an event map across the EventChannel to Flutter.
         */
        fun sendEvent(event: Map<String, Any?>) {
            instance?.eventSink?.success(event)
        }

        /**
         * Pushes an error across the EventChannel to Flutter.
         */
        fun sendError(code: String, message: String) {
            instance?.eventSink?.error(code, message, null)
        }
    }
}
