# owl_ads

Provider-neutral, pure Dart advertising contracts. This package contains no
Flutter APIs, native SDKs, provider identifiers, permission helpers, retry
policy, or persistent ad cache.

Applications construct a concrete provider in their composition root and pass
the `Ads` interface to features. The first implementation is
`owl_ads_gromore`.

After the first `0.1.0` release is available on pub.dev, add:

```yaml
dependencies:
  owl_ads: ^0.1.0
```
