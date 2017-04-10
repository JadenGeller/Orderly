extension Sequence where SubSequence: Sequence, SubSequence.Iterator.Element == Iterator.Element {
    public func isSorted<Comparator: Comparable>(on transform: @escaping (Iterator.Element) -> Comparator) -> Bool {
        let comparator = lazy.map(transform)
        for (lhs, rhs) in zip(comparator, comparator.dropFirst()) {
            guard lhs <= rhs else { return false }
        }
        return true
    }
    
    // FIXME: Use `withoutActuallyEscaping` in Swift 3.1
    public func sorted<Comparator: Comparable>(on transform: @escaping (Iterator.Element) -> Comparator) -> [Iterator.Element] {
        // FIXME: Remove type annotation after SR-4509 is resolved.
        return (lazy.map({ (value: $0, comparator: transform($0)) }) as LazyMapSequence)
                    .sorted(by: { (a, b) in a.comparator < b.comparator })
                    .map({ $0.value })
    }
}

public struct LazyMapSortedArray<Element, Comparator: Comparable> {
    fileprivate var base: [Element]
    fileprivate var transform: (Element) -> Comparator
}

extension LazyMapSortedArray {
    public struct Slice {
        fileprivate var base: ArraySlice<Element>
        fileprivate var transform: ((Element) -> Comparator)?
    }
}

extension LazyMapSortedArray {
    /// Constructs a `LazyMapSortedArray` assuring that `base` is already sorted,
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

extension Sequence {
    func sorted<Comparator: Comparable>(on transform: @escaping (Iterator.Element) -> Comparator) -> LazyMapSortedArray<Iterator.Element, Comparator> {
        return LazyMapSortedArray(sorting: Array(self), on: transform)
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
            return base[index]
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
    
    public subscript(_ range: Range<Int>) -> LazyMapSortedArray<Element, Comparator>.Slice {
        get {
            return LazyMapSortedArray.Slice(uncheckedSorted: base[range], on: transform)
        }
        set {
            
            // Fast path for empty assignment
            guard !newValue.isEmpty else {
                base.removeSubrange(range)
                return
            }
            
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

//extension LazyMapSortedArray: RangeReplaceableCollection {
//    public mutating func replaceSubrange<C: Collection>(_ subrange: Range<Int>, with newElements: C)
//        where C.Iterator.Element == Iterator.Element {
//        
//    }
//}

extension LazyMapSortedArray: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        return base.description
    }
    
    public var debugDescription: String {
        // FIXME: Incorrectly `ArraySlice` for `.Slice` variants.
        return base.debugDescription
    }
}

extension LazyMapSortedArray {
    public func insertionIndex(of element: Element, for selection: IndexPosition = .any) -> Int {

        return insertionIndex(ofComparator: transform(element), for: selection)
    }
    
    public func insertionIndex(ofComparator elementComparator: Comparator, for selection: IndexPosition = .any) -> Int {
    
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
    public mutating func insert(_ element: Element, at selection: IndexPosition = .any) -> Int {
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
    public mutating func insert(_ element: Element, at index: Int) {
        
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
    
    public mutating func append(_ element: Element) {
        
        guard let lastValue = base.last else {
            // Currently empty
            base.append(element)
            return
        }
        let elementComparator = transform(element)
        let lastValueComparator = transform(lastValue)
        guard lastValueComparator <= elementComparator else {
            preconditionFailure("Cannot append \(element) after \(lastValue).") 
        }
        base.append(element)
    }
}

extension LazyMapSortedArray {
    /// Returns the index where the specified value appears in the specified
    /// position in the collection.
    /// - Complexity: O(log(n)), where n is the length of the base.
    public func index(of element: Element, at selection: IndexPosition = .any) -> Int? {
        
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
    
    @discardableResult
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
    
    public mutating func removeSubrange(_ bounds: Range<Int>) {
        base.removeSubrange(bounds)
    }
    
    public mutating func removeSubrange(_ bounds: ClosedRange<Int>) {
        base.removeSubrange(bounds)
    }
    
    public mutating func removeSubrange(_ bounds: CountableRange<Int>) {
        base.removeSubrange(bounds)
    }
    
    public mutating func removeSubrange(_ bounds: CountableClosedRange<Int>) {
        base.removeSubrange(bounds)
    }
    
    public mutating func reserveCapacity(minimumCapacity: Int) {
        base.reserveCapacity(minimumCapacity)
    }
}
extension LazyMapSortedArray {
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

extension LazyMapSortedArray.Slice {
//    public init() {
//        self.init(uncheckedSorted: [])
//    }
    
    fileprivate init(uncheckedSorted base: ArraySlice<Element>, on transform: ((Element) -> Comparator)? = nil) {
        self.base = base
        self.transform = transform
    }
    
    /// Constructs a `LazyMapSortedArray` assuring that `base` is already sorted,
    /// only performing check during testing.
    public init(uncheckedSorted base: ArraySlice<Element>, on transform: @escaping (Element) -> Comparator) {
        assert(base.isSorted(on: transform))
        self.base = base
        self.transform = transform
    }
    
    /// Constructs a `LazyMapSortedArray` if `base` is verified to be sorted, otherwise returns `nil`.
    public init?(checkingSorted base: ArraySlice<Element>, on transform: @escaping (Element) -> Comparator) {
        guard base.isSorted(on: transform) else { return nil }
        self.base = base
        self.transform = transform
    }
    
    // Constructs a `LazyMapSortedArray` by sorting `base`.
    public init(sorting base: ArraySlice<Element>, on transform: @escaping (Element) -> Comparator) {
        self.base = ArraySlice(base.sorted(on: transform))
        self.transform = transform
    }
    
    public init(on transform: @escaping (Element) -> Comparator) {
        self.base = []
        self.transform = transform
    }
}


extension LazyMapSortedArray.Slice: BidirectionalCollection {
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
            guard let transform = transform else { fatalError("Sorted array type not initialized with necessary predicate.") }
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
    
    public subscript(_ range: Range<Int>) -> LazyMapSortedArray<Element, Comparator>.Slice {
        get {
            return LazyMapSortedArray.Slice(uncheckedSorted: base[range], on: transform)
        }
        set {
            guard let transform = transform else { fatalError("Sorted array type not initialized with necessary predicate.") }
            
            // Fast path for empty assignment
            guard !newValue.isEmpty else {
                base.removeSubrange(range)
                return
            }
            
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

//extension LazyMapSortedArray.Slice: RangeReplaceableCollection {
//    public mutating func replaceSubrange<C: Collection>(_ subrange: Range<Int>, with newElements: C)
//        where C.Iterator.Element == Iterator.Element {
//        
//    }
//}

extension LazyMapSortedArray.Slice: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        return base.description
    }
    
    public var debugDescription: String {
        // FIXME: Incorrectly `ArraySlice` for `.Slice` variants.
        return base.debugDescription
    }
}

extension LazyMapSortedArray.Slice {
    public func insertionIndex(of element: Element, for selection: IndexPosition = .any) -> Int {
        guard let transform = transform else { fatalError("Sorted array type not initialized with necessary predicate.") }

        return insertionIndex(ofComparator: transform(element), for: selection)
    }
    
    public func insertionIndex(ofComparator elementComparator: Comparator, for selection: IndexPosition = .any) -> Int {
        guard let transform = transform else { fatalError("Sorted array type not initialized with necessary predicate.") }
    
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
    public mutating func insert(_ element: Element, at selection: IndexPosition = .any) -> Int {
        let index = insertionIndex(of: element, for: selection)
        base.insert(element, at: index)
        return index
    }
}

extension LazyMapSortedArray.Slice {
    public mutating func insert<S: Sequence>(contentsOf sequence: S) where S.Iterator.Element == Element {
        for element in sequence {
            insert(element)
        }
    }
}

extension LazyMapSortedArray.Slice {
    public mutating func insert(_ element: Element, at index: Int) {
        guard let transform = transform else { fatalError("Sorted array type not initialized with necessary predicate.") }
        
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
    
    public mutating func append(_ element: Element) {
        guard let transform = transform else { fatalError("Sorted array type not initialized with necessary predicate.") }
        
        guard let lastValue = base.last else {
            // Currently empty
            base.append(element)
            return
        }
        let elementComparator = transform(element)
        let lastValueComparator = transform(lastValue)
        guard lastValueComparator <= elementComparator else {
            preconditionFailure("Cannot append \(element) after \(lastValue).") 
        }
        base.append(element)
    }
}

extension LazyMapSortedArray.Slice {
    /// Returns the index where the specified value appears in the specified
    /// position in the collection.
    /// - Complexity: O(log(n)), where n is the length of the base.
    public func index(of element: Element, at selection: IndexPosition = .any) -> Int? {
        guard let transform = transform else { fatalError("Sorted array type not initialized with necessary predicate.") }
        
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

extension LazyMapSortedArray.Slice {
    public mutating func popLast() -> Element? {
        return base.popLast()
    }
    
    public mutating func removeAll(keepingCapacity: Bool = false) {
        base.removeAll(keepingCapacity: keepingCapacity)
    }
    
    @discardableResult
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
    
    public mutating func removeSubrange(_ bounds: Range<Int>) {
        base.removeSubrange(bounds)
    }
    
    public mutating func removeSubrange(_ bounds: ClosedRange<Int>) {
        base.removeSubrange(bounds)
    }
    
    public mutating func removeSubrange(_ bounds: CountableRange<Int>) {
        base.removeSubrange(bounds)
    }
    
    public mutating func removeSubrange(_ bounds: CountableClosedRange<Int>) {
        base.removeSubrange(bounds)
    }
    
    public mutating func reserveCapacity(minimumCapacity: Int) {
        base.reserveCapacity(minimumCapacity)
    }
}
extension LazyMapSortedArray.Slice {
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

extension LazyMapSortedArray.Slice {
    /// Replaces element at index with a new element, resorting the base afterwards.
    ///
    /// Note this is more efficient than simply removing and adding since this function
    /// will only shift the elements that actually need to move.
    ///
    /// - Complexity: O(n), where n is the length of the base.
    public mutating func replace(at index: Int, with element: Element) {
        guard let transform = transform else { fatalError("Sorted array type not initialized with necessary predicate.") }
            
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

public func ==<Element: Equatable, Comparator: Comparable>(
    lhs: LazyMapSortedArray<Element, Comparator>.Slice,
    rhs: LazyMapSortedArray<Element, Comparator>.Slice
) -> Bool {
    return lhs.base == rhs.base
}
