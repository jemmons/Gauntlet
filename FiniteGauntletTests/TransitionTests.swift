import Foundation
import XCTest
import FiniteGauntlet


class TransitionTests : XCTestCase{
  enum State: StateType {
    case Ready, Working, Success(String), Failure(NSError)
    func shouldTransitionFrom(from: State, to: State) -> Bool {
      switch (from, to) {
      case
      (.Ready, .Ready),
      (.Ready, .Working):
        return true
      default:
        return false
      }
    }
  }


  var machine = StateMachine(initialState: State.Ready)

  
  func testValidTransition(){
    machine.transitionHandler = { from, to in
      if case (.Ready, .Working) = (from, to) {
        XCTAssert(true)
      } else {
        XCTFail("Transition to valid state didn't trigger handler.")
      }
    }
    machine.state = .Working
  }
  
  
  func testInvalidTransition(){
    machine.transitionHandler = { from, to in
      if case (.Ready, .Success) = (from, to) {
        XCTFail("Transition is invalid")
      }
    }
    machine.state = .Success("foo")
  }

  
  func testValidDoubleTransition(){
    machine.transitionHandler = { from, to in
      if case (.Ready, .Ready) = (from, to) {
        XCTAssert(true)
      } else {
        XCTFail("Transition to same state didn't trigger handler.")
      }
    }
    machine.state = .Ready
  }
  
  
  func testInvaludDoubleTransition(){
    machine.transitionHandler = { from, to in
      if case (.Working, .Working) = (from, to){
        XCTFail("Transition is invalid.")
      }
    }
    machine.state = .Working
    machine.state = .Working
  }
}

