extension Sequence where SubSequence: Sequence, SubSequence.Iterator.Element == Iterator.Element {
    public func isSorted<Comparator: Comparable>(on transform: @escaping (Iterator.Element) -> Comparator) -> Bool {
        let transformed = lazy.map(transform)
        for (lhs, rhs) in zip(transformed, transformed.dropFirst()) {
            guard lhs <= rhs else { return false }
        }
        return true
    }
    
    // FIXME: Use `withoutActuallyEscaping` in Swift 3.1
    public func sorted<Comparator: Comparable>(on transform: @escaping (Iterator.Element) -> Comparator) -> [Iterator.Element] {
        return /*withoutActuallyEscaping(transform) { transform in*/
            lazy.map({ (value: $0, comparator: transform($0)) })
            .sorted(by: { (a, b) in a.comparator < b.comparator })
            .map({ $0.value })
        /*}*/
    }
}

public struct LazyMapSortedArray<Element, Comparator: Comparable> {
    fileprivate var array: [Element]
    fileprivate var transform: (Element) -> Comparator
}

extension LazyMapSortedArray {
    /// Constructs a `LazyMapSortedArray` assuing that `array` is already sorted,
    /// only performing check during testing.
    public init(unsafeUncheckedFromSorted array: [Element], on transform: @escaping (Element) -> Comparator) {
        assert(array.isSorted(on: transform))
        self.array = array
        self.transform = transform
    }
    
    /// Constructs a `LazyMapSortedArray` if `array` is verified to be sorted, otherwise returns `nil`.
    public init?(fromSorted array: [Element], on transform: @escaping (Element) -> Comparator) {
        guard array.isSorted(on: transform) else { return nil }
        self.array = array
        self.transform = transform
    }
    
    // Constructs a `LazyMapSortedArray` by sorting `array`.
    public init(fromUnsorted array: [Element], on transform: @escaping (Element) -> Comparator) {
        self.array = array.sorted(on: transform)
        self.transform = transform
    }
    
    public init(on transform: @escaping (Element) -> Comparator) {
        self.array = []
        self.transform = transform
    }
}

extension Array {
    public init<Comparator: Comparable>(_ sortedArray: LazyMapSortedArray<Comparator, Element>) {
        self = sortedArray.array
    }
}

extension LazyMapSortedArray: BidirectionalCollection {
    public var indices: CountableRange<Int> {
        return array.indices
    }
    
    public func index(after i: Int) -> Int {
        return array.index(after: i)
    }
    
    public func index(before i: Int) -> Int {
        return array.index(before: i)
    }

    public func index(_ i: Int, offsetBy n: Int) -> Int? {
        return array.index(i, offsetBy: n)
    }
    
    public func index(_ i: Int, offsetBy n: Int, limitedBy limit: Int) -> Int? {
        return array.index(i, offsetBy: n, limitedBy: limit)
    }
    
    public var startIndex: Int {
        return array.startIndex
    }
    
    public var endIndex: Int {
        return array.endIndex
    }
    
    public subscript(index: Int) -> Element {
        return array[index]
    }
}

extension LazyMapSortedArray {
    public subscript(checked index: Int) -> Element {
        get {
            return self[index]
        }
        set {
            let newValueComparator = transform(newValue)
            if index - 1 >= array.startIndex {
                let precedingValue = array[index - 1]
                let precedingValueComparator = transform(precedingValue)
                guard precedingValueComparator <= newValueComparator else {
                    preconditionFailure("Cannot assign \(newValue) in position after \(precedingValue).") 
                }
            }
            if index + 1 < array.endIndex {
                let followingValue = array[index + 1]
                let followingValueComparator = transform(followingValue)
                guard newValueComparator <= followingValueComparator else {
                    preconditionFailure("Cannot assign \(newValue) in position before \(followingValue).") 
                }
            }
            array[index] = newValue
        }
    }
    
    public subscript(unsafeUnchecked index: Int) -> Element {
        get {
            return self[index]
        }
        set {
            #if DEBUG
                // Check during debug mode
                self[index] = newValue
            #else
                array[index] = newValue
            #endif
        }
    }
}

extension LazyMapSortedArray: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        return array.description
    }
    
    public var debugDescription: String {
        return array.debugDescription
    }
}

extension LazyMapSortedArray {
    public func insertionIndex(of element: Element, for position: IndexPosition = .any,
                               in range: Range<Int>) -> Int {
        let elementComparator = transform(element)
        var (min, max) = (range.lowerBound, range.upperBound)
        while min < max {
            let mid = (max - min) / 2 + min
            let midElement = self[mid]
            let midElementComparator = transform(midElement)
            
            if midElementComparator < elementComparator {
                min = mid + 1
            } else if midElementComparator > elementComparator {
                max = mid
            } else {
                switch position {
                    case .first: max = mid
                    case .last:  min = mid + 1
                    case .any:   return mid
                }
            }
        }
        assert(min == max)
        return min
    }
    
    /// The index at which an element would be inserted into the array.
    public func insertionIndex(of element: Element, for position: IndexPosition = .any) -> Int {
        return insertionIndex(of: element, for: position, in: Range(array.indices))
    }
    
    @discardableResult 
    public mutating func insert(_ element: Element, at position: IndexPosition = .any) -> Int {
        let index = insertionIndex(of: element, for: position)
        array.insert(element, at: index)
        return index
    }
}

extension LazyMapSortedArray {
    public mutating func insert<S: Sequence>(contentsOf sequence: S) where S.Iterator.Element == Element {
        for element in sequence {
            insert(element)
        }
    }
}

extension LazyMapSortedArray {
    public mutating func insert(_ element: Element, atChecked index: Int) {
        let elementComparator = transform(element)
        if index - 1 >= array.startIndex {
            let precedingValue = array[index - 1]
            let precedingValueComparator = transform(precedingValue)
            guard precedingValueComparator <= elementComparator else {
                preconditionFailure("Cannot insert \(element) in position after \(precedingValue).") 
            }
        }
        if index < array.endIndex {
            let followingValue = array[index]
            let followingValueComparator = transform(followingValue)
            guard elementComparator <= followingValueComparator else {
                preconditionFailure("Cannot insert \(element) in position before \(followingValue).") 
            }
        }
        array.insert(element, at: index)
    }
    
    public mutating func insert(_ element: Element, atUnsafeUnchecked index: Int) {
        #if DEBUG
            // Check during debug mode
            insert(element, atChecked: index)
        #else
            array.insert(element, at: index)
        #endif
    }
}

extension LazyMapSortedArray {
    /// Returns the index where the specified value appears in the specified
    /// position in the collection.
    /// - Complexity: O(log(n)), where n is the length of the array.
    public func index(of element: Element, at position: IndexPosition = .any) -> Int? {
        let potentialIndex = insertionIndex(of: element, for: position)
        let potentialElement = self[potentialIndex]
        let elementComparator = transform(element)
        let potentialElementComparator = transform(potentialElement)
        guard elementComparator == potentialElementComparator else { return nil }
        return potentialIndex
    }
    
    /// Returns a Boolean value indicating whether the sequence contains the given element.
    /// - Complexity: O(log(n)), where n is the length of the array.
    public func contains(element: Element) -> Bool {
        return index(of: element) != nil
    }
}

extension LazyMapSortedArray {
    public mutating func popLast() -> Element? {
        return array.popLast()
    }
    
    public mutating func removeAll(keepingCapacity: Bool = false) {
        array.removeAll(keepingCapacity: keepingCapacity)
    }
    
    public mutating func remove(at index: Int) -> Element {
        return array.remove(at: index)
    }
    
    public mutating func removeFirst() {
        array.removeFirst()
    }
    
    public mutating func removeFirst(n: Int) {
        array.removeFirst(n)
    }
    
    public mutating func removeLast() {
        array.removeLast()
    }
    
    public mutating func removeSubrange(subRange: Range<Int>) {
        array.removeSubrange(subRange)
    }
    
    public mutating func removeSubrange(subRange: ClosedRange<Int>) {
        array.removeSubrange(subRange)
    }
    
    public mutating func removeSubrange(subRange: CountableRange<Int>) {
        array.removeSubrange(subRange)
    }
    
    public mutating func removeSubrange(subRange: CountableClosedRange<Int>) {
        array.removeSubrange(subRange)
    }
    
    public mutating func reserveCapacity(minimumCapacity: Int) {
        array.reserveCapacity(minimumCapacity)
    }
}

extension LazyMapSortedArray {
    /// Replaces element at index with a new element, resorting the array afterwards.
    ///
    /// Note this is more efficient than simply removing and adding since this function
    /// will only shift the elements that actually need to move.
    ///
    /// - Complexity: O(n), where n is the length of the array.
    public mutating func replace(at index: Int, with element: Element) {        
        // Find most efficient position to insert at
        let oldElement = array[index]
        let elementComparator = transform(element)
        let oldElementComparator = transform(oldElement)
        if oldElementComparator < elementComparator {
            let newIndex = insertionIndex(of: element, for: .first, in: (index + 1)..<array.endIndex)
            array[index..<(newIndex - 1)] = array[(index + 1)..<newIndex]
            array[newIndex - 1] = element
        } else if oldElementComparator > elementComparator {
            let newIndex = insertionIndex(of: element, for: .last, in: array.startIndex..<(index + 1))
            array[(newIndex + 1)..<(index + 1)] = array[newIndex..<index]
            array[newIndex] = element
        } else {
            array[index] = element
        }
    }
}

public func ==<Element: Comparable, Comparator: Comparable>(
    lhs: LazyMapSortedArray<Comparator, Element>,
    rhs: LazyMapSortedArray<Comparator, Element>
) -> Bool {
    return lhs.array == rhs.array
}
