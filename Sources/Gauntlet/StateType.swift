import Foundation


/**
 Deprecated. Use `Transitionable` instead.
 */
@available(*, deprecated, message: "`StateType` has been renamed `Transitionable` to better reflect its semeantics." )
public typealias StateType = Transitionable



/**
 Describes the primary unit of state in a `StateMachine`. In theory, this could be any type capable of calculating whether a transition between two instances of itself is legal. In practice, it’s almost always an `enum`:
 
 ```
 enum MyState: Transitionable {
   case Red, Yellow, Green 
   func shouldTransition(to: MyState) -> Bool {
     switch (self, to) {
     case (.Red, Green), (.Green, .Yellow), (.Yellow, Red):
       return true
     default:
       return false
     }
   }
 }
 ```
*/
public protocol Transitionable {
  /**
   Defines whether a transition between two states is legal or illegal.
   
   * parameter to: The type to potentially transition to.
   * returns: `true` if it’s legal to trasition from `self` to `to`. Otherwise, `false`.
   */
  func shouldTransition(to: Self) -> Bool
}
