import Foundation
import XCTest
import FiniteGauntlet

class TransitionTests : XCTestCase{
  var machine:StateMachine<TransitionTests>!
  var success:Bool = false

  override func setUp() {
    machine = StateMachine(initialState: .Ready, delegate: self)
  }
  
  
  func testDoubleTransition(){
    machine.state = .Ready
    XCTAssertTrue(success)
  }
}

extension TransitionTests : StateMachineDelegateProtocol{
  typealias StateType = State
  enum State : StateMachineDataSourceProtocol{
    case Ready, Working, Success(String), Failure(NSError)
    func shouldTransitionFrom(from: State, to: State) -> Should<State> {
      return .Continue
    }
  }

  func didTransitionFrom(from: State, to: State) {
    switch (from,to){
    case (.Ready, .Ready):
      success = true
    default:
      break
    }
  }
}
