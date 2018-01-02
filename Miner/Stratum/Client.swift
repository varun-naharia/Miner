//
//  StratumClient.swift
//  Miner
//
//  Created by Stevie Hetelekides on 9/19/14.
//  Copyright (c) 2014 Expetelek. All rights reserved.
//

import Foundation

enum StratumMethods : String
{
    case Subscribe = "mining.subscribe"
    case Authorize = "mining.authorize"
    case Submit = "mining.submit"
}

class StratumClient : NSObject, StreamDelegate
{
    let TERMINATING_BYTE: UInt8 = 0x0A
    
    var delegate: StartumClientProtocol?
    var host: String
    var port: Int
    
    private var currentAwaitingRequests:[Int:Any] = Dictionary()
    private var inputStream:  InputStream?
    private var outputStream: OutputStream?
    
    init(host: String, port: Int)
    {
        self.host = host
        self.port = port
    }
    
    func connect()
    {
        // get streams to host/port
        Stream.getStreamsToHost(withName: host, port: port, inputStream: &inputStream, outputStream: &outputStream)
        
        // set delegates
        inputStream?.delegate = self
        outputStream?.delegate = self
        
        // schedule run loops
        inputStream?.schedule(in: .main, forMode: .defaultRunLoopMode)
        outputStream?.schedule(in: .main, forMode: .defaultRunLoopMode)
        
        // open streams
        inputStream?.open()
        outputStream?.open()
    }
    
    func subscribe()
    {
        // create the request, add it to the dictionary
        let request = RPCRequest(method: StratumMethods.Subscribe.rawValue)
        
        // send the request
        sendRequest(request: request!)
    }
    
    func authorizeWorker(username: String, password: String)
    {
        // create username/password array
        let usernamePasswordArray = [username, password]
        
        // create the request
        let request = RPCRequest(method: StratumMethods.Authorize.rawValue, params: usernamePasswordArray)
        
        // send the request
        sendRequest(request: request!)
    }
    
    func submiteShare(miner: String, jobId: String, extraNonce2: String, nTime: String, nonce: String)
    {
        // create username/password array
        let shareInformationArray = [miner, jobId, extraNonce2, nTime, nonce]
        
        // create the request
        let request = RPCRequest(method: StratumMethods.Submit.rawValue, params: shareInformationArray)
        
        // send the request
        sendRequest(request: request!)
    }
    
    func close()
    {
        // close streams
        inputStream?.close()
        outputStream?.close()
        
        // remove from run loop
        inputStream?.remove(from: .main, forMode: .defaultRunLoopMode)
        outputStream?.remove(from: .main, forMode: .defaultRunLoopMode)
        
        // remove references to them
        inputStream = nil
        outputStream = nil
    }
    
    private func sendRequest(request: RPCRequest)
    {
//        currentAwaitingRequests.updateValue(request, forKey: request.id)
        currentAwaitingRequests[request.id.intValue] = request
        // get bytes of request's json data
        let dataDictonary = request.serialize()
        do  {
            let data = try JSONSerialization.data(withJSONObject: dataDictonary!, options: JSONSerialization.WritingOptions.init(rawValue: 0))
            let dataUnwrapped = data
            // copy it into mutable data
            dataUnwrapped.withUnsafeBytes{(bytes: UnsafePointer<UInt8>) -> Void in
                var mutableData = Data(bytes: bytes, count: dataUnwrapped.count + 1)
                // add terminating byte
                mutableData.withUnsafeMutableBytes{(mutableBytes:UnsafeMutablePointer<UInt8>) -> Void in
                    
                    mutableBytes[dataUnwrapped.count] = TERMINATING_BYTE
                    
                    // write the buffer
                    outputStream?.write(mutableBytes, maxLength: mutableData.count)
                }
            }
        }
        catch let parsingError as NSError {
                print(parsingError.description)
        }
        
        
    }
    
    internal func stream(_ stream: Stream, handle eventCode: Stream.Event)
    {
        if stream is InputStream
        {
            switch eventCode
            {
            case Stream.Event.endEncountered:
                // close the streams if needed
                close()
                
            case Stream.Event.hasBytesAvailable:
                // get the input stream
                let inputStream = stream as! InputStream
                
                // read a page of data
                var buffer = Data(capacity: 4096)
                buffer.withUnsafeMutableBytes({ (mutableBytes:UnsafeMutablePointer<UInt8>) -> Void in
                    inputStream.read(mutableBytes, maxLength: 4096)
                    
                    // parse the data (into responses)
                    let responses = ResponseParser.parseResponse(response: buffer as NSData)
                    
                    // handle them (fire delegate methods)
                    self.handleResponses(responses: responses)
                })
                
                
                break
            default:
                print("possible stream error: \(String(describing: stream.streamError))")
                break
            }
        }
    }
    
    private func handleResponses(responses: [AnyObject])
    {
        for response in responses
        {
            if let responseUnwrapped = response as? RPCResponse
            {
                if let requestUnwrapped = currentAwaitingRequests[responseUnwrapped.id.intValue] as? RPCRequest
                {
                    // remove it from awaiting requests
                    currentAwaitingRequests.removeValue(forKey: responseUnwrapped.id.intValue)
                    
                    switch requestUnwrapped.method
                    {
                    case StratumMethods.Subscribe.rawValue:
                        // try and parse it as a SubscribeResult
                        if let subscribeResult = SubscribeResult.attemptParseWithResponse(response: responseUnwrapped)
                        {
                            delegate?.didSubscribe(result: subscribeResult)
                        }
                        break
                    case StratumMethods.Authorize.rawValue:
                        // get the parameters (username/password)
                        let paramsArray = requestUnwrapped.params as! [String]
                        delegate?.didAuthorize(username: paramsArray[0], password: paramsArray[1], success: responseUnwrapped.result as! Bool)
                        break
                    case StratumMethods.Submit.rawValue:
                        // get the parameters, check if we succeeded
                        let paramsArray = requestUnwrapped.params as! [String]
                        let success = responseUnwrapped.error == nil && responseUnwrapped.result as! Bool
                        
                        delegate?.didSubmitShare(jobId: paramsArray[1], success: success)
                        break
                    default:
                        break
                    }
                }
            }
            else if let requestUnwrapped = response as? RPCRequest
            {
                if let jobParameters = JobParameters.attemptParseWithRequest(response: requestUnwrapped)
                {
                    delegate?.didRecieveNewJob(job: jobParameters)
                }
            }
        }
    }
    
    deinit
    {
        close()
    }
}
