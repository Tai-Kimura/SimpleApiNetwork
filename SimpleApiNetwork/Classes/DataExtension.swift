//
//  DataExtension.swift
//
//  Created by 木村太一朗 on 2016/12/15.
//

import Foundation

public extension Data {
    
    public var mimeType: DataMimeType {
        let bytes = self.bytes
        if bytes.count == 0 {
            return .none
        }
        let c = self.bytes[0]
        switch (c) {
        case 0xFF:
            return .imageJpeg
        case 0x89:
            return .imagePng
        case 0x47:
            return .imageGif
        case 0x49,0x4D:
            return .imageTiff
        case 0x25:
            return .applicationPdf
        case 0xD0:
            return .applicationVnd
        case 0x46:
            return .textPlain
        default:
            return .applicationOctetStream
        }
    }
    
    public var bytes: Array<UInt8> {
        return Array(self)
    }
}

public enum DataMimeType: String {
    case imageJpeg = "image/jpeg"
    case imagePng = "image/png"
    case imageGif = "image/gif"
    case imageTiff = "image/tiff"
    case applicationPdf = "application/pdf"
    case applicationVnd = "application/vnd.oasis.opendocument.text"
    case textPlain = "text/html"
    case applicationOctetStream = "video/mpeg"
    case none = "none"
}
