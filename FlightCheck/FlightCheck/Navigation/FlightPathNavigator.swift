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

enum DroneCameraCommand: String, Hashable, Codable {
	case pointForward
	case pointDown
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


struct DroneTarget: Equatable {
	var destination: Position3D
	var orientation: Double
	var desiredHorizontalAccuracy: Double
	var desiredVerticalAccuracy: Double
	var desiredAngularAccuracy: Double
}

extension DroneTarget: Codable {}

struct DroneScanningPathSegment: Equatable {
	enum SegmentOperation: String, Codable, Hashable {
		case approach
		case scan
	}
	
	var target: DroneTarget
	var operation: SegmentOperation
}

extension DroneScanningPathSegment: Codable {}

class FlightPathNavigator {
	private(set) var droneState: DroneState = .idle {
		didSet {
			print("Drone State: \(droneState)")
		}
	}
	private(set) var navigationState: DroneNavigationState = .approaching {
		didSet {
			print("Navigation State: \(navigationState)")
		}
	}
	
	var onExecuteCommand: ((DroneFlightCommand) -> ())?
	var onImageCaptured: ((CGImage) -> ())?
	
	var path: [DroneScanningPathSegment] {
		didSet {
			if path.isEmpty {
				pathIndex = nil
			} else {
				pathIndex = 0
			}
		}
	}
	private(set) var pathIndex: Int? = nil {
		didSet {
			print("Path index: \(pathIndex.map(String.init) ?? "nil")")
		}
	}
	
	var pathElement: DroneScanningPathSegment? {
		return pathIndex.flatMap {path.indices.contains($0) ? path[$0] : nil}
	}
	
	private var stateHandler: StateHandler = DroneIdleStateCoordinator() {
		didSet {
			oldValue.exit()
			stateHandler.onExecuteCommand = onExecuteCommand
			stateHandler.enter()
		}
	}
	
	init(path: [DroneScanningPathSegment]) {
		self.path = path
	}
	
	func beginNavigation() {
		droneState = .flying
		pathIndex = 0
		onExecuteCommand?(.liftOff)
		DroneManager.shared.liftoffDrone()
		stateHandler = DronePositionCoordinator()
	}
	
	func performEmergencyLanding() {
		droneState = .emergency
		stateHandler = DroneEmergencyCoordinator()
		DroneManager.shared.landDrone()
	}
	
	func update(with frame: DroneFrame) {
		guard let pathElement = self.pathElement else {
			if droneState == .emergency {
				DroneManager.shared.landDrone()
			}
			return
		}
		
		if stateHandler.isCompleted(by: frame, destination: pathElement) {
			switch (navigationState, pathElement.operation, pathIndex) {
			case (.approaching, .approach, let index?), (.scanning, .scan, let index?):
				navigationState = .approaching
				pathIndex = index + 1
				if path.indices ~= index + 1 {
					droneState = .flying
					stateHandler = DronePositionCoordinator()
				} else {
					droneState = .idle
					stateHandler = DroneIdleStateCoordinator()
				}
				
			case (.approaching, .scan, _):
				navigationState = .scanning
				let handler = DronePictureCoordinator()
				handler.pictureHandler = onImageCaptured
				stateHandler = handler
				
			default:
				break
			}
		}
		
		stateHandler.update(with: frame, destination: self.pathElement ?? pathElement)
	}
}

