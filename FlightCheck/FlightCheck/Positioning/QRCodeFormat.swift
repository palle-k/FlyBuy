//
//  File.swift
//  JASS 2018
//
//  Created by Palle Klewitz on 19.03.18.
//  Copyright © 2018 Palle Klewitz. All rights reserved.
//

import Foundation
import CoreImage

struct AerialNavigationCode: Codable, Hashable {
	var x: Int16 // Position in increments of 25cm
	var y: Int16
	var sideLength: Int16 // Physical code size in mm
}

extension AerialNavigationCode {
	init?(data: Data) {
		guard [4, 6].contains(data.count) else {
			print("Found invalid code. Ignoring")
			return nil
		}
		
		self = data.withUnsafeBytes { (bytes: UnsafePointer<Int16>) -> AerialNavigationCode in
			AerialNavigationCode(
				x: bytes[0],
				y: bytes[1],
				sideLength: data.count == 4 ? 130 : bytes[2]
			)
		}
	}
	
	init?(base64String string: String) {
		guard let data = Data(base64Encoded: string) else {
			return nil
		}
		self.init(data: data)
	}
	
	var image: CIImage? {
		guard let filter = CIFilter(name: "CIQRCodeGenerator") else {
			print("Unknown filter")
			return nil
		}
		
		let ptr = UnsafeMutablePointer<AerialNavigationCode>.allocate(capacity: 1)
		ptr[0] = self
		let data = Data(bytes: ptr, count: MemoryLayout<AerialNavigationCode>.size)
		let base64 = data.base64EncodedData()
		filter.setValue(base64, forKey: "inputMessage")
		filter.setValue("Q", forKey: "inputCorrectionLevel")
		
		return filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 50, y: 50))
	}
}
