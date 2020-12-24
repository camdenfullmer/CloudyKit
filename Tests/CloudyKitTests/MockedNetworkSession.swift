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
        sendRequest()
    }
    
    func request(_ demand: Subscribers.Demand) {
        //TODO: - Optionaly Adjust The Demand
    }
    
    func cancel() {
        subscriber = nil
    }
    
    private func sendRequest() {
        guard let subscriber = subscriber else { return }
        if let error = error {
            subscriber.receive(completion: .failure(error))
        } else if let data = self.data, let response = self.response {
            _ = subscriber.receive((data, response))
        } else {
            subscriber.receive(completion: .failure(CloudyKit.CKError(code: .internalError)))
        }
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
    
    func internalDataTaskPublisher(for request: URLRequest) -> AnyPublisher<(data: Data, response: URLResponse), Error> {
        self.request = request
        return MockedURLSessionDataPublisher(data: self.mockedData,
                                             response: self.mockedResponse,
                                             error: self.mockedError)
            .eraseToAnyPublisher()
    }
}
