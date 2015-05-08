import Foundation


public class StateMachine<P:StateMachineDelegateProtocol>{
  private var _state:P.StateType{
    didSet{
      delegate.didTransitionFrom(oldValue, to: _state)
    }
  }
  unowned let delegate:P
  public var state:P.StateType{
    get{
      return _state
    }
    set{ //Can't be an observer because we need the option to CONDITIONALLY set state
      delegateTransitionTo(newValue)
    }
  }
  
  
  init(initialState:P.StateType, delegate:P){
    _state = initialState //set the primitive to avoid calling the delegate.
    self.delegate = delegate
  }
  
  
  private func delegateTransitionTo(to:P.StateType){
    switch _state.shouldTransitionFrom(_state, to:to){
    case .Continue:
      _state = to
    case .Redirect(let newState):
      _state = to
      state = newState
    case .Abort:
      break;
    }
  }
}
