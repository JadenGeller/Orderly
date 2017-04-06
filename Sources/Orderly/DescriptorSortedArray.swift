extension Sequence where SubSequence: Sequence, SubSequence.Iterator.Element == Iterator.Element {
    public func isSorted(by areIncreasingInOrdering: @escaping (Iterator.Element, Iterator.Element) -> Bool) -> Bool {
        for (lhs, rhs) in zip(self, self.dropFirst()) {
            guard !areIncreasingInOrdering(rhs, lhs) else { return false }
        }
        return true
    }
}

public struct DescriptorSortedArray<Element> {
    fileprivate var base: [Element]
    fileprivate let areIncreasingInOrdering: (Element, Element) -> Bool
}

extension DescriptorSortedArray {
    /// Constructs a `DescriptorSortedArray` assuing that `base` is already sorted,
    /// only performing check during testing.
    public init(uncheckedSorted base: [Element], by areIncreasingInOrdering: @escaping (Element, Element) -> Bool) {
        assert(base.isSorted(by: areIncreasingInOrdering))
        self.base = base
        self.areIncreasingInOrdering = areIncreasingInOrdering
    }
    
    /// Constructs a `DescriptorSortedArray` if `base` is verified to be sorted, otherwise returns `nil`.
    public init?(checkingSorted base: [Element], by areIncreasingInOrdering: @escaping (Element, Element) -> Bool) {
        guard base.isSorted(by: areIncreasingInOrdering) else { return nil }
        self.base = base
        self.areIncreasingInOrdering = areIncreasingInOrdering
    }
    
    // Constructs a `DescriptorSortedArray` by sorting `base`.
    public init(sorting base: [Element], by areIncreasingInOrdering: @escaping (Element, Element) -> Bool) {
        self.base = base.sorted(by: areIncreasingInOrdering)
        self.areIncreasingInOrdering = areIncreasingInOrdering
    }
    
    public init(by areIncreasingInOrdering: @escaping (Element, Element) -> Bool) {
        self.base = []
        self.areIncreasingInOrdering = areIncreasingInOrdering
    }
}

extension Sequence {
    func sorted(by areIncreasingInOrdering: @escaping (Iterator.Element, Iterator.Element) -> Bool) -> DescriptorSortedArray<Iterator.Element> {
        return DescriptorSortedArray(sorting: Array(self), by: areIncreasingInOrdering)
    }
}

extension DescriptorSortedArray: BidirectionalCollection {
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
    
    public subscript(_ index: Int) -> Element {
        get {
            return base[index]
        }
        set {
            if index - 1 >= base.startIndex {
                let precedingValue = base[index - 1]
                guard !areIncreasingInOrdering(newValue, precedingValue) else {
                    preconditionFailure("Cannot assign \(newValue) in position after \(precedingValue).") 
                }
            }
            if index + 1 < base.endIndex {
                let followingValue = base[index + 1]
                guard !areIncreasingInOrdering(followingValue, newValue) else {
                    preconditionFailure("Cannot assign \(newValue) in position before \(followingValue).") 
                }
            }
            base[index] = newValue
        }
    }
    
    public subscript(_ range: Range<Int>) -> DescriptorSortedArraySlice<Element> {
        get {
                return DescriptorSortedArraySlice(base: base[range], areIncreasingInOrdering: areIncreasingInOrdering)
        }
        set {
            if range.lowerBound - 1 >= base.startIndex, let firstNewValue = newValue.first {
                let precedingValue = base[range.lowerBound - 1]
                guard !areIncreasingInOrdering(firstNewValue, precedingValue) else {
                    preconditionFailure("Cannot assign \(firstNewValue) in position after \(precedingValue).") 
                }
            }
            if range.upperBound < base.endIndex, let lastNewValue = newValue.last {
                let followingValue = base[range.upperBound]
                guard !areIncreasingInOrdering(followingValue, lastNewValue) else {
                    preconditionFailure("Cannot assign \(lastNewValue) in position before \(followingValue).") 
                }
            }
            base[range] = newValue.base
        }
    }
}

extension DescriptorSortedArray: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        return base.description
    }
    
    public var debugDescription: String {
        return base.debugDescription
    }
}

extension DescriptorSortedArray {
    public func insertionIndex(of element: Element, for selection: BoundSelection = .any) -> Int {
        var (lowerBound, upperBound) = (startIndex, endIndex)
        while lowerBound < upperBound {
            let middleBound = (upperBound - lowerBound) / 2 + lowerBound
            let middleElement = self[middleBound]
            
            if areIncreasingInOrdering(middleElement, element) {
                lowerBound = middleBound + 1
            } else if areIncreasingInOrdering(element, middleElement) {
                upperBound = middleBound
            } else {
                switch selection {
                    case .least:    upperBound = middleBound
                    case .greatest: lowerBound = middleBound + 1
                    case .any:      return middleBound
                }
            }
        }
        assert(lowerBound == upperBound)
        return lowerBound
    }
    
    @discardableResult 
    public mutating func insert(_ element: Element, at selection: BoundSelection = .any) -> Int {
        let index = insertionIndex(of: element, for: selection)
        base.insert(element, at: index)
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
    public mutating func insert(_ element: Element, at index: Int) {
        if index - 1 >= base.startIndex {
            let precedingValue = base[index - 1]
            guard !areIncreasingInOrdering(element, precedingValue) else {
                preconditionFailure("Cannot insert \(element) in position after \(precedingValue).") 
            }
        }
        if index < base.endIndex {
            let followingValue = base[index]
            guard !areIncreasingInOrdering(followingValue, element) else {
                preconditionFailure("Cannot insert \(element) in position before \(followingValue).") 
            }
        }
        base.insert(element, at: index)
    }
    
    public mutating func append(_ element: Element) {
        guard let lastValue = base.last else {
            // Currently empty
            base.append(element)
            return
        }
        guard !areIncreasingInOrdering(element, lastValue) else {
            preconditionFailure("Cannot append \(element) after \(lastValue).") 
        }
        base.append(element)
    }
}

extension DescriptorSortedArray {
    /// Returns the index where the specified value appears in the specified
    /// position in the collection.
    /// - Complexity: O(log(n)), where n is the length of the base.
    public func index(of element: Element, at selection: BoundSelection = .any) -> Int? {
        let potentialIndex = insertionIndex(of: element, for: selection)
        let potentialElement = self[potentialIndex]
        guard !areIncreasingInOrdering(element, potentialElement) && !areIncreasingInOrdering(potentialElement, element) else { return nil }
        return potentialIndex
    }
    
    /// Returns a Boolean value indicating whether the sequence contains the given element.
    /// - Complexity: O(log(n)), where n is the length of the base.
    public func contains(element: Element) -> Bool {
        return index(of: element) != nil
    }
}

extension DescriptorSortedArray {
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

extension DescriptorSortedArray {
    /// Replaces element at index with a new element, resorting the base afterwards.
    ///
    /// Note this is more efficient than simply removing and adding since this function
    /// will only shift the elements that actually need to move.
    ///
    /// - Complexity: O(n), where n is the length of the base.
    public mutating func replace(at index: Int, with element: Element) {        
        // Find most efficient position to insert at
        let oldElement = base[index]
        if areIncreasingInOrdering(oldElement, element) {
            let newIndex = self[(index + 1)..<base.endIndex].insertionIndex(of: element, for: .least)
            base[index..<(newIndex - 1)] = base[(index + 1)..<newIndex]
            base[newIndex - 1] = element
        } else if areIncreasingInOrdering(element, oldElement) {
            let newIndex = self[base.startIndex..<(index + 1)].insertionIndex(of: element, for: .greatest)
            base[(newIndex + 1)..<(index + 1)] = base[newIndex..<index]
            base[newIndex] = element
        } else {
            base[index] = element
        }
    }
}

public func ==<Element: Comparable>(
    lhs: DescriptorSortedArray<Element>,
    rhs: DescriptorSortedArray<Element>
) -> Bool {
    return lhs.base == rhs.base
}

public struct DescriptorSortedArraySlice<Element> {
    fileprivate var base: ArraySlice<Element>
    fileprivate let areIncreasingInOrdering: (Element, Element) -> Bool
}

extension DescriptorSortedArraySlice {
    /// Constructs a `DescriptorSortedArraySlice` assuing that `base` is already sorted,
    /// only performing check during testing.
    public init(uncheckedSorted base: ArraySlice<Element>, by areIncreasingInOrdering: @escaping (Element, Element) -> Bool) {
        assert(base.isSorted(by: areIncreasingInOrdering))
        self.base = base
        self.areIncreasingInOrdering = areIncreasingInOrdering
    }
    
    /// Constructs a `DescriptorSortedArraySlice` if `base` is verified to be sorted, otherwise returns `nil`.
    public init?(checkingSorted base: ArraySlice<Element>, by areIncreasingInOrdering: @escaping (Element, Element) -> Bool) {
        guard base.isSorted(by: areIncreasingInOrdering) else { return nil }
        self.base = base
        self.areIncreasingInOrdering = areIncreasingInOrdering
    }
    
    // Constructs a `DescriptorSortedArraySlice` by sorting `base`.
    public init(sorting base: ArraySlice<Element>, by areIncreasingInOrdering: @escaping (Element, Element) -> Bool) {
        let sorted = base.sorted(by: areIncreasingInOrdering)
        self.base = sorted[sorted.indices]
        self.areIncreasingInOrdering = areIncreasingInOrdering
    }
    
    public init(by areIncreasingInOrdering: @escaping (Element, Element) -> Bool) {
        self.base = []
        self.areIncreasingInOrdering = areIncreasingInOrdering
    }
}

extension DescriptorSortedArraySlice: BidirectionalCollection {
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
    
    public subscript(_ index: Int) -> Element {
        get {
            return base[index]
        }
        set {
            if index - 1 >= base.startIndex {
                let precedingValue = base[index - 1]
                guard !areIncreasingInOrdering(newValue, precedingValue) else {
                    preconditionFailure("Cannot assign \(newValue) in position after \(precedingValue).") 
                }
            }
            if index + 1 < base.endIndex {
                let followingValue = base[index + 1]
                guard !areIncreasingInOrdering(followingValue, newValue) else {
                    preconditionFailure("Cannot assign \(newValue) in position before \(followingValue).") 
                }
            }
            base[index] = newValue
        }
    }
    
    public subscript(_ range: Range<Int>) -> DescriptorSortedArraySlice<Element> {
        get {
                return DescriptorSortedArraySlice(base: base[range], areIncreasingInOrdering: areIncreasingInOrdering)
        }
        set {
            if range.lowerBound - 1 >= base.startIndex, let firstNewValue = newValue.first {
                let precedingValue = base[range.lowerBound - 1]
                guard !areIncreasingInOrdering(firstNewValue, precedingValue) else {
                    preconditionFailure("Cannot assign \(firstNewValue) in position after \(precedingValue).") 
                }
            }
            if range.upperBound < base.endIndex, let lastNewValue = newValue.last {
                let followingValue = base[range.upperBound]
                guard !areIncreasingInOrdering(followingValue, lastNewValue) else {
                    preconditionFailure("Cannot assign \(lastNewValue) in position before \(followingValue).") 
                }
            }
            base[range] = newValue.base
        }
    }
}

extension DescriptorSortedArraySlice: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        return base.description
    }
    
    public var debugDescription: String {
        return base.debugDescription
    }
}

extension DescriptorSortedArraySlice {
    public func insertionIndex(of element: Element, for selection: BoundSelection = .any) -> Int {
        var (lowerBound, upperBound) = (startIndex, endIndex)
        while lowerBound < upperBound {
            let middleBound = (upperBound - lowerBound) / 2 + lowerBound
            let middleElement = self[middleBound]
            
            if areIncreasingInOrdering(middleElement, element) {
                lowerBound = middleBound + 1
            } else if areIncreasingInOrdering(element, middleElement) {
                upperBound = middleBound
            } else {
                switch selection {
                    case .least:    upperBound = middleBound
                    case .greatest: lowerBound = middleBound + 1
                    case .any:      return middleBound
                }
            }
        }
        assert(lowerBound == upperBound)
        return lowerBound
    }
    
    @discardableResult 
    public mutating func insert(_ element: Element, at selection: BoundSelection = .any) -> Int {
        let index = insertionIndex(of: element, for: selection)
        base.insert(element, at: index)
        return index
    }
}

extension DescriptorSortedArraySlice {
    public mutating func insert<S: Sequence>(contentsOf sequence: S) where S.Iterator.Element == Element {
        for element in sequence {
            insert(element)
        }
    }
}

extension DescriptorSortedArraySlice {
    public mutating func insert(_ element: Element, at index: Int) {
        if index - 1 >= base.startIndex {
            let precedingValue = base[index - 1]
            guard !areIncreasingInOrdering(element, precedingValue) else {
                preconditionFailure("Cannot insert \(element) in position after \(precedingValue).") 
            }
        }
        if index < base.endIndex {
            let followingValue = base[index]
            guard !areIncreasingInOrdering(followingValue, element) else {
                preconditionFailure("Cannot insert \(element) in position before \(followingValue).") 
            }
        }
        base.insert(element, at: index)
    }
    
    public mutating func append(_ element: Element) {
        guard let lastValue = base.last else {
            // Currently empty
            base.append(element)
            return
        }
        guard !areIncreasingInOrdering(element, lastValue) else {
            preconditionFailure("Cannot append \(element) after \(lastValue).") 
        }
        base.append(element)
    }
}

extension DescriptorSortedArraySlice {
    /// Returns the index where the specified value appears in the specified
    /// position in the collection.
    /// - Complexity: O(log(n)), where n is the length of the base.
    public func index(of element: Element, at selection: BoundSelection = .any) -> Int? {
        let potentialIndex = insertionIndex(of: element, for: selection)
        let potentialElement = self[potentialIndex]
        guard !areIncreasingInOrdering(element, potentialElement) && !areIncreasingInOrdering(potentialElement, element) else { return nil }
        return potentialIndex
    }
    
    /// Returns a Boolean value indicating whether the sequence contains the given element.
    /// - Complexity: O(log(n)), where n is the length of the base.
    public func contains(element: Element) -> Bool {
        return index(of: element) != nil
    }
}

extension DescriptorSortedArraySlice {
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

extension DescriptorSortedArraySlice {
    /// Replaces element at index with a new element, resorting the base afterwards.
    ///
    /// Note this is more efficient than simply removing and adding since this function
    /// will only shift the elements that actually need to move.
    ///
    /// - Complexity: O(n), where n is the length of the base.
    public mutating func replace(at index: Int, with element: Element) {        
        // Find most efficient position to insert at
        let oldElement = base[index]
        if areIncreasingInOrdering(oldElement, element) {
            let newIndex = self[(index + 1)..<base.endIndex].insertionIndex(of: element, for: .least)
            base[index..<(newIndex - 1)] = base[(index + 1)..<newIndex]
            base[newIndex - 1] = element
        } else if areIncreasingInOrdering(element, oldElement) {
            let newIndex = self[base.startIndex..<(index + 1)].insertionIndex(of: element, for: .greatest)
            base[(newIndex + 1)..<(index + 1)] = base[newIndex..<index]
            base[newIndex] = element
        } else {
            base[index] = element
        }
    }
}

public func ==<Element: Comparable>(
    lhs: DescriptorSortedArraySlice<Element>,
    rhs: DescriptorSortedArraySlice<Element>
) -> Bool {
    return lhs.base == rhs.base
}
