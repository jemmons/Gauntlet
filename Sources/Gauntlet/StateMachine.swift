import Foundation



/**
 On Testing:
 
 Often when testing, we'll want to assert that a state machine has made some transition. Because state machines should be private implementation details of their classes, and becasue state change happens asynchronously (or, at least, in the next cycle of the runloop), this can be difficult without sprinkling completion handlers throughout our code.
 
 Instead, we can define the environment variable `GAUNTLET_POST_TEST_NOTIFICATIONS` in our testing scheme (any non-nil value will do), and subscribe to one or more of the following notification names:
 
 * `GauntletNotification.willTransition`
 * `GauntletNotification.didTransition`
 
 Both will post a `userInfo` with the following values:
 
 * `from`: The `StateType` the `StateMachine` did/will transition from.
 * `to`: The `StateType` the `StateMachine` did/will transition to.
 */
public class StateMachine<State> where State: Transitionable {
  /**
   Delegate tasks of `StateMachine`. Consumers can assign implementations to respond to lifecycle events.
   */
  public struct StateTransitionDelegates {
    /**
     Delegate closure that gets called whenever `StateMachine` successfully transitions from one state to another.

     - Note:
         Why assign a closure for delegated functionality instead of the more standard “set a reference to a class that conforms to a delegate protocol”? Because it’s important the states passed to the delegate method have the same type as `State` (relative to the `StateMachine` class).
     
         To do this with a protocol is a bit of a mess because it involves associated types. This has gotten better with conditional conformance, but we still have to make it a top-level generic type, and that’s still ugly (it requrires we give a delegate type even if we don’t use one, it can’t infer the type if we don’t add the delegate as an initialization parameter, etc).
     
     - Warning:
         Like all delegates, there's a high likelihood the delegatee owns the delegator and retain cycles are a danger. If the closure references the delegatee (even as `self`), it should be declared `weak` in a capture list. See [String Reference Cycles for Closures](https://developer.apple.com/library/prerelease/ios/documentation/Swift/Conceptual/Swift_Programming_Language/AutomaticReferenceCounting.html#//apple_ref/doc/uid/TP40014097-CH20-ID56).
     */
    public var didTransition: ((_ from: State, _ to: State) -> Void)?
  }

  
  /**
   Consumers can assign implementations to protperties of `delegates` to respond to lifecycle events.
   
   - Note:
       Why assign a closure for delegated functionality instead of the more standard “set a reference to a class that conforms to a delegate protocol”? Because it’s important the states passed to the delegate method have the same type as `State` (relative to the `StateMachine` class).
       
       To do this with a protocol is a bit of a mess because it involves associated types. This has gotten better with conditional conformance, but we still have to make it a top-level generic type, and that’s still ugly (it requrires we give a delegate type even if we don’t use one, it can’t infer the type if we don’t add the delegate as an initialization parameter, etc).
   */
  public var delegates = StateTransitionDelegates()
  
  
  /**
   The current state of the state machine. Read-only.
   */
  public private(set) var state: State


  /**
   Initializes the state machine with the given initial state.
   
   * note: This could very easily also take a(n optional) `didTransition` handler, saving us a common assignment that will almost always take place directly after instantiation. But I'm always forgetting whether `didTransition` is called when setting initial state or not. Keeping the assignment seperate makes the answer obvious.
   */
  public init(initialState: State) {
    state = initialState //set the internal value so we don't need a special rule in «shouldTranistionFrom(_,to:)». Also avoids calling «didTransition».
  }
  
  
  /**
   Use this method to transition states. It first take the given `state` and determine its validity via `StateType.shouldTransitionFrom(_,to:)`. If it is, it transitions the machine to it, calling `transformationHandler` once complete. If not, the given `state` is silently ignored.
   
   * parameter state: The state to transition to.
   * attention: This method queues the state transition to happen on the next pass of the run loop. Thus, it's safe to call `queue(_)` from `didTransition` without concern for the stack. However, this also means that even valid calls to `queue(_)` will not be reflected immediately in the state machine:
   
   ```
   let machine = StateMachine(initialState: State.ready)
   machine.queue(State.fetch)
   machine.state //> State.ready
   ```
   */
  public func queue(_ state: State) {
    OperationQueue.main.addOperation { [weak self] () -> Void in
      self?.delegateTransition(to: state)
    }
  }
  
  
  private func delegateTransition(to: State) {
    if state.shouldTransition(to: to) {
      let from = state
      state = to
      postNotification(GauntletNotification.willTransition, from: from, to: to)
      delegates.didTransition?(from, to)
      postNotification(GauntletNotification.didTransition, from: from, to: to)
    }
  }
}



private extension StateMachine {
  func postNotification(_ name: Notification.Name, from: State, to: State) {
    guard Helper.isTestingEnvironmentDefined else {
      return
    }
    NotificationCenter.default.post(name: name, object: self, userInfo: makeUserInfo(from: from, to: to))
  }
  
  
  private func makeUserInfo(from: State, to: State) -> [AnyHashable: Any] {
    return ["from": from,
            "to": to]
  }
}



private enum Helper {
  static var isTestingEnvironmentDefined: Bool {
    return ProcessInfo.processInfo.environment["GAUNTLET_POST_TEST_NOTIFICATIONS"] != nil
  }
}
