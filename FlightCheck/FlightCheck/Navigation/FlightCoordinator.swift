//
//  FlightCoordinator.swift
//  FlightCheck
//
//  Created by Palle Klewitz on 17.11.18.
//  Copyright © 2018 FlightCheck. All rights reserved.
//

import Foundation
import CoreGraphics
import UIKit


class FlightCoordinator {
	private let navigator: FlightPathNavigator
	private let positionDetector = DronePositionDetector()
	private let qrDetector = QRCodeDetector()
	
	private var lastKnownTransform: (location: Position3D, rotation: Double)?
	private var lastKnownTransformTime: TimeInterval?
	
	var onExecuteCommand: ((DroneFlightCommand) -> ())? {
		get {
			return navigator.onExecuteCommand
		}
		set {
			navigator.onExecuteCommand = newValue
		}
	}
	
	var onImageCaptured: ((CGImage) -> ())? {
		get {
			return navigator.onImageCaptured
		}
		set {
			navigator.onImageCaptured = newValue
		}
	}
	
	var onCode: (([QRCodeObservation]) -> ())? = nil
	
	var onLocation: ((Position3D, Double) -> ())? = nil
	
	var path: [DroneScanningPathSegment] {
		get {
			return navigator.path
		}
		set {
			navigator.path = newValue
		}
	}
	
	init(path: [DroneScanningPathSegment]) {
		navigator = FlightPathNavigator(path: path)
	}
	
	func update(with frame: CGImage, completion: (() -> ())? = nil) {
		do {
			try qrDetector.detect(in: frame) { observations in
				let observations = observations.filter {
					AerialNavigationCode(base64String: $0.payload) != nil
				}
				
				self.onCode?(observations)
				
				self.positionDetector.update(with: observations) { position in
					let droneFrame: DroneFrame
					
					if let position = position {
						let rotation = normalizeAngle(observations.map({$0.angle}).reduce(0, +) / Double(observations.count))
						
						let estimatedHeight = observations.reduce(0) { avg, observation -> Double in
							let width = CGVector(from: observation.topLeft, to: observation.topRight).length
							let height = CGVector(from: observation.topLeft, to: observation.bottomLeft).length
							
							let sideLength = Double(AerialNavigationCode(base64String: observation.payload)?.sideLength ?? 130) * 0.001
							
							// Phantom 4 has approx. 90° FOV, so length on ground == distance to ground
							return avg + (sideLength / (Double(width + height) / 2) - 0.05) / Double(observations.count)
						}
						
						self.onLocation?(Position3D(x: position.0, y: position.1, z: estimatedHeight), rotation)
						
						self.lastKnownTransform = (Position3D(x: position.0, y: position.1, z: estimatedHeight), rotation)
						self.lastKnownTransformTime = CACurrentMediaTime()
						
						droneFrame = DroneFrame(
							image: frame,
							qrObservations: observations,
							rotation: rotation,
							location: position,
							estimatedHeight: estimatedHeight
						)
						
					} else if let lastKnownTransform = self.lastKnownTransform, let transformTime = self.lastKnownTransformTime, CACurrentMediaTime() - transformTime < 0.5 {
						droneFrame = DroneFrame(
							image: frame,
							qrObservations: observations,
							rotation: lastKnownTransform.rotation,
							location: (lastKnownTransform.location.x, lastKnownTransform.location.y),
							estimatedHeight: lastKnownTransform.location.z
						)
					} else {
						self.lastKnownTransform = nil
						self.lastKnownTransformTime = nil
						droneFrame = DroneFrame(
							image: frame,
							qrObservations: observations,
							rotation: nil,
							location: nil,
							estimatedHeight: nil
						)
					}
					
					self.navigator.update(with: droneFrame)
					completion?()
				}
			}
		} catch {
			print(error)
			completion?()
		}
	}
	
	func begin() {
		navigator.beginNavigation()
	}
	
	func abort() {
		navigator.performEmergencyLanding()
		lastKnownTransform = nil
		lastKnownTransformTime = nil
	}
}
