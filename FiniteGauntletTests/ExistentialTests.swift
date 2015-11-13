import Foundation
import XCTest
import FiniteGauntlet

class ExistentialTests : XCTestCase{
  var machine:StateMachine<ExistentialTests>!
  
  override func setUp() {
    machine = StateMachine(initialState: .Ready, delegate: self)
  }
  
  func testInitialState(){
    switch machine.state{
    case .Ready:
      XCTAssert(true)
    default:
      XCTFail("Not Ready")
    }
  }
}

extension ExistentialTests : StateMachineDelegateProtocol{
  typealias StateType = State
  enum State : StateMachineDataSourceProtocol{
    case Ready, Working, Success(String), Failure(NSError)
    func shouldTransitionFrom(from: State, to: State) -> Bool {
      return true
    }
  }
  
  func didTransitionFrom(from: State, to: State) {
    
  }
}