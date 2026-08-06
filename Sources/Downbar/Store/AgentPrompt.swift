import Foundation

/// Builds the copy-paste prompt (Settings → Services → "Add from a Codebase")
/// that lets any coding agent — Claude Code, Cursor, Codex — scan a repository,
/// map its dependencies against the built-in catalog, and merge what it finds
/// into `services.json`. Generated from `ServiceCatalog` so the known-services
/// table can never drift from what the app actually ships.
enum AgentPrompt {
    /// The full prompt, with the real (sandbox-resolved) config path baked in.
    static func text(configPath: String = ServiceStore.shared.fileURL.path) -> String {
        """
        Find the external services this codebase depends on — and the URLs it \
        deploys to production — and add them to Downbar, a macOS menu-bar status \
        monitor. Downbar's config is a plain JSON file it \
        reloads live on every save:

            \(configPath)

        ## Step 1 — find what this project depends on AND what it deploys

        Look through dependency manifests (package.json, requirements.txt, \
        pyproject.toml, go.mod, Cargo.toml, Gemfile, Package.swift, composer.json…), \
        SDK imports in source, environment variables (.env.example, config files), \
        infrastructure and deploy config (terraform, docker-compose, wrangler.toml, \
        vercel.json, netlify.toml, fly.toml…), and CI workflows. Collect two lists:

        1. Third-party hosted services the project depends on to run or ship: \
        clouds, hosting, databases, AI APIs, payments, email/SMS, auth, monitoring, \
        package registries, CI. Ignore plain code libraries that aren't a hosted \
        service.
        2. The project's OWN deployed surfaces — the production site, deployed API \
        base URLs, self-hosted services. Look in deploy config (custom domains and \
        routes in vercel.json / netlify.toml / fly.toml / wrangler.toml, CNAME \
        files, k8s ingress, terraform), package.json "homepage", README links, \
        CORS allowlists, and env vars like API_URL / NEXT_PUBLIC_*. Prefer the bare \
        production origin (https://example.com) over deep paths; skip localhost, \
        preview/per-branch URLs, and anything that needs auth to return a response.

        ## Step 2 — map each entry to something Downbar can monitor

        For third-party services, match against Downbar's known catalog first \
        (Name | status page URL | provider):

        \(catalogTable)

        For a third-party service not in this table, find its public status page \
        and verify its format yourself (e.g. with curl):
        - If `https://<status-host>/api/v2/status.json` returns JSON with a \
        `status.indicator` field → provider "statuspage".
        - Else if `https://<status-host>/summary.json` returns JSON with a `page` \
        field → provider "instatus".
        - Else, as a last resort, monitor the service's main URL with provider \
        "website" (a plain up/down + latency ping).
        Skip anything whose status page you can't verify — never guess a URL.

        The project's own deployed surfaces have no status page — add each one \
        directly with provider "website", named after the project (e.g. \
        "myapp.com (prod)", "myapp API"). Verify each URL responds over HTTPS \
        before adding it.

        ## Step 3 — merge into the config file

        The file is a JSON array of entries like \
        {"name": "GitHub", "url": "https://www.githubstatus.com", "provider": "statuspage"}. \
        Valid providers: statuspage, instatus, website, aws, apple, gcp, azure, xai, statusio.

        Rules:
        - Keep every existing entry exactly as it is, including its "id" field.
        - Append new entries WITHOUT an "id" — Downbar assigns one on reload.
        - Skip a service whose URL host is already present in the file.
        - If the file is missing, create it with the new entries only.

        Downbar picks the change up immediately — no restart needed. When you're done, \
        list what you added and what you found but skipped (and why).
        """
    }

    private static var catalogTable: String {
        ServiceCatalog.all
            .map { "\($0.name) | \($0.url.absoluteString) | \($0.provider.rawValue)" }
            .joined(separator: "\n")
    }
}
