//
//  VariableLengthInteger.swift
//  Miner
//
//  Created by Stevie Hetelekides on 9/14/14.
//  Copyright (c) 2014 Expetelek. All rights reserved.
//

import Foundation

enum VariableLengthIntegerType : UInt8
{
    case UInt16 = 0xFD
    case UInt32 = 0xFE
    case UInt64 = 0xFF
}

struct VariableLengthInteger : DataObjectProtocol
{
    var value: UInt64
    
    init(rawData: NSData)
    {
        self.init(data: rawData, index: 0)
    }
    
    init(data: NSData, index: Int)
    {
        // get the type (int16, int32, int64)
        var integerType: UInt8 = 0
        data.getBytes(&integerType, range: NSMakeRange(index, 1))
        
        // parse it based on its type
        switch integerType
        {
        case VariableLengthIntegerType.UInt16.rawValue:
            var unsignedInt16: UInt16 = 0
            data.getBytes(&unsignedInt16, range: NSMakeRange(index + 1, 2))
            value = UInt64(unsignedInt16)
            break
        case VariableLengthIntegerType.UInt32.rawValue:
            var unsignedInt32: UInt32 = 0
            data.getBytes(&unsignedInt32, range: NSMakeRange(index + 1, 4))
            value = UInt64(unsignedInt32)
            break
        case VariableLengthIntegerType.UInt64.rawValue:
            var unsignedInt64: UInt64 = 0
            data.getBytes(&unsignedInt64, range: NSMakeRange(index + 1, 8))
            value = UInt64(unsignedInt64)
            break
        default:
            value = UInt64(integerType)
        }
    }
    
    init(unsignedInt16: UInt16)
    {
        self.value = UInt64(unsignedInt16)
    }
    
    init(signedInt16: Int16)
    {
        self.value = UInt64(signedInt16)
    }
    
    init(unsignedInt32: UInt32)
    {
        self.value = UInt64(unsignedInt32)
    }
    
    init(signedInt32: Int32)
    {
        self.value = UInt64(signedInt32)
    }
    
    init(unsignedInt: UInt)
    {
        self.value = UInt64(unsignedInt)
    }
    
    init(signedInt: Int)
    {
        self.value = UInt64(signedInt)
    }
    
    init(unsignedInt64: UInt64)
    {
        self.value = unsignedInt64
    }
    
    init(signedInt64: Int64)
    {
        self.value = UInt64(signedInt64)
    }
    
    var integerLength: Int
    {
        get
        {
            if value < 0xFD
            {
                // int8
                return 1
            }
            else if value <= 0xFFFF
            {
                // int16
                return 2
            }
            else if value <= 0xFFFFFFFF
            {
                // int32
                return 4
            }
            else
            {
                // int64
                return 8
            }
        }
    }
    
    var rawData: NSData
    {
        get
        {
            var bytes: [UInt8]
            let valueSize = self.integerLength
            
            // get the first value of the array
            if value < 0xFD
            {
                bytes = []
            }
            else if value <= 0xFFFF
            {
                bytes = [VariableLengthIntegerType.UInt16.rawValue]
            }
            else if value <= 0xFFFFFFFF
            {
                bytes = [VariableLengthIntegerType.UInt32.rawValue]
            }
            else
            {
                bytes = [VariableLengthIntegerType.UInt64.rawValue]
            }
            
            // add the bytes to the array
            var temp = value
            for _ in 0..<valueSize //var i = 0; i < valueSize; ++i
            {
                bytes.append(UInt8(temp & 0xFF))
                temp >>= 8
            }
            
            return NSData(bytes: bytes, length: bytes.count)
        }
    }
}
