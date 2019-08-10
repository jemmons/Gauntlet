import XCTest
import Gauntlet



@available(iOS 13, macOS 10.15, *)
class PropertyWrapperTests: XCTestCase {
  enum State: Transitionable {
    case ready, working, done
    
    func shouldTransition(to: PropertyWrapperTests.State) -> Bool {
      switch (self, to) {
      case (.ready, .ready),
           (.ready, .working),
           (.working, .done),
           (.done, .ready):
        return true
      default:
        return false
      }
    }
  }
  
  
  @StateMachine var state: State = .ready
  
  
  func testTransitions() {
    XCTAssertEqual(.ready, state)
    let transition = expectation(description: "Waiting for transition")
    let sub = $state.sink { set in
      switch set {
      case (.ready, .working):
        XCTAssertEqual(.working, self.state)
        transition.fulfill()
      default:
        break
      }
    }
    state = .working
    
    wait(for: [transition], timeout: 1)
  }
  
  
  func testInvalidTransition(){
    let noChange = expectation(description: "The state should not have changed.")

    let sub = $state.sink { from, to in
      XCTFail("Handler for invalid transition should not have been called.")
    }
    state = .done
    OperationQueue.main.addOperation {
      XCTAssertEqual(.ready, self.state)
      noChange.fulfill()
    }
    
    wait(for: [noChange], timeout: 1)
  }

  
  func testValidDoubleTransition(){
    let doubleReady = expectation(description: "Expect from ready to ready.")

    let sub = $state.sink { set in
      if case (.ready, .ready) = set {
        XCTAssertEqual(.ready, self.state)
        doubleReady.fulfill()
      }
    }
    state = .ready

    wait(for: [doubleReady], timeout: 1)
  }
  
  
  func testInvalidDoubleTransition(){
    let toWorking = expectation(description: "Waiting for transition to working.")
    let noChange = expectation(description: "Expecting no tranistion.")
    
    let sub = $state.sink { set in
      switch set {
      case (.ready, .working):
        toWorking.fulfill()
      default:
        XCTFail("Invalid transitions should not be published.")
      }
    }
    state = .working
    state = .working
    OperationQueue.main.addOperation {
      XCTAssertEqual(.working, self.state)
      noChange.fulfill()
    }
    
    wait(for: [toWorking, noChange], timeout: 1)
  }
  
  
  func testNestedTransitions(){
    let toWorking = expectation(description: "Transition Complete")
    let toDone = expectation(description: "Transition Complete")
    var inWorking = false
    
    let sub = $state.sink { _, to in
      switch to {
      case .working:
        inWorking = true
        defer { inWorking = false }
        toWorking.fulfill()
        self.state = .done
      case .done:
        XCTAssertFalse(inWorking, "no other handler should be on the stack")
        XCTAssertEqual(.done, self.state)
        toDone.fulfill()
      default:
        XCTFail()
      }
    }
    state = .working
    
    wait(for: [toWorking, toDone], timeout: 1)
  }
  
  
  func testTransitionDelay(){
    let toWorking = expectation(description: "Waiting for transition to working.")
    let sub = $state.sink { set in
      if case (.ready, .working) = set {
        XCTAssertEqual(self.state, .working)
        toWorking.fulfill()
      }
    }
    state = .working
    XCTAssertEqual(state, State.ready, "The transistion doesn't happen until the next run loop")
    wait(for: [toWorking], timeout: 1)
  }
    

  func testMultipleTransitions() {
    let toReady = expectation(description: "Transitioned to ready.")
    let toWorking = expectation(description: "Transitioned to working.")
    let toDone = expectation(description: "Transitioned to done.")

    let sub = $state.sink {  from, to in
      switch (from, to) {
      case (.ready, .working):
        XCTAssertEqual(.working, self.state)
        toWorking.fulfill()
      case (.working, .done):
        XCTAssertEqual(.done, self.state)
        toDone.fulfill()
      case (.done, .ready):
        XCTAssertEqual(.ready, self.state)
        toReady.fulfill()
      default:
        XCTFail()
      }
    }
    
    state = .working
    XCTAssertEqual(.ready, state)
    state = .done
    XCTAssertEqual(.ready, state)
    state = .ready
    XCTAssertEqual(.ready, state)

    wait(for: [toReady, toWorking, toDone], timeout: 2)
  }

}
