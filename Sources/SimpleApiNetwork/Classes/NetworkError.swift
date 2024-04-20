//
//  NetworkError.swift
//
//  Created by 木村太一朗 on 2018/04/19.
//

import UIKit

public protocol NetworkError {
    init(statusCode: HttpStatusCode, data: Any?)
}
