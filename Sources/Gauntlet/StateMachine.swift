import Foundation
import Combine



/**
 The “machine” part of our finite state machine. Given a `Transitionable` type `State`, this class holds the current state value and manages transitions between them by consulting `State`’s `shouldTransition(to:)` method.
 
 ```
 let stateMachine = StateMachine(initialState: MyState.ready)
 stateMachine.transition(to: .working)
 stateMachine.state // "working" if ready->working is a
                    // valid transition; otherwise "ready"
 ```
 
 It will also publish state changes to subscribers via `publisher`:
 
 ```
 let stateMachine = StateMachine(initialState: MyState.ready)
 stateMachine.publisher.sink { from, to in
   // from == .ready, to == .working if
   // ready -> working is a valid transition
 }
 stateMachine.transition(to: .working)
 ```
 
 ### Property Wrapper
 `StateMachine` can also be used as a property wrapper, in which case its default vaule is used as its initial state, its projected value is its `publisher`, and all assignment happens through `transition(to:)`. The above example could be written as:
 
 ```
 @StateMachine var stateMachine: MyState = .ready
 $stateMachine.sink { from, to in
   // from == .ready, to == .working if
   // ready -> working is a valid transition
 }
 stateMachine = .working
 ```
 */
@propertyWrapper
public class StateMachine<State> where State: Transitionable {
  lazy private var _publisher = PassthroughSubject<(from: State, to: State), Never>()


  /**
   The current state of the state machine. Read-only.
   */
  public private(set) var state: State


  /**
   Publishes state changes after valid transitions.
   
   Consumers can subscribe (in the `Combine` sense) to `publisher` to recieve a set of `State` values after ⃰ a valid transition:
   
   ```
   let machine = StateMachine(initialState: State.ready)
   //...
   let subscription = machine.publisher.sink { from, to in
     // stuff to do when `machine` has transitioned
     // to or from particular states...
   }
   ```
   
   - Attention:
       “After”, in this case, means “on the *next* cycle of the run loop”. Subscribers will always be sent all the state changes in the order they were made. But if `state` is transitioned multiple times in *this* cycle of the run loop, `to:` may not represent the current value of `state` by the time it’s received.
       
       See the documentation for `transition(to:)` for more details and examples.
       
   - SeeAlso: `transition(to:)`
   
   ### Property Wrapper
   When using `StateMachine` as a property wrapper, this is its “projected value” — meaning we can access it by usign the `$` prefix:
   
   ```
   @StateMachine var state: MyState = .ready
   //...
   let subscription = $state.sink { /*...*/ }
   ```
   */
  public var publisher: AnyPublisher<(from: State, to: State), Never> {
    return _publisher.eraseToAnyPublisher()
  }
  
  
  /**
   Equivalent to `state` property.
   */
  public var wrappedValue: State {
    get { state }
    set { transition(to: newValue) }
  }
  
  
  /**
   Equivalent to `publisher` property.
   */
  public var projectedValue: AnyPublisher<(from: State, to: State), Never> {
    get { publisher }
  }
    
  
  /**
   Initializes the state machine with the given initial state.
   */
  public init(initialState: State) {
    state = initialState //set the internal value so we don't need a special rule in `shouldTranistion(to:)`. Also avoids publishing the change to `publisher`.
  }
  
  
  /**
   The default value of the property wrapper is made the “initial state” of the state machine.
   */
  convenience public init(wrappedValue: State) {
    self.init(initialState: wrappedValue)
  }
  
  
  /**
   Use this method to transition states.
   
   First, the validity of a transition to the given `state` is determined via a call to its `shouldTransition(to:)`.
   
   If it is valid, the machine tranisitons to it and publishes the previous and new state via `publisher`.
   
   If transition to the given `state` *not* valid, it is silently ignored.
   
   - Attention:
       This method publishes to `publisher` on the *next* cycle of the run loop. This is so we can call `transition(to:)` from within a subscriber of `publisher` without concern for growing the stack.
   
       But this also means that, while subscribers of `publisher` will always be sent all state changes and in the order they occured, if `state` is transitioned multiple times in *this* cycle of the run loop, `to:` may not represent the current value of `state` by the time it’s received:
   
       ```
       let stateMachine = StateMachine(initialState: MyState.first)
       let sub = stateMachine.publisher.sink { from, to in
         // On the first call...
         print(to)                 //> .second
         print(stateMachine.state) //> but `state` is already .third
   
         // Second call...
         print(to)                 //> .third
         print(stateMachine.state) //> also .third
       }

       stateMachine.transition(to: .second)
                       // `state` is immediately set to `.second`,
                       // but `(.first, .second)` won't be published
                       // until the next runloop.
       
       stateMachine.trasition(to: .third)
                       // Still in the current runloop; `state` is
                       // is set to `.third`. We still won’t publish
                       // `(.first, .second)` until the next runloop
                       // and `(.second, .third)` right after that.
       ```
   
   - Parameter to: The `State` to transition to.
   
   - SeeAlso: `publisher`
   */
  public func transition(to: State) {
    if state.shouldTransition(to: to) {
      let from = state
      state = to
      OperationQueue.current?.addOperation { [weak self] () -> Void in
        self?._publisher.send((from: from, to: to))
      }
    }
  }
}
