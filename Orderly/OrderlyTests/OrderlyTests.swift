//
//  OrderlyTests.swift
//  OrderlyTests
//
//  Created by Jaden Geller on 1/12/16.
//  Copyright © 2016 Jaden Geller. All rights reserved.
//

import XCTest
@testable import Orderly

class OrderlyTests: XCTestCase {
    func testIsSorted() {
        XCTAssertTrue([-60, 1, 2, 3, 3, 3, 5, 6, 10000].isSorted)
        XCTAssertFalse([61, -60, 1, 2, 3, 3, 3, 5, 6, 10000].isSorted)
        XCTAssertFalse([1, 2, 3, 3, 3, 5, 6, -10].isSorted)
        XCTAssertFalse([1, 2, 3, 3, 3, 5, 6, 5].isSorted)
        XCTAssertFalse([1, 2, 3, 2, 3, 5, 6].isSorted)
    }
    
    func testInsertionIndex() {
        let arr = SortedArray(unsorted: [1, 2, 5, 6, 6, 10, 12])
        XCTAssertEqual(0, arr.insertionIndexOf(-100))
        XCTAssertEqual(0, arr.insertionIndexOf(0))
        XCTAssertEqual(0, arr.insertionIndexOf(1))
        XCTAssertEqual(1, arr.insertionIndexOf(2))
        XCTAssertEqual(2, arr.insertionIndexOf(3))
        XCTAssertEqual(2, arr.insertionIndexOf(4))
        XCTAssertEqual(2, arr.insertionIndexOf(5))
        XCTAssertEqual(3, arr.insertionIndexOf(6))
        XCTAssertEqual(7, arr.insertionIndexOf(100))
    }
    
    func testInsert() {
        var arr = SortedArray(unsorted: [1, 2, 5, 6, 6, 10, 12])
        arr.insert(3)
        arr.insert(6)
        arr.insert(0)
        XCTAssertEqual([0, 1, 2, 3, 5, 6, 6, 6, 10, 12], Array(arr))
        arr.insertContentsOf(7...11)
        XCTAssertEqual([0, 1, 2, 3, 5, 6, 6, 6, 7, 8, 9, 10, 10, 11, 12], Array(arr))
    }
    
    func testInsertSortedArray() {
        let arr = SortedArray(unsorted: [1, 2, 3, 5, 10, 12, 13])
        let sortedBar = SortedArray(unsorted: [2, 3, 4, 6, 7, 8, 16])
        let unsortedBar: Array = [2, 3, 4, 6, 7, 8, 16]
        
        var arrNormal = arr
        arrNormal.insertContentsOf(unsortedBar)
        
        var arrOptimized = arr
        arrOptimized.insertContentsOf(sortedBar)
        
        XCTAssertTrue(arrNormal == arrOptimized)
    }
}
