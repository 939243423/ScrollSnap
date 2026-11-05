import WidgetKit
import SwiftUI

@main
public struct ScrollSnapWidgetBundle: WidgetBundle {
    public init() {}
    
    public var body: some Widget {
        RecentStitchWidget()
        StitchActivityWidget()
    }
}
