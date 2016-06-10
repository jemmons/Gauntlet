import Foundation

/// On Testing:
///
/// Often when testing, we'll want to assert that a state machine has made some transition. Because state machines should be private implementation details of their classes, and becasue state change happens asynchronously (or, at least, in the next cycle of the runloop), this can be difficult without sprinkling completion handlers throughout our code.
///
/// Instead, we can define the environment variable `GAUNTLET_POST_TEST_NOTIFICATIONS` in our testing scheme (any non-nil value will do), and subscribe to one or more of the following notifications:
///
/// * `GauntletWillTransitionNotification`
/// * `GauntletDidTransitionNotification`
///
/// Both will post a `userInfo` with the following values:
///
/// * `fromString`: String value of the `StateType` the `StateMachine` did/will transition from.
/// * `fromBox`: Boxed version of the `StateType` the `StateMachine` did/will transition from. Use the `value` property to unbox the `StateType`.
/// * `toString`: String value of the `StateType` the `StateMachine` did/will transition to.
/// * `toBox`: Boxed version of the `StateType` the `StateMachine` did/will transitioning to. Use the `value` property to unbox the `StateType`.
public class StateMachine<T: StateType> {
  /// The current state of the state machine. Read-only.
  public private(set) var state: T


  /// Closure that gets called whenever `StateMachine` successfully transitions from one state to another.
  /// * Warning: There's a high likelihood a) the class using a given state machine will hold a strong reference to it and, b) the closure the class assigns to this property will reference `self`. This will create a retain cycle if `self` isn't declared as `unowned` in a capture list. See [String Reference Cycles for Closures](https://developer.apple.com/library/prerelease/ios/documentation/Swift/Conceptual/Swift_Programming_Language/AutomaticReferenceCounting.html#//apple_ref/doc/uid/TP40014097-CH20-ID56).
  public var transitionHandler: (T,T)->Void = { _,_ in }


  /// Initializes the state machine with the given initial state.
  /// This could very easily also take a(n optional) `transitionHandler`, saving us a common assignment that will almost always take place directly after instantiation. But I'm always forgetting whether `transitionHandler` is called when setting the initial state or not. Keeping the assignment seperate makes the answer to this question obvious.
  public init(initialState: T) {
    state = initialState //set the internal value so we don't need a special rule in «shouldTranistionFrom(_,to:)». Also avoids calling «transitionHandler».
  }
  
  
  /// Use this method to transition states. It first take the given `state` and determine its validity via `StateType.shouldTransitionFrom(_,to:)`. If it is, it transitions the machine to it, calling `transformationHandler` once complete. If not, the given `state` is silently ignored.
  /// * parameter state: The state to transition to.
  /// * Note: This method queues the state transition to happen on the next pass of the run loop. Thus, it's safe to call `queueState(_)` from `transitionHandler` without concern for the stack. However, this also means that even valid calls to `queueState(_)` will not be reflected immediately in the state machine:
  /// ````
  /// let machine = StateMachine(initialState: State.Ready)
  /// machine.queueState(State.Fetch)
  /// machine.state //> State.Ready
  /// ````
  public func queueState(state: T) {
    NSOperationQueue.mainQueue().addOperationWithBlock { [weak self] () -> Void in
      self?.delegateTransitionTo(state)
    }
  }
  
  
  private func delegateTransitionTo(to: T) {
    if T.shouldTransition(state, to: to) {
      let from = state //If «T» is a mutable ref type, this can do Bad Things.
      state = to
      postNotification(withName: "GauntletWillTransitionNotification", userInfo: makeUserInfo(withFrom: from, to: to))
      transitionHandler(from, to)
      postNotification(withName: "GauntletDidTransitionNotification", userInfo: makeUserInfo(withFrom: from, to: to))
    }
  }
}



private extension StateMachine {
  func postNotification(withName name:String, userInfo: [NSObject: AnyObject]) {
    guard testingEnvironmentDefined else {
      return
    }
    NSNotificationCenter.defaultCenter().postNotificationName(name, object: self, userInfo: userInfo)
  }
  
  
  private func makeUserInfo(withFrom from: T, to: T) -> [NSObject: AnyObject] {
    return ["fromString": String(from), "fromBox": StateBox(value:from), "toString": String(to), "toBox": StateBox(value:to)]
  }

  
  private var testingEnvironmentDefined: Bool {
    return NSProcessInfo.processInfo().environment["GAUNTLET_POST_TEST_NOTIFICATIONS"] != nil
  }
}
