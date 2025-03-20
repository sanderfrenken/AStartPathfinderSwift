import Foundation

// MARK: - Core Data Types
struct GridPosition: Hashable {
    let x: Int
    let y: Int

    init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }
}

// MARK: - Pathfinding Protocol
protocol PathfindingGrid {
    func isWalkable(_ position: GridPosition) -> Bool
    func isValid(_ position: GridPosition) -> Bool
    var width: Int { get }
    var height: Int { get }
}

// MARK: - Optimized Game Grid
struct GameGrid: PathfindingGrid {
    let width: Int
    let height: Int
    private let obstacles: Set<GridPosition>
    private let neighborCache: [GridPosition: [GridPosition]]

    init(width: Int, height: Int, obstacles: Set<GridPosition>) {
        self.width = width
        self.height = height
        self.obstacles = obstacles
        self.neighborCache = Self.precomputeNeighbors(width: width, height: height, obstacles: obstacles)
    }

    func isWalkable(_ position: GridPosition) -> Bool {
        isValid(position) && !obstacles.contains(position)
    }

    func isValid(_ position: GridPosition) -> Bool {
        position.x >= 0 && position.y >= 0 &&
        position.x < width && position.y < height
    }

    fileprivate func neighbors(for position: GridPosition) -> [GridPosition] {
        neighborCache[position] ?? []
    }

    private static func precomputeNeighbors(width: Int, height: Int, obstacles: Set<GridPosition>) -> [GridPosition: [GridPosition]] {
        var cache = [GridPosition: [GridPosition]]()

        for x in 0..<width {
            for y in 0..<height {
                let pos = GridPosition(x: x, y: y)
                guard !obstacles.contains(pos) else { continue }

                var neighbors = [GridPosition]()
                for dx in -1...1 {
                    for dy in -1...1 {
                        guard dx != 0 || dy != 0 else { continue } // Skip self
                        let neighbor = GridPosition(x: x + dx, y: y + dy)

                        // Boundary check
                        guard neighbor.x >= 0 && neighbor.x < width else { continue }
                        guard neighbor.y >= 0 && neighbor.y < height else { continue }

                        // Obstacle check
                        guard !obstacles.contains(neighbor) else { continue }

                        // Diagonal movement check
                        if dx != 0 && dy != 0 {
                            let horizontal = GridPosition(x: x + dx, y: y)
                            let vertical = GridPosition(x: x, y: y + dy)
                            guard !obstacles.contains(horizontal) else { continue }
                            guard !obstacles.contains(vertical) else { continue }
                        }

                        neighbors.append(neighbor)
                    }
                }
                cache[pos] = neighbors
            }
        }
        return cache
    }
}

// MARK: - Priority Queue (Optimized)
struct PriorityQueue<Element: Comparable> {
    private var heap = ContiguousArray<Element>()

    var isEmpty: Bool { heap.isEmpty }

    mutating func enqueue(_ element: Element) {
        heap.append(element)
        siftUp(from: heap.count - 1)
    }

    mutating func dequeue() -> Element? {
        guard !isEmpty else { return nil }
        heap.swapAt(0, heap.count - 1)
        let value = heap.removeLast()
        siftDown(from: 0)
        return value
    }

    private mutating func siftUp(from index: Int) {
        var child = index
        while child > 0 {
            let parent = (child - 1) / 2
            guard heap[child] < heap[parent] else { break }
            heap.swapAt(child, parent)
            child = parent
        }
    }

    private mutating func siftDown(from index: Int) {
        var parent = index
        while true {
            let left = 2 * parent + 1
            let right = 2 * parent + 2
            var candidate = parent

            if left < heap.count && heap[left] < heap[candidate] {
                candidate = left
            }
            if right < heap.count && heap[right] < heap[candidate] {
                candidate = right
            }
            if candidate == parent { return }
            heap.swapAt(parent, candidate)
            parent = candidate
        }
    }
}

// MARK: - A* Pathfinder
struct AStarPathfinder {
    private let grid: PathfindingGrid
    private let straightCost: Double = 1.0
    private let diagonalCost: Double = 1.41421

    init(grid: PathfindingGrid) {
        self.grid = grid
    }

    func findPath(from start: GridPosition, to goal: GridPosition) -> [GridPosition]? {
        guard grid.isWalkable(start), grid.isWalkable(goal) else { return nil }

        let gridSize = grid.width * grid.height
        var closedSet = [Bool](repeating: false, count: gridSize)
        var gScores = [Double](repeating: .infinity, count: gridSize)
        var openSet = PriorityQueue<Node>()
        var cameFrom = [GridPosition: GridPosition]()

        let startIndex = index(for: start)
        gScores[startIndex] = 0
        openSet.enqueue(Node(position: start, priority: 0))

        while let current = openSet.dequeue() {
            let currentIndex = index(for: current.position)
            if closedSet[currentIndex] { continue }
            closedSet[currentIndex] = true

            if current.position == goal {
                return reconstructPath(cameFrom: cameFrom, current: current.position)
            }

            for neighbor in getNeighbors(of: current.position) {
                let neighborIndex = index(for: neighbor)
                let moveCost = isDiagonal(current.position, neighbor) ? diagonalCost : straightCost
                let tentativeG = gScores[currentIndex] + moveCost

                if tentativeG < gScores[neighborIndex] {
                    cameFrom[neighbor] = current.position
                    gScores[neighborIndex] = tentativeG
                    let h = heuristic(neighbor, goal)
                    openSet.enqueue(Node(position: neighbor, priority: tentativeG + h))
                }
            }
        }
        return nil
    }

    // MARK: - Helper Methods
    private func index(for position: GridPosition) -> Int {
        position.x + position.y * grid.width
    }

    private func isDiagonal(_ a: GridPosition, _ b: GridPosition) -> Bool {
        abs(a.x - b.x) == 1 && abs(a.y - b.y) == 1
    }

    private func heuristic(_ a: GridPosition, _ b: GridPosition) -> Double {
        let dx = abs(a.x - b.x)
        let dy = abs(a.y - b.y)
        return straightCost * Double(dx + dy) + (diagonalCost - 2 * straightCost) * Double(min(dx, dy))
    }

    private func getNeighbors(of position: GridPosition) -> [GridPosition] {
        (grid as? GameGrid)?.neighbors(for: position) ?? []
    }

    private func reconstructPath(cameFrom: [GridPosition: GridPosition], current: GridPosition) -> [GridPosition] {
        var path = [current]
        var current = current
        while let next = cameFrom[current] {
            path.insert(next, at: 0)
            current = next
        }
        return path
    }
}

// MARK: - Node Structure
struct Node: Comparable, Hashable {
    let position: GridPosition
    let priority: Double

    static func < (lhs: Node, rhs: Node) -> Bool {
        lhs.priority < rhs.priority
    }
}
