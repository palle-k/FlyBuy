//
//  QRCodeDetector.swift
//  JASS 2018
//
//  Created by Palle Klewitz on 19.03.18.
//  Copyright © 2018 Palle Klewitz. All rights reserved.
//

import Foundation
import Vision
import CoreGraphics

protocol RectangularObservation {
	var topLeft: CGPoint { get }
	var topRight: CGPoint { get }
	var bottomLeft: CGPoint { get }
	var bottomRight: CGPoint { get }
}

extension RectangularObservation {
	var angle: Double {
		let leftAngle = Double(computeAngle((topLeft, bottomLeft), (CGPoint(x: 0, y: 0), CGPoint(x: 0, y: 1))))
		return normalizeAngle(leftAngle + .pi)
	}
	
	var center: CGPoint {
		return [topLeft, topRight, bottomLeft, bottomRight].reduce(into: .zero) { acc, point in
			acc.x += point.x / 4
			acc.y += point.y / 4
		}
	}
}

struct QRCodeObservation: Codable, Equatable, RectangularObservation {
	var payload: String
	var topLeft: CGPoint
	var topRight: CGPoint
	var bottomLeft: CGPoint
	var bottomRight: CGPoint
}

struct RectangleObservation: Codable, Equatable, RectangularObservation {
	var topLeft: CGPoint
	var topRight: CGPoint
	var bottomLeft: CGPoint
	var bottomRight: CGPoint
}

class QRCodeDetector {
	let requestHandler: VNSequenceRequestHandler
	
	init() {
		requestHandler = VNSequenceRequestHandler()
	}
	
	private func makeRequest(imageSize: CGSize, completion: @escaping ([QRCodeObservation]) -> ()) -> VNDetectBarcodesRequest {
		let request = VNDetectBarcodesRequest { request, error in
			if let error = error {
				print(error)
				return
			}
			guard let observations = request.results as? [VNBarcodeObservation] else {
				return
			}
			
			let transform = CGAffineTransform(translationX: -0.5, y: -0.5)
				.concatenating(CGAffineTransform(scaleX: imageSize.width / imageSize.height, y: 1))
				.concatenating(CGAffineTransform(translationX: 0.5, y: 0.5))
			
			let results: [QRCodeObservation] = observations.compactMap { observation -> (String, (topLeft: CGPoint, topRight: CGPoint, bottomLeft: CGPoint, bottomRight: CGPoint))? in
				observation.payloadStringValue.map {($0, (observation.topLeft, observation.topRight, observation.bottomLeft, observation.bottomRight))}
				}.map { payload, bounds in
					QRCodeObservation(
						payload: payload,
						topLeft: bounds.topLeft.applying(transform),
						topRight: bounds.topRight.applying(transform),
						bottomLeft: bounds.bottomLeft.applying(transform),
						bottomRight: bounds.bottomRight.applying(transform)
					)
			}
			completion(results)
		}
		request.symbologies = [.QR]
		request.usesCPUOnly = false
		request.preferBackgroundProcessing = false
		return request
	}
	
	func detect(in image: CVPixelBuffer, completion: @escaping ([QRCodeObservation]) -> ()) throws {
		let request = makeRequest(imageSize: image.size,completion: completion)
		try requestHandler.perform([request], on: image)
	}
	
	func detect(in image: CIImage, completion: @escaping ([QRCodeObservation]) -> ()) throws {
		let request = makeRequest(imageSize: image.extent.size, completion: completion)
		try requestHandler.perform([request], on: image)
	}
	
	func detect(in image: CGImage, completion: @escaping ([QRCodeObservation]) -> ()) throws {
		let request = makeRequest(imageSize: CGSize(width: image.width, height: image.height), completion: completion)
		try requestHandler.perform([request], on: image)
	}
}

func computeAngle(_ firstLine: (CGPoint, CGPoint), _ secondLine: (CGPoint, CGPoint)) -> CGFloat {
	let firstVector = CGVector(from: firstLine.0, to: firstLine.1).normalized
	let secondVector = CGVector(from: secondLine.0, to: secondLine.1).normalized
	
	let dot = firstVector * secondVector
	let det = firstVector.dx * secondVector.dy - firstVector.dy * secondVector.dx
	
	return atan2(det, dot)
}

extension CGVector {
	init(from: CGPoint, to: CGPoint) {
		self.init(dx: to.x - from.x, dy: to.y - from.y)
	}
	
	var normalized: CGVector {
		return CGVector(dx: dx / length, dy: dy / length)
	}
	
	var length: CGFloat {
		return sqrt(self * self)
	}
	
	static func * (lhs: CGVector, rhs: CGVector) -> CGFloat {
		return lhs.dx * rhs.dx + lhs.dy * rhs.dy
	}
}

extension CVPixelBuffer {
	var size: CGSize {
		return CGSize(width: CVPixelBufferGetWidth(self), height: CVPixelBufferGetHeight(self))
	}
}
