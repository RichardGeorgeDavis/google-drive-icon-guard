# Service Registration Scaffold

This directory is the packaged registration scaffold for the helper install/runtime path.

Current intent:

- package install-plan resources with the beta app
- define the launch-agent and Mach-service artefacts used by the helper registration flow
- give the app and helper CLI concrete files to install when preparing the deployed helper boundary

What is now in repo:

- an example launch-agent plist for the beta helper Mach service
- installer code that can write a real launch-agent plist and installation receipt
- helper CLI commands to print the install plan, write/remove registration files, bootstrap/bootout/status the LaunchAgent, and run the helper as a named XPC service host

This still does **not** mean the final signed helper is fully deployable today.

The remaining work is still:

- Apple-granted Endpoint Security entitlement approval
- signed deployment and trust validation for the installed helper target
- app-driven install/start/stop/status UX flows
- final deployed caller-identity validation using the installed helper/service environment
