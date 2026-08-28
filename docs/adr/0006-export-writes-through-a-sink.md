# Export writes through a Sink

Status: proposed

`StaticSite::ExportJob` carries four unrelated concerns in one class — deploy lock and retry,
which content belongs to a site, pagination and artifact rendering, and file IO — and its spec
asserts against the real filesystem, so every example checks "is a file there" instead of "is the
export correct". Now that `StaticSite::Routes` owns the address scheme, the IO can be lifted out:
`StaticSite::Export` renders a site against a **Sink** and the job keeps only job-shaped work.

The Sink contract is two methods and no lifecycle:

- `write(path, content)` — content generated in the process
- `copy(path, from:)` — a file that already exists on disk

Implementations must be thread-safe, because the export writes from four threads via
`ParallelProcessor`. They guarantee nothing about write *order*.

Two implementations:

- `FileSink` creates a fresh temporary directory inside `deployment_target.build_path` — same
  filesystem as `source_dir`, so moving it into place at the end is cheap. It additionally exposes
  `#dir` and `#discard!`, which are implementation-specific and deliberately *not* part of the
  contract.
- `RecordingSink` keeps a Hash for tests. Its `copy` records the source path and never reads the
  bytes, so image variants — up to 25 MB each, times every entry in `Image::Variants` — never enter
  memory. The name says what the object does rather than claiming where bytes live.

`StaticSite::Export.new(site:, routes:, sink:)` takes no `DeploymentTarget`; if it ever does, the
extraction has failed and the coupling has merely moved. The job builds `Routes` and the `FileSink`,
runs the export, precompresses `sink.dir`, replaces `source_dir` with it, deploys, notifies, and
calls `discard!` in the same `ensure` that releases the deploy lock.

## Consequences

The export becomes near-atomic. Today `cleanup` runs `rm_rf(source_dir)` *first*, so a crash
mid-export leaves the deployed directory half-destroyed until the next successful run. Building into
a temporary directory shrinks that window to the `rm_rf` + `mv` at the end. It is not fully atomic —
an interrupt between those two still leaves `source_dir` missing.

`POSTS_PER_PAGE` moves to `PageRenderer`, so `PreviewsController` stops reaching into a job constant.
This anticipates a later step that gives `PreviewsController` and the export a single renderer; doing
it now avoids cementing the constant in `Export`, where it belongs even less.

Specs split three ways: the export assertions run against `RecordingSink` with no IO, a small
`FileSink` spec against `Dir.mktmpdir` covers nested paths, byte-exact copies and encoding, and one
end-to-end example proves the wiring. Tests stop touching `storage/`.

`PrecompressJob` stays an `ActiveJob` that is only ever `perform_now`'d from a single call site.
That was already true and is not addressed here.

Only one non-test implementation of the Sink exists. A `ZipSink` was considered and rejected as a
sink — zipping a built site is a deployment concern, not a way of writing one. The seam therefore
rests on separating the job's four concerns, not on counting adapters.

## Considered options

**Use `Dir.mktmpdir` in the spec and change nothing else.** Cheapest option, and it was the original
motivation: the export was believed to leave empty directories behind. Measured, that is false — the
full suite (988 examples) leaves `storage/hugo` empty, and the directories found there are dev-run
output and pre-ADR-0005 Hugo debris. Rejected because it fixes a symptom that does not exist and
leaves the four concerns entangled.

**Give the Sink a lifecycle — `prepare`, `finalize`, `commit!`.** Rejected: each of these would be
empty in `RecordingSink`. Preparing the directory belongs in `FileSink`'s constructor, precompressing
and moving into place belong to the job, which already owns lock, deploy and notify.
