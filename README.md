# Orderly

Orderly defines a sorted array type that implements optimized forms of `insert(_:)`, `index(of:)`, `contains(_:)`, and more by taking advantage of binary search. This type is also useful for maintaining queues where constant-time `min()` or `max()` lookup is important.

```swift
var queue: SortedArray = [18, 1, 2, 20, 6].sort()
queue.insert(3)
queue.insert(12)
print(queue) // -> [1, 2, 3, 6, 12, 18, 20]
```

Note that `SortedArray` defines a similiar interface to `Array` except that it does not allow mutations that would invalidate the ordering.
