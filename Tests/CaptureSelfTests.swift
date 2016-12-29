import Foundation
import XCTest


class Ref {
  var success = false
}



class Foo {
  private let ref: Ref
  private var handler: (()->Void)?
  func noop(){}

  init(ref: Ref) {
    self.ref = ref
  }
  
  func createCycle(){
    handler = { self.noop() }
  }
  
  func createCaptureList(){
    handler = { [unowned self] in self.noop() }
  }
  
  func directAssignment(){
    handler = noop
  }
  
  deinit {
    ref.success = true
  }
}



class CaptureSelfTests: XCTestCase {
  let ref = Ref()
  

  func testDeinitWorks() {
    let _ = Foo(ref: ref)
    XCTAssert(ref.success)
  }
  
  
  func testRetainCycle() {
    var subject = Optional(Foo(ref: ref))
    subject?.createCycle()
    subject = nil
    XCTAssertFalse(ref.success)
  }
  
  
  func testCaptureList() {
    var subject = Optional(Foo(ref: ref))
    subject?.createCaptureList()
    subject = nil
    XCTAssert(ref.success)
  }

  /**
   D'oh. We'd really like to see this work so that we could do things like

       class Foo {
         let machine: StateMachine<MyMachine>
         
         init(){
           machine = StateMachine(initialState: .Thing)
           machine.transitionHandler = didTransitionFrom
         }
   
         func didTransitionFrom(from: MyMachine, to: MyMachine){
           ...
         }
       }
   
   But for now it leaks.
   */
  func testDirectAssignment() {
    var subject = Optional(Foo(ref: ref))
    subject?.directAssignment()
    subject = nil
    XCTAssertFalse(ref.success) //Uh-oh!
  }
}
