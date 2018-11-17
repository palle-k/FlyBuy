//
//  DroneManager+ImageProvider.swift
//  JASS 2018
//
//  Created by Paul Schmiedmayer on 3/19/18.
//  Copyright © 2018 Paul Schmiedmayer. All rights reserved.
//

import Foundation
import CoreImage
import DJISDK
import DJIWidget

protocol DroneImageListener: class {
    func accept(newImage image: CGImage)
}

extension DroneManager {
    func setUpDroneImageProvider() {
        DJISDKManager.videoFeeder()?.primaryVideoFeed.add(self, with: nil)
        DJIVideoPreviewer.instance().start()
        
//        drone?.camera?.setExposureMode(.manual, withCompletion: { _ in
//            self.drone?.camera?.setISO(.ISO6400)
//        })
		
		
        // Setup Camera to look down
        DJISDKManager.product()?.gimbal?.rotate(with: DJIGimbalRotation.init(pitchValue: -90,
                                                                             rollValue: 0,
                                                                             yawValue: 0,
                                                                             time: 1.0,
                                                                             mode: DJIGimbalRotationMode.absoluteAngle))
    }
}


extension DroneManager: DJIVideoFeedListener {
    func videoFeed(_ videoFeed: DJIVideoFeed, didUpdateVideoData videoData: Data) {
        videoData.withUnsafeBytes { (pointer: UnsafePointer<UInt8>) in
            let mutablePointer = UnsafeMutablePointer(mutating: pointer)
            DJIVideoPreviewer.instance().push(mutablePointer, length: Int32(videoData.count))
            self.frameCounter += 1
//            guard frameCounter % 10 == 0 else {
//                return
//            }
			DJIVideoPreviewer.instance().snapshotPreview({ (image) in
				guard let image = image else {
					return
				}
				for listener in self.imageListener {
					if let cgImage = image.cgImage {
						listener.accept(newImage: cgImage)
					}
				}
			})
        }
    }
}
