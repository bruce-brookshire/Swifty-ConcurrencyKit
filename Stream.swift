//
//  Stream.swift
//  Swifty-ConcurrencyKit
//
//  Created by Bruce Brookshire on 2/27/18.
//  Copyright © 2018 bruce-brookshire.com. All rights reserved.
//

///Stream class allows for easy chaining of functional expressions
public class Stream<T> {
    
    ///Array of operations to perform
    fileprivate var operations: [(() -> T?)]
    
    ///Create a Stream to perform operations on given elements
    /// - parameter elements: Elements to perform operations on
    public init (array elements: [T]) {
        operations = []
        for element in elements { operations.append({ return element }) }
    }
    
    ///For easy initialization in map
    /// - parameter operations: operations to perform
    private init (operations: inout [(() -> T?)]) {
        self.operations = operations
    }
    
    ///Parallelizes the execution of this Stream
    /// - returns: A ParallelStream containing the same operations as self
    public func parallel() -> ParallelStream<T> {
        return ParallelStream(stream: self)
    }
    
    ///Completion stage function to perform an operation for each path in the Stream
    /// - parameter lambda: the operation to perform
    public func forEach(_ lambda: @escaping (T) -> Void){
        for operation in operations { if let operation = operation() { lambda(operation) } }
    }
    
    ///Intermediate operation function to apply an operation to each element in the Stream
    /// - parameter lambda: operation to apply
    /// - returns: self to continue chaining operations
    public func apply(_ lambda: @escaping (T) -> T) -> Stream<T> {
        for i in 0..<operations.count { operations[i] = addLambda(first: operations[i], second: lambda) }
        return self
    }
    
    ///Intermediate operation function to map an element to another type
    /// - parameter lambda: operation to map
    /// - returns: a new Stream with completion stage result of type B to continue chaining operations
    public func map<B>(_ lambda: @escaping (T) -> B) -> Stream<B>  {
        var newOperations: [(() -> B?)] = []
        for operation in operations { newOperations.append(addLambda(first: operation, second: lambda)) }
        return Stream<B>(operations: &newOperations)
    }
    
    ///Intermediate operation function to filter an element out of the Stream
    /// - parameter lambda: operation to filter elements
    /// - returns: self to continue chaining operations
    public func filter(_ lambda: @escaping (T) -> Bool) -> Stream<T> {
        for i in 0..<operations.count {
            operations[i] = {
                let element = self.operations[i]()
                if element != nil, lambda(element!) { return element }
                else { return nil }
            }
        }
        return self
    }
    
    ///Executes all operations and collects the results into an array
    /// - returns: An array of elements resulting from each operation submitted to the Stream
    public func collect() -> [T] {
        var results: [T] = []
        for operation in operations { if let result = operation() { results.append(result) } }
        return results
    }
    
    ///Composition function (helper function)
    private func addLambda<B>(first: @escaping () -> T?, second: @escaping (T) -> B?) -> (() -> B?) {
        return {
            if let first = first() { return second(first) }
            else { return nil }
        }
    }
}

///ParallelStream class allows for easy chaining of functional expressions executed in parallel
public class ParallelStream<T> {
    
    ///Array of operations to perform
    fileprivate var operations: [(() -> T?)]
    
    ///Create a ParallelStream to perform operations on given elements
    /// - parameter elements: Elements to perform operations on
    public init (array elements: [T]) {
        operations = []
        for element in elements {
            operations.append({ return element })
        }
    }
    
    ///Init a ParallelStream from a Stream
    /// - parameter stream: Stream to parallelize
    public init(stream: Stream<T>) {
        self.operations = stream.operations
    }
    
    ///For easy initialization in map
    /// - parameter operations: operations to perform
    private init (operations: inout [(() -> T?)]) {
        self.operations = operations
    }
    
    ///Completion stage function to perform an operation for each path in the Stream.
    ///Executes all operations in parallel
    /// - parameter lambda: the operation to perform
    public func forEach(_ lambda: @escaping (T) -> Void) {
        let execService = ExecutorService()
        for operation in operations {
            let newOp = {
                let result = operation()
                if result != nil {
                    lambda(result!)
                }
            }
            execService.submit(newOp)
        }
    }
    
    ///Executes all operations in parallel and collects the results into an array
    /// - returns: An array of elements resulting from each operation submitted to the ParallelStream
    public func collect() -> [T] {
        var results: [T] = []
        var futures: [Future<T>] = []
        
        let execService = ExecutorService()
        
        for operation in operations { futures.append(execService.submit(operation)) }
        
        for future in futures {
            if let future = future.get() { results.append(future) }
        }
        
        return results
    }
    
    ///Intermediate operation function to apply an operation to each element in the Stream
    /// - parameter lambda: operation to apply
    /// - returns: self to continue chaining operations
    public func apply(_ lambda: @escaping (T) -> T) -> ParallelStream<T> {
        for i in 0..<operations.count {
            operations[i] = addLambda(first: operations[i], second: lambda)
        }
        return self
    }
    
    ///Intermediate operation function to map an element to another type
    /// - parameter lambda: operation to map
    /// - returns: a new Stream with completion stage result of type B to continue chaining operations
    public func map<B>(_ lambda: @escaping (T) -> B) -> ParallelStream<B>  {
        var newOperations: [(() -> B?)] = []
        for operation in operations {
            newOperations.append(addLambda(first: operation, second: lambda))
        }
        return ParallelStream<B>(operations: &newOperations)
    }
    
    ///Intermediate operation function to filter an element out of the Stream
    /// - parameter lambda: operation to filter elements
    /// - returns: self to continue chaining operations
    public func filter(_ lambda: @escaping (T) -> Bool) -> ParallelStream<T> {
        for i in 0..<operations.count {
            operations[i] = {
                let element = self.operations[i]()
                if element != nil, lambda(element!) {
                    return element
                } else {
                    return nil
                }
            }
        }
        return self
    }
    
    ///Composition function (helper function)
    private func addLambda<B>(first: @escaping () -> T?, second: @escaping (T) -> B?) -> (() -> B?) {
        return {
            if let first = first() {
                return second(first)
            } else {
                return nil
            }
        }
    }
}

extension Array {
    ///Turn self into a Stream of the same type as self
    /// - returns: Stream of the same type as self
    public func toStream() -> Stream<Element> {
        return Stream(array: self)
    }
    
    ///Turn self into a ParallelStream of the same type as self
    /// - returns: ParallelStream of the same type as self
    public func toParallelStream() -> ParallelStream<Element> {
        return ParallelStream(array: self)
    }
}
