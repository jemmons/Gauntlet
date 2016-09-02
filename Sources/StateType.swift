import Foundation


/// The primary unit of state in a `StateMachine`. In theory, this could be anything that can determin whether a transition should happen between two instances of itself. In practice, this always an `enum` like so:
///
///     enum MyState: StateType {
///       case Red, Yellow, Green
///       func shouldTransition(from from: MyState, to: MyState) -> Bool {
///         switch (from, to) {
///         case (.Red, Green), (.Green, .Yellow), (.Yellow, Red):
///           return true
///         default:
///           return false
///       }
///     }
public protocol StateType {
  static func shouldTransition(from: Self, to: Self) -> Bool
}



/// A type to box non-class `StateType`s in classes for better ObjC portability. Curretnly this is only used for test notifications (see: "On Testing" in `StateMachine.swift`).
public class StateBox<T:StateType> {
  public let value: T
  init(value: T) {
    self.value = value
  }
}
