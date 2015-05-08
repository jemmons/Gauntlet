import Foundation

protocol StateMachineDataSourceProtocol{
  func shouldTransitionFrom(from:Self, to:Self)->Should<Self>
}
