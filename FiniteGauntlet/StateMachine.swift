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
  
  
  public init(initialState:P.StateType, delegate:P){
    _state = initialState //set the primitive to avoid calling the delegate.
    self.delegate = delegate
  }
  
  
  private func delegateTransitionTo(to:P.StateType){
    if _state.shouldTransitionFrom(_state, to:to){
      _state = to
    }
  }
}
