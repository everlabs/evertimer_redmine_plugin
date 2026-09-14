Security Policy
================

Supported Versions
-------------------

| Version | Supported |
|---------|-----------|
| 1.0.x   | ✅ |
| < 1.0   | ❌ |

Only the latest `1.0.x` release receives security fixes. Earlier, untagged `0.0.1` builds (only ever available from the `feat/user-stats` branch) are not supported — please upgrade before reporting an issue against one of them.

Reporting a Vulnerability
--------------------------

Please **do not** open a public issue or discussion for a security vulnerability.

Instead, report it privately through GitHub's [private vulnerability reporting](https://github.com/everlabs/evertimer_redmine_plugin/security/advisories/new). This opens a draft security advisory visible only to the maintainers until it's resolved.

When reporting, please include as much of the following as you can:

- A description of the vulnerability and its potential impact.
- Steps to reproduce it (a minimal Redmine setup, request/response examples, etc.).
- The plugin version and the Redmine/Ruby/Rails versions you tested against.
- Whether it requires a valid Redmine API key, an authenticated session, or is reachable anonymously.

What to Expect
---------------

This is a small, maintainer-run project, so we can't promise a fixed response time (no SLA). We'll acknowledge new reports as soon as we can, and we'll keep you updated as we investigate and work on a fix. Credit is offered in the advisory unless you'd prefer to stay anonymous.

Scope
-----

The plugin authenticates every request through **Redmine's own standard API-key auth** (`X-Redmine-API-Key`); it does not implement its own authentication, key storage or key rotation. Vulnerabilities in Redmine's core API-key handling itself belong to [Redmine](https://www.redmine.org/projects/redmine/wiki/Security), not this plugin — please report those upstream. This policy covers the plugin's own code: its two endpoints, its settings screen, and its migrations.
