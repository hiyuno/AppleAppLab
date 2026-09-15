import Testing
import Foundation
@testable import Fintrol

/// C-12: the `Bmx-Token` is the only credential in this project — cover save, replace,
/// read, delete and the not-found case, per Woz's own Keychain checklist.
@Suite("KeychainStore — Bmx-Token (C-12)")
struct KeychainStoreTests {
    init() throws {
        try? KeychainStore.delete()
    }

    @Test("Reading with nothing saved returns nil, not an error")
    func readsNilWhenNotFound() {
        try? KeychainStore.delete()
        #expect(KeychainStore.read() == nil)
    }

    @Test("Save then read round-trips the exact value")
    func saveThenRead() throws {
        try KeychainStore.save("abc123-token")
        #expect(KeychainStore.read() == "abc123-token")
    }

    @Test("Saving again replaces the value (update path, not duplicate-item error)")
    func saveReplacesExistingValue() throws {
        try KeychainStore.save("first-token")
        try KeychainStore.save("second-token")
        #expect(KeychainStore.read() == "second-token")
    }

    @Test("Delete removes the value; a second delete on an absent item does not throw")
    func deleteRemovesValueAndIsIdempotent() throws {
        try KeychainStore.save("to-be-deleted")
        try KeychainStore.delete()
        #expect(KeychainStore.read() == nil)
        try KeychainStore.delete() // idempotent — errSecItemNotFound must not throw
    }
}
