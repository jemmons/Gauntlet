import Foundation


public class StateMachine<T: StateType> {
  /// This private stored property serves as the backing for the public computed `state` property. This lets us use `state` as a gatekeeper that filters out invalid transitions. It also gives us a (private) mechanisim to set state without triggering handlers.
  private var _state: T

  
  /// The state of the state machine. To transition states, set this property.
  /// Note that attempts to set this property to an invalid state (as determined by `StateType.shouldTransitionFrom(_,to:)`) are silently ignored.
  public var state: T {
    get {
      return _state
    }
    set { //Can't be an observer because we need the option to CONDITIONALLY set state
      delegateTransitionTo(newValue)
    }
  }
  

  /// Closure that gets called whenever `StateMachine` successfully transitions from one state to another.
  /// * Warning: There's a high likelihood a) the class using a given state machine will hold a strong reference to it and, b) the closure the class assigns to this property of the state machine will reference `self`. This will create a retain cycle if `self` isn't declared as `unowned` in a capture list. See [String Reference Cycles for Closures](https://developer.apple.com/library/prerelease/ios/documentation/Swift/Conceptual/Swift_Programming_Language/AutomaticReferenceCounting.html#//apple_ref/doc/uid/TP40014097-CH20-ID56).
  public var transitionHandler: (T,T)->Void = { _,_ in }


  /// Initializes the state machine with the given initial state.
  /// This could very easily also take a(n optional) `transitionHandler`, saving us a common assignment that will almost always take place directly after instantiation. But a common confusion I run in to using `StateMachine` is an inability to remember whether `transitionHandler` is called when setting the initial state or not. Keeping the assignment seperate makes the answer to this question obvious.
  public init(initialState: T) {
    _state = initialState //set the internal value so we don't need a special rule in «shouldTranistionFrom(_,to:)». Also avoids calling «transitionHandler».
  }
  
  
  private func delegateTransitionTo(to: T) {
    if state.shouldTransitionFrom(state, to:to){
      let from = state //If «T» is a mutable ref type, this will do Bad Things.
      _state = to //uses internal value to prevent looping.
      transitionHandler(from, to)
    }
  }
}
