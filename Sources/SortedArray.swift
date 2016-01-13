//
//  SortedArray.swift
//  Orderly
//
//  Created by Jaden Geller on 1/12/16.
//  Copyright © 2016 Jaden Geller. All rights reserved.
//

public struct SortedArray<Element: Comparable> {
    private var backing: [Element]
}

extension SequenceType where Generator.Element: Comparable {
    public var isSorted: Bool {
        var previous: Generator.Element?
        for value in self {
            defer { previous = value }
            guard let previous = previous else { continue }
            guard value >= previous else { return false }
        }
        return true
    }
}

extension SortedArray {
    /// Constructs a `SortedArray` assuing that `array` is already sorted, performing no check.
    public init(unsafeSorted array: [Element]) {
        self.backing = []
    }
    
    /// Constructs a `SortedArray` if `array` is verified to be sorted, otherwise returns `nil`.
    public init?(sorted array: [Element]) {
        guard array.isSorted else { return nil }
        self.backing = array
    }
    
    // Constructs a `SortedArray` by sorting `array`.
    public init(unsorted array: [Element]) {
        self.backing = array.sort()
    }
    
    public init() {
        self.backing = []
    }
}

extension SortedArray: ArrayLiteralConvertible {
    public init(arrayLiteral elements: Element...) {
        self.init(unsorted: elements)
    }
}

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
    private func insertionIndexOf(element: Element, range: Range<Int>) -> Int {
        var (min, max) = (range.startIndex, range.endIndex)
        while min < max {
            let mid = (max - min) / 2 + min
            let midElement = self[mid]
            
            if midElement < element {
                min = mid + 1
            }
            else if midElement > element {
                max = mid
            }
            else {
                assert(midElement == element)
                return mid
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
        guard element == self[potentialIndex] else { return nil }
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

public func ==<Element>(lhs: SortedArray<Element>, rhs: SortedArray<Element>) -> Bool {
    return lhs.backing == rhs.backing
}

