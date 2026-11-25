import Foundation
import XCTest
@testable import EjectBar

final class VolumePreferencesTests: XCTestCase {
    func testMissingPreferencesKeepEnabledDefaults() {
        withIsolatedDefaults { defaults in
            let preferences = VolumePreferences(defaults: defaults)
            XCTAssertTrue(preferences.automaticEject)
            XCTAssertTrue(preferences.remountOnWake)
        }
    }

    func testPersistedDisabledPreferencesAreLoaded() {
        withIsolatedDefaults { defaults in
            defaults.set(false, forKey: "automaticEject")
            defaults.set(false, forKey: "remountOnWake")

            let preferences = VolumePreferences(defaults: defaults)
            XCTAssertFalse(preferences.automaticEject)
            XCTAssertFalse(preferences.remountOnWake)
        }
    }

    private func withIsolatedDefaults(_ body: (UserDefaults) -> Void) {
        let suiteName = "EjectBarTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Could not create isolated user defaults.")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }
        body(defaults)
    }
}

final class VolumePolicyTests: XCTestCase {
    func testInternalVolumesAreNeverManaged() {
        XCTAssertFalse(VolumePolicy.shouldManage(isInternal: true, isRemovable: true, isEjectable: true))
    }

    func testRemovableAndEjectableExternalVolumesAreManaged() {
        XCTAssertTrue(VolumePolicy.shouldManage(isInternal: false, isRemovable: true, isEjectable: false))
        XCTAssertTrue(VolumePolicy.shouldManage(isInternal: false, isRemovable: false, isEjectable: true))
    }

    func testUnknownOrNonRemovableExternalVolumesAreIgnored() {
        XCTAssertFalse(VolumePolicy.shouldManage(isInternal: nil, isRemovable: nil, isEjectable: nil))
        XCTAssertFalse(VolumePolicy.shouldManage(isInternal: false, isRemovable: false, isEjectable: false))
    }
}
