# Gauntlet

[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)

Gauntlet is a swift-friendly state machine focusing on simple configuration and light objects. It was originally inspired by [a blog post over on figure.ink](http://www.figure.ink/blog/2015/1/31/swift-state-machines-part-1), but has evolved substantially since then.

## Simple Configuration
Rather than requiring complicated graphs and configuration XML, state in Gauntlet is modeled by a single type (conforming to `StateType`) that is capable of judging whether transitions to other instances of itself are allowed or not. 

This not only simplifies configuration substantially, it maps very nicely onto swift's concept of an `enum` and can be trivially implemented with a single `switch`.   

## Usage

```swift
enum TrafficLight: StateType {
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
