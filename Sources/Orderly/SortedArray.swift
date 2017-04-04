extension Sequence where SubSequence: Sequence, SubSequence.Iterator.Element == Iterator.Element, Iterator.Element: Comparable {
    public func isSorted() -> Bool {
        for (lhs, rhs) in zip(self, self.dropFirst()) {
            guard lhs <= rhs else { return false }
        }
        return true
    }
}

public struct SortedArray<Element: Comparable> {
    fileprivate var base: [Element]
}

extension SortedArray {
    /// Constructs a `SortedArray` assuing that `base` is already sorted,
    /// only performing check during testing.
    public init(uncheckedSorted base: [Element]) {
        assert(base.isSorted())
        self.base = base
    }
    
    /// Constructs a `SortedArray` if `base` is verified to be sorted, otherwise returns `nil`.
    public init?(checkingSorted base: [Element]) {
        guard base.isSorted() else { return nil }
        self.base = base
    }
    
    // Constructs a `SortedArray` by sorting `base`.
    public init(sorting base: [Element]) {
        self.base = base.sorted()
    }
    
    public init() {
        self.base = []
    }
}

extension SortedArray: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: Element...) {
        guard elements.isSorted() else { fatalError("`SortedArray` literal must already be sorted.") }
        self.base = elements
    }
}


extension SortedArray: BidirectionalCollection {
    public var indices: CountableRange<Int> {
        return base.indices
    }
    
    public func index(after i: Int) -> Int {
        return base.index(after: i)
    }
    
    public func index(before i: Int) -> Int {
        return base.index(before: i)
    }

    public func index(_ i: Int, offsetBy n: Int) -> Int? {
        return base.index(i, offsetBy: n)
    }
    
    public func index(_ i: Int, offsetBy n: Int, limitedBy limit: Int) -> Int? {
        return base.index(i, offsetBy: n, limitedBy: limit)
    }
    
    public var startIndex: Int {
        return base.startIndex
    }
    
    public var endIndex: Int {
        return base.endIndex
    }
    
    public subscript(index: Int) -> Element {
        return base[index]
    }
}

extension SortedArray {
    public subscript(checked index: Int) -> Element {
        get {
            return self[index]
        }
        set {
            if index - 1 >= base.startIndex {
                let precedingValue = base[index - 1]
                guard precedingValue <= newValue else {
                    preconditionFailure("Cannot assign \(newValue) in position after \(precedingValue).") 
                }
            }
            if index + 1 < base.endIndex {
                let followingValue = base[index + 1]
                guard newValue <= followingValue else {
                    preconditionFailure("Cannot assign \(newValue) in position before \(followingValue).") 
                }
            }
            base[index] = newValue
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
                base[index] = newValue
            #endif
        }
    }
}

extension SortedArray: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        return base.description
    }
    
    public var debugDescription: String {
        return base.debugDescription
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
    
    /// The index at which an element would be inserted into the base.
    public func insertionIndex(of element: Element, for selection: BoundSelection = .any) -> Int {
        return insertionIndex(of: element, for: selection, in: Range(base.indices))
    }
    
    @discardableResult 
    public mutating func insert(_ element: Element, at selection: BoundSelection = .any) -> Int {
        let index = insertionIndex(of: element, for: selection)
        base.insert(element, at: index)
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
            base.insert(element, at: index)
        }
    }
}

extension SortedArray {
    public mutating func insert(_ element: Element, atChecked index: Int) {
        if index - 1 >= base.startIndex {
            let precedingValue = base[index - 1]
            guard precedingValue <= element else {
                preconditionFailure("Cannot insert \(element) in position after \(precedingValue).") 
            }
        }
        if index < base.endIndex {
            let followingValue = base[index]
            guard element <= followingValue else {
                preconditionFailure("Cannot insert \(element) in position before \(followingValue).") 
            }
        }
        base.insert(element, at: index)
    }
    
    public mutating func insert(_ element: Element, atUnsafeUnchecked index: Int) {
        #if DEBUG
            // Check during debug mode
            insert(element, atChecked: index)
        #else
            base.insert(element, at: index)
        #endif
    }
}

extension SortedArray {
    /// Returns the index where the specified value appears in the specified
    /// position in the collection.
    /// - Complexity: O(log(n)), where n is the length of the base.
    public func index(of element: Element, at selection: BoundSelection = .any) -> Int? {
        let potentialIndex = insertionIndex(of: element, for: selection)
        let potentialElement = self[potentialIndex]
        guard element == potentialElement else { return nil }
        return potentialIndex
    }
    
    /// Returns a Boolean value indicating whether the sequence contains the given element.
    /// - Complexity: O(log(n)), where n is the length of the base.
    public func contains(element: Element) -> Bool {
        return index(of: element) != nil
    }
}

extension SortedArray {
    public mutating func popLast() -> Element? {
        return base.popLast()
    }
    
    public mutating func removeAll(keepingCapacity: Bool = false) {
        base.removeAll(keepingCapacity: keepingCapacity)
    }
    
    public mutating func remove(at index: Int) -> Element {
        return base.remove(at: index)
    }
    
    public mutating func removeFirst() {
        base.removeFirst()
    }
    
    public mutating func removeFirst(n: Int) {
        base.removeFirst(n)
    }
    
    public mutating func removeLast() {
        base.removeLast()
    }
    
    public mutating func removeSubrange(subRange: Range<Int>) {
        base.removeSubrange(subRange)
    }
    
    public mutating func removeSubrange(subRange: ClosedRange<Int>) {
        base.removeSubrange(subRange)
    }
    
    public mutating func removeSubrange(subRange: CountableRange<Int>) {
        base.removeSubrange(subRange)
    }
    
    public mutating func removeSubrange(subRange: CountableClosedRange<Int>) {
        base.removeSubrange(subRange)
    }
    
    public mutating func reserveCapacity(minimumCapacity: Int) {
        base.reserveCapacity(minimumCapacity)
    }
}

// Avoid doing unnecessary work
extension SortedArray {
    public func sorted() -> [Element] {
            return base
    }

    public func sorted() -> SortedArray<Element> {
            return self
    }

    public func isSorted() -> Bool {
        return true
    }
}

extension SortedArray {
    /// Returns the maximum element of the base.
    /// - Complexity: O(1)
    @warn_unqualified_access public func max() -> Element? {
        return last
    }
    
    /// Returns the minimum element of the base.
    /// - Complexity: O(1)
    @warn_unqualified_access public func min() -> Element? {
        return first
    }
}

extension SortedArray {
    /// Replaces element at index with a new element, resorting the base afterwards.
    ///
    /// Note this is more efficient than simply removing and adding since this function
    /// will only shift the elements that actually need to move.
    ///
    /// - Complexity: O(n), where n is the length of the base.
    public mutating func replace(at index: Int, with element: Element) {        
        // Find most efficient position to insert at
        let oldElement = base[index]
        if oldElement < element {
            let newIndex = insertionIndex(of: element, for: .least, in: (index + 1)..<base.endIndex)
            base[index..<(newIndex - 1)] = base[(index + 1)..<newIndex]
            base[newIndex - 1] = element
        } else if oldElement > element {
            let newIndex = insertionIndex(of: element, for: .greatest, in: base.startIndex..<(index + 1))
            base[(newIndex + 1)..<(index + 1)] = base[newIndex..<index]
            base[newIndex] = element
        } else {
            base[index] = element
        }
    }
}

public func ==<Element: Comparable>(
    lhs: SortedArray<Element>,
    rhs: SortedArray<Element>
) -> Bool {
    return lhs.base == rhs.base
}
