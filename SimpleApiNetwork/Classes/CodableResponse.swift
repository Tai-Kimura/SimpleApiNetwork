//
//  CodableResponse.swift
//  Pods
//
//  Created by 木村太一朗 on 2024/04/17.
//

import Foundation

public class CodableResponse<T: Codable> {
    let response: T
    let status: HttpStatusCode
    
    init(data: Data, statusCode: HttpStatusCode) throws {
        status = statusCode
        let decoder = JSONDecoder()
        do {
            response = try decoder.decode(T.self, from: data)
        } catch let error {
            throw error
        }
    }
}
