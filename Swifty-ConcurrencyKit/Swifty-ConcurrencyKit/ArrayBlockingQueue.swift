

class ArrayBlockingQueue<T>
{
    private var array: [T] = []
    private var m = pthread_mutex_t()
    
    func insert(_ element: T) {
        print("inserting", array.count + 1)
        array.append(element)
    }
    
    func next() -> T {
        print("returning", array.count)
        return array.remove(at: 0)
    }
    
    func size() -> Int {
        return array.count
    }
    
    func lock() {
        pthread_mutex_lock(&m)
    }
    
    func unlock() {
        pthread_mutex_unlock(&m)
    }
}

