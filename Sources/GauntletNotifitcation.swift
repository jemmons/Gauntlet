import Foundation



/**
 Holds notification name constants. A client may want to define `GAUNTLET_POST_TEST_NOTIFICATIONS` and  observe notificationas with these names when testing.
 
 * seealso: "On Testing" in `StateMachine` documentation.
 */
public enum GauntletNotification {
  /**
   Name used to post notifications before transitions when `GAUNTLET_POST_TEST_NOTIFICATIONS` is defined in the environment.
   
   * seealso: "On Testing" in `StateMachine` documentation.
   */
  public static let willTransition = Notification.Name(rawValue: "GauntletWillTransitionNotification")
  
  
  /**
   Name used to post notifications after transitions when `GAUNTLET_POST_TEST_NOTIFICATIONS` is defined in the environment.
   
   * seealso: "On Testing" in `StateMachine` documentation.
   */
  public static let didTransition = Notification.Name(rawValue: "GauntletDidTransitionNotification")
}
