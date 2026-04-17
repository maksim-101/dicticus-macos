# Deferred Items - Phase 03

## Pre-existing Issues (Out of Scope)

### PermissionManagerTests.swift references removed `inputMonitoringStatus`
- **Discovered during:** 03-04 Task 1 test execution
- **File:** `Dicticus/DicticusTests/PermissionManagerTests.swift`
- **Issue:** Tests reference `manager.inputMonitoringStatus` which no longer exists on `PermissionManager`. This blocks the entire test target from compiling.
- **Impact:** Cannot run xcodebuild test for any test class until this is fixed
- **Likely cause:** Another phase plan (probably 03-03 or a parallel agent) removed `inputMonitoringStatus` from PermissionManager without updating the test file
- **Fix:** Update PermissionManagerTests.swift to remove references to `inputMonitoringStatus` or add the property back
