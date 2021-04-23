//
//  MockedNetworkSession.swift
//  
//
//  Created by Camden on 12/21/20.
//

import Foundation
#if os(Linux)
import FoundationNetworking
import OpenCombine
#else
import Combine
#endif
@testable import CloudyKit

class MockedURLSessionDataSubscription<S: Subscriber>: Subscription where S.Input == (data: Data, response: URLResponse), S.Failure == Error {
    private let data: Data?
    private let response: URLResponse?
    private let error: Error?
    private var subscriber: S?
    
    init(data: Data?, response: URLResponse?, error: Error?, subscriber: S) {
        self.data = data
        self.response = response
        self.error = error
        self.subscriber = subscriber
    }
    
    func request(_ demand: Subscribers.Demand) {
        if demand > 0 {
            guard let subscriber = self.subscriber else { return }
            if let error = error {
                subscriber.receive(completion: .failure(error))
            } else if let data = self.data, let response = self.response {
                _ = subscriber.receive((data, response))
                subscriber.receive(completion: .finished)
            } else {
                subscriber.receive(completion: .failure(CloudyKit.CKError(code: .internalError, userInfo: [:])))
            }
        }
    }
    
    func cancel() {
        self.subscriber = nil
    }
}

struct MockedURLSessionDataPublisher: Publisher {
    typealias Output = (data: Data, response: URLResponse)
    typealias Failure = Error
    
    private let data: Data?
    private let response: URLResponse?
    private let error: Error?
    
    
    init(data: Data?, response: URLResponse?, error: Error?) {
        self.data = data
        self.response = response
        self.error = error
    }
    
    func receive<S: Subscriber>(subscriber: S) where MockedURLSessionDataPublisher.Failure == S.Failure, MockedURLSessionDataPublisher.Output == S.Input {
        let subscription = MockedURLSessionDataSubscription(data: self.data,
                                                            response: self.response,
                                                            error: self.error,
                                                            subscriber: subscriber)
        subscriber.receive(subscription: subscription)
    }
}

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
    
    var requests: [URLRequest] = []
    var responseHandler: ((URLRequest) -> (Data?, URLResponse?, Error?))?
    
    func internalDataTask(with request: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> NetworkSessionDataTask {
        self.requests.append(request)
        let (data, response, error) = self.responseHandler?(request) ?? (nil, nil, nil)
        return MockedURLSessionDataTask {
            completionHandler(data, response, error)
        }
    }
    
    func internalDataTaskPublisher(for request: URLRequest) -> AnyPublisher<(data: Data, response: URLResponse), Error> {
        self.requests.append(request)
        let (data, response, error) = self.responseHandler?(request) ?? (nil, nil, nil)
        return MockedURLSessionDataPublisher(data: data, response: response, error: error)
            .eraseToAnyPublisher()
    }
}
