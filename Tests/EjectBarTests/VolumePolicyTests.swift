import XCTest
@testable import EjectBar

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
