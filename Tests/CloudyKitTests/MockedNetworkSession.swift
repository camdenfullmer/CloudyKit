//
//  MockedNetworkSession.swift
//  
//
//  Created by Camden on 12/21/20.
//

import Foundation
@testable import CloudyKit

class MockedURLSessionDataTask: NetworkSessionDataTask {
    let resumeCalled: (()->Void)?
    
    init(resumeCalled: (()->Void)? = nil) {
        self.resumeCalled = resumeCalled
    }
    
    func resume() {
        self.resumeCalled?()
    }
}

class MockedNetworkSession: NetworkSession {
    var request: URLRequest? = nil
    var mockedData: Data? = nil
    var mockedResponse: URLResponse? = nil
    var mockedError: Error? = nil
    
    func internalDataTask(with request: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> NetworkSessionDataTask {
        self.request = request
        return MockedURLSessionDataTask {
            completionHandler(self.mockedData, self.mockedResponse, self.mockedError)
        }
    }
}
