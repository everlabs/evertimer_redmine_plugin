Security Policy
================

Supported Versions
-------------------

| Version | Supported |
|---------|-----------|
| 1.0.x   | ✅ |
| < 1.0   | ❌ |

Only the latest `1.0.x` release receives security fixes. Untagged `0.0.1` builds are not supported — please upgrade before reporting an issue against one of them.

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

The plugin relies on **Redmine's own authentication** (`X-Redmine-API-Key` or a logged-in session) and does not store or rotate keys. Its only authentication logic of its own is that, on its endpoints, a presented API key takes precedence over a session cookie. Vulnerabilities in Redmine's core authentication belong to [Redmine](https://www.redmine.org/projects/redmine/wiki/Security), not this plugin — please report those upstream. This policy covers the plugin's own code: its two endpoints (including that key-over-session rule), its settings screen, and its migrations.
