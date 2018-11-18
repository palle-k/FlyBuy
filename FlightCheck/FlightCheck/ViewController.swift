//
//  ViewController.swift
//  FlightCheck
//
//  Created by Palle Klewitz on 17.11.18.
//  Copyright © 2018 FlightCheck. All rights reserved.
//

import UIKit
import DJIWidget
import DJISDK
import Moya
import Alamofire


class ViewController: UIViewController {
	
	private var shapeLayer: CAShapeLayer!
	
	private var flightCoordinator = FlightCoordinator(path: [])
	
	private var isBusy = false
    
    private var provider = MoyaProvider<UploadService>()
    private var imageId = 0
    
    private var eanEvaluator = EANEvaluator()
    private var eanDetector = EANDetector()
    
    private var onCode: (([EANCodeObservation]) -> ())? = nil
	
	@IBOutlet weak var commandLabel: UILabel!
	@IBOutlet weak var positionLabel: UILabel!
	@IBOutlet weak var stateLabel: UILabel!
	
	@IBAction func cameraDown(_ sender: Any) {
		DroneManager.shared.rotateCamera(by: (-90, 0, 0)) { _ in }
	}
	
	@IBAction func cameraForward(_ sender: Any) {
		DroneManager.shared.rotateCamera(by: (90, 0, 0)) { _ in }
	}
	
	override var preferredStatusBarStyle: UIStatusBarStyle {
		return .lightContent
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		DJIVideoPreviewer.instance().setView(view)

		DroneManager.shared.addImageListener(self)
//		DroneManager.shared.setupFlightControl()
		
		flightCoordinator.onExecuteCommand = { [weak self] command in
			guard let `self` = self else {
				return
			}
			DispatchQueue.main.async {
				let description = """
				\(dateFormatter.string(from: Date()))
				\(command)
				"""
				self.commandLabel.text = description
			}
		}

		flightCoordinator.onLocation = { [weak self] position, rotation in
			guard let `self` = self else {
				return
			}
			DispatchQueue.main.async {
				self.positionLabel.text = """
				x: \(numberFormatter.string(from: NSNumber(value: position.x))!)
				y: \(numberFormatter.string(from: NSNumber(value: position.y))!)
				z: \(numberFormatter.string(from: NSNumber(value: position.z))!)
				r: \(numberFormatter.string(from: NSNumber(value: rotation))!)
				"""
			}
		}
		
		flightCoordinator.onCode = { [weak self] observations in
			self?.didDetect(observations: observations)
		}
		
		flightCoordinator.onImageCaptured = { [weak self] image, target in
            self?.provider.request(
                .uploadImage(name: "img_\(self?.imageId)",
                             sessionId: 1,
                             img: image,
                             pos: target.destination,
                             angle: target.orientation
            )) { result in
                switch result {
                case .success(let response):
                    print(String(data: response.data, encoding: .utf8)!)
                    self?.imageId += 1
                case .failure(let error):
                    print(error)
                    return
                }
            }
            
            do {
                try self?.eanDetector.detect(in: CIImage(cgImage: image)) {
                    observations in let observations = observations
                    self?.onCode?(observations)
                    self?.eanEvaluator.update(with: observations) {
                        print($0 ?? "no observation")
                    }
                }
            } catch {
                print(error)
            }
		}
		
		shapeLayer = CAShapeLayer()
		shapeLayer.frame = view.bounds
		shapeLayer.strokeColor = UIColor.red.cgColor
		shapeLayer.fillColor = UIColor.clear.cgColor
		shapeLayer.lineJoin = CAShapeLayerLineJoin.round
		shapeLayer.lineWidth = 5.0
		
		view.layer.addSublayer(shapeLayer)
		viewDidLayoutSubviews()
		
		flightCoordinator.path = [
			DroneScanningPathSegment(
				target: DroneTarget(
					destination: Position3D(x: 2, y: 0, z: 1),
					orientation: 0,
					desiredHorizontalAccuracy: 0.2,
					desiredVerticalAccuracy: 0.2,
					desiredAngularAccuracy: 0.5
				),
				operation: .scan
			),
			DroneScanningPathSegment(
				target: DroneTarget(
					destination: Position3D(x: 0, y: 0, z: 1.5),
					orientation: 0,
					desiredHorizontalAccuracy: 0.2,
					desiredVerticalAccuracy: 0.2,
					desiredAngularAccuracy: 0.5
				),
				operation: .approach
			),
		]
		
		UIApplication.shared.isIdleTimerDisabled = true
	}
	
	@IBAction func landDrone(_ sender: Any) {
		flightCoordinator.abort()
	}
	
	@IBAction func beginFlight(_ sender: Any) {
		flightCoordinator.begin()
	}
}

extension ViewController: DroneImageListener {
	func accept(newImage image: CGImage) {
		guard !isBusy else {
			return
		}
		
		isBusy = true
		
		DispatchQueue.global().async {
			self.flightCoordinator.update(with: image) {
				self.isBusy = false
				DispatchQueue.main.async {
					self.stateLabel.text = """
					Drone: \(self.flightCoordinator.navigator.droneState)
					Nav: \(self.flightCoordinator.navigator.navigationState) (idx: \(self.flightCoordinator.navigator.pathIndex.map(String.init) ?? "none"))
					"""
				}
			}
		}
	}
	
	private func transform(point: CGPoint) -> CGPoint {
		return CGPoint(
			x: (point.x - 0.5) * shapeLayer.frame.height + shapeLayer.frame.width / 2,
			y: (1 - point.y) * shapeLayer.frame.height
		)
	}
	
	func didDetect(observations: [RectangularObservation]) {
		DispatchQueue.main.async {
			guard !observations.isEmpty else {
				self.shapeLayer.path = nil
				return
			}
			
			let path = CGMutablePath()
			
			for observation in observations {
				path.move(to: observation.topLeft)
				path.addLines(between: [observation.topLeft, observation.bottomLeft, observation.bottomRight, observation.topRight].map(self.transform))
				path.closeSubpath()
				
				path.addArc(center: self.transform(point: observation.topLeft), radius: 20, startAngle: 0, endAngle: CGFloat.pi * 2, clockwise: false)
				
				path.move(to: self.transform(point: observation.center))
				let angle = -observation.angle
				path.addLine(to: self.transform(point: CGPoint(x: observation.center.x + CGFloat(cos(.pi / 2 + angle)) * 0.25, y: observation.center.y + CGFloat(sin(.pi / 2 + angle)) * 0.25)))
			}
			
			self.shapeLayer?.path = path
		}
	}
}
