import Foundation



/**
 - Warning: Obsolete. Use `Transitionable` instead.
*/
@available(*, unavailable, renamed: "Transitionable")
public typealias StateType = Transitionable



public extension StateMachine {
  /**
   - Warning: Obsolete. Subscribe to `publisher` instead.
  */
  @available(*, unavailable, message: "Subscribe to `publisher` instead.")
  struct StateTransitionDelegates {
    /**
     - Warning: Obsolete. Subscribe to `publisher` instead.
    */
    @available(*, unavailable, message: "Subscribe to `publisher` instead.")
    public var didTransition: ((_ from: State, _ to: State) -> Void)?
  }


  /**
   - Warning: Obsolete. Subscribe to `publisher` instead.
   */
  @available(*, unavailable, message: "Subscribe to `publisher` instead.")
  var delegates: StateTransitionDelegates {
    get { StateTransitionDelegates() }
    set { _ = newValue }
  }


  /**
   - Warning: Obsolete. Use `trasition(to:)` instead.
  */
  @available(*, unavailable, renamed: "transition(to:)")
  func queue(_ state: State) {}
}



/**
 - Warning: Obsolete. States are now assigned syncronously in the current run loop. Debug notifications are no longer needed.
*/
@available(*, unavailable, message: "States are now assigned syncronously in the current run loop. Debug notifications are no longer needed.")
public enum GauntletNotification {
  /**
   - Warning: Obsolete. States are now assigned syncronously in the current run loop. Debug notifications are no longer needed.
  */
  @available(*, unavailable, message: "States are now assigned syncronously in the current run loop. Debug notifications are no longer needed.")
  public static let willTransition = Notification.Name(rawValue: "GauntletWillTransitionNotification")
  
  
  /**
   - Warning: Obsolete. States are now assigned syncronously in the current run loop. Debug notifications are no longer needed.
  */
  @available(*, unavailable, message: "States are now assigned syncronously in the current run loop. Debug notifications are no longer needed.")
  public static let didTransition = Notification.Name(rawValue: "GauntletDidTransitionNotification")
}
