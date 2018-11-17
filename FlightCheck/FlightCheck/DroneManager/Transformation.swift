//
//  Transformation.swift
//  JASS 2018
//
//  Created by Paul Schmiedmayer on 3/21/18.
//  Copyright © 2018 Paul Schmiedmayer. All rights reserved.
//

import Foundation
import CoreGraphics

class Velocity {
    var vx: Float
    var vy: Float
    var vz: Float
    
    static var zero: Velocity {
        return Velocity(vx: 0.0, vy: 0.0, vz: 0.0)
    }
    
    init(vx: Float, vy: Float, vz: Float = 0.0) {
        self.vx = vx
        self.vy = vy
        self.vz = vz
    }
    
    init(_ cgvector: CGVector) {
        self.vx = Float(cgvector.dx)
        self.vy = Float(cgvector.dy)
        self.vz = 0.0
    }
}

extension Velocity: Equatable {
    static func == (lhs: Velocity, rhs: Velocity) -> Bool {
        return lhs.vx == rhs.vx && lhs.vy == rhs.vy && lhs.vz == rhs.vz
    }
}

class Transformation {
    var velocity: Velocity
    var momentum: Float
    
    static var zero: Transformation {
        return Transformation(velocity: .zero, momentum: 0.0)
    }
    
    init(velocity: Velocity, momentum: Float = 0.0) {
        self.velocity = velocity
        self.momentum = momentum
    }
}

extension Transformation: Equatable {
    static func == (lhs: Transformation, rhs: Transformation) -> Bool {
        return lhs.velocity == rhs.velocity && lhs.momentum == rhs.momentum
    }
}
