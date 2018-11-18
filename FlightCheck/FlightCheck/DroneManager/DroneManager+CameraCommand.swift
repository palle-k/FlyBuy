//
//  DroneManager+CameraCommand.swift
//  FlightCheck
//
//  Created by Palle Klewitz on 17.11.18.
//  Copyright © 2018 FlightCheck. All rights reserved.
//

import Foundation
import DJISDK

extension DroneManager {
	func rotateCamera(by orientation: (pitch: Double, roll: Double, yaw: Double), completion: @escaping (Error?) -> ()) {
		DJISDKManager.product()?.gimbal?.rotate(
			with: DJIGimbalRotation(pitchValue: NSNumber(value: orientation.pitch),
				rollValue: NSNumber(value: orientation.roll),
				yawValue: NSNumber(value: orientation.yaw),
				time: 1.0,
				mode: DJIGimbalRotationMode.relativeAngle
			),
			completion: { error in
				if let error = error {
					print("Camera rotated: \(error)")
					completion(error)
				} else {
					DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(1200), execute: {
						print("Camera rotated")
						completion(nil)
					})
				}
			}
		)
		
	}
}
