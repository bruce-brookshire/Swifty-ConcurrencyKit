class Stream<T> {
    
    fileprivate var operations: [(() -> T?)]
    
    init () {
        operations = []
    }
    
    init (array elements: [T]) {
        operations = []
        for element in elements {
            operations.append({ return element })
        }
    }
    
    fileprivate init (operations: inout [(() -> T?)]) {
        self.operations = operations
    }
    
    func parallel() -> ParallelStream<T> {
        return ParallelStream(stream: self)
    }
    
    func forEach(_ lambda: @escaping (T) -> Void){
        for operation in operations {
            if let operation = operation() {
                lambda(operation)
            }
        }
    }
    
    func apply(_ lambda: @escaping (T) -> T) -> Stream<T> {
        for i in 0..<operations.count {
            operations[i] = addLambda(first: operations[i], second: lambda)
        }
        return self
    }
    
    func map<B>(_ lambda: @escaping (T) -> B) -> Stream<B>  {
        var newOperations: [(() -> B?)] = []
        for operation in operations {
            newOperations.append(addLambda(first: operation, second: lambda))
        }
        return Stream<B>(operations: &newOperations)
    }
    
    func filter(_ lambda: @escaping (T) -> Bool) -> Stream<T> {
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
    
    func collect() -> [T] {
        var results: [T] = []
        for operation in operations {
            if let result = operation() {
                results.append(result)
            }
        }
        return results
    }
    
    private func addLambda<B>(first: @escaping () -> T?, second: @escaping (T) -> B?) -> (() -> B?) {
        return {
            if let first = first() {
                return second(first)
            } else {
                return nil
            }
        }
    }
    
    private func addLambda<T>(first: @escaping () -> T?, second: @escaping (T) -> T?) -> (() -> T?) {
        return {
            if let first = first() {
                return second(first)
            } else {
                return nil
            }
        }
    }
}

final class ParallelStream<T>: Stream<T> {
    
    init(stream: Stream<T>) {
        super.init(operations: &stream.operations)
    }
    
    override func forEach(_ lambda: @escaping (T) -> Void) {
        let execService = createExecServe()
        for operation in operations {
            let newOp = {
                let result = operation()
                if result != nil {
                    lambda(result!)
                }
            }
            execService.submit(newOp)
        }
        execService.shutdownNow()
    }
    
    override func collect() -> [T] {
        var results: [T] = []
        var futures: [Future<T>] = []
        
        let execService = createExecServe()
        
        for operation in operations {
            futures.append(execService.submit(operation))
        }
        
        for future in futures {
            if let future = future.get() {
                results.append(future)
            }
        }
        return results
    }
    
    private func createExecServe() -> ExecutorService {
        let processors = ProcessInfo.processInfo.activeProcessorCount
        return ExecutorService(threadCount: processors > 1 ? processors - 1 : 1, qos: .default)
    }
    
}
