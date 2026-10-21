//! The target runtime, not Prism's latest grammar, owns Ruby syntax.
use ruby_prism::{Options, ParseOptions, ParseResult, Version};

pub struct Parser {
    version: Version,
    options: ParseOptions,
}

impl Parser {
    /// Accept a recorded RUBY_DESCRIPTION or an explicit CLI runtime version.
    /// No host Ruby subprocess, file inference, or nearest/latest fallback.
    pub fn for_runtime(runtime: &str) -> Result<Self, String> {
        let number = runtime.strip_prefix("ruby ").unwrap_or(runtime)
            .split_whitespace().next().unwrap_or("");
        let parts: Vec<_> = number.split('.').collect();
        let valid_patch = |patch: &str| {
            let suffix = patch.trim_start_matches(|c: char| c.is_ascii_digit());
            patch != suffix && (suffix.is_empty() || suffix == "dev"
                || ["preview", "rc", "p"].iter().any(|prefix| suffix.strip_prefix(prefix)
                    .is_some_and(|n| !n.is_empty() && n.bytes().all(|b| b.is_ascii_digit()))))
        };
        let version = match parts.as_slice() {
            // Prism 2 names the CRuby 4.0 grammar CRuby3_5; not Ruby 3.5 support.
            ["4", "0", patch] if valid_patch(patch) => Version::CRuby3_5,
            ["4", "1", patch] if valid_patch(patch) => Version::CRuby4_1,
            _ => return Err(format!("unsupported target Ruby {runtime:?}: explicit Ruby 4.0.x or 4.1.x required; refusing to parse")),
        };
        Ok(Self { version, options: Options::default().version(version).build() })
    }

    pub fn version(&self) -> Version { self.version }

    pub fn parse<'a>(&'a self, source: &'a [u8]) -> ParseResult<'a> {
        ruby_prism::parse_with_options(source, &self.options)
    }
}
