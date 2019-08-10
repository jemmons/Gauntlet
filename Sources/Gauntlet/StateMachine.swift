import Foundation

#if canImport(Combine)
import Combine
#endif


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
@propertyWrapper
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
  
  
  @available(iOS 13, macOS 10.15, *)
  lazy private var _publisher = PassthroughSubject<(from: State, to: State), Never>()


  /**
   Publishes state changes after valid transitions.
   
   Consumers can subscribe (in the `Combine` sense) to `publisher` to recieve a set of `State` values immediately after every valid transition:
   
   ```
   let machine = StateMachine(initialState: State.ready)
   //...
   let subscription = machine.publisher.sink { from, to in
     // stuff to do when `machine` has transitioned
     // to or from particular states...
   }
   ```
   
   - Note: In systems that support it (iOS 13, macOS Catalina), this can be used as a replacement for the somewhat hackey practice of assigning a closure to `delegates.didTransition`.
   
       At some point in the future `Combine` will have a larger installed base, `publisher` will be the blessed way to respond to state changes, and the `delegates` property will be deprecated with extreme prejudice.
   */
  @available(iOS 13, macOS 10.15, *)
  public var publisher: AnyPublisher<(from: State, to: State), Never> {
    return _publisher.eraseToAnyPublisher()
  }
  
  
  public var wrappedValue: State {
    get { state }
    set { queue(newValue) }
  }
  
  
  @available(iOS 13, macOS 10.15, *)
  public var projectedValue: AnyPublisher<(from: State, to: State), Never> {
    get { publisher }
  }
    
  
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
  
  
  convenience public init(wrappedValue: State) {
    self.init(initialState: wrappedValue)
  }
  
  
  /**
   Use this method to transition states.
   
   First, the validity of a transition to the given `state` is determined via a call to its `shouldTransitionFrom(_,to:)`. If it is valid, the machine tranisitons to it, calling `didTransition(from:to:)` once complete. If not, the given `state` is silently ignored.
   
   - Attention:
       This method queues the state transition to happen on the next pass of the run loop. Thus, it's safe to call `queue(_)` from `didTransition(from:to:)` without concern for the stack. However, this also means that even calls to `queue(_)` with valid transition targets will not be reflected immediately in the state:
   
       ```
       let machine = StateMachine(initialState: State.ready)
       machine.queue(State.fetch)
       machine.state //> still `State.ready`
       ```
   
   - Parameter state: The state to transition to.
   */
  public func queue(_ state: State) {
    OperationQueue.main.addOperation { [weak self] () -> Void in
      self?.delegateTransition(to: state)
    }
  }
  
  
  private func delegateTransition(to: State) {
    if state.shouldTransition(to: to) {
      let from = state
      postNotification(GauntletNotification.willTransition, from: from, to: to)
      state = to
      if #available(iOS 13, macOS 10.15, *) {
        _publisher.send((from: from, to: to))
      }
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
