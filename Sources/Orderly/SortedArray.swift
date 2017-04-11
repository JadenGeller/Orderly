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
    public struct Slice {
        fileprivate var base: ArraySlice<Element>
    }
}

extension SortedArray {
    /// Constructs a `SortedArray` assuring that `base` is already sorted,
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

extension Sequence where Iterator.Element: Comparable {
    func sorted() -> SortedArray<Iterator.Element> {
        return SortedArray(sorting: Array(self))
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
    
    public subscript(_ index: Int) -> Element {
        get {
            return base[index]
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
    
    public subscript(_ range: Range<Int>) -> SortedArray<Element>.Slice {
        get {
            return SortedArray.Slice(uncheckedSorted: base[range])
        }
        set {
            // Fast path for empty assignment
            guard !newValue.isEmpty else {
                base.removeSubrange(range)
                return
            }
            
            if range.lowerBound - 1 >= base.startIndex, let firstNewValue = newValue.first {
                let precedingValue = base[range.lowerBound - 1]
                guard precedingValue <= firstNewValue else {
                    preconditionFailure("Cannot assign \(firstNewValue) in position after \(precedingValue).") 
                }
            }
            if range.upperBound < base.endIndex, let lastNewValue = newValue.last {
                let followingValue = base[range.upperBound]
                guard lastNewValue <= followingValue else {
                    preconditionFailure("Cannot assign \(lastNewValue) in position before \(followingValue).") 
                }
            }
            base[range] = newValue.base
        }
    }
}

extension SortedArray: RangeReplaceableCollection {
    public mutating func replaceSubrange<C: Collection>(_ subrange: Range<Int>, with newElements: C)
        where C.Iterator.Element == Iterator.Element {
        guard let sorted = SortedArray<Element>.Slice(checkingSorted: ArraySlice(newElements)) else {
            fatalError("`newElements` must already be sorted.")
        }
        self[subrange] = sorted
    }
}

extension SortedArray: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        return base.description
    }
    
    public var debugDescription: String {
        // FIXME: Incorrectly `ArraySlice` for `.Slice` variants.
        return base.debugDescription
    }
}

extension SortedArray {
    public func insertionIndex(of element: Element, for selection: IndexPosition = .any) -> Int {
        var (lowerBound, upperBound) = (startIndex, endIndex)
        while lowerBound < upperBound {
            let middleBound = (upperBound - lowerBound) / 2 + lowerBound
            let middleElement = self[middleBound]
            
            if middleElement < element {
                lowerBound = middleBound + 1
            } else if middleElement > element {
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

extension SortedArray {
    public mutating func insert<S: Sequence>(contentsOf sequence: S) where S.Iterator.Element == Element {
        for element in sequence {
            insert(element)
        }
    }
    
    public mutating func insert(contentsOf sortedArray: SortedArray<Element>, at selection: IndexPosition = .any) {
        var index = startIndex
        for element in sortedArray {
            index = self[index..<endIndex].insertionIndex(of: element, for: selection)
            base.insert(element, at: index)
        }
    }
}

extension SortedArray {
    public mutating func insert(_ element: Element, at index: Int) {
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
    
    public mutating func append(_ element: Element) {
        guard let lastValue = base.last else {
            // Currently empty
            base.append(element)
            return
        }
        guard lastValue <= element else {
            preconditionFailure("Cannot append \(element) after \(lastValue).") 
        }
        base.append(element)
    }
}

extension SortedArray {
    /// Returns the index where the specified value appears in the specified
    /// position in the collection.
    /// - Complexity: O(log(n)), where n is the length of the base.
    public func index(of element: Element, at selection: IndexPosition = .any) -> Int? {
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

extension SortedArray.Slice {
    /// Constructs a `SortedArray` assuring that `base` is already sorted,
    /// only performing check during testing.
    public init(uncheckedSorted base: ArraySlice<Element>) {
        assert(base.isSorted())
        self.base = base
    }
    
    /// Constructs a `SortedArray` if `base` is verified to be sorted, otherwise returns `nil`.
    public init?(checkingSorted base: ArraySlice<Element>) {
        guard base.isSorted() else { return nil }
        self.base = base
    }
    
    // Constructs a `SortedArray` by sorting `base`.
    public init(sorting base: ArraySlice<Element>) {
        self.base = ArraySlice(base.sorted())
    }
    
    public init() {
        self.base = []
    }
}

extension SortedArray.Slice: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: Element...) {
        guard elements.isSorted() else { fatalError("`SortedArray` literal must already be sorted.") }
        self.base = ArraySlice(elements)
    }
}


extension SortedArray.Slice: BidirectionalCollection {
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
    
    public subscript(_ range: Range<Int>) -> SortedArray<Element>.Slice {
        get {
            return SortedArray.Slice(uncheckedSorted: base[range])
        }
        set {
            // Fast path for empty assignment
            guard !newValue.isEmpty else {
                base.removeSubrange(range)
                return
            }
            
            if range.lowerBound - 1 >= base.startIndex, let firstNewValue = newValue.first {
                let precedingValue = base[range.lowerBound - 1]
                guard precedingValue <= firstNewValue else {
                    preconditionFailure("Cannot assign \(firstNewValue) in position after \(precedingValue).") 
                }
            }
            if range.upperBound < base.endIndex, let lastNewValue = newValue.last {
                let followingValue = base[range.upperBound]
                guard lastNewValue <= followingValue else {
                    preconditionFailure("Cannot assign \(lastNewValue) in position before \(followingValue).") 
                }
            }
            base[range] = newValue.base
        }
    }
}

extension SortedArray.Slice: RangeReplaceableCollection {
    public mutating func replaceSubrange<C: Collection>(_ subrange: Range<Int>, with newElements: C)
        where C.Iterator.Element == Iterator.Element {
        guard let sorted = SortedArray<Element>.Slice(checkingSorted: ArraySlice(newElements)) else {
            fatalError("`newElements` must already be sorted.")
        }
        self[subrange] = sorted
    }
}

extension SortedArray.Slice: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        return base.description
    }
    
    public var debugDescription: String {
        // FIXME: Incorrectly `ArraySlice` for `.Slice` variants.
        return base.debugDescription
    }
}

extension SortedArray.Slice {
    public func insertionIndex(of element: Element, for selection: IndexPosition = .any) -> Int {
        var (lowerBound, upperBound) = (startIndex, endIndex)
        while lowerBound < upperBound {
            let middleBound = (upperBound - lowerBound) / 2 + lowerBound
            let middleElement = self[middleBound]
            
            if middleElement < element {
                lowerBound = middleBound + 1
            } else if middleElement > element {
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

extension SortedArray.Slice {
    public mutating func insert<S: Sequence>(contentsOf sequence: S) where S.Iterator.Element == Element {
        for element in sequence {
            insert(element)
        }
    }
    
    public mutating func insert(contentsOf sortedArray: SortedArray<Element>.Slice, at selection: IndexPosition = .any) {
        var index = startIndex
        for element in sortedArray {
            index = self[index..<endIndex].insertionIndex(of: element, for: selection)
            base.insert(element, at: index)
        }
    }
}

extension SortedArray.Slice {
    public mutating func insert(_ element: Element, at index: Int) {
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
    
    public mutating func append(_ element: Element) {
        guard let lastValue = base.last else {
            // Currently empty
            base.append(element)
            return
        }
        guard lastValue <= element else {
            preconditionFailure("Cannot append \(element) after \(lastValue).") 
        }
        base.append(element)
    }
}

extension SortedArray.Slice {
    /// Returns the index where the specified value appears in the specified
    /// position in the collection.
    /// - Complexity: O(log(n)), where n is the length of the base.
    public func index(of element: Element, at selection: IndexPosition = .any) -> Int? {
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

extension SortedArray.Slice {
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
// Avoid doing unnecessary work
extension SortedArray.Slice {
    public func sorted() -> [Element] {
        return Array(base)
    }

    public func sorted() -> SortedArray<Element> {
        return SortedArray(uncheckedSorted: Array(base))
    }

    public func isSorted() -> Bool {
        return true
    }
}

extension SortedArray.Slice {
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

extension SortedArray.Slice {
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
            let newIndex = self[(index + 1)..<base.endIndex].insertionIndex(of: element, for: .least)
            base[index..<(newIndex - 1)] = base[(index + 1)..<newIndex]
            base[newIndex - 1] = element
        } else if oldElement > element {
            let newIndex = self[base.startIndex..<(index + 1)].insertionIndex(of: element, for: .greatest)
            base[(newIndex + 1)..<(index + 1)] = base[newIndex..<index]
            base[newIndex] = element
        } else {
            base[index] = element
        }
    }
}

public func ==<Element: Comparable>(
    lhs: SortedArray<Element>.Slice,
    rhs: SortedArray<Element>.Slice
) -> Bool {
    return lhs.base == rhs.base
}
