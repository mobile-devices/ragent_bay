TODO list
=========

The listed features are sorted by priority, the most important comes first.

* Fix the cookies (see README)
* Allow to start a sequence with a multiple shot
* Link a sequence to an external event on the device (reboot, lost connection, etc.)
* Reduce messagepacked messages size (for instance, by storing the message fields in an array rather than a map + not transmit optional fields which are not set)
* Properly handle optional field which are not set (currently, an e.g. int optional field will be encoded in Java becasue there is no way to tell if the user set it to 0 or if the user did not set it)
* Add a "enum" type.
* Write tests (current ones are outdated)
* Allow several first shots, or starting at several positions in the sequence
* Allow sequence linking (say: continue that sequence with this other one)
* Check that the Java compilation succeeded.
* Update the json-schema gem to the latest version (requires rewriting part of the schema)

Features to test:

* 'bytes' basic type in Ruby
* extensive use of cookies
