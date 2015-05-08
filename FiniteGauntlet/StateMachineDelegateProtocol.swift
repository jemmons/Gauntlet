import Foundation

public protocol StateMachineDelegateProtocol: class{
  typealias StateType:StateMachineDataSourceProtocol
  func didTransitionFrom(from:StateType, to:StateType)
}
