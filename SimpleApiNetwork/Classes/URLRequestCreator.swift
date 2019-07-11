//
//  URLRequestCreator.swift
//
//  Created by 木村太一朗 on 2015/02/03.
//  Copyright (c) 2015年 木村太一朗. All rights reserved.
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import UIKit

open class URLRequestCreator {
    
    public static var boundary = "_insert_some_boundary_here_"
    
    open class func requestWithHttpRequestResource(dataToSend params: [String :Any]!, sendTo url: URL, method: SimpleApiNetwork.HttpMethod = .post) -> NSMutableURLRequest {
        //JSON形式にparse
        let request = NSMutableURLRequest(url: url)
        let cookies = HTTPCookieStorage.shared.cookies(for: url)
        let header = HTTPCookie.requestHeaderFields(with: cookies!)
        request.allHTTPHeaderFields = header
        request.httpMethod = method.rawValue
        switch method {
        case .post,.put,.patch:
            if let params  = params {
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: params, options: JSONSerialization.WritingOptions.prettyPrinted)
                    request.httpBody = jsonData
                } catch  _ as NSError {
                }
            }
        default:
            break
        }
        
        return request
    }
    
    open class func requestWithMultipartHttpRequestResource(_ params: [String :Any]!, sendTo url: URL, method: SimpleApiNetwork.HttpMethod = .post) -> NSMutableURLRequest {
        
        var body = NSMutableData()
        //エンコーディング
        body.append(("--\(boundary)\r\n" as NSString).data(using: String.Encoding.utf8.rawValue)!)
        body.append(("Content-Disposition: form-data; name=\"utf8\";" as NSString).data(using: String.Encoding.utf8.rawValue)!)
        body.append(("Content-Type: application/json\r\n\r\n" as NSString).data(using: String.Encoding.utf8.rawValue)!)
        body.append(("✓" as NSString).data(using: String.Encoding.utf8.rawValue)!)
        body.append(("\r\n" as NSString).data(using: String.Encoding.utf8.rawValue)!)
        appendDictionary(body: &body, params: params, boundary: boundary, baseKey: "")
        //リクエストボディーの最後は改行とboudary
        body.append(("--\(boundary)--\r\n\r\n" as NSString).data(using: String.Encoding.utf8.rawValue)!)
        //リクエストを作成
        let request = NSMutableURLRequest(url: url)
        let cookies = HTTPCookieStorage.shared.cookies(for: url)
        let header = HTTPCookie.requestHeaderFields(with: cookies!)
        request.allHTTPHeaderFields = header
        request.httpMethod = method.rawValue
        request.httpBody = body as Data
        return request
    }
    
    open class func appendDictionary(body: inout NSMutableData, params:[String:Any], boundary: String, baseKey: String) {
        for (key, value) in params {
            let name = baseKey.isEmpty ? key : "(baseKey)[\(key)]"
            if let fileData = value as? SimpleApiFileData {
                let dataName = "Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(fileData.fileName)\"\r\n"
                let mimeType = fileData.data.mimeType.rawValue
                body.append(("--\(boundary)\r\n" as NSString).data(using: String.Encoding.utf8.rawValue)!)
                body.append((dataName as NSString).data(using: String.Encoding.utf8.rawValue)!)
                body.append(("Content-Type: \(mimeType)\r\n\r\n" as NSString).data(using: String.Encoding.utf8.rawValue)!)
                body.append(fileData.data)
                body.append(("\r\n" as NSString).data(using: String.Encoding.utf8.rawValue)!)
            } else if let dictionaryData = value as? [String:Any] {
                appendDictionary(body: &body, params: dictionaryData, boundary: boundary, baseKey: baseKey + "[\(key)]")
            } else if let arrayData = value as? [String] {
                //配列パラメーター
                for object in arrayData {
                    body.append(("--\(boundary)\r\n" as NSString).data(using: String.Encoding.utf8.rawValue)!)
                    body.append(("Content-Disposition: form-data; name=\"\(name)[]\";" as NSString).data(using: String.Encoding.utf8.rawValue)!)
                    body.append(("Content-Type: application/json\r\n\r\n" as NSString).data(using: String.Encoding.utf8.rawValue)!)
                    body.append(("\(object)" as NSString).data(using: String.Encoding.utf8.rawValue)!)
                    body.append(("\r\n" as NSString).data(using: String.Encoding.utf8.rawValue)!)
                }
            } else if let arrayData = value as? [SimpleApiFileData] {
                for fileData in arrayData {
                    let dataName = "Content-Disposition: form-data; name=\"\(name)[]\"; filename=\"\(fileData.fileName)\"\r\n"
                    let mimeType = fileData.data.mimeType.rawValue
                    body.append(("--\(boundary)\r\n" as NSString).data(using: String.Encoding.utf8.rawValue)!)
                    body.append((dataName as NSString).data(using: String.Encoding.utf8.rawValue)!)
                    body.append(("Content-Type: \(mimeType)\r\n\r\n" as NSString).data(using: String.Encoding.utf8.rawValue)!)
                    body.append(fileData.data)
                    body.append(("\r\n" as NSString).data(using: String.Encoding.utf8.rawValue)!)
                }
            } else if value as? String != nil || value as? Int != nil || value as? Float != nil || value as? TimeInterval != nil {
                //通常パラメーター
                body.append(("--\(boundary)\r\n" as NSString).data(using: String.Encoding.utf8.rawValue)!)
                body.append(("Content-Disposition: form-data; name=\"\(name)\";" as NSString).data(using: String.Encoding.utf8.rawValue)!)
                body.append(("Content-Type: application/json\r\n\r\n" as NSString).data(using: String.Encoding.utf8.rawValue)!)
                body.append(("\(value)" as NSString).data(using: String.Encoding.utf8.rawValue)!)
                body.append(("\r\n" as NSString).data(using: String.Encoding.utf8.rawValue)!)
            }
        }
    }
}
