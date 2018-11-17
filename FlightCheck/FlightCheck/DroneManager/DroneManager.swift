//
//  DroneManager.swift
//  JASS 2018
//
//  Created by Paul Schmiedmayer on 3/19/18.
//  Copyright © 2018 Paul Schmiedmayer. All rights reserved.
//

import Foundation
import DJISDK
import VideoPreviewer

enum DroneStatus {
    case disconnected, connected(drone: DJIAircraft)
}

class DroneManager: NSObject {
    private(set) var status: DroneStatus = .disconnected
    private(set) var imageListener: [DroneImageListener] = []
    static let shared = DroneManager()
	var frameCounter = 0
    
    var drone: DJIAircraft? {
        guard case let .connected(drone) = status else {
            return nil
        }
        return drone
    }
    
    fileprivate override init() {}
    
    func addImageListener(_ listener: DroneImageListener) {
        imageListener.append(listener)
    }
    
    func removeImageListener(_ listener: DroneImageListener) {
        imageListener = imageListener.filter({ $0 !== listener })
    }
    
    func setupDrone() {
        DJISDKManager.registerApp(with: self)
    }
}

extension DroneManager: DJISDKManagerDelegate {
    func appRegisteredWithError(_ error: Error?) {
        if let error = error {
            print("Could not register with error: \(error.localizedDescription)")
            return
        }
        
        // DJISDKManager.enableBridgeMode(withBridgeAppIP: "172.31.3.126")
        DJISDKManager.startConnectionToProduct()
    }
    
    func productConnected(_ product: DJIBaseProduct?) {
        if let drone = product as? DJIAircraft {
            status = .connected(drone: drone)
            
            setUpDroneImageProvider()
            setupFlightControl()
        }
    }
    
    func productDisconnected() {
        status = .disconnected
    }
}
