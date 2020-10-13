//
//  LHBinaryCookiesReader.swift
//  TestLocalCookie
//
//  Created by 梁辉 on 2020/8/30.
//  Copyright © 2020 Xiaohu Internet Technology. All rights reserved.
//

import UIKit

class LHBinaryCookiesReader {
    
    static func localCookies() -> [BinaryCookie] {
        
        let path = NSHomeDirectory().appending("/Library/Cookies/Cookies.binarycookies")
        return self.readCookies(path: path)
    }
    
    static func localCookies(like domain:String) -> [BinaryCookie] {
        
        let path = NSHomeDirectory().appending("/Library/Cookies/Cookies.binarycookies")
        return self.readCookies(path: path).filter { $0.domain?.contains(domain) ?? false }
    }
    
    static func readCookies(path: String) -> [BinaryCookie] {
    
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            return []
        }
        return self.readCookies(data: data)
    }
    
    static func readCookies(data: Data) -> [BinaryCookie] {
        
        var curentLocation: Int = 0
        var cookieList:[BinaryCookie] = []
        
        let file_header = data.read(location: curentLocation, length: 4)
        curentLocation += 4
            
        if String(data: file_header , encoding: .utf8) != "cook" {
            debugPrint("Not a Cookies.binarycookie file")
            return cookieList
        }
        
        // pageCount
        let pageCount = self.bytesToInt(data: data.read(location: curentLocation, length: 4) , isBe: true)
        curentLocation += 4
        
        guard pageCount - 1 >= 0 else {
            return cookieList
        }
            
        // pageSize of page
        var pageSize:[Int] = []
        for _ in 0...(pageCount - 1) {
            let size = self.bytesToInt(data: data.read(location: curentLocation, length: 4) , isBe: true)
            pageSize.append(size)
            curentLocation += 4
        }
            
        // 提取cookie
        for i in 0...(pageCount - 1) {
            let begin = data.read(location: curentLocation, length: pageSize[i])
            let cookies = self.handeleCookieData(data: begin)
            cookieList.append(contentsOf: cookies)
            curentLocation += pageSize[i]
        }
        
        return cookieList
    }
    
    static func handeleCookieData(data: Data) -> [BinaryCookie] {

        let cookieData = data
        var tempLocation:Int = 0
        var cookieList:[BinaryCookie] = []
        
        let pageHeader = self.bytesToInt(data: cookieData, isBe: true)
        tempLocation += 4
        
        if pageHeader != 0x00000100 {
            debugPrint("page header is error, not 0x00000100!")
            return cookieList
        }
        
        let cookieCount = self.bytesToInt(data: cookieData.read(location: tempLocation, length: 4) , isBe: false)
         tempLocation += 4
        
        if cookieCount - 1 >= 0 {
            for _ in 0...(cookieCount - 1 ) {
                let offset =  self.bytesToInt(data: cookieData.read(location: tempLocation, length: 4), isBe: false)
                tempLocation += 4
                
                let contentData = cookieData.read(location: offset, length: cookieData.count - offset)
                
                var contentDataLocation = 0
                let cookieSize = self.bytesToInt(data: contentData.read(location: contentDataLocation, length: 4), isBe: false)
                contentDataLocation += 4
                
               // let version = self.bytesToInt(data: contentData.read(location: contentDataLocation, length: 4), isBe: false)
                contentDataLocation += 4

                //let flags = self.bytesToInt(data: contentData.read(location: contentDataLocation, length: 4), isBe: false)
                contentDataLocation += 4
                
                //let hasPort = self.bytesToInt(data: contentData.read(location: contentDataLocation, length: 4), isBe: false)
                contentDataLocation += 4
                
                let url_offset = self.bytesToInt(data: contentData.read(location: contentDataLocation, length: 4), isBe: false)
                contentDataLocation += 4
                
                let name_offset = self.bytesToInt(data: contentData.read(location: contentDataLocation, length: 4), isBe: false)
                contentDataLocation += 4
                
                let path_offset = self.bytesToInt(data: contentData.read(location: contentDataLocation, length: 4), isBe: false)
                contentDataLocation += 4
                
                let value_offset = self.bytesToInt(data: contentData.read(location: contentDataLocation, length: 4), isBe: false)
                contentDataLocation += 4
                
                //let endofcookie = self.bytesToInt(data: contentData.read(location: contentDataLocation, length: 8), isBe: false)
                contentDataLocation += 8
                
                let data:NSData = contentData.read(location: contentDataLocation, length: 8) as NSData
                contentDataLocation += 8
                var out:double_t = 0;
                memcpy(&out, data.bytes, MemoryLayout<double_t>.size);
                let expiry_date_epoch = Int64(out) + Int64(978307200)
                let expireDate:Date = Date(timeIntervalSince1970: TimeInterval(expiry_date_epoch))
                
                let domainData = contentData.read(location: url_offset, length: name_offset-url_offset)
                let domain = String(data: domainData, encoding: .utf8)?.replacingOccurrences(of: "\0", with: "")
                
                let nameData = contentData.read(location: name_offset, length: path_offset-name_offset)
                let name = String(data: nameData, encoding: .utf8)?.replacingOccurrences(of: "\0", with: "")
                
                let pathData = contentData.read(location: path_offset, length: value_offset-path_offset)
                let path = String(data: pathData, encoding: .utf8)?.replacingOccurrences(of: "\0", with: "")
                
                let valueData = contentData.read(location: value_offset, length: cookieSize-value_offset)
                let value = String(data: valueData, encoding: .utf8)?.replacingOccurrences(of: "\0", with: "")
                
                let cookie = BinaryCookie(name: name, value: value, path: path, domain: domain, expireDate: expireDate)
                cookieList.append(cookie)
            }
        }
        return cookieList
    }
    
    static func bytesToInt(data: Data, isBe: Bool) -> Int {
        
        if data.count < 4 {
            return 0
        }
        
        let temp = [UInt8](data)
        var src:[UInt64] = []
        for item in temp {
            src.append(UInt64(item))
        }
        if isBe { // 小端
            let first = (src[3] & 0xFF) | ((src[2] & 0xFF)<<8)
            return Int(first | ((src[1] & 0xFF)<<16) | ((src[0] & 0xFF)<<24))
        } else { // 大端
            let first = (src[0] & 0xFF) | ((src[1] & 0xFF)<<8)
            return Int(first | ((src[2] & 0xFF)<<16) | ((src[3] & 0xFF)<<24))
        }
    }
    
    static func cookieSting(cookieList: [BinaryCookie]) -> String {
        
        var cookiePair:[String] = []
        for cookie in cookieList {
            if cookie.name?.count ?? 0 <= 0 {
                continue
            }
            cookiePair.append("\(cookie.name ?? "")=\(cookie.value ?? "");")
        }
        return cookiePair.joined(separator: "")
    }
    
}

struct BinaryCookie {
    var name:String?
    var value:String?
    var path:String?
    var domain:String?
    var expireDate:Date?
}


extension Data {
    
    func read(location:Int, length: Int) -> Data {
        
        if location >= self.count || length <= 0 {
            return Data()
        }
        
        let endLocation = location + length
        if self.count < endLocation {
            return self.subdata(in: location..<(self.count - location))
        }
        return self.subdata(in: location..<(location + length))
    }
    
    func string(encoding: String.Encoding) -> String? {
        return String(data: self, encoding: encoding)
    }
}
