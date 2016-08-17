
public protocol Queue {
  associatedtype T
  func enqueue(item:T) 
  func dequeue() -> T?
  func remove()->T
  func isEmpty()->Bool
  func peek()->T?
}

public class ArrayQueue<T>:Queue {
   private var items = [T]()

   public func enqueue(item:T) {
       items.append(item)
   }

   public func dequeue()->T? {
       return items.count == 0 ? nil : items.removeFirst()
   }

   public func remove()->T {
       return dequeue()!
   }

   public func isEmpty()->Bool {
       return items.isEmpty
   }

   public func peek()->T? {
       return items.first
   }
}


class QNode<T> {
    var value : T
    var next : QNode?

    init(item:T){
        value=item
    }
}

public class ListQueue<T>:Queue {
    private var top : QNode<T>!
    private var bottom : QNode<T>!

    init() {
        top = nil
        bottom = nil
    }

    public func enqueue(item:T) {
        let node:QNode<T> = QNode(item:item)

        if top == nil {
            top = node
            bottom = top
            return
        }
        bottom.next = node
        bottom = node
    }

    public func dequeue()->T? {
        let topItem:T? = top?.value
        if topItem == nil {
            return nil
        }

        if let nextItem = top.next {
            top = nextItem
        } else {
            top = nil
            bottom = nil
        }
        return topItem
    }

    public func remove()->T {
        return dequeue()!
    }

    public func isEmpty()->Bool {
        return top == nil ? true : false
    }

    public func peek() -> T? {
        return top?.value
    }
}


class FastQueue<T>:Queue {
    private var ptr : UnsafeMutablePointer<T>
    private var size : Int 

    init(initSize:Int) {
        size = initSize
        ptr = UnsafeMutablePointer<T>.allocate(capacity:size)
    }

    deinit {
        if count > 0 { //only deinitialize useful content
            if front == 0 || front < rear {
                (ptr+front).deinitialize(count:count)
            } else {
                ptr.deinitialize(count:rear)
                (ptr+front).deinitialize(count:count-rear)
            }
        } 
        ptr.deallocate(capacity:size)
    }

    private var rear : Int = 0
    private var front : Int = 0
    private var count : Int = 0

    /// Expand the storage to have more 
    private func expand() {
        // Full means rear == front && count == size
        // Case1: rear == front
        let newSize = size * 2 
        let newPtr = UnsafeMutablePointer<T>.allocate(capacity:newSize)

        if front == 0 || front < rear {
            newPtr.initialize(from:ptr+front, count:size)
            rear = size // can continue expand
        } else {
            newPtr.initialize(from:ptr+front, count:(size-front))
            (newPtr+size-front).initialize(from:ptr, count:front)
            front = 0
            rear = size
        }
        ptr.deinitialize(count:size)
        ptr.deallocate(capacity:size)
        ptr = newPtr
        size = newSize
    }


    public func enqueue(item:T) {
        if count == size {
            expand()
        }

        (ptr + rear).initialize(to:item)
        rear = (rear + 1) % size
        count += 1
    }

    public func dequeue() -> T? {
        guard count > 0 else { return nil }
        let item = (ptr + front).pointee
        (ptr + front).deinitialize()
        front = (front + 1) % size
        count -= 1
        return item
    }

    public func remove() -> T {
        guard count > 0  
        else { preconditionFailure("Queue is empty") }
        
        let item = (ptr + front).pointee
        (ptr + front).deinitialize()
        front = (front + 1) % size
        count -= 1
        return item
    }

    public func isEmpty()->Bool {
        return count == 0
    }

    public func peek() -> T? {
        guard count > 0 else { return nil }
        return (ptr + front).pointee
    }

}

