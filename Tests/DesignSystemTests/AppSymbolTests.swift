import Testing
@testable import DesignSystem

@Test func entitySymbolsAreStableAndDistinct() {
    #expect(AppSymbol.library == "rectangle.stack.fill")
    #expect(AppSymbol.study == "graduationcap.fill")
    #expect(AppSymbol.tags == "tag")
    #expect(AppSymbol.library != AppSymbol.study)
}
