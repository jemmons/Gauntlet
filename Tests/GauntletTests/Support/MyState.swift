import Foundation
import Gauntlet



enum MyState: Transitionable, Equatable {
  case ready, working, success(String), failure(NSError)
  func shouldTransition(to: Self) -> Bool {
    switch (self, to) {
    case (.ready, .ready),
         (.ready, .working),
         (.working, .success),
         (.working, .failure),
         (.success, .ready),
         (.failure, .ready):
      return true
    default:
      return false
    }
  }
}

