//
//  RenderingArguments.swift
//  
//
//  Created by Alistair Leszkiewicz on 11/4/21.
//

import Foundation

public struct RenderingArguments {
    
    /// The mode for rendering attachments
    public let renderingMode: RenderingMode
    
    /// When `true` the report generation process will exclude passing tests
    public let failingTestsOnly: Bool
    
    public init(renderingMode: RenderingMode, failingTestsOnly: Bool) {
        self.renderingMode = renderingMode
        self.failingTestsOnly = failingTestsOnly
    }
    
}

public enum RenderingMode {
    case inline
    case linking
}
