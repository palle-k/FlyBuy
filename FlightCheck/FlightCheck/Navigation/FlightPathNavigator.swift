//
//  FlightPathNavigator.swift
//  FlightCheck
//
//  Created by Palle Klewitz on 17.11.18.
//  Copyright © 2018 FlightCheck. All rights reserved.
//

import Foundation
import CoreGraphics
import CoreVideo
import CoreImage
import Vision
import UIKit


struct DroneFrame {
	var image: CGImage
	var qrObservations: [QRCodeObservation]
	var rotation: Double?
	var location: (x: Double, y: Double)?
	var estimatedHeight: Double?
}

enum DroneFlightCommand: Hashable {
	case rotate(Double)
	case translateHorizontal(x: Double, y: Double)
	case translate(x: Double, y: Double, z: Double, r: Double)
	case transformWithFixedHeight(x: Double, y: Double, height: Double, r: Double)
	case fixHeight(Double)
	case liftOff
	case land
	case hover
}

enum DroneCameraCommand: String, Hashable {
	case pointForward
	case pointDown
}


enum DroneScanningNavigationState: String, Hashable {
	case idle
	case unknown
	case navigating
	case scanning
	case done
	case emergency
}


struct DroneTarget: Equatable, Codable {
	var destination: Position3D
	var orientation: Double
	var desiredHorizontalAccuracy: Double
	var desiredVerticalAccuracy: Double
	var desiredAngularAccuracy: Double
}

struct DroneScanningPathSegment: Equatable {
	enum SegmentOperation: String, Codable, Hashable {
		case approach
		case scan
	}
	
	var target: DroneTarget
	var operation: SegmentOperation
}


enum ScanningState: String, Hashable {
	case pointingCamera
	case shootingPicture
	case pictureShot
	case resettingCamera
	case completed
}

enum DroneState: String, Hashable {
	enum Event: String, Hashable {
		case liftoff
		case land
		case abort
	}
	
	case idle
	case flying
	case emergency
	
	func changedState(after event: Event) -> DroneState? {
		switch (self, event) {
		case (.idle, .liftoff):
			return .flying
		case (.flying, .land):
			return .idle
		case (.emergency, _), (_, .abort):
			return .emergency
		case (_, _):
			return .none
		}
	}
}


protocol StateHandler: class {
	func enter()
	func exit()
	
	func update(with frame: DroneFrame, destination: DroneScanningPathSegment)
	func isCompleted(by frame: DroneFrame, destination: DroneScanningPathSegment) -> Bool
}


class DronePositionCoordinator: StateHandler {
	func isCompleted(by frame: DroneFrame, destination: DroneScanningPathSegment) -> Bool {
		return isDestinationReached(destination.target, with: frame)
	}
	
	func enter() {
		// pass
	}
	
	func exit() {
		// pass
	}
	
	func update(with frame: DroneFrame, destination: DroneScanningPathSegment) {
		guard let command = update(with: frame, destination: destination.target) else {
			return
		}
		execute(command)
	}
	
	func update(with frame: DroneFrame, destination: DroneTarget) -> DroneFlightCommand? {
		guard let location = frame.location, let rotation = frame.rotation else {
			return nil
		}
		let dx = destination.destination.x - location.x
		let dy = destination.destination.y - location.y
		
		let point = CGPoint(x: dx, y: dy).applying(CGAffineTransform(rotationAngle: CGFloat(-rotation)))
		
		let rotDx = Double(point.x)
		let rotDy = Double(point.y)
		
		let dr = destination.orientation - rotation
		
		let operation: DroneFlightCommand = .transformWithFixedHeight(
			x: rotDx / 3 + sgn(rotDx) * 0.1, // add minimum speed with sign
			y: rotDy / 3 + sgn(rotDy) * 0.1, // add minimum speed with sign
			height: destination.destination.z,
			r: dr * 5
		)
		
		return operation
	}
	
	func isDestinationReached(_ segment: DroneTarget, with frame: DroneFrame) -> Bool {
		guard let (x, y) = frame.location, let z = frame.estimatedHeight, let rotation = frame.rotation else {
			return false
		}
		guard (segment.destination.x - segment.desiredHorizontalAccuracy) ... (segment.destination.x + segment.desiredHorizontalAccuracy) ~= x else {
			return false
		}
		guard (segment.destination.y - segment.desiredHorizontalAccuracy) ... (segment.destination.y + segment.desiredHorizontalAccuracy) ~= y else {
			return false
		}
		guard (segment.destination.z - segment.desiredVerticalAccuracy) ... (segment.destination.z + segment.desiredVerticalAccuracy) ~= z else {
			return false
		}
		guard (segment.orientation - segment.desiredAngularAccuracy) ... (segment.orientation + segment.desiredAngularAccuracy) ~= rotation else {
			return false
		}
		return true
	}
	
	private func execute(_ command: DroneFlightCommand) {
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
					momentum: Float(r) * 180 / .pi
				)
			)
			
		case .transformWithFixedHeight(x: let x, y: let y, height: let height, r: let r):
			DroneManager.shared.transform(
				withDirection: CGVector(dx: x, dy: y),
				momentum: Float(r) * 180 / .pi,
				atHeight: Float(height)
			)
			
		case .rotate(let r):
			DroneManager.shared.rotateWith(momentum: Float(r) * 180 / .pi)
			
		case .fixHeight(let height):
			DroneManager.shared.moveWith(velocity: .zero)
			DroneManager.shared.fixHeight(to: Float(height))
		}
	}
}


class DronePictureCoordinator: StateHandler {
	private var state: ScanningState = .pointingCamera
	
	func enter() {
		state = .shootingPicture
		execute(.pointForward) {
			self.state = .shootingPicture
		}
	}
	
	func exit() {
		state = .pointingCamera
	}
	
	func update(with frame: DroneFrame, destination: DroneScanningPathSegment) {
		if state == .shootingPicture {
			state = .pictureShot // prevent further pictures from being taken
			
			let picture = frame.image
			print(picture)
			
			// if picture is bad, state = .shootingPicture
			
			execute(.pointDown) {
				self.state = .completed
			}
		}
	}
	
	func isCompleted(by frame: DroneFrame, destination: DroneScanningPathSegment) -> Bool {
		return state == .completed
	}
	
	private func execute(_ command: DroneCameraCommand, completion: @escaping () -> ()) {
		switch command {
		case .pointDown:
			DroneManager.shared.pointCamera(to: (-90, 0, 0)) { _ in
				completion()
			}
		case .pointForward:
			DroneManager.shared.pointCamera(to: (0, 0, 0)) { _ in
				completion()
			}
		}
	}
}


class DroneScanningNavigator {
	private(set) var droneState: DroneState = .idle
	
	
	var path: [DroneScanningPathSegment] {
		didSet {
			if path.isEmpty {
				pathIndex = nil
			} else {
				pathIndex = 0
			}
		}
	}
	private(set) var pathIndex: Int? = nil
	
	init(path: [DroneScanningPathSegment]) {
		self.path = path
	}
	
	func beginNavigation() {
		
	}
	
	func performEmergencyLanding() {
		
	}
	
	func update(with frame: DroneFrame) {
		
	}
	
	
	
	
}
