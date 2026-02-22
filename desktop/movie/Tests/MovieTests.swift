import Testing

@Suite("Movie Desktop")
struct MovieDesktopTests {
    @Test("App module compiles")
    func appModuleCompiles() {
        #expect(true)
    }
}
