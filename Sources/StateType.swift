import Foundation


public protocol StateType{
  func shouldTransitionFrom(from:Self, to:Self)->Bool
}
