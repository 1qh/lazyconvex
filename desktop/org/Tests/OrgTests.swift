import Testing

struct OrgDesktopTests {
    @Test("App module compiles")
    func appModuleCompiles() {
        #expect(Bool(true))
    }
}
