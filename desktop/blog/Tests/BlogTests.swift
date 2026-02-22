import Testing

@Suite("Blog Desktop")
struct BlogDesktopTests {
    @Test("App module compiles")
    func appModuleCompiles() {
        #expect(true)
    }
}
