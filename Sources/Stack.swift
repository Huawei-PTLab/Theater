//
//  ArrayAsStack.swift
//  Actors
//
//  Created by Dario on 10/5/15.
//  Copyright © 2015 dario. All rights reserved.
//

import Foundation

/**
Stack data structure implementation for general purposes.
*/

public class Stack<A> {
    
    /**
    Undelying array, do not modify it directly
    */
    
    private var array : [A]
    
    /**
    Stack default construction
     
    - returns : empty Stack
    */
    
    public init() {
        self.array = [A]()
    }
    
    /**
    Push an element of type A into the Stack
     
    - parameter element : element to push
    */
    
    public func push(element : A) -> Void {
        self.array.append(element)
    }
    
    /**
    Pop an element from the Stack, if the stack is emplty, it returns None
    */
    
    public func pop() -> Optional<A> {
        return self.array.popLast();
    }
    
    /**
    Peek into the stack, handy when you want to determine what's left in the Stack without removing the element from the stack
    */
    
    public func head() -> Optional<A> {
        return self.array.last
    }
    
    /**
    Method to determine if the stack is empty
    
    - returns : returns if the Stack is empty or not
    */
    
    public func isEmpty() -> Bool {
        return self.array.isEmpty
    }
    
}
