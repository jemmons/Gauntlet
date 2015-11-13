import Foundation

public protocol StateMachineDataSourceProtocol{
  func shouldTransitionFrom(from:Self, to:Self)->Bool
}
