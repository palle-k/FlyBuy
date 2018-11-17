//
//  NavigationStateHandlers.swift
//  JASS 2018
//
//  Created by Palle Klewitz on 24.03.18.
//  Copyright © 2018 Palle Klewitz. All rights reserved.
//

import Foundation
import Vision
import CoreGraphics
import UIKit

protocol DroneStateHandler {
	func update(with frame: DroneFrame, completion: @escaping (DroneFlightCommand?) -> ())
}

struct DroneIdleStateHandler: DroneStateHandler {
	func update(with frame: DroneFrame, completion: @escaping (DroneFlightCommand?) -> ()) {
		completion(nil)
	}
}

struct DroneNavigationStateHandler: DroneStateHandler {
	let destination: (x: Double, y: Double)
	
	init(destination: (x: Double, y: Double)) {
		self.destination = destination
	}
	
	func update(with frame: DroneFrame, completion: @escaping (DroneFlightCommand?) -> ()) {
		guard let location = frame.location, let rotation = frame.rotation else {
			completion(nil)
			return
		}
		let dx = destination.x - location.x
		let dy = destination.y - location.y
		
		let point = CGPoint(x: dx, y: dy).applying(CGAffineTransform(rotationAngle: CGFloat(-rotation)))
		
		let rotDx = Double(point.x)
		let rotDy = Double(point.y)
		
//		let squared = rotation * abs(rotation) / .pi
//		let linear = rotation
//		let targetRotation = max(min(0.5 * squared + 0.5 * linear, .pi), -.pi)
		
		completion(
			.transformWithFixedHeight(
				x: rotDx / 3 + sgn(rotDx) * 0.1,
				y: rotDy / 3 + sgn(rotDy) * 0.1,
				height: 1.25,
				r: 0
			)
		)
	}
}

struct DroneUnknownStateHandler: DroneStateHandler {
	func update(with frame: DroneFrame, completion: @escaping (DroneFlightCommand?) -> ()) {
		completion(.fixHeight(1.5))
	}
}

struct DroneRestingStateHandler: DroneStateHandler {
	func update(with frame: DroneFrame, completion: @escaping (DroneFlightCommand?) -> ()) {
		completion(nil)
	}
}

struct EmergencyStateHandler: DroneStateHandler {
	func update(with frame: DroneFrame, completion: @escaping (DroneFlightCommand?) -> ()) {
		completion(.land)
	}
}

class TargetApproachingStateHandler: DroneStateHandler {
	var destinationPoint: (x: Double, y: Double, z: Double)
	
	var currentPoint: (x: Double, y: Double, z: Double, r: Double)? = nil
	var currentHeight: Double? = nil
	var lastUpdateTime: Double = CACurrentMediaTime()
	
	init(destinationPoint: (x: Double, y: Double, z: Double)) {
		self.destinationPoint = destinationPoint
	}
	
	func update(with frame: DroneFrame, completion: @escaping (DroneFlightCommand?) -> ()) {
		let transformationX: Double
		let transformationY: Double
		let transformationZ: Double
		let rotation: Double
	
		let currentTime = CACurrentMediaTime()
		
		if let observation = frame
			.qrObservations
			.first(where: { observation -> Bool in
				guard let payload = AerialNavigationCode(base64String: observation.payload) else {
					return false
				}
				return payload.x >= Int16.max - 1
			}) {
			
			let width = CGVector(from: observation.topLeft, to: observation.topRight).length
			let height = CGVector(from: observation.topLeft, to: observation.bottomLeft).length
			
			let sideLength = Double(AerialNavigationCode(base64String: observation.payload)?.sideLength ?? 70) * 0.001
			let estimatedHeight = sideLength / (Double(width + height) / 2) - 0.05
			self.currentHeight = estimatedHeight
			
			transformationX = Double(observation.center.x) - 0.5
			transformationY = Double(observation.center.y) - 0.5
			
			if sqrt(transformationX * transformationX + transformationY * transformationY) < 0.2 {
				transformationZ = destinationPoint.z - estimatedHeight + sgn(destinationPoint.z - estimatedHeight) * 0.05
			} else {
				transformationZ = 0
			}
			
			rotation = observation.angle
			
			self.currentPoint = (transformationX, transformationY, transformationZ, rotation)
			self.lastUpdateTime = currentTime
			
		} else if let currentPoint = self.currentPoint, currentTime - lastUpdateTime < 0.1 {
			
			(transformationX, transformationY, transformationZ, rotation) = currentPoint
			
		} else if let location = frame.location, let rot = frame.rotation, let estimatedHeight = frame.estimatedHeight {
			currentPoint = nil
			currentHeight = estimatedHeight
			
			let dx = destinationPoint.x - location.x
			let dy = destinationPoint.y - location.y
			
			let point = CGPoint(x: dx, y: dy).applying(CGAffineTransform(rotationAngle: CGFloat(-rot)))
			
			let targetDistance = CGVector(
				from: CGPoint(x: destinationPoint.x, y: destinationPoint.y),
				to: CGPoint(x: location.x, y: location.y)
			).length
			
			transformationX = Double(point.x)
			transformationY = Double(point.y)
			
			if targetDistance < 0.2 {
				transformationZ = destinationPoint.z - estimatedHeight + sgn(destinationPoint.z - estimatedHeight) * 0.03
			} else {
				transformationZ = 0
			}
			
			rotation = 0
			
		} else {
			completion(.fixHeight(1.4))
			return
		}
		
		let speed = 0.7
		let verticalSpeed = 0.2
		let rotationSpeed = 0.5
		
		let squared = rotation * abs(rotation) / .pi
		let linear = rotation
		let targetRotation = max(min(0.5 * squared + 0.5 * linear, .pi), -.pi)
		
		completion(
			.translate(
				x: transformationX * speed,
				y: transformationY * speed,
				z: transformationZ * verticalSpeed,
				r: targetRotation * rotationSpeed
			)
		)
	}
}
