import XCTest
import Gauntlet

#if canImport(Combine)
import Combine
#endif



@available(iOS 13, macOS 10.15, *)
class PublisherTests: XCTestCase {
  enum State: Transitionable, Equatable {
    case ready, working, done
    func shouldTransition(to: State) -> Bool {
      switch (self, to) {
      case
      (.ready, .ready),
      (.ready, .working),
      (.working, .done),
      (.done, .ready):
        return true
      default:
        return false
      }
    }
  }


  var machine = StateMachine(initialState: State.ready)
  
  
  
  func testValidTransition(){
    let expectWorking = expectation(description: "Completed Transition")
    let sub = machine.publisher.sink { from, to in
      if case (.ready, .working) = (from, to) {
        XCTAssertEqual(self.machine.state, State.working)
        expectWorking.fulfill()
      }
    }
    machine.queue(.working)
    
    wait(for: [expectWorking], timeout: 1)
  }
  
  
  func testInvalidTransition(){
    let expectQueued = expectation(description: "Queued Expectation")
    
    let sub = machine.publisher.sink { from, to in
      XCTFail("Handler for invalid transition should not have been called.")
    }
    machine.queue(.done)
    OperationQueue.main.addOperation { expectQueued.fulfill() }
    
    waitForExpectations(timeout: 2) { _ in
      XCTAssertEqual(self.machine.state, State.ready)
    }
  }
  
  
  func testValidDoubleTransition(){
    let expectDoubleReady = expectation(description: "Transition Complete")
    
    let sub = machine.publisher.sink { from, to in
      if case (.ready, .ready) = (from, to) {
        expectDoubleReady.fulfill()
      }
    }
    machine.queue(.ready)
    
    waitForExpectations(timeout: 2) { _ in
      XCTAssertEqual(self.machine.state, State.ready)
    }
  }
  
  
  func testInvalidDoubleTransition(){
    let expectWorking = expectation(description: "Transition Complete")
    let expectQueued = expectation(description: "Queued Expectation")
    
    let sub = machine.publisher.sink { from, to in
      switch (from, to) {
      case (.ready, .working):
        expectWorking.fulfill()
      default:
        XCTFail("Transition is invalid.")
      }
    }
    machine.queue(.working)
    machine.queue(.working)
    OperationQueue.main.addOperation { expectQueued.fulfill() }
    
    waitForExpectations(timeout: 2) { _ in
      XCTAssertEqual(self.machine.state, State.working)
    }
  }
  
  
  func testNestedTransitions(){
    let expectWorking = expectation(description: "Transition Complete")
    let expectDone = expectation(description: "Transition Complete")
    var inWorking = false
    
    let sub = machine.publisher.sink { _, to in
      switch to {
      case .working:
        inWorking = true
        defer { inWorking = false }
        expectWorking.fulfill()
        self.machine.queue(.done)
      case .done:
        XCTAssertFalse(inWorking, "no other handler should be on the stack")
        expectDone.fulfill()
      default:
        XCTFail()
      }
    }
    machine.queue(.working)
    
    wait(for: [expectWorking, expectDone], timeout: 1)
  }
  
  
  func testNilSelf() {
    var subject:StateMachine? = StateMachine(initialState: State.ready)
    let sub = subject?.publisher.sink { from, to in
      XCTFail("Should never be called.")
    }
    subject!.queue(.working)
    subject = nil
    
    let expectTimeWasted = expectation(description: "Should waste time.")
    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
      expectTimeWasted.fulfill()
    }
    //This just pumps the event loop.
    waitForExpectations(timeout: 1.5, handler: nil)
  }
  
  
  func testTransitionDelay(){
    let expectWorking = expectation(description: "Completed Transition")
    let sub = machine.publisher.sink { from, to in
      if case (.ready, .working) = (from, to) {
        expectWorking.fulfill()
      }
    }
    machine.queue(.working)
    XCTAssertEqual(machine.state, State.ready, "The transistion doesn't happen until the next run loop")
    waitForExpectations(timeout: 2) { error in
      XCTAssertEqual(self.machine.state, State.working)
    }
  }
    

  func testMultipleTransitions() {
    let toReady = expectation(description: "Transitioned to ready.")
    let toWorking = expectation(description: "Transitioned to working.")
    let toDone = expectation(description: "Transitioned to done.")

    let sub = machine.publisher.sink { [weak self] from, to in
      switch (from, to) {
      case (.ready, .working):
        XCTAssertEqual(.working, self?.machine.state)
        toWorking.fulfill()
      case (.working, .done):
        XCTAssertEqual(.done, self?.machine.state)
        toDone.fulfill()
      case (.done, .ready):
        XCTAssertEqual(.ready, self?.machine.state)
        toReady.fulfill()
      default:
        XCTFail()
      }
    }
    
    machine.queue(.working)
    XCTAssertEqual(.ready, machine.state)
    machine.queue(.done)
    XCTAssertEqual(.ready, machine.state)
    machine.queue(.ready)
    XCTAssertEqual(.ready, machine.state)

    wait(for: [toReady, toWorking, toDone], timeout: 2)
  }
}
