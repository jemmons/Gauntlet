# Gauntlet

[![SwiftPM compatible](https://img.shields.io/badge/SwiftPM-compatible-success)](https://github.com/Apple/swift-package-manager) [![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-success)](https://github.com/Carthage/Carthage) [![Documentation](https://jemmons.github.io/Gauntlet/badge.svg)](https://jemmons.github.io/Gauntlet/Protocols/Transitionable.html)

Gauntlet is a swift-friendly [state machine](https://en.wikipedia.org/wiki/Finite-state_machine) focusing on simple configuration and light weight objects. It was originally inspired by [a series of blog posts over on figure.ink](http://www.figure.ink/blog/2015/1/31/swift-state-machines-part-1), but has evolved substantially since then.

## Simple Configuration
Rather than requiring complicated graphs and configuration XML, state in Gauntlet is modeled by a single type (conforming to `Transitionable`) that is capable of determining whether transitions to other instances of itself are allowed. 

This not only simplifies configuration substantially, it maps very nicely onto swift's concept of an `enum` and can be trivially implemented with a single `switch`:   

```swift
enum TrafficLight: Transitionable {
  case red, yellow, green

  func shouldTransition(to: TrafficLight) -> Bool {
    switch (self, to) {
    case (.red, .green), 
         (.green, .yellow), 
         (.yellow, .red):
      return true
    default:
      return false
    }
  }
}
```

## Light Weight Objects
Gauntlet doesn’t require you to subclass objects from some abstract root machine or manage class hierarchies of behavior. Instead, a simple light weight `StateMachine` class is available to compose into your types and behaviors. 

A `StateMachine` gets created with a `Transitionable` type and an initial state. Transitioning states is a simple method call. A `Combine` publisher gives subscribers the ability to react to transitions:

```swift
class MyClass {
  let stateMachine = StateMachine(initialState: TrafficLight.red)
  let subscription: AnyCancellable
  
  init() {
    subscription = stateMachine.publisher.sink { [weak self] _, to in
      switch to {
      case .red:
        self?.stop()
      case .yellow:
        self?.slow()
      case .green:
        self?.go()
      }
    }
  }
  
  
  func timerTriggerd(light: TrafficLight) {
    stateMachine.transition(to: light)
  }
}
```

## Property Wrapper
Becasue `StateMachine` is so often used as a property, it can sometimes be more succinct to write it using property wrapper syntax. When used as a property wrapper:
* The type of the wrapped property is the state type conforming to `Transitionable`.
* The default value of the wrapped property is used as the initial state of the state machine.
* Values assigned to the wrapped property pass through `transition(to:)` and are ignored if they would result in an invalid transition.
* State changes are published to the “projected value” of the wrapped property — meaning we can access it by prefixing the wrapped property with a `$`.

The example above could be rewritten as:

```swift
class MyClass {
  @StateMachine var stateMachine: TrafficLight = .red
  let subscription: AnyCancellable
  
  init() {
    subscription = $stateMachine.sink { [weak self] _, to in
      //...
    }
  }
  
  
  func timerTriggerd(light: TrafficLight) {
    stateMachine = light
  }
}
```


## Associating Values

An oft overlooked advantage of conforming to `Transitionable` with an `enum` is it allows us to easily associate values with a state:

```swift
enum Connection: Transitionable {
  case fetch(URLSessionTask), success([AnyHashable: Any]), failure(Error), cancel
  
  func shouldTransition(to: Connection) -> Bool {
    switch (self, to) {
    case (.fetch, .success), 
         (.fetch, .failure), 
         (_, .cancel):
      return true
    default:
      return false
    }
  }
}
```

Values get associated when a transition is requested:

```swift
func connect() {
  let task = makeTask(for: myURL) { json, error in
    guard error == nil else {
      stateMachine.transition(to: .faulure(error))
      return
    }
    stateMachine.transition(to: .success(json))
  }

stateMachine.transition(to: .fetch(task))
}
```

…And can be pulled out again when handling state changes:

```swift
subscription = stateMachine.publisher.sink { [weak self] from, to in
  switch (from, to) {
  case (_, .success(let json)):
    self?.processJSON(json)
  case (_, .failure(let error)):
    self?.alert(error)
  case (.fetching(let task), .cancel):
    task.cancel()
  default:
    break
  }
}
```

## Migrating from Gauntlet v4.x
Version 5 of Gauntlet presents a number of breaking changes.

* `StateType` was deprecated last version. Now it’s dead. Use `Transitionable` instead.

* Delegates were always a bit wonky in Gauntlet and have been replaced with a `Combine` pub/sub model. The `delegates` property and its `didTransition` member have been removed. Subscribe to the `publisher` property (or the `$` projected value of a wrapped property) to get notified of state changes.  

* `queue(_:)` has been renamed to `transition(to:)`. This is simple enough, but is indicative of a larger change… 

* Timing is version 5 is subtlely different in significant ways. In version 4, state changes were queued onto the next cycle of the run loop. Then the state change and the (now obsolete) `didTransition` would run “together”. As a result, we could rely on the `state` property of the state machine and the `to` argument to `didTransition` to be in agreement.
    
    As of version 5, this has changd. Now state changes are applied to the state machine synchronously. But notification of these changes (via publication to the `publisher` property) still happens asynchronously (to allow for recursive transitions without overflowing the stack).
    
    As a result, the `state` of the machine is much more stable and less prone to timing-related edge cases. Yay! But we can no longer assume the `to` arguments of our subscriptions to `publisher` reflect the current `state` of the machine. Boo? 
    
    Subscribers will always get all state changes and will always receive them in the order they were made, so in practice I'm hoping this isn’t a big deal. But if you were relying on notifications of state change happening along side the actual change itself, it’s time to revisit those assumptions.

* In version 4, becasue `state` was set asyncronously, it was surpassingly hard to test unless the transition happened to trigger some behavior observable to the test case. So Gauntlet provided `willTransition` and `didTransition` notifications that would fire if `GAUNTLET_POST_TEST_NOTIFICATIONS` was set in the environment.
    
    Now that transitions happen syncronously in version 5, these are no longer necessary and have been removed.



## API
Full API documentation [can be found here](https://jemmons.github.io/Gauntlet/Classes/StateMachine.html).
