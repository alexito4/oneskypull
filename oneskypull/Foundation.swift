//
//  Foundation.swift
//  oneskypull
//
//  Created by Alejandro Martinez on 22/01/2017.
//  Copyright © 2017 Alejandro Martinez. All rights reserved.
//

import Foundation

public typealias JSON = Dictionary<String, AnyObject>

extension URLSession {
    public func synchronousDataTask(with urlRequest: URLRequest) -> (Data?, URLResponse?, Error?) {
        var data: Data?
        var response: URLResponse?
        var error: Error?
        
        let semaphore = DispatchSemaphore(value: 0)
        
        let dataTask = self.dataTask(with: urlRequest) {
            data = $0
            response = $1
            error = $2
            
            semaphore.signal()
        }
        dataTask.resume()
        
        _ = semaphore.wait(timeout: .distantFuture)
            
        return (data, response, error)
    }
}

extension String: Error {}

func ensure<Return>(_ should: () -> Return?, orSave save: (String) -> (), byAsking question: String) -> Return {
    
    if let value = should() {
        return value
    }
    
    var newValue = "" // compiler doesn't know that the while will always set this `let`
    
    while true {
        print(question)
        if let entered = readLine(), entered.isEmpty == false {
            newValue = entered
            break
        }
    }
    
    save(newValue)
    return should()!
}
