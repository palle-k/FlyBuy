//
//  States.swift
//  FlightCheck
//
//  Created by Palle Klewitz on 17.11.18.
//  Copyright © 2018 FlightCheck. All rights reserved.
//

import Foundation


enum DroneNavigationState: String, Hashable {
	case approaching
	case scanning
}


enum ScanningState: String, Hashable {
	case pointingCamera
	case shootingPicture
	case pictureShot
	case resettingCamera
	case completed
}

enum DroneState: String, Hashable {
	enum Event: String, Hashable {
		case liftoff
		case land
		case abort
	}
	
	case idle
	case flying
	case emergency
	
	func changedState(after event: Event) -> DroneState? {
		switch (self, event) {
		case (.idle, .liftoff):
			return .flying
		case (.flying, .land):
			return .idle
		case (.emergency, _), (_, .abort):
			return .emergency
		case (_, _):
			return .none
		}
	}
}

