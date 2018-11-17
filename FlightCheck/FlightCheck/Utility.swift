//
//  Utility.swift
//  JASS 2018
//
//  Created by Palle Klewitz on 24.03.18.
//  Copyright © 2018 Paul Schmiedmayer. All rights reserved.
//

import Foundation
import CoreGraphics

func normalizeAngle(_ radiands: Double) -> Double {
	var improvedAngle = radiands
	while improvedAngle < 0 {
		improvedAngle += Double.pi * 2
	}
	while improvedAngle >= Double.pi * 2 {
		improvedAngle -= Double.pi * 2
	}
	if improvedAngle > Double.pi {
		return improvedAngle - Double.pi * 2
	}
	return improvedAngle
}


func sgn(_ value: Double) -> Double {
	if value < 0 {
		return -1
	} else if value > 0 {
		return 1
	} else {
		return 0
	}
}

extension CGVector {
	func combine(from first: CGVector, _ second: CGVector) -> (CGFloat, CGFloat) {
		let ux = first.dx
		let uy = first.dy
		let vx = second.dx
		let vy = second.dy
		let wx = dx
		let wy = dy
		
		let b = (wy - wx * uy / ux) / (vy - vx * uy / ux)
		let a = (wx - b * vx) / ux
		
		return (a, b)
	}
}

func sgn(_ value: Float) -> Float {
	return Float(sgn(Double(value)))
}


let numberFormatter: NumberFormatter = {
	let formatter = NumberFormatter()
	formatter.maximumIntegerDigits = 2
	formatter.minimumIntegerDigits = 1
	formatter.minimumFractionDigits = 2
	formatter.maximumFractionDigits = 2
	return formatter
}()

let dateFormatter: DateFormatter = {
	let formatter = DateFormatter()
	formatter.dateFormat = "HH:mm:ss"
	return formatter
}()
