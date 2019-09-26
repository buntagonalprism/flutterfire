@JS()
library global;

import "package:js/js.dart";

@JS('Promise')
class Promise {
  external void then(Function onFulfilled, Function onRejected);
}
