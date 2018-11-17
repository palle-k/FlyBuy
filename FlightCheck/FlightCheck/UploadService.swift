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
    case uploadImage(name: String, session_id: Int, img: UIImage, pos: Position3D)
    case start()
    case stop(session_id: Int)
    case getFlightPath(path_id: Int)
}

extension UploadService: TargetType {
    
    var baseURL: URL {
        return URL(string: "http://131.159.207.140:5000")!
    }
    
    var parameterEncoding: Moya.ParameterEncoding {
        return JSONEncoding.default
    }
    
    var path: String {
        switch self {
        case .uploadImage(_, _, _, _): return "/images"
        case .start(): return "/sessions"
        case .stop(_): return "/sessions"
        case .getFlightPath(_): return "/flightpaths"
        }
    }
    
    var method: Moya.Method {
        switch self {
        case .uploadImage(_, _, _, _), .start(), .stop(_):
            return .post
        case .getFlightPath(_):
            return .get
        }
    }
    
    var sampleData: Data {
        return Data()
    }
    
    var task: Task {
        // TODO
        switch self {
        case let .uploadImage(name, session_id, img, pos):
            return Task.requestParameters(parameters: ["name": name, "session_id": session_id, "img": img], encoding: URLEncoding.queryString)
        case .start():
            return Task.requestParameters(parameters: [:], encoding: URLEncoding.queryString)
        case let .stop(session_id):
            return Task.requestParameters(parameters: ["session_id": session_id], encoding: URLEncoding.queryString)
        case let .getFlightPath(path_id):
            return Task.requestParameters(parameters: ["path_id": path_id], encoding: URLEncoding.queryString)
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

fileprivate struct ImageUploadRequestBody: Codable {
    var name: String?
    var img: Data?
    var session_id: String?
    var path_id: String?
    
    private enum CodingKeys: String, CodingKey {
        case name, img, session_id, path_id
    }
}
