import Foundation
import XCTest
import Gauntlet


class ExistentialTests : XCTestCase{
  enum State: StateType{
    case Ready, Working, Success(String), Failure(NSError)
    static func shouldTransition(from: State, to: State) -> Bool {
      return true
    }
  }
  
  
  var machine = StateMachine(initialState: State.Ready)
  
  
  func testInitialState(){
    switch machine.state{
    case .Ready:
      XCTAssert(true)
    default:
      XCTFail("Not Ready")
    }
  }
}
