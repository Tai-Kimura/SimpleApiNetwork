//
//  NetworkResponse.swift
//  Pods
//
//  Created by 木村太一朗 on 2018/09/28.
//

import UIKit

public protocol NetworkResponse {
    init(data: Data) throws
}
