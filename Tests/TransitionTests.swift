import Foundation
import XCTest
import Gauntlet

func ==(lhs: TransitionTests.State, rhs: TransitionTests.State) -> Bool {
  switch (lhs, rhs){
  case (.Ready, .Ready), (.Working, .Working), (.Success, .Success), (.Failure, .Failure):
    return true
  default:
    return false
  }
}


class TransitionTests : XCTestCase{
  enum State: StateType, Equatable {
    case Ready, Working, Success(String), Failure(NSError)
    static func shouldTransition(from: State, to: State) -> Bool {
      switch (from, to) {
      case
      (.Ready, .Ready),
      (.Ready, .Working),
      (.Working, .Ready):
        return true
      default:
        return false
      }
    }
  }
  var machine = StateMachine(initialState: State.Ready)

  
  func testTransitionDelay(){
    let expectWorking = expectationWithDescription("Completed Transition")
    machine.transitionHandler = { from, to in
      if case (.Ready, .Working) = (from, to) {
        expectWorking.fulfill()
      }
    }
    machine.queueState(.Working)
    XCTAssertEqual(machine.state, State.Ready, "The transistion doesn't happen until the next run loop")
    waitForExpectationsWithTimeout(2) { error in
      XCTAssertEqual(self.machine.state, State.Working)
    }
  }
  
  
  func testValidTransition(){
    let expectWorking = expectationWithDescription("Completed Transition")
    expectationForNotification("GauntletWillTransitionNotification", object: machine) {
      return ($0.userInfo!["fromString"] as! String).containsString("Ready") && ($0.userInfo!["toString"] as! String).containsString("Working")
    }
    expectationForNotification("GauntletDidTransitionNotification", object: machine) {
      return ($0.userInfo!["fromString"] as! String).containsString("Ready") && ($0.userInfo!["toString"] as! String).containsString("Working")
    }
    machine.transitionHandler = { from, to in
      if case (.Ready, .Working) = (from, to) {
        expectWorking.fulfill()
      }
    }
    machine.queueState(.Working)
    
    waitForExpectationsWithTimeout(2) { _ in
      XCTAssertEqual(self.machine.state, State.Working)
    }
  }
  
  
  func testMultipleTransitions(){
    let expectWorking = expectationWithDescription("Completed Working")
    let expectReady = expectationWithDescription("Completed Ready")

    machine.transitionHandler = { _, to in
      switch to {
      case .Working:
        expectWorking.fulfill()
      case .Ready:
        expectReady.fulfill()
      default:
        XCTFail()
      }
    }
    machine.queueState(.Working)
    machine.queueState(.Ready)
    
    waitForExpectationsWithTimeout(2) { _ in
      XCTAssertEqual(self.machine.state, State.Ready)
    }
  }
  
  
  /// `testInvalidTransition` relies on the state-changing operation completing before the expectation is fulfilled (which it always should, because the main queue is essentially FIFO). This tests that that's true.
  func testTimingForInvalidTransition() {
    var didTransition = false
    let expectQueued = expectationWithDescription("Queued Expectation")
    
    machine.transitionHandler = { from, to in
      didTransition = true
    }
    //This will put the state-changing operation on the main queue.
    machine.queueState(.Working)
    //This will queue up another operation -- after the state-changing one.
    NSOperationQueue.mainQueue().addOperationWithBlock { expectQueued.fulfill() }
    
    waitForExpectationsWithTimeout(2) { _ in
      XCTAssert(didTransition, "Our expectation should fulfill *after* the transition completes.")
    }
  }
  
  
  func testInvalidTransition(){
    let expectQueued = expectationWithDescription("Queued Expectation")

    machine.transitionHandler = { from, to in
      XCTFail("Handler for invalid transition should not have been called.")
    }
    machine.queueState(.Success("foo"))
    NSOperationQueue.mainQueue().addOperationWithBlock { expectQueued.fulfill() }
    
    waitForExpectationsWithTimeout(2) { _ in
      XCTAssertEqual(self.machine.state, State.Ready)
    }
  }

  
  func testValidDoubleTransition(){
    let expectDoubleReady = expectationWithDescription("Transition Complete")

    machine.transitionHandler = { from, to in
      if case (.Ready, .Ready) = (from, to) {
        expectDoubleReady.fulfill()
      }
    }
    machine.queueState(.Ready)

    waitForExpectationsWithTimeout(2) { _ in
      XCTAssertEqual(self.machine.state, State.Ready)
    }
  }
  
  
  func testInvalidDoubleTransition(){
    let expectWorking = expectationWithDescription("Transition Complete")
    let expectQueued = expectationWithDescription("Queued Expectation")
    
    machine.transitionHandler = { from, to in
      switch (from, to) {
      case (.Ready, .Working):
        expectWorking.fulfill()
      default:
        XCTFail("Transition is invalid.")
      }
    }
    machine.queueState(.Working)
    machine.queueState(.Working)
    NSOperationQueue.mainQueue().addOperationWithBlock { expectQueued.fulfill() }
    
    waitForExpectationsWithTimeout(2) { _ in
      XCTAssertEqual(self.machine.state, State.Working)
    }
  }
  
  
  func testNestedTransitions(){
    let expectReady = expectationWithDescription("Transition Complete")
    let expectWorking = expectationWithDescription("Transition Complete")
    var inWorking = false
    
    machine.transitionHandler = { _, to in
      switch to {
      case .Ready:
        XCTAssertFalse(inWorking, "no other handler should be on the stack")
        expectReady.fulfill()
      case .Working:
        inWorking = true
        defer { inWorking = false }
        expectWorking.fulfill()
        self.machine.queueState(.Ready)
      default:
        XCTFail()
      }
    }
    machine.queueState(.Working)
    
    waitForExpectationsWithTimeout(2, handler: nil)
  }
  
  
  func testNilSelf() {
    var subject:StateMachine? = StateMachine(initialState: State.Ready)
    subject!.transitionHandler = { from, to in
      XCTFail("Should never be called.")
    }
    subject!.queueState(.Working)
    subject = nil
    
    let expectTimeWasted = expectationWithDescription("Should waste time.")
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(1 * NSEC_PER_SEC)), dispatch_get_main_queue()) {
      expectTimeWasted.fulfill()
    }
    //This just pumps the event loop.
    waitForExpectationsWithTimeout(1.5, handler: nil)
  }
}
