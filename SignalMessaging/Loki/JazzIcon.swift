
import CryptoSwift

private class RNG {
    private var seed: UInt
    private var initial: UInt
    
    init(seed: UInt) {
        self.seed = seed % 2147483647
        self.initial = self.seed
    }
    
    func next() -> UInt {
        let seed = (self.seed * 16807) % 2147483647
        self.seed = seed
        return seed
    }
    
    func nextFloat() -> Float {
        return Float(next() - 1) / 2147483647.0
    }
    
    func nextCGFloat() -> CGFloat {
        return CGFloat(nextFloat())
    }
    
    func reset() {
        seed = initial
    }
}


public class JazzIcon {
    private let generator: RNG
    
    // Colour palette
    private var colours: [UIColor] = [
        0x01888c, // Teal
        0xfc7500, // bright orange
        0x034f5d, // dark teal
        0xE784BA, // light pink
        0x81C8B6, // bright green
        0xc7144c, // raspberry
        0xf3c100, // goldenrod
        0x1598f2, // lightning blue
        0x2465e1, // sail blue
        0xf19e02, // gold
    ].map { UIColor(rgb: $0) }
    
    // Defaults
    private let shapeCount = 4
    private let wobble = 30
    
    init(seed: UInt, colours: [UIColor]? = nil) {
        self.generator = RNG(seed: seed)
        if let colours = colours {
            self.colours = colours
        }
    }
    
    convenience init(seed: String, colours: [UIColor]? = nil) {
        let hash = seed.md5()
        guard let number = UInt(hash.substring(to: min(hash.count, 12)), radix: 16) else {
            owsFailDebug("[JazzIcon] Failed to generate number from seed string: \(seed)")
            self.init(seed: 1234, colours: colours)
            return
        }
        
        self.init(seed: number, colours: colours)
    }
    
    public func generateLayer(ofSize diameter: CGFloat) -> CALayer {
        generator.reset()
        
        let newColours = hueShift(colours: colours)
        let shuffled = shuffle(newColours)
        
        let base = getSquareLayer(with: diameter, colour: shuffled[0].cgColor)
        base.masksToBounds = true
        
        for index in 0..<shapeCount {
            let layer = generateShapeLayer(diameter: diameter, colour: shuffled[index + 1].cgColor, index: index, total: shapeCount - 1)
            base.addSublayer(layer)
        }
        
        return base
    }
    
    private func getSquareLayer(with diameter: CGFloat, colour: CGColor? = nil) -> CAShapeLayer {
        let frame = CGRect(x: 0, y: 0, width: diameter, height: diameter)
        
        let layer = CAShapeLayer()
        layer.frame = frame
        layer.path = UIBezierPath(roundedRect: frame, cornerRadius: 0).cgPath
        layer.fillColor = colour
        return layer
    }
    
    private func generateShapeLayer(diameter: CGFloat, colour: CGColor, index: Int, total: Int) -> CALayer {
        let center = diameter / 2
        let firstRotation = generator.nextCGFloat()
        let angle = CGFloat.pi * 2 * firstRotation
        
        let a = diameter / CGFloat(total)
        let b: CGFloat = generator.nextCGFloat()
        let c = CGFloat(index) * a
        let velocity = a * b + c
        let translation = CGPoint(x: cos(angle) * velocity, y: sin(angle) * velocity)
    
        // Third random is a shape rotation ontop of all that
        let secondRotation = generator.nextCGFloat()
        let rotation = (firstRotation * 360.0) + (secondRotation * 180)
        let radians = rotation.rounded(toPlaces: 1) * CGFloat.pi / 180.0
        
        let layer = getSquareLayer(with: diameter, colour: colour)
        layer.position = CGPoint(x: center + translation.x, y: center + translation.y)
        layer.transform = CATransform3DMakeRotation(radians, 0, 0, center)
        
        return layer
    }
    
    private func shuffle<T>(_ array: [T]) -> [T] {
        var currentIndex = array.count
        var mutated = array
        while (currentIndex > 0) {
            let randomIndex = Int(generator.next()) % currentIndex
            currentIndex -= 1
            mutated.swapAt(currentIndex, randomIndex)
        }
        return mutated
    }
    
    private func hueShift(colours: [UIColor]) -> [UIColor] {
        let amount = generator.nextCGFloat() * 30 - CGFloat(wobble / 2);
        return colours.map { $0.adjust(hueBy: amount / 360.0) }
    }
}
