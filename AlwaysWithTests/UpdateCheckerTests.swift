import Foundation
import Testing
@testable import AlwaysWith

struct UpdateCheckerTests {

    @Test
    func parsesPlainSemver() {
        #expect(UpdateChecker.parseVersion("1.2.3") == [1, 2, 3])
    }

    @Test
    func stripsLeadingV() {
        #expect(UpdateChecker.parseVersion("v1.0.0") == [1, 0, 0])
        #expect(UpdateChecker.parseVersion("V2.1") == [2, 1])
    }

    @Test
    func dropsPrereleaseSuffix() {
        #expect(UpdateChecker.parseVersion("1.2.3-beta.4") == [1, 2, 3])
    }

    @Test
    func handlesShortVersions() {
        #expect(UpdateChecker.parseVersion("1.0") == [1, 0])
        #expect(UpdateChecker.parseVersion("3") == [3])
    }

    @Test
    func detectsNewerMajor() {
        #expect(UpdateChecker.isVersion("2.0.0", newerThan: "1.9.9") == true)
    }

    @Test
    func detectsNewerMinor() {
        #expect(UpdateChecker.isVersion("1.1.0", newerThan: "1.0.9") == true)
    }

    @Test
    func detectsNewerPatch() {
        #expect(UpdateChecker.isVersion("1.0.1", newerThan: "1.0.0") == true)
    }

    @Test
    func sameVersionIsNotNewer() {
        #expect(UpdateChecker.isVersion("1.0.0", newerThan: "1.0.0") == false)
        #expect(UpdateChecker.isVersion("v1.0.0", newerThan: "1.0.0") == false)
    }

    @Test
    func olderVersionIsNotNewer() {
        #expect(UpdateChecker.isVersion("1.0.0", newerThan: "1.0.1") == false)
        #expect(UpdateChecker.isVersion("1.9.9", newerThan: "2.0.0") == false)
    }

    @Test
    func extraTrailingZerosAreEqual() {
        #expect(UpdateChecker.isVersion("1.0", newerThan: "1.0.0") == false)
        #expect(UpdateChecker.isVersion("1.0.0", newerThan: "1.0") == false)
    }

    @Test
    func trailingNonZeroIsNewer() {
        #expect(UpdateChecker.isVersion("1.0.1", newerThan: "1.0") == true)
    }

    @Test
    func parsesReleaseWithBodyAndZipAsset() throws {
        let json: [String: Any] = [
            "tag_name": "v1.0.2",
            "name": "Release 1.0.2",
            "html_url": "https://github.com/magobaol/always-with/releases/tag/v1.0.2",
            "body": "Version 1.0.2\n\n## Install\n\nDownload and unzip.",
            "assets": [
                [
                    "name": "AlwaysWith-1.0.2.zip",
                    "browser_download_url": "https://github.com/magobaol/always-with/releases/download/v1.0.2/AlwaysWith-1.0.2.zip"
                ]
            ]
        ]
        let release = try UpdateChecker.parseRelease(from: json)
        #expect(release.tag == "v1.0.2")
        #expect(release.name == "Release 1.0.2")
        #expect(release.body?.contains("Install") == true)
        #expect(release.assetURL?.absoluteString.hasSuffix(".zip") == true)
    }

    @Test
    func parsesReleaseWithoutBodyOrAssets() throws {
        let json: [String: Any] = [
            "tag_name": "v1.0.0",
            "html_url": "https://github.com/example/repo/releases/tag/v1.0.0"
        ]
        let release = try UpdateChecker.parseRelease(from: json)
        #expect(release.body == nil)
        #expect(release.assetURL == nil)
    }

    @Test
    func picksFirstZipAssetIgnoringOthers() {
        let assets: [[String: Any]] = [
            ["name": "checksums.txt", "browser_download_url": "https://example.com/checksums.txt"],
            ["name": "AlwaysWith-1.0.0.zip", "browser_download_url": "https://example.com/app.zip"],
            ["name": "AlwaysWith-1.0.0-dbg.zip", "browser_download_url": "https://example.com/dbg.zip"]
        ]
        let url = UpdateChecker.extractZipAssetURL(from: assets)
        #expect(url?.absoluteString == "https://example.com/app.zip")
    }

    @Test
    func returnsNilWhenAssetsAreMissingOrEmpty() {
        #expect(UpdateChecker.extractZipAssetURL(from: nil) == nil)
        #expect(UpdateChecker.extractZipAssetURL(from: [[String: Any]]()) == nil)
        #expect(UpdateChecker.extractZipAssetURL(from: [["name": "notes.md", "browser_download_url": "https://example.com/notes.md"]]) == nil)
    }
}
