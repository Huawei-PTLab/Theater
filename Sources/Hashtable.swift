//
//  Hashtable.swift
//  
//
//  Created by Xuejun Yang on 8/27/16
//

//import Foundation
import Glibc

/**
Hash table implementation based on associative arrays and quadratic probing
*/

public final class Hashtable<K: Hashable, V> : CustomStringConvertible {
    private var tableSize = 8
    private var elementNum = 0
    private let emptyKey : K
    private let dummyValue : V

    /**
    Undelying array, do not modify it directly
    */
    
    private var keys : UnsafeMutablePointer<K>
    private var values : UnsafeMutablePointer<V>
    private var occupied: UnsafeMutablePointer<Bool>
    private var relocatedTo: UnsafeMutablePointer<[Int]>
    
    /**
    Stack default construction
     
    - returns : empty hash table
    */
    public init(count: Int, emptyKey : K, dummyValue : V) {
        self.emptyKey = emptyKey
        self.dummyValue = dummyValue
        
        while tableSize < count  { tableSize <<= 1 }

        self.keys = UnsafeMutablePointer<K>.allocate(capacity: tableSize) //ContiguousArray<K>(repeating: emptyKey, count: tableSize)
        self.values = UnsafeMutablePointer<V>.allocate(capacity: tableSize) //ContiguousArray<V>(repeating: dummyValue, count: tableSize)
        self.occupied = UnsafeMutablePointer<Bool>.allocate(capacity: tableSize) //ContiguousArray<Bool>(repeating: false, count: tableSize)
        self.relocatedTo = UnsafeMutablePointer<[Int]>.allocate(capacity: tableSize) //ContiguousArray<[Int]>(repeating: [], count: tableSize)
        for i in 0..<tableSize {
            (self.keys + i).initialize(to: self.emptyKey)
            (self.values + i).initialize(to: self.dummyValue)
            (self.occupied + i).initialize(to: false)
            (self.relocatedTo + i).initialize(to: [])
        }
    }

    deinit {
        self.keys.deinitialize(count: tableSize)
        self.keys.deallocate(capacity:tableSize)
        self.values.deinitialize(count: tableSize)
        self.values.deallocate(capacity:tableSize)
        self.occupied.deinitialize(count: tableSize)
        self.occupied.deallocate(capacity:tableSize)
        self.relocatedTo.deinitialize(count: tableSize)
        self.relocatedTo.deallocate(capacity:tableSize)
    }

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
    public func set(key: K, value: V) -> Bool {
       if key != self.emptyKey {
            let sizeMinus1 = (tableSize - 1)
            var index = key.hashValue & sizeMinus1
            let origIndex = index
            var probe = 0
            //print("inserting " + String(describing: key) + " : " + String(describing: value))
            while true {
                // case 1: the desired bucket is empty -> insert new entry
                if !self.occupied[index] {
                    self.keys[index] = key
                    self.values[index] = value
                    self.occupied[index] = true
                    if probe != 0 {
                        self.relocatedTo[origIndex].append(index)
                    }
                    elementNum += 1

                    // Grow the table if we are about to use up space
                    if self.count >= sizeMinus1 {
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
                    if probe >= tableSize {
                        // case 3a: table full! -> double the size
                        enlarge()
                        return set(key:key, value:value)
                    }
                }
            }
        }
        return false;
    }
    
    /**
    Find the index in the associative array for a given key

    - parameter key : key to look up
    - return: the index in the associative array. -1 if not found
     */

    private func findIndex(key: K, remove: Bool) -> Int {
        let index = key.hashValue & (tableSize - 1)
        
        // case 1: the bucket is empty -> return not found
        // We can do this because the move we did in remove function
        if !self.occupied[index] {
            return -1
        } 
        
        // case 2: the desired bucket is taken by the same key -> return value
        if self.keys[index] == key {
            return index
        }
            
        // case 3: collision! -> use relocatedTo array to find its real location
        for i in 0..<self.relocatedTo[index].count {
            let relocatedIndex = self.relocatedTo[index][i]
            if self.keys[relocatedIndex] == key {
                if remove { 
                    self.relocatedTo[index].remove(at: i) 
                }
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
        let index = findIndex(key:key, remove: false)
        if index != -1 { return self.values[index] }
        return nil
    }

    /**
    Remove the key-value pair identified by the key

    - parameter key : key to look up
    - return: true if deleted. false if not found
     */

    public func remove(key: K) -> Bool {
        var index = findIndex(key:key, remove: true)
        if index != -1 {
            elementNum -= 1

            // move a collided entry to here if there is one
            while !self.relocatedTo[index].isEmpty {
                let relocatedToIndex = self.relocatedTo[index].popLast()!

                // move the KV pair
                self.keys[index] = self.keys[relocatedToIndex]
                self.values[index] = self.values[relocatedToIndex]

                // deal with the next hole
                index = relocatedToIndex
            }
            // mark the bucket as empty
            self.occupied[index] = false

            // TODO: check if we should shrink the table
            return true
        }
        return false
    }

    /**
    Method to determine if the table is empty
    
    - returns : returns if the table is empty or not
    */
    
    public func isEmpty() -> Bool {
        return self.count == 0
    }
    
    /**
    Method to 4x the capacity of the table. All entries need to be copied
    */
    public func enlarge() { return enlarge (toSize: tableSize * 4) }

    /**
    Method to increase the capacity of the table to a given size. The size is normalized to 2 ^ n
    */
    public func enlarge(toSize: Int) {
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
            (newKeys + i).initialize(to: self.emptyKey)
            (newValues + i).initialize(to: self.dummyValue)
            (newFlags + i).initialize(to: false)
            (newRelocations + i).initialize(to: [])
        }
        elementNum = 0

        for i in 0..<origSize {
            let key = self.keys[i]
            let value = self.values[i]
            if self.occupied[i] {
                #if DEBUG 
                print("inserting " + String(key) + ":" + String(value))
                #endif

                var probe = 0;                      // how many times we've probed
                let sizeMinus1 = tableSize - 1;
                var index = key.hashValue & sizeMinus1;
                let origIndex = index
                while probe < tableSize {
                    #if DEBUG  
                    print("table size: \(tableSize), size-1: \(sizeMinus1), index: \(index), probe: \(probe)") 
                    #endif
                    if !newFlags[index] { break }
                    probe += 1
                    index = (index + probe) & sizeMinus1 
                }       
                assert(probe < tableSize, "Error: Hash table gets full during enlarging");

                newKeys[index] = key
                newValues[index] = value
                newFlags[index] = true
                if probe != 0 {
                    newRelocations[origIndex].append(index)
                }
                elementNum += 1
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
                let key = self.keys[i]
                let value = self.values[i]
                if occupied[i] {
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

var insertOnly = false
var noResizing = true

var allKeys = [String]()
var allValues = [Int]()
var deleteIndices = [Int]()
var lookupIndices = [Int]()
let allLetters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"

/**
Method to unit test the hash table with small number of entries
*/
private func smallTest() {
    let ht = Hashtable<String, Int>(count: 8, emptyKey:"", dummyValue:-1)
    let names = ["Zero", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Ten", "Eleven", "Twelve", "Thirteen", "Fourteen", "Fifteen"]
    var i = 0;
    for name in names {
        let _ = ht.set(key:name, value:i)
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

    let num1 = random() % count
    for _ in 0..<num1 {
        deleteIndices.append(random() % count)
    }
    print("Will delete \(num1) keys")

    let num2 = random() % count
    for _ in 0..<num1 {
        lookupIndices.append(random() % count)
    }
    print("Will lookup \(num2) keys")
}

func perfTestDictionary(count:Int) -> Int {
    var sum = 0 
    let start = clock()

    // measure timing for the standard Dictionary
    var ht = noResizing ? Dictionary<MyKey, MyVal>(minimumCapacity:count) : Dictionary<MyKey, MyVal>()

    // insert half of the pairs
    let mid = count/2
    for i in 0..<mid {
        ht[MyKey(allKeys[i])] = MyVal(allValues[i])
    } 
    //print("Hashtable: after first insert: \(ht.count)")

    if !insertOnly {
        // delete 1/2 of the entries in the table
        for index in deleteIndices {
            let _ = ht.removeValue(forKey: MyKey(allKeys[index]))
        }
    }
 
    // insert 2nd half of the pairs
    for k in mid..<count {
        ht[MyKey(allKeys[k])] = MyVal(allValues[k])
    }
    
    if !insertOnly {
        // lookup random number of entries
        for index in lookupIndices {
            let key = MyKey(allKeys[index])
            if let v = ht[key] {
                sum += v.i 
            }
        }
    }

    let end = clock()

    print("Time used with Dictionary filled with objects: \((end-start)/1) us")
    return sum;
}

func perfTestHashtable(count:Int) -> Int {
    var sum = 0
    let start = clock()

    // measure timing for this implementation
    let ht = Hashtable<MyKey, MyVal>(count: count, emptyKey: MyKey(""), dummyValue: MyVal(-1))

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

    if !insertOnly {
        // lookup random number of entries
        for index in lookupIndices {
            let key = MyKey(allKeys[index])
            if let v = ht[key] {
                sum += v.i 
            }
        }
    }

    let end = clock()

    print("Time used with Hashtable filled with objects: \((end-start)/1) us. Collison rate: \(ht.collisionRate())%")
    return sum;
}

private func bigTest() {
    var count = 100000
    if CommandLine.arguments.count > 1 { count = Int(CommandLine.arguments[1])! }
    if CommandLine.arguments.count > 2 { insertOnly = Bool(CommandLine.arguments[2])! }
    if CommandLine.arguments.count > 3 { noResizing = Bool(CommandLine.arguments[3])! }

    insertOnly = false
    noResizing = false
    print("count is \(count). insertOnly: \(insertOnly), noResizing: \(noResizing)")

    for _ in 0..<3 {
        generateKVs(count: count)
        generateDeleteAndLookupIndices(count: count)

        let i1 = perfTestDictionary(count: count)
        let i2 = perfTestHashtable(count: count)
        print("\(i1) vs \(i2)")
        assert(i1 == i2, "The sum is different. \(i1) != \(i2)")
    }
}

// Comment out tests to use Hashtable in an application
//smallTest()
//bigTest()


