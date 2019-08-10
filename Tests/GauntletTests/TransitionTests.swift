import Foundation
import XCTest
import Gauntlet



class TransitionTests : XCTestCase{
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
    machine.delegates.didTransition = { from, to in
      if case (.ready, .working) = (from, to) {
        XCTAssertEqual(self.machine.state, State.working)
        expectWorking.fulfill()
      }
    }
    machine.queue(.working)
    
    wait(for: [expectWorking], timeout: 1)
  }
  
  
  /// `testInvalidTransition` relies on the state-changing operation completing before the expectation is fulfilled (which it always should, because the main queue is essentially FIFO). This tests that that's true.
  func testTimingForInvalidTransition() {
    var didTransition = false
    let expectQueued = expectation(description: "Queued Expectation")
    
    machine.delegates.didTransition = { from, to in
      didTransition = true
    }
    //This will put the state-changing operation on the main queue.
    machine.queue(.working)
    //This will queue up another operation -- after the state-changing one.
    OperationQueue.main.addOperation { expectQueued.fulfill() }
    
    waitForExpectations(timeout: 2) { _ in
      XCTAssert(didTransition, "Our expectation should fulfill *after* the transition completes.")
    }
  }
  
  
  func testInvalidTransition(){
    let expectQueued = expectation(description: "Queued Expectation")

    machine.delegates.didTransition = { from, to in
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

    machine.delegates.didTransition = { from, to in
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
    
    machine.delegates.didTransition = { from, to in
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
    
    machine.delegates.didTransition = { _, to in
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
    subject!.delegates.didTransition = { from, to in
      XCTFail("Should never be called.")
    }
    subject!.queue(.working)
    subject = nil
    
    let expectTimeWasted = expectation(description: "Should waste time.")
    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(1 * NSEC_PER_SEC)) / Double(NSEC_PER_SEC)) {
      expectTimeWasted.fulfill()
    }
    //This just pumps the event loop.
    waitForExpectations(timeout: 1.5, handler: nil)
  }
  
  
  func testTransitionDelay(){
    let expectWorking = expectation(description: "Completed Transition")
    machine.delegates.didTransition = { from, to in
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

    machine.delegates.didTransition = { [weak self] from, to in
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
