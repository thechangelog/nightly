# Changelog Nightly

Changelog Nightly is a free email we ship every night at 10pm US Central. It unearths the hottest new repos on GitHub before they blow up.

<a href="https://changelog.com/nightly"><img src="images/subscribe.png" alt="Subscribe to Changelog Nightly" width=250/></a>

Here's a preview:

[![Changelog Nightly Preview](images/changelog-nightly.jpg)][nightly]

Want something opinionated and less frequent? Subscribe to [Changelog News][news]!

## Props and thanks

This project would not be possible without [Ilya Grigorik][igvita] and the work he put in to [GitHub Archive][gh-archive]. Thanks for all you do, Ilya!

[Listen to our in-depth interview with Ilya on The Changelog #144][144] where we cover all the details about GitHub Archive and Changelog Nightly.

## Contributing

[See here.][contributing]

## How an issue is picked

- **Top Starred** comes from GitHub Archive via BigQuery: repos that gained at least 50 stars that day.
- **Top New** comes from the GitHub search API: repos created that day with at least 10 stars. (It used to come from GitHub Archive too, but GitHub's event feed stopped carrying repository `CreateEvent`s in October 2025.)
- Both lists are best-first, and keep going until there are 15 repos that pass every check or the lookup budget runs out.
- Every repo that doesn't make it is logged to stderr as `[nightly] DATE skipped URL (N stars): reason`, so a thin issue explains itself in the logs.
- Top New also screens for spam the keyword list can't see: lookalike repos (same stars, same size), throwaway accounts, and malware-list topics on accounts that haven't established themselves. See `lib/new_repos.rb`.

## Hacking

1. Sign up for Google BigQuery and get an API key
2. Create a GitHub token (no scopes needed) for `GITHUB_TOKEN`; it is used for repo, search and owner lookups
3. Copy `.env.example` to `.env` and configure for your environment
4. run `rake -T` to see all the possible commands

## License

[MIT][license]

[nightly]: https://changelog.com/nightly
[news]: https://changelog.com/news
[igvita]: http://igvita.com
[gh-archive]: https://www.githubarchive.org
[144]: https://changelog.com/144
[contributing]: https://github.com/thechangelog/nightly/blob/master/CONTRIBUTING.md
[license]: https://github.com/thechangelog/nightly/blob/master/LICENSE
