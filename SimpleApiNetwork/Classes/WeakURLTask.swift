//
//  WeakURLTask.swift
//  Pods-SimpleApiNetwork_Example
//
//  Created by 木村太一朗 on 2019/07/11.
//

import Foundation


public class WeakURLTask {
    private weak var _task: URLSessionDataTask?
    
    var get: URLSessionDataTask? {
        get {
            return _task
        }
    }
    
    init(task: URLSessionDataTask) {
        _task = task
    }
}
