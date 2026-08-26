import SwiftUI

public enum MotionTokens {
    public static let pressResponse = Animation.spring(response: 0.3, dampingFraction: 0.7)
    public static let selectionChange = Animation.easeOut(duration: 0.15)
    public static let entrance = Animation.easeOut(duration: 0.2)
    public static let exit = Animation.easeIn(duration: 0.15)
}
