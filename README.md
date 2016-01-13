# Orderly

Orderly defines a sorted array type that implements optimized forms of `insert`, `indexOf`, `contains`, and more by taking advantage of binary search. This type is also useful for maintaining queues where constant-time `minElement` or `maxElement` lookup is important.

```swift
var queue: SortedArray = [1, 2, 6, 18, 20]
queue.insert(3)
queue.insert(12)
print(queue) // -> [1, 2, 3, 6, 12, 18, 20]
```

Note that `SortedArray` defines a similiar interface to `Array` except that it does not allow mutation of arbitrary indices as this would invalidate the ordering. To "mutate" a value in `SortedArray`, simply `removeAtIndex` the value that is to be modified and `insert` the new value into the array.
