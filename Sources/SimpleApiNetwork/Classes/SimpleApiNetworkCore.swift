//
//  Network.swift
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

open class SimpleApiNetworkCore: NSObject, URLSessionTaskDelegate {
    
    nonisolated(unsafe) public static var HttpHost: String = "http://localhost:3000"
    
    nonisolated(unsafe) public static var defaultTimeout: TimeInterval = 30
    
    nonisolated(unsafe) public static var defaultMultipartTimeout: TimeInterval = 60
    
    nonisolated(unsafe) private static var tasks = [String:[WeakURLTask]]()
    
    public var request: NSMutableURLRequest?
    
    public var response: NSMutableData = NSMutableData()
    
    nonisolated(unsafe) private static var registeringDevice = false
    
    private static let singleton = SimpleApiNetworkCore();
    
    nonisolated(unsafe) private static var userAgent = getUserAgentName()
    
    nonisolated(unsafe) private static var taskQueue = DispatchQueue(label: "task_queue")
    
    nonisolated(unsafe) open class var  headers: [String:String] {
        get {
            return [String:String]()
        }
    }
    
    private var statusCode: Int = 0
    
    override init() {
        super.init()
        
    }
    
    public class func sharedInstance() -> SimpleApiNetwork {
        return singleton;
    }
    
    public static func addTask(task: WeakURLTask, for key: String) {
        taskQueue.async {
            var group = tasks[key] ?? [WeakURLTask]()
            group.append(task)
            tasks[key] = group
        }
    }
    
    public static func addTask(task: URLSessionTask?, for key: String) {
        guard let task = task as? URLSessionDataTask else { return }
        taskQueue.async {
            var group = tasks[key] ?? [WeakURLTask]()
            group.append(WeakURLTask(task: task))
            tasks[key] = group
        }
    }
    
    public static func cancelTasks(for key: String) {
        taskQueue.async {
            if let group = tasks[key] {
                for task in group {
                    task.get?.cancel()
                }
                tasks[key] = nil
            }
        }
    }
    
    public static func setUserAgent(userAgent: String) {
        SimpleApiNetwork.userAgent = userAgent
    }
    
    class func newSession(delegate: URLSessionTaskDelegate? = nil, tag: String = "com.tanosys.simple_api_network") -> URLSession {
        let operationQueue = OperationQueue()
        operationQueue.name = tag
        let session = URLSession(configuration: URLSessionConfiguration.default,
                                 delegate: delegate == nil ? SimpleApiNetwork.sharedInstance() : delegate!, delegateQueue: operationQueue)
        return session;
    }
    
    //    MARK: リクエスト
    @discardableResult public class func request<T1: NetworkResponse, T2: NetworkError>(_ path: String, dataToSend data: [String : Any]!, completionHandler:@escaping (T1)->Void, errorHandler:((_ errors: T2) -> Void)? = nil, method: HttpMethod = .post, isMultipart: Bool = false, contentType: String? = nil, host: String = HttpHost, timeout: TimeInterval? = nil, delegate: URLSessionTaskDelegate? = nil) -> WeakURLTask {
        var endPoint = host + path
        switch method {
        case .get,.delete:
            endPoint += "?"
            for (key,value) in data {
                endPoint += "\(key)=\(value)&"
            }
        default:
            break
        }
        let url = URL(string: endPoint)
        let request = isMultipart ? URLRequestCreator.requestWithMultipartHttpRequestResource(data, sendTo: url!, method: method) : URLRequestCreator.requestWithHttpRequestResource(dataToSend: data, sendTo: url!, method: method)
        request.addValue(SimpleApiNetwork.userAgent, forHTTPHeaderField:"User-Agent")
        if let contentType = contentType {
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }else if isMultipart {
            request.setValue("multipart/form-data; boundary=\(URLRequestCreator.boundary)", forHTTPHeaderField: "Content-Type")
        } else {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        for (key,value) in headers {
            request.addValue(value, forHTTPHeaderField: key)
        }
        request.timeoutInterval = timeout ?? (isMultipart ? defaultMultipartTimeout : defaultTimeout)
        let task = handleRequest(request, completionHandler: completionHandler, errorHandler: errorHandler, delegate: delegate)
        task.resume()
        return WeakURLTask(task: task)
    }
    
    private class func handleRequest<T1: NetworkResponse, T2: NetworkError>(_ request: NSMutableURLRequest, completionHandler:@escaping (T1)->Void, errorHandler:((_ errors: T2) -> Void)? = nil, delegate: URLSessionTaskDelegate? = nil) -> URLSessionDataTask {
        let session = newSession(delegate: delegate);
        return session.dataTask(with: request as URLRequest, completionHandler: {
            (data, resp, err) in
            session.invalidateAndCancel()
            SimpleApiNetwork.saveCookie()
            if let error = err {
                if ((error as NSError).code != NSURLErrorCancelled) {
                    DispatchQueue.main.async(execute: {
                        errorHandler?(T2.init(statusCode: .serverError, data: error))
                    })
                }
                return
            }
            if let httpResponse = resp as? HTTPURLResponse, let content = data {
                if (httpResponse.statusCode == 200 && err == nil) {
                    do {
                        let result = try T1.init(data: content)
                        if checkIfSuccessResponse(result: result) {
                            DispatchQueue.main.async(execute: {
                                completionHandler(result)
                            })
                        } else {
                            DispatchQueue.main.async(execute: {
                                errorHandler?(T2.init(statusCode: .requestSuccess, data: result))
                            })
                        }
                    } catch let error {
                        DispatchQueue.main.async(execute: {
                            errorHandler?(T2.init(statusCode: .requestSuccess, data: error))
                        })
                    }
                    return
                }
            }
            DispatchQueue.main.async(execute: {
                errorHandler?(T2.init(statusCode: HttpStatusCode(rawValue: (resp as? HTTPURLResponse)?.statusCode ?? 0) ?? .serverError, data: data))
            })
        })
    }
    
    @discardableResult public class func asyncRequest<T: Codable>(_ path: String, dataToSend data: [String : Any]!, method: HttpMethod = .post, isMultipart: Bool = false, contentType: String? = nil, host: String = HttpHost, timeout: TimeInterval? = nil, delegate: URLSessionTaskDelegate? = nil, tag: String = "com.tanosys.simple_api_network") async throws -> CodableResponse<T>? {
        var endPoint = host + path
        switch method {
        case .get,.delete:
            endPoint += "?"
            for (key,value) in data {
                endPoint += "\(key)=\(value)&"
            }
        default:
            break
        }
        let url = URL(string: endPoint)
        let request = isMultipart ? URLRequestCreator.requestWithMultipartHttpRequestResource(data, sendTo: url!, method: method) : URLRequestCreator.requestWithHttpRequestResource(dataToSend: data, sendTo: url!, method: method)
        request.addValue(SimpleApiNetwork.userAgent, forHTTPHeaderField:"User-Agent")
        if let contentType = contentType {
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }else if isMultipart {
            request.setValue("multipart/form-data; boundary=\(URLRequestCreator.boundary)", forHTTPHeaderField: "Content-Type")
        } else {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        for (key,value) in headers {
            request.addValue(value, forHTTPHeaderField: key)
        }
        request.timeoutInterval = timeout ?? (isMultipart ? defaultMultipartTimeout : defaultTimeout)
        return try await handleAsyncRequest(request, delegate: delegate, tag: tag)
    }
    
    private class func handleAsyncRequest<T: Codable>(_ request: NSMutableURLRequest, delegate: URLSessionTaskDelegate? = nil, tag: String) async throws -> CodableResponse<T>? {
        let session = newSession(delegate: delegate, tag: tag)
        do {
            let (data, resp) = try await session.data(for: request as URLRequest)
            session.invalidateAndCancel()
            SimpleApiNetwork.saveCookie()
            if let httpResponse = resp as? HTTPURLResponse {
                do {
                    return try CodableResponse<T>.init(data: data, statusCode: HttpStatusCode(rawValue: httpResponse.statusCode) ?? HttpStatusCode.unKnown)
                } catch let error {
                    throw error
                }
            }
        } catch let err {
            session.invalidateAndCancel()
            if (err as NSError).code != NSURLErrorCancelled {
                throw err
            }
        }
        return nil
    }
    
    open class func checkIfSuccessResponse<T: NetworkResponse>(result: T) -> Bool {
        return true
    }
    
    // MARK: ユーザーエージェント
    open class func getUserAgentName() -> String {
        let appVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as! String
        let osVersion  = UIDevice.current.systemVersion;
        let agentName  = "\(Bundle.main.object(forInfoDictionaryKey: "CFBundleName") ?? "")/\(appVersion) (iOS \(osVersion))";
        return agentName;
    }
    
    fileprivate func storeCookie(_ httpResponse: HTTPURLResponse) {
        let cookies = HTTPCookie.cookies(withResponseHeaderFields: httpResponse.allHeaderFields as! [String:String], for: httpResponse.url!)
        for cookie in cookies {
            HTTPCookieStorage.shared.setCookie(cookie )
        }
        _ = HTTPCookieStorage.shared.cookies(for: httpResponse.url!)
    }
    
    
    //MARK: Cookie stack
    
    open class func loadCookie() {
        if let cookiesData: Data = Util.get(key: "savedHttpCookie") as? Data, let cookies: [HTTPCookie] = (try? NSKeyedUnarchiver.unarchivedObject(ofClasses: [], from: cookiesData)) as? [HTTPCookie] {
            for  cookie in cookies {
                HTTPCookieStorage.shared.setCookie(cookie)
            }
        }
    }
    
    open class func saveCookie() {
        // Save the cookies to the user defaults
        guard let cookies = HTTPCookieStorage.shared.cookies, let cookiesData = try? NSKeyedArchiver.archivedData(withRootObject: cookies, requiringSecureCoding: true) else {
            return
        }
        Util.set(object: cookiesData as Any,
                 forKey:"savedHttpCookie")
    }
    
    
    public enum HttpMethod: String , Sendable{
        case get = "GET"
        case head = "HEAD"
        case post = "POST"
        case options = "OPTIONS"
        case put = "PUT"
        case delete = "DELETE"
        case connect = "CONNECT"
        case trace = "TRACE"
        case patch = "PATCH"
        case link = "LINK"
        case unlink = "UNLINK"
    }
    
    open class Util {
        @discardableResult class func set(object: Any, forKey key: String) -> Bool {
            let userDefault = UserDefaults.standard
            userDefault.set(object, forKey: key)
            return userDefault.synchronize()
        }
        
        open class func get(key: String) -> Any? {
            return UserDefaults.standard.object(forKey: key)
        }
        
        open class func delete(key: String) {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}





public enum HttpStatusCode: Int, Sendable {
    case serverMaintenance = 503
    case requestSuccess = 200
    case notFound = 404
    case invalidDomain = 410
    case notAuthorized = 401
    case serverError = 500
    case unKnown = -1
}
