import Foundation

public struct GauntletNotification {
  /// Notification name used to post notifications before transitions when `GAUNTLET_POST_TEST_NOTIFICATIONS` is defined in the environment. See: "On Testing" for more.
  public static let willTransition = Notification.Name(rawValue: "GauntletWillTransitionNotification")
  /// Notification name used to post notifications after transitions when `GAUNTLET_POST_TEST_NOTIFICATIONS` is defined in the environment. See: "On Testing" for more.
  public static let didTransition = Notification.Name(rawValue: "GauntletDidTransitionNotification")
}


//This can be become a nested type of `StateMachine` in Swift 3.1.
/// Callbacks `StateMachine` consumers can implement to respond to certain delegation tasks.
public struct StateTransitionDelegates<T: StateType> {
  /// Delegate closure that gets called whenever `StateMachine` successfully transitions from one state to another.
  /// * Warning: Like all delegates, there's a high likelihood the delegatee owns the delegator. If this is the case, and this closure references the delegatee with a strong `self`, it will create a retain cycle. The fix is to declare `self` as `weak` in a capture list. See [String Reference Cycles for Closures](https://developer.apple.com/library/prerelease/ios/documentation/Swift/Conceptual/Swift_Programming_Language/AutomaticReferenceCounting.html#//apple_ref/doc/uid/TP40014097-CH20-ID56).
  public var didTransition: ((_ from: T, _ to: T) -> Void)?
}



/// On Testing:
///
/// Often when testing, we'll want to assert that a state machine has made some transition. Because state machines should be private implementation details of their classes, and becasue state change happens asynchronously (or, at least, in the next cycle of the runloop), this can be difficult without sprinkling completion handlers throughout our code.
///
/// Instead, we can define the environment variable `GAUNTLET_POST_TEST_NOTIFICATIONS` in our testing scheme (any non-nil value will do), and subscribe to one or more of the following notification names:
///
/// * `GauntletNotification.willTransition`
/// * `GauntletNotification.didTransition`
///
/// Both will post a `userInfo` with the following values:
///
/// * `fromString`: String value of the `StateType` the `StateMachine` did/will transition from.
/// * `fromBox`: Boxed version of the `StateType` the `StateMachine` did/will transition from. Use the `value` property to unbox the `StateType`.
/// * `toString`: String value of the `StateType` the `StateMachine` did/will transition to.
/// * `toBox`: Boxed version of the `StateType` the `StateMachine` did/will transitioning to. Use the `value` property to unbox the `StateType`.
public class StateMachine<T: StateType> {
  /// Callbacks `StateMachine` consumers can implement to respond to certain delegation tasks.
  public var delegates = StateTransitionDelegates<T>()
  
  
  /// The current state of the state machine. Read-only.
  public private(set) var state: T


  /// Initializes the state machine with the given initial state.
  /// This could very easily also take a(n optional) `transitionHandler`, saving us a common assignment that will almost always take place directly after instantiation. But I'm always forgetting whether `transitionHandler` is called when setting the initial state or not. Keeping the assignment seperate makes the answer to this question obvious.
  public init(initialState: T) {
    state = initialState //set the internal value so we don't need a special rule in «shouldTranistionFrom(_,to:)». Also avoids calling «transitionHandler».
  }
  
  
  /// Use this method to transition states. It first take the given `state` and determine its validity via `StateType.shouldTransitionFrom(_,to:)`. If it is, it transitions the machine to it, calling `transformationHandler` once complete. If not, the given `state` is silently ignored.
  /// * parameter state: The state to transition to.
  /// * Note: This method queues the state transition to happen on the next pass of the run loop. Thus, it's safe to call `queue(_)` from `transitionHandler` without concern for the stack. However, this also means that even valid calls to `queue(_)` will not be reflected immediately in the state machine:
  /// ````
  /// let machine = StateMachine(initialState: State.ready)
  /// machine.queue(State.fetch)
  /// machine.state //> State.ready
  /// ````
  public func queue(_ state: T) {
    OperationQueue.main.addOperation { [weak self] () -> Void in
      self?.delegateTransition(to: state)
    }
  }
  
  
  private func delegateTransition(to: T) {
    if T.shouldTransition(from: state, to: to) {
      let from = state //If «T» is a mutable ref type, this can do Bad Things.
      state = to
      postNotification(withName: GauntletNotification.willTransition, userInfo: makeUserInfo(withFrom: from, to: to))
      delegates.didTransition?(from, to)
      postNotification(withName: GauntletNotification.didTransition, userInfo: makeUserInfo(withFrom: from, to: to))
    }
  }
}



private extension StateMachine {
  func postNotification(withName name: Notification.Name, userInfo: [AnyHashable: Any]) {
    guard testingEnvironmentDefined else {
      return
    }
    NotificationCenter.default.post(name: name, object: self, userInfo: userInfo)
  }
  
  
  func makeUserInfo(withFrom from: T, to: T) -> [AnyHashable: Any] {
    return ["fromString": String(describing: from),
            "fromBox": StateBox(value:from),
            "toString": String(describing: to),
            "toBox": StateBox(value:to)]
  }

  
  var testingEnvironmentDefined: Bool {
    return ProcessInfo.processInfo.environment["GAUNTLET_POST_TEST_NOTIFICATIONS"] != nil
  }
}
