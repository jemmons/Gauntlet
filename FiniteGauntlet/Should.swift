import Foundation

enum Should<T>{
  case Continue, Abort, Redirect(T)
}
