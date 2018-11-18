//
//  UploadService.swift
//  FlightCheck
//
//  Created by Luca Klingenberg on 17.11.18.
//  Copyright © 2018 FlightCheck. All rights reserved.
//

import Foundation
import Moya

enum UploadService {
    case uploadImage(name: String, sessionId: Int, img: CGImage, pos: Position3D, angle: Double)
    case start()
    case stop(sessionId: Int)
    case getFlightPath(pathId: Int)
}

extension UploadService: TargetType {
    
    var baseURL: URL {
        return URL(string: "http://131.159.194.230:5000")!
    }
    
    var parameterEncoding: Moya.ParameterEncoding {
        return JSONEncoding.default
    }
    
    var path: String {
        switch self {
        case .uploadImage(_, _, _, _, _): return "/images"
        case .start(): return "/sessions"
        case .stop(_): return "/sessions"
        case .getFlightPath(_): return "/flightpaths"
        }
    }
    
    var method: Moya.Method {
        switch self {
        case .uploadImage(_, _, _, _, _), .start(), .stop(_):
            return .post
        case .getFlightPath(_):
            return .get
        }
    }
    
    var sampleData: Data {
        return Data()
    }
    
    var task: Task {
        switch self {
        case let .uploadImage(name, sessionId, img, pos, angle):
            guard let imgJpg = (UIImage(cgImage: img) as UIImage).jpegData(compressionQuality: 1.0) else {
                return Task.requestPlain
            }
            let imageStr = imgJpg.base64EncodedString()
            return Task.requestParameters(parameters: ["name": name, "session_id": sessionId, "img": imageStr, "pos": pos, "angle": angle], encoding: URLEncoding.queryString)
        case .start():
            return Task.requestParameters(parameters: [:], encoding: URLEncoding.queryString)
        case let .stop(sessionId):
            return Task.requestParameters(parameters: ["session_id": sessionId], encoding: URLEncoding.queryString)
        case let .getFlightPath(pathId):
            return Task.requestParameters(parameters: ["path_id": pathId], encoding: URLEncoding.queryString)
        }
    }
    
    var headers: [String : String]? {
        return ["Content-type": "application/json"]
    }
}

private extension String {
    var urlEscaped: String {
        return addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
    }
    
    var utf8Encoded: Data {
        return data(using: .utf8)!
    }
}
