import Foundation
import Combine



/**
 The “machine” part of our finite state machine.
 
 Given a `Transitionable` type `State`, this class holds its current value in the property `state` and manages transitions to new states by consulting `state`’s `shouldTransition(to:)` method.
 
 ```
 let stateMachine = StateMachine(initialState: MyState.ready)
 stateMachine.transition(to: .working)
 stateMachine.state // If `state.shouldTransition(to: .working)`
                    // returns `true`, this will be `.working`.
                    // Otherwise it will be `.ready`.
 ```
 
 This class also publishes state changes to subscribers via `publisher`:
 
 ```
 let stateMachine = StateMachine(initialState: MyState.ready)
 stateMachine.publisher.sink { from, to in
   // from == .ready, to == .working if
   // ready -> working is a valid transition
 }
 stateMachine.transition(to: .working)
 ```
 
 ### Property Wrapper
 `StateMachine` can also be used as a property wrapper, in which case the wrapped property’s type is the state type conforming to `Transitionable`, its default value is the initial state, its projected value is its `publisher`, and all assignment happens through `transition(to:)`. The above example could be written as:
 
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
   
   To transition to another state, use `transition(to:)`
   
   ### Property Wrapper
   When using `StateMachine` as a property wrapper, the wrapped property’s getter is equivalent to the `state` property:
   
   ```
   let stateMachine = StateMachine(initialState: MyState.ready)
   stateMachine.state //> .ready
   
   // Is equivalent to:
   @StateMachine var stateMachine: MyState = .ready
   stateMachine //> .ready
   ```
   
   - SeeAlso: `transition(to:)`
   */
  public private(set) var state: State


  /**
   Publishes state changes after valid transitions.
   
   Consumers can subscribe (in the `Combine` sense) to `publisher` to recieve a set of `State` values after ⃰ a valid transition:
   
   ```
   let stateMachine = StateMachine(initialState: MyState.ready)
   //...
   let subscription = stateMachine.publisher.sink { from, to in
     // stuff to do when `stateMachine` has transitioned
     // to or from particular states...
   }
   ```
   
   - Attention:
       “After”, in this case, means “on the *next* cycle of the run loop”. Subscribers will always be sent all the state changes in the order they were made. But if `state` is transitioned multiple times in *this* cycle of the run loop, `to:` may not represent the current value of `state` by the time it’s received.
       
       See the documentation for `transition(to:)` for more details and examples.
       
   ### Property Wrapper
   When using `StateMachine` as a property wrapper, `publisher` is the wrapped property’s “projected value” — meaning we can access it by usign the `$` prefix. The above could be written as:
   
   ```
   @StateMachine var stateMachine: MyState = .ready
   //...
   let subscription = $stateMachine.sink { from, to in
     // stuff to do when `machine` has transitioned
     // to or from particular states...
   }
   ```

   - SeeAlso: `transition(to:)`
   */
  public var publisher: AnyPublisher<(from: State, to: State), Never> {
    return _publisher.eraseToAnyPublisher()
  }
  
  
  /**
   The value of the wrapped property when `StateMachine` is used as a property wrapper. Getting the value is equivalent to `state`. Setting the value is equivalent to calling `transition(to:)` with the new value.
   
   - SeeAlso: `state`, `transition(to:)`
   */
  public var wrappedValue: State {
    get { state }
    set { transition(to: newValue) }
  }
  
  
  /**
   The projected value of the property (that is, the value when the property is prepended with a `$`) when `StateMachine` is used as a property wrapper.
   
   The projected value is equivalent to the `publisher` property:
   
   ```
   let stateMachine = StateMachine(initialState: MyState.ready)
   stateMachine.publisher.sink { ... }
   
   // Is equivalent to:
   @StateMachine var stateMachine: MyState = .ready
   $stateMachine.sink { ... }
   ```
   */
  public var projectedValue: AnyPublisher<(from: State, to: State), Never> {
    publisher
  }
    
  
  /**
   Initializes the state machine with the given initial state.
   */
  public init(initialState: State) {
    state = initialState // set the internal value so we don't need a special rule in `shouldTranistion(to:)`. Also avoids publishing the change to `publisher`.
  }
  
  
  /**
   Initializer called when using `StateMachine` as a property wrapper.
   
   The default value of the property wrapper is made the “initial state” of the state machine:
   
   ```
   let stateMachine = StateMachine(initialState: MyState.ready)
   
   // Is equivalent to:
   @StateMachine var stateMachine: MyState = .ready
   ```
   */
  convenience public init(wrappedValue: State) {
    self.init(initialState: wrappedValue)
  }
  
  
  /**
   Use this method to transition states.
   
   When called, this method:
   * First, determines the validity of the transition to the given `newState` via a call to `state.shouldTransition(to:)`.
   * If it is valid, `newState` is *synchonously* assigned to the `state` property. Then the previous and new states are published *asynchronously* to subscribers of `publisher`.
   * If the transition to `newState` is *not* valid, it is silently ignored and nothing is published.
   
   - Attention:
       This method publishes to subscribers of `publisher` *asynchronously*. This is so we can call `transition(to:)` from within a the subscriber without concern for growing the stack.
   
       But this also means that, while subscribers of `publisher` will always be sent all state changes and always in the order they occured, if `state` (which is is transitioned *synchronously*) is set multiple times in a row, a subscriber’s parameters may not reflect the *current* state of the machine by the time it’s received:
   
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
   
   - Parameter newState: The `State` to transition to.
   
   ### Property Wrapper
   When using `StateMachine` as a property wrapper, the wrapped property’s setter is equivalent to calling `transition(to:)`:
   
   ```
   let stateMachine = StateMachine(initialState: MyState.ready)
   stateMachine.transition(to: .working)
   
   // Is equivalent to:
   @StateMachine var stateMachine: MyState = .ready
   stateMachine = .working
   ```

   - SeeAlso: `publisher`
   */
  public func transition(to newState: State) {
    if state.shouldTransition(to: newState) {
      let from = state
      state = newState
      OperationQueue.current?.addOperation { [weak self] () -> Void in
        self?._publisher.send((from: from, to: newState))
      }
    }
  }
}
