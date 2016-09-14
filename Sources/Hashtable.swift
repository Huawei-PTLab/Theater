//
//  Hashtable.swift
//  
//
//  Created by Xuejun Yang on 8/27/16
//  Copyright Xuejun Yang @ Huawei
//

import Glibc

/**
Hash table implementation based on associative arrays and quadratic probing.

As a major difference from the official Swift Dictionary implementation, aside 
from quadratic probing instead of linear probing, I use an array to track The
keys should be put in a bucket, but relocated to another due to collisions. This 
results in: 1) faster lookups; 2) faster deletions; 3) slower insertions; 
4) slower resizings.

Overall, the pros seem to outweight the cons. With a fixed number of insertions,
bundle with a random number of deletions and lookups, this implementation shows 
great performance gain over the official Swift Dictionary. However, I noticed
the gains are shrinked when 1) the keys have less collisions and/or 2) there 
are less deletions.
*/

public struct Hashtable<K: Hashable, V> : CustomStringConvertible {
    private var tableSize = 2
    private var elementNum = 0

    /**
    Undelying array, do not modify it directly
    */
    
    private var keys : UnsafeMutablePointer<K>
    private var values : UnsafeMutablePointer<V>
    private var occupied: UnsafeMutablePointer<Bool>
    private var relocatedTo: UnsafeMutablePointer<[Int]>
    
    /**
    Hash table default construction
     
    - returns : empty hash table
    */
    public init(count: Int = 2) {
        while tableSize < count  { tableSize <<= 1 }
        self.keys = UnsafeMutablePointer<K>.allocate(capacity: tableSize)
        self.values = UnsafeMutablePointer<V>.allocate(capacity: tableSize)
        self.occupied = UnsafeMutablePointer<Bool>.allocate(capacity: tableSize)
        self.relocatedTo = UnsafeMutablePointer<[Int]>.allocate(capacity: tableSize)
        for i in 0..<tableSize {
            (self.occupied + i).initialize(to: false)
            (self.relocatedTo + i).initialize(to: [])
        }
    }
    /*
    deinit {
        for i in 0..<tableSize {
            if occupied[i] {
                (self.values + i).deinitialize()
                (self.keys + i).deinitialize()
            }
        }

        self.keys.deallocate(capacity:tableSize)
        self.values.deallocate(capacity:tableSize)
        self.occupied.deallocate(capacity:tableSize)
        self.relocatedTo.deallocate(capacity:tableSize)
    } */

    /**
    Property about the number of elements in the hash table
    */
    var count: Int {
        return elementNum
    }

    /**
    Push an key-value pair of type (K, V) into the table
     
    - parameter key : key to insert
    - parameter value: value to insert
    - return: whether a new entry is created or not
    */
    mutating public func set(key: K, value: V) -> Bool {
        let sizeMinus1 = (tableSize - 1)
        var index = key.hashValue & sizeMinus1
        let origIndex = index
        var probe = 0
        //print("inserting " + String(describing: key) + " : " + String(describing: value))
        while true {
            // case 1: the desired bucket is empty -> insert new entry
            if !self.occupied[index] {
                (self.keys + index).initialize(to: key)
                (self.values + index).initialize(to: value)
                self.occupied[index] = true
                if probe != 0 {
                    self.relocatedTo[origIndex].append(index)
                }
                elementNum += 1

                // Grow the table if we are about to use up space
                if self.count >= (sizeMinus1 * 7 / 10) {
                    enlarge()
                }
                return true
            } 
            // case 2: the desired bucket is taken by the same key -> update value
            else if self.keys[index] == key {
                self.values[index] = value
                return false
            }
            // case 3: collision! -> use quadratic probing to find an available bucket
            else {
                probe += 1
                index = (index + probe) & sizeMinus1
                assert(probe < tableSize, "Failed to grow the table earlier")
            }
        }
    }
    
    /**
    Find the index in the associative array for a given key

    - parameter key : key to look up
    - return: the index in the associative array. -1 if not found
     */

    private func findIndex(key: K) -> Int {
        let index = key.hashValue & (tableSize - 1)
        
        // case 1: the bucket is empty -> return not found
        // We can do this because the move we did in remove function
        if !self.occupied[index] {
            return -1
        } 
        
        // case 2: the desired bucket is taken by the same key -> return key index
        if self.keys[index] == key {
            return index
        }
            
        // case 3: collision! -> use relocatedTo array to find its real location
        for i in 0..<self.relocatedTo[index].count {
            let relocatedIndex = self.relocatedTo[index][i]
            if self.keys[relocatedIndex] == key {
                return relocatedIndex
            }
        }

        // case 4: searched all table -> not found
        return -1
    }

    mutating private func findAndRemoveRelocateIndex(key: K) -> Int {
        let index = key.hashValue & (tableSize - 1)
        
        // case 1: the bucket is empty -> return not found
        // We can do this because the move we did in remove function
        if !self.occupied[index] {
            return -1
        } 
        
        // case 2: the desired bucket is taken by the same key -> return key index
        if self.keys[index] == key {
            return index
        }
            
        // case 3: collision! -> use relocatedTo array to find its real location
        for i in 0..<self.relocatedTo[index].count {
            let relocatedIndex = self.relocatedTo[index][i]
            if self.keys[relocatedIndex] == key {
                self.relocatedTo[index].remove(at: i) 
                return relocatedIndex
            }
        }

        // case 4: searched all table -> not found
        return -1
    }

    /**
    Retrieve the value associated with a key

    - parameter key : key to look up
     */

    public func get(key: K) -> V? {
        let index = findIndex(key:key)
        if index != -1 { return self.values[index] }
        return nil
    }

    /**
    Remove the key-value pair identified by the key

    - parameter key : key to look up
    - return: true if deleted. false if not found
     */

    mutating public func remove(key: K) -> Bool {
        var index = findAndRemoveRelocateIndex(key:key)
        if index != -1 {
            elementNum -= 1

            // move a collided entry to here if there is one
            while !self.relocatedTo[index].isEmpty {
                let relocatedToIndex = self.relocatedTo[index].popLast()!

                // move the KV pair
                self.keys[index] = self.keys[relocatedToIndex]
                self.values[index] = self.values[relocatedToIndex]

                // deal with the hole left by the above moving
                index = relocatedToIndex
            }
            // mark the bucket as empty
            self.occupied[index] = false
            // free the value and key
            (self.values + index).deinitialize()
            (self.keys + index).deinitialize()

            // TODO: check if we should shrink the table
            return true
        }
        return false
    }

    mutating public func removeValue(forKey: K) {
        let _ = remove(key: forKey)
    }

    /**
    Method to determine if the table is empty
    
    - returns : returns if the table is empty or not
    */
    
    public func isEmpty() -> Bool {
        return self.count == 0
    }

    public func forEachValue(_ lambda: (V)->()) {
        //var cnt = 0
        for i in 0..<tableSize {
            if occupied[i] {
                lambda(values[i])
                //cnt += 1
                // early exit
                //if cnt == self.count { break }
            }
        }
    }

    public func forEachKey(_ lambda: (K)->()) {
        //var cnt = 0
        for i in 0..<tableSize {
            if occupied[i] {
                lambda(keys[i])
                //cnt += 1
                // early exit 
                //if cnt == self.count { break }
            }
        }
    }

    public func forEach(_ lambda: (K, V)->()) {
        for i in 0..<tableSize {
            if occupied[i] {
                lambda(keys[i], values[i])
            }
        }
    }
    
    /**
    Method to 4x the capacity of the table. All entries need to be copied
    */
    mutating public func enlarge() { return enlarge (toSize: tableSize * 4) }

    /**
    Method to increase the capacity of the table to a given size. The size is normalized to 2 ^ n
    */
    mutating public func enlarge(toSize: Int) {
        #if DEBUG 
        print("Table before enlarging: \(self)")
        #endif

        let origSize = tableSize
        while tableSize < toSize  { tableSize <<= 1 }
        #if DEBUG  
        print("Table size will be \(tableSize)")
        #endif

        let newKeys = UnsafeMutablePointer<K>.allocate(capacity: tableSize)
        let newValues = UnsafeMutablePointer<V>.allocate(capacity: tableSize)
        let newFlags = UnsafeMutablePointer<Bool>.allocate(capacity: tableSize)
        let newRelocations = UnsafeMutablePointer<[Int]>.allocate(capacity: tableSize)
        for i in 0..<tableSize {
            (newFlags + i).initialize(to: false)
            (newRelocations + i).initialize(to: [])
        }

        for i in 0..<origSize {
            if self.occupied[i] {
                let key = self.keys[i]
                let value = self.values[i]
                #if DEBUG 
                print("inserting " + String(describing: key) + ":" + String(describing: value))
                #endif

                var probe = 0;                      // how many times we've probed
                let sizeMinus1 = tableSize - 1;
                var index = key.hashValue & sizeMinus1;
                let origIndex = index

                // Shortcut???: the length of the relocation array tells us how many conflicts 
                // we've had. Skip checking the already relocated-to buckets
                //var probe = newRelocations[origIndex].count
                //if probe > 0 {
                //    index = newRelocations[origIndex].last!
                //}
                while probe < tableSize {
                    #if DEBUG  
                    print("table size: \(tableSize), size-1: \(sizeMinus1), index: \(index), probe: \(probe)") 
                    #endif
                    if !newFlags[index] { break }
                    probe += 1
                    index = (index + probe) & sizeMinus1 
                }       
                assert(probe < tableSize, "Error: Hash table gets full during enlarging");

                (newKeys + index).initialize(to: key)
                (newValues + index).initialize(to: value)
                newFlags[index] = true
                if probe != 0 {
                    newRelocations[origIndex].append(index)
                }
            }
        }

        self.keys.deallocate(capacity: origSize)
        self.values.deallocate(capacity: origSize)
        self.occupied.deallocate(capacity: origSize)
        self.relocatedTo.deallocate(capacity: origSize)

        self.keys = newKeys
        self.values = newValues // TODO: make array copy more efficient with ownership
        self.occupied = newFlags
        self.relocatedTo = newRelocations

        #if DEBUG
        print("Table after enlarging: \(self)")
        #endif
    }

    /**
    Method to implement CustomStringConvertible
    */
    public var description: String {
        get {
            if elementNum == 0 { return "[]"}
            var str = "["
            for i in 0..<tableSize {
                if occupied[i] {
                    let key = self.keys[i]
                    let value = self.values[i]
                    if str != "[" { str += ", "}
                    str += String(describing: key) + ": " + String(describing: value)
                }
            }
            str += "]"
            return str
        }
    }

    /**
    Method to calculate collision rate as: 
        1) the size of relocatedTo array for each bucket represents the collisions found for that bucket index
        2) Collision Rate = Sum(relocatedTo-array-sizes) / elementNum
    */
    public func collisionRate() -> Int {
        var collisions = 0
        for i in 0..<tableSize {
            collisions += self.relocatedTo[i].count

            #if DEBUG
            print("\(i)....\(self.relocatedTo[i])....\(self.occupied[i])")
            #endif
        }
        return collisions * 100 / self.elementNum
    }

    /**
    Method to enable subscripted read/write, such as "hashTable["aaa"] = hashTable["bbb"] + 1"
    */
    subscript(key: K) -> V? {
        get {
            return get(key: key)
        }
        set {
            if let value = newValue {
                let _ = set(key: key, value: value)
            } else {
                let _ = remove(key: key)
            }
        }
    }
} 

public struct ThreadSafeHashtable<K: Hashable, V> : CustomStringConvertible {
    var hashtable: Hashtable<K, V>;
    // Thread safe read-write lock
    var lock = pthread_rwlock_t()
    public init(count: Int = 2) {
        hashtable = Hashtable<K, V>(count:count)
        pthread_rwlock_init(&lock, nil)
    }

    mutating public func set(key: K, value: V) -> Bool {
        pthread_rwlock_wrlock(&lock);
        defer { pthread_rwlock_unlock(&lock); }
        return hashtable.set(key:key, value:value)
    }

    mutating public func get(key: K) -> V? {
        pthread_rwlock_rdlock(&lock);
        defer { pthread_rwlock_unlock(&lock); }
        return hashtable.get(key:key)
    }

    mutating public func remove(key: K) -> Bool {
        pthread_rwlock_wrlock(&lock);
        defer { pthread_rwlock_unlock(&lock); }
        return hashtable.remove(key:key)
    }

    mutating public func isEmpty() -> Bool {
        pthread_rwlock_rdlock(&lock);
        defer { pthread_rwlock_unlock(&lock); }
        return hashtable.isEmpty() 
    }

    // FIXME: description is not thread safe. But swift doesnot allow mutating get for description
    public var description: String {
        //pthread_rwlock_rdlock(&lock);
        //defer { pthread_rwlock_unlock(&lock); }
        return hashtable.description
    }

    mutating public func forEachValue(_ lambda: (V)->()) {
        pthread_rwlock_rdlock(&lock);
        defer { pthread_rwlock_unlock(&lock); }
        hashtable.forEachValue(lambda)
    }


    mutating public func forEachKey(_ lambda: (K)->()) {
        pthread_rwlock_rdlock(&lock);
        defer { pthread_rwlock_unlock(&lock); }
        hashtable.forEachKey(lambda)
    }

    mutating public func forEach(_ lambda: (K, V)->()) {
        pthread_rwlock_rdlock(&lock);
        defer { pthread_rwlock_unlock(&lock); }
        hashtable.forEach(lambda)
    }

    subscript(key: K) -> V? {
        mutating get {
            return get(key: key)
        }
        set {
            if let value = newValue {
                _ = set(key: key, value: value)
            } else {
                _ = remove(key: key)
            }
        }
    }
}



/*********************************************************************************
 *              End of implementation. Test code below.
 *********************************************************************************/

/**
Class to represent objects stored in the hash table as values
*/
final class MyVal {
    public var i = 0
    init(_ input:Int) { i = input }
}

/**
Class to represent objects stored in the hash table as keys
*/
struct MyKey : Hashable {
    public var s = ""
    init(_ input:String) { s = input }

    public var hashValue: Int { get { return s.hashValue}}
}

func ==(x: MyKey, y: MyKey) -> Bool {
    return x.s == y.s
}

/**
Method to unit test the hash table with small number of entries
*/
private func smallTest() {
    //print("11")
    var ht = Hashtable<String, Int>(count: 8)
    //print("22")
    let names = ["Zero", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Ten", "Eleven", "Twelve", "Thirteen", "Fourteen", "Fifteen"]
    var i = 0;
    for name in names {
        //print("33 \(name)")
        let _ = ht.set(key:name, value:i)
        //print("44")
        i += 1
    }

    let _ = ht.remove(key:"Sixteen")
    let _ = ht.remove(key:"Eight")

    let _ = ht.set(key:"Sixteen", value:16)

    assert(ht.get(key:"Five")! == 5, "Wrong value at 5")
    assert(ht.get(key:"Eight") == nil, "Wrong value at 8")

    print(ht)

    let _ = ht.remove(key:"Five")
    let _ = ht.remove(key:"Six")
    let _ = ht.remove(key:"Ten")
    let _ = ht.remove(key:"Twelve")
    let _ = ht.remove(key:"Thirteen")
    let _ = ht.remove(key:"Three")
    let _ = ht.remove(key:"Fifteen")
    let _ = ht.remove(key:"Fourteen")
    let _ = ht.remove(key:"Two")
    let _ = ht.remove(key:"One")
    let _ = ht.remove(key:"Zero")

    assert(ht.get(key:"Four")! == 4, "Wrong value at 4")
    assert(ht.get(key:"Ten") == nil, "Wrong value at 10")

    print(ht)
}

var allKeys = [String]()
var allValues = [Int]()
var deleteIndices = [Int]()
var lookupIndices = [Int]()
var updateIndices = [Int]()
let allLetters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"

func generateKVs(count: Int) {
    allKeys = []
    allValues = []
    // create the random key-value pairs
    for _ in 0..<count {
        var index = allLetters.index(allLetters.startIndex, offsetBy: random() % 52)
        var key : String = String(allLetters[index])
        index = allLetters.index(allLetters.startIndex, offsetBy: random() % 52)
        key += String(allLetters[index])
        index = allLetters.index(allLetters.startIndex, offsetBy: random() % 52)
        key += String(allLetters[index])

        allKeys.append(key)

        allValues.append(random())
    }
    #if DEBUG
    print(allKeys) 
    #endif
}

func generateDeleteAndLookupIndices(count : Int) {
    deleteIndices = []
    lookupIndices = []
    updateIndices = []

    let num1 = random() % count
    for _ in 0..<num1 {
        deleteIndices.append(random() % count)
    }
    //print("Will delete \(num1) keys")

    let num2 = random() % count
    for _ in 0..<num2 {
        lookupIndices.append(random() % count)
    }
    //print("Will lookup \(num2) keys")
    
    let num3 = random() % count
    for _ in 0..<num3 {
        updateIndices.append(random() % count)
    }
    //print("Will update \(num3) keys")
}

var insertOnly = false      // If true, we only do insertions to the table, nithing else
var testDictionary = true
var testHashtable = true

func perfTestDictionary(count:Int) -> (Int, Int) {
    var sum = 0 
    let start = clock()

    // measure timing for the standard Dictionary
    var ht = Dictionary<MyKey, MyVal>()

    // insert half of the pairs
    let mid = count/2
    for i in 0..<mid {
        ht[MyKey(allKeys[i])] = MyVal(allValues[i])
    }

    //print("Hashtable: after first insert: \(ht.count())")

    if !insertOnly {
        // delete random number of entries in the table
        for index in deleteIndices {
            ht.removeValue(forKey: MyKey(allKeys[index]))
        }
    }
   
    // insert 2nd half of the pairs
    for k in mid..<count {
        ht[MyKey(allKeys[k])] = MyVal(allValues[k])
    }

    // update random number of values
    if (!insertOnly) {
        for index in updateIndices {
            let key = MyKey(allKeys[index])
            ht[key] = MyVal(0)
        }
    }

    // Sum up random number of values
    if !insertOnly {
        // lookup random number of entries
        for index in lookupIndices {
            let key = MyKey(allKeys[index])
            if let v = ht[key] {
                sum = sum &+ v.i 
            }
        }
    }

    let end = clock()

    print("Time used with Dictionary filled with objects: \((end-start)/1) us")
    return (sum, end-start);
}

func perfTestHashtable(count:Int) -> (Int, Int) {
    var sum = 0
    let start = clock()

    // measure timing for this implementation
    var ht = Hashtable<MyKey, MyVal>()

    // insert half of the pairs
    let mid = count/2
    for i in 0..<mid {
        ht[MyKey(allKeys[i])] = MyVal(allValues[i])
    }

    //print("Hashtable: after first insert: \(ht.count())")

    if !insertOnly {
        // delete random number of entries in the table
        for index in deleteIndices {
            let _ = ht.remove(key: MyKey(allKeys[index]))
        }
    }
   
    // insert 2nd half of the pairs
    for k in mid..<count {
        ht[MyKey(allKeys[k])] = MyVal(allValues[k])
    }

    // update random number of values
    if (!insertOnly) {
        for index in updateIndices {
            let key = MyKey(allKeys[index])
            ht[key] = MyVal(0)
        }
    }

    // Sum up random number of values
    if !insertOnly {
        // lookup random number of entries
        for index in lookupIndices {
            let key = MyKey(allKeys[index])
            if let v = ht[key] {
                sum = sum &+ v.i 
            }
        }
    }

    let end = clock()

    print("Time used with Hashtable filled with objects: \((end-start)/1) us. Collison rate: \(ht.collisionRate())%")
    return (sum, end-start);
}

private func bigTest() {
    var count = 100000
    if CommandLine.arguments.count > 1 { 
        count = Int(CommandLine.arguments[1])! 
    }
    if CommandLine.arguments.count > 2 {
        print(CommandLine.arguments[2])
        if CommandLine.arguments[2] == "Dict" { testDictionary = true; testHashtable = false }
        else if CommandLine.arguments[2] == "Hash" { testDictionary = false; testHashtable = true }
    }

    insertOnly = false
    print("count is \(count). insertOnly: \(insertOnly), testDictionary: \(testDictionary), testHashtable: \(testHashtable)")

    let loops = 100
    var totalTime1 = 0
    var totalTime2 = 0
    for i in 0..<loops {
        generateKVs(count: count)
        generateDeleteAndLookupIndices(count: count)

        let (sum1, time1) = testDictionary ? perfTestDictionary(count: count) : (0, 0)
        let (sum2, time2) = testHashtable ? perfTestHashtable(count: count) : (0, 0)
        print("Iteration \(i): \(sum1) vs \(sum2)")
        if testDictionary && testHashtable {
            assert(sum1 == sum2, "Iteration \(i): the sums are different. \(sum1) != \(sum2)")
        }
        totalTime1 += time1
        totalTime2 += time2
    }
    print("Average time spent with Dictionary: \(totalTime1/100)")
    print("Average time spent with Hashable: \(totalTime2/100)")
}

// Comment out tests to use Hashtable in an application
//smallTest()
//bigTest()


