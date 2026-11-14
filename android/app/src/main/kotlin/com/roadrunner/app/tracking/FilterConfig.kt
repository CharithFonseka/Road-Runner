package com.roadrunner.app.tracking

/**
 * Values from section 4.6 of the SRS.
 * Coordinate any future value change through the team's contract process.
 */
object FilterConfig {
    const val MAX_ACCURACY_M = 25.0
    const val FIRST_FIX_MAX_ACCURACY_M = 20.0
    const val MAX_IMPLIED_SPEED_MPS = 12.0
    const val STATIONARY_SPEED_MPS = 0.5
    const val TINY_MOVE_M = 2.0
    const val EARTH_RADIUS_M = 6_371_000.0
}