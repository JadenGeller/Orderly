# Orderly

Orderly defines a sorted array type that implements optimized forms of `insert(_:)`, `index(of:)`, `contains(_:)`, and more by taking advantage of binary search. This type is also useful for maintaining queues where constant-time `min()` or `max()` lookup is important.

```swift
var queue: SortedArray = [18, 1, 2, 20, 6].sorted()
queue.insert(3)
queue.insert(12)
print(queue) // -> [1, 2, 3, 6, 12, 18, 20]
```

In addition to `SortedArray`, Orderly also provides a `LazyMapSortedArray` type for sorting on arbitrary properties or transforms and a `DescriptorSortedArray` type for sorting by an arbitrary predicate.

```swift
let x: LazyMapSortedArray = arr.sorted(on: { $0.foo })
let y: DescriptorSortedArray = arr.sortedy(by: { $0.foo < $1.foo || $0.bar < $0.bar })
```
