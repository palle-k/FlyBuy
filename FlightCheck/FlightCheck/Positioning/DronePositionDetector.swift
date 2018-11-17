//
//  DronePositionDetector.swift
//  JASS 2018
//
//  Created by Palle Klewitz on 20.03.18.
//  Copyright © 2018 Paul Schmiedmayer. All rights reserved.
//

import Foundation
import CoreGraphics
import CoreVideo


class DronePositionDetector {
	let qrRecognizer = QRCodeDetector()
	
	init() {}
	
	func update(with observations: [QRCodeObservation], completion: @escaping ((Double, Double)?) -> ()) {
		guard !observations.isEmpty else {
			completion(nil)
			return
		}
		
		let detectedPositions = observations.compactMap { observation -> (x: Double, y: Double)? in
			guard let qrLocation = AerialNavigationCode(base64String: observation.payload) else {
				print("Could not decode QR code")
				return nil
			}
			
			guard qrLocation.x < Int16.max - 1 else {
				return nil
			}
			
			let codeIncrement: Double = 4 // 4 increments per meter
			let codeBasePosition = (Double(qrLocation.x) / codeIncrement, Double(qrLocation.y) / codeIncrement)
			
			let qrSideLength: CGFloat = CGFloat(qrLocation.sideLength) * 0.001 // Convert from mm to m
			
			let qrLeftSide = CGVector(from: observation.bottomLeft, to: observation.topLeft)
			let qrTopSide = CGVector(from: observation.topLeft, to: observation.topRight)
			
			let centerToQR = CGVector(from: CGPoint(x: 0.5, y: 0.5), to: observation.center)
			
			let (lengthFactor, heightFactor) = centerToQR.combine(from: qrTopSide, qrLeftSide)
			
			return (codeBasePosition.0 - Double(qrSideLength * lengthFactor), codeBasePosition.1 - Double(qrSideLength * heightFactor))
		}
		
		guard !detectedPositions.isEmpty else {
			completion(nil)
			return
		}
		
		let estimatedDronePosition = detectedPositions.reduce((0, 0)) { acc, position in
			return (acc.0 + position.0 / Double(detectedPositions.count), acc.1 + position.1 / Double(detectedPositions.count))
		}
		
		completion(estimatedDronePosition)
	}
}

