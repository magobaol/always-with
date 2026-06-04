import Testing
@testable import AlwaysWith

struct ReleaseNoteBlockTests {

    @Test
    func parsesHeadingsAtVariousLevels() {
        let blocks = ReleaseNoteBlock.parse("# Title\n## Section\n### Subsection")
        #expect(blocks.count == 3)
        if case .heading(let l1) = blocks[0].kind { #expect(l1 == 1) } else { Issue.record("expected heading"); return }
        if case .heading(let l2) = blocks[1].kind { #expect(l2 == 2) } else { Issue.record("expected heading"); return }
        if case .heading(let l3) = blocks[2].kind { #expect(l3 == 3) } else { Issue.record("expected heading"); return }
        #expect(blocks[0].text == "Title")
        #expect(blocks[1].text == "Section")
        #expect(blocks[2].text == "Subsection")
    }

    @Test
    func parsesBullets() {
        let blocks = ReleaseNoteBlock.parse("- first\n* second")
        #expect(blocks.count == 2)
        #expect(blocks[0].kind == .bullet)
        #expect(blocks[0].text == "first")
        #expect(blocks[1].kind == .bullet)
        #expect(blocks[1].text == "second")
    }

    @Test
    func emptyLinesBecomeBlankBlocks() {
        let blocks = ReleaseNoteBlock.parse("para1\n\npara2")
        #expect(blocks.count == 3)
        #expect(blocks[0].kind == .paragraph)
        #expect(blocks[1].kind == .blank)
        #expect(blocks[2].kind == .paragraph)
    }

    @Test
    func hashWithoutSpaceIsNotHeading() {
        let blocks = ReleaseNoteBlock.parse("#NoSpace")
        #expect(blocks.count == 1)
        #expect(blocks[0].kind == .paragraph)
        #expect(blocks[0].text == "#NoSpace")
    }

    @Test
    func headingLevelCapsAtSix() {
        let blocks = ReleaseNoteBlock.parse("####### TooMany")
        #expect(blocks.count == 1)
        // 7 hashes, parser stops at 6 then expects space → finds '#', not a heading
        #expect(blocks[0].kind == .paragraph)
    }

    @Test
    func paragraphPreservesInlineMarkdown() {
        let blocks = ReleaseNoteBlock.parse("Download **the file** and `unzip` it.")
        #expect(blocks.count == 1)
        #expect(blocks[0].kind == .paragraph)
        #expect(blocks[0].text == "Download **the file** and `unzip` it.")
    }
}
