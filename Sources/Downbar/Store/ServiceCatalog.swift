import Foundation

/// A known service the user can toggle on in Settings without typing a URL.
struct CatalogEntry: Identifiable, Hashable {
    let name: String
    let url: URL
    let provider: ProviderKind
    let category: String

    /// Stable identity = provider + host, so it matches a monitored `Service`.
    var id: String { "\(provider.rawValue):\(host)" }
    var host: String { (url.host()?.lowercased()) ?? url.absoluteString.lowercased() }
}

/// Curated directory of public status pages developers care about, grouped by
/// category. Hosts for the eight defaults match `ServiceStore.seed` exactly so
/// seeded services show as already-enabled. Every entry's endpoint has been
/// verified live; anything unreachable simply shows gray, never crashes.
enum ServiceCatalog {
    /// Category display order.
    static let categories = [
        "AI · Models & APIs",
        "AI · Voice, Image & Video",
        "AI · Dev & Infra",
        "Hosting & PaaS",
        "Cloud & Infra",
        "Developer Tools",
        "Data & Backend",
        "Identity & Auth",
        "Observability & APM",
        "Errors & Crash Reporting",
        "Incident & On-Call",
        "Payments & Commerce",
        "Communication",
        "Productivity",
    ]

    static let all: [CatalogEntry] = [
        // AI · Models & APIs
        e("Anthropic", "https://status.claude.com", .statuspage, "AI · Models & APIs"),
        e("OpenAI", "https://status.openai.com", .statuspage, "AI · Models & APIs"),
        e("Google AI Studio", "https://aistudio.google.com", .website, "AI · Models & APIs"),
        e("xAI", "https://status.x.ai/", .xai, "AI · Models & APIs"),
        e("Perplexity", "https://status.perplexity.com", .instatus, "AI · Models & APIs"),
        e("Cohere", "https://status.cohere.com", .statuspage, "AI · Models & APIs"),
        e("Groq", "https://groqstatus.com", .statuspage, "AI · Models & APIs"),
        e("Cerebras", "https://status.cerebras.ai", .statuspage, "AI · Models & APIs"),
        e("Replicate", "https://replicatestatus.com", .statuspage, "AI · Models & APIs"),
        e("Scale AI", "https://status.scale.com", .statuspage, "AI · Models & APIs"),
        e("Nomic", "https://status.nomic.ai", .statuspage, "AI · Models & APIs"),
        e("Jina AI", "https://status.jina.ai", .statuspage, "AI · Models & APIs"),
        e("Hume AI", "https://status.hume.ai", .statuspage, "AI · Models & APIs"),

        // AI · Voice, Image & Video
        e("ElevenLabs", "https://status.elevenlabs.io", .statuspage, "AI · Voice, Image & Video"),
        e("Deepgram", "https://status.deepgram.com", .statuspage, "AI · Voice, Image & Video"),
        e("AssemblyAI", "https://status.assemblyai.com", .statuspage, "AI · Voice, Image & Video"),
        e("Speechmatics", "https://status.speechmatics.com", .statuspage, "AI · Voice, Image & Video"),
        e("Retell AI", "https://status.retellai.com", .statuspage, "AI · Voice, Image & Video"),
        e("Runway", "https://status.runwayml.com", .statuspage, "AI · Voice, Image & Video"),
        e("Stability AI", "https://status.stability.ai", .statuspage, "AI · Voice, Image & Video"),
        e("Synthesia", "https://status.synthesia.io", .statuspage, "AI · Voice, Image & Video"),
        e("HeyGen", "https://status.heygen.com", .statuspage, "AI · Voice, Image & Video"),
        e("Twelve Labs", "https://status.twelvelabs.io", .statuspage, "AI · Voice, Image & Video"),
        e("Ideogram", "https://status.ideogram.ai", .statuspage, "AI · Voice, Image & Video"),
        e("Recraft", "https://status.recraft.ai", .instatus, "AI · Voice, Image & Video"),
        e("Character.AI", "https://status.character.ai", .statuspage, "AI · Voice, Image & Video"),

        // AI · Dev & Infra
        e("Cursor", "https://status.cursor.com", .statuspage, "AI · Dev & Infra"),
        e("LangSmith", "https://status.smith.langchain.com", .statuspage, "AI · Dev & Infra"),
        e("Baseten", "https://status.baseten.co", .statuspage, "AI · Dev & Infra"),
        e("Lambda Labs", "https://status.lambdalabs.com", .statuspage, "AI · Dev & Infra"),
        e("Pinecone", "https://status.pinecone.io", .statuspage, "AI · Dev & Infra"),
        e("Clarifai", "https://status.clarifai.com", .statuspage, "AI · Dev & Infra"),

        // Hosting & PaaS
        e("Vercel", "https://www.vercel-status.com", .statuspage, "Hosting & PaaS"),
        e("Netlify", "https://www.netlifystatus.com", .statuspage, "Hosting & PaaS"),
        e("Render", "https://status.render.com", .statuspage, "Hosting & PaaS"),
        e("Fly.io", "https://status.flyio.net", .statuspage, "Hosting & PaaS"),

        // Cloud & Infra
        e("AWS", "https://health.aws.amazon.com/health/status", .aws, "Cloud & Infra"),
        e("Google Cloud", "https://status.cloud.google.com", .gcp, "Cloud & Infra"),
        e("Microsoft Azure", "https://azure.status.microsoft", .azure, "Cloud & Infra"),
        e("Apple Developer", "https://developer.apple.com/system-status/", .apple, "Cloud & Infra"),
        e("Apple System Status", "https://www.apple.com/support/systemstatus/", .apple, "Cloud & Infra"),
        e("Cloudflare", "https://www.cloudflarestatus.com", .statuspage, "Cloud & Infra"),
        e("DigitalOcean", "https://status.digitalocean.com", .statuspage, "Cloud & Infra"),
        e("Linode", "https://status.linode.com", .statuspage, "Cloud & Infra"),
        e("Scaleway", "https://status.scaleway.com", .statuspage, "Cloud & Infra"),
        e("HashiCorp", "https://status.hashicorp.com", .statuspage, "Cloud & Infra"),
        e("Bunny", "https://status.bunny.net", .statuspage, "Cloud & Infra"),

        // Developer Tools
        e("GitHub", "https://www.githubstatus.com", .statuspage, "Developer Tools"),
        e("Bitbucket", "https://bitbucket.status.atlassian.com", .statuspage, "Developer Tools"),
        e("CircleCI", "https://status.circleci.com", .statuspage, "Developer Tools"),
        e("Travis CI", "https://www.traviscistatus.com", .statuspage, "Developer Tools"),
        e("Gitpod", "https://www.gitpodstatus.com", .statuspage, "Developer Tools"),
        e("Postman", "https://status.postman.com", .statuspage, "Developer Tools"),
        e("npm", "https://status.npmjs.org", .statuspage, "Developer Tools"),
        e("PyPI", "https://status.python.org", .statuspage, "Developer Tools"),
        e("crates.io", "https://status.crates.io", .statuspage, "Developer Tools"),
        e("RubyGems", "https://status.rubygems.org", .statuspage, "Developer Tools"),
        e("Temporal", "https://status.temporal.io", .statuspage, "Developer Tools"),
        e("LaunchDarkly", "https://status.launchdarkly.com", .statuspage, "Developer Tools"),

        // Data & Backend
        e("Supabase", "https://status.supabase.com", .statuspage, "Data & Backend"),
        e("MongoDB Atlas", "https://status.mongodb.com", .statuspage, "Data & Backend"),
        e("PlanetScale", "https://www.planetscalestatus.com", .statuspage, "Data & Backend"),
        e("Upstash", "https://status.upstash.com", .statuspage, "Data & Backend"),
        e("Confluent", "https://status.confluent.cloud", .statuspage, "Data & Backend"),
        e("Snowflake", "https://status.snowflake.com", .statuspage, "Data & Backend"),
        e("Elastic", "https://status.elastic.co", .statuspage, "Data & Backend"),
        e("Cloudinary", "https://status.cloudinary.com", .statuspage, "Data & Backend"),
        e("Contentful", "https://www.contentfulstatus.com", .statuspage, "Data & Backend"),
        e("Sanity", "https://www.sanity-status.com", .statuspage, "Data & Backend"),
        e("Mux", "https://status.mux.com", .statuspage, "Data & Backend"),
        e("Segment", "https://status.segment.com", .statuspage, "Data & Backend"),

        // Identity & Auth
        e("Clerk", "https://status.clerk.com", .statuspage, "Identity & Auth"),
        e("WorkOS", "https://status.workos.com", .statuspage, "Identity & Auth"),

        // Observability & APM
        e("Datadog", "https://status.datadoghq.com", .statuspage, "Observability & APM"),
        e("New Relic", "https://status.newrelic.com", .statuspage, "Observability & APM"),
        e("Grafana", "https://status.grafana.com", .statuspage, "Observability & APM"),
        e("Honeycomb", "https://status.honeycomb.io", .statuspage, "Observability & APM"),
        e("Coralogix", "https://status.coralogix.com", .statuspage, "Observability & APM"),
        e("Sumo Logic", "https://status.sumologic.com", .statuspage, "Observability & APM"),
        e("Logz.io", "https://status.logz.io", .statuspage, "Observability & APM"),
        e("Mezmo", "https://status.mezmo.com", .statuspage, "Observability & APM"),

        // Errors & Crash Reporting
        e("Sentry", "https://status.sentry.io", .statuspage, "Errors & Crash Reporting"),
        e("Rollbar", "https://status.rollbar.com", .statuspage, "Errors & Crash Reporting"),
        e("Bugsnag", "https://status.bugsnag.com", .statuspage, "Errors & Crash Reporting"),
        e("Airbrake", "https://status.airbrake.io", .statuspage, "Errors & Crash Reporting"),
        e("Honeybadger", "https://status.honeybadger.io", .statuspage, "Errors & Crash Reporting"),

        // Incident & On-Call
        e("incident.io", "https://status.incident.io", .statuspage, "Incident & On-Call"),
        e("Opsgenie", "https://status.opsgenie.com", .statuspage, "Incident & On-Call"),
        e("xMatters", "https://status.xmatters.com", .statuspage, "Incident & On-Call"),
        e("BigPanda", "https://status.bigpanda.io", .statuspage, "Incident & On-Call"),
        e("Checkly", "https://checklyhq.instatus.com", .instatus, "Incident & On-Call"),

        // Payments & Commerce
        e("Stripe", "https://www.stripestatus.com", .statuspage, "Payments & Commerce"),
        e("Coinbase", "https://status.coinbase.com", .statuspage, "Payments & Commerce"),
        e("Plaid", "https://status.plaid.com", .statuspage, "Payments & Commerce"),
        e("Shopify", "https://www.shopifystatus.com", .statuspage, "Payments & Commerce"),

        // Communication
        e("Discord", "https://discordstatus.com", .statuspage, "Communication"),
        e("Zoom", "https://status.zoom.us", .statuspage, "Communication"),
        e("Twilio", "https://status.twilio.com", .statuspage, "Communication"),
        e("SendGrid", "https://status.sendgrid.com", .statuspage, "Communication"),
        e("Mailgun", "https://status.mailgun.com", .statuspage, "Communication"),
        e("Resend", "https://resend-status.com", .statuspage, "Communication"),
        e("Intercom", "https://www.intercomstatus.com", .statuspage, "Communication"),
        e("Reddit", "https://www.redditstatus.com", .statuspage, "Communication"),
        e("Vimeo", "https://www.vimeostatus.com", .statuspage, "Communication"),

        // Productivity
        e("Notion", "https://www.notion-status.com", .statuspage, "Productivity"),
        e("Linear", "https://linearstatus.com", .statuspage, "Productivity"),
        e("Atlassian", "https://status.atlassian.com", .statuspage, "Productivity"),
        e("Figma", "https://status.figma.com", .statuspage, "Productivity"),
        e("Asana", "https://status.asana.com", .statuspage, "Productivity"),
        e("HubSpot", "https://status.hubspot.com", .statuspage, "Productivity"),
        e("Dropbox", "https://status.dropbox.com", .statuspage, "Productivity"),
        e("Squarespace", "https://status.squarespace.com", .statuspage, "Productivity"),
    ]

    static func entries(in category: String) -> [CatalogEntry] {
        all.filter { $0.category == category }
    }

    private static func e(_ name: String, _ url: String, _ provider: ProviderKind, _ category: String) -> CatalogEntry {
        CatalogEntry(name: name, url: URL(string: url)!, provider: provider, category: category)
    }
}
