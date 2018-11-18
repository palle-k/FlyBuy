//
//  EANDetector.swift
//  FlightCheck
//
//  Created by Luca Klingenberg on 17.11.18.
//  Copyright © 2018 FlightCheck. All rights reserved.
//

import Foundation
import Vision
import CoreGraphics

struct EANCodeObservation: Codable, Equatable, RectangularObservation {
    var payload: String
    var topLeft: CGPoint
    var topRight: CGPoint
    var bottomLeft: CGPoint
    var bottomRight: CGPoint
}

class EANDetector {
    
    let requestHandler: VNSequenceRequestHandler
    
    init() {
        requestHandler = VNSequenceRequestHandler()
    }
    
    private func makeRequest(imageSize: CGSize, completion: @escaping ([EANCodeObservation]) -> ()) -> VNDetectBarcodesRequest {
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
            
            let results: [EANCodeObservation] = observations.compactMap
            { observation -> (String, (topLeft: CGPoint, topRight: CGPoint, bottomLeft: CGPoint, bottomRight: CGPoint))? in
                observation.payloadStringValue.map {($0, (observation.topLeft, observation.topRight, observation.bottomLeft, observation.bottomRight))}
                }.map { payload, bounds in
                    EANCodeObservation(
                        payload: payload,
                        topLeft: bounds.topLeft.applying(transform),
                        topRight: bounds.topRight.applying(transform),
                        bottomLeft: bounds.bottomLeft.applying(transform),
                        bottomRight: bounds.bottomRight.applying(transform)
                    )
            }
            
            completion(results)
        }
        request.symbologies = [.EAN13,.EAN8]
        request.usesCPUOnly = false
        request.preferBackgroundProcessing = false
        return request
    }

    func detect(in image: CVPixelBuffer, completion: @escaping ([EANCodeObservation]) -> ()) throws {
        let request = makeRequest(imageSize: image.size,completion: completion)
        try requestHandler.perform([request], on: image)
    }
    
    func detect(in image: CIImage, completion: @escaping ([EANCodeObservation]) -> ()) throws {
        let request = makeRequest(imageSize: image.extent.size, completion: completion)
        try requestHandler.perform([request], on: image)
    }
    
    func detect(in image: CGImage, completion: @escaping ([EANCodeObservation]) -> ()) throws {
        let request = makeRequest(imageSize: CGSize(width: image.width, height: image.height), completion: completion)
        try requestHandler.perform([request], on: image)
    }
}
