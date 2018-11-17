//
//  DroneNavigator.swift
//  JASS 2018
//
//  Created by Veronika Eickhoff on 19.03.18.
//  Copyright © 2018 Palle Klewitz, Veronika Eickhoff. All rights reserved.
//

import Foundation
import CoreGraphics
import CoreVideo
import CoreImage
import Vision
import UIKit

enum DroneNavigationState: String, Codable {
	case idle
	case unknown
	case navigating
	case aboveDestination
	case done
	
	case emergency
}



extension DroneFlightCommand: CustomStringConvertible {
	var description: String {
		switch self {
		case .rotate(let angle):
			return "rotate(\(numberFormatter.string(from: NSNumber(value: angle))!))"
		case .translateHorizontal(x: let x, y: let y):
			let xs = numberFormatter.string(from: NSNumber(value: x))!
			let ys = numberFormatter.string(from: NSNumber(value: y))!
			return "translateHorizontal(x: \(xs), y: \(ys))"
		case .translate(x: let x, y: let y, z: let z, r: let r):
			let xs = numberFormatter.string(from: NSNumber(value: x))!
			let ys = numberFormatter.string(from: NSNumber(value: y))!
			let zs = numberFormatter.string(from: NSNumber(value: z))!
			let rs = numberFormatter.string(from: NSNumber(value: r))!
			return "translate(x: \(xs), y: \(ys), z: \(zs), r: \(rs))"
		case .transformWithFixedHeight(x: let x, y: let y, height: let z, r: let r):
			let xs = numberFormatter.string(from: NSNumber(value: x))!
			let ys = numberFormatter.string(from: NSNumber(value: y))!
			let zs = numberFormatter.string(from: NSNumber(value: z))!
			let rs = numberFormatter.string(from: NSNumber(value: r))!
			return "transformWithFixedHeight(x: \(xs), y: \(ys), z: \(zs), r: \(rs))"
		case .liftOff:
			return "liftOff"
		case .land:
			return "land"
		case .hover:
			return "hover"
		case .fixHeight(let height):
			return "fixHeight(\(height))"
		}
	}
}

struct DroneNavigationPath {
	enum Operation {
		case navigate
		case approach(height: Double)
		case land
	}
	
	struct Segment {
		var operation: Operation
		var location: (x: Double, y: Double)
		var orientation: Double
		var accuracy: Double
		var verticalAccuracy: Double
	}
	
	var path: [Segment]
}

extension DroneNavigationPath {
	init(pickup: (x: Double, y: Double, z: Double), dropOff: (x: Double, y: Double, z: Double), landing: (x: Double, y: Double)) {
		self.path = [
			Segment(operation: .navigate, location: (pickup.x, pickup.y), orientation: 0, accuracy: 0.2, verticalAccuracy: .infinity),
			Segment(operation: .approach(height: pickup.z), location: (pickup.x, pickup.y), orientation: 0, accuracy: 0.08, verticalAccuracy: 0.04),
			Segment(operation: .navigate, location: (dropOff.x, dropOff.y), orientation: 0, accuracy: 0.2, verticalAccuracy: .infinity),
			Segment(operation: .approach(height: dropOff.z), location: (dropOff.x, dropOff.y), orientation: 0, accuracy: 0.1, verticalAccuracy: 0.05),
			Segment(operation: .navigate, location: landing, orientation: 0, accuracy: 0.2, verticalAccuracy: .infinity),
			Segment(operation: .land, location: landing, orientation: 0, accuracy: 0.2, verticalAccuracy: .infinity)
		]
	}
    
    init(landing: (x: Double, y: Double)) {
        self.path = [
            Segment(operation: .navigate, location: landing, orientation: 0, accuracy: 0.2, verticalAccuracy: .infinity),
            Segment(operation: .land, location: landing, orientation: 0, accuracy: 0.2, verticalAccuracy: .infinity)
        ]
    }
}

class DroneNavigator {
	typealias Location = (x:Double, y:Double)
	
	private(set) var state: DroneNavigationState
	
	private let queue = DispatchQueue(label: "DroneNavigator")
	
	private var qrDetector = QRCodeDetector()
	private var locationDetector = DronePositionDetector()
	
	private(set) var currentHeight: Double? = nil
    
	var onLocation: ((Double, Double, Double) -> ())?
	var onCode: (([RectangularObservation]) -> ())?
	
	var lastDefinedStateTime = CACurrentMediaTime()
	var currentRotation: Double? = nil
	var currentLocation: Location? = nil
	
	var path: DroneNavigationPath {
		didSet {
			currentPathIndex = 0
		}
	}
	
	var destinationCell: Location {
		return path.path[currentPathIndex].location
	}
	
	private(set) var currentPathIndex: Int
	
	var currentSegment: DroneNavigationPath.Segment {
		return path.path[currentPathIndex]
	}
	
	private var hasNextSegment: Bool {
		return currentPathIndex + 1 < path.path.count
	}
	
	init(path: DroneNavigationPath) {
		currentPathIndex = 0
		self.path = path
        state = .idle
    }
	
	private func requiredState(for pathSegment: DroneNavigationPath.Segment) -> DroneNavigationState {
		switch pathSegment.operation {
		case .approach:
			return .aboveDestination
			
		case .navigate:
			return .navigating
			
		case .land:
			return .done
		}
	}
	
	private func isSegmentCompleted(_ segment: DroneNavigationPath.Segment, for frame: DroneFrame) -> Bool {
		switch segment.operation {
		case .approach(height: let height):
			guard let currentLocation = approachingHandler.currentPoint, let currentHeight = approachingHandler.currentHeight ?? frame.estimatedHeight else {
				return false
			}
			
			return abs(currentLocation.x) < segment.accuracy && abs(currentLocation.y) < segment.accuracy && abs(height - currentHeight) < segment.verticalAccuracy
			
		case .land:
			return false //TODO: Test whether this is a good choice
			
		case .navigate:
			guard let currentLocation = frame.location else {
				return false
			}
			let destination = segment.location
			return abs(currentLocation.x - destination.x) < segment.accuracy && abs(currentLocation.y - destination.y) < segment.accuracy
		}
	}
	
	func performEmergencyLanding() {
		state = .emergency
		DroneManager.shared.landDrone()
	}
	
	func liftOff() {
		state = .unknown
		execute(.liftOff)
	}
	
	func update(with buffer: CGImage, completion: (() -> ())? = nil) {
		try! qrDetector.detect(in: buffer) { observations in
			
			// Filter to only keep codes with valid payloads
			let observations = observations.filter {
				AerialNavigationCode(base64String: $0.payload) != nil
			}
			
			self.onCode?(observations)
			
			self.locationDetector.update(with: observations) { (position) in
				let frame: DroneFrame
				
				let currentTime = CACurrentMediaTime()
				
				if let (x, y) = position {
					let rotation = normalizeAngle(observations.map({$0.angle}).reduce(0, +) / Double(observations.count))
					
					self.currentLocation = (x, y)
					self.currentRotation = rotation
					self.lastDefinedStateTime = currentTime
					
					if (x, y) == (0, 0) {
						fatalError()
					}
					
					let estimatedHeight = observations.reduce(0) { avg, observation -> Double in
						let width = CGVector(from: observation.topLeft, to: observation.topRight).length
						let height = CGVector(from: observation.topLeft, to: observation.bottomLeft).length
						
						let sideLength = Double(AerialNavigationCode(base64String: observation.payload)?.sideLength ?? 130) * 0.001
						
						// Phantom 4 has approx. 90° FOV, so length on ground == distance to ground
						return avg + (sideLength / (Double(width + height) / 2) - 0.05) / Double(observations.count)
					}
					self.currentHeight = estimatedHeight
					
					frame = DroneFrame(
						image: buffer,
						qrObservations: observations,
						rotation: rotation,
						location: (x, y),
						estimatedHeight: estimatedHeight
					)
					self.onLocation?(x, y, rotation)
				} else if let currentLocation = self.currentLocation, let currentRotation = self.currentRotation, let currentHeight = self.currentHeight, currentTime - self.lastDefinedStateTime < 0.5 {
					frame = DroneFrame(image: buffer, qrObservations: observations, rotation: currentRotation, location: currentLocation, estimatedHeight: currentHeight)
				} else {
					frame = DroneFrame(image: buffer, qrObservations: observations, rotation: nil, location: nil, estimatedHeight: nil)
					self.currentHeight = nil
					self.currentLocation = nil
				}
				
				self.currentPathIndex = self.newSegmentIndex(for: frame)
				self.state = self.newState(for: self.state, frame: frame)
				self.actions(for: self.state, frame: frame) { command in
					self.execute(command)
					completion?()
				}
			}
		}
	}
	
	func newState(for currentState: DroneNavigationState, frame: DroneFrame) -> DroneNavigationState {
		switch currentState {
		case .idle:
			return .idle
			
		case .aboveDestination:
			return requiredState(for: currentSegment)
			
		case .unknown, .navigating:
			if frame.location != nil, frame.rotation != nil {
				return requiredState(for: currentSegment)
			} else {
				return .unknown
			}
			
		case .done:
			return .done
			
		case .emergency:
			return .emergency
		}
	}
	
	func newSegmentIndex(for frame: DroneFrame) -> Int {
		guard hasNextSegment else {
			return currentPathIndex
		}
		if isSegmentCompleted(currentSegment, for: frame) {
			return currentPathIndex + 1
		} else {
			return currentPathIndex
		}
	}
	
	var approachingHandler = TargetApproachingStateHandler(destinationPoint: (0, 0, 0))
	
	func actions(for state: DroneNavigationState, frame: DroneFrame, completion: @escaping (DroneFlightCommand?) -> ()) {
		switch state {
		case .idle:
			return DroneIdleStateHandler().update(with: frame, completion: completion)
			
		case .unknown:
			return DroneUnknownStateHandler().update(with: frame, completion: completion)
			
		case .navigating:
			return DroneNavigationStateHandler(destination: destinationCell).update(with: frame, completion: completion)
			
		case .aboveDestination:
			guard case .approach(height: let height) = currentSegment.operation else {
				print("INVALID STATE! No height given for target approaching")
				return DroneUnknownStateHandler().update(with: frame, completion: completion)
			}
			approachingHandler.destinationPoint = (destinationCell.x, destinationCell.y, height)
			approachingHandler.update(with: frame, completion: completion)
			
		case .done:
			return completion(.land)
			
		case .emergency:
			return EmergencyStateHandler().update(with: frame, completion: completion)
		}
	}
	
	var onExecuteCommand: ((DroneFlightCommand) -> ())?
	
	private func execute(_ command: DroneFlightCommand?) {
		let command = command ?? .hover
		
		onExecuteCommand?(command)
		
		queue.async {
			switch command {
			case .hover:
				DroneManager.shared.hover()
				
			case .land:
				DroneManager.shared.landDrone()
				
			case .liftOff:
				DroneManager.shared.liftoffDrone()
				
			case .translateHorizontal(x: let x, y: let y):
				DroneManager.shared.moveIn(direction: CGVector(dx: x, dy: y))
				
			case .translate(x: let x, y: let y, z: let z, r: let r):
				DroneManager.shared.transform(
					Transformation(
						velocity: Velocity(vx: Float(x), vy: Float(y), vz: Float(z)),
						momentum: Float(r) * 180 / .pi)
				)
				
			case .transformWithFixedHeight(x: let x, y: let y, height: let height, r: let r):
				DroneManager.shared.transform(withDirection: CGVector(dx: x, dy: y), momentum: Float(r) * 180 / .pi, atHeight: Float(height))
				
			case .rotate(let r):
				DroneManager.shared.rotateWith(momentum: Float(r) * 180 / .pi)
				
			case .fixHeight(let height):
				DroneManager.shared.moveWith(velocity: .zero)
				DroneManager.shared.fixHeight(to: Float(height))
			}
		}
	}
}

