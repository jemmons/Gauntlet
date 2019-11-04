import Foundation
import XCTest
import Gauntlet


class ExistentialTests : XCTestCase{
  var machine = StateMachine(initialState: MyState.ready)
  
  
  func testInitialState(){
    switch machine.state{
    case .ready:
      XCTAssert(true)
    default:
      XCTFail("Not Ready")
    }
  }
  
  
  func testValidTransition() {
    machine.transition(to: .working)
    XCTAssertEqual(machine.state, .working)
  }
  
  
  func testInvalidTransition() {
    machine.transition(to: .success("foo"))
    XCTAssertEqual(machine.state, .ready)
  }
  
  
  func testMultiTransition() {
    let error = NSError()
    XCTAssertEqual(machine.state, .ready)
    machine.transition(to: .working)
    XCTAssertEqual(machine.state, .working)
    machine.transition(to: .success("hello"))
    XCTAssertEqual(machine.state, .success("hello"))
    machine.transition(to: .ready)
    XCTAssertEqual(machine.state, .ready)
    machine.transition(to: .working)
    XCTAssertEqual(machine.state, .working)
    machine.transition(to: .failure(error))
    XCTAssertEqual(machine.state, .failure(error))
    machine.transition(to: .ready)
    XCTAssertEqual(machine.state, .ready)
  }
  
  
  func testSomeInvalidMultiTransition() {
    let error = NSError()
    XCTAssertEqual(machine.state, .ready)
    machine.transition(to: .working)
    XCTAssertEqual(machine.state, .working)

    machine.transition(to: .ready)
    XCTAssertEqual(machine.state, .working, "Invalid tranisition ignored.")

    machine.transition(to: .success("hello"))
    XCTAssertEqual(machine.state, .success("hello"))
    
    machine.transition(to: .failure(error))
    XCTAssertEqual(machine.state, .success("hello"), "Invalid transition ignored.")

    machine.transition(to: .ready)
    XCTAssertEqual(machine.state, .ready)
  }
}
