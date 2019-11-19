import Foundation



/**
 The “state” part of our finite state machine.
 
 Instances of the conforming type model the states of our system. Their implementations of `shouldTrasition(to:)` determine what transitions between states are allowed.
 
 - Note:
     In theory, this could be any type capable of calculating whether a transition between two instances of itself are legal. In practice, it’s almost always best to use an `enum`. For example:
 
     ```
     enum TrafficLight: Transitionable {
       case red, yellow, green
       
       func shouldTransition(to: Self) -> Bool {
         switch (self, to) {
         case (.red, green),
              (.green, .yellow),
              (.yellow, red):
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
   Defines whether a transition from `self` to the given state is valid.
   
   * parameter to: The type to potentially transition to.
   * returns: `true` if it’s legal to trasition from `self` to `to`. Otherwise, `false`.
   */
  func shouldTransition(to: Self) -> Bool
}
