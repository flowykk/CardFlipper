import Testing
@testable import Core

@Test func normalizationCollapsesWhitespaceAndCase() {
    #expect(TextNormalizer.searchKey("  Hello   WORLD ") == "hello world")
}
