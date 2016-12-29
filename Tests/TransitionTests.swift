import Foundation
import XCTest
import Gauntlet

func ==(lhs: TransitionTests.State, rhs: TransitionTests.State) -> Bool {
  switch (lhs, rhs){
  case (.ready, .ready), (.working, .working), (.success, .success), (.failure, .failure):
    return true
  default:
    return false
  }
}


class TransitionTests : XCTestCase{
  enum State: StateType, Equatable {
    case ready, working, success(String), failure(NSError)
    static func shouldTransition(from: State, to: State) -> Bool {
      switch (from, to) {
      case
      (.ready, .ready),
      (.ready, .working),
      (.working, .ready):
        return true
      default:
        return false
      }
    }
  }
  var machine = StateMachine(initialState: State.ready)

  
  func testTransitionDelay(){
    let expectWorking = expectation(description: "Completed Transition")
    machine.transitionHandler = { from, to in
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
  
  
  func testValidTransition(){
    let expectWorking = expectation(description: "Completed Transition")
    expectation(forNotification: GauntletNotification.willTransition.rawValue, object: machine) {
      return (($0 as NSNotification).userInfo!["fromString"] as! String).contains("ready") && (($0 as NSNotification).userInfo!["toString"] as! String).contains("working")
    }
    expectation(forNotification: GauntletNotification.didTransition.rawValue, object: machine) {
      return (($0 as NSNotification).userInfo!["fromString"] as! String).contains("ready") && (($0 as NSNotification).userInfo!["toString"] as! String).contains("working")
    }
    machine.transitionHandler = { from, to in
      if case (.ready, .working) = (from, to) {
        expectWorking.fulfill()
      }
    }
    machine.queue(.working)
    
    waitForExpectations(timeout: 2) { _ in
      XCTAssertEqual(self.machine.state, State.working)
    }
  }
  
  
  func testMultipleTransitions(){
    let expectWorking = expectation(description: "Completed Working")
    let expectReady = expectation(description: "Completed Ready")

    machine.transitionHandler = { _, to in
      switch to {
      case .working:
        expectWorking.fulfill()
      case .ready:
        expectReady.fulfill()
      default:
        XCTFail()
      }
    }
    machine.queue(.working)
    machine.queue(.ready)
    
    waitForExpectations(timeout: 2) { _ in
      XCTAssertEqual(self.machine.state, State.ready)
    }
  }
  
  
  /// `testInvalidTransition` relies on the state-changing operation completing before the expectation is fulfilled (which it always should, because the main queue is essentially FIFO). This tests that that's true.
  func testTimingForInvalidTransition() {
    var didTransition = false
    let expectQueued = expectation(description: "Queued Expectation")
    
    machine.transitionHandler = { from, to in
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

    machine.transitionHandler = { from, to in
      XCTFail("Handler for invalid transition should not have been called.")
    }
    machine.queue(.success("foo"))
    OperationQueue.main.addOperation { expectQueued.fulfill() }
    
    waitForExpectations(timeout: 2) { _ in
      XCTAssertEqual(self.machine.state, State.ready)
    }
  }

  
  func testValidDoubleTransition(){
    let expectDoubleReady = expectation(description: "Transition Complete")

    machine.transitionHandler = { from, to in
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
    
    machine.transitionHandler = { from, to in
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
    let expectReady = expectation(description: "Transition Complete")
    let expectWorking = expectation(description: "Transition Complete")
    var inWorking = false
    
    machine.transitionHandler = { _, to in
      switch to {
      case .ready:
        XCTAssertFalse(inWorking, "no other handler should be on the stack")
        expectReady.fulfill()
      case .working:
        inWorking = true
        defer { inWorking = false }
        expectWorking.fulfill()
        self.machine.queue(.ready)
      default:
        XCTFail()
      }
    }
    machine.queue(.working)
    
    waitForExpectations(timeout: 2, handler: nil)
  }
  
  
  func testNilSelf() {
    var subject:StateMachine? = StateMachine(initialState: State.ready)
    subject!.transitionHandler = { from, to in
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
}
