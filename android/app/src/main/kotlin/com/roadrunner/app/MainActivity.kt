package com.roadrunner.app

import com.roadrunner.app.bridge.Contract
import com.roadrunner.app.bridge.TrackingBridgePlugin
import com.roadrunner.app.tracking.RunRecovery
import com.roadrunner.app.tracking.TrackingApi
import com.roadrunner.app.tracking.TrackingRunState
import com.roadrunner.app.tracking.TrackingService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineScope
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

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(TrackingBridgePlugin())
        TrackingBridgePlugin.serviceDelegate = buildServiceDelegate()
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
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

    private fun buildServiceDelegate(): TrackingBridgePlugin.ServiceDelegate =
        object : TrackingBridgePlugin.ServiceDelegate {
            override fun onStartRun(result: Result) {
                try {
                    val runId = TrackingService.startFromVisibleActivity(this@MainActivity)
                    result.success(mapOf(Contract.KEY_RUN_ID to runId))
                } catch (error: Exception) {
                    val msg = error.message ?: "Could not start tracking service"
                    val code = when {
                        error is SecurityException || msg.contains("permission", ignoreCase = true) ->
                            Contract.ERROR_PERMISSION_DENIED
                        msg.contains("location", ignoreCase = true) ->
                            Contract.ERROR_LOCATION_OFF
                        else -> Contract.ERROR_SERVICE_FAILED
                    }
                    result.error(code, msg, null)
                }
            }

            override fun onPauseRun(result: Result) {
                try {
                    TrackingService.pauseFromVisibleActivity(this@MainActivity)
                    result.success(emptyMap<String, Any>())
                } catch (error: Exception) {
                    result.error(
                        Contract.ERROR_SERVICE_FAILED,
                        error.message ?: "Could not pause run",
                        null,
                    )
                }
            }

            override fun onResumeRun(result: Result) {
                try {
                    TrackingService.resumeFromVisibleActivity(this@MainActivity)
                    result.success(emptyMap<String, Any>())
                } catch (error: Exception) {
                    result.error(
                        Contract.ERROR_SERVICE_FAILED,
                        error.message ?: "Could not resume run",
                        null,
                    )
                }
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
