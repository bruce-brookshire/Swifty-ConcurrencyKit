//
//  ExecutorService.swift
//  Swifty-ConcurrencyKit
//
//  Created by Bruce Brookshire on 2/27/18.
//  Copyright © 2018 bruce-brookshire.com. All rights reserved.
//

///Protocol for SwiftyThread to communicate with its ExecutorService owner
fileprivate protocol SwiftyThreadDelegate {
    func getNextTask() -> (() -> Void)?
    func timeOutThread()
}

///ExecutorService uses a specified number of threads to run tasks asynchronously in the background
///Tasks can be runnable or callable, the latter being fulfilled through a potentially blocking call to Future.get()
///It is recommended that Future.get() for Callables only be called after all tasks first submitted for processing.
final class ExecutorService: SwiftyThreadDelegate
{
    private var threads: [SwiftyThread]
    private var queue: BlockingQueue<() -> Void>
    private var threadQueueLock: NSLock = NSLock()
    private var threadId = 0
    private var autoScaling: Bool
    private var qos: QualityOfService
    
    var isAutoScaling: Bool {
        get {
            return autoScaling
        }
        set {
            autoScaling = newValue
            threadQueueLock.lock()
            for thread in threads {
                thread.isScalable = autoScaling
            }
            threadQueueLock.unlock()
        }
    }
    
    ///The quality of service of thread execution
    var qualityOfService: QualityOfService {
        get {
            return qos
        }
        set {
            qos = newValue
            threadQueueLock.lock()
            for thread in threads {
                thread.qualityOfService = newValue
            }
            threadQueueLock.unlock()
        }
    }
    
    var numberOfValues: Int {
        get {
            return threads.count
        }
    }
    
    ///Initializes ExecutorService to be able to process submitted tasks
    /// - parameter threadCount: Number of threads to utilize in processing. Default is 1
    /// - parameter qos: Quality of service with which to process submitted tasks. Default is .default
    init (threadCount: Int? = nil, qos: QualityOfService = .default, autoScaling: Bool = true) {
        threads = []
        queue = BlockingQueue()
        self.autoScaling = autoScaling
        self.qos = qos
        
        var threadCount = threadCount
        if threadCount == nil {
            let processors = ProcessInfo.processInfo.activeProcessorCount
            threadCount = (processors > 1 ? (processors - 1) : 1)
        }
        
        for i in 0..<threadCount! {
            threads.append(SwiftyThread(delegate: self, qos: qos, isScalable: autoScaling))
            threads[i].name = String(i)
        }
        threadId = threadCount!
        
        for thread in threads { thread.start() }
    }
    
    deinit { if threads.count > 0 { shutdownNow() } }
    
    ///Delegate method for a SwiftyThread to retreive the next processable entity
    /// - returns: A processable entity. If nil, there was no process to complete
    fileprivate func getNextTask() -> (() -> Void)? {
        return queue.timedNext(waitTimeSeconds: 5)
    }
    
    private func scaleIfNecessary() {
        if autoScaling && (queue.unsafeGetSize()/2) > threads.count {
            threadQueueLock.lock()
            threads.append(SwiftyThread(delegate: self, qos: qos, isScalable: autoScaling))
            threads[threads.count - 1].name = String(threadId)
            threadId += 1
            threadQueueLock.unlock()
        }
    }
    
    func addThreads(quantity: Int) throws {
        if quantity <= 0 {
            throw ExecutorServiceError.InvalidValue("Cannot add a non-positive number of threads")
        } else {
            threadQueueLock.lock()
            for _ in 0..<quantity {
                threads.append(SwiftyThread(delegate: self, qos: qos, isScalable: autoScaling))
                threads[threads.count - 1].name = String(threadId)
                threadId += 1
            }
            threadQueueLock.unlock()
        }
    }
    
    func reduceThreads(quantity: Int) throws {
        if quantity <= 0 {
            throw ExecutorServiceError.InvalidValue("Cannot remove a non-positive number of threads")
        } else if quantity > threads.count {
            throw ExecutorServiceError.InvalidValue("Cannot remove more threads than exist")
        } else {
            threadQueueLock.lock()
            for i in 0..<quantity {
                threads[i].cancel()
            }
            threadQueueLock.unlock()
        }
    }
    
    fileprivate func timeOutThread() {
        let name = Thread.current.name!
        threadQueueLock.lock()
        for i in 0..<threads.count {
            if threads[i].name! == name { threads.remove(at: i); break}
        }
        threadQueueLock.unlock()
    }
    
    ///Submit a callable for execution
    /// - parameter callable: A Callable that processes and returns an entity
    /// - returns: A Future to the entity returned from Callable
    func submit<T>(_ callable: Callable<T>) -> Future<T> { return submit(callable.call) }
    
    ///Submit a Runnable for execution
    /// - parameter runnable: A Runnable that processes a task
    func submit(_ runnable: Runnable) { submit(runnable.run) }
    
    ///Submit a callable for execution
    /// - parameter lambda: A callable that processes and returns an entity
    /// - returns: A Future to the entity returned from lambda
    func submit<T>(_ lambda: @escaping () -> T?) -> Future<T> {
        let future = Future<T>()
        let task = { future.set(t: lambda()) }
        
        queue.insert(task)
        scaleIfNecessary()
        return future
    }
    
    ///Submit a task for execution
    /// - parameter task: A runnable that processes a task
    func submit(_ task: @escaping () -> Void) {
        queue.insert(task)
        scaleIfNecessary()
    }
    
    ///Shutdown current threads managed by the ExecutorService
    func shutdownNow() {
        for thread in threads {
            thread.cancel()
        }
        threads = []
    }
    
    enum ExecutorServiceError: Error {
        case InvalidValue(String)
    }
}

///Custom Thread class to be able to retrieve tasks to process utilizing
///     a work stealing approach
fileprivate class SwiftyThread: Thread
{
    private var swifty_delegate: SwiftyThreadDelegate
    fileprivate var isScalable: Bool
    
    ///Submit a callable for execution
    /// - parameter delegate: Protocol that delivers the source of tasks to process
    /// - parameter qos: Service quality to be performed by the thread
    init(delegate: SwiftyThreadDelegate, qos: QualityOfService, isScalable: Bool) {
        self.swifty_delegate = delegate
        self.isScalable = isScalable
        super.init()
        qualityOfService = qos
    }
    
    ///Hook method overriden from Thread to perform execution.
    ///     accesses delegate for task supply. If there is no task to perform,
    ///     Thread blocks for 60s then shuts down.
    override func main() {
        while (!isCancelled) {
            if let task = swifty_delegate.getNextTask() {
                task()
            } else {
                if isScalable {
                    cancel()
                }
            }
        }
        swifty_delegate.timeOutThread()
    }
}

///Template class. Implement and override run() to submit a task to ExecutorService
class Runnable { func run() {} }

///Template class. Implement and override call() -> T? to submit a task to ExecutorService
class Callable<T> { func call() -> T? { return nil } }
