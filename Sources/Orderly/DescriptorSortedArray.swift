extension Sequence where SubSequence: Sequence, SubSequence.Iterator.Element == Iterator.Element {
    public func isSorted(by areIncreasingInOrdering: @escaping (Iterator.Element, Iterator.Element) -> Bool) -> Bool {
        for (lhs, rhs) in zip(self, self.dropFirst()) {
            guard !areIncreasingInOrdering(rhs, lhs) else { return false }
        }
        return true
    }
}

public struct DescriptorSortedArray<Element> {
    fileprivate var array: [Element]
    fileprivate let areIncreasingInOrdering: (Element, Element) -> Bool
}

extension DescriptorSortedArray {
    /// Constructs a `DescriptorSortedArray` assuing that `array` is already sorted,
    /// only performing check during testing.
    public init(uncheckedSorted array: [Element], by areIncreasingInOrdering: @escaping (Element, Element) -> Bool) {
        assert(array.isSorted(by: areIncreasingInOrdering))
        self.array = array
        self.areIncreasingInOrdering = areIncreasingInOrdering
    }
    
    /// Constructs a `DescriptorSortedArray` if `array` is verified to be sorted, otherwise returns `nil`.
    public init?(checkingSorted array: [Element], by areIncreasingInOrdering: @escaping (Element, Element) -> Bool) {
        guard array.isSorted(by: areIncreasingInOrdering) else { return nil }
        self.array = array
        self.areIncreasingInOrdering = areIncreasingInOrdering
    }
    
    // Constructs a `DescriptorSortedArray` by sorting `array`.
    public init(sorting array: [Element], by areIncreasingInOrdering: @escaping (Element, Element) -> Bool) {
        self.array = array.sorted(by: areIncreasingInOrdering)
        self.areIncreasingInOrdering = areIncreasingInOrdering
    }
    
    public init(by areIncreasingInOrdering: @escaping (Element, Element) -> Bool) {
        self.array = []
        self.areIncreasingInOrdering = areIncreasingInOrdering
    }
}

extension Array {
    public init(_ sortedArray: DescriptorSortedArray<Element>) {
        self = sortedArray.array
    }
}

extension DescriptorSortedArray: BidirectionalCollection {
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

extension DescriptorSortedArray {
    public subscript(checked index: Int) -> Element {
        get {
            return self[index]
        }
        set {
            if index - 1 >= array.startIndex {
                let precedingValue = array[index - 1]
                guard !areIncreasingInOrdering(newValue, precedingValue) else {
                    preconditionFailure("Cannot assign \(newValue) in position after \(precedingValue).") 
                }
            }
            if index + 1 < array.endIndex {
                let followingValue = array[index + 1]
                guard !areIncreasingInOrdering(followingValue, newValue) else {
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

extension DescriptorSortedArray: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        return array.description
    }
    
    public var debugDescription: String {
        return array.debugDescription
    }
}

extension DescriptorSortedArray {
    
    public func insertionIndex(of element: Element, for selection: BoundSelection = .any,
                               in range: Range<Int>) -> Int {
        var (min, max) = (range.lowerBound, range.upperBound)
        while min < max {
            let mid = (max - min) / 2 + min
            let midElement = self[mid]
            
            if areIncreasingInOrdering(midElement, element) {
                min = mid + 1
            } else if areIncreasingInOrdering(element, midElement) {
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

extension DescriptorSortedArray {
    public mutating func insert<S: Sequence>(contentsOf sequence: S) where S.Iterator.Element == Element {
        for element in sequence {
            insert(element)
        }
    }
}

extension DescriptorSortedArray {
    public mutating func insert(_ element: Element, atChecked index: Int) {
        if index - 1 >= array.startIndex {
            let precedingValue = array[index - 1]
            guard !areIncreasingInOrdering(element, precedingValue) else {
                preconditionFailure("Cannot insert \(element) in position after \(precedingValue).") 
            }
        }
        if index < array.endIndex {
            let followingValue = array[index]
            guard !areIncreasingInOrdering(followingValue, element) else {
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

extension DescriptorSortedArray {
    /// Returns the index where the specified value appears in the specified
    /// position in the collection.
    /// - Complexity: O(log(n)), where n is the length of the array.
    public func index(of element: Element, at selection: BoundSelection = .any) -> Int? {
        let potentialIndex = insertionIndex(of: element, for: selection)
        let potentialElement = self[potentialIndex]
        guard !areIncreasingInOrdering(element, potentialElement) && !areIncreasingInOrdering(potentialElement, element) else { return nil }
        return potentialIndex
    }
    
    /// Returns a Boolean value indicating whether the sequence contains the given element.
    /// - Complexity: O(log(n)), where n is the length of the array.
    public func contains(element: Element) -> Bool {
        return index(of: element) != nil
    }
}

extension DescriptorSortedArray {
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

extension DescriptorSortedArray {
    /// Replaces element at index with a new element, resorting the array afterwards.
    ///
    /// Note this is more efficient than simply removing and adding since this function
    /// will only shift the elements that actually need to move.
    ///
    /// - Complexity: O(n), where n is the length of the array.
    public mutating func replace(at index: Int, with element: Element) {        
        // Find most efficient position to insert at
        let oldElement = array[index]
        if areIncreasingInOrdering(oldElement, element) {
            let newIndex = insertionIndex(of: element, for: .least, in: (index + 1)..<array.endIndex)
            array[index..<(newIndex - 1)] = array[(index + 1)..<newIndex]
            array[newIndex - 1] = element
        } else if areIncreasingInOrdering(element, oldElement) {
            let newIndex = insertionIndex(of: element, for: .greatest, in: array.startIndex..<(index + 1))
            array[(newIndex + 1)..<(index + 1)] = array[newIndex..<index]
            array[newIndex] = element
        } else {
            array[index] = element
        }
    }
}

public func ==<Element: Comparable>(
    lhs: DescriptorSortedArray<Element>,
    rhs: DescriptorSortedArray<Element>
) -> Bool {
    return lhs.array == rhs.array
}
