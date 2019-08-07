# Gauntlet

[![SwiftPM compatible](https://img.shields.io/badge/SwiftPM-compatible-success)](https://github.com/Apple/swift-package-manager) [![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-success)](https://github.com/Carthage/Carthage)

Gauntlet is a swift-friendly [state machine](https://en.wikipedia.org/wiki/Finite-state_machine) focusing on simple configuration and light weight objects. It was originally inspired by [a series of blog posts over on figure.ink](http://www.figure.ink/blog/2015/1/31/swift-state-machines-part-1), but has evolved substantially since then.

## Simple Configuration
Rather than requiring complicated graphs and configuration XML, state in Gauntlet is modeled by a single type (conforming to `Transitionable`) that is capable of determining whether transitions to other instances of itself are allowed. 

This not only simplifies configuration substantially, it maps very nicely onto swift's concept of an `enum` and can be trivially implemented with a single `switch`:   

```swift
enum TrafficLight: Transitionable {
  case red, yellow, green

  func shouldTransition(to: TrafficLight) -> Bool {
    switch (self, to) {
    case (.red, .green), (.green, .yellow), (.yellow, .red):
      return true
    default:
      return false
    }
  }
}
```

## Light Weight Objects
Gauntlet doesn't require you subclass your objects from some abstract root machine or manage class hierarchies of behavior. Instead, a simple light weight `StateMachine` class is available for you to compose into any of your existing types. 

A `StateMachine` gets created with a `Transitionable` type and an initial state. Queueing up state changes is a simple method call and a delegate handler can be assigned to respond to transitions. Once again, swift's `switch` is a good fit here:

```swift
class MyClass {
  let machine: StateMachine<TrafficLight>

  init() {
    machine = StateMachine(initialState: .red)
    machine.delegates.didTransition = { [weak self] _, to in
      switch to {
      case .red:
        self?.stop()
      case .yellow:
        self?.caution()
      case .green:
        self?.go() 
      }
    }
  }

  func doThing() {
    machine.queue(.green)
  }
}
```

## Associating Values

Conforming to `Transitionable` with an `enum` allows us to associate values with a state:

```swift
enum Connection: Transitionable {
  case fetch(URLSessionTask), success([AnyHashable: Any]), failure(Error), cancel
  
  func shouldTransition(to: Connection) -> Bool {
    switch (self, to) {
    case (.fetching, .success), (.fetching, .failure), (_, .cancel):
      return true
    default:
      return false
    }
  }
}
```

Values get associated when a state change is queued:

```swift
func connect() {
  let task = makeTask(for: myURL) { json, error in
    guard error == nil else {
      machine.queue(.faulure(error))
      return
    }
    machine.queue(.success(json))
  }

  machine.queue(.fetching(task))
}
```

…And can be pulled out again when handling transitions:

```swift
machine.delegates.didTransition = { [weak self] from, to in
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

## API
Full API documentation [can be found here](https://jemmons.github.io/Gauntlet/Protocols/Transitionable.html).
