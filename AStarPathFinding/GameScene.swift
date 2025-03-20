import SpriteKit
import MSKTiled

class GameScene: MSKTiledMapScene {

    var firstTile: MSKTiledTile?
    let pathNode = SKNode()
    var pathFinder: AStarPathfinder!

    init(size: CGSize) {
        let zPositionPerNamedLayer = [
            "base": 1,
            "obstacles": 2
        ]
        super.init(size: size,
                   tiledMapName: "exampleTiled",
                   minimumCameraScale: 0.12,
                   maximumCameraScale: nil,
                   zPositionPerNamedLayer: zPositionPerNamedLayer)
        guard let obstacleLayer = getLayer(name: "obstacles") else {
            fatalError("")
        }
        addChild(pathNode)
        pathNode.zPosition = 40

        updatePathGraphUsing(layer: obstacleLayer, diagonalsAllowed: true)

        var obstacles: Set<GridPosition> = []
        for column in 0..<obstacleLayer.numberOfColumns {
            for row in 0..<obstacleLayer.numberOfRows {
                if obstacleLayer.tileDefinition(atColumn: column, row: row) != nil {
                    obstacles.insert(.init(x: column, y: row))
                }
            }
        }

        let nonWalkableTileTexture = SKTexture(imageNamed: "icon_x")
        for obstacle in obstacles {
            let node = SKSpriteNode(texture: nonWalkableTileTexture)
            node.position = obstacleLayer.centerOfTile(atColumn: obstacle.x, row: obstacle.y)
            node.zPosition = 30
            addChild(node)
        }
        let grid = GameGrid(width: obstacleLayer.numberOfColumns,
                            height: obstacleLayer.numberOfRows,
                            obstacles: obstacles)
        pathFinder = AStarPathfinder(grid: grid)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        let touchLocationInScene = touches.first!.location(in: self)
        guard let tile = getTileFromPositionInScene(position: touchLocationInScene) else {
            return
        }
        if !isValidPathTile(tile: tile) {
            return
        }
        if let firstTile = firstTile {
            var startTime = DispatchTime.now()
            if let path = getPath(fromTile: firstTile, toTile: tile) {
                markTime(startTime: startTime, label: "time to find GKGridGraph path")
                print("steps in GKGridGraph path: \(path.count)")
                for point in path {
                    addIndicatorToPathNodeAt(tile: .init(column: Int(point.column), row: Int(point.row)),
                                             color: .red)
                }
                let start = GridPosition(x: firstTile.column, y: firstTile.row)
                let goal = GridPosition(x: tile.column, y: tile.row)
                startTime = DispatchTime.now()
                if let path = pathFinder.findPath(from: start, to: goal) {
                    markTime(startTime: startTime, label: "time to find custom Astar path")
                    print("steps in Astar path: \(path.count)")
                    for point in path {
                        addIndicatorToPathNodeAt(tile: .init(column: Int(point.x), row: Int(point.y)),
                                                 color: .green)
                    }
                }
            }
            self.firstTile = nil
        } else {
            pathNode.removeAllChildren()
            firstTile = tile
            addIndicatorToPathNodeAt(tile: tile, color: .red)
        }
    }

    private func addIndicatorToPathNodeAt(tile: MSKTiledTile, color: SKColor) {
        let shapeNode = SKShapeNode(circleOfRadius: 16)
        shapeNode.fillColor = color
        shapeNode.alpha = 0.6
        shapeNode.position = getPositionInSceneFromTile(tile: tile)
        pathNode.addChild(shapeNode)
    }
}

func markTime(startTime: DispatchTime, label: String) {
    let elapsedTime = DispatchTime.now().uptimeNanoseconds - startTime.uptimeNanoseconds
    let elapsedTimeInMilliSeconds = Double(elapsedTime) / 1_000_000.0
    print("\(label): \(elapsedTimeInMilliSeconds)")
}
