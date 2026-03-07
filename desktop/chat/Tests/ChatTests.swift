import Testing

struct ChatDesktopTests {
    @Test("App module compiles")
    func appModuleCompiles() {
        #expect(Bool(true))
    }
}
