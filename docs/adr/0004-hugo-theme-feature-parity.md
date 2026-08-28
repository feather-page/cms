# Hugo theme feature parity

Status: superseded by [0005](0005-static-sites-with-erb.md)

While the CMS shipped multiple Hugo themes (`ink`, `simple_emoji`), every content feature had to be
implemented in all of them before it counted as done, so that switching themes never lost functionality.

The policy made each feature more expensive while the second theme added little value. ADR-0005 removed
Hugo and the themes entirely, which makes this moot. None of the files it referenced still exist; kept as
a record of why the multi-theme era worked the way it did.
