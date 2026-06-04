import Foundation
import Testing
@testable import AlwaysWith

struct FilterTests {

    private func makeAssociation(ext: String, defaultAppName: String? = nil) -> ExtensionAssociation {
        let defaultApp = defaultAppName.map {
            AppRef(bundleIdentifier: "com.example.\($0)", name: $0, version: nil, url: URL(fileURLWithPath: "/Applications/\($0).app"))
        }
        return ExtensionAssociation(
            ext: ext,
            uti: "public.\(ext)",
            currentDefaultApp: defaultApp,
            supportingApps: defaultApp.map { [$0] } ?? []
        )
    }

    private var sample: [ExtensionAssociation] {
        [
            makeAssociation(ext: "md", defaultAppName: "Typora"),
            makeAssociation(ext: "mdc", defaultAppName: "Cursor"),
            makeAssociation(ext: "mdown", defaultAppName: "Typora"),
            makeAssociation(ext: "cmd", defaultAppName: "Terminal"),
            makeAssociation(ext: "pdf", defaultAppName: "Preview"),
            makeAssociation(ext: "swift", defaultAppName: "Xcode"),
            makeAssociation(ext: "json"),
        ]
    }

    @Test
    func emptyQueryReturnsAll() {
        let result = AssociationsModel.filter(sample, query: "")
        #expect(result.count == sample.count)
    }

    @Test
    func whitespaceOnlyQueryReturnsAll() {
        let result = AssociationsModel.filter(sample, query: "   ")
        #expect(result.count == sample.count)
    }

    @Test
    func fulltextMatchesAnywhereInExtension() {
        let result = AssociationsModel.filter(sample, query: "md")
        let exts = Set(result.map(\.ext))
        #expect(exts == ["md", "mdc", "mdown", "cmd"])
    }

    @Test
    func fulltextMatchesAppName() {
        let result = AssociationsModel.filter(sample, query: "preview")
        #expect(result.map(\.ext) == ["pdf"])
    }

    @Test
    func fulltextIsCaseInsensitive() {
        let result = AssociationsModel.filter(sample, query: "TYPORA")
        let exts = Set(result.map(\.ext))
        #expect(exts == ["md", "mdown"])
    }

    @Test
    func dotPrefixMatchesOnlyExtensionsStartingWith() {
        let result = AssociationsModel.filter(sample, query: ".md")
        let exts = Set(result.map(\.ext))
        #expect(exts == ["md", "mdc", "mdown"])
        #expect(!exts.contains("cmd"))
    }

    @Test
    func dotPrefixIgnoresAppNameMatches() {
        let result = AssociationsModel.filter(sample, query: ".preview")
        #expect(result.isEmpty)
    }

    @Test
    func dotAloneReturnsAll() {
        let result = AssociationsModel.filter(sample, query: ".")
        #expect(result.count == sample.count)
    }

    @Test
    func queryIsTrimmedBeforeMatching() {
        let result = AssociationsModel.filter(sample, query: "  .md  ")
        let exts = Set(result.map(\.ext))
        #expect(exts == ["md", "mdc", "mdown"])
    }

    @Test
    func noMatchReturnsEmpty() {
        let result = AssociationsModel.filter(sample, query: "xyzzy")
        #expect(result.isEmpty)
    }

    @Test
    func associationsWithoutDefaultAppAreFilterableByExtension() {
        let result = AssociationsModel.filter(sample, query: "json")
        #expect(result.map(\.ext) == ["json"])
    }
}
