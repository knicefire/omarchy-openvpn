import QtQuick
import QtTest
import ".."

TestCase {
  id: testCase
  name: "OpenVpnProgress"

  // A fresh service per test: the stub processes never stop running.
  Component { id: serviceComponent; OpenVpnService {} }

  readonly property string u: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"

  function make() { return createTemporaryObject(serviceComponent, testCase) }
  function profile(active) { return { uuid: u, name: "A", active: active, connecting: false, disconnecting: false } }

  function test_disconnectShowsDisconnecting() {
    var s = make()
    var p = profile(true)
    s.setConnection(p)
    compare(s.profileStatus(p), "Disconnecting…")
    compare(s.profileSwitchOn(p), false)
  }

  function test_connectShowsConnecting() {
    var s = make()
    var p = profile(false)
    verify(s.setConnection(p, true))
    s.submitAuthentication("/p/connect-profile")
    compare(s.profileStatus(p), "Connecting…")
    compare(s.profileSwitchOn(p), true)
  }

  function test_deleteShowsDeleting() {
    var s = make()
    var p = profile(true)
    s.deleteConnection(u, "/p/delete-profile")
    compare(s.profileStatus(p), "Deleting…")
  }

  function test_renameKeepsStatus() {
    var s = make()
    var p = profile(false)
    s.renameConnection(u, "B")
    compare(s.profileStatus(p), "Disconnected")
    compare(s.profileSwitchOn(p), false)
  }

  function test_networkManagerStates() {
    var s = make()
    var list = s.parseProfiles(u + ":A:vpn:wlp59s0:deactivating\nbbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb:B:vpn::activating")
    compare(list[0].disconnecting, true)
    compare(s.profileStatus(list[0]), "Disconnecting…")
    compare(s.profileStatus(list[1]), "Connecting…")
    compare(s.profileStatus(profile(true)), "Connected")
  }

  function test_busyStaysThroughStaleList() {
    // A list that started before the action ended still shows the old state.
    var s = make()
    s.queryHelper = "/p/nmcli-query"
    var p = profile(true)
    s.setConnection(p)
    s.refresh()
    s.settleAction()
    s.listOutput = u + ":A:vpn:wlp59s0:activated"
    s.listExitCode = 0
    s.listStreamFinished = true
    s.finalizeList()
    compare(s.busyUuid, u)
    compare(s.profileStatus(s.profiles[0]), "Disconnecting…")
  }

  function test_newActionCancelsSettling() {
    // A retry right after a failed connect starts while the old action settles.
    var s = make()
    s.queryHelper = "/p/nmcli-query"
    var other = "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"
    s.renameConnection(u, "B")
    s.settleAction()
    s.authUuid = other
    s.submitAuthentication("/p/connect-profile")
    s.refresh()
    s.listOutput = other + ":B:vpn::"
    s.listExitCode = 0
    s.listStreamFinished = true
    s.finalizeList()
    compare(s.busyUuid, other)
    compare(s.busyAction, "connect")
  }

  function test_busyClearsAfterFreshList() {
    var s = make()
    s.queryHelper = "/p/nmcli-query"
    var p = profile(true)
    s.setConnection(p)
    s.settleAction()
    s.refresh()
    s.listOutput = u + ":A:vpn::"
    s.listExitCode = 0
    s.listStreamFinished = true
    s.finalizeList()
    compare(s.busyUuid, "")
    compare(s.busyAction, "")
    compare(s.profileStatus(s.profiles[0]), "Disconnected")
  }
}
