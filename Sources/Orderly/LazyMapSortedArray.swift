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
    fileprivate var base: [Element]
    fileprivate var transform: (Element) -> Comparator
}

extension LazyMapSortedArray {
    /// Constructs a `LazyMapSortedArray` assuing that `base` is already sorted,
    /// only performing check during testing.
    public init(uncheckedSorted base: [Element], on transform: @escaping (Element) -> Comparator) {
        assert(base.isSorted(on: transform))
        self.base = base
        self.transform = transform
    }
    
    /// Constructs a `LazyMapSortedArray` if `base` is verified to be sorted, otherwise returns `nil`.
    public init?(checkingSorted base: [Element], on transform: @escaping (Element) -> Comparator) {
        guard base.isSorted(on: transform) else { return nil }
        self.base = base
        self.transform = transform
    }
    
    // Constructs a `LazyMapSortedArray` by sorting `base`.
    public init(sorting base: [Element], on transform: @escaping (Element) -> Comparator) {
        self.base = base.sorted(on: transform)
        self.transform = transform
    }
    
    public init(on transform: @escaping (Element) -> Comparator) {
        self.base = []
        self.transform = transform
    }
}


extension LazyMapSortedArray: BidirectionalCollection {
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
            return self[index]
        }
        set {
            let newValueComparator = transform(newValue)
            if index - 1 >= base.startIndex {
                let precedingValue = base[index - 1]
                let precedingValueComparator = transform(precedingValue)
                guard precedingValueComparator <= newValueComparator else {
                    preconditionFailure("Cannot assign \(newValue) in position after \(precedingValue).") 
                }
            }
            if index + 1 < base.endIndex {
                let followingValue = base[index + 1]
                let followingValueComparator = transform(followingValue)
                guard newValueComparator <= followingValueComparator else {
                    preconditionFailure("Cannot assign \(newValue) in position before \(followingValue).") 
                }
            }
            base[index] = newValue
        }
    }
    
    public subscript(_ range: Range<Int>) -> LazyMapSortedArraySlice<Element, Comparator> {
        get {
                return LazyMapSortedArraySlice(base: base[range], transform: transform)
        }
        set {
            if range.lowerBound - 1 >= base.startIndex, let firstNewValue = newValue.first {
                let precedingValue = base[range.lowerBound - 1]
                let precedingValueComparator = transform(precedingValue)
                let firstNewValueComparator = transform(firstNewValue)
                guard precedingValueComparator <= firstNewValueComparator else {
                    preconditionFailure("Cannot assign \(firstNewValue) in position after \(precedingValue).") 
                }
            }
            if range.upperBound < base.endIndex, let lastNewValue = newValue.last {
                let followingValue = base[range.upperBound]
                let followingValueComparator = transform(followingValue)
                let lastNewValueComparator = transform(lastNewValue)
                guard lastNewValueComparator <= followingValueComparator else {
                    preconditionFailure("Cannot assign \(lastNewValue) in position before \(followingValue).") 
                }
            }
            base[range] = newValue.base
        }
    }
}

extension LazyMapSortedArray: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        return base.description
    }
    
    public var debugDescription: String {
        return base.debugDescription
    }
}

extension LazyMapSortedArray {
    public func insertionIndex(of element: Element, for selection: BoundSelection = .any) -> Int {
        return insertionIndex(ofComparator: transform(element), for: selection)
    }
    
    public func insertionIndex(ofComparator elementComparator: Comparator, for selection: BoundSelection = .any) -> Int {
        var (lowerBound, upperBound) = (startIndex, endIndex)
        while lowerBound < upperBound {
            let middleBound = (upperBound - lowerBound) / 2 + lowerBound
            let middleElement = self[middleBound]
            let middleElementComparator = transform(middleElement)
            
            if middleElementComparator < elementComparator {
                lowerBound = middleBound + 1
            } else if middleElementComparator > elementComparator {
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
        if index - 1 >= base.startIndex {
            let precedingValue = base[index - 1]
            let precedingValueComparator = transform(precedingValue)
            guard precedingValueComparator <= elementComparator else {
                preconditionFailure("Cannot insert \(element) in position after \(precedingValue).") 
            }
        }
        if index < base.endIndex {
            let followingValue = base[index]
            let followingValueComparator = transform(followingValue)
            guard elementComparator <= followingValueComparator else {
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

extension LazyMapSortedArray {
    /// Returns the index where the specified value appears in the specified
    /// position in the collection.
    /// - Complexity: O(log(n)), where n is the length of the base.
    public func index(of element: Element, at selection: BoundSelection = .any) -> Int? {
        let potentialIndex = insertionIndex(of: element, for: selection)
        let potentialElement = self[potentialIndex]
        let elementComparator = transform(element)
        let potentialElementComparator = transform(potentialElement)
        guard elementComparator == potentialElementComparator else { return nil }
        return potentialIndex
    }
    
    /// Returns a Boolean value indicating whether the sequence contains the given element.
    /// - Complexity: O(log(n)), where n is the length of the base.
    public func contains(element: Element) -> Bool {
        return index(of: element) != nil
    }
}

extension LazyMapSortedArray {
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

extension LazyMapSortedArray {
    /// Replaces element at index with a new element, resorting the base afterwards.
    ///
    /// Note this is more efficient than simply removing and adding since this function
    /// will only shift the elements that actually need to move.
    ///
    /// - Complexity: O(n), where n is the length of the base.
    public mutating func replace(at index: Int, with element: Element) {        
        // Find most efficient position to insert at
        let oldElement = base[index]
        let elementComparator = transform(element)
        let oldElementComparator = transform(oldElement)
        if oldElementComparator < elementComparator {
            let newIndex = self[(index + 1)..<base.endIndex].insertionIndex(of: element, for: .least)
            base[index..<(newIndex - 1)] = base[(index + 1)..<newIndex]
            base[newIndex - 1] = element
        } else if oldElementComparator > elementComparator {
            let newIndex = self[base.startIndex..<(index + 1)].insertionIndex(of: element, for: .greatest)
            base[(newIndex + 1)..<(index + 1)] = base[newIndex..<index]
            base[newIndex] = element
        } else {
            base[index] = element
        }
    }
}

public func ==<Element: Comparable, Comparator: Comparable>(
    lhs: LazyMapSortedArray<Element, Comparator>,
    rhs: LazyMapSortedArray<Element, Comparator>
) -> Bool {
    return lhs.base == rhs.base
}

public struct LazyMapSortedArraySlice<Element, Comparator: Comparable> {
    fileprivate var base: ArraySlice<Element>
    fileprivate var transform: (Element) -> Comparator
}

extension LazyMapSortedArraySlice {
    /// Constructs a `LazyMapSortedArraySlice` assuing that `base` is already sorted,
    /// only performing check during testing.
    public init(uncheckedSorted base: ArraySlice<Element>, on transform: @escaping (Element) -> Comparator) {
        assert(base.isSorted(on: transform))
        self.base = base
        self.transform = transform
    }
    
    /// Constructs a `LazyMapSortedArraySlice` if `base` is verified to be sorted, otherwise returns `nil`.
    public init?(checkingSorted base: ArraySlice<Element>, on transform: @escaping (Element) -> Comparator) {
        guard base.isSorted(on: transform) else { return nil }
        self.base = base
        self.transform = transform
    }
    
    // Constructs a `LazyMapSortedArraySlice` by sorting `base`.
    public init(sorting base: ArraySlice<Element>, on transform: @escaping (Element) -> Comparator) {
        let sorted = base.sorted(on: transform)
        self.base = sorted[sorted.indices]
        self.transform = transform
    }
    
    public init(on transform: @escaping (Element) -> Comparator) {
        self.base = []
        self.transform = transform
    }
}


extension LazyMapSortedArraySlice: BidirectionalCollection {
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
            return self[index]
        }
        set {
            let newValueComparator = transform(newValue)
            if index - 1 >= base.startIndex {
                let precedingValue = base[index - 1]
                let precedingValueComparator = transform(precedingValue)
                guard precedingValueComparator <= newValueComparator else {
                    preconditionFailure("Cannot assign \(newValue) in position after \(precedingValue).") 
                }
            }
            if index + 1 < base.endIndex {
                let followingValue = base[index + 1]
                let followingValueComparator = transform(followingValue)
                guard newValueComparator <= followingValueComparator else {
                    preconditionFailure("Cannot assign \(newValue) in position before \(followingValue).") 
                }
            }
            base[index] = newValue
        }
    }
    
    public subscript(_ range: Range<Int>) -> LazyMapSortedArraySlice<Element, Comparator> {
        get {
                return LazyMapSortedArraySlice(base: base[range], transform: transform)
        }
        set {
            if range.lowerBound - 1 >= base.startIndex, let firstNewValue = newValue.first {
                let precedingValue = base[range.lowerBound - 1]
                let precedingValueComparator = transform(precedingValue)
                let firstNewValueComparator = transform(firstNewValue)
                guard precedingValueComparator <= firstNewValueComparator else {
                    preconditionFailure("Cannot assign \(firstNewValue) in position after \(precedingValue).") 
                }
            }
            if range.upperBound < base.endIndex, let lastNewValue = newValue.last {
                let followingValue = base[range.upperBound]
                let followingValueComparator = transform(followingValue)
                let lastNewValueComparator = transform(lastNewValue)
                guard lastNewValueComparator <= followingValueComparator else {
                    preconditionFailure("Cannot assign \(lastNewValue) in position before \(followingValue).") 
                }
            }
            base[range] = newValue.base
        }
    }
}

extension LazyMapSortedArraySlice: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        return base.description
    }
    
    public var debugDescription: String {
        return base.debugDescription
    }
}

extension LazyMapSortedArraySlice {
    public func insertionIndex(of element: Element, for selection: BoundSelection = .any) -> Int {
        return insertionIndex(ofComparator: transform(element), for: selection)
    }
    
    public func insertionIndex(ofComparator elementComparator: Comparator, for selection: BoundSelection = .any) -> Int {
        var (lowerBound, upperBound) = (startIndex, endIndex)
        while lowerBound < upperBound {
            let middleBound = (upperBound - lowerBound) / 2 + lowerBound
            let middleElement = self[middleBound]
            let middleElementComparator = transform(middleElement)
            
            if middleElementComparator < elementComparator {
                lowerBound = middleBound + 1
            } else if middleElementComparator > elementComparator {
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

extension LazyMapSortedArraySlice {
    public mutating func insert<S: Sequence>(contentsOf sequence: S) where S.Iterator.Element == Element {
        for element in sequence {
            insert(element)
        }
    }
}

extension LazyMapSortedArraySlice {
    public mutating func insert(_ element: Element, atChecked index: Int) {
        let elementComparator = transform(element)
        if index - 1 >= base.startIndex {
            let precedingValue = base[index - 1]
            let precedingValueComparator = transform(precedingValue)
            guard precedingValueComparator <= elementComparator else {
                preconditionFailure("Cannot insert \(element) in position after \(precedingValue).") 
            }
        }
        if index < base.endIndex {
            let followingValue = base[index]
            let followingValueComparator = transform(followingValue)
            guard elementComparator <= followingValueComparator else {
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

extension LazyMapSortedArraySlice {
    /// Returns the index where the specified value appears in the specified
    /// position in the collection.
    /// - Complexity: O(log(n)), where n is the length of the base.
    public func index(of element: Element, at selection: BoundSelection = .any) -> Int? {
        let potentialIndex = insertionIndex(of: element, for: selection)
        let potentialElement = self[potentialIndex]
        let elementComparator = transform(element)
        let potentialElementComparator = transform(potentialElement)
        guard elementComparator == potentialElementComparator else { return nil }
        return potentialIndex
    }
    
    /// Returns a Boolean value indicating whether the sequence contains the given element.
    /// - Complexity: O(log(n)), where n is the length of the base.
    public func contains(element: Element) -> Bool {
        return index(of: element) != nil
    }
}

extension LazyMapSortedArraySlice {
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

extension LazyMapSortedArraySlice {
    /// Replaces element at index with a new element, resorting the base afterwards.
    ///
    /// Note this is more efficient than simply removing and adding since this function
    /// will only shift the elements that actually need to move.
    ///
    /// - Complexity: O(n), where n is the length of the base.
    public mutating func replace(at index: Int, with element: Element) {        
        // Find most efficient position to insert at
        let oldElement = base[index]
        let elementComparator = transform(element)
        let oldElementComparator = transform(oldElement)
        if oldElementComparator < elementComparator {
            let newIndex = self[(index + 1)..<base.endIndex].insertionIndex(of: element, for: .least)
            base[index..<(newIndex - 1)] = base[(index + 1)..<newIndex]
            base[newIndex - 1] = element
        } else if oldElementComparator > elementComparator {
            let newIndex = self[base.startIndex..<(index + 1)].insertionIndex(of: element, for: .greatest)
            base[(newIndex + 1)..<(index + 1)] = base[newIndex..<index]
            base[newIndex] = element
        } else {
            base[index] = element
        }
    }
}

public func ==<Element: Comparable, Comparator: Comparable>(
    lhs: LazyMapSortedArraySlice<Element, Comparator>,
    rhs: LazyMapSortedArraySlice<Element, Comparator>
) -> Bool {
    return lhs.base == rhs.base
}
