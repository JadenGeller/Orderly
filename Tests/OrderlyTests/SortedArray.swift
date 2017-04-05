//
//  SortedArray.swift
//  
//
//  Created by Jaden Geller on 3/28/17.
//
//

import XCTest
import Orderly

class SortedArrayTests: XCTestCase {

    func testIsSorted() {
        XCTAssertTrue([-60, 1, 2, 3, 3, 3, 5, 6, 10000].isSorted())
        XCTAssertFalse([61, -60, 1, 2, 3, 3, 3, 5, 6, 10000].isSorted())
        XCTAssertFalse([1, 2, 3, 3, 3, 5, 6, -10].isSorted())
        XCTAssertFalse([1, 2, 3, 3, 3, 5, 6, 5].isSorted())
        XCTAssertFalse([1, 2, 3, 2, 3, 5, 6].isSorted())
    }
    
    func testInsertionIndex() {
        let arr = SortedArray(sorting: [1, 2, 5, 6, 6, 10, 12])
        XCTAssertEqual(0, arr.insertionIndex(of: -100))
        XCTAssertEqual(0, arr.insertionIndex(of: 0))
        XCTAssertEqual(0, arr.insertionIndex(of: 1))
        XCTAssertEqual(1, arr.insertionIndex(of: 2))
        XCTAssertEqual(2, arr.insertionIndex(of: 3))
        XCTAssertEqual(2, arr.insertionIndex(of: 4))
        XCTAssertEqual(2, arr.insertionIndex(of: 5))
        XCTAssertEqual(3, arr.insertionIndex(of: 6))
        XCTAssertEqual(3, arr.insertionIndex(of: 6, for: .least))
        XCTAssertEqual(3, arr.insertionIndex(of: 6, for: .least))
        XCTAssertEqual(5, arr.insertionIndex(of: 6, for: .greatest))
        XCTAssertEqual(7, arr.insertionIndex(of: 100))
    }
    
    func testInsert() {
        var arr = SortedArray(sorting: [1, 2, 5, 6, 6, 10, 12])
        arr.insert(3)
        arr.insert(6)
        arr.insert(0)
        XCTAssertEqual([0, 1, 2, 3, 5, 6, 6, 6, 10, 12], Array(arr))
        arr.insert(contentsOf: 7...11)
        XCTAssertEqual([0, 1, 2, 3, 5, 6, 6, 6, 7, 8, 9, 10, 10, 11, 12], Array(arr))
    }
    
    func testInsertSortedArray() {
        let arr = SortedArray(sorting: [1, 2, 3, 5, 10, 12, 13])
        let sortedBar = SortedArray(sorting: [2, 3, 4, 6, 7, 8, 16])
        let unsortedBar: Array = [2, 3, 4, 6, 7, 8, 16]
        
        var arrNormal = arr
        arrNormal.insert(contentsOf: unsortedBar)
        
        var arrOptimized = arr
        arrOptimized.insert(contentsOf: sortedBar)
        
        XCTAssertTrue(arrNormal == arrOptimized)
    }

}
