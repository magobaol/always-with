import Testing
@testable import AlwaysWith

struct AppScannerTests {

    @Test
    func extractsExtensionsFromSingleDocumentType() {
        let docTypes: [[String: Any]] = [
            ["CFBundleTypeExtensions": ["md", "markdown"]]
        ]
        let result = AppScanner.extensions(fromDocumentTypes: docTypes)
        #expect(result == ["md", "markdown"])
    }

    @Test
    func mergesExtensionsAcrossMultipleDocumentTypes() {
        let docTypes: [[String: Any]] = [
            ["CFBundleTypeExtensions": ["md"]],
            ["CFBundleTypeExtensions": ["txt", "log"]],
        ]
        let result = AppScanner.extensions(fromDocumentTypes: docTypes)
        #expect(result == ["md", "txt", "log"])
    }

    @Test
    func skipsEmptyAndWildcardEntries() {
        let docTypes: [[String: Any]] = [
            ["CFBundleTypeExtensions": ["", "*", "md", "  "]]
        ]
        let result = AppScanner.extensions(fromDocumentTypes: docTypes)
        #expect(result == ["md"])
    }

    @Test
    func normalizesCaseAndWhitespace() {
        let docTypes: [[String: Any]] = [
            ["CFBundleTypeExtensions": [" PDF ", "Md", "TXT"]]
        ]
        let result = AppScanner.extensions(fromDocumentTypes: docTypes)
        #expect(result == ["pdf", "md", "txt"])
    }

    @Test
    func ignoresEntriesWithoutExtensionsKey() {
        let docTypes: [[String: Any]] = [
            ["CFBundleTypeName": "Plain text"],
            ["CFBundleTypeExtensions": ["txt"]],
        ]
        let result = AppScanner.extensions(fromDocumentTypes: docTypes)
        #expect(result == ["txt"])
    }

    @Test
    func ignoresEntriesWhereExtensionsHaveWrongType() {
        let docTypes: [[String: Any]] = [
            ["CFBundleTypeExtensions": "md"],
            ["CFBundleTypeExtensions": ["pdf"]],
        ]
        let result = AppScanner.extensions(fromDocumentTypes: docTypes)
        #expect(result == ["pdf"])
    }

    @Test
    func emptyInputProducesEmptySet() {
        let result = AppScanner.extensions(fromDocumentTypes: [])
        #expect(result.isEmpty)
    }

    @Test
    func deduplicatesIdenticalExtensions() {
        let docTypes: [[String: Any]] = [
            ["CFBundleTypeExtensions": ["md", "MD"]],
            ["CFBundleTypeExtensions": [" md "]],
        ]
        let result = AppScanner.extensions(fromDocumentTypes: docTypes)
        #expect(result == ["md"])
    }

    @Test
    func resolvesExtensionsFromLSItemContentTypes() {
        let docTypes: [[String: Any]] = [
            ["LSItemContentTypes": ["public.plain-text"]]
        ]
        let result = AppScanner.extensions(fromDocumentTypes: docTypes)
        #expect(result.contains("txt"))
    }

    @Test
    func mergesExplicitExtensionsAndUTIDerivedOnes() {
        let docTypes: [[String: Any]] = [
            ["CFBundleTypeExtensions": ["log"],
             "LSItemContentTypes": ["public.plain-text"]]
        ]
        let result = AppScanner.extensions(fromDocumentTypes: docTypes)
        #expect(result.contains("log"))
        #expect(result.contains("txt"))
    }

    @Test
    func normalizeExtensionStripsDotWhitespaceAndCase() {
        #expect(AppScanner.normalizeExtension(".ENV") == "env")
        #expect(AppScanner.normalizeExtension("  Md  ") == "md")
        #expect(AppScanner.normalizeExtension("txt") == "txt")
        #expect(AppScanner.normalizeExtension(".gitignore") == "gitignore")
    }

    @Test
    func normalizeExtensionRejectsInvalidInput() {
        #expect(AppScanner.normalizeExtension("") == nil)
        #expect(AppScanner.normalizeExtension("   ") == nil)
        #expect(AppScanner.normalizeExtension(".") == nil)
        #expect(AppScanner.normalizeExtension("*") == nil)
        #expect(AppScanner.normalizeExtension("a.b") == nil)
        #expect(AppScanner.normalizeExtension("a/b") == nil)
        #expect(AppScanner.normalizeExtension("two words") == nil)
    }
}
