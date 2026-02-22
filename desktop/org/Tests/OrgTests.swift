import Testing

@Suite("Org Desktop")
struct OrgDesktopTests {
    @Test("App module compiles")
    func appModuleCompiles() {
        #expect(Bool(true))
    }
}
