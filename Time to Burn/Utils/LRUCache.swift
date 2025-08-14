import Foundation

/// A minimal in-memory LRU cache for small result sets.
///
/// Not thread-safe. Use on the main actor (e.g. from UI models) or wrap with your own synchronization.
final class LRUCache<Key: Hashable, Value> {
    private final class Node {
        let key: Key
        var value: Value
        var prev: Node?
        var next: Node?
        init(key: Key, value: Value) {
            self.key = key
            self.value = value
        }
    }
    
    private let capacity: Int
    private var dict: [Key: Node] = [:]
    private var head: Node?
    private var tail: Node?
    
    init(capacity: Int) {
        self.capacity = max(1, capacity)
    }
    
    func value(forKey key: Key) -> Value? {
        guard let node = dict[key] else { return nil }
        moveToHead(node)
        return node.value
    }
    
    func setValue(_ value: Value, forKey key: Key) {
        if let node = dict[key] {
            node.value = value
            moveToHead(node)
            return
        }
        let node = Node(key: key, value: value)
        dict[key] = node
        addToHead(node)
        if dict.count > capacity {
            removeTail()
        }
    }
    
    // MARK: - Doubly Linked List helpers
    
    private func addToHead(_ node: Node) {
        node.prev = nil
        node.next = head
        head?.prev = node
        head = node
        if tail == nil { tail = node }
    }
    
    private func moveToHead(_ node: Node) {
        guard head !== node else { return }
        // unlink
        node.prev?.next = node.next
        node.next?.prev = node.prev
        if tail === node {
            tail = node.prev
        }
        // insert at head
        node.prev = nil
        node.next = head
        head?.prev = node
        head = node
    }
    
    private func removeTail() {
        guard let tailNode = tail else { return }
        dict[tailNode.key] = nil
        if head === tail {
            head = nil
            tail = nil
            return
        }
        tail = tailNode.prev
        tail?.next = nil
    }
}


