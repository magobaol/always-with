import Foundation
import Testing
@testable import AlwaysWith

struct ManualExtensionStoreTests {

    private func makeStore() -> ManualExtensionStore {
        let name = "test.manualExtensions.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return ManualExtensionStore(defaults: defaults, key: "manuallyAddedExtensions")
    }

    @Test
    func startsEmpty() {
        #expect(makeStore().all().isEmpty)
    }

    @Test
    func addNormalizesAndReturnsValue() {
        let store = makeStore()
        #expect(store.add(".ENV ") == "env")
        #expect(store.all() == ["env"])
    }

    @Test
    func addPersistsAcrossInstances() {
        let name = "test.manualExtensions.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        ManualExtensionStore(defaults: defaults, key: "k").add("env")
        let reopened = ManualExtensionStore(defaults: defaults, key: "k")
        #expect(reopened.contains("env"))
        #expect(reopened.all() == ["env"])
    }

    @Test
    func addDeduplicatesRegardlessOfFormatting() {
        let store = makeStore()
        store.add("env")
        store.add(".env")
        store.add("ENV")
        #expect(store.all() == ["env"])
    }

    @Test
    func addRejectsInvalidInput() {
        let store = makeStore()
        #expect(store.add("") == nil)
        #expect(store.add("*") == nil)
        #expect(store.add("a.b") == nil)
        #expect(store.all().isEmpty)
    }

    @Test
    func removeDeletesTheExtension() {
        let store = makeStore()
        store.add("env")
        store.add("ini")
        store.remove(".env")
        #expect(store.all() == ["ini"])
    }

    @Test
    func allIsSorted() {
        let store = makeStore()
        store.add("zsh")
        store.add("env")
        store.add("ini")
        #expect(store.all() == ["env", "ini", "zsh"])
    }
}
