/ //
//  SortedArray.swift
//  Orderly
//
//  Created by Jaden Geller on 1/12/16.
//  Copyright © 2016 Jaden Geller. All rights reserved.
//

import Comparator

public struct SortedArray<Element> {
    private let isOrderedBefore: (Element, Element) -> Bool
    private var backing: [Element]
}

extension SequenceType {
    public func isSorted(@noescape isOrderedBefore: (Generator.Element, Generator.Element) -> Bool) -> Bool {
        var previous: Generator.Element?
        for value in self {
            defer { previous = value }
            guard let previous = previous else { continue }
            guard Ordering(previous, value, isOrderedBefore: isOrderedBefore) != .Descending else { return false }
        }
        return true
    }
}

extension SequenceType where Generator.Element: Comparable {
    public var isSorted: Bool {
        return isSorted(<)
    }
}

extension SortedArray {
    /// Constructs a `SortedArray` assuing that `array` is already sorted, performing no check.
    public init(unsafeSorted array: [Element], isOrderedBefore: (Element, Element) -> Bool) {
        self.backing = array
        self.isOrderedBefore = isOrderedBefore
    }
    
    /// Constructs a `SortedArray` if `array` is verified to be sorted, otherwise returns `nil`.
    public init?(sorted array: [Element], isOrderedBefore: (Element, Element) -> Bool) {
        guard array.isSorted(isOrderedBefore) else { return nil }
        self.backing = array
        self.isOrderedBefore = isOrderedBefore
    }
    
    // Constructs a `SortedArray` by sorting `array`.
    public init(unsorted array: [Element], isOrderedBefore: (Element, Element) -> Bool) {
        self.backing = array.sort(isOrderedBefore)
        self.isOrderedBefore = isOrderedBefore
    }
    
    public init(isOrderedBefore: (Element, Element) -> Bool) {
        self.backing = []
        self.isOrderedBefore = isOrderedBefore
    }
}

extension SortedArray where Element: Comparable {
    /// Constructs a `SortedArray` assuing that `array` is already sorted, performing no check.
    public init(unsafeSorted array: [Element]) {
        self.init(unsafeSorted: array, isOrderedBefore: <)
    }
    
    /// Constructs a `SortedArray` if `array` is verified to be sorted, otherwise returns `nil`.
    public init?(sorted array: [Element]) {
        self.init(sorted: array, isOrderedBefore: <)
    }
    
    // Constructs a `SortedArray` by sorting `array`.
    public init(unsorted array: [Element]) {
        self.init(unsorted: array, isOrderedBefore: <)
    }
    
    public init() {
        self.init(isOrderedBefore: <)
    }
}

// Swift 3.0 :(
//extension SortedArray: ArrayLiteralConvertible where Element: Comparable {
//    public init(arrayLiteral elements: Element...) {
//        self.init(unsorted: elements)
//    }
//}

extension Array where Element: Comparable {
    public init(_ sortedArray: SortedArray<Element>) {
        self.init(sortedArray.backing)
    }
}

extension SortedArray: CollectionType {
    public var startIndex: Int {
        return backing.startIndex
    }
    
    public var endIndex: Int {
        return backing.endIndex
    }
    
    public subscript(index: Int) -> Element {
        return backing[index]
    }
}

extension SortedArray: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        return backing.description
    }
    
    public var debugDescription: String {
        return backing.debugDescription
    }
}

extension SortedArray {
    @warn_unused_result private func insertionIndexOf(element: Element, range: Range<Int>) -> Int {
        var (min, max) = (range.startIndex, range.endIndex)
        while min < max {
            let mid = (max - min) / 2 + min
            let midElement = self[mid]

            switch Ordering(midElement, element, isOrderedBefore: isOrderedBefore) {
            case .Ascending:  min = mid + 1
            case .Descending: max = mid
            case .Same:       return mid
            }
        }
        return min
    }
    
    /// The index at which an element would be inserted into the array. Note that an
    /// element is always inserted at the leftmost possible index if duplicates exist.
    public func insertionIndexOf(element: Element) -> Int {
        return insertionIndexOf(element, range: startIndex..<endIndex)
    }
    
    public mutating func insert(element: Element) {
        backing.insert(element, atIndex: insertionIndexOf(element))
    }
    
    public mutating func insertContentsOf<S: SequenceType where S.Generator.Element == Element>(sequence: S) {
        sequence.forEach{ insert($0) }
    }
    
    public mutating func insertContentsOf(sortedArray: SortedArray) {
        var index = startIndex
        sortedArray.forEach { element in
            index = insertionIndexOf(element, range: index..<endIndex)
            backing.insert(element, atIndex: index)
        }
    }
}

extension SortedArray {
    public func sort() -> [Element] {
        return backing
    }
    
    public var isSorted: Bool {
        return true
    }
    
    public func indexOf(element: Element) -> Int? {
        let potentialIndex = insertionIndexOf(element)
        guard .Same == Ordering(element, self[potentialIndex], isOrderedBefore: isOrderedBefore) else { return nil }
        return potentialIndex
    }
    
    public func contains(element: Element) -> Bool {
        return indexOf(element) != nil
    }
    
    public func maxElement() -> Element? {
        return last
    }
    
    public func minElement() -> Element? {
        return first
    }
}

extension SortedArray {
    public mutating func popLast() -> Element? {
        return backing.popLast()
    }
    
    public mutating func removeAll(keepCapacity: Bool = false) {
        backing.removeAll(keepCapacity: keepCapacity)
    }
    
    public mutating func removeAtIndex(index: Int) -> Element {
        return backing.removeAtIndex(index)
    }
    
    public mutating func removeFirst() {
        backing.removeFirst()
    }
    
    public mutating func removeFirst(n: Int) {
        backing.removeFirst(n)
    }
    
    public mutating func removeLast() {
        backing.removeLast()
    }
    
    public mutating func removeRange(subRange: Range<Int>) {
        backing.removeRange(subRange)
    }
    
    public mutating func reserveCapacity(minimumCapacity: Int) {
        backing.reserveCapacity(minimumCapacity)
    }
}

public func ==<Element: Equatable>(lhs: SortedArray<Element>, rhs: SortedArray<Element>) -> Bool {
    return lhs.backing == rhs.backing
}

