import CoreGraphics

public enum SpacingTokens {
    public static let unit: CGFloat = 8
    public static let screenMargin: CGFloat = 16
    public static let cardPadding: CGFloat = 16
    public static let sectionSpacing: CGFloat = 24
    public static let itemSpacing: CGFloat = 8
    public static let buttonSpacing: CGFloat = 12
    public static let minTapTarget: CGFloat = 44
}

public enum RadiusTokens {
    public static let card: CGFloat = 20
    public static let nestedInCard: CGFloat = card - SpacingTokens.cardPadding
    public static let input: CGFloat = 12
    public static let pill: CGFloat = 999
}
