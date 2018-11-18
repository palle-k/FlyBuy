//
//  StateHandlers.swift
//  FlightCheck
//
//  Created by Palle Klewitz on 17.11.18.
//  Copyright © 2018 FlightCheck. All rights reserved.
//

import Foundation
import CoreGraphics


protocol StateHandler: class {
	var onExecuteCommand: ((DroneFlightCommand) -> ())? { get set }
	
	func enter()
	func exit()
	
	func update(with frame: DroneFrame, destination: DroneScanningPathSegment)
	func isCompleted(by frame: DroneFrame, destination: DroneScanningPathSegment) -> Bool
}


class DronePositionCoordinator: StateHandler {
	var onExecuteCommand: ((DroneFlightCommand) -> ())? = nil
	
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
			return .hover
		}
		let dx = destination.destination.x - location.x
		let dy = destination.destination.y - location.y
		
		let point = CGPoint(x: dx, y: dy).applying(CGAffineTransform(rotationAngle: CGFloat(-rotation)))
		
		let rotDx = Double(point.x)
		let rotDy = Double(point.y)
		
		let dr = destination.orientation - rotation
		
		let rotationRate = abs(dr) < destination.desiredAngularAccuracy ? 0 : dr * -1.5
		
		let operation: DroneFlightCommand = .transformWithFixedHeight(
			x: rotDx / 3 + sgn(rotDx) * 0.1, // add minimum speed with sign
			y: rotDy / 3 + sgn(rotDy) * 0.1, // add minimum speed with sign
			height: destination.destination.z,
			r: rotationRate
		)
		
		return operation
	}
	
	func isDestinationReached(_ segment: DroneTarget, with frame: DroneFrame) -> Bool {
		guard let (x, y) = frame.location, let rotation = frame.rotation else {
			return false
		}
		guard (segment.destination.x - segment.desiredHorizontalAccuracy) ... (segment.destination.x + segment.desiredHorizontalAccuracy) ~= x else {
			return false
		}
		guard (segment.destination.y - segment.desiredHorizontalAccuracy) ... (segment.destination.y + segment.desiredHorizontalAccuracy) ~= y else {
			return false
		}
		guard (segment.orientation - segment.desiredAngularAccuracy) ... (segment.orientation + segment.desiredAngularAccuracy) ~= rotation else {
			return false
		}
		return true
	}
	
	private func execute(_ command: DroneFlightCommand) {
		onExecuteCommand?(command)
		
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
	var onExecuteCommand: ((DroneFlightCommand) -> ())?
	var pictureHandler: ((CGImage) -> ())?
	
	private var state: ScanningState = .pointingCamera
	
	func enter() {
		state = .pointingCamera
		execute(.pointForward) {
			self.state = .shootingPicture
		}
		onExecuteCommand?(.hover)
		DroneManager.shared.hover()
	}
	
	func exit() {
		state = .pointingCamera
	}
	
	func update(with frame: DroneFrame, destination: DroneScanningPathSegment) {
		if state == .shootingPicture {
			state = .pictureShot // prevent further pictures from being taken
			
			let picture = frame.image
			print("Picture taken")
			pictureHandler?(picture)
			
			// if picture is bad then state = .shootingPicture
			
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
			DroneManager.shared.rotateCamera(by: (-90, 0, 0)) { _ in
				completion()
			}
		case .pointForward:
			DroneManager.shared.rotateCamera(by: (90, 0, 0)) { _ in
				completion()
			}
		}
	}
}

class DroneIdleStateCoordinator: StateHandler {
	var onExecuteCommand: ((DroneFlightCommand) -> ())?
	
	func enter() {
		onExecuteCommand?(.land)
		DroneManager.shared.landDrone()
	}
	
	func exit() {
		// pass
	}
	
	func update(with frame: DroneFrame, destination: DroneScanningPathSegment) {
		// pass
	}
	
	func isCompleted(by frame: DroneFrame, destination: DroneScanningPathSegment) -> Bool {
		return false
	}
}

class DroneEmergencyCoordinator: StateHandler {
	var onExecuteCommand: ((DroneFlightCommand) -> ())?
	
	func enter() {
		onExecuteCommand?(.land)
		DroneManager.shared.landDrone()
	}
	
	func exit() {
		// pass
	}
	
	func update(with frame: DroneFrame, destination: DroneScanningPathSegment) {
		onExecuteCommand?(.land)
		DroneManager.shared.landDrone()
	}
	
	func isCompleted(by frame: DroneFrame, destination: DroneScanningPathSegment) -> Bool {
		return false
	}
}
