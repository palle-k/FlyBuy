//
//  EANEvaluator.swift
//  FlightCheck
//
//  Created by Luca Klingenberg on 17.11.18.
//  Copyright © 2018 FlightCheck. All rights reserved.
//

import Foundation
import CoreGraphics
import CoreVideo


class EANEvaluator {
    let eanRecognizer = EANDetector()
    
    init() {}
    
    func update(with observations: [EANCodeObservation], completion: @escaping (String?) -> ()) {
        guard !observations.isEmpty else {
            completion(nil)
            return
        }
        
        let detected = observations.compactMap { observation -> String? in
            return observation.payload
        }
        
        guard !detected.isEmpty else {
            completion(nil)
            return
        }
        
        let mostFrequent = Dictionary(detected.map {($0, 1)}, uniquingKeysWith: +)
            .max(by: {$0.1 < $1.1})?.key
        
        completion(mostFrequent)
    }
}
