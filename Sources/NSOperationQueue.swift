//
//  NSOperationQueue.swift
//  Actors
//
//  Created by Dario on 10/5/15.
//  Copyright © 2015 dario. All rights reserved.
//

import Foundation

prefix operator ^ {}

/**
 Convenience operator that executes a block with type (Void) -> (Void) in the main queue.
 
 Replaces:
 
 ```
 let blockOp = BlockOperation({
 print("blah")
 })
 
 OperationQueue.mainQueue().addOperations([blockOp], waitUntilFinished: true)
 
 ```
 
 with
 
 ```
 ^{print("blah")}
 ```
 
 */

public prefix func ^ (block : (Void) -> (Void)) -> Void {
    OperationQueue.mainQueue().addOperations([BlockOperation(block: block)], waitUntilFinished: true)
}

prefix operator ^^ {}

/**
 Convenience operator that executes a block with type (Void) -> (Void) in the main queue and blocks until it's finished.
 
 Replaces:
 

 
 ```
 OperationQueue.mainQueue().addOperationWithBlock({
 print("blah")
 })
 ```
 
 with
 
 ```
 ^^{print("blah")}
 ```
 
 */

public prefix func ^^ (block : (Void) -> (Void)) -> Void {
    OperationQueue.mainQueue().addOperations([BlockOperation(block: block)], waitUntilFinished: false)
}
