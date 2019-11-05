import XCTest
import Combine
import Gauntlet



class PropertyWrapperTests: XCTestCase {
  @StateMachine var state: MyState = .ready
  var subscription: AnyCancellable?
  
  func testInitialState() {
    switch state {
    case .ready:
      XCTAssert(true)
    default:
      XCTFail()
    }
  }
  
  
  func testTransitions() {
    let transition = expectation(description: "Waiting for transition")
    
    subscription = $state.sink { trans in
      switch trans {
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

    subscription = $state.sink { from, to in
      XCTFail("Invalid transition should not publish.")
    }
    
    state = .success("hello")
    
    OperationQueue.current?.addOperation {
      XCTAssertEqual(.ready, self.state)
      noChange.fulfill()
    }
    
    wait(for: [noChange], timeout: 1)
  }

  
  func testValidSelfTransition(){
    let selfTransition = expectation(description: "Expect from ready to ready.")

    subscription = $state.sink { trans in
      if case (.ready, .ready) = trans {
        XCTAssertEqual(.ready, self.state)
        selfTransition.fulfill()
      }
    }
    
    state = .ready

    wait(for: [selfTransition], timeout: 1)
  }
  
  
  func testInvalidDoubleTransition(){
    let toWorking = expectation(description: "Waiting for transition to working.")
    let noChange = expectation(description: "Expecting no tranistion.")
    
    subscription = $state.sink { transition in
      switch transition {
      case (.ready, .working):
        toWorking.fulfill()
      default:
        XCTFail("Invalid transitions should not be published.")
      }
    }
    
    state = .working
    state = .working
    
    OperationQueue.current?.addOperation {
      XCTAssertEqual(.working, self.state)
      noChange.fulfill()
    }
    
    wait(for: [toWorking, noChange], timeout: 1)
  }
  
  
  func testNestedTransitions(){
    let toWorking = expectation(description: "Transition to .working complete")
    let toSuccess = expectation(description: "Transition to .success complete")
    var inWorking = false
    
    let sub = $state.sink { _, to in
      switch to {
      case .working:
        inWorking = true
        defer { inWorking = false }
        toWorking.fulfill()
        self.state = .success("Hello")
      case .success:
        XCTAssertFalse(inWorking, "no other handler should be on the stack")
        // When transitions only happen in subscriptions, we can count on the state being what we think it should be:
        XCTAssertEqual(.success("Hello"), self.state)
        toSuccess.fulfill()
      default:
        XCTFail()
      }
    }
    
    state = .working
    
    wait(for: [toWorking, toSuccess], timeout: 1)
  }
  
  
  func testTransitionDelay(){
    let toWorking = expectation(description: "Waiting for transition to .working.")
    let toSuccess = expectation(description: "Waiting for transition to .success.")

    subscription = $state.sink { transition in
      switch transition {
      case (.ready, .working):
        // By the time our subscription get this, state has already moved on to .success.
        XCTAssertEqual(.success("hello"), self.state)
        toWorking.fulfill()
      case (.working, .success):
        // This will come down the subscription immediately after the last. We'd expect `state`'s value to be the same.
        XCTAssertEqual(.success("hello"), self.state)
        toSuccess.fulfill()
      default:
        XCTFail()
      }
    }
    
    state = .working
    state = .success("hello")
    
    XCTAssertEqual(state, .success("hello"), "The transistions happen immediately.")

    wait(for: [toWorking, toSuccess], timeout: 1, enforceOrder: true)
  }
    

  func testMultipleTransitions() {
    let toWorking = expectation(description: "Transitioned to working.")
    let toSuccess = expectation(description: "Transitioned to success.")
    let toReady = expectation(description: "Transitioned to ready.")

    subscription = $state.sink {  transition in
      switch transition {
      case (.ready, .working):
        toWorking.fulfill()
      case (.working, .success):
        toSuccess.fulfill()
      case (.success, .ready):
        toReady.fulfill()
      default:
        XCTFail()
      }
    }
    
    state = .working
    state = .success("woo")
    state = .ready

    wait(for: [toWorking, toSuccess, toReady], timeout: 2, enforceOrder: true)
  }

}
