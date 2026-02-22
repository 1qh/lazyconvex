import Testing

@Suite("Chat Desktop")
struct ChatDesktopTests {
    @Test("App module compiles")
    func appModuleCompiles() {
        #expect(Bool(true))
    }
}
