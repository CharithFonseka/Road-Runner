package com.roadrunner.app.tracking

fun trackingProblem(
    hasFineLocation: Boolean,
    gpsEnabled: Boolean,
): TrackingErrorCode? = when {
    !hasFineLocation -> TrackingErrorCode.PERMISSION_DENIED
    !gpsEnabled -> TrackingErrorCode.LOCATION_OFF
    else -> null
}