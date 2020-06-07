//
//  CircleControl.swift
//  WheelV
//
//  Created by Surjeet on 05/06/20.
//  Copyright © 2020 Surjeet. All rights reserved.
//

import UIKit

protocol CircularControlDelegate: class {
    func onValueChanged(_ selectedIndex: Int)
}

public class CircularControl: UIControl {
    private var backingValue: CGFloat = 0.0

    /** Layer renderer **/
    private let circleRenderer = CircleRenderer()
    private var containerView = UIView()
    
    private var titleArray: [String]?
    private var colorArray: [UIColor]?

    var delegate: CircularControlDelegate?
    
    private override init(frame: CGRect) {
        super.init(frame: frame)
    }

    internal required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    init(frame: CGRect, items:[String], colors:[UIColor]) {
        super.init(frame: frame)
        titleArray = items
        colorArray = colors
        initilize()
    }
    
    func initilize() {
        
        containerView.isUserInteractionEnabled = false
        containerView.frame = self.bounds
        self.addSubview(containerView)
        createSubLayers()
    }
    
    /** Set bounds of all the sub layers **/
    func createSubLayers() {
        circleRenderer.update(bounds: bounds, titleArray: titleArray, colorArray: colorArray)
        containerView.layer.addSublayer(circleRenderer.circleLayer)
    }
    
    var deltaAngle: CGFloat = 0
    var startTransform: CGAffineTransform?
    
    override public func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        let touchPoint = touch.location(in: self)
        
        let dx = touchPoint.x - containerView.center.x
        let dy = touchPoint.y - containerView.center.y
        deltaAngle = atan2(dy, dx)
        startTransform = containerView.transform
        return true
    }
    
    override public func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        
        let touchPoint = touch.location(in: self)
        
        let dx = touchPoint.x - containerView.center.x
        let dy = touchPoint.y - containerView.center.y
        let ang = atan2(dy, dx)
        let diff = deltaAngle - ang
        containerView.transform = startTransform!.rotated(by: -diff)
        return true
    }
    
    override public func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        let radian = CGFloat(atan2f(Float(containerView.transform.b), Float(containerView.transform.a)))
        
        var newVal: CGFloat = 0.0
        var currentValue: Int = 0
        
        for shape in circleRenderer.shapeArray {
            if shape.minValue > 0 && shape.maxValue < 0 {
                if shape.maxValue > radian || shape.minValue < radian {
                    if radian > 0 {
                        newVal = radian - CGFloat(Double.pi)
                    } else {
                        newVal = CGFloat(Double.pi) + radian
                    }
                    currentValue = shape.value
                }
            } else if (radian > shape.minValue && radian < shape.maxValue) {
                newVal = radian - shape.midValue
                currentValue = shape.value
            }
        }
        UIView.animate(withDuration: 0.2) {
            self.containerView.transform = self.containerView.transform.rotated(by: -newVal)
        }
        delegate?.onValueChanged(currentValue)
    }
    
}

private class CircleRenderer {
    /** Layers **/
    let circleLayer = CALayer()
    var shapeArray = [Shape]()
    
    /** Initialize the colors **/
    init() {
        circleLayer.isOpaque = true
        circleLayer.backgroundColor = UIColor.clear.cgColor
    }

    /** Draw the segment layers paths **/
    func update(titleArray: [String], colorArray: [UIColor]?) {
        let center = CGPoint(x: circleLayer.bounds.size.width / 2.0, y: circleLayer.bounds.size.height / 2.0)
        let radius:CGFloat = min(circleLayer.bounds.size.width, circleLayer.bounds.size.height) / 2
        let segmentSize = CGFloat((Double.pi*2) / Double(titleArray.count))
        
        for i in 0..<titleArray.count {
            let startAngle = segmentSize*CGFloat(i) - segmentSize/2
            let endAngle = segmentSize*CGFloat(i+1) - segmentSize/2
            let midAngle = (startAngle+endAngle)/2
            
            let shapeLayer = CAShapeLayer()
            if let colors = colorArray, colors.count > i {
                shapeLayer.fillColor = colors[i].cgColor
            } else {
                shapeLayer.fillColor = UIColor.random.cgColor
            }
            
            let bezierPath = UIBezierPath(arcCenter: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
            bezierPath.addLine(to: center)
            shapeLayer.path = bezierPath.cgPath
            
            let position = CGPoint(x: center.x + radius/1.6 * cos(midAngle), y: center.y + radius/1.6 * sin(midAngle))
            let maxWidth = radius - 50
            let height = min(titleArray[i].height(withConstrainedWidth: maxWidth, font: UIFont.systemFont(ofSize: 15)), 40)
            
            let textLayer = CATextLayer()
            textLayer.frame = CGRect(x: 0, y: 0, width: maxWidth, height: height)
            textLayer.position = position
            textLayer.fontSize = 15
            textLayer.contentsScale = UIScreen.main.scale
            textLayer.alignmentMode = .center
            textLayer.string = titleArray[i]
            textLayer.isWrapped = true
            textLayer.backgroundColor = UIColor.clear.cgColor
            textLayer.foregroundColor = UIColor.white.cgColor
            textLayer.transform = CATransform3DMakeRotation(midAngle, 0.0, 0.0, 1.0)
            shapeLayer.addSublayer(textLayer)
            circleLayer.addSublayer(shapeLayer)
        }
    }

    /** Update the frame and position of the layers **/
    func update(bounds: CGRect, titleArray: [String]?, colorArray: [UIColor]?) {
        let position = CGPoint(x: bounds.width / 2.0, y: bounds.height / 2.0)

        circleLayer.position = position
        circleLayer.bounds = bounds

        guard let titles = titleArray else {return}
        buildShapeObjects(titles.count)
        update(titleArray: titles, colorArray: colorArray)
    }
    
    func buildShapeObjects(_ segments: Int) {
        let width = CGFloat(Double.pi*2/Double(segments))
        var mid: CGFloat = 0
        
        for i in 0..<segments {
            let shape = Shape()
            shape.midValue = mid
            shape.minValue = mid - width/2
            shape.maxValue = mid + width/2
            shape.value = i
       
            if segments % 2 == 0 { // Even Nums
                if shape.maxValue-width < -CGFloat(Double.pi) {
                    mid = CGFloat(Double.pi)
                    shape.midValue = mid
                    shape.minValue = CGFloat(fabsf(Float(shape.maxValue)))
                }
                mid -= width
            } else {  // Odd Nums
                mid -= width
                if mid < -CGFloat(Double.pi) {
                    mid = -mid
                    mid -= width
                }
            }
            shapeArray.append(shape)
        }
    }
}


class Shape: NSObject {
    var minValue: CGFloat = 0
    var maxValue: CGFloat = 0
    var midValue: CGFloat = 0
    var value: Int = 0
}

extension UIColor {
    static var random: UIColor {
        return .init(hue: .random(in: 0...1), saturation: 1, brightness: 1, alpha: 1)
    }
}

extension CGRect {
    var center: CGPoint { return CGPoint(x: midX, y: midY) }
}

extension Double {
    func degreesToRadians () -> Double {
        return self * .pi / 180.0
    }

    func radiansToDegrees () -> Double {
        return self * 180.0 / .pi
    }
}

extension String {
    func height(withConstrainedWidth width: CGFloat, font: UIFont) -> CGFloat {
        let constraintRect = CGSize(width: width, height: .greatestFiniteMagnitude)
        let boundingBox = self.boundingRect(with: constraintRect, options: .usesLineFragmentOrigin, attributes: [NSAttributedString.Key.font: font], context: nil)
        return ceil(boundingBox.height)
    }

    func width(withConstrainedHeight height: CGFloat, font: UIFont) -> CGFloat {
        let constraintRect = CGSize(width: .greatestFiniteMagnitude, height: height)
        let boundingBox = self.boundingRect(with: constraintRect, options: .usesLineFragmentOrigin, attributes: [NSAttributedString.Key.font: font], context: nil)

        return ceil(boundingBox.width)
    }
}