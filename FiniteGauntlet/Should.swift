import Foundation

public enum Should<T>{
  case Continue, Abort, Redirect(T)
}
