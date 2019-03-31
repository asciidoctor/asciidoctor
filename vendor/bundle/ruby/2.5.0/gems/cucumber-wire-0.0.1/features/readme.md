Cucumber's wire protocol allows step definitions to be
implemented and invoked on any platform.

Communication is over a TCP socket, which Cucumber connects to when it finds
a definition file with the .wire extension in the step_definitions folder
(or other load path). Note that these files are rendered with ERB when loaded.

A `Wire::DataPacket` flowing in either direction is formatted as a JSON-encoded
string, with a newline character signaling the end of a packet. See the
specs for `Cucumber::Wire::DataPacket` for more details.

Cucumber sends the following request messages out over the wire:

* `step_matches` - Find out whether the wire server has a definition for a step
* `invoke` - Ask for a step definition to be invoked
* `begin_scenario` - signals that cucumber is about to execute a scenario
* `end_scenario` - signals that cucumber has finished executing a scenario
* `snippet_text` - requests a snippet for an undefined step

Every message supports two standard responses:

* `success` - expects different arguments (sometimes none at all) depending
  on the request that was sent.
* `fail` - causes a Cucumber::Wire::Exception to be raised.

Some messages support more responses - see individual scenarios for details.
