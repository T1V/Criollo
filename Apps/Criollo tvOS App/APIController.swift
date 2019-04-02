//
//  APIController.swift
//  Criollo iOS App
//
//  Created by Cătălin Stan on 19/07/16.
//  Copyright © 2016 Cătălin Stan. All rights reserved.
//

import Criollo

class APIController : CRRouteController {

    override init(prefix: String) {
        super.init(prefix: prefix)

        let uname = SystemInfoHelper.systemInfo()
        let bundle:Bundle! = Bundle.main
        
        self.add("/env")  { (request, response, completionHandler) in
            let dict:Dictionary = request.env as Dictionary
            response.send(dict)
        }

        // Prints some more info as text/html
        self.add("/status") { (request, response, completionHandler) in

            let startTime:NSDate! = NSDate()

            var responseString:String = String()

            // HTML
            responseString += "<!DOCTYPE html><html lang=\"en\"><head><meta charset=\"utf-8\"/><meta http-equiv=\"X-UA-Compatible\" content=\"IE=edge\"/><meta name=\"viewport\" content=\"width=device-width, initial-scale=1\"/>"
            responseString += "<title>\(bundle.bundleIdentifier!)</title>"
            responseString += "<link rel=\"stylesheet\" href=\"/static/style.css\"/><link rel=\"stylesheet\" href=\"https://maxcdn.bootstrapcdn.com/bootstrap/3.3.6/css/bootstrap.min.css\" integrity=\"sha384-1q8mTJOASx8j1Au+a5WDVnPi2lkFfwwEAa8hDDdjZlpLegxhjVME1fgjWPGmkzs7\" crossorigin=\"anonymous\"/><link rel=\"stylesheet\" href=\"https://maxcdn.bootstrapcdn.com/bootstrap/3.3.6/css/bootstrap-theme.min.css\" integrity=\"sha384-fLW2N01lMqjakBkx3l/M9EahuwpSfeNvV63J5ezn3uZzapT0u7EYsXMjQV+0En5r\" crossorigin=\"anonymous\"/></head><body>"

            // Bundle info
            responseString += "<h1>\(bundle.bundleIdentifier!)</h1>"
            responseString += "<h2>Version \(bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String) build \(bundle.object(forInfoDictionaryKey: "CFBundleVersion") as! String)</h2>"

            // Headers
            responseString += "<h3>Request Headers:</h2><pre>"
            for (key, object) in request.allHTTPHeaderFields {
                responseString += "\(key): \(object)\n"
            }
            responseString += "</pre>"

            // Request Enviroment
            responseString += "<h3>Request Environment:</h2><pre>"
            for (key, object) in request.env {
                responseString += "\(key): \(object)\n"
            }
            responseString += "</pre>"

            // Query
            responseString += "<h3>Request Query:</h2><pre>"
            for (key, object) in request.query {
                responseString += "\(key): \(object)\n"
            }
            responseString += "</pre>"

            // Cookies
            responseString += "<h3>Request Cookies:</h2><pre>"
            for (key, object) in request.cookies! {
                responseString += "\(key): \(object)\n"
            }
            responseString += "</pre>"

            // Stack trace
            responseString += "<h3>Stack Trace:</h2><pre>"
            for (object) in Thread.callStackSymbols {
                responseString += "\(object)\n"
            }

            responseString += "</pre>"

            // System Info
            responseString += "<hr/>"
            responseString += "<small>\(uname)</small><br/>"
            responseString += String(format: "<small>Task took: %.4fms</small>", startTime.timeIntervalSinceNow * -1000)

            // HTML
            responseString += "</body></html>"

            response.setValue("text/html; charset=utf-8", forHTTPHeaderField: "Content-type")
            response.setValue("\(responseString.lengthOfBytes(using: String.Encoding.utf8))", forHTTPHeaderField: "Content-Length")
            response.send(responseString)
            
            completionHandler()
            
        }

        self.add("/info") { (request, response, next) in
            let info:Dictionary = [
                "IPAddress":SystemInfoHelper.ipAddress(),
                "systemInfo":SystemInfoHelper.systemInfo(),
                "systemVersion":SystemInfoHelper.systemVersion(),
                "processName":SystemInfoHelper.processName(),
                "processRunningTime":SystemInfoHelper.processRunningTime(),
                "memoryInfo":SystemInfoHelper.memoryInfo(nil),
                "requestsServed":SystemInfoHelper.requestsServed(),
                "criolloVersion":SystemInfoHelper.criolloVersion(),
                "bundleVersion":SystemInfoHelper.bundleVersion(),
                ]
            do {
                try response.send(JSONSerialization.data(withJSONObject: info, options: JSONSerialization.WritingOptions.prettyPrinted))
            } catch let error as NSError {
                CRServer.errorHandlingBlock(withStatus: 500, error: error)(request, response, next)
            }
        }
    }

}
