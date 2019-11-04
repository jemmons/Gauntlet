import XCTest
import Gauntlet
import Combine



class PublisherTests: XCTestCase {
  var machine = StateMachine(initialState: MyState.ready)
  
  
  func testValidTransition(){
    let expectWorking = expectation(description: "Completed Transition")
    let sub = machine.publisher.sink { from, to in
      if case (.ready, .working) = (from, to) {
        XCTAssertEqual(self.machine.state, .working)
        expectWorking.fulfill()
      }
    }
    machine.transition(to: .working)
    
    wait(for: [expectWorking], timeout: 1)
  }
  
  
  /// `testInvalidTransition` relies on the state-changing operation completing before the expectation is fulfilled on whatever thread we're on. This tests that that's the case.
  func testTimingForInvalidTransition() {
    let toWorking = expectation(description: "Waiting to transition to working.")
    let expectQueued = expectation(description: "Queued Expectation")
    
    let sub = machine.publisher.sink { transition in
      if case (.ready, .working) = transition {
        toWorking.fulfill()
      }
    }
    
    //This will put the state-changing operation on the main queue.
    machine.transition(to: .working)
    
    //This will queue up another operation -- after the state-changing one.
    OperationQueue.current?.addOperation {
      expectQueued.fulfill()
    }
    
    wait(for: [toWorking, expectQueued], timeout: 1, enforceOrder: true)
  }
  

  func testInvalidTransition(){
    let expectQueued = expectation(description: "Queued Expectation")
    
    let sub = machine.publisher.sink { from, to in
      XCTFail("Handler for invalid transition should not have been called.")
    }
    machine.transition(to: .success("foo"))
    OperationQueue.main.addOperation {
      XCTAssertEqual(self.machine.state, .ready)
      expectQueued.fulfill()
    }
    
    wait(for: [expectQueued], timeout: 1)
  }
  
  
  func testValidSelfTransition(){
    let selfTransition = expectation(description: "Transition Complete")
    
    let sub = machine.publisher.sink { transition in
      if case (.ready, .ready) = transition {
        XCTAssertEqual(self.machine.state, .ready)
        selfTransition.fulfill()
      }
    }
    machine.transition(to: .ready)
    
    wait(for: [selfTransition], timeout: 1)
  }
  
  
  func testInvalidSelfTransition(){
    let expectWorking = expectation(description: "Transition Complete")
    let expectQueued = expectation(description: "Queued Expectation")
    
    let sub = machine.publisher.sink { transition in
      switch transition {
      case (.ready, .working):
        expectWorking.fulfill()
      default:
        XCTFail("Transition is invalid.")
      }
    }
    machine.transition(to: .working)
    machine.transition(to: .working)
    
    OperationQueue.current?.addOperation {
      XCTAssertEqual(self.machine.state, .working)
      expectQueued.fulfill()
    }
    
    wait(for: [expectWorking, expectQueued], timeout: 1)
  }
  
  
  func testNestedTransitions(){
    let expectWorking = expectation(description: "Transition to working.")
    let expectSuccess = expectation(description: "Trasition to success.")
    var inWorking = false
    
    let sub = machine.publisher.sink { _, to in
      switch to {
      case .working:
        inWorking = true
        defer { inWorking = false }
        expectWorking.fulfill()
        self.machine.transition(to: .success("foo"))
      case .success:
        XCTAssertFalse(inWorking, "no other handler should be on the stack")
        expectSuccess.fulfill()
      default:
        XCTFail()
      }
    }
    
    machine.transition(to: .working)
    
    wait(for: [expectWorking, expectSuccess], timeout: 1)
  }
  
  
  func testNilSelf() {
    var subject:StateMachine? = StateMachine(initialState: MyState.ready)
    let sub = subject!.publisher.sink { _ in
      XCTFail("Should never be called.")
    }
    subject!.transition(to: .working)
    subject = nil
    
    let expectTimeWasted = expectation(description: "Should waste time.")
    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
      expectTimeWasted.fulfill()
    }
    //This just pumps the event loop.
    wait(for: [expectTimeWasted], timeout: 1.5)
  }
  
  
  func testTransitionDelay(){
    let transitionToWorking = expectation(description: "Completed transition to working.")
    let sub = machine.publisher.sink { transition in
      if case (.ready, .working) = transition {
        XCTAssertEqual(self.machine.state, .working)
        transitionToWorking.fulfill()
      }
    }
    machine.transition(to: .working)
    XCTAssertEqual(machine.state, .working, "The transistion is applied immediately")

    wait(for: [transitionToWorking], timeout: 1)
  }
    

  func testMultipleTransitions() {
    let toWorking = expectation(description: "Transitioned to working.")
    let toSuccess = expectation(description: "Transitioned to success.")
    let toReady = expectation(description: "Transitioned to ready.")

    let sub = machine.publisher.sink { [weak self] transition in
      switch transition {
      case (.ready, .working):
        XCTAssertEqual(.ready, self!.machine.state, "assignments have already happened")
        toWorking.fulfill()
      case (.working, .success):
        XCTAssertEqual(.ready, self!.machine.state, "assignments have already happened")
        toSuccess.fulfill()
      case (.success, .ready):
        XCTAssertEqual(.ready, self!.machine.state, "assignments have already happened")
        toReady.fulfill()
      default:
        XCTFail()
      }
    }
    
    XCTAssertEqual(.ready, machine.state)
    machine.transition(to: .working)
    XCTAssertEqual(.working, machine.state)
    machine.transition(to: .success("foo"))
    XCTAssertEqual(.success("foo"), machine.state)
    machine.transition(to: .ready)
    XCTAssertEqual(.ready, machine.state)

    wait(for: [toWorking, toSuccess, toReady], timeout: 1, enforceOrder: true)
  }
}
