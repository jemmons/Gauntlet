import Foundation



//This can be become a nested type of `StateMachine` in Swift 3.1.
/**
 Delegate tasks of `StateMachine`. Consumers can assign implementations to respond to lifecycle events.
 */
public struct StateTransitionDelegates<T: StateType> {
  /**
   Delegate closure that gets called whenever `StateMachine` successfully transitions from one state to another.
   
   * Warning: Like all delegates, there's a high likelihood the delegatee owns the delegator and retain cycles are a danger. If the closure references the delegatee (even as `self`), it should be declared `weak` in a capture list. See [String Reference Cycles for Closures](https://developer.apple.com/library/prerelease/ios/documentation/Swift/Conceptual/Swift_Programming_Language/AutomaticReferenceCounting.html#//apple_ref/doc/uid/TP40014097-CH20-ID56).
   */
  public var didTransition: ((_ from: T, _ to: T) -> Void)?
}
