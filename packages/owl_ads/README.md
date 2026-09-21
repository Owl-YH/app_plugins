# owl_ads

Provider-neutral, pure Dart advertising contracts. This package contains no
Flutter APIs, native SDKs, provider identifiers, permission helpers, retry
policy, or persistent ad cache.

Applications construct a concrete provider in their composition root and pass
the `Ads` interface to features. The first implementation is
`owl_ads_gromore`.

Version `0.1.0` is available on pub.dev. Add:

```yaml
dependencies:
  owl_ads: ^0.1.0
```
