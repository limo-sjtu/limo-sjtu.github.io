# LIMO website maintenance guide

This repository uses a request-and-review workflow. Lab members submit facts through GitHub Issue Forms; the website maintainer decides what to publish, prepares the file changes, reviews the pull request, and merges it. Submitting a request never changes the website automatically.

## Roles and access

| Role               | Access                                  | Responsibility                                                 |
| ------------------ | --------------------------------------- | -------------------------------------------------------------- |
| Lab member         | Open and comment on issues              | Submit complete, public, accurate information                  |
| Website maintainer | Write access and pull-request review    | Accept, revise, or reject requests; implement accepted changes |
| GitHub Actions     | Read repository contents and run checks | Reject structurally invalid content and failed builds          |

Members do not need direct write access. The maintainer remains the code owner for the repository through `.github/CODEOWNERS`.

## Request lifecycle

1. A member opens a [website update request](https://github.com/limo-sjtu/limo-sjtu.github.io/issues/new/choose).
2. The maintainer checks the request and records one of these decisions in a comment:
   - **Accepted** — implement the request as submitted.
   - **Revision requested** — ask the submitter for missing or corrected facts.
   - **Accepted with revisions** — the maintainer adjusts wording or structure while preserving the facts.
   - **Rejected** — close the request with a short reason.
3. For an accepted request, create a branch and a pull request that contains `Closes #<issue-number>`.
4. Review the generated diff, automated validation, Jekyll build, and affected pages.
5. Merge to `master`. Close the issue only after the deployed page is correct.

Recommended labels are `status: needs review`, `status: revision requested`, `status: accepted`, and `status: rejected`. Labels are optional; the issue and linked pull request remain the audit trail.

## Sources of truth

| Content                              | Canonical files                    |
| ------------------------------------ | ---------------------------------- |
| Member directory entry and biography | `_people/<member-id>.md`           |
| Structured member CV                 | `_data/cv/<member-id>.yml`         |
| Member portrait                      | `assets/img/people/<filename>`     |
| Research-area descriptions           | `_data/research_areas.yml`         |
| Publications                         | `_bibliography/papers.bib`         |
| News                                 | `_news/YYYY-MM-DD-<short-slug>.md` |
| Recruitment information              | `_pages/join.md`                   |

Do not create a second bibliography, a second member-layout protocol, or an additional copy of publication data. Historical CV publication lists may remain, but new publications must first be added to `papers.bib`.

## Member schema

Use a lowercase `firstname_lastname` identifier for new members. The page and CV filenames must share the same identifier.

Internal profile:

```yaml
---
layout: limo-member
title: Full Name
img: portrait.jpg
cv: firstname_lastname
toc:
  sidebar: right
importance: 10
category: PhD student
status: current
research_areas: [imaging, optimization]
webpage: true
scholar:
github:
---
Short biography.
```

Redirect-only profile:

```yaml
---
layout: page
title: Full Name
img: portrait.jpg
importance: 10
category: Faculty
status: current
redirect: https://example.edu/profile
webpage: true
scholar:
github:
---
```

Allowed categories are `Faculty`, `Post-doc`, `PhD student`, `Master student`, `Undergraduate`, and `Alumni`. Use `status: current` for current members and `status: alumni` with the `Alumni` category for former members. Optional `research_areas` values are `imaging`, `optimization`, and `learning`; only add areas supported by the member's submitted biography. `importance` is an integer used for ordering within a category. Use full `https://` URLs for public links and verify that the portrait filename matches its case exactly.

CV data is a list of sections. Supported section types are `map`, `time_table`, `publications`, `list`, `nested_list`, and `list_groups`. Remove empty sections instead of leaving template placeholders in production data. A publication URL is optional in an existing CV entry; the template renders plain text when no URL is present.

## Publication schema

`_bibliography/papers.bib` is the only bibliography. Each citation key and each field inside an entry must be unique.

```bibtex
@article{author2026keyword,
  title={Paper Title},
  author={Last, First and Last, First},
  journal={Journal Name},
  year={2026},
  abbr={Journal},
  bibtex_show={true},
  html={https://doi.org/...},
  cate_primary={optimization},
  cate_secondary={none},
  selected={false},
}
```

Rules for new entries:

- Use `@article`, `@inproceedings`, or `@phdthesis` as appropriate.
- `abbr` must be `Journal`, `Conference`, `Preprint`, or `Thesis`.
- `cate_primary` must be `imaging`, `optimization`, or `learning`.
- `cate_secondary` is optional and may use the same values or `none`.
- `bibtex_show` and `selected` must be explicit booleans.
- Add a DOI or public `html` link. Historical entries without links are allowed temporarily and reported as a warning.
- Add `abstract` only when real abstract text is available; omit empty fields.
- The maintainer decides `selected`; submitters do not decide homepage placement.

## News schema

Filename: `_news/YYYY-MM-DD-short-slug.md`.

```yaml
---
layout: post
title: Short descriptive title
date: YYYY-MM-DD
kind: publication
inline: true
related_posts: false
---
Concise Markdown announcement with public links where useful.
```

Allowed `kind` values are `publication`, `event`, `award`, `member`, `recruiting`, `grant`, and `general`. Use `inline: true` for a short list item and `inline: false` for a longer standalone page. News is explicitly sorted by its front-matter date.

Reserve News for meaningful lab updates: awards, defenses and graduations, visitors and events, new members, grants, recruiting, and selected publication milestones. Routine bibliography additions belong only in `_bibliography/papers.bib`; they do not require a duplicate News item.

## Site content architecture

The primary navigation is `Research`, `People`, `Publications`, `News`, and `Join Us`. The PI page remains available below People but is not a separate top-level destination.

Research-area names and descriptions are maintained once in `_data/research_areas.yml`. The homepage cards and the full Research page both read this file. Each entry requires a stable lowercase `id`, a title, summary, description, methods, applications, and one or more publication-topic links. Do not duplicate these descriptions directly in page templates.

The homepage is a curated overview rather than a complete archive:

- three research areas come from `_data/research_areas.yml`;
- three featured papers come from bibliography entries with `selected={true}`;
- five recent non-preprint publications not already shown as featured come from the bibliography;
- five recent News items come from `_news/`;
- recruitment details link to `_pages/join.md`.

The maintainer controls `selected` and homepage placement. Member requests may propose a highlight, but publication acceptance does not automatically make an item featured.

## Local checks

Run the structural validator first:

```bash
ruby scripts/validate_content.rb
```

Then build the site:

```bash
bundle exec jekyll build
```

For any dependency, layout, include, JavaScript, or Sass change, also run the
theme compatibility checks:

```bash
bundle exec al-folio upgrade audit
bundle exec al-folio upgrade overrides audit --fail-on-stale
```

The repository excludes the unused demonstration notebook from the build, so Jupyter is not required for ordinary website maintenance. When layout, images, or rendered text changes, also inspect the affected page in a local browser preview.

## Theme architecture and upgrades

The al-folio runtime is supplied by versioned gems in `Gemfile.lock`. Site-owned
presentation code is deliberately namespaced so that a theme update does not
silently replace it:

| Responsibility     | Location                                                      |
| ------------------ | ------------------------------------------------------------- |
| LIMO layouts       | `_layouts/limo-*.liquid`                                      |
| LIMO components    | `_includes/limo/`                                             |
| LIMO styles        | `_sass/limo/`                                                 |
| Structured content | `_people/`, `_data/cv/`, `_news/`, `_bibliography/papers.bib` |

Only two intentional theme overrides remain and both are recorded in
`.al-folio-overrides.yml`:

- `_layouts/bib.liquid` adds LIMO publication highlights while retaining the
  upstream publication renderer.
- `assets/css/main.scss` loads the upstream Sass modules and then the LIMO Sass
  entry point.

Do not add a local file with the same path as an al-folio layout, include,
JavaScript file, or Sass partial unless an override is unavoidable. Prefer a
new `limo-*` layout or a component below `_includes/limo/`.

To update al-folio:

1. Create a dedicated branch and update the pinned al-folio gems and lockfile.
2. Run `bundle exec al-folio upgrade audit` and the override audit shown above.
3. Review the upstream diff for each reported override before acknowledging it.
4. Run the content validator and a clean Jekyll build.
5. Inspect the homepage, People, Publications, one member CV, and mobile
   navigation before merging.

If an intentional override changes after review, acknowledge only that path:

```bash
bundle exec al-folio upgrade overrides accept _layouts/bib.liquid
```

Never run `overrides accept --all` merely to silence a warning; the manifest is
the review record for upstream-sensitive files.

## Repository protection to enable on GitHub

The repository files prepare the workflow, but an owner must enable branch protection in GitHub settings:

1. Create a ruleset for the `master` branch.
2. Require changes through pull requests.
3. Require at least one approval and require code-owner review.
4. Require the `Validate website content / validate` status check and the site build check.
5. Block force pushes and branch deletion.
6. Limit bypass permission to the website maintainer or repository administrators.

This is the access-control boundary: members can submit requests without permission to merge or publish, while the maintainer retains the final decision.
