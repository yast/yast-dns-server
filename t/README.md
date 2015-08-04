# Integration tests of the Command Line Interface (CLI)

## Running

> **Warning**, they will reconfigure your system, so use them in a scratch VM.

```sh
prove
```

`prove` is a runner for the [Test Anything Protocol](http://testanything.org/),
which has a stdio interface and thus is well suited for command line tests.
The program is conveniently part of a base openSUSE system, in perl5.rpm.
