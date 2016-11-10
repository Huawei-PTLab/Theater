//
// Copyright (c) 2015 Dario Lencina and Huawei PT-Lab Open Source project authors.
// Licensed under Apache License v2.0
//
// Stack.swift
// A simple Stack implementation based on Array
//


/// Stack data structure implementation for general purposes.
public class Stack<A> {

    /// Undelying array, do not modify it directly
    private var array : [A]

    /// Stack default construction
    /// - Returns: empty stack
    public init() {
        self.array = [A]()
    }
    

    /// Push an element of type A into the Stack
    /// - Parameter element : element to push
    public func push(element : A) -> Void {
        self.array.append(element)
    }

    /// Push an element of type A into the Stack and replace the prev head if
    /// there is one
    /// - Parameter element : element to push
    /// - Returns : the previous head
    public func replaceHead(element : A) ->  Optional<A> {
        if self.array.count == 0 {
            self.array.append(element);
            return nil;
        } else {
            let old = self.array[array.count - 1];
            self.array[array.count - 1] = element;
            return old;
        }
    }

    /// Pop an element from the Stack, if the stack is emplty, it returns nil
    public func pop() -> A? {
        return self.array.popLast();
    }

    /// Peek into the stack, handy when you want to determine what's left in the 
    /// stack without removing the element from the stack
    public func head() -> A? {
        return self.array.last
    }
    
    /// Method to determine if the stack is empty
    /// Returns: returns if the stack is empty or not
    public func isEmpty() -> Bool {
        return self.array.isEmpty
    }
    
}
