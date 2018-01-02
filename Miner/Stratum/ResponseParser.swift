//
//  ResponseParser.swift
//  Miner
//
//  Created by Stevie Hetelekides on 9/20/14.
//  Copyright (c) 2014 Expetelek. All rights reserved.
//

import Foundation

let RESPONSE_SEPERATOR = NSData(bytes: UnsafePointer<UInt8>([0x0A]), length: 1)
class ResponseParser
{
    class func parseResponse(response: NSData) -> [AnyObject]
    {
        // create our array
        var parsedResponses: [AnyObject] = []
        
        // get the length
        let responseLength = response.length
        
        // setup start index, get the end index of the first dictionary
        var startIndex = 0
        var endIndex = response.range(of: RESPONSE_SEPERATOR as Data, options: NSData.SearchOptions.init(rawValue: 0), in: NSMakeRange(0, responseLength)).location
        
        // parse the data
        while endIndex <= responseLength
        {
            // get the subdata
            let currentDictionaryData = response.subdata(with: NSMakeRange(startIndex, endIndex - startIndex))
            do{
            // convert it to an object
                let jsonObject: AnyObject? = try JSONSerialization.jsonObject(with: currentDictionaryData, options: JSONSerialization.ReadingOptions.allowFragments) as AnyObject

                // if it's a NSDictionary, append it
                if let dictionaryObject = jsonObject as? NSDictionary
                {
                    #if DEBUG
                    println(dictionaryObject)
                    #endif
                    
                    if dictionaryObject.object(forKey: "params") != nil
                    {
                        parsedResponses.append(RPCRequest(dictionary: dictionaryObject as [NSObject : AnyObject]))
                    }
                    else
                    {
                        parsedResponses.append(RPCResponse(dictionary: dictionaryObject as [NSObject : AnyObject]))
                    }
                }
                
                // update start/end indexes
                startIndex = endIndex + 1
                
                let searchRange = NSMakeRange(startIndex, responseLength - startIndex)
                endIndex = response.range(of: RESPONSE_SEPERATOR as Data, options: NSData.SearchOptions.init(rawValue: 0), in: searchRange).location
            }
            catch
            {
                print(error)
            }
        }
        
        // return the dictionaries
        return parsedResponses
    }
}
