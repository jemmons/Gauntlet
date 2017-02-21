import Foundation



/**
 A type to box non-class `StateType`s in classes for better ObjC portability. Curretnly this is only used to box states in the `userInfo` object of an `Notification`.
 
 * seealso: “On Testing” in `StateMachine` documentation.
 */
public class StateBox<T: StateType> {
  /**
   Property holding the boxed type.
   */
  public let value: T
  
  
  
  /**
   Creates a new `StateBox`.
   
   * parameter value: The value to box.
   */
  init(value: T) {
    self.value = value
  }
}
