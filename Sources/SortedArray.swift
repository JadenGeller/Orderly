//
//  SortedArray.swift
//  Orderly
//
//  Created by Jaden Geller on 1/12/16.
//  Copyright © 2017 Jaden Geller. All rights reserved.
//

import Comparator

public struct SortedArray<Element> {
    fileprivate let ordering: (Element, Element) -> Ordering
    fileprivate var array: [Element]
}

extension Sequence where SubSequence: Sequence, SubSequence.Iterator.Element == Iterator.Element {
    public func isSorted(by ordering: (Iterator.Element, Iterator.Element) -> Ordering) -> Bool {
        for (a, b) in zip(self, dropFirst()) {
            guard ordering(a, b) != .descending else { return false }
        }
        return true
    }
}

extension Sequence where Iterator.Element: Comparable, SubSequence: Sequence, SubSequence.Iterator.Element == Iterator.Element {
    public var isSorted: Bool {
        return isSorted(by: <=>)
    }
}

extension SortedArray {
    /// Constructs a `SortedArray` assuing that `array` is already sorted,
    /// only performing check during testing.
    public init(unsafeUncheckedFromSorted array: [Element], by ordering: @escaping (Element, Element) -> Ordering) {
        assert(array.isSorted(by: ordering))
        self.array = array
        self.ordering = ordering
    }
    
    /// Constructs a `SortedArray` if `array` is verified to be sorted, otherwise returns `nil`.
    public init?(fromSorted array: [Element], by ordering: @escaping (Element, Element) -> Ordering) {
        guard array.isSorted(by: ordering) else { return nil }
        self.array = array
        self.ordering = ordering
    }
    
    // Constructs a `SortedArray` by sorting `array`.
    public init(fromUnsorted array: [Element], by ordering: @escaping (Element, Element) -> Ordering) {
        self.array = array.sorted(by: { (a, b) in ordering(a, b) == .ascending })
        self.ordering = ordering
    }
    
    public init(by ordering: @escaping (Element, Element) -> Ordering) {
        self.array = []
        self.ordering = ordering
    }
}

extension SortedArray where Element: Comparable {
    /// Constructs a `SortedArray` assuing that `array` is already sorted, performing no check.
    public init(unsafeUncheckedFromSorted array: [Element]) {
        self.init(unsafeUncheckedFromSorted: array, by: <=>)
    }
    
    /// Constructs a `SortedArray` if `array` is verified to be sorted, otherwise returns `nil`.
    public init?(fromSorted array: [Element]) {
        self.init(fromSorted: array, by: <=>)
    }
    
    // Constructs a `SortedArray` by sorting `array`.
    public init(fromUnsorted array: [Element]) {
        self.init(fromUnsorted: array, by: <=>)
    }
    
    public init() {
        self.init(by: <=>)
    }
}

// FIXME: Requires Swift to support conditional conformances.
//extension SortedArray: ArrayLiteralConvertible where Element: Comparable {
//    public init(arrayLiteral elements: Element...) {
//        self.init(unsorted: elements)
//    }
//}

extension Array {
    public init(_ sortedArray: SortedArray<Element>) {
        self = sortedArray.array
    }
}

extension Sequence {
    public func sorted(by areInIncreasingOrder: @escaping (Iterator.Element, Iterator.Element) -> Bool) -> SortedArray<Iterator.Element> {
        return sorted(by: { (a, b) in Ordering(a, b, by: areInIncreasingOrder) })
    }
    
    public func sorted(by ordering: @escaping (Iterator.Element, Iterator.Element) -> Ordering) -> SortedArray<Iterator.Element> {
        return SortedArray(fromUnsorted: Array(self), by: ordering)
    }
}

extension Sequence where Iterator.Element: Comparable {
    public func sorted() -> SortedArray<Iterator.Element> {
        return sorted(by: <=>)
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
    public subscript(unsafe index: Int) -> Element {
        get {
            return self[index]
        }
        set {
            if index - 1 >= array.startIndex {
                let valueBefore = array[index - 1]
                guard ordering(valueBefore, newValue) != .descending else {
                    preconditionFailure("Cannot assign \(newValue) in position after \(valueBefore).") 
                }
            }
            if index + 1 < array.endIndex {
                let valueAfter = array[index + 1]
                guard ordering(newValue, valueAfter) != .descending else {
                    preconditionFailure("Cannot assign \(newValue) in position before \(valueAfter).") 
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

/// Option that indices which insertion index to use when multiple
/// possibilities exist (in the case of duplicate matching elements).
public enum IndexPosition {
    /// The first possible index.
    case first
    /// The last possible index.
    case last
    /// The most efficient index to locate.
    case any
}

extension SortedArray {
    public func insertionIndex(of element: Element, for position: IndexPosition = .any,
                               in range: Range<Int>) -> Int {
        var (min, max) = (range.lowerBound, range.upperBound)
        while min < max {
            let mid = (max - min) / 2 + min
            let midElement = self[mid]

            switch ordering(midElement, element) {
            case .ascending:  min = mid + 1
            case .descending: max = mid
            case .same:
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
    
    @discardableResult public mutating func insert(_ element: Element, at position: IndexPosition = .any) -> Int {
        let index = insertionIndex(of: element, for: position)
        array.insert(element, at: index)
        return index
    }
}

extension SortedArray {
    public mutating func insert<S: Sequence>(ContentsOf sequence: S) where S.Iterator.Element == Element {
        for element in sequence {
            insert(element)
        }
    }
    
    public mutating func insert(contentsOf sortedArray: SortedArray, at position: IndexPosition = .any) {
        var index = startIndex
        for element in sortedArray {
            index = insertionIndex(of: element, for: position, in: index..<endIndex)
            array.insert(element, at: index)
        }
    }
}

extension SortedArray {
    public mutating func insert(_ element: Element, atUnsafe index: Int) {
        if index - 1 >= array.startIndex {
            let valueBefore = array[index - 1]
            guard ordering(valueBefore, element) != .descending else {
                preconditionFailure("Cannot insert \(element) in position after \(valueBefore).") 
            }
        }
        if index < array.endIndex {
            let valueAfter = array[index]
            guard ordering(element, valueAfter) != .descending else {
                preconditionFailure("Cannot insert \(element) in position before \(valueAfter).") 
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

// FIXME: We have no way of knowing whether the `Comparable` instance was used...
//extension SortedArray where Element: Comparable {
//    public func sorted() -> [Element] {
//        return array
//    }
//
//    public var isSorted: Bool {
//        return true
//    }
//}

extension SortedArray {
    /// Returns the index where the specified value appears in the specified
    /// position in the collection.
    /// - Complexity: O(log(n)), where n is the length of the array.
    public func index(of element: Element, at position: IndexPosition) -> Int? {
        let potentialIndex = insertionIndex(of: element, for: position)
        guard ordering(element, self[potentialIndex]) == .same else { return nil }
        return potentialIndex
    }
    
    /// Returns the first index where the specified value appears in the collection.
    /// - Complexity: O(log(n)), where n is the length of the array.
    public func index(of element: Element) -> Int? {
        return index(of: element, at: .first)
    }
    
    /// Returns a Boolean value indicating whether the sequence contains the given element.
    /// - Complexity: O(log(n)), where n is the length of the array.
    public func contains(element: Element) -> Bool {
        return index(of: element) != nil
    }
    
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

public func ==<Element: Equatable>(lhs: SortedArray<Element>, rhs: SortedArray<Element>) -> Bool {
    return lhs.array == rhs.array
}
