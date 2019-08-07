import Foundation
import XCTest
import Gauntlet


class ExistentialTests : XCTestCase{
  enum State: Transitionable {
    case ready, working, success(String), failure(NSError)
    func shouldTransition(to: State) -> Bool {
      return true
    }
  }
  
  
  var machine = StateMachine(initialState: State.ready)
  
  
  func testInitialState(){
    switch machine.state{
    case .ready:
      XCTAssert(true)
    default:
      XCTFail("Not Ready")
    }
  }
}
