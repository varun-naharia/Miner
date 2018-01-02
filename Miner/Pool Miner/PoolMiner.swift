//
//  P.swift
//  Miner
//
//  Created by Stevie Hetelekides on 9/21/14.
//  Copyright (c) 2014 Expetelek. All rights reserved.
//

import Foundation

class PoolMiner : StartumClientProtocol
{
    private var client: StratumClient
    private var subscribeResult: SubscribeResult?
    private var currentlyMining = false
    private var cancelMining = false
    
    init(host: String, port: Int)
    {
        client = StratumClient(host: host, port: 3333)
        
        client.delegate = self
        client.connect()
        client.subscribe()
    }
    
    func authorizeUser(username: String, password: String)
    {
        client.authorizeWorker(username: username, password: password)
    }
    
    func didRecieveNewJob(job: JobParameters)
    {
        #if DEBUG
        println("didRecieveNewJob")
        #endif
        
        // if we are currently mining, cancel and wait
        if self.currentlyMining
        {
            self.cancelMining = true
            while self.currentlyMining { }
        }
        
        // start mining
        startMining(job: job)
    }
    
    func didSubscribe(result: SubscribeResult)
    {
        #if DEBUG
        println("didSubscribe")
        #endif
        
        subscribeResult = result
        client.authorizeWorker(username: "hetelek.worker1", password: "123")
    }
    
    func didAuthorize(username: String, password: String, success: Bool)
    {
        #if DEBUG
        println("didAuthorize - \(username):\(password), \(success)")
        #endif
    }
    
    func didSubmitShare(jobId: String, success: Bool)
    {
        #if DEBUG
        print("didSubmitShare - \(jobId), \(success)")
        #endif
    }
    
    func startMining(job: JobParameters)
    {
        // FIXME: may not hash properly, test and verify
        
        if let subscribeResultUnwrapped = subscribeResult
        {
            // setup
            self.currentlyMining = true
            var lastTime = NSDate()
            var hashesDone: Double = 0
            var extraNonce2: UInt32 = 0
            
            // mining loop
            repeat
            {
                // cancel the mining job if requested
                if self.cancelMining
                {
                    self.cancelMining = false
                    self.currentlyMining = false
                    break
                }
                
                // get extranonce2
                let extraNonce2String = String(format: "%08x", extraNonce2)
                
                // create coinbase, hash it
                let coinbase = NSData(hexString: job.coinb1 + subscribeResultUnwrapped.extraNonce1 + extraNonce2String + job.coinb2)
                let coinbaseHash = Cryptography.doubleSha256HashData(coinbase?.bytes, length: UInt32(coinbase!.length))
            
                // calculate merkle root
                var merkleRoot = coinbaseHash
                for h in job.merkleBranch
                {
                    let merkleRootDataBlock = DataBlock(rawData: merkleRoot! as NSData)
                    merkleRootDataBlock.addSegment(NSData(hexString: h))
                    let data = merkleRootDataBlock.rawData
                    
                    merkleRoot = Cryptography.doubleSha256HashData(data.bytes, length: UInt32(data.length))
                }
                
                // create block header
                let blockHeaderDataBlock = DataBlock()
                blockHeaderDataBlock.addSegment(NSData(hexString: job.version).reverse()! as NSData)
                blockHeaderDataBlock.addSegment(NSData(hexString: job.previousHash).reverse(inChunks: 4)! as NSData)
                blockHeaderDataBlock.addSegment(merkleRoot! as NSData)
                blockHeaderDataBlock.addSegment(NSData(hexString: job.ntime).reverse()! as NSData)
                blockHeaderDataBlock.addSegment(NSData(hexString: job.nbits).reverse()! as NSData)
                blockHeaderDataBlock.addSegment(NSData(hexString: "00000000000000800000000000000000000000000000000000000000000000000000000000000000000000000000000080020000"))
                
                // get the raw data, hash it
                let blockHeaderRawData = blockHeaderDataBlock.rawData
                let hash = Cryptography.doubleSha256HashData(blockHeaderRawData.bytes, length: UInt32(blockHeaderRawData.length))! as NSData
            
                #if DEBUG
                println("coinbase: \(coinbase)")
                println("coinbase hash: \(coinbaseHash)")
                println("merkle root: \(merkleRoot)")
                println("block header: \(blockHeaderRawData)")
                println("block header hash: \(hash)")
                #endif
                
                // see if the block header meets difficulty
                let leading = hash.range(of: NSData(bytes: [0, 0, 0, 0] as [UInt8], length: 4) as Data, options: NSData.SearchOptions.anchored, in: NSMakeRange(0, hash.length)).length != 0
                let trailing = hash.range(of: NSData(bytes: [0, 0, 0, 0] as [UInt8], length: 4) as Data, options: NSData.SearchOptions(rawValue: NSData.SearchOptions.RawValue(UInt8(NSData.SearchOptions.anchored.rawValue) | UInt8(NSData.SearchOptions.backwards.rawValue))), in: NSMakeRange(0, hash.length)).length != 0
                if leading || trailing
                {
                    // if so, print the has and submit it
                    print(hash)
                    client.submiteShare(miner: "hetelek.worker1", jobId: job.jobId, extraNonce2: String(format: "%08x", extraNonce2), nTime: job.ntime, nonce: subscribeResultUnwrapped.extraNonce1)
                }
                
                // increment the amount of hashes we've done
                hashesDone += 1
                
                // get the time it's been since last calculated
                let interval = NSDate().timeIntervalSince(lastTime as Date)
                if interval > 10
                {
                    // if greate than 10 seconds, recalculate
                    let hashesPerSecond = hashesDone / interval
                    print("hashes per second: \(hashesPerSecond)")
                    
                    // reset hashes done and the last calculated time
                    hashesDone = 0
                    lastTime = NSDate()
                }
                extraNonce2 += 1
            }
            while extraNonce2 < 0xFFFFFFFF
        }
        
        print("not solved...")
    }
}
