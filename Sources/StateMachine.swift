import Foundation


public class StateMachine<T: StateType> {
  /// The current state of the state machine. Read-only.
  public private(set) var state: T

  /// Use this method to transition states. It first take the given `state` and determine its validity via `StateType.shouldTransitionFrom(_,to:)`. If it is, it transitions the machine to it, calling `transformationHandler` once complete. If not, the given `state` is silently ignored.
  /// * parameter state: The state to transition to.
  /// * Note: This method queues the state transition to happen on the next pass of the run loop. Thus, it's safe to call `queueState(_)` from `transitionHandler` without concern for the stack. However, this also means that even valid calls to `queueState(_)` will not be reflected immediately in the state machine:
  /// ````
  /// let machine = StateMachine(initialState: State.Ready)
  /// machine.queueState(State.Fetch)
  /// machine.state //> State.Ready
  /// ````
  public func queueState(state: T) {
    NSOperationQueue.mainQueue().addOperationWithBlock { () -> Void in
      self.delegateTransitionTo(state)
    }
  }
  

  /// Closure that gets called whenever `StateMachine` successfully transitions from one state to another.
  /// * Warning: There's a high likelihood a) the class using a given state machine will hold a strong reference to it and, b) the closure the class assigns to this property will reference `self`. This will create a retain cycle if `self` isn't declared as `unowned` in a capture list. See [String Reference Cycles for Closures](https://developer.apple.com/library/prerelease/ios/documentation/Swift/Conceptual/Swift_Programming_Language/AutomaticReferenceCounting.html#//apple_ref/doc/uid/TP40014097-CH20-ID56).
  public var transitionHandler: (T,T)->Void = { _,_ in }


  /// Initializes the state machine with the given initial state.
  /// This could very easily also take a(n optional) `transitionHandler`, saving us a common assignment that will almost always take place directly after instantiation. But I'm always forgetting whether `transitionHandler` is called when setting the initial state or not. Keeping the assignment seperate makes the answer to this question obvious.
  public init(initialState: T) {
    state = initialState //set the internal value so we don't need a special rule in «shouldTranistionFrom(_,to:)». Also avoids calling «transitionHandler».
  }
  
  
  private func delegateTransitionTo(to: T) {
    if state.shouldTransitionFrom(state, to:to){
      let from = state //If «T» is a mutable ref type, this will do Bad Things.
      state = to
      transitionHandler(from, to)
    }
  }
}
