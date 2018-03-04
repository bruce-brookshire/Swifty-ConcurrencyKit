class ArrayBlockingQueue<T>
{
    private var array: [T] = []
    private var m: pthread_mutex_t
    private var q_not_empty: pthread_cond_t
    
    init() {
        m = pthread_mutex_t()
        pthread_mutex_init(&m, nil)
        q_not_empty = pthread_cond_t()
        pthread_cond_init(&q_not_empty, nil)
    }
    
    deinit {
        pthread_mutex_destroy(&m)
        pthread_cond_destroy(&q_not_empty)
    }
    
    func insert(_ element: T) {
        pthread_mutex_lock(&m)
        defer { pthread_mutex_unlock(&m) }
        array.append(element)
        if array.count == 1 {
            pthread_cond_signal(&q_not_empty)
        }
    }
    
    func next() -> T {
        pthread_mutex_lock(&m)
        defer { pthread_mutex_unlock(&m) }
        
        while(array.count == 0) {
            pthread_cond_wait(&q_not_empty, &m)
        }
        
        return array.remove(at: 0)
    }
}

