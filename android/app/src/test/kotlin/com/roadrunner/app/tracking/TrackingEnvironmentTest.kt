package com.roadrunner.app.tracking

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class TrackingEnvironmentTest {
    @Test
    fun permissionLossTakesPriority() {
        assertEquals(
            TrackingErrorCode.PERMISSION_DENIED,
            trackingProblem(
                hasFineLocation = false,
                gpsEnabled = false,
            ),
        )
    }

    @Test
    fun disabledGpsReportsLocationOff() {
        assertEquals(
            TrackingErrorCode.LOCATION_OFF,
            trackingProblem(
                hasFineLocation = true,
                gpsEnabled = false,
            ),
        )
    }

    @Test
    fun readyEnvironmentHasNoProblem() {
        assertNull(
            trackingProblem(
                hasFineLocation = true,
                gpsEnabled = true,
            )
        )
    }
}
