#!/usr/bin/env bash
# check_contract.sh
# Owner: Praveen
# Verifies that all constants in lib/core/contract/contract.dart exactly
# match those in android/.../bridge/Contract.kt (and FilterConfig.kt if present).
#
# Run locally: bash scripts/check_contract.sh
# Also runs in CI on every pull request.

set -euo pipefail

DART_FILE="lib/core/contract/contract.dart"
KOTLIN_FILE="android/app/src/main/kotlin/com/roadrunner/app/bridge/Contract.kt"
FILTER_KT_FILE="android/app/src/main/kotlin/com/roadrunner/app/tracking/FilterConfig.kt"

echo "=== Road Runner contract check ==="
echo "Dart   : $DART_FILE"
echo "Kotlin : $KOTLIN_FILE"
echo ""

ERRORS=0
CHECKED=0

check() {
  local label="$1"
  local dart_value="$2"
  local kotlin_value="$3"

  CHECKED=$((CHECKED + 1))

  if [ -z "$dart_value" ] || [ -z "$kotlin_value" ]; then
    echo "MISSING   $label"
    echo "  Dart  : '${dart_value}'"
    echo "  Kotlin: '${kotlin_value}'"
    ERRORS=$((ERRORS + 1))
  elif [ "$dart_value" != "$kotlin_value" ]; then
    echo "MISMATCH  $label"
    echo "  Dart  : $dart_value"
    echo "  Kotlin: $kotlin_value"
    ERRORS=$((ERRORS + 1))
  else
    echo "OK        $label = '$dart_value'"
  fi
}

extract_dart() {
  local name="$1"
  grep -E "(static )?const (String|int|double) ${name} =" "$DART_FILE" \
    | sed -E "s/.*= '([^']+)';.*/\1/" \
    | sed -E "s/.*= ([0-9._]+);.*/\1/" \
    | sed -E 's/([0-9])_([0-9])/\1\2/g' \
    | sed -E 's/([0-9])_([0-9])/\1\2/g'
}

extract_kotlin() {
  local name="$1"
  local target_file="${2:-$KOTLIN_FILE}"
  grep -E "const val ${name} =" "$target_file" \
    | sed -E 's/.*= "([^"]+)".*/\1/' \
    | sed -E 's/.*= ([0-9._]+).*/\1/' \
    | sed -E 's/([0-9])_([0-9])/\1\2/g' \
    | sed -E 's/([0-9])_([0-9])/\1\2/g'
}

# 1. Channels
check "CONTROL_CHANNEL"           "$(extract_dart kControlChannel)"               "$(extract_kotlin CONTROL_CHANNEL)"
check "EVENTS_CHANNEL"            "$(extract_dart kEventsChannel)"                "$(extract_kotlin EVENTS_CHANNEL)"

# 2. Methods
check "METHOD_START_RUN"          "$(extract_dart kMethodStartRun)"               "$(extract_kotlin METHOD_START_RUN)"
check "METHOD_PAUSE_RUN"          "$(extract_dart kMethodPauseRun)"               "$(extract_kotlin METHOD_PAUSE_RUN)"
check "METHOD_RESUME_RUN"         "$(extract_dart kMethodResumeRun)"              "$(extract_kotlin METHOD_RESUME_RUN)"
check "METHOD_STOP_RUN"           "$(extract_dart kMethodStopRun)"                "$(extract_kotlin METHOD_STOP_RUN)"
check "METHOD_GET_STATE"          "$(extract_dart kMethodGetState)"               "$(extract_kotlin METHOD_GET_STATE)"
check "METHOD_GET_UNFINISHED_RUN" "$(extract_dart kMethodGetUnfinishedRun)"       "$(extract_kotlin METHOD_GET_UNFINISHED_RUN)"
check "METHOD_DISCARD_RUN"        "$(extract_dart kMethodDiscardRun)"             "$(extract_kotlin METHOD_DISCARD_RUN)"
check "BRIDGE_CONTRACT_VERSION"    "$(extract_dart kBridgeContractVersion)"        "$(extract_kotlin BRIDGE_CONTRACT_VERSION)"

# 3. Run states
check "STATE_IDLE"                "$(extract_dart kStateIdle)"                    "$(extract_kotlin STATE_IDLE)"
check "STATE_RUNNING"             "$(extract_dart kStateRunning)"                 "$(extract_kotlin STATE_RUNNING)"
check "STATE_PAUSED"              "$(extract_dart kStatePaused)"                  "$(extract_kotlin STATE_PAUSED)"
check "STATE_STOPPED"             "$(extract_dart kStateStopped)"                 "$(extract_kotlin STATE_STOPPED)"
check "STATE_SAVED"               "$(extract_dart kStateSaved)"                   "$(extract_kotlin STATE_SAVED)"

# 4. Event types
check "EVENT_TYPE_STATE"          "$(extract_dart kEventTypeState)"               "$(extract_kotlin EVENT_TYPE_STATE)"
check "EVENT_TYPE_GPS"            "$(extract_dart kEventTypeGps)"                 "$(extract_kotlin EVENT_TYPE_GPS)"
check "EVENT_TYPE_SNAPSHOT"       "$(extract_dart kEventTypeSnapshot)"            "$(extract_kotlin EVENT_TYPE_SNAPSHOT)"
check "EVENT_TYPE_POINT"          "$(extract_dart kEventTypePoint)"               "$(extract_kotlin EVENT_TYPE_POINT)"
check "EVENT_TYPE_ERROR"          "$(extract_dart kEventTypeError)"               "$(extract_kotlin EVENT_TYPE_ERROR)"

# 5. GPS quality
check "GPS_SEARCHING"             "$(extract_dart kGpsSearching)"                 "$(extract_kotlin GPS_SEARCHING)"
check "GPS_WEAK"                  "$(extract_dart kGpsWeak)"                      "$(extract_kotlin GPS_WEAK)"
check "GPS_GOOD"                  "$(extract_dart kGpsGood)"                      "$(extract_kotlin GPS_GOOD)"

# 6. Error codes
check "ERROR_LOCATION_OFF"        "$(extract_dart kErrorLocationOff)"             "$(extract_kotlin ERROR_LOCATION_OFF)"
check "ERROR_PERMISSION_DENIED"   "$(extract_dart kErrorPermissionDenied)"        "$(extract_kotlin ERROR_PERMISSION_DENIED)"
check "ERROR_SERVICE_FAILED"      "$(extract_dart kErrorServiceFailed)"           "$(extract_kotlin ERROR_SERVICE_FAILED)"

# 7. Bridge payload JSON keys
check "KEY_TYPE"                  "$(extract_dart kKeyType)"                      "$(extract_kotlin KEY_TYPE)"
check "KEY_STATE"                 "$(extract_dart kKeyState)"                     "$(extract_kotlin KEY_STATE)"
check "KEY_RUN_ID"                "$(extract_dart kKeyRunId)"                     "$(extract_kotlin KEY_RUN_ID)"
check "KEY_FILE_PATH"             "$(extract_dart kKeyFilePath)"                  "$(extract_kotlin KEY_FILE_PATH)"
check "KEY_SNAPSHOT"              "$(extract_dart kKeySnapshot)"                  "$(extract_kotlin KEY_SNAPSHOT)"
check "KEY_QUALITY"               "$(extract_dart kKeyQuality)"                   "$(extract_kotlin KEY_QUALITY)"
check "KEY_ELAPSED_MS"            "$(extract_dart kKeyElapsedMs)"                 "$(extract_kotlin KEY_ELAPSED_MS)"
check "KEY_MOVING_MS"             "$(extract_dart kKeyMovingMs)"                  "$(extract_kotlin KEY_MOVING_MS)"
check "KEY_DISTANCE_M"            "$(extract_dart kKeyDistanceM)"                 "$(extract_kotlin KEY_DISTANCE_M)"
check "KEY_SPEED_MPS"             "$(extract_dart kKeySpeedMps)"                  "$(extract_kotlin KEY_SPEED_MPS)"
check "KEY_PACE_SEC_PER_KM"       "$(extract_dart kKeyPaceSecPerKm)"              "$(extract_kotlin KEY_PACE_SEC_PER_KM)"
check "KEY_LAT"                   "$(extract_dart kKeyLat)"                       "$(extract_kotlin KEY_LAT)"
check "KEY_LON"                   "$(extract_dart kKeyLon)"                       "$(extract_kotlin KEY_LON)"
check "KEY_SEQ"                   "$(extract_dart kKeySeq)"                       "$(extract_kotlin KEY_SEQ)"
check "KEY_CODE"                  "$(extract_dart kKeyCode)"                      "$(extract_kotlin KEY_CODE)"
check "KEY_MESSAGE"               "$(extract_dart kKeyMessage)"                   "$(extract_kotlin KEY_MESSAGE)"

# 8. Run file format v1
check "RUN_FILE_VERSION"          "$(extract_dart kRunFileVersion)"               "$(extract_kotlin RUN_FILE_VERSION)"
check "RUN_FILE_KIND_POINT"       "$(extract_dart kRunFileKindPoint)"             "$(extract_kotlin RUN_FILE_KIND_POINT)"
check "RUN_FILE_KIND_STATE"       "$(extract_dart kRunFileKindState)"             "$(extract_kotlin RUN_FILE_KIND_STATE)"
check "RUN_FILE_KIND_END"         "$(extract_dart kRunFileKindEnd)"               "$(extract_kotlin RUN_FILE_KIND_END)"
check "RUN_FILE_KEY_VERSION"      "$(extract_dart kRunFileKeyVersion)"            "$(extract_kotlin RUN_FILE_KEY_VERSION)"
check "RUN_FILE_KEY_KIND"         "$(extract_dart kRunFileKeyKind)"               "$(extract_kotlin RUN_FILE_KEY_KIND)"
check "RUN_FILE_KEY_STARTED_AT"   "$(extract_dart kRunFileKeyStartedAtUtcMs)"     "$(extract_kotlin RUN_FILE_KEY_STARTED_AT_UTC_MS)"
check "RUN_FILE_KEY_SEQ"          "$(extract_dart kRunFileKeySeq)"                "$(extract_kotlin RUN_FILE_KEY_SEQ)"
check "RUN_FILE_KEY_TIME"         "$(extract_dart kRunFileKeyTime)"               "$(extract_kotlin RUN_FILE_KEY_TIME)"
check "RUN_FILE_KEY_LAT"          "$(extract_dart kRunFileKeyLat)"                "$(extract_kotlin RUN_FILE_KEY_LAT)"
check "RUN_FILE_KEY_LON"          "$(extract_dart kRunFileKeyLon)"                "$(extract_kotlin RUN_FILE_KEY_LON)"
check "RUN_FILE_KEY_ACC"          "$(extract_dart kRunFileKeyAcc)"                "$(extract_kotlin RUN_FILE_KEY_ACC)"
check "RUN_FILE_KEY_SPEED"        "$(extract_dart kRunFileKeySpeed)"              "$(extract_kotlin RUN_FILE_KEY_SPEED)"
check "RUN_FILE_KEY_ALT"          "$(extract_dart kRunFileKeyAlt)"                "$(extract_kotlin RUN_FILE_KEY_ALT)"
check "RUN_FILE_KEY_ACCEPTED"     "$(extract_dart kRunFileKeyAccepted)"           "$(extract_kotlin RUN_FILE_KEY_ACCEPTED)"

# 9. FilterConfig constants
check "MAX_ACCURACY_M"            "$(extract_dart maxAccuracyM)"                  "$(extract_kotlin MAX_ACCURACY_M)"
check "FIRST_FIX_MAX_ACCURACY_M"  "$(extract_dart firstFixMaxAccuracyM)"          "$(extract_kotlin FIRST_FIX_MAX_ACCURACY_M)"
check "MAX_IMPLIED_SPEED_MPS"     "$(extract_dart maxImpliedSpeedMps)"            "$(extract_kotlin MAX_IMPLIED_SPEED_MPS)"
check "STATIONARY_SPEED_MPS"      "$(extract_dart stationarySpeedMps)"            "$(extract_kotlin STATIONARY_SPEED_MPS)"
check "TINY_MOVE_M"               "$(extract_dart tinyMoveM)"                     "$(extract_kotlin TINY_MOVE_M)"
check "MAX_GAP_SECONDS"           "$(extract_dart maxGapSeconds)"                 "$(extract_kotlin MAX_GAP_SECONDS)"
check "EARTH_RADIUS_M"            "$(extract_dart earthRadiusM)"                  "$(extract_kotlin EARTH_RADIUS_M)"

# 10. CalcConfig constants
check "MIN_DISTANCE_FOR_PACE_M"   "$(extract_dart minDistanceForPaceM)"           "$(extract_kotlin MIN_DISTANCE_FOR_PACE_M)"
check "MIN_SPEED_FOR_PACE_MPS"    "$(extract_dart minSpeedForPaceMps)"            "$(extract_kotlin MIN_SPEED_FOR_PACE_MPS)"
check "MAX_PACE_SEC_PER_KM"       "$(extract_dart maxPaceSecPerKm)"               "$(extract_kotlin MAX_PACE_SEC_PER_KM)"
check "SPLIT_DISTANCE_M"          "$(extract_dart splitDistanceM)"                "$(extract_kotlin SPLIT_DISTANCE_M)"
check "SPEED_SMOOTHING_WINDOW_S"  "$(extract_dart speedSmoothingWindowS)"         "$(extract_kotlin SPEED_SMOOTHING_WINDOW_S)"

# 11. Also check FilterConfig.kt if present (from tracking module)
if [ -f "$FILTER_KT_FILE" ]; then
  echo ""
  echo "=== Checking tracking/FilterConfig.kt against Contract ==="
  check "FilterConfig.MAX_ACCURACY_M"           "$(extract_dart maxAccuracyM)"         "$(extract_kotlin MAX_ACCURACY_M "$FILTER_KT_FILE")"
  check "FilterConfig.FIRST_FIX_MAX_ACCURACY_M" "$(extract_dart firstFixMaxAccuracyM)" "$(extract_kotlin FIRST_FIX_MAX_ACCURACY_M "$FILTER_KT_FILE")"
  check "FilterConfig.MAX_IMPLIED_SPEED_MPS"    "$(extract_dart maxImpliedSpeedMps)"   "$(extract_kotlin MAX_IMPLIED_SPEED_MPS "$FILTER_KT_FILE")"
  check "FilterConfig.STATIONARY_SPEED_MPS"     "$(extract_dart stationarySpeedMps)"   "$(extract_kotlin STATIONARY_SPEED_MPS "$FILTER_KT_FILE")"
  check "FilterConfig.TINY_MOVE_M"              "$(extract_dart tinyMoveM)"            "$(extract_kotlin TINY_MOVE_M "$FILTER_KT_FILE")"
  check "FilterConfig.EARTH_RADIUS_M"           "$(extract_dart earthRadiusM)"         "$(extract_kotlin EARTH_RADIUS_M "$FILTER_KT_FILE")"
fi

echo ""
if [ $ERRORS -eq 0 ]; then
  echo "✅  All $CHECKED contract constants match."
  exit 0
else
  echo "❌  $ERRORS mismatch(es) found out of $CHECKED checked. Fix before merging."
  exit 1
fi
