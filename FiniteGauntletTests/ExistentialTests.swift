import Foundation
import XCTest
import FiniteGauntlet

class ExistentialTests : XCTestCase{
  func testStateMachine(){
    let foo:StateMachine<ExistentialTests>
    
  }
}

extension ExistentialTests : StateMachineDelegateProtocol{
  typealias StateType = State
  enum State : StateMachineDataSourceProtocol{
    case Foo
    func shouldTransitionFrom(from: State, to: State) -> Should<State> {
      return .Continue
    }
  }
  
  func didTransitionFrom(from: State, to: State) {
    
  }
}