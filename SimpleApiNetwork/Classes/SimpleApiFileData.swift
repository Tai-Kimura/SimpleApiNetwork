//
//  SimpleApiFileData.swift
//  Pods
//
//  Created by 木村太一朗 on 2018/09/22.
//

import UIKit

open class SimpleApiFileData: @unchecked Sendable {
    public var data: Data
    public var fileName: String
    
    required public init(data: Data, fileName: String) {
        self.data = data
        self.fileName = fileName
    }

}
