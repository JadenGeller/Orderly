extension Sequence where SubSequence: Sequence, SubSequence.Iterator.Element == Iterator.Element, Iterator.Element: Comparable {
    public func isSorted() -> Bool {
        for (lhs, rhs) in zip(self, self.dropFirst()) {
            guard lhs <= rhs else { return false }
        }
        return true
    }
}

public struct SortedArray<Element: Comparable> {
    fileprivate var array: [Element]
}

extension SortedArray {
    /// Constructs a `SortedArray` assuing that `array` is already sorted,
    /// only performing check during testing.
    public init(unsafeUncheckedFromSorted array: [Element]) {
        assert(array.isSorted())
        self.array = array
    }
    
    /// Constructs a `SortedArray` if `array` is verified to be sorted, otherwise returns `nil`.
    public init?(fromSorted array: [Element]) {
        guard array.isSorted() else { return nil }
        self.array = array
    }
    
    // Constructs a `SortedArray` by sorting `array`.
    public init(fromUnsorted array: [Element]) {
        self.array = array.sorted()
    }
    
    public init() {
        self.array = []
    }
}

extension SortedArray: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: Element...) {
        guard elements.isSorted() else { fatalError("`SortedArray` literal must already be sorted.") }
        self.array = elements
    }
}

extension Array where Element: Comparable {
    public init(_ sortedArray: SortedArray<Element>) {
        self = sortedArray.array
    }
}

extension SortedArray: BidirectionalCollection {
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

extension SortedArray {
    public subscript(checked index: Int) -> Element {
        get {
            return self[index]
        }
        set {
            if index - 1 >= array.startIndex {
                let precedingValue = array[index - 1]
                guard precedingValue <= newValue else {
                    preconditionFailure("Cannot assign \(newValue) in position after \(precedingValue).") 
                }
            }
            if index + 1 < array.endIndex {
                let followingValue = array[index + 1]
                guard newValue <= followingValue else {
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

extension SortedArray: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        return array.description
    }
    
    public var debugDescription: String {
        return array.debugDescription
    }
}

extension SortedArray {
    
    public func insertionIndex(of element: Element, for selection: BoundSelection = .any,
                               in range: Range<Int>) -> Int {
        var (min, max) = (range.lowerBound, range.upperBound)
        while min < max {
            let mid = (max - min) / 2 + min
            let midElement = self[mid]
            
            if midElement < element {
                min = mid + 1
            } else if midElement > element {
                max = mid
            } else {
                switch selection {
                    case .least: max = mid
                    case .greatest:  min = mid + 1
                    case .any:   return mid
                }
            }
        }
        assert(min == max)
        return min
    }
    
    /// The index at which an element would be inserted into the array.
    public func insertionIndex(of element: Element, for selection: BoundSelection = .any) -> Int {
        return insertionIndex(of: element, for: selection, in: Range(array.indices))
    }
    
    @discardableResult 
    public mutating func insert(_ element: Element, at selection: BoundSelection = .any) -> Int {
        let index = insertionIndex(of: element, for: selection)
        array.insert(element, at: index)
        return index
    }
}

extension SortedArray {
    public mutating func insert<S: Sequence>(contentsOf sequence: S) where S.Iterator.Element == Element {
        for element in sequence {
            insert(element)
        }
    }
    
    public mutating func insert(contentsOf sortedArray: SortedArray, at selection: BoundSelection = .any) {
        var index = startIndex
        for element in sortedArray {
            index = insertionIndex(of: element, for: selection, in: index..<endIndex)
            array.insert(element, at: index)
        }
    }
}

extension SortedArray {
    public mutating func insert(_ element: Element, atChecked index: Int) {
        if index - 1 >= array.startIndex {
            let precedingValue = array[index - 1]
            guard precedingValue <= element else {
                preconditionFailure("Cannot insert \(element) in position after \(precedingValue).") 
            }
        }
        if index < array.endIndex {
            let followingValue = array[index]
            guard element <= followingValue else {
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

extension SortedArray {
    /// Returns the index where the specified value appears in the specified
    /// position in the collection.
    /// - Complexity: O(log(n)), where n is the length of the array.
    public func index(of element: Element, at selection: BoundSelection = .any) -> Int? {
        let potentialIndex = insertionIndex(of: element, for: selection)
        let potentialElement = self[potentialIndex]
        guard element == potentialElement else { return nil }
        return potentialIndex
    }
    
    /// Returns a Boolean value indicating whether the sequence contains the given element.
    /// - Complexity: O(log(n)), where n is the length of the array.
    public func contains(element: Element) -> Bool {
        return index(of: element) != nil
    }
}

extension SortedArray {
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

// Avoid doing unnecessary work
extension SortedArray {
    public func sorted() -> [Element] {
        return array
    }

    public func sorted() -> SortedArray<Element> {
        return self
    }

    public func isSorted() -> Bool {
        return true
    }
}

extension SortedArray {
    /// Returns the maximum element of the array.
    /// - Complexity: O(1)
    @warn_unqualified_access public func max() -> Element? {
        return last
    }
    
    /// Returns the minimum element of the array.
    /// - Complexity: O(1)
    @warn_unqualified_access public func min() -> Element? {
        return first
    }
}

extension SortedArray {
    /// Replaces element at index with a new element, resorting the array afterwards.
    ///
    /// Note this is more efficient than simply removing and adding since this function
    /// will only shift the elements that actually need to move.
    ///
    /// - Complexity: O(n), where n is the length of the array.
    public mutating func replace(at index: Int, with element: Element) {        
        // Find most efficient position to insert at
        let oldElement = array[index]
        if oldElement < element {
            let newIndex = insertionIndex(of: element, for: .least, in: (index + 1)..<array.endIndex)
            array[index..<(newIndex - 1)] = array[(index + 1)..<newIndex]
            array[newIndex - 1] = element
        } else if oldElement > element {
            let newIndex = insertionIndex(of: element, for: .greatest, in: array.startIndex..<(index + 1))
            array[(newIndex + 1)..<(index + 1)] = array[newIndex..<index]
            array[newIndex] = element
        } else {
            array[index] = element
        }
    }
}

public func ==<Element: Comparable>(
    lhs: SortedArray<Element>,
    rhs: SortedArray<Element>
) -> Bool {
    return lhs.array == rhs.array
}
