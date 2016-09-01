/// A very simple sequential exectuor


public class Executor {
    var running : Bool = false // by default is false
    typealias Task = ()->()
    var taskQueue = FastQueue<Task>(initSize:100)

    func putAndRun(task: @escaping Task) {
        taskQueue.enqueue(item:  task)
        if !running {
            running = true
            while let task = taskQueue.dequeue() {
                task() //run the task, during the step, more tasks may be added
            }
            running = false
        }
    }
}
