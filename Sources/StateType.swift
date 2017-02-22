import Foundation


/**
 Describes the primary unit of state in a `StateMachine`. In theory, this could be any type capable of calculating whether a transition between two instances of itself is legal. In practice, it is always an `enum`:
 
 ```
 enum MyState: StateType {
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
public protocol StateType {
  /**
   Defines what it means for a transition between states to be legal or illegal.
   
   * parameter to: The state to potentially transition to.
   * returns: `true` if it’s legal to trasition from `self` to `to`. Otherwise, `false`.
   */
  func shouldTransition(to: Self) -> Bool
}
