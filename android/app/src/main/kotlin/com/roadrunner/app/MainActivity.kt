package com.roadrunner.app

import android.Manifest
import android.content.pm.PackageManager
import androidx.core.content.ContextCompat
import com.google.android.gms.location.CurrentLocationRequest
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.google.android.gms.tasks.CancellationTokenSource
import com.roadrunner.app.bridge.Contract
import com.roadrunner.app.bridge.TrackingBridgePlugin
import com.roadrunner.app.tracking.DebugRouteSimulator
import com.roadrunner.app.tracking.RunRecovery
import com.roadrunner.app.tracking.TrackingApi
import com.roadrunner.app.tracking.TrackingRunState
import com.roadrunner.app.tracking.TrackingStatus
import com.roadrunner.app.tracking.TrackingService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull

class MainActivity : FlutterActivity() {
    private val activityScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private var eventForwardJob: Job? = null
    private var debugSimChannel: MethodChannel? = null
    private var locationChannel: MethodChannel? = null

    private sealed class ControlOutcome {
        data class Success(val payload: Map<String, Any?> = emptyMap()) : ControlOutcome()
        data class Failure(val code: String, val message: String) : ControlOutcome()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(TrackingBridgePlugin())
        TrackingBridgePlugin.serviceDelegate = buildServiceDelegate()
        locationChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "roadrunner/location",
        ).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "getCurrentLocation" -> getCurrentLocation(result)
                    else -> result.notImplemented()
                }
            }
        }
        if (DebugRouteSimulator.isDebuggable(this)) {
            debugSimChannel = MethodChannel(
                flutterEngine.dartExecutor.binaryMessenger,
                "roadrunner/debug_sim",
            ).apply {
                setMethodCallHandler { call, result ->
                    when (call.method) {
                        "getEnabled" -> result.success(DebugRouteSimulator.isEnabled(this@MainActivity))
                        "setEnabled" -> {
                            val enabled = call.argument<Boolean>("enabled") ?: false
                            DebugRouteSimulator.setEnabled(this@MainActivity, enabled)
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                }
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        locationChannel?.setMethodCallHandler(null)
        locationChannel = null
        debugSimChannel?.setMethodCallHandler(null)
        debugSimChannel = null
        eventForwardJob?.cancel()
        eventForwardJob = null
        TrackingBridgePlugin.serviceDelegate = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onDestroy() {
        eventForwardJob?.cancel()
        eventForwardJob = null
        TrackingBridgePlugin.serviceDelegate = null
        activityScope.cancel()
        super.onDestroy()
    }

    private fun getCurrentLocation(result: Result) {
        val fine = ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION)
        val coarse = ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION)
        if (fine != PackageManager.PERMISSION_GRANTED && coarse != PackageManager.PERMISSION_GRANTED) {
            result.error("PERMISSION_DENIED", "Allow location to see nearby weather and plan routes", null)
            return
        }

        val request = CurrentLocationRequest.Builder()
            .setPriority(Priority.PRIORITY_BALANCED_POWER_ACCURACY)
            .setMaxUpdateAgeMillis(30_000L)
            .setDurationMillis(10_000L)
            .build()
        val cancellation = CancellationTokenSource()
        try {
            LocationServices.getFusedLocationProviderClient(this)
                .getCurrentLocation(request, cancellation.token)
                .addOnSuccessListener { location ->
                    if (location == null) {
                        result.success(null)
                    } else {
                        result.success(mapOf("latitude" to location.latitude, "longitude" to location.longitude))
                    }
                }
                .addOnFailureListener { error ->
                    result.error("LOCATION_UNAVAILABLE", error.message ?: "Current location unavailable", null)
                }
        } catch (error: SecurityException) {
            cancellation.cancel()
            result.error("PERMISSION_DENIED", "Allow location to use your current position", null)
        }
    }

    private fun mapExceptionCode(error: Exception, message: String): String =
        when {
            error is SecurityException || message.contains("permission", ignoreCase = true) ->
                Contract.ERROR_PERMISSION_DENIED
            message.contains("location", ignoreCase = true) ->
                Contract.ERROR_LOCATION_OFF
            else -> Contract.ERROR_SERVICE_FAILED
        }

    private fun parseRunState(wireValue: String?): TrackingRunState? =
        when (wireValue) {
            Contract.STATE_IDLE -> TrackingRunState.IDLE
            Contract.STATE_RUNNING -> TrackingRunState.RUNNING
            Contract.STATE_PAUSED -> TrackingRunState.PAUSED
            Contract.STATE_STOPPED -> TrackingRunState.STOPPED
            else -> null
        }

    private fun awaitServiceTransition(
        timeoutMs: Long,
        timeoutMessage: String,
        result: Result,
        isTargetState: (TrackingRunState) -> Boolean,
        successPayload: (TrackingStatus) -> Map<String, Any?> = { emptyMap() },
        trigger: () -> Unit,
    ) {
        val outcome = CompletableDeferred<ControlOutcome>()

        val collectorJob = activityScope.launch(start = CoroutineStart.UNDISPATCHED) {
            TrackingApi.events.collect { event ->
                when (event[Contract.KEY_TYPE]) {
                    Contract.EVENT_TYPE_ERROR -> {
                        val code = event[Contract.KEY_CODE]?.toString()
                            ?: Contract.ERROR_SERVICE_FAILED
                        val msg = event[Contract.KEY_MESSAGE]?.toString()
                            ?: timeoutMessage
                        outcome.complete(ControlOutcome.Failure(code, msg))
                    }
                    Contract.EVENT_TYPE_STATE -> {
                        val nextState = parseRunState(event[Contract.KEY_STATE]?.toString())
                        if (nextState != null && isTargetState(nextState)) {
                            outcome.complete(
                                ControlOutcome.Success(
                                    successPayload(TrackingApi.status.value),
                                ),
                            )
                        } else if (
                            nextState == TrackingRunState.IDLE ||
                            nextState == TrackingRunState.STOPPED
                        ) {
                            outcome.complete(
                                ControlOutcome.Failure(
                                    Contract.ERROR_SERVICE_FAILED,
                                    "Tracking service is not active",
                                ),
                            )
                        }
                    }
                }
            }
        }

        try {
            trigger()
        } catch (error: Exception) {
            collectorJob.cancel()
            val msg = error.message ?: timeoutMessage
            result.error(mapExceptionCode(error, msg), msg, null)
            return
        }

        val currentStatus = TrackingApi.status.value
        if (!outcome.isCompleted && isTargetState(currentStatus.state)) {
            outcome.complete(ControlOutcome.Success(successPayload(currentStatus)))
        }

        activityScope.launch {
            val resolved = try {
                withTimeoutOrNull(timeoutMs) { outcome.await() }
                    ?: ControlOutcome.Failure(Contract.ERROR_SERVICE_FAILED, timeoutMessage)
            } finally {
                collectorJob.cancel()
            }

            when (resolved) {
                is ControlOutcome.Success -> result.success(resolved.payload)
                is ControlOutcome.Failure -> result.error(resolved.code, resolved.message, null)
            }
        }
    }

    private fun buildServiceDelegate(): TrackingBridgePlugin.ServiceDelegate =
        object : TrackingBridgePlugin.ServiceDelegate {
            override fun onStartRun(result: Result) {
                val current = TrackingApi.status.value
                if (
                    current.state == TrackingRunState.RUNNING ||
                    current.state == TrackingRunState.PAUSED
                ) {
                    result.success(mapOf(Contract.KEY_RUN_ID to (current.runId ?: "")))
                    return
                }

                var startedRunId: String? = null
                awaitServiceTransition(
                    timeoutMs = 5000L,
                    timeoutMessage = "Timed out starting tracking service",
                    result = result,
                    isTargetState = { state ->
                        state == TrackingRunState.RUNNING || state == TrackingRunState.PAUSED
                    },
                    successPayload = { status ->
                        mapOf(Contract.KEY_RUN_ID to (startedRunId ?: status.runId ?: ""))
                    },
                    trigger = {
                        startedRunId = TrackingService.startFromVisibleActivity(this@MainActivity)
                    },
                )
            }

            override fun onPauseRun(result: Result) {
                val current = TrackingApi.status.value
                if (current.state == TrackingRunState.PAUSED) {
                    result.success(emptyMap<String, Any>())
                    return
                }
                if (current.state != TrackingRunState.RUNNING) {
                    result.error(Contract.ERROR_SERVICE_FAILED, "Run is not running", null)
                    return
                }

                awaitServiceTransition(
                    timeoutMs = 3000L,
                    timeoutMessage = "Timed out pausing run",
                    result = result,
                    isTargetState = { state -> state == TrackingRunState.PAUSED },
                    trigger = {
                        TrackingService.pauseFromVisibleActivity(this@MainActivity)
                    },
                )
            }

            override fun onResumeRun(result: Result) {
                val current = TrackingApi.status.value
                if (current.state == TrackingRunState.RUNNING) {
                    result.success(emptyMap<String, Any>())
                    return
                }
                if (current.state != TrackingRunState.PAUSED) {
                    result.error(Contract.ERROR_SERVICE_FAILED, "Run is not paused", null)
                    return
                }

                awaitServiceTransition(
                    timeoutMs = 3000L,
                    timeoutMessage = "Timed out resuming run",
                    result = result,
                    isTargetState = { state -> state == TrackingRunState.RUNNING },
                    trigger = {
                        TrackingService.resumeFromVisibleActivity(this@MainActivity)
                    },
                )
            }

            override fun onStopRun(result: Result) {
                val current = TrackingApi.status.value
                if (current.state == TrackingRunState.IDLE || current.state == TrackingRunState.STOPPED) {
                    result.success(
                        mapOf(
                            Contract.KEY_RUN_ID to (current.runId ?: ""),
                            Contract.KEY_FILE_PATH to (current.filePath ?: ""),
                        ),
                    )
                    return
                }

                try {
                    TrackingService.stopFromVisibleActivity(this@MainActivity)
                } catch (error: Exception) {
                    result.error(
                        Contract.ERROR_SERVICE_FAILED,
                        error.message ?: "Could not stop run",
                        null,
                    )
                    return
                }

                activityScope.launch {
                    val stopped = withTimeoutOrNull(5000L) {
                        TrackingApi.status.first {
                            it.state == TrackingRunState.STOPPED || it.state == TrackingRunState.IDLE
                        }
                    } ?: TrackingApi.status.value

                    result.success(
                        mapOf(
                            Contract.KEY_RUN_ID to (stopped.runId ?: current.runId ?: ""),
                            Contract.KEY_FILE_PATH to (stopped.filePath ?: current.filePath ?: ""),
                        ),
                    )
                }
            }

            override fun onGetState(result: Result) {
                result.success(TrackingApi.status.value.toControlMap())
            }

            override fun onGetUnfinishedRun(result: Result) {
                val filesDir = applicationContext.filesDir
                activityScope.launch {
                    val unfinished = withContext(Dispatchers.IO) {
                        RunRecovery.findLatest(filesDir)
                    }
                    result.success(unfinished?.toControlMap())
                }
            }

            override fun onDiscardRun(runId: String?, result: Result) {
                if (runId.isNullOrBlank()) {
                    result.success(emptyMap<String, Any>())
                    return
                }
                val filesDir = applicationContext.filesDir
                activityScope.launch {
                    withContext(Dispatchers.IO) {
                        RunRecovery.discardUnfinished(filesDir, runId)
                    }
                    result.success(emptyMap<String, Any>())
                }
            }

            override fun onEventChannelListening(isListening: Boolean) {
                eventForwardJob?.cancel()
                eventForwardJob = null
                if (isListening) {
                    eventForwardJob = activityScope.launch {
                        TrackingApi.events.collect { event ->
                            TrackingBridgePlugin.sendEvent(event)
                        }
                    }
                }
            }
        }
}
