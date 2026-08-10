import SwiftUI

struct TagChipLayout: Layout {
    var horizontalSpacing: CGFloat
    var verticalSpacing: CGFloat

    init(horizontalSpacing: CGFloat = 8, verticalSpacing: CGFloat = 8) {
        self.horizontalSpacing = horizontalSpacing
        self.verticalSpacing = verticalSpacing
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        arrangement(maxWidth: proposal.width ?? .infinity, subviews: subviews).size
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let arrangement = arrangement(maxWidth: bounds.width, subviews: subviews)

        for (placement, subview) in zip(arrangement.placements, subviews) {
            subview.place(
                at: CGPoint(
                    x: bounds.minX + placement.origin.x,
                    y: bounds.minY + placement.origin.y
                ),
                anchor: .topLeading,
                proposal: ProposedViewSize(placement.size)
            )
        }
    }

    private func arrangement(maxWidth: CGFloat, subviews: Subviews) -> Arrangement {
        guard !subviews.isEmpty else {
            return Arrangement(placements: [], size: .zero)
        }

        var placements: [Placement] = []
        var cursor = CGPoint.zero
        var rowHeight: CGFloat = 0
        var measuredWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let proposedX = cursor.x == 0 ? 0 : cursor.x + horizontalSpacing

            if proposedX > 0, proposedX + size.width > maxWidth {
                cursor.x = 0
                cursor.y += rowHeight + verticalSpacing
                rowHeight = 0
            } else {
                cursor.x = proposedX
            }

            placements.append(Placement(origin: cursor, size: size))
            measuredWidth = max(measuredWidth, cursor.x + size.width)
            rowHeight = max(rowHeight, size.height)
            cursor.x += size.width
        }

        return Arrangement(
            placements: placements,
            size: CGSize(width: measuredWidth, height: cursor.y + rowHeight)
        )
    }
}

private extension TagChipLayout {
    struct Placement {
        let origin: CGPoint
        let size: CGSize
    }

    struct Arrangement {
        let placements: [Placement]
        let size: CGSize
    }
}
