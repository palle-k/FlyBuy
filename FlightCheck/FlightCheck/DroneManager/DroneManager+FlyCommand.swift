//
//  DroneManager+FlyCommand.swift
//  JASS 2018
//
//  Created by Paul Schmiedmayer on 3/19/18.
//  Copyright © 2018 Paul Schmiedmayer. All rights reserved.
//

import Foundation
import DJISDK

extension DroneManager {
    private struct DroneFlyController {
        class DroneTransformation {
            enum DroneHeight: Equatable {
                case fixed(height: Float)
                case velocity(_ : Float)
                case hover
                
                var verticalThrottle: Float {
                    return djiRepresentation.verticalThrottle
                }
                
                var verticalControlMode: DJIVirtualStickVerticalControlMode {
                    return djiRepresentation.verticalControlMode
                }
                
                private var djiRepresentation: (verticalThrottle: Float, verticalControlMode: DJIVirtualStickVerticalControlMode) {
                    switch self {
                    case let .fixed(height):
                        return (height, .position)
                    case let .velocity(velocity):
                        return (velocity, .velocity)
                    case .hover:
                        return DroneHeight.velocity(0.0).djiRepresentation
                    }
                }
            }
            
            enum DroneRotation: Equatable {
                case angle(_: Float)
                case momentum(_: Float)
                case hover
                
                private struct Constants {
                    static let maxRotationSpeed: Float = 90
                }
                
                static var zero: DroneRotation {
                    return hover
                }
                
                var yaw: Float {
                    return max(min(djiRepresentation.yaw, Constants.maxRotationSpeed), -Constants.maxRotationSpeed)
                }
                
                var yawControlMode: DJIVirtualStickYawControlMode {
                    return djiRepresentation.yawControlMode
                }
                
                private var djiRepresentation: (yaw: Float, yawControlMode: DJIVirtualStickYawControlMode) {
                    switch self {
                    case let .angle(angle):
                        return (angle, .angle)
                    case let .momentum(momentum):
                        return (momentum, .angularVelocity)
                    case .hover:
                        return DroneRotation.momentum(0.0).djiRepresentation
                    }
                }
            }
            
            enum DroneVelocity: Equatable {
                case threeDVelocity(_: Velocity)
                case twoDVelocity(_: Velocity, atHeight: DroneHeight)
                
                private struct Constants {
                    static let maxHorizontalSpeed: Float = 1
                }
                
                static var zero: DroneVelocity {
                    return threeDVelocity(.zero)
                }
                
                var vx: Float {
                    switch self {
                    case .threeDVelocity(let velocity), .twoDVelocity(let velocity, _):
                        return max(min(velocity.vx, Constants.maxHorizontalSpeed), -Constants.maxHorizontalSpeed)
                    }
                }
                
                var vy: Float {
                    switch self {
                    case .threeDVelocity(let velocity), .twoDVelocity(let velocity, _):
                        return max(min(velocity.vy, Constants.maxHorizontalSpeed), -Constants.maxHorizontalSpeed)
                    }
                }
                
                var vz: Float {
                    switch self {
                    case let .threeDVelocity(velocity):
                        return velocity.vz
                    case let .twoDVelocity(_, height):
                        return height.verticalThrottle
                    }
                }
                
                var velocity: Velocity {
                    return Velocity(vx: vx, vy: vy, vz: vz)
                }
                
                var height: DroneHeight {
                    get {
                        switch self {
                        case .threeDVelocity:
                            return vz == 0.0 ? .hover : DroneHeight.velocity(vz)
                        case let .twoDVelocity(_, height):
                            return height
                        }
                    }
                    set {
                        self = .twoDVelocity(Velocity(vx: vx, vy: vy), atHeight: newValue)
                    }
                }
                
                var verticalControlMode: DJIVirtualStickVerticalControlMode {
                    switch self {
                    case .threeDVelocity:
                        return .velocity
                    case let .twoDVelocity(_, height):
                        return height.verticalControlMode
                    }
                }
            }
            
            var velocity: DroneVelocity
            var rotation: DroneRotation
            
            static var zero: DroneTransformation {
                get {
                    return DroneTransformation(velocity: .zero, rotation: .zero)
                }
            }
            
            init(velocity: DroneVelocity, rotation: DroneRotation) {
                self.velocity = velocity
                self.rotation = rotation
            }
        }
        
        static let commandsPerSecond: Int = 60
        static var sharedCommandTimer: Timer?
        static var currentCommand: DroneTransformation = .zero
    }
    
    
    func setupFlightControl() {
        guard let flightController = drone?.flightController else {
            return
        }
        
        flightController.setVirtualStickModeEnabled(true)
        flightController.rollPitchCoordinateSystem = .body
        flightController.setFlightOrientationMode(.aircraftHeading)
		flightController.flightAssistant?.setActiveObstacleAvoidanceEnabled(false, withCompletion: nil)
		flightController.flightAssistant?.setCollisionAvoidanceEnabled(false, withCompletion: nil)
		flightController.setVisionAssistedPositioningEnabled(true, withCompletion: nil)
		flightController.flightAssistant?.setUpwardsAvoidanceEnabled(false, withCompletion: nil)
    }
    
    func liftoffDrone(completion: ((Error?) -> ())? = nil) {
		DispatchQueue.main.async {
			guard let flightController = self.drone?.flightController else {
				return
			}
            
            DJISDKManager.product()?.gimbal?.rotate(with: DJIGimbalRotation.init(pitchValue: -90,
                                                                                 rollValue: 0,
                                                                                 yawValue: 0,
                                                                                 time: 1.0,
                                                                                 mode: DJIGimbalRotationMode.absoluteAngle))
			
			let delayedStartingCompletion = {(error: Error?) -> () in
				Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false, block: {_ in
					
					DroneFlyController.sharedCommandTimer?.invalidate()
					DroneFlyController.sharedCommandTimer = Timer.scheduledTimer(withTimeInterval: 1.0/Double(DroneFlyController.commandsPerSecond),
																				 repeats: true,
																				 block: { _ in
                        DispatchQueue.main.async {
                            self.sendCommand()
                        }
					})
					
					if let completion = completion {
						completion(error)
					}
				})
			}
			
			flightController.startTakeoff(completion: delayedStartingCompletion)
		}
    }
    
    func landDrone(completion: ((Error?) -> ())? = nil) {
		DispatchQueue.main.async {
			guard let flightController = self.drone?.flightController else {
				return
			}
			
			flightController.startLanding(completion: { error in
				DroneFlyController.sharedCommandTimer?.invalidate()
				completion?(error)
			})
		}
    }
	
    func rotateWith(momentum: Float) {
        DroneFlyController.currentCommand.rotation = .momentum(momentum)
        DroneFlyController.currentCommand.velocity = .zero
    }
    
    func moveIn(direction: CGVector) {
        DroneFlyController.currentCommand.velocity = .twoDVelocity(Velocity(direction),
                                                                   atHeight: .velocity(DroneFlyController.currentCommand.velocity.vz))
        DroneFlyController.currentCommand.rotation = .hover
    }
    
    func moveWith(velocity: Velocity) {
        DroneFlyController.currentCommand.velocity = .threeDVelocity(velocity)
        DroneFlyController.currentCommand.rotation = .hover
    }
	
    func transform(_ transformation: Transformation) {
        DroneFlyController.currentCommand = DroneFlyController.DroneTransformation(velocity: .threeDVelocity(transformation.velocity),
                                                                                   rotation: .momentum(transformation.momentum))
    }
    
    func fixHeight(to height: Float) {
        DroneFlyController.currentCommand.velocity.height = .fixed(height: height)
        DroneFlyController.currentCommand.rotation = .hover
    }
    
    func transform(withDirection direction: CGVector, momentum: Float, atHeight height: Float) {
        DroneFlyController.currentCommand.velocity = .twoDVelocity(Velocity(direction),
                                                                   atHeight: .fixed(height: height))
        DroneFlyController.currentCommand.rotation = .momentum(momentum)
    }
    
    func hover() {
        DroneFlyController.currentCommand = .zero
    }
    
    private func sendCommand() {
		guard let flightController = self.drone?.flightController else {
			return
		}
		let currentCommand = DroneFlyController.currentCommand
		
		flightController.rollPitchControlMode = .velocity
		flightController.yawControlMode = currentCommand.rotation.yawControlMode
		flightController.verticalControlMode = currentCommand.velocity.verticalControlMode
		
		let stickFlightControlData = DJIVirtualStickFlightControlData(pitch: currentCommand.velocity.vx,
																	  roll: currentCommand.velocity.vy,
																	  yaw: currentCommand.rotation.yaw,
																	  verticalThrottle: currentCommand.velocity.vz)
		
//		print(stickFlightControlData)
		
		flightController.send(stickFlightControlData) { error in
			if let error = error {
				print("Could not send command: \(stickFlightControlData). ERROR: \(error.localizedDescription)")
			}
		}
    }
}
