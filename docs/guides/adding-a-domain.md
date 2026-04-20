# Adding a Domain

How to add a new domain detection to aiframework.

## What is a Domain?

Domains represent application concerns like "authentication", "payments", "search", or "caching". When aiframework detects a domain, it generates domain-specific invariants, security concerns, and CLAUDE.md guidance.

## How Detection Works

The domain scanner (`rust/src/scanner/domain.rs`) matches file paths against pattern lists. Each domain has a name, display name, and a list of path patterns.

## Adding a New Domain

Edit `rust/src/scanner/domain.rs`. Find the `domain_defs` array and add your entry:

```rust
("caching", "Caching Layer", &[
    "cache/", "cache.", "redis", "memcached", "cdn",
]),
```

Then add invariants in `derive_invariants()`:

```rust
"caching" => {
    invariants.push("cache-invalidation-required".to_string());
}
```

And security concerns in `derive_security_concerns()`:

```rust
"caching" => {
    concerns.push("cache-poisoning".to_string());
}
```

## Testing

```bash
cd rust && cargo test
```

The domain scanner runs against the file list — no external dependencies needed.
