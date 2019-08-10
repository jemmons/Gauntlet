import XCTest
import Gauntlet



class NotificationTests: XCTestCase {
  enum State: Transitionable {
    case ready, working
    func shouldTransition(to: NotificationTests.State) -> Bool {
      switch (self, to) {
      case (.ready, .working):
        return true
      default:
        return false
      }
    }
  }
  
  
  let machine = StateMachine<State>(initialState: .ready)
  
  
  func testNotifications() {
    expectation(forNotification: GauntletNotification.willTransition, object: machine) { notification in
      XCTAssertEqual(State.ready, self.machine.state)
      let info = notification.userInfo
      return (info!["from"] as! State) == State.ready
        && (info!["to"] as! State) == State.working
    }
    expectation(forNotification: GauntletNotification.didTransition, object: machine) { notification in
      XCTAssertEqual(State.working, self.machine.state)
      let info = notification.userInfo
      return (info!["from"] as! State) == State.ready
        && (info!["to"] as! State) == State.working
    }
    machine.queue(.working)
    
    waitForExpectations(timeout: 1, handler: nil)
  }
}
